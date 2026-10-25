extends Area3D
class_name StartFinishLine

@export var spawn_markers: Array[Marker3D] = []
@export var car_scene: PackedScene = preload("res://Prefabs/car_base_a.tscn")

func spawn_racers() -> void:
	for marker in spawn_markers:
		var car = car_scene.instantiate()
		get_tree().current_scene.add_child(car)
		car.global_transform = marker.global_transform
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Optionally call spawn_racers here or trigger it from the RaceManager
	# Use call_deferred to avoid modifying scene tree during read-only phase
	call_deferred("spawn_racers")

func _on_body_entered(body: Node3D) -> void:
	# Find RaceManager in the scene
	var manager = get_tree().current_scene.find_child("RaceManager", true, false)
	if manager and manager.has_method("on_racer_entered_start_finish"):
		manager.on_racer_entered_start_finish(body)

	if body.has_method("on_start_finish_entered"):
		body.on_start_finish_entered(self)
