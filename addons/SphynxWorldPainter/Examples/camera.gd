extends Camera3D

@export var draw_timer : Timer

@export var brush : WorldBrush

var can_draw : bool = true

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	draw_timer.timeout.connect(on_draw_timer_timeout)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		global_rotation += Vector3(rad_to_deg(-event.relative.y), rad_to_deg(-event.relative.x), 0) / 10000
		draw_process()
	
	if Input.is_action_just_pressed("LeftClick"):
		brush.paint(0.5)
	
	if Input.is_action_just_pressed("RightClick"):
		brush.erase()


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
		brush.paint(0.5)
	
	if Input.is_action_pressed("RightClick"):
		brush.erase()
