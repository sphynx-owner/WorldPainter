extends Node

var collision_paint_meshes : Dictionary

func _ready():
	pass

func subscribe_world_painter(world_painter : WorldPainter):
	for collision in world_painter.relevant_collisions:
		if !collision_paint_meshes.has(collision):
			collision_paint_meshes[collision] = []
		collision_paint_meshes[collision].append(world_painter)

func paint(collision : CollisionObject3D, brush : WorldBrush, in_position : Vector3, in_basis : Basis, brush_multiplier : float):
	if !collision_paint_meshes.has(collision):
		return
	
	for world_painter in collision_paint_meshes[collision]:
		(world_painter as WorldPainter).paint(brush, in_position, in_basis, brush_multiplier)
