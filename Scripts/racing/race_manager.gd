extends Node

signal race_started
signal lap_completed(racer: Node3D, lap_number: int)
signal checkpoint_reached(racer: Node3D, checkpoint_index: int)
signal race_finished(standings: Array)

@export var total_laps: int = 3

var checkpoints: Array[Area3D] = []
var start_finish_line: Area3D = null
var racers: Array[Node3D] = []

# Racer tracking dictionary: { racer_node: { "lap": int, "next_checkpoint": int } }
var racer_states: Dictionary = {}

func _ready() -> void:
	# Auto-discover race components within the scene tree
	var root = get_tree().current_scene
	_find_race_nodes(root)

func _find_race_nodes(node: Node) -> void:
	if node is Checkpoint:
		register_checkpoint(node)
	elif node is StartFinishLine:
		register_start_finish(node)
		
	for child in node.get_children():
		_find_race_nodes(child)

func register_racer(racer: Node3D) -> void:
	if not racers.has(racer):
		racers.append(racer)
		racer_states[racer] = {
			"lap": 1,
			"next_checkpoint": 0,
			"finished": false
		}

func unregister_racer(racer: Node3D) -> void:
	racers.erase(racer)
	racer_states.erase(racer)

func register_checkpoint(checkpoint: Area3D) -> void:
	if not checkpoints.has(checkpoint):
		checkpoints.append(checkpoint)
		# Sort checkpoints by index if desired

func register_start_finish(sfl: Area3D) -> void:
	start_finish_line = sfl

func on_racer_entered_checkpoint(racer: Node3D, checkpoint: Area3D) -> void:
	if not racer_states.has(racer):
		register_racer(racer)
	
	var state = racer_states[racer]
	if state["finished"]:
		return
		
	var cp_index = checkpoint.get("checkpoint_index") if checkpoint.has_method("get") or "checkpoint_index" in checkpoint else 0
	if cp_index == state["next_checkpoint"]:
		state["next_checkpoint"] += 1
		emit_signal("checkpoint_reached", racer, cp_index)

func on_racer_entered_start_finish(racer: Node3D) -> void:
	if not racer_states.has(racer):
		register_racer(racer)
		
	var state = racer_states[racer]
	if state["finished"]:
		return
		
	# Check if all checkpoints for the current lap have been hit
	if state["next_checkpoint"] >= checkpoints.size() and checkpoints.size() > 0:
		state["next_checkpoint"] = 0
		state["lap"] += 1
		emit_signal("lap_completed", racer, state["lap"] - 1)
		
		if state["lap"] > total_laps:
			state["finished"] = true
			emit_signal("race_finished", racers)
