# Zipball

Working title. A 3D arena sports game: players swing around a jungle-gym arena on
grappling hooks and throw a ball into the other team's net.

- **Platform:** PC, released on Steam.
- **Modes:** local couch multiplayer first (1v1), then online competitive (1v1 and 3v3), with bots to fill slots.
- **Look:** stylized low-poly, Sega Dreamcast era.
- **Who builds it:** Claude Code writes most of the code and generated art. Keep everything editable as text.

## Tools

- **Godot 4.7.2**, standard build (not .NET). **GDScript only.** Renderer: Forward+. Physics: Jolt.
- Run Godot through `tools/godot.sh` (Git Bash). It uses the console build, so output reaches the
  terminal, and passes `--path .`. Override the binary with `GODOT=/path/to/godot`.
- **Blender 4.5 LTS** for generated 3D assets: `"C:/Program Files/Blender Foundation/Blender 4.5/blender.exe"`.
  Not installed yet as of 2026-11-12. The automated download was blocked, so the user installs it.

## Commands

| Task | Command |
|---|---|
| Import assets and refresh class caches (after adding files or a `class_name`) | `tools/godot.sh --headless --import` |
| Run all tests | `tools/godot.sh --headless --script res://tools/run_tests.gd` |
| Run matching tests | `... run_tests.gd -- --filter=<text>` (matches `file:test_name`) |
| Screenshot the main scene (the menu) | `tools/godot.sh -- --screenshot=tmp/screenshots/main.png`, then Read the PNG |
| Screenshot a match (default settings) | `tools/godot.sh res://src/match/match.tscn -- --screenshot=tmp/screenshots/match.png` |
| Screenshot another scene | `tools/godot.sh res://src/<path>.tscn -- --screenshot=tmp/screenshots/<name>.png` |
| Screenshot from a fixed camera | `... -- --screenshot=tmp/screenshots/x.png --camera=75,45,95 --look-at=0,0,0` |
| Run headless for N frames (surfaces runtime errors) | `tools/godot.sh --headless --quit-after 300` (the menu; put `res://src/match/match.tscn` before `--quit-after` for a match) |
| Record a frame sequence (folder must exist first) | `mkdir -p tmp/movie && tools/godot.sh --write-movie tmp/movie/frame.png --fixed-fps 30 --quit-after 90` (writes `frame00000000.png`, ...) |
| Open the editor (for the user) | `tools/godot.sh --editor` |
| Play (for the user, no terminal needed) | Double-click `play.cmd` |

Screenshots and recordings open a real game window on the user's screen for a moment. `--screenshot`
cannot be combined with `--headless`. Add `--frames=<n>` to wait longer before capturing.

One-off `extends SceneTree` scripts run with `--script` can't create the keyboard player:
`LocalInputSource` uses the `DevTools` autoload, which isn't a known name there, so `Match` logs
compile errors and adds no player. Give them a player with `match.add_player(ScriptedInputSource.new(), 0, true)`.
Put such scripts in `tmp/` and add a quit timer, so a script error can't leave a window hanging open.

## Definition of done

- Tests pass and the headless run logs no errors.
- Visual changes: take a screenshot and look at it before calling the work done.
- New gameplay logic gets tests where practical (see "Tests" below).

## Project layout

```
src/arena/    Zip point geometry, beams or orbs (Lattice), tumbling (ArenaSpin), the Arena node
src/player/   Player simulation, movement math (Movement), MovementTuning, visuals, camera
src/input/    PlayerInput and input sources (LocalInputSource, ScriptedInputSource)
src/match/    Match: runs the tick loop and spawns players. MatchSettings: the menu's choices
src/ball/     Ball: frozen at the faceoff spot until grabbed or hooked, carried, thrown, flies and bounces
src/ui/       MainMenu (main_menu.tscn is the main scene), HUD, TargetArrows (edge arrows to the ball and goals)
src/scenery/  Venues (Scenery): one scene per environment with sky, sun, fog, floor, peaks (MountainRing), weather
src/dev/      Dev-only tooling (DevTools autoload: --screenshot, --camera)
docs/         design.md: design decisions, build stages, starting tuning values
assets/       Art: models/ (.glb), textures/, shaders/ (venue skies, floors, peaks), audio/. Credits in CREDITS.md
art_src/      Blender Python scripts that generate assets (Godot ignores this folder)
tests/        Headless tests, test_*.gd
tools/        CLI helpers: godot.sh, run_tests.gd, test_case.gd
tmp/          Scratch output: screenshots, previews, recordings (gitignored, Godot-ignored)
```

## Architecture rules (these keep online play possible later)

1. **Input → simulation → presentation.**
   - Gameplay code never reads `Input` directly. Each tick, every player receives a plain input
     object (movement, aim, buttons). Input comes from a local gamepad or keyboard, a bot, or later
     the network, and gameplay can't tell which.
   - The **simulation** is everything that can affect the score: player movement, grapple, ball,
     goals, match clock. It runs only in `_physics_process` (fixed tick).
   - **Presentation** covers camera, animation, particles, sound and UI. It reads simulation
     state and never changes it, and may use `_process`.
