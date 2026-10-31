extends VehicleBody3D

@export var max_engine_force: float = 1200.0
@export var max_steering_angle: float = 0.6
@export var brake_force: float = 15.0
@export var speed_label: Label

# Input variables that can be driven by Player or AI controller
var steer_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0

## True for the car the player drives. Only that car reads the keyboard; any other
## car keeps its steer/throttle/brake inputs, so an AI controller can drive it.
var is_player: bool = false

func _ready() -> void:
	# RaceManager adds the player to "player_car" before the car enters the tree, so
	# the group is already set here. Opponents share this prefab but stay parked:
	# nothing writes their inputs until an AI controller does.
	is_player = is_in_group("player_car")
	if not is_player:
		_remove_speedometer()


## Opponents inherit the whole player prefab, car HUD included. Their copy of it is
## deleted rather than hidden: several copies anchored to the same screen corner
## stack on top of each other, and hiding proved unreliable.
func _remove_speedometer() -> void:
	var speedometer := get_node_or_null("Speedometer")
	if speedometer == null:
		return
	speed_label = null # Stop the per-frame text updates before the label goes away.
	speedometer.queue_free()
	print("CarDrive: %s is an opponent, speedometer removed" % name)

func _physics_process(delta: float) -> void:
	# 1. Gather inputs. Only the player reads the keyboard; an AI controller writes
	# steer_input/throttle_input/brake_input on every other car.
	if is_player:
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
