# AI Context — Dungeon Driver (technical memory)

Permanent memory for AI coding sessions. Read this before changing code.

- **Game design (intent, WIP):** [Design.md](./Design.md) — never duplicate it here.
- **This file = code reality.** If this file and the code disagree, the code wins; fix this file in the same change.
- **Maintenance:** edit only the affected section; one fact per line; no prose padding, no tutorial content. Every fact appears exactly once, in the section a future session would look for it. When a section exceeds ~40 lines, move its detail to `Documentation/systems/<topic>.md` and leave a one-line pointer. Split this file itself once it passes ~500 lines. Delete entries when the code they describe is removed.

---

## 1. Project meta

| Item | Value |
|---|---|
| Project name | `DungeonDriverWeb` |
| Engine | **Godot 4.7.2** |
| Renderer | `gl_compatibility` (both default and mobile) — web export target |
| Main scene | `res://Scenes/race_menu.tscn` (quick-race menu); the race scene it loads is `res://Scenes/race_session.tscn` (`uid://0txiole8x7i8`) |
| Autoloads | **none created yet** — allowed in the future when a real need appears |
| Physics | 60 ticks/s, 8 max steps/frame |
| Scene format | text `.tscn`, `format=4`; `.gd.uid` sidecar files are committed |

---

## 2. Folder map + placement rules

```
Scenes/            race_menu.tscn (main), race_session.tscn (race scene), race_template.tscn (compat shim), test_drive2.tscn (manual sandbox)
Prefabs/           car_base_a.tscn
Scripts/           car_drive.gd, camera_follow.gd, speedometer.tscn
Scripts/racing/    race_manager.gd, race_hud.gd+.tscn, checkpoint.gd+.tscn, start_finish_line.gd+.tscn
Art/Outsource/     KenneyCars/ (GLB cars + colormap), KenneyPrototype/ (modular walls, cubes)
Documentation/     Design.md, ai_context.md
addons/orca/       editor tooling — ignore for gameplay work
```

Rules:
- Reusable, manager-agnostic node → `Prefabs/` (car) or `Scripts/<domain>/` next to its `.gd` (race gates currently do this).
- Playable/level scene → `Scenes/`.
- Third-party art → `Art/Outsource/<KitName>/`; keep kits intact.
- Design intent → `Documentation/Design.md`; architecture facts → this file.
- Existing quirk: two race prefabs live in `Scripts/racing/`. Do not mass-move files unless asked; a `.tscn` move rewrites UIDs/paths.

---

## 3. Architecture

```
RaceManager (Node — scene-local, one per race scene, dies with it)
  ├─ scans parent subtree by *type* for Checkpoint / StartFinishLine / RaceHUD
  ├─ connects gate body_entered → tracks lap/checkpoint per racer; runs the race clock
  ├─ calls hud.bind(self) → HUD renders clock / laps / checkpoints / finish banner
  └─ deferred-spawns car_scene at StartFinishLine.spawn_markers
		└─ slot 0 also joins group "player_car"
			  └─ Camera3D (camera_follow.gd) follows group "player_car"
```

**Core principle: managers wire, prefabs stay dumb.** `Checkpoint`, `StartFinishLine` and cars hold no reference to `RaceManager`; all connections are made by the manager. Communication outward is by signal.

**Car input seam:** `car_drive.gd` never reads input outside `_gather_player_input()`. Player and future AI both write `steer_input / throttle_input / brake_input`.

---

## 4. Key files

