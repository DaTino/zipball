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
| D3 | Arena shape | Cube lattice 216 m across, of beams (pipes along all three axes) or orbs (D24). The menu picks 4, 6, 8 or 10 per side; the cube stays the same size, so fewer means farther apart (72, 43, 31 or 24 m). Default 10. Always an even count, so an open cell sits at the center for the faceoff; the user first asked for 3, 5, 7 and 10, which would put a joint there. Was 6 m apart at first, which felt cramped: players bumped into pipes constantly and never felt like they were flying | 2026-11-17 |
| D4 | Goals | Spheres on the cube's main diagonal toward opposite corners, each in the open cell nearest two-thirds of the way from the center to the corner (two layers in from the corner with 10 per side). The menu picks Small, Medium or Large: 8, 12 or 18 m across. Default 12 m (was 3 m at first) | 2026-11-17 |
| D5 | Rotation | The cube tumbles semi-randomly around its center. The spin axis and speed drift so players have to keep adjusting. The spin is driven by a seed, so it's reproducible | 2026-11-12 |
| D6 | Gravity | World-down (the sky stays put; the cube turns). Outside the cube, a pull back toward it replaces gravity, for players and ball | 2026-11-12 |
| D7 | Collisions | Players and ball bump off beams. Orbs are never solid (D24). The grapple line passes through everything (no wrapping) | 2026-11-17 |
| D8 | Ball physics | Our own movement code, like the players: Match moves the ball each tick (a CharacterBody3D), with gravity, the pull back into the cube and bounces off pipes (bouncier than players). Was a Jolt rigid body; changed so the ball stays in the single tick loop and its state stays easy to save and restore for online play | 2026-11-13 |
| D9 | Grapple | 80 m range, attaches to pipes. Aim assist is an angle (3°), so far pipes are as easy to catch as near ones; a direct hit always wins. The anchor moves with the arena. Releasing keeps momentum, with no extra boost. Once the hook lands, it pulls you in (D21) | 2026-11-13 |
| D10 | Movement | No walking or jumping. Grapple plus air control only | 2026-11-12 |
| D11 | Possession | Auto pickup when your center gets within 4 m of the ball's surface (was 2 m, and about 1.5 m before that); if two players are in range on the same tick, the first in player order gets it. Hooking a loose ball (even the frozen faceoff ball) reels it in at 60 m/s (was 40) with no gravity while you hold the button; you catch it when it reaches pickup range, and letting go leaves it flying with its speed. The ball wins the hook over a zip point unless a zip point is directly in the way. A newer hook takes the ball from an older one. A thrower can't hook their own throw during the regrab wait. Still to do: hooking the carrier steals it; hooking an opponent without the ball does nothing; cooldown after steals | 2026-11-17 |
| D12 | Throwing | Hold to charge (up to 1 s). A tap throws at 15 m/s, a full charge at 100 m/s (was 50). The ball leaves straight down the crosshair line: your own velocity isn't added (it was until 2026-11-17, and moving players' throws drifted off their aim), so only gravity bends it. The thrower can't grab it back for 0.5 s; anyone else can catch it right away. You can grapple while holding the ball. A bar under the crosshair shows the charge | 2026-11-17 |
| D13 | Scoring | The ball (thrown, carried or being reeled in) touches a goal sphere: a point for the team that doesn't defend that goal, so own goals count for the other side. The HUD calls it an own goal when the last player to grab or hook the ball defends that goal. The ball then stays where it touched, turning with the cube, for a 2 s GOAL! pause: players keep flying, but nobody can grab or hook the ball and nothing scores. Then the faceoff (D14) | 2026-11-18 |
| D14 | Faceoff | The match starts with one, and so does each goal (after its pause) and overtime. The ball is frozen at the cube's center until first touch. Players go back to their spawns, at equal distances on their own side, facing it, and are held there for a 3-second countdown: they turn with the cube and can look around, but can't move or grapple. A grapple button held through the countdown fires on "GO!". The clock stops from a goal until play resumes | 2026-11-18 |
| D15 | Match rules | Chosen on the menu (D23): Time (default 5 min, 1–30) or Points (first to N, default 5, 1–25). A timed match ends the instant the clock hits 0:00; a ball still in the air doesn't count. A tie at 0:00 goes to sudden-death overtime: a faceoff, then the next goal wins. When the match ends, the ball stops where it is, nothing scores, and players can still fly and look around; the HUD shows the result and "Press M for the menu" | 2026-11-18 |
| D16 | Local devices | Player 1: keyboard and mouse or first gamepad. Player 2: second gamepad. Two keyboard players isn't possible because Windows can't tell two mice apart | 2026-11-12 |
| D17 | Pipe look | Plain silver with Gouraud (per-vertex) shading, no shadows. Replaces per-axis colors; the sky above and green ground below are enough for orientation | 2026-11-13 |
| D18 | Finding things | HUD arrows at the screen edge point toward the ball and both goals when they're out of view. In view, they get a small diamond. Each shows its distance. A testing aid for now; revisit for the real HUD | 2026-11-13 |
| D19 | Zip point size | The menu picks Small, Medium or Large. Beams: 1, 2 or 3 m thick (Small is the original; was 0.4 m before that), with joints 1.6 times as wide. Orbs: 2, 4 or 6 m across. You hang 1.5 m from the surface, whatever the size | 2026-11-17 |
| D20 | Gravity switch | The menu sets whether a match starts with gravity on. In the match, G / Back still turns downward gravity off and on for everyone, players and ball. The pull back into the cube works either way | 2026-11-17 |
| D21 | Auto-reel | Modeled on the Q-Claw in *007: Agent Under Fire* multiplayer. Hold the grapple button: the hook flies out (400 m/s, was 200; let go before it lands to cancel). When it lands, the line pulls you toward the zip point at up to 45 m/s (was 30) with no gravity, keeps some of your sideways speed, and brakes so you stop and hang 1.5 m from its surface. Keep holding to hang there, moving with the cube. Let go any time to fly off with your speed. E / R2 lets the line out: the pull stops and it becomes a plain rope you swing on (Q/E change its length at 20 m/s, gravity applies). One button, no new ones. Replaces options A–C. The menu can turn the pull off (D25) | 2026-11-17 |
| D22 | Ball size and carrying | The menu picks Small, Medium or Large: 2, 3 or 5 m across. Default 3 m (tripled from 1 m on 2026-11-13). A carried ball rides just in front of the carrier, along their aim. It's hidden from the carrier's own camera (it would fill the screen); the HUD says "Ball YOURS" instead. Right after a throw it's also hidden from the thrower until it's 8 m away, so it doesn't flash across their view | 2026-11-17 |
| D23 | Main menu | The game opens on a menu: Grid Dimension (4, 6, 8, 10), Zip Points (Beams, Orbs), Zip Point Size, Gravity (Off, On), Ball Size, Goal Size, Grapple (Reel, Swing; D25), Environment (Classic, Space, Snow, Lava, Desert; D26) and Match (D15), then Start Game!. Match has two radio buttons, Time and Points, each followed by its number (minutes or points to win) between − and + buttons; only the chosen one's number can change. A mouse can also click the number and type one; keyboard and gamepad focus skip the text, so they can't get stuck editing it. A live preview of the cube changes with each choice. It remembers the last choices (`user://match_settings.cfg`); the first time, it shows the original game. M in a match returns to it. Works with a mouse, keyboard or gamepad | 2026-11-18 |
| D24 | Orbs | The other kind of zip point: a sphere wherever beams would cross, still a 3D grid. You can grapple them but never bump into them, so nothing kills your momentum; the ball flies through them too. The pull and hang work as on beams. Aim assist is 6° for orbs (3° for beams): an orb is a point and a beam is a line, so with 3° random shots found an orb about a third as often | 2026-11-17 |
| D25 | Grapple mode | The menu picks Reel (the auto-reel, D21; the default) or Swing: the hook lands as a plain rope at its current length and you swing on it under gravity, like the first prototype; Q / L2 reels in and E / R2 lets out. Hooking the ball reels it in either way | 2026-11-17 |
| D26 | Environments | Five venues, picked on the menu, each its own scene in `src/scenery/`: **Classic** (blue sky, green ground; unchanged), **Space** (stars, nebulae and a big banded planet below in place of a floor; glowing pale-blue zip points), **Snow** (pale sky, white fog, drifting snow floor, a ring of snowcapped peaks, snowfall; ice-blue zip points), **Lava** (red-orange sky and haze, a floor of crust with glowing, pulsing cracks, a ring of volcanoes with glowing craters, rising embers; gunmetal-gray zip points, which were hot iron until playtest 6 and blended into the reds) and **Desert** (deep blue sky over a sandy haze, dunes with shaded slip faces and wind ripples, a ring of layered red-rock mesas, blowing dust; weathered-wood brown zip points). Zip points never use a team color, so goals stand out. Presentation only: they never change play. Floors sit 420 m below the cube's center, and peaks ring it about 1.4–1.5 km out; they fade into their own haze, so the cube's fog doesn't hide them. Weather fills a box around the camera and stays put in the world, so it streams past as you fly. The sky, floor and peak shaders are in `assets/shaders/` | 2026-11-17 |
| D27 | Match HUD | Top center: each team's score in its color (yours labeled YOU), with the clock between them: time left, "+m:ss" and OVERTIME in overtime, or the time played and FIRST TO N in a points match. Big text in the upper middle, clear of the crosshair: the countdown (3, 2, 1, with "Get ready", "Faceoff" or "OVERTIME: next goal wins"), "GO!" fading out, "GOAL!" in the scoring team's color ("Teal scores" or "Own goal! Point to Orange"), and the result ("YOU WIN!" or "YOU LOSE", the final score, and "Press M for the menu" below the crosshair). Edge arrows (D18) stay clear of the scoreboard | 2026-11-18 |

