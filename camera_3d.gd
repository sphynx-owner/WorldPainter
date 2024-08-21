extends Camera3D

@export var world_painter : WorldPainter

@export var raycast : RayCast3D 

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		global_rotation += Vector3(rad_to_deg(-event.relative.y), rad_to_deg(-event.relative.x), 0) / 10000
	
	if Input.is_action_just_pressed("LeftClick"):
		world_painter.paint(raycast.get_collision_point())

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	var movement_input : Vector2 = Input.get_vector("A", "D", "W", "S")
	
	var movement_3D_input : Vector3 = Vector3(movement_input.x, Input.get_vector("Q", "E", "A", "D").x, movement_input.y) * delta * 10;
	
	global_position += global_basis * movement_3D_input
