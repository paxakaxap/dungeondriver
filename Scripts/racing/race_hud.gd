extends CanvasLayer
class_name RaceHUD
## Race HUD overlay: race clock, lap counter, checkpoint counter, finish banner.
##
## Purely presentational - it stores no race state. RaceManager discovers it by
## type inside the race scene and calls bind() with itself, so the HUD never
## searches the tree for its manager (same rule as the race gates).
##
## Attach to a RaceHUD node in a race scene (e.g. race_template.tscn).

## Minutes' seconds" milliseconds, e.g. 01' 23" 456.
const TIME_FORMAT := "%02d' %02d\" %03d"

# Untyped on purpose: RaceManager has no class_name, and typing this reference
# would make race_hud.gd and race_manager.gd reference each other's types.
var _manager = null

var _time_label: Label = null
var _lap_label: Label = null
var _checkpoint_label: Label = null
var _finish_label: Label = null


func _ready() -> void:
	# bind() may already have run: RaceManager is an earlier sibling, so its
	# _ready() (and therefore bind()) runs before this one. Only stay idle when
	# no manager has bound itself yet.
	if not _manager:
		set_process(false)


## Called once by RaceManager right after it discovered this HUD.
func bind(manager: Node) -> void:
	_manager = manager
	# Child nodes exist as soon as the HUD scene is in the tree, so get_node()
	# is safe here even though this runs before this node's own _ready().
	_time_label = get_node_or_null("Root/Margin/TopRow/TimeColumn/TimeLabel")
	_lap_label = get_node_or_null("Root/Margin/TopRow/StatusColumn/LapLabel")
	_checkpoint_label = get_node_or_null("Root/Margin/TopRow/StatusColumn/CheckpointLabel")
	_finish_label = get_node_or_null("Root/Center/FinishLabel")
	for label in [_time_label, _lap_label, _checkpoint_label, _finish_label]:
		if label == null:
			push_warning("RaceHUD: a HUD label node is missing; check the HUD scene layout.")
			break
	if _finish_label:
		_finish_label.visible = false
	print("RaceHUD: bound to %s" % manager.name)
	manager.checkpoint_reached.connect(_on_checkpoint_reached)
	manager.lap_completed.connect(_on_lap_completed)
	manager.race_finished.connect(_on_race_finished)
	_refresh_progress()
	_refresh_clock()
	set_process(true)


func _process(_delta: float) -> void:
	_refresh_clock()


func _refresh_clock() -> void:
	if not _time_label or not _manager:
		return
	var seconds: float = _manager.elapsed_time
	if not _manager.race_running and _manager.finish_time >= 0.0:
		seconds = _manager.finish_time
		set_process(false) # Clock frozen at the finish time.
	_set_label(_time_label, TIME_FORMAT % _split_time(seconds))


## Splits seconds into [minutes, seconds, milliseconds] for TIME_FORMAT.
func _split_time(seconds: float) -> Array:
	var total_ms := int(round(seconds * 1000.0))
	return [total_ms / 60000, (total_ms / 1000) % 60, total_ms % 1000]


func _refresh_progress() -> void:
	if not _manager:
		return
	var progress: Dictionary = _manager.get_player_progress()
	var sprint := bool(progress.get("is_sprint", false))
	if _lap_label:
		# A sprint is point-to-point, so there is no lap to count.
		_lap_label.visible = not sprint
		_set_label(_lap_label, "Lap %d/%d" % [progress["lap"], progress["total_laps"]])
	if _checkpoint_label:
		_set_label(_checkpoint_label, "Checkpoints: %d/%d" % [
			progress["checkpoints_done"], progress["checkpoints_total"]
		])


## Assigns text only when it changed, to avoid needless relayouts every frame.
func _set_label(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _on_checkpoint_reached(racer: Node3D, _checkpoint_index: int) -> void:
	if _manager and racer == _manager.get_player():
		_refresh_progress()


func _on_lap_completed(racer: Node3D, _lap_number: int) -> void:
	if _manager and racer == _manager.get_player():
		_refresh_progress()


func _on_race_finished(_standings: Array) -> void:
	_refresh_progress()
	if _finish_label:
		_finish_label.visible = true
	_refresh_clock()
	print("RaceHUD: finish banner shown, final time %s" % (_time_label.text if _time_label else "?"))
