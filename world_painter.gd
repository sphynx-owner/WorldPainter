extends Node
class_name WorldPainter

@export var map_size : Vector3i = Vector3i(100, 100, 100)

@export var map_extents : Vector3 = Vector3(50, 50, 50)

@export var brush_radius : float = 5

var texture_3D_rd : Texture3DRD 

var rd : RenderingDevice = null
var shader_file : RDShaderFile
var shader_bytecode
var shader
var pipeline
func _ready():
	RenderingServer.call_on_render_thread(initialize_compute)
	for paintable in get_tree().get_nodes_in_group("paintable_element"):
		paintable.get_surface_override_material(0).set_shader_parameter("map_size", map_size)
		paintable.get_surface_override_material(0).set_shader_parameter("map_extents", map_extents)
		paintable.get_surface_override_material(0).set_shader_parameter.call_deferred("world_paint_texture", texture_3D_rd)

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
	
	texture_3D_format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	
	texture_3D_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	
	var texture3D_view = RDTextureView.new()
	
	var texture_3D : RID
	
	texture_3D = rd.texture_create(texture_3D_format, texture3D_view, [])
	
	var texture_uniform = RDUniform.new()
	
	texture_uniform.binding = 0
	
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	
	texture_uniform.add_id(texture_3D)
	
	var uniform_set = rd.uniform_set_create([texture_uniform], shader, 0)
	
	# Start compute list to start recording our compute commands
	var compute_list = rd.compute_list_begin()
	# Bind the pipeline, this tells the GPU what shader to use
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	# Binds the uniform set with the data we want to give our shader
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# Dispatch 1x1x1 (XxYxZ) work groups
	
	var position : Vector3
	
	var push_constants : PackedFloat32Array = [
		position.x,
		position.y,
		position.z,
		0,
	]
	
	var byte_push_constants = push_constants.to_byte_array()
	
	var size_x = (map_size.x - 1) / 8 + 1
	var size_y = (map_size.y - 1) / 8 + 1
	var size_z = (map_size.z - 1) / 8 + 1
	
	rd.compute_list_set_push_constant(compute_list, byte_push_constants, byte_push_constants.size())
	
	rd.compute_list_dispatch(compute_list, size_x, size_y, size_z)
	#rd.compute_list_add_barrier(compute_list)
	# Tell the GPU we are done with this compute task
	rd.compute_list_end()
	# Force the GPU to start our commands
	rd.submit()
	# Force the CPU to wait for the GPU to finish with the recorded commands
	rd.sync()
	
	texture_3D_rd = Texture3DRD.new()
	texture_3D_rd.texture_rd_rid = texture_3D

func paint(in_position : Vector3):
	print("in position: ", in_position)
	var position : Vector3i
	var truncated_position : Vector3i = clamp(Vector3i((in_position + map_extents / 2) * Vector3(map_size) / map_extents), Vector3i(brush_radius, brush_radius, brush_radius), Vector3i(map_size.x - brush_radius, map_size.y - brush_radius, map_size.z - brush_radius))
	print("truncated position: ", truncated_position)
	

func erase(in_position : Vector3):
	print("in position: ", in_position)
	var position : Vector3i
	var truncated_position : Vector3i = clamp(Vector3i((in_position + map_extents / 2) * Vector3(map_size) / map_extents), Vector3i(brush_radius, brush_radius, brush_radius), Vector3i(map_size.x - brush_radius, map_size.y - brush_radius, map_size.x - brush_radius))
	print("truncated position: ", truncated_position)
	
