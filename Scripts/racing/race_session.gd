extends Node3D
class_name RaceSession
## One running race: loads the venue scenery and the track route named by a
## RaceConfig, then hands control to RaceManager. Owns presentation only (camera,
## HUD, sky, lights) and holds no geometry of its own.
##
## Run this scene directly for a dev race (falls back to the dev defaults in
## RaceConfig). The menu (future) instantiates it, assigns `config`, then adds it
## to the tree; a hosting menu listens to `race_closed`.

signal race_closed

@export var config: RaceConfig = null
## Start immediately in _ready(), using `config` or the dev default race.
@export var auto_start: bool = true

@onready var venue_holder: Node3D = $VenueHolder
@onready var track_holder: Node3D = $TrackHolder
@onready var racers_root: Node3D = $Racers
# Untyped on purpose: RaceManager has no class_name (same rule as RaceHUD).
@onready var race_manager = $RaceManager


func _ready() -> void:
	if auto_start:
		start(config if config else _dev_config())


## Loads venue + track and starts the race. False means nothing was spawned.
func start(race_config: RaceConfig) -> bool:
	if race_config == null:
		push_error("RaceSession: start() called without a RaceConfig.")
		return false
	config = race_config
	for problem in config.validate():
		push_warning("RaceSession: config problem - %s" % problem)
	if config.venue_scene == null or config.track_scene == null:
		push_error("RaceSession: venue or track scene missing; race not started.")
		return false

	_swap_scene(config.venue_scene, venue_holder)
	_swap_scene(config.track_scene, track_holder)
	if not race_manager.racers_spawned.is_connected(_on_racers_spawned):
		race_manager.racers_spawned.connect(_on_racers_spawned)
	var started: bool = bool(race_manager.begin(config, racers_root))
	if started:
		print("RaceSession: %s / %s - %s, %d lap(s), %d car(s)" % [
			config.venue_name, config.track_name, config.race_type_name(),
			config.total_laps, config.racer_count()])
	return started


## Replaces whatever sat in a holder, so re-saving in the editor is harmless.
func _swap_scene(scene: PackedScene, holder: Node3D) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	holder.add_child(scene.instantiate())


## The camera is presentation, so the race scene points it at the player.
func _on_racers_spawned() -> void:
	var camera := get_node_or_null("Camera3D")
	var player: Node3D = race_manager.get_player()
	if camera and player:
		camera.follow(player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()


## Tears the race down. A hosting menu listens to `race_closed`.
func close() -> void:
	race_closed.emit()
	queue_free()


## Smoke-test race used when this scene is run on its own.
func _dev_config() -> RaceConfig:
	var dev := RaceConfig.new()
	dev.venue_name = "Test Floor"
	dev.track_name = "Loop A"
	dev.venue_scene = RaceConfig.DEV_VENUE
	dev.track_scene = RaceConfig.DEV_TRACK
	dev.player_car_scene = RaceConfig.PLAYER_CAR
	dev.opponent_car_scene = RaceConfig.OPPONENT_CAR
	return dev