## Arena geometry

All in the arena's own coordinates, centered on the cube's center. The numbers are for the default
grid (10 per side); the menu changes the grid, zip points and sizes (D23).

- The cube is 216 m across for every grid: beam lines at ±108 m on each axis and evenly between.
  With 10 per side they're at `-108, -84, ..., 84, 108` m (spacing 24 m).
- Beams along X, Y and Z through every pair of positions: 3 × 10 × 10 = 300 beams. Orbs instead sit
  at every crossing: 10 × 10 × 10 = 1000 orbs.
- The cube's center `(0, 0, 0)` is the middle of an open cell (every grid size is even), so the
  faceoff ball sits in open space.
- Goals sit in the open cell nearest two-thirds of the way along the main diagonal toward opposite
  corners. With 10 per side: goal A at `(-72, -72, -72)`, goal B at `(72, 72, 72)`, about 249 m apart.
- Spawns sit in the cell next to the center cell on each team's side: `(-24, -24, -24)` (team 0,
  goal A's side) and `(24, 24, 24)` (team 1). With 4 per side, that cell holds the goal, so the
  spawn is a quarter of a cell out from the center instead.
- Zip points are plain silver (D17). Default: beams 1 m thick (D19), goals 12 m across (D4).
- The ball (3 m across by default, D22) waits at the center, the faceoff spot. Get within 4 m of it
  to grab it, or hook it with the grapple to reel it in (D11). Hold RMB / R1 to charge a throw and
  let go to throw (D12). It stays frozen at the center until its first touch; respawning with the
  ball sends it back there, frozen.

