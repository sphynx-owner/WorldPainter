@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("WorldPainterSingleton", "res://addons/SphynxWorldPainter/Singletons/world_painter_singleton.gd")
	pass


func _exit_tree() -> void:
	remove_autoload_singleton("WorldPainterSingleton")
	pass
