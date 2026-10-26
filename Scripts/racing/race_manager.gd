extends Node
## Manages a single race session inside its parent scene.
##
## Discovers all Checkpoint and StartFinishLine nodes under its parent, wires
## up their collision signals, spawns racers on the start grid and tracks
## lap/checkpoint progress. Prints race status to the console.
##
## Attach to a RaceManager node in a race scene (e.g. race_template.tscn).
## Intentionally NOT an autoload: it only exists during races, not in menus
## or the garage. Prefabs (Checkpoint, StartFinishLine, cars) know nothing
## about this manager; all wiring is done here.

signal race_started
signal lap_completed(racer: Node3D, lap_number: int)
signal checkpoint_reached(racer: Node3D, checkpoint_index: int)
signal race_finished(standings: Array)

@export var total_laps: int = 3
@export var car_scene: PackedScene = preload("res://Prefabs/car_base_a.tscn")

var checkpoints: Array[Checkpoint] = []
var start_finish_line: StartFinishLine = null
var racers: Array[Node3D] = []

# Racer tracking dictionary: { racer_node: { "lap": int, "next_checkpoint": int, "finished": bool } }
var racer_states: Dictionary = {}


func _ready() -> void:
	# Discover race prefabs in the parent scene's subtree. The whole subtree
	# is already in the tree before any _ready runs, so this is safe even
	# though the checkpoints' own _ready may not have run yet.
	var race_scope := get_parent() if get_parent() else get_tree().current_scene
	_find_race_nodes(race_scope)
	checkpoints.sort_custom(func(a, b): return a.checkpoint_index < b.checkpoint_index)
	print("RaceManager: registered %d checkpoint(s), %s" % [
		checkpoints.size(),
		start_finish_line.name if start_finish_line else "no start/finish line found"
	])
	_connect_race_nodes()
	if car_scene:
		# Deferred: the scene root is still setting up children during _ready,
		# so add_child() must wait until the current setup phase finishes.
		spawn_racers.call_deferred()
	_race_start()


func _find_race_nodes(node: Node) -> void:
	if node is Checkpoint:
		checkpoints.append(node)
	elif node is StartFinishLine:
		start_finish_line = node
	for child in node.get_children():
		_find_race_nodes(child)


func _connect_race_nodes() -> void:
	for checkpoint in checkpoints:
		checkpoint.body_entered.connect(_on_checkpoint_body_entered.bind(checkpoint))
	if start_finish_line:
		start_finish_line.body_entered.connect(_on_start_finish_body_entered)


func _race_start() -> void:
	print("Race started")
	race_started.emit()


func spawn_racers() -> void:
	if not start_finish_line:
		push_warning("RaceManager: cannot spawn racers, no StartFinishLine found.")
		return
	var scope := start_finish_line.get_parent()
	for i in range(start_finish_line.spawn_markers.size()):
		var marker := start_finish_line.spawn_markers[i]
		var car := car_scene.instantiate()
		scope.add_child(car)
		car.global_transform = marker.global_transform
		register_racer(car)
		if i == 0:
			car.add_to_group("player_car")
	print("RaceManager: spawned %d racer(s)" % racers.size())


func register_racer(racer: Node3D) -> void:
	if racers.has(racer):
		return
	racers.append(racer)
	racer_states[racer] = {
		"lap": 1,
		"next_checkpoint": 0,
		"finished": false,
	}


func unregister_racer(racer: Node3D) -> void:
	racers.erase(racer)
	racer_states.erase(racer)


func _on_checkpoint_body_entered(body: Node3D, checkpoint: Checkpoint) -> void:
	if not racer_states.has(body):
		return
	var state: Dictionary = racer_states[body]
	if state["finished"]:
		return
	if checkpoint.checkpoint_index != state["next_checkpoint"]:
		return # Wrong checkpoint or out of order; ignore.
	state["next_checkpoint"] += 1
	print("Racer %s: checkpoint %d passed" % [body.name, checkpoint.checkpoint_index])
	checkpoint_reached.emit(body, checkpoint.checkpoint_index)


func _on_start_finish_body_entered(body: Node3D) -> void:
	if not racer_states.has(body):
		return
	var state: Dictionary = racer_states[body]
	if state["finished"]:
		return
	if checkpoints.size() > 0 and state["next_checkpoint"] < checkpoints.size():
		push_warning("Racer %s crossed start/finish but missed %d checkpoint(s); lap not counted."
			% [body.name, checkpoints.size() - state["next_checkpoint"]])
		return
	state["next_checkpoint"] = 0
	print("Racer %s: lap %d completed" % [body.name, state["lap"]])
	lap_completed.emit(body, state["lap"])
	state["lap"] += 1
	if state["lap"] > total_laps:
		state["finished"] = true
		print("Race finished - winner: %s" % body.name)
		race_finished.emit(_standings())


func _compare_racers(a: Node3D, b: Node3D) -> bool:
	var sa: Dictionary = racer_states[a]
	var sb: Dictionary = racer_states[b]
	if sa["finished"] != sb["finished"]:
		return sa["finished"]
	if sa["lap"] != sb["lap"]:
		return sa["lap"] > sb["lap"]
	return sa["next_checkpoint"] > sb["next_checkpoint"]


func _standings() -> Array:
	var order := racers.duplicate()
	order.sort_custom(_compare_racers)
	return order