## Controls

| Action | Keyboard and mouse | Gamepad |
|---|---|---|
| Aim | Mouse | Right stick |
| Air control (adds momentum while swinging or in the air) | WASD | Left stick |
| Fire grapple (hold: pulled in, then hang; let go to fly). At the ball: reels it in to you | Left mouse button | L1 |
| Let line out (Reel mode: stops the pull; then swing on a plain rope. Swing mode: lengthens the rope) | E | R2 |
| Reel in (on the plain rope) | Q | L2 |
| Throw (hold to charge) | Right mouse button | R1 |
| Respawn (prototype only; returns the ball to the center if you have it) | R | Start |
| Gravity on / off (testing only) | G | Back / Select |
| Back to the main menu | M | |
| Release / recapture mouse | Esc / click | |
| Fullscreen (prototype only) | F11 | |

**To play the current build:** double-click `play.cmd` in the project folder. It opens the main menu
(D23); pick settings and press Start Game!. A keyboard and mouse and the first gamepad both control
the one player. The match starts with a 3-second countdown and runs to the result (D15); with one
player on Teal, Orange scores only from own goals.

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
- [x] Playtest 4 changes: main menu with grid, zip point, gravity, ball and goal choices (D23); orbs (D24)
- [x] Playtest 5 changes: faster hook, pull and ball reel; Reel or Swing grapple (D25); Space, Snow and Lava venues (D26)
- [x] Playtest 6 changes: faster, straight throws (D12); gunmetal Lava zip points; Desert venue (D26)
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
- **2026-11-17, playtest 4:** The ball was still very hard to get, and with so many beams, bumping
  into them constantly killed momentum. The user proposed a bigger ball and grab range, hooking the
  ball with the line, bigger goals, and fewer beams or orbs you can't bump into, all chosen on a
  main menu. Built: the menu (D23), orbs (D24), hooking the ball (D11), 4 m grab range, and size
  choices for zip points, ball and goals (D4, D19, D22).
