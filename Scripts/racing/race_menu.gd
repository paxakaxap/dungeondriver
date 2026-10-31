extends Control
## Quick-race menu: pick venue, track, race type, laps and opponents, then start.
##
## Staygap: the menu is the current scene and only hides while a race runs. The race
## scene is added as a sibling of the viewport root, so starting another race needs
## no scene reload and no state handover. It returns here when the race closes.
##
## The track list is hand-written in _tracks (see ai_context §9). When the career
## calendar exists it moves into a data resource and the menu only picks from it.

const RACE_SCENE := preload("res://Scenes/race_session.tscn")
const VENUE_TEST_FLOOR := preload("res://Scenes/Venues/test_floor.tscn")
const TRACK_LOOP_A := preload("res://Scenes/Tracks/test_floor_a.tscn")
const TRACK_LOOP_B := preload("res://Scenes/Tracks/test_floor_b.tscn")
const TRACK_SPRINT := preload("res://Scenes/Tracks/test_floor_sprint.tscn")

## Race types offered for now; SPRINT waits for its own finish gate.
## Race types offered for now.
const RACE_TYPES: Array = [
	RaceConfig.RaceType.CIRCUIT,
	RaceConfig.RaceType.SPRINT,
	RaceConfig.RaceType.TIME_ATTACK,
]

## Hand-written track list: venue display name + scenery scene, track display name
## + route scene. Two tracks share one venue scene.
## Hand-written track list: venue display name + scenery scene, track display name
## + route scene. `lap_race` gates which race types may use the route: lap routes
## loop back to the start line, sprint routes end at a FinishLine gate.
var _tracks: Array[Dictionary] = [
	{
		"venue": "Test Floor",
		"venue_scene": VENUE_TEST_FLOOR,
		"track": "Loop A",
		"track_scene": TRACK_LOOP_A,
		"lap_race": true,
	},
	{
		"venue": "Test Floor",
		"venue_scene": VENUE_TEST_FLOOR,
		"track": "Loop B",
		"track_scene": TRACK_LOOP_B,
		"lap_race": true,
	},
	{
		"venue": "Test Floor",
		"venue_scene": VENUE_TEST_FLOOR,
		"track": "Sprint Straight",
		"track_scene": TRACK_SPRINT,
		"lap_race": false,
	},
]

var _session: Node = null

@onready var _venue_option: OptionButton = $Center/Panel/Margin/VBox/VenueRow/VenueOption
@onready var _track_option: OptionButton = $Center/Panel/Margin/VBox/TrackRow/TrackOption
@onready var _type_option: OptionButton = $Center/Panel/Margin/VBox/TypeRow/TypeOption
@onready var _laps_spin: SpinBox = $Center/Panel/Margin/VBox/LapsRow/LapsSpin
@onready var _opponents_spin: SpinBox = $Center/Panel/Margin/VBox/OpponentsRow/OpponentsSpin
@onready var _start_button: Button = $Center/Panel/Margin/VBox/StartButton


func _ready() -> void:
	for race_type in RACE_TYPES:
		_type_option.add_item(_type_label(race_type))
	_fill_venues()
	_type_option.select(0)
	_venue_option.item_selected.connect(_on_venue_selected)
	_type_option.item_selected.connect(_on_type_selected)
	_start_button.pressed.connect(_on_start_pressed)
	_refresh_type()


func _fill_venues() -> void:
	_venue_option.clear()
	var seen := {}
	for track in _tracks:
		var venue: String = track["venue"]
		if seen.has(venue):
			continue
		seen[venue] = true
		_venue_option.add_item(venue)
	_venue_option.select(0)
	_fill_tracks()


func _fill_tracks() -> void:
	_track_option.clear()
	for track in _selectable_tracks():
		_track_option.add_item(track["track"])
	_track_option.select(0)


## Routes the selected race type can actually run: a sprint route ends at a
## FinishLine gate, a lap route loops back to its start line. The dropdown and
## _selected_track() both read this one list, so they can never disagree.
func _selectable_tracks() -> Array[Dictionary]:
	var sprint := _selected_race_type() == RaceConfig.RaceType.SPRINT
	var found: Array[Dictionary] = []
	for track in _tracks_for_venue(_selected_venue()):
		if bool(track["lap_race"]) == sprint:
			continue
		found.append(track)
	return found


func _tracks_for_venue(venue: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for track in _tracks:
		if track["venue"] == venue:
			found.append(track)
	return found


func _selected_venue() -> String:
	if _venue_option.selected < 0:
		return ""
	return _venue_option.get_item_text(_venue_option.selected)


func _selected_track() -> Dictionary:
	var tracks := _selectable_tracks()
	var index := _track_option.selected
	if index < 0 or index >= tracks.size():
		return {}
	return tracks[index]


func _selected_race_type() -> int:
	var index := _type_option.selected
	if index < 0 or index >= RACE_TYPES.size():
		return RaceConfig.RaceType.CIRCUIT
	return RACE_TYPES[index]


func _type_label(race_type: int) -> String:
	match race_type:
		RaceConfig.RaceType.SPRINT:
			return "Sprint (point-to-point)"
		RaceConfig.RaceType.TIME_ATTACK:
			return "Time Attack (solo)"
	return "Circuit"


## Time attack is solo and sprint is a single run, so both change the fields below.
func _refresh_type() -> void:
	var race_type := _selected_race_type()
	var solo := race_type == RaceConfig.RaceType.TIME_ATTACK
	var sprint := race_type == RaceConfig.RaceType.SPRINT
	_opponents_spin.editable = not solo
	if solo:
		_opponents_spin.value = 0.0
	elif _opponents_spin.value < 1.0:
		_opponents_spin.value = 2.0
	# Sprint is point-to-point, so a lap count is meaningless.
	_laps_spin.editable = not sprint
	if sprint:
		_laps_spin.value = 1.0
	_fill_tracks()


func _on_venue_selected(_index: int) -> void:
	_fill_tracks()


func _on_type_selected(_index: int) -> void:
	_refresh_type()


func _build_config() -> RaceConfig:
	var track := _selected_track()
	var config := RaceConfig.new()
	config.venue_name = String(track.get("venue", ""))
	config.track_name = String(track.get("track", ""))
	config.venue_scene = track.get("venue_scene", null) as PackedScene
	config.track_scene = track.get("track_scene", null) as PackedScene
	config.race_type = _selected_race_type() as RaceConfig.RaceType
	config.total_laps = int(_laps_spin.value)
	config.opponent_count = int(_opponents_spin.value)
	config.player_car_scene = RaceConfig.PLAYER_CAR
	config.opponent_car_scene = RaceConfig.OPPONENT_CAR
	return config


func _on_start_pressed() -> void:
	if _session != null:
		return # A race is already running behind this hidden menu.
	var config := _build_config()
	for problem in config.validate():
		push_warning("RaceMenu: config problem - %s" % problem)
	_session = RACE_SCENE.instantiate()
	_session.config = config
	_session.race_closed.connect(_on_race_closed)
	get_tree().root.add_child(_session)
	visible = false
	print("RaceMenu: starting %s / %s" % [config.venue_name, config.track_name])


func _on_race_closed() -> void:
	_session = null
	visible = true
