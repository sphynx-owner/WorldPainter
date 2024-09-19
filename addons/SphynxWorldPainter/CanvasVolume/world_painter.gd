extends MeshInstance3D
class_name WorldPainter

const world_painter_material : Material = preload("res://addons/SphynxWorldPainter/CanvasVolume/Materials/world_painter_material.tres")
## The pixel count in each dimension of the 3D paint texture.[br][br]
## [color=yellow]Warning:[/color] Having too many pixels assigned across
## all your world paint textures can easily lead to GPU memory limits being reached
## avoid having more than 1,000,000 pixels per world painter.[br]
@export var map_resolution : Vector3i = Vector3i(100, 100, 100)
## Wether the pixel count scales with the texture or represents the resolution per
## world unit.[br][br]
## [color=yellow]Warning:[/color] this counts the meshe's extents as well, meaning larger
## mesh assets would increase the pixel count.[br]
@export var world_space_resolution : bool = false

@export var relevant_collisions : Array[CollisionObject3D]

var texture_3D_rd : Texture3DRD 

var texture_3D : RID

var texture_uniform : RDUniform

var texture3D_view : RDTextureView

var compute_list : int

var compute_size : Vector3i 

var uniform_set : RID

var rd : RenderingDevice = null
var shader_file : RDShaderFile
var shader
var pipeline

@onready var mesh_extents : Vector3 = mesh.get_aabb().size

func _ready():
	RenderingServer.call_on_render_thread(initialize_compute)
	set_surface_override_material(0, world_painter_material.duplicate())
	get_surface_override_material(0).set_shader_parameter.call_deferred("world_paint_texture", texture_3D_rd)
	get_surface_override_material(0).set_shader_parameter.call_deferred("mesh_extents", mesh_extents)
	WorldPainterSingleton.subscribe_world_painter(self)


func initialize_compute():
	# We will be using our own RenderingDevice to handle the compute commands
	rd = RenderingServer.get_rendering_device()
	
	# Create shader and pipeline
	shader_file = preload("res://addons/SphynxWorldPainter/CanvasVolume/Compute/canvas_volume.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)
	
	if world_space_resolution:
		map_resolution = Vector3i(Vector3(map_resolution) * global_transform.basis.scaled(mesh_extents).get_scale())
	
	var texture_3D_format : RDTextureFormat = RDTextureFormat.new()
	texture_3D_format.width = map_resolution.x
	texture_3D_format.height = map_resolution.y
	texture_3D_format.depth = map_resolution.z
	
	texture_3D_format.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	
	texture_3D_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	
	texture_3D_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	
	texture3D_view = RDTextureView.new()
	
	texture_3D = rd.texture_create(texture_3D_format, texture3D_view, [])
	
	texture_uniform = RDUniform.new()
	
	texture_uniform.binding = 0
	
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	
	texture_uniform.add_id(texture_3D)
	
	texture_3D_rd = Texture3DRD.new()
	texture_3D_rd.texture_rd_rid = texture_3D


func paint(brush : WorldBrush, in_position : Vector3, in_basis : Basis, brush_multiplier : float):
	in_position = global_basis.scaled(mesh_extents).inverse() * (in_position - global_position)
	
	in_position = (in_position + Vector3(0.5, 0.5, 0.5)) * Vector3(map_resolution)
	
	compute_size = Vector3(brush.brush_size, brush.brush_size, brush.brush_size) / global_transform.basis.scaled(mesh_extents).get_scale() * Vector3(map_resolution)
	
	compute_size = (compute_size - Vector3i(1, 1, 1)) / 8 + Vector3i(1, 1, 1)
	
	var volume_basis : Basis = global_basis.orthonormalized();
	
	RenderingServer.call_on_render_thread(render_paint.bind(brush, in_position, in_basis, volume_basis, brush_multiplier))


func render_paint(brush : WorldBrush, in_position : Vector3, in_basis : Basis, volume_basis : Basis, brush_multiplier : float):	
	var push_constants : PackedFloat32Array = [
		in_position.x,
		in_position.y,
		in_position.z,
		brush_multiplier,
		in_basis.x.x,
		in_basis.x.y,
		in_basis.x.z,
		0,
		in_basis.y.x,
		in_basis.y.y,
		in_basis.y.z,
		0,
		in_basis.z.x,
		in_basis.z.y,
		in_basis.z.z,
		0,
		volume_basis.x.x,
		volume_basis.x.y,
		volume_basis.x.z,
		0,
		volume_basis.y.x,
		volume_basis.y.y,
		volume_basis.y.z,
		0,
		volume_basis.z.x,
		volume_basis.z.y,
		volume_basis.z.z,
		0,
	]
	
	var int_push_constants : PackedInt32Array = [
		0,
		0,
		0,
		0,
	]
	
	var byte_push_constants = push_constants.to_byte_array()
	
	byte_push_constants.append_array(int_push_constants.to_byte_array())
	
	uniform_set = rd.uniform_set_create([texture_uniform, brush.paint_texture_uniform], shader, 0)
	
	compute_list = rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	rd.compute_list_set_push_constant(compute_list, byte_push_constants, byte_push_constants.size())
	
	rd.compute_list_dispatch(compute_list, compute_size.x, compute_size.y, compute_size.z)
	
	rd.compute_list_end()
	
	rd.submit()
	
	rd.sync()