- **2026-11-17, playtest 5:** The ball is much easier to get now. The user asked for a faster hook
  and reel, a menu choice between the auto-reel and the old swinging rope, and three themed
  environments (space, snow/ice, lava/volcano) to pick on the menu. Built: hook 400 m/s, pull
  45 m/s, ball reel 60 m/s, Q/E 20 m/s (D21, D11); the Grapple choice (D25); four venues (D26).
- **2026-11-17, playtest 6:** Full-power throws were too slow, and too affected by momentum: the
  ball should fly straight where the crosshair points instead of drifting with the thrower's
  speed. The Lava zip points needed more contrast (gunmetal gray), and the user asked for a desert
  venue. Built: throws up to 100 m/s with no velocity added (D12), gunmetal Lava zip points, and
  the Desert venue (D26). While building the desert floor, the shared shader noise turned out to
  leave straight seams along its grid (a float hash rounding shared corners differently per cell);
  it now hashes in integers.

### Stage 2: ball and scoring (started)

Possession (proximity, snag, steal), charged throws, goals, faceoff, score.

- [x] Ball 3 m across; grab it within 2 m; it rides in front of the carrier (D11, D22)
- [x] Throwing (hold to charge, straight along your aim) and ball physics (D8, D12)
- [x] Hooking a loose ball reels it in to you; 4 m grab range (D11)
- [ ] Hooking the carrier steals it; cooldown after steals (D11). Needs a second player (Stage 3)
- [x] Goals and score (D13), faceoff and countdown (D14), match rules on the menu (D15, D23),
  scoreboard, banners and result screen (D27)

### Stage 3: two players

Side-by-side split screen, device assignment, a HUD per player (the one-player HUD already shows
the score, clock and result, D27). Match settings (time or points) are already on the menu (D15).

### Later

Online play (1v1, 3v3) through Steam, bots, real art (Blender pipeline), the rest of the menus
(the main menu exists, D23), audio.

## Tuning

Starting values. Adjust them in the files named here.

- **Movement and grapple:** `src/player/movement_tuning.tres` (open it in the Godot inspector).
  Gravity 9.8, air acceleration 8 m/s² up to 10 m/s, grapple range 80 m, aim assist 3°,
  line speed 20 m/s (was 10), line length 1.5–90 m, pipe bounce 0.3, top speed 60 m/s (was 45, raised so the
  faster pull isn't clipped), pull back 20 m/s² plus 4 m/s² per meter outside.
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
  - Orbs get their own aim assist, `orb_aim_assist_degrees` 6° (D24). Random shots from random
    spots, 10 per side, 80 m range (2026-11-17), found a target:
    - Small beams at 3°: 76%.
    - Orbs at 3°: 14% (small), 25% (medium), 41% (large).
    - Orbs at 6°: 45%, 59%, 69%.
    - Orbs at 10°: 82%, 88%, 92%.
    - With 6 per side, orbs stay under 40% even at 10°: from the middle of a 43 m cell, few orbs
      are in range.
  - Pull (D21): hook flies at 400 m/s (0 = instant). Pull speed 45 m/s, reached at 180 m/s²,
    which is also how hard it brakes before the zip point. Keeps half your sideways speed
    (`pull_keep_sideways` 0.5; 0 = dead straight like the Q-Claw, 1 = keep it all and curve around
    the zip point). Hangs `hang_gap` 1.5 m from the zip point's surface (2 m from a small beam's
    center line). Pull speed 0 turns the pull off (plain rope).
    Reaching a beam 45 m away takes about 1.3 s from the button press (0.1 s of hook flight,
    1.2 s of pull). Before 2026-11-17 (hook 200 m/s, pull 30 m/s at 120 m/s²) it took 1.9 s.
