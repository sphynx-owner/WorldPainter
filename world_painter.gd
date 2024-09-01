extends MeshInstance3D
class_name WorldPainter

@export var map_size : Vector3i = Vector3i(800, 800, 800)

@export var brush_size : float = 1

@export var paint_texture : Texture2D

var map_extents : Vector3 = Vector3(50, 50, 50)

var texture_3D_rd : Texture3DRD 

var texture_3D : RID

var texture_uniform : RDUniform

var texture3D_view : RDTextureView

var depth_texture_rd : Texture2DRD

var compute_list : int

var compute_size : Vector3i 

var uniform_set : RID

var rd : RenderingDevice = null
var shader_file : RDShaderFile
var shader_bytecode
var shader
var pipeline

func _ready():
	RenderingServer.call_on_render_thread(initialize_compute)
	get_surface_override_material(0).set_shader_parameter.call_deferred("world_paint_texture", texture_3D_rd)
	visible = true

func initialize_compute():
	# We will be using our own RenderingDevice to handle the compute commands
	rd = RenderingServer.get_rendering_device()
	
	# Create shader and pipeline
	shader_file = load("res://minimal_compute.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)
	
	var texture_3D_format : RDTextureFormat = RDTextureFormat.new()
	texture_3D_format.width = map_size.x
	texture_3D_format.height = map_size.y
	texture_3D_format.depth = map_size.z
	
	texture_3D_format.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	
	texture_3D_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	
	texture_3D_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	
	texture3D_view = RDTextureView.new()
	
	texture_3D = rd.texture_create(texture_3D_format, texture3D_view, [])
	
	texture_uniform = RDUniform.new()
	
	texture_uniform.binding = 0
	
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	
	texture_uniform.add_id(texture_3D)
	
	var sampler_state := RDSamplerState.new()
	
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	
	var linear_sampler : RID = rd.sampler_create(sampler_state)
	
	var paint_image : Image = paint_texture.get_image()
	paint_image.clear_mipmaps()
	paint_image.decompress()
	paint_image.convert(Image.FORMAT_RGBAF)
	
	var paint_texture_format : RDTextureFormat = RDTextureFormat.new()
	paint_texture_format.width = paint_image.get_width()
	paint_texture_format.height = paint_image.get_height()
	paint_texture_format.depth = 1
	
	paint_texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	
	paint_texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	
	paint_texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	
	var paint_texture_view : RDTextureView = RDTextureView.new()
	
	var paint_texture_rd = rd.texture_create(paint_texture_format, paint_texture_view, [paint_image.get_data()])
	
	var paint_texture_uniform = RDUniform.new()
	paint_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	paint_texture_uniform.binding = 1
	paint_texture_uniform.add_id(linear_sampler)
	paint_texture_uniform.add_id(paint_texture_rd)
	
	uniform_set = rd.uniform_set_create([texture_uniform, paint_texture_uniform], shader, 0)
	
	texture_3D_rd = Texture3DRD.new()
	texture_3D_rd.texture_rd_rid = texture_3D

func paint(in_position : Vector3, in_basis : Basis, brush_multiplier : float):
	RenderingServer.call_on_render_thread(render_paint.bind(in_position, in_basis))

func render_paint(in_position : Vector3, in_basis : Basis, brush_multiplier : float):
	map_extents = global_transform.basis.get_scale()
	
	in_position = global_basis.orthonormalized() * (in_position - global_position)
	
	var truncated_position : Vector3i = clamp(Vector3i((in_position + map_extents / 2) * Vector3(map_size) / map_extents), Vector3i(brush_radius, brush_radius, brush_radius), Vector3i(map_size.x - brush_radius, map_size.y - brush_radius, map_size.z - brush_radius))
	
	compute_size = (Vector3i(brush_radius, brush_radius, brush_radius) * 2 - Vector3i(1, 1, 1)) / 8 + Vector3i(1, 1, 1)
	
	var push_constants : PackedFloat32Array = [
		truncated_position.x,
		truncated_position.y,
		truncated_position.z,
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
		global_basis.x.x,
		global_basis.x.y,
		global_basis.x.z,
		0,
		global_basis.y.x,
		global_basis.y.y,
		global_basis.y.z,
		0,
		global_basis.z.x,
		global_basis.z.y,
		global_basis.z.z,
		0,
	]
	
	var int_push_constants : PackedInt32Array = [
		brush_size,
		0,
		0,
		0,
	]
	
	var byte_push_constants = push_constants.to_byte_array()
	
	byte_push_constants.append_array(int_push_constants.to_byte_array())
	
	compute_list = rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	rd.compute_list_set_push_constant(compute_list, byte_push_constants, byte_push_constants.size())
	
	rd.compute_list_dispatch(compute_list, compute_size.x, compute_size.y, compute_size.z)
	
	rd.compute_list_end()
	
	rd.submit()
	
	rd.sync()
