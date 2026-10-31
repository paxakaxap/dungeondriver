extends Resource
class_name RaceConfig
## Everything that defines one race: which venue and track to load, plus the rules.
##
## Built by the race menu (later: by the career calendar) and handed to
## RaceManager.begin() by the race scene. No prefab reads this: Checkpoint,
## StartFinishLine and the cars stay dumb and RaceManager does all the wiring.

enum RaceType {
	CIRCUIT = 0,     ## Loop track; first car to complete total_laps wins.
  SPRINT = 1,      ## Point-to-point: grid at the start line, a FinishLine gate ends it.
	TIME_ATTACK = 2, ## Solo run against the clock; opponent_count is ignored.
}

## Design cap from Design.md: up to 7 competitors.
const MAX_OPPONENTS := 7

const DEV_VENUE := preload("res://Scenes/Venues/test_floor.tscn")
const DEV_TRACK := preload("res://Scenes/Tracks/test_floor_a.tscn")
const PLAYER_CAR := preload("res://Prefabs/car_base_a.tscn")
const OPPONENT_CAR := preload("res://Prefabs/car_opponent_a.tscn")

@export var venue_name: String = ""
@export var track_name: String = ""
## Scenery only: meshes and collision. Contains no race logic.
@export var venue_scene: PackedScene = null
## Route only: StartFinishLine + Checkpoint gates. Contains no race logic.
@export var track_scene: PackedScene = null
@export var race_type: RaceType = RaceType.CIRCUIT
@export var total_laps: int = 3
## Opponents only; the player always takes grid slot 0 on top of these.
@export var opponent_count: int = 2
@export var player_car_scene: PackedScene = null
@export var opponent_car_scene: PackedScene = null
## Delay between cars appearing and the clock starting, in seconds.
@export var countdown_seconds: float = 3.0


## Total cars on the grid, player included.
func racer_count() -> int:
	var opponents := 0 if race_type == RaceType.TIME_ATTACK else opponent_count
	return opponents + 1


## Sprint races end at a FinishLine gate instead of counting laps.
func is_sprint() -> bool:
	return race_type == RaceType.SPRINT


func race_type_name() -> String:
	match race_type:
		RaceType.CIRCUIT:
			return "Circuit"
		RaceType.SPRINT:
			return "Sprint"
		RaceType.TIME_ATTACK:
			return "Time Attack"
	return "Unknown"


## Problems that make this config unusable; empty array means fine.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if venue_scene == null:
		problems.append("venue_scene is not set")
	if track_scene == null:
		problems.append("track_scene is not set")
	if player_car_scene == null:
		problems.append("player_car_scene is not set")
	if total_laps < 1:
		problems.append("total_laps must be at least 1")
	if opponent_count < 0 or opponent_count > MAX_OPPONENTS:
		problems.append("opponent_count must be between 0 and %d" % MAX_OPPONENTS)
	return problems