| Path | Type | Responsibility / note |
|---|---|---|
| `Scripts/racing/race_manager.gd` | `Node` | Race session: discovery, wiring, spawning, lap logic, standings, race clock, countdown. `begin(config, racers_parent)` starts everything — nothing self-starts in `_ready`; public `get_player()`, `get_player_progress()`, `elapsed_time`, `race_running`, `finish_time`, `hud`; signal `racers_spawned` |
| `Scripts/racing/race_hud.gd` + `.tscn` | `CanvasLayer`, `class_name RaceHUD` | Race HUD overlay (`layer=1`): clock top-left, `Lap X/X` + `Checkpoints: X/X` top-right, centered `Finish` banner. Discovered by type; state read from `RaceManager` via `bind()` |
| `Scripts/racing/checkpoint.gd` + `.tscn` | `Area3D`, `class_name Checkpoint` | `@export checkpoint_index:int` (0-based, contiguity required) |
| `Scripts/racing/start_finish_line.gd` + `.tscn` | `Area3D`, `class_name StartFinishLine` | `@export spawn_markers:Array[Marker3D]` (front→back; index 0 = player) |
| `Scripts/car_drive.gd` | `VehicleBody3D` | Steering/throttle/brake, speedometer text. Exports: `max_engine_force=1200`, `max_steering_angle=0.6`, `brake_force=15`, `speed_label:Label` |
| `Scripts/camera_follow.gd` | `Camera3D` | Chase cam. Exports: `target_path`, `follow_speed=5`, `offset=(0,2,5)` |
| `Scripts/speedometer.tscn` | `Control` | Car HUD, wired from the car prefab as `Speedometer/CanvasLayer/SpeedLabel`. The node *named* `CanvasLayer` is a plain `Node`, not a `CanvasLayer` — never write `is CanvasLayer` checks against it. Non-player cars delete the whole `Speedometer` node, because stacked copies all anchor to the same screen corner |
| `Prefabs/car_base_a.tscn` | `VehicleBody3D` | Root has `car_drive.gd`; BoxShape 2.55×0.90×1.30; visuals `sedan-sports/body`+`spoiler`; wheels `VehicleWheel3D_BR/BL/FL/FR`; child `Speedometer`; `speed_label = NodePath("Speedometer/CanvasLayer/SpeedLabel")` |
| `Scenes/race_session.tscn` | `Node3D` `race_root` + `race_session.gd` | The race scene (`uid://0txiole8x7i8`): `WorldEnvironment`/`DirectionalLight3D`, `VenueHolder`, `TrackHolder`, `Racers`, `RaceManager`, `Camera3D`, `RaceHUD`. Holds **no geometry** — venue + track are instanced from `RaceConfig`. Loaded by the menu; `Scenes/race_template.tscn` is now a one-node compat shim instancing it |
| `Scenes/race_menu.tscn` + `Scripts/racing/race_menu.gd` | `Control` | Quick-race menu (main scene): venue/track/race-type/laps/opponents, hand-written track list in `_tracks`. Stays the current scene and hides while a race runs; adds the race scene as a sibling of the viewport root and returns on `race_closed` |
| `Scripts/racing/race_config.gd` | `Resource`, `class_name RaceConfig` | One race's data: `venue_scene`, `track_scene`, `race_type` (CIRCUIT/SPRINT/TIME_ATTACK), `total_laps`, `opponent_count`, player/opponent car scenes, `countdown_seconds`; `racer_count()`, `race_type_name()`, `is_sprint()`, `validate()` |
| `Scripts/racing/race_session.gd` | `Node3D`, `class_name RaceSession` | Instances venue then track into the holders, calls `race_manager.begin(config, Racers)`, points the camera at the player on `racers_spawned`, `close()` (and `ui_cancel`) frees the race; `_dev_config()` keeps the scene runnable standalone |
| `Prefabs/car_opponent_a.tscn` | `VehicleBody3D` | Inherits `car_base_a.tscn` (same model for now); used for every opponent, its speedometer is hidden |
| `Scenes/Venues/test_floor.tscn` | `Node3D` | Dev venue: scenery + collision only, zero logic |
| `Scenes/Tracks/test_floor_a.tscn` / `_b.tscn` | `Node3D` | Lap routes: `StartFinishLine` with 8 `GridSlot*` markers + 3 numbered `Checkpoint*` gates; zero logic |
| `Scenes/Tracks/test_floor_sprint.tscn` | `Node3D` | Sprint route: `StartFinishLine` (grid only) + 2 checkpoints + a `FinishLine` gate; zero logic |
| `Scripts/racing/finish_line.gd` + `.tscn` | `Area3D`, `class_name FinishLine` | Sprint-only finish gate: 12x4x2 box at y+2 plus two flag props, no exports, no state |
| `Scenes/test_drive2.tscn` | `Node3D` | Scratch sandbox: `car_base_a` instance, Kenney props, own camera. Not shipped content |

---

## 5. Contracts (keep in sync when refactoring)

`RaceManager` signals: `race_started`, `checkpoint_reached(racer:Node3D, index:int)`, `lap_completed(racer:Node3D, lap:int)`, `race_finished(standings:Array)`.

`RaceManager` public: `begin(config, racers_parent)`, `spawn_racers()`, `register_racer(racer)`, `unregister_racer(racer)`; state fields `config`, `checkpoints`, `start_finish_line`, `finish_line`, `racers`, `racer_states`.

`racer_states` schema: `{ racer_node(KEY) : { "lap": int(1-based), "next_checkpoint": int, "finished": bool } }`.

HUD contract: `RaceHUD.bind(manager)` is its only entry point — the manager calls the HUD, the HUD never looks up the manager; it filters manager signals with `racer == manager.get_player()`.
Clock: `elapsed_time` accumulates delta in `RaceManager._process` only while `race_running`; the clock starts only after `countdown_seconds`, so grid settle time is excluded; on the first finish `race_running=false` and `finish_time=elapsed_time`.
`get_player()` = racer in group `player_car`, else `racers[0]`. `get_player_progress()` = `{ is_sprint, lap (1-based, clamped to total_laps), total_laps, checkpoints_done (per lap; whole race in a sprint), checkpoints_total, finished }`.

Lap rules (CIRCUIT/TIME_ATTACK): a crossing counts only if `next_checkpoint == checkpoints.size()`; then `next_checkpoint = 0`, `lap += 1`, and only afterwards is `lap_completed(racer, completed_lap)` emitted — **state is fully mutated before signals fire**, because listeners (HUD, standings) read `racer_states` inside the handler; race ends when `lap > total_laps`.

