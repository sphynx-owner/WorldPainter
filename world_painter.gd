extends Node
class_name WorldPainter

@export var map_size : Vector3i = Vector3i(100, 100, 100)

@export var map_extents : Vector3 = Vector3(50, 50, 50)

@export var brush_radius : float = 5

@onready var images : Array[Image] = []

@onready var image_3D : ImageTexture3D = ImageTexture3D.new()

func _ready():
	for paintable in get_tree().get_nodes_in_group("paintable_element"):
		paintable.get_surface_override_material(0).set_shader_parameter("world_paint_texture", image_3D)
		paintable.get_surface_override_material(0).set_shader_parameter("map_size", map_size)
		paintable.get_surface_override_material(0).set_shader_parameter("map_extents", map_extents)
	
	for index in map_size.z:
		images.append(Image.create(map_size.x, map_size.y, false, Image.FORMAT_RF))
	
	image_3D.create(Image.FORMAT_RF, map_size.x, map_size.y, map_size.z, false, images)

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
