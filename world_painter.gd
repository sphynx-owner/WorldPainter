extends Node
class_name WorldPainter

@export var map_size : Vector3i = Vector3i(800, 800, 800)

@export var map_extents : Vector3 = Vector3(50, 50, 50)

@export var brush_radius : float = 50

@export var paint_texture : Texture2D

var texture_3D_rd : Texture3DRD 

var texture_3D : RID

var texture_uniform : RDUniform

var texture3D_view : RDTextureView

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
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	
	var linear_sampler : RID = rd.sampler_create(sampler_state)
	
	var paint_image : Image = Image.new()
	paint_image.copy_from(paint_texture.get_image())
	paint_image.decompress()
	paint_image.convert(Image.FORMAT_RGBAF)
	paint_image.clear_mipmaps()
	
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
	
	compute_size = (Vector3i(brush_radius, brush_radius, brush_radius) * 2 - Vector3i(1, 1, 1)) / 8 + Vector3i(1, 1, 1)
	
	texture_3D_rd = Texture3DRD.new()
	texture_3D_rd.texture_rd_rid = texture_3D

func paint(in_position : Vector3, in_normal : Vector3):
	RenderingServer.call_on_render_thread(render_paint.bind(in_position, in_normal))

func erase(in_position : Vector3, in_normal : Vector3):
	RenderingServer.call_on_render_thread(render_erase.bind(in_position, in_normal))

func render_paint(in_position : Vector3, in_normal : Vector3):
	# Start compute list to start recording our compute commands
	compute_list = rd.compute_list_begin()
	# Bind the pipeline, this tells the GPU what shader to use
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	# Binds the uniform set with the data we want to give our shader
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# Dispatch 1x1x1 (XxYxZ) work groups
	
	var truncated_position : Vector3i = clamp(Vector3i((in_position + map_extents / 2) * Vector3(map_size) / map_extents), Vector3i(brush_radius, brush_radius, brush_radius), Vector3i(map_size.x - brush_radius, map_size.y - brush_radius, map_size.z - brush_radius))
	
	var push_constants : PackedFloat32Array = [
		truncated_position.x,
		truncated_position.y,
		truncated_position.z,
		1,
		in_normal.x,
		in_normal.y,
		in_normal.z,
		0,
	]
	
	var int_push_constants : PackedInt32Array = [
		brush_radius,
		0,
		0,
		0,
	]
	
	var byte_push_constants = push_constants.to_byte_array()
	
	byte_push_constants.append_array(int_push_constants.to_byte_array())
	
	rd.compute_list_set_push_constant(compute_list, byte_push_constants, byte_push_constants.size())
	
	rd.compute_list_dispatch(compute_list, compute_size.x, compute_size.y, compute_size.z)
	#rd.compute_list_add_barrier(compute_list)
	# Tell the GPU we are done with this compute task
	rd.compute_list_end()
	# Force the GPU to start our commands
	rd.submit()
	# Force the CPU to wait for the GPU to finish with the recorded commands
	rd.sync()


func render_erase(in_position : Vector3, in_normal : Vector3):
	# Start compute list to start recording our compute commands
	compute_list = rd.compute_list_begin()
	# Bind the pipeline, this tells the GPU what shader to use
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	# Binds the uniform set with the data we want to give our shader
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# Dispatch 1x1x1 (XxYxZ) work groups
	
	var truncated_position : Vector3i = clamp(Vector3i((in_position + map_extents / 2) * Vector3(map_size) / map_extents), Vector3i(brush_radius, brush_radius, brush_radius), Vector3i(map_size.x - brush_radius, map_size.y - brush_radius, map_size.z - brush_radius))
	
	var push_constants : PackedFloat32Array = [
		truncated_position.x,
		truncated_position.y,
		truncated_position.z,
		-1,
		in_normal.x,
		in_normal.y,
		in_normal.z,
		0,
	]
	
	var int_push_constants : PackedInt32Array = [
		brush_radius,
		0,
		0,
		0,
	]
	
	var byte_push_constants = push_constants.to_byte_array()
	
	byte_push_constants.append_array(int_push_constants.to_byte_array())
	
	rd.compute_list_set_push_constant(compute_list, byte_push_constants, byte_push_constants.size())
	
	rd.compute_list_dispatch(compute_list, compute_size.x, compute_size.y, compute_size.z)
	#rd.compute_list_add_barrier(compute_list)
	# Tell the GPU we are done with this compute task
	rd.compute_list_end()
	# Force the GPU to start our commands
	rd.submit()
	# Force the CPU to wait for the GPU to finish with the recorded commands
	rd.sync()
