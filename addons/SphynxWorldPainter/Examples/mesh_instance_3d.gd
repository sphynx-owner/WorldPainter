extends MeshInstance3D

func _process(delta: float) -> void:
	rotation.y += delta * 3
