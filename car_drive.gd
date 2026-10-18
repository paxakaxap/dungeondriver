extends VehicleBody3D

@export var max_engine_force: float = 1200.0
@export var max_steering_angle: float = 0.6
@export var brake_force: float = 15.0
var accel_input

func _physics_process(delta: float) -> void:
	# Steering (Left key turns left / positive angle, Right key turns right / negative angle)
	var steering_input = Input.get_axis("ui_right", "ui_left")
	steering = move_toward(steering, steering_input * max_steering_angle, delta * 5.0)

	# Acceleration / Engine force
	# Godot 3D forward direction is -Z. In VehicleBody3D, positive engine_force accelerates forward (-Z).
	# ui_up = +1.0 for forward throttle, ui_down = -1.0 for reverse/brake.
	var accel_input = Input.get_axis("ui_down", "ui_up")
	engine_force = accel_input * max_engine_force
	if Input.is_anything_pressed():
		print(accel_input)

	# Braking
	if Input.is_action_pressed("ui_select"):
		brake = brake_force
	else:
		brake = 0.0
