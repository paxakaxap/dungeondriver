extends Node
## Manages a single race session inside its parent scene.
##
## Discovers Checkpoint / StartFinishLine / FinishLine nodes and the RaceHUD by
## its parent, wires their signals, spawns racers on the start grid, tracks
## lap/checkpoint progress and runs the race clock. Prints race status to the
## console.
##
## Nothing runs until begin() is called: the venue and the track route are added
## to the tree at runtime, i.e. after this node's _ready(). The race scene
## (RaceSession) loads the level and then calls begin() with a RaceConfig.
##
## Intentionally NOT an autoload: it only exists during races, not in menus or
## the garage. Prefabs (Checkpoint, StartFinishLine, cars, RaceHUD) know nothing
## about this manager; all wiring is done here.

signal race_started
signal lap_completed(racer: Node3D, lap_number: int)
signal checkpoint_reached(racer: Node3D, checkpoint_index: int)
signal race_finished(standings: Array)
## Emitted once the whole grid exists, so the camera can be pointed at the player.
signal racers_spawned

## Rules for this race. Set by begin(); the gates and cars never read it.
var config: RaceConfig = null

var checkpoints: Array[Checkpoint] = []
var start_finish_line: StartFinishLine = null
## Sprint finish gate; null on lap tracks, where the start line doubles as finish.
var finish_line: FinishLine = null
var racers: Array[Node3D] = []
## Race HUD discovered by type in the race scene; receives bind() with this manager.
var hud: RaceHUD = null

# Race clock: advances only while the race runs. finish_time stays -1 until the
# first racer finishes, so the HUD knows when to freeze the displayed time.
var elapsed_time: float = 0.0
var race_running: bool = false
var finish_time: float = -1.0

# Racer tracking dictionary: { racer_node: { "lap": int, "next_checkpoint": int, "finished": bool } }
var racer_states: Dictionary = {}

var _racers_parent: Node3D = null
var _countdown_left: float = 0.0


func _ready() -> void:
	set_process(false) # The clock only runs between GO and the first finish.


func _process(delta: float) -> void:
	if _countdown_left > 0.0:
		_countdown_left -= delta
		if _countdown_left > 0.0:
			return
		_countdown_left = 0.0
		race_running = true
		print("RaceManager: go")
		race_started.emit()
		return
	if race_running:
		elapsed_time += delta


## Wires up an already-populated race tree and starts the countdown.
## Returns false (after push_error) when the config or the track is unusable, in
## which case nothing is spawned and the clock never starts.
func begin(race_config: RaceConfig, racers_parent: Node3D = null) -> bool:
	if race_config == null:
		push_error("RaceManager: begin() called without a RaceConfig.")
		return false
	if race_config.track_scene == null:
		push_error("RaceManager: config has no track_scene.")
		return false
	config = race_config
	for problem in config.validate():
		push_warning("RaceManager: config problem - %s" % problem)
	_racers_parent = racers_parent if racers_parent else get_parent()

	_find_race_nodes(get_parent())
	checkpoints.sort_custom(func(a, b): return a.checkpoint_index < b.checkpoint_index)
	print("RaceManager: registered %d checkpoint(s), %s" % [
		checkpoints.size(),
		start_finish_line.name if start_finish_line else "no start/finish line found"
	])
	if not _validate_track():
		return false
	_connect_race_nodes()
	if hud:
		# Same wiring rule as the gates: the manager calls into the HUD, the
		# HUD never searches the tree for the manager.
		hud.bind(self)
	# Deferred: the race scene is still adding children during its own _ready.
	spawn_racers.call_deferred()
	_start_countdown()
	return true


## Fails loudly on an authoring mistake instead of running an unwinnable race.
func _validate_track() -> bool:
	var problems := PackedStringArray()
	if start_finish_line == null:
		problems.append("no StartFinishLine in the track")
	elif start_finish_line.spawn_markers.is_empty():
		problems.append("StartFinishLine has no spawn_markers")
	if checkpoints.is_empty():
		problems.append("no Checkpoint gates in the track")
	for i in range(checkpoints.size()):
		if checkpoints[i].checkpoint_index != i:
			problems.append(
				"checkpoint order is broken at position %d (index %d); indices must be 0..%d with no gaps"
				% [i, checkpoints[i].checkpoint_index, checkpoints.size() - 1])
			break
	if _is_sprint():
		if finish_line == null:
			problems.append("sprint track has no FinishLine gate")
	elif finish_line != null:
		problems.append("lap track has a FinishLine gate; only sprint tracks use one")
	if problems.is_empty():
		return true
	for problem in problems:
		push_error("RaceManager: track is unusable - %s" % problem)
	return false


## Sprint: a one-way run, so the finish is a separate gate and laps mean nothing.
func _is_sprint() -> bool:
	return config != null and config.race_type == RaceConfig.RaceType.SPRINT


func _find_race_nodes(node: Node) -> void:
	if node is Checkpoint:
		checkpoints.append(node)
	elif node is StartFinishLine:
		start_finish_line = node
	elif node is FinishLine:
		finish_line = node
	elif node is RaceHUD:
		hud = node
	for child in node.get_children():
		_find_race_nodes(child)