2. **Gameplay state must be easy to save and restore.** Keep it in plain variables. Don't put
   gameplay timing in Timer nodes, Tweens or AnimationPlayers; count ticks instead.
3. **Determinism where it's cheap.** The match owns a seeded RNG. Nothing depends on frame rate or
   wall-clock time. Never hardcode `1.0 / 60.0`; use `delta` or the configured tick rate.
4. **Movement and grapple are custom code** (CharacterBody3D plus our own rope math), not physics joints.
5. **`Match._physics_process` is the only tick driver.** It steps the arena, then for each player in a
   fixed order calls `source.poll()` and `player.simulate()`. Don't give simulation nodes their own
   `_physics_process`.
6. **Presentation nodes** (`PlayerVisuals`, `PlayerCamera`, `Hud`) only read state. Anything positioned
   in `_process` sets `physics_interpolation_mode = OFF` and reads positions through
   `get_global_transform_interpolated()` (physics interpolation is on).

## Design doc

`docs/design.md` records every design decision, the build stages with their checklists, and the
starting tuning values. Read it before gameplay work. Update it when a decision changes or a stage item is done.

## GDScript conventions

- **Godot 4 syntax only.** Common Godot 3 mistakes to avoid:
  `KinematicBody`→`CharacterBody3D`, `Spatial`→`Node3D`, `move_and_slide(vel)`→set `velocity` then `move_and_slide()`,
  `yield`→`await`, `export var`→`@export var`, `onready`→`@onready`, `tool`→`@tool`,
  `connect("sig", self, "fn")`→`sig.connect(fn)`, `instance()`→`instantiate()`,
  `rand_range`→`randf_range`, `deg2rad`→`deg_to_rad`, `Pool*Array`→`Packed*Array`,
  `Transform`→`Transform3D`, `.empty()`→`.is_empty()`, `setget`→property `get:`/`set:`.
- **Static typing everywhere:** typed variables, parameters, return types, typed arrays and dictionaries,
  typed `for` loop variables. The `untyped_declaration` warning is on.
- Official style guide: tabs, snake_case files/functions/variables, PascalCase `class_name` and node
  names, CONSTANT_CASE constants, past-tense signals (`goal_scored`), `_private` members.
- Prefer `@export` and `%UniqueName` node references over long `get_node` paths.
- Add a `class_name` for types used across files, then run `--import` so the global class cache updates.
- Put `##` doc comments on classes and on non-obvious functions.

## Editing scenes and resources by hand

- `.tscn` and `.tres` files are text, so edit them directly.
- **Don't compute rotations by hand.** In scene files, `Transform3D(...)` lists the basis **row by row**,
  then the origin. Get the values from Godot instead (a quick `--script` that prints
  `var_to_str(Transform3D(Basis.from_euler(...), origin))`), or set `rotation_degrees` on the node.
- Never invent `uid=` values: leave them out and Godot adds them. Keep existing uids intact.
- Every `ext_resource` and `sub_resource` id must be unique within its file.
- When moving or renaming a script, move its `.gd.uid` file with it. Commit `.uid` and `.import`
  files. Never edit anything in `.godot/`.
- After editing scenes, run the tests (`test_scenes` loads every scene under `src/`).

## Tests

- Test files: `tests/**/test_*.gd`, beginning with `extends "res://tools/test_case.gd"`. Each `test_*`
  method runs on a fresh instance and may `await`. Optional hooks: `before_each` and `after_each`.
- Helpers: `assert_true/false/eq/almost_eq/null/not_null`, `fail()`, `add_to_tree(node)` (freed after the
  test), `await wait_physics_ticks(n)`.
- Any engine or script error logged during a test fails it, including `push_error` and null calls.
- The headless window is only 64×64 px. Tests that project points onto the screen should put their
  camera in a `SubViewport` of known size.
- Derive positions in tests from the arena (`spawn_local_position`, `spacing`, `lattice.half_extent`)
  rather than hardcoding them, so tests survive layout changes.
- The simulation should be testable without rendering: feed scripted inputs for N ticks, then assert
  on the resulting state.

## Art pipeline

- The Python scripts in `art_src/` are the source of truth for generated art. Run them with
  `blender --background --factory-startup --python art_src/<script>.py`. They export `.glb` files to
  `assets/models/` and render preview PNGs to `tmp/previews/`. Look at the previews.
  (Not verified yet: Blender isn't installed.)
- Dreamcast-era targets:
  - Polygon counts: props roughly 50–500 triangles, characters roughly 1–3k.
  - Textures: small (64–256 px), or palette textures plus vertex colors.
  - Bright, saturated colors, smooth shading and linear texture filtering.
- Third-party assets must be CC0 or clearly licensed. Record each source and license in `assets/CREDITS.md`.
- Steam requires disclosing AI-generated content. Everything made by `art_src/` scripts counts, so keep it traceable.

## Git

- Don't commit unless the user asks.
