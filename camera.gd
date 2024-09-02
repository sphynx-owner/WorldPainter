extends Camera3D

@export var world_painter : WorldPainter

@export var raycast : RayCast3D 

@export var draw_timer : Timer

var can_draw : bool = true


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	draw_timer.timeout.connect(on_draw_timer_timeout)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		global_rotation += Vector3(rad_to_deg(-event.relative.y), rad_to_deg(-event.relative.x), 0) / 10000
		#draw_process()
	
	if Input.is_action_just_pressed("LeftClick"):
		world_painter.paint(raycast.get_collision_point(), normal_to_basis(raycast.get_collision_normal()), 1)
	
	if Input.is_action_just_pressed("RightClick"):
		world_painter.paint(raycast.get_collision_point(), normal_to_basis(raycast.get_collision_normal()), -1)


func _process(delta: float) -> void:
	var movement_input : Vector2 = Input.get_vector("A", "D", "W", "S")
	
	var movement_3D_input : Vector3 = Vector3(movement_input.x, Input.get_vector("Q", "E", "A", "D").x, movement_input.y) * delta * 10;
	
	global_position += global_basis * movement_3D_input
	
	draw_process()


func on_draw_timer_timeout():
	can_draw = true


func draw_process():
	if !can_draw:
		return
	
	can_draw = false
	draw_timer.start()
	
	if Input.is_action_pressed("LeftClick"):
		world_painter.paint(raycast.get_collision_point(), normal_to_basis(raycast.get_collision_normal()), 1)
	
	if Input.is_action_pressed("RightClick"):
		world_painter.paint(raycast.get_collision_point(), normal_to_basis(raycast.get_collision_normal()), -1)


func normal_to_basis(normal : Vector3) -> Basis:
	normal = normal.normalized()
	var result_basis : Basis
	var z : Vector3 = normal
	var y : Vector3 = Vector3(0, 1, 0) if !normal.is_equal_approx(Vector3(0, 1, 0)) else Vector3(0, 0, 1)
	var x : Vector3 = z.cross(y) if !normal.is_equal_approx(Vector3(0, 1, 0)) else Vector3(1, 0, 0)
	y = z.cross(x) if !normal.is_equal_approx(Vector3(0, 1, 0)) else y
	result_basis = Basis(x.normalized(), y.normalized(), z.normalized())
	return result_basis
