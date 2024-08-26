extends Node
class_name WorldPainter

@export var map_size : Vector3i = Vector3i(100, 100, 100)

@export var map_extents : Vector3 = Vector3(50, 50, 50)

@export var brush_radius : float = 5

@onready var images : Array[Image] = []

@onready var image_3D : ImageTexture3D = ImageTexture3D.new()

@onready var texture_3D : Texture3D = Texture3D.new()

var image_3D_tex : RID 
@onready var image_uniform = RDUniform.new()
var rd : RenderingDevice = null
var shader_file : RDShaderFile
var shader_bytecode
var shader
var pipeline
func _ready():
	for paintable in get_tree().get_nodes_in_group("paintable_element"):
		paintable.get_surface_override_material(0).set_shader_parameter("world_paint_texture", image_3D)
		paintable.get_surface_override_material(0).set_shader_parameter("map_size", map_size)
		paintable.get_surface_override_material(0).set_shader_parameter("map_extents", map_extents)
	
	for index in map_size.z:
		images.append(Image.create(map_size.x, map_size.y, false, Image.FORMAT_RF))
	
	image_3D.create(Image.FORMAT_RF, map_size.x, map_size.y, map_size.z, false, images)
	
	# We will be using our own RenderingDevice to handle the compute commands
	rd = RenderingServer.create_local_rendering_device()
	
	# Create shader and pipeline
	shader_file = load("res://minimal_compute.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)
	
	var texture3D_format : RDTextureFormat = RDTextureFormat.new()
	texture3D_format.width = map_size.x
	texture3D_format.height = map_size.y
	texture3D_format.depth = map_size.z
	
	texture3D_format.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	
	texture3D_format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	
	texture3D_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var texture3D_view = RDTextureView.new()
	
	var data : PackedByteArray = []
	
	for image in image_3D.get_data():
		data.append_array(image.get_data())
	
	image_3D_tex = rd.texture_create(texture3D_format, texture3D_view, [data])
	
	image_uniform.binding = 0
	
	image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	
	image_uniform.add_id(image_3D_tex)
	
	
	
	var uniform_set = rd.uniform_set_create([image_uniform], shader, 0)
	
	var texture_3D_rd = Texture3DRD.new()
	
	texture_3D_rd = texture_3D.get_rid()
	
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

func paint(in_position : Vector3):
	print("in position: ", in_position)
	var position : Vector3i
	var truncated_position : Vector3i = clamp(Vector3i((in_position + map_extents / 2) * Vector3(map_size) / map_extents), Vector3i(brush_radius, brush_radius, brush_radius), Vector3i(map_size.x - brush_radius, map_size.y - brush_radius, map_size.z - brush_radius))
	print("truncated position: ", truncated_position)
	for i in brush_radius * 2:
		for j in brush_radius * 2:
			for k in brush_radius * 2:
				var offset = Vector3i(i - brush_radius, j - brush_radius, k - brush_radius)
				if offset.length() > brush_radius:
					continue
				position = truncated_position + offset
				images[position.z].set_pixelv(Vector2i(position.x, position.y), Color(1, 1, 1, 1))
	
	image_3D.update(images)

func erase(in_position : Vector3):
	print("in position: ", in_position)
	var position : Vector3i
	var truncated_position : Vector3i = clamp(Vector3i((in_position + map_extents / 2) * Vector3(map_size) / map_extents), Vector3i(brush_radius, brush_radius, brush_radius), Vector3i(map_size.x - brush_radius, map_size.y - brush_radius, map_size.x - brush_radius))
	print("truncated position: ", truncated_position)
	for i in brush_radius * 2:
		for j in brush_radius * 2:
			for k in brush_radius * 2:
				position = truncated_position + Vector3i(i - brush_radius, j - brush_radius, k - brush_radius)
				images[position.z].set_pixelv(Vector2i(position.x, position.y), Color(0, 0, 0, 0))
	
	image_3D.update(images)