- **Arena spin:** exported on the Arena node in `src/arena/arena.tscn`. 2–6 degrees per second,
  new spin direction every 6–12 s, blended over 3 s.
- **Ball:** exported on the Ball node (`src/ball/ball.gd`). Radius from the menu (1.5 m default),
  pickup distance 4 m (from your center to the ball's surface). Throws: 1 s to full charge,
  15–100 m/s (was 15–50 plus your velocity), 0.5 s before the thrower can grab or hook it again.
  With gravity on, a full throw drops about 5 m over 100 m and 20 m over 200 m, a quarter of what
  a 50 m/s throw dropped over the same distance. Flight: bounce 0.6, pipe friction
  0.05, drag 0.02 per second, top speed 120 m/s (was 80); gravity and the pull back come from
  `movement_tuning.tres`. Hooked: reeled toward you at 60 m/s (on top of your speed), reached at
  300 m/s², no gravity (was 40 m/s at 200 m/s²).
- **Menu choices:** `src/match/match_settings.gd`. Grid sizes 4, 6, 8, 10. Radii for Small, Medium
  and Large: beams 0.5, 1, 1.5 m; orbs 1, 2, 3 m; ball 1, 1.5, 2.5 m; goals 4, 6, 9 m. Grapple: Reel
  or Swing. Environment: Classic, Space, Snow, Lava or Desert. Match: Time, 1–30 min (default 5),
  or Points, 1–25 (default 5); `MIN_MINUTES` and friends set the limits.
- **Match timing:** exported on the Match node (`src/match/match.gd`). Countdown 3 s, GOAL! pause
  2 s. Counted in ticks at the configured tick rate; the clock runs only during play.
- **Environments:** one scene each in `src/scenery/` (sky, sun, fog, floor, peaks, weather, zip point
  color and glow), shaders in `assets/shaders/`. Floors 420 m below the center, peaks about 1.4 km
  out (Desert mesas 1.5 km), their haze 0.0005 per meter (mesas 0.0003). Lava zip points: albedo
  (0.28, 0.33, 0.41) plus a gray glow (0.11, 0.13, 0.16); the glow keeps them steel gray under the
  orange light, which on its own turned them brown. Desert dunes: one crest every ~170 m, up to
  35 m tall, slip faces facing downwind (`Scenery.DUST_WIND`, the same way the dust blows).
- **Lattice:** exported on the Arena node (the menu overrides these). Cube 216 m across, 10 beams
  per side, beam radius 0.5 m (joints 1.6 times that), goal radius 6 m.
- **Rendering:** 4× MSAA (Project Settings → Rendering → Anti Aliasing), so thin, distant pipes
  don't shimmer. No shadows. Glow (bloom) is on in Space and Lava.

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
  size, or should it have fewer pipes per side (6 per side makes it 120 m)? The menu now keeps the
  cube at 216 m and changes the spacing instead.
- **Sparse grids and orbs.** With 4 or 6 per side, zip points are 72 or 43 m apart, close to the
  80 m grapple range, so there are few to aim at. Should range grow in sparse grids? Is 6° the right
  aim assist for orbs (see Tuning)?
- **Known issue: dark specks near the sun.** Looking toward the sun, a few single dark pixels show
  on the edges of thin, distant beams, in every venue (Classic too). Not specular (turning it off
  didn't help) and not the weather. Probably the 4x MSAA resolve against the very bright sky near
  the sun. Worth trying another anti-aliasing mode or a dimmer sun glow.
