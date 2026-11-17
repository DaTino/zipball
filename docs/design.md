# Zipball design

Living document. It records what we decided, why, and where each build stage stands.
Update it whenever a decision changes. Tunable numbers live in code (see "Tuning"); this
doc records the intent and the starting values.

## Concept

First-person arena sports. Players swing through a slowly tumbling cube-shaped jungle gym on
grappling hooks, carry or throw a ball, and score by touching the ball to the other team's
spherical goal.

- **Platform:** PC, released on Steam.
- **Modes:** local split-screen 1v1 first, then online 1v1 and 3v3, with bots to fill slots.
- **Look:** stylized low-poly, Sega Dreamcast era.

## Decisions

| # | Topic | Decision | Date |
|---|---|---|---|
| D1 | Engine | Godot 4.7.2, GDScript, Jolt physics | 2026-11-12 |
| D2 | View | First person. Local multiplayer uses side-by-side split screen | 2026-11-12 |
| D3 | Arena shape | Cube lattice: pipes along all three axes, 10 pipes per side (9 gaps), 24 m apart. Was 6 m, which felt cramped: players bumped into pipes constantly and never felt like they were flying | 2026-11-13 |
| D4 | Goals | Spheres 12 m across (was 3 m) in opposite corners on the cube's main diagonal, each in the open cell two pipe layers in from the corner | 2026-11-13 |
| D5 | Rotation | The cube tumbles semi-randomly around its center. The spin axis and speed drift so players have to keep adjusting. The spin is driven by a seed, so it's reproducible | 2026-11-12 |
| D6 | Gravity | World-down (the sky stays put; the cube turns). Outside the cube, a pull back toward it replaces gravity, for players and ball | 2026-11-12 |
| D7 | Collisions | Players and ball bump off pipes. The grapple line passes through pipes (no wrapping) | 2026-11-12 |
| D8 | Ball physics | Our own movement code, like the players: Match moves the ball each tick (a CharacterBody3D), with gravity, the pull back into the cube and bounces off pipes (bouncier than players). Was a Jolt rigid body; changed so the ball stays in the single tick loop and its state stays easy to save and restore for online play | 2026-11-13 |
| D9 | Grapple | 80 m range, attaches to pipes. Aim assist is an angle (3°), so far pipes are as easy to catch as near ones; a direct hit always wins. The anchor moves with the arena. Releasing keeps momentum, with no extra boost. Once the hook lands, it pulls you in (D21) | 2026-11-13 |
| D10 | Movement | No walking or jumping. Grapple plus air control only | 2026-11-12 |
| D11 | Possession | Auto pickup when your center gets within 2 m of the ball's surface (was about 1.5 m); if two players are in range on the same tick, the first in player order gets it. Hooking a loose ball pulls it to you. Hooking the carrier steals it. Hooking an opponent without the ball does nothing. Short cooldown after throws and steals | 2026-11-13 |
| D12 | Throwing | Hold to charge (up to 1 s). A tap throws at 15 m/s, a full charge at 50 m/s, along your aim, plus your own velocity. The thrower can't grab it back for 0.5 s; anyone else can catch it right away. You can grapple while holding the ball. A bar under the crosshair shows the charge | 2026-11-13 |
| D13 | Scoring | The ball (thrown or carried) touches the opponent's goal. Own goals count for the other side | 2026-11-12 |
| D14 | Faceoff | After each goal, the ball is frozen at the cube's center until first touch. Players start at equal distances on their own side, facing it. 3-second countdown | 2026-11-12 |
| D15 | Match rules | Chosen at start: timed (default 5 min, sudden-death overtime on a tie) or first to N points (default 5) | 2026-11-12 |
| D16 | Local devices | Player 1: keyboard and mouse or first gamepad. Player 2: second gamepad. Two keyboard players isn't possible because Windows can't tell two mice apart | 2026-11-12 |
| D17 | Pipe look | Plain silver with Gouraud (per-vertex) shading, no shadows. Replaces per-axis colors; the sky above and green ground below are enough for orientation | 2026-11-13 |
| D18 | Finding things | HUD arrows at the screen edge point toward the ball and both goals when they're out of view. In view, they get a small diamond. Each shows its distance. A testing aid for now; revisit for the real HUD | 2026-11-13 |
| D19 | Pipe size | Pipes 1 m thick (was 0.4 m), joints 1.6 m across | 2026-11-13 |
| D20 | Gravity switch (testing) | G / Back turns downward gravity off and on for the whole match, players and ball. The pull back into the cube still works with it off | 2026-11-13 |
| D21 | Auto-reel | Modeled on the Q-Claw in *007: Agent Under Fire* multiplayer. Hold the grapple button: the hook flies out (200 m/s; let go before it lands to cancel). When it lands, the line pulls you toward the pipe at up to 30 m/s with no gravity, keeps some of your sideways speed, and brakes so you stop and hang 2 m from the pipe. Keep holding to hang there, moving with the cube. Let go any time to fly off with your speed. E / R2 lets the line out: the pull stops and it becomes a plain rope you swing on (Q/E change its length, gravity applies). One button, no new ones. Replaces options A–C | 2026-11-13 |
| D22 | Ball size and carrying | The ball is 3 m across (tripled from 1 m) so it's easier to see and grab. A carried ball rides just in front of the carrier, along their aim. It's hidden from the carrier's own camera (it would fill the screen); the HUD says "Ball YOURS" instead. Right after a throw it's also hidden from the thrower until it's 8 m away, so it doesn't flash across their view | 2026-11-13 |