func _connect_race_nodes() -> void:
	for checkpoint in checkpoints:
		checkpoint.body_entered.connect(_on_checkpoint_body_entered.bind(checkpoint))
	if start_finish_line:
		start_finish_line.body_entered.connect(_on_start_finish_body_entered)
	if finish_line:
		finish_line.body_entered.connect(_on_finish_line_body_entered)


## Cars sit on the grid during the countdown, so the clock excludes the settle time.
func _start_countdown() -> void:
	_countdown_left = maxf(config.countdown_seconds, 0.0)
	if _countdown_left > 0.0:
		print("RaceManager: countdown %.1fs" % _countdown_left)
	else:
		race_running = true
		print("RaceManager: go")
		race_started.emit()
	set_process(true)


## Fills the accepted grid slots: player in slot 0, opponents in the rest.
func spawn_racers() -> void:
	if not start_finish_line or config == null:
		push_warning("RaceManager: cannot spawn racers (no start line or no config).")
		return
	var parent: Node3D = _racers_parent if _racers_parent else start_finish_line.get_parent()
	var slots := start_finish_line.spawn_markers.size()
	var wanted := config.racer_count()
	if wanted > slots:
		push_warning("RaceManager: %d racer(s) requested but the grid has %d slot(s); spawning %d."
			% [wanted, slots, slots])
	for i in range(mini(wanted, slots)):
		var marker: Marker3D = start_finish_line.spawn_markers[i]
		var car_scene: PackedScene = config.player_car_scene if i == 0 else config.opponent_car_scene
		if car_scene == null:
			car_scene = config.player_car_scene
		if car_scene == null:
			push_warning("RaceManager: no car scene for grid slot %d." % i)
			continue
		var car: Node3D = car_scene.instantiate()
		car.name = "PlayerCar" if i == 0 else "OpponentCar%d" % i
		if i == 0:
			# Before entering the tree, so car_drive._ready() knows to keep its HUD.
			car.add_to_group("player_car")
		parent.add_child(car)
		car.global_transform = marker.global_transform
		register_racer(car)
	print("RaceManager: spawned %d racer(s)" % racers.size())
	racers_spawned.emit()


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
	# In a sprint the start line only holds the grid: crossing it means nothing.
	if _is_sprint():
		return
	if not racer_states.has(body):
		return
	var state: Dictionary = racer_states[body]
	if state["finished"]:
		return
	if checkpoints.size() > 0 and state["next_checkpoint"] < checkpoints.size():
		push_warning("Racer %s crossed start/finish but missed %d checkpoint(s); lap not counted."
			% [body.name, checkpoints.size() - state["next_checkpoint"]])
		return
	# Mutate the state completely, then notify: listeners (HUD, standings) read
	# racer_states during the signal, so lap/checkpoint must already be updated.
	var completed_lap: int = state["lap"]
	state["next_checkpoint"] = 0
	state["lap"] = completed_lap + 1
	print("Racer %s: lap %d completed" % [body.name, completed_lap])
	lap_completed.emit(body, completed_lap)
	if state["lap"] > _total_laps():
		_finish_racer(body)


## Sprint finish. Every checkpoint must be behind the racer, so corners cannot be cut.
func _on_finish_line_body_entered(body: Node3D) -> void:
	if not racer_states.has(body):
		return
	var state: Dictionary = racer_states[body]
	if state["finished"]:
		return
	var missing := checkpoints.size() - int(state["next_checkpoint"])
	if missing > 0:
		push_warning("Racer %s crossed the finish line but missed %d checkpoint(s); not finished."
			% [body.name, missing])
		return
	print("Racer %s: finish line crossed with %d/%d checkpoints" % [
		body.name, int(state["next_checkpoint"]), checkpoints.size()])
	_finish_racer(body)


## Shared finish path: freezes the clock on the first car home and ranks everyone.
func _finish_racer(body: Node3D) -> void:
	var state: Dictionary = racer_states[body]
	state["finished"] = true
	if race_running:
		race_running = false
		finish_time = elapsed_time
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


## Laps for this race; 0 when no config was applied yet.
func _total_laps() -> int:
	return config.total_laps if config else 0


## Player racer: the car in group "player_car", falling back to the first racer.
func get_player() -> Node3D:
	for racer in racers:
		if is_instance_valid(racer) and racer.is_in_group("player_car"):
			return racer
	return racers[0] if not racers.is_empty() else null


## Player-facing progress snapshot for the HUD. `lap` is 1-based and clamped to
## total_laps; `checkpoints_done` is the per-lap count (resets every lap) and, in a
## sprint, the whole-race count, since `is_sprint` races never reset it.
func get_player_progress() -> Dictionary:
	var player := get_player()
	var state: Dictionary = racer_states.get(player, {})
	return {
		"is_sprint": _is_sprint(),
		"lap": mini(int(state.get("lap", 1)), _total_laps()),
		"total_laps": _total_laps(),
		"checkpoints_done": int(state.get("next_checkpoint", 0)),
		"checkpoints_total": checkpoints.size(),
		"finished": bool(state.get("finished", false)),
	}