Sprint rules: crossing `StartFinishLine` does nothing (the clock already runs from GO); `FinishLine` finishes a racer only when `next_checkpoint == checkpoints.size()`, so corners cannot be cut; `total_laps` is ignored and the HUD hides its lap label.

Track shape is type-checked: sprint tracks must contain a `FinishLine`, lap tracks must not — `_validate_track()` push_errors otherwise. `_finish_racer()` is the shared finish path (freeze clock, mark finished, emit `race_finished`).

Extension hooks: any new race node type must be added inside `_find_race_nodes()`; new per-racer data belongs in `racer_states`.

---

## 6. Instructions for AI sessions

1. **Every new semantic trigger node gets `class_name`,** because discovery is type-based, not path-based.
2. Prefabs must not call `get_parent()` chains to find managers — emit signals, let the manager wire.
3. Adding children during `_ready` must be `call_deferred()` (existing pattern in `spawn_racers`).
4. Style: GDScript with tabs, typed params/returns, `snake_case`, `##` doc comments on exported resources and non-obvious functions, `print()` for race telemetry (existing convention: prefix `RaceManager:` / `Camera`).
5. Exported properties are serialized in `.tscn` — renaming/removing one requires updating every scene that sets it (`car_base_a.tscn` uses `node_paths=...` for `speed_label`).
6. Test by running `res://Scenes/race_menu.tscn` (main scene) and pressing Start Race; console must show `RaceMenu: starting <venue> / <track>`, then `RaceManager: registered N checkpoint(s)`, `RaceHUD: bound to <manager>`, `RaceSession: <venue> / <track> - <type>, N lap(s), N car(s)`, `RaceManager: countdown`, `RaceManager: spawned N racer(s)`, `Camera: following <car>`. A sprint adds `Racer <name>: finish line crossed with N/N checkpoints`.
7. Do not restructure folders, rename scenes, or change what is vs. isn't scene-scoped without an explicit request.
8. **UI:** build with `Control` + anchors/containers, never absolute pixel offsets; layouts must hold at 4:3, 16:9 and ultrawide (project uses stretch aspect `expand`, so do not assume letterboxing).
9. **Explain before you specify:** for design/architecture questions, answer in plain language first — what the thing does, what it costs, what it means for the game — using concrete analogies. File paths, node names and code go in a short follow-up section, not the opener. The user finds code-first answers hard to read. Keep the code-first register for actual implementation work.

---

## 7. Input map

Custom actions (only 4): `drive_f`, `drive_b`, `drive_l`, `drive_r` (arrow keys, deadzone 0.2).
The other ~91 actions are stock Godot `ui_*` defaults — do not hand-edit them.

---

## 8. Known issues / tech debt

1. `Camera3D` never searches the tree: `RaceSession._on_racers_spawned()` calls `camera_follow.follow(player)`. `Scenes/test_drive2.tscn` instances `car_base_a` outside a race, so that car is not in `player_car` and its speedometer is removed — cosmetic, scratch scene only.
2. Opponents spawn but have no AI controller: they sit on the grid, since nothing writes `steer_input`/`throttle_input` for them yet.
3. `race_finished` is emitted only for the first finisher; later finishers never get an updated standings payload, and standings rank by `finished`/`lap`/`next_checkpoint` only — no lap times or finish order timestamps.
4. `start_finish_line.gd` has a duplicated comment on lines 4–5 (cosmetic).
5. HUD reads only the **player** racer; per-racer standings stay console-only. A race blocks forever if a car never finishes (`race_running` stays true, clock keeps running).
6. Single car model with hardcoded exports; parts/upgrades from `Design.md` have no runtime data layer.
7. Time attack is "circuit with 0 opponents": no per-lap times, no best-lap result yet.

---

## 9. Where new systems plug in (from Design.md)

- AI opponents → per-car controller that writes `steer_input/throttle_input/brake_input`; add `Marker3D`s to `StartFinishLine.spawn_markers`.
- Race types: CIRCUIT and SPRINT implemented (`FinishLine` gate + `_is_sprint()` branch); TIME_ATTACK reuses the circuit path with `opponent_count` forced to 0.
- Car parts/upgrades → stat block applied to `car_base_a` exports (`max_engine_force`, wheel grip, etc.) at spawn time.
- Crate → `Area3D` prefab + `class_name`, discovered/wired by `RaceManager` alongside gates.
- Career/save/garage → not implemented; garage/shop will be separate scenes, state scoping decided when built. `RaceManager` stays race-only.

---

## 10. Glossary

- **Venue** — location containing several tracks (e.g. The Mill). **Track** — a route through a venue.
- **League / Sunday Cup** — career progression tiers; 3 Sunday Cups = champion of one league.
- **Part** — semi-randomized car upgrade item, rarity-tiered, equipped in the garage.
- **Checkpoint** — ordered gate; **Start/Finish Line** — lap gate + spawn grid holder.
- **Racer state** — per-car progress record in `RaceManager.racer_states`.
