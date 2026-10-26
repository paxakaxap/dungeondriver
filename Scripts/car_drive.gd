extends VehicleBody3D

@export var max_engine_force: float = 1200.0
@export var max_steering_angle: float = 0.6
@export var brake_force: float = 15.0
@export var speed_label: Label

# Input variables that can be driven by Player or AI controller
var steer_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0

func _physics_process(delta: float) -> void:
	# 1. Gather inputs (Currently Player; can be overridden by an AI controller later)
	_gather_player_input()

	# 2. Apply vehicle control values
	steering = move_toward(steering, steer_input * max_steering_angle, delta * 5.0)
	engine_force = throttle_input * max_engine_force
	brake = brake_input

	# Speedometer UI update
	var speed_ms = linear_velocity.length()
	var speed_kmh = int(speed_ms * 3.6)
	if speed_label:
		speed_label.text = str(speed_kmh) + " km/h"

func _gather_player_input() -> void:
	steer_input = Input.get_axis("ui_right", "ui_left")
	throttle_input = Input.get_axis("ui_down", "ui_up")
	
	if Input.is_action_pressed("ui_select"):
		brake_input = brake_force
	else:
		brake_input = 0.0