## Arena geometry

All in the arena's own coordinates, centered on the cube's center.

- 10 pipe positions per axis at `-108, -84, ..., 84, 108` m (spacing 24 m), so the cube is 216 m across.
- Pipes along X, Y and Z through every pair of positions: 3 × 10 × 10 = 300 pipes.
- The cube's center `(0, 0, 0)` is the middle of an open cell, so the faceoff ball sits in open space.
- Goal A at `(-72, -72, -72)`, goal B at `(72, 72, 72)`. Both are open-cell centers, two layers in
  from opposite corners, about 249 m apart.
- Spawns at `(-24, -24, -24)` (team 0, next to goal A's side) and `(24, 24, 24)` (team 1).
- Pipes are plain silver (D17), 1 m thick (D19). Goals are 12 m across (D4).
- The ball (3 m across, D22) waits at the center, the faceoff spot. Get within 2 m of it to grab
  it (D11), hold RMB / R1 to charge a throw, and let go to throw (D12). It stays frozen at the
  center until its first touch; respawning with the ball sends it back there, frozen.

## Controls

| Action | Keyboard and mouse | Gamepad |
|---|---|---|
| Aim | Mouse | Right stick |
| Air control (adds momentum while swinging or in the air) | WASD | Left stick |
| Fire grapple (hold: pulled in, then hang; let go to fly) | Left mouse button | L1 |
| Let line out (stops the pull; then swing on a plain rope) | E | R2 |
| Reel in (on the plain rope) | Q | L2 |
| Throw (hold to charge) | Right mouse button | R1 |
| Respawn (prototype only; returns the ball to the center if you have it) | R | Start |
| Gravity on / off (testing only) | G | Back / Select |
| Release / recapture mouse | Esc / click | |
| Fullscreen (prototype only) | F11 | |

**To play the current build:** double-click `play.cmd` in the project folder. A keyboard and mouse and
the first gamepad both control the one player.

## Build stages

### Stage 1: arena and one player (in progress)

Goal: swinging around the tumbling cube feels good.

- [x] Pipe lattice with collisions
- [x] Semi-random tumbling, reproducible from a seed
- [x] Goal spheres (visual only for now)
- [x] Grapple: aim assist, attach, swing, shorten/lengthen, release
- [x] Air control, gravity, pull back into the cube
- [x] First-person camera, crosshair showing where the grapple will land, debug readout
- [x] Simulation tests
- [x] Playtest 1 changes: pipes 24 m apart, silver pipes without shadows, HUD arrows to the ball and goals
- [x] Playtest 2 changes: 1 m pipes, 12 m goals, angle-based aim assist, gravity test switch
- [x] Auto-reel: a pull modeled on the Agent Under Fire Q-Claw (D21)
- [ ] **Playtest and tune feel** (the user plays; we adjust numbers together)

### Playtest notes

- **2026-11-13, playtest 1:** Looks good overall. Pipes were much too close (constant bumping, no
  sense of flying), so spacing went from 6 m to 24 m, and grapple range and line length grew to
  match. Pipes became silver, without shadows. HUD arrows were added for testing. Swinging and
  movement feel are next.
- **2026-11-13, playtest 2:** Pipes thickened to 1 m and goals to 12 m. Aim assist became an angle.
  Added a gravity on/off test button. Proposed auto-reel: the line reels you in automatically when
  it connects; hold to stay on and swing, let go to fly. The user pointed to the Q-Claw in
  *007: Agent Under Fire* as the feel to aim for, so the auto-reel follows it (D21).
- **2026-11-13, playtest 3:** The Q-Claw pull is good so far. The ball was too small and hard to
  grab, so it's now 3 m across and you grab it within 2 m (D11, D22).

### Stage 2: ball and scoring (started)

Possession (proximity, snag, steal), charged throws, goals, faceoff, score.

- [x] Ball 3 m across; grab it within 2 m; it rides in front of the carrier (D11, D22)
- [x] Throwing (hold to charge, inherits your velocity) and ball physics (D8, D12)
- [ ] Hooking the ball pulls it to you; hooking the carrier steals it; cooldowns (D11)
- [ ] Goals and score (D13), faceoff and countdown (D14), match rules (D15)

### Stage 3: two players

Side-by-side split screen, device assignment, match settings (timed or points), HUD.

### Later

Online play (1v1, 3v3) through Steam, bots, real art (Blender pipeline), menus, audio.

## Tuning

Starting values. Adjust them in the files named here.

- **Movement and grapple:** `src/player/movement_tuning.tres` (open it in the Godot inspector).
  Gravity 9.8, air acceleration 8 m/s² up to 10 m/s, grapple range 80 m, aim assist 3°,
  line speed 10 m/s, line length 1.5–90 m, pipe bounce 0.3, pull back 20 m/s² plus 4 m/s² per meter outside.
  - Range and aim assist were scaled up with the 24 m spacing (2026-11-13). Measured over random
    look directions from inside the cube, a target was found:
    - 95% of the time with 6 m spacing and the old values (35 m range, 0.6 m assist).
    - 21% of the time with 24 m spacing and the old values.
    - 68% of the time with 24 m spacing, 80 m range and 1.5 m assist.
  - With 1 m pipes and an angle-based assist (80 m range), a target was found:
    - 28% of the time with no assist.
    - 54% at 1°.
    - 72% at 2°.
    - 84% at 3° (the default).
    - 90% at 4°.
  - Pull (D21): hook flies at 200 m/s (0 = instant). Pull speed 30 m/s, reached at 120 m/s²,
    which is also how hard it brakes before the pipe. Keeps half your sideways speed
    (`pull_keep_sideways` 0.5; 0 = dead straight like the Q-Claw, 1 = keep it all and curve around
    the pipe). Hangs 2 m from the pipe's center line. Pull speed 0 turns the pull off (plain rope).
    Reaching a pipe 45 m away takes about 1.9 s from the button press (0.2 s of hook flight,
    1.7 s of pull).
- **Arena spin:** exported on the Arena node in `src/arena/arena.tscn`. 2–6 degrees per second,
  new spin direction every 6–12 s, blended over 3 s.
- **Ball:** exported on the Ball node (`src/ball/ball.gd`). Radius 1.5 m, pickup distance 2 m
  (from your center to the ball's surface). Throws: 1 s to full charge, 15–50 m/s, 0.5 s before
  the thrower can grab it again. Flight: bounce 0.6, pipe friction 0.05, drag 0.02 per second,
  top speed 80 m/s; gravity and the pull back come from `movement_tuning.tres`.
- **Lattice:** exported on the Arena node. 10 pipes per side, 24 m apart, pipe radius 0.5 m,
  joint radius 0.8 m, goal radius 6 m.
- **Rendering:** 4× MSAA (Project Settings → Rendering → Anti Aliasing), so thin, distant pipes
  don't shimmer. No shadows.

## Open questions

- **Tuning the pull (D21).** How fast should it pull, and how much sideways speed should it keep?
  Straighter feels more like the Q-Claw; keeping more makes it curve around pipes like a swing.
  For reference, the Q-Claw (from fan guides): the line flew out and you had to hold until it
  landed; it pulled you straight in, fast, without gravity; holding at the end kept you hanging;
  letting go kept your speed. It had no rope swing; the "swinging" players remember was chaining
  pull, let go, pull. Options considered before choosing it: a short yank and then a fixed-length
  swing; reeling the whole time you hold (tetherball); two separate hooks.
- Does world-down gravity with a tumbling cube feel good, or should gravity follow the cube?
- With 24 m spacing, the cube is 216 m across and the goals are about 249 m apart. Is that the right
  size, or should it have fewer pipes per side (6 per side makes it 120 m)?
