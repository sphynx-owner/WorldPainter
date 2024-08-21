extends Node
class_name WorldPainter

@onready var texture_3D : Texture3D

func _ready():
	for paintable in get_tree().get_nodes_in_group("paintable_element"):
		paintable.material.set_shader_parameter("world_paint_texture", texture_3D)

func paint(position : Vector3):
	print(position)
