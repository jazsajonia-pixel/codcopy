# Test Report

Environment for every result below: **Godot 4.7.2-stable (Linux x86_64)**, headless, run in a cloud Linux
container on 10 Oct 2026. Match suites use `--fixed-fps 60` (simulated time, not real time); the LAN test runs in
real time. Godot 4.7.3 does not exist yet, so nothing was tested on it. Screenshots were rendered under Xvfb with
`--rendering-driver opengl3` (Compatibility), **not** the Mobile Vulkan renderer the project is configured for.

## Tests that were run (latest round)

| Suite | What it checks | Result |
|---|---|---|
| Script/scene check (`godot --headless -s res://tests/check_scripts.gd`) | every script and scene parses and loads | 90 resources, 0 failures |
| `unit` | weapons, attachments, fire rate, reloads, falloff, inventory, BR ammo pools, heal/plate, XP/unlocks, save/load, TDM/FFA rules, safe zone, armor, no friendly fire, settings tabs | **42 passed, 0 failed** |
| `menus` | all main-menu pages open; loadout persists; BR SOLO/SQUAD buttons set the squad size; LAN host, START shown but disabled alone, map buttons, can't start alone, leave; HUD editor move/save/reset | **19 passed, 0 failed** |
| `touch` | injected multi-touch: buttons don't rotate the camera, FIRE holds trigger, joystick + fire together, look area, pause/resume | **9 passed, 0 failed** |
| `flow` | real path menu → MULTIPLAYER → START MATCH and BATTLE ROYALE → DEPLOY through the loading screen with the touch scheme; HUD script loaded, touch HUD visible, joystick moves the player; BR jump + landing; get in a vehicle, touch HUD switches to driving layout, joystick drives it (≈22 m), EXIT button leaves it | **18 passed, 0 failed** (fails on the pre-fix code, which reproduced the "no HUD / can't move" bug) |
| `tdm` / `ffa` | full autoplayed matches on Outpost / Crossroads (shortened limits) | **5/0** and **5/0** |
| `br` | full solo BR (boarding, jump, landing, looting, zone, eliminations, placement) | **8 passed, 0 failed** |
| `br_squad` | full autoplayed BR in squads of 4 (12 operators, 3 squads) to the results screen | **8 passed, 0 failed** (placed #2) |
| `vehicle` | real physics on flat ground: rests on wheels, enter/exit, accelerates (≈22 m/s), top speed, steering (67–94°), stays upright in hard turns, brakes, exit spot, run-over damages enemies only, bullet damage + 25% to occupants, explodes at 0 HP, ejects occupants, wreck can't be entered | **20 passed, 0 failed** |
| `squad` | squads of 4 in a real BR match: teammates follow the player and land near them; lethal damage knocks down; kill feed shows the knock; downed can't shoot; bleed-out; revive prompt; holding interact revives (35 HP); AI teammate walks over and revives the player; revives take the full 4 s (no stacking); squad wipe kills downed members; match continues while teammates live; spectating a teammate; placement by squad | **19 passed, 0 failed** (5 repeated runs passed after making the scenario deterministic) |
| `dom` | Domination rules (kills don't score, flag points, limit ends match); 3 flags spread over the map; bots capture a flag; held flags score; 3-kill streak gives a UAV; UAV expires after 20 s | **10 passed, 0 failed** |
| LAN (`tests/run_net_test.sh`) | **two separate Godot processes on one machine** over ENet/localhost: client joins lobby, host starts LAN TDM, both load the match and start together; each side sees the other human as a named puppet and 8 `[BOT]` bots (10 actors); remote movement replicated (45–57 m); remote shot effects received; client hit reports accepted by the host (9–15 per match, 0 rejected); kills scored; both reach the results screen; **final team scores identical on host and client** (e.g. 12-6, 12-9, 11-12 on three runs) | **host 13/0, client 13/0, scores match** |
| LAN disconnect (manual run) | client process killed ~25 s into the match | host kept running and finished the match normally |

Also run on **Godot 4.6.3** and **4.5.2**: script check (0 failures) and the `vehicle`, `squad` and `dom` suites all passed.

### Visual checks (screenshots, opengl3 under Xvfb at 1280x720)

Reviewed by eye this round: driving on Isla Verde (chase camera, vehicle HUD), BR squad downed state, the BR page,
the LAN lobby page, and Domination (flag ring, HUD flag strip, minimap flags). Plus first-person arm poses for every
weapon class (hip, ADS, reload, pump/bolt cycle, throw, heal, melee, unarmed). Problems found and fixed this way:
the BR page's DEPLOY button was pushed off-screen, a downed player still held the gun up, the squad panel was showing
in regular Multiplayer, and vehicle names read "Suv". Screenshots are in [`docs/screenshots/`](screenshots/).

### Bugs found by the tests this round (fixed)

- Loading screen used threaded loading; on real runs `hud.tscn` failed to load its script, so matches had **no HUD and
  no touch controls** (players couldn't move). Fixed with a synchronous load; the `flow` suite covers this path.
- `pointing/emulate_mouse_from_touch` was off, which would make menu buttons ignore taps on phones.
- Vehicles: a person entering a car pushed it into the air for one frame; empty rolling cars could kill; people
  stopped cars dead like walls; cars rolled over in hard turns.
- Squads: AI teammates preferred finishing off a downed enemy or running from the zone edge over reviving a teammate.
- LAN: bot network ids could collide with Godot's large random peer ids.

### Known warnings

- `ObjectDB instances leaked at exit` when the headless test runner quits mid-scene (test-only exit path).
- Navmesh bake warning that agent height was rounded up to the cell height; one "navigation map query before first
  synchronization" message at BR start.

## Not verified (no claims made)

- **Android**: no APK was built (no JDK/Android SDK/export templates in the environment). Install, launch,
  performance, thermal and memory on phones are untested.
- **Physical touchscreens**: multi-touch, driving and revive-by-holding were only tested with synthetic events.
- **LAN between separate devices**: only two processes on one machine (localhost). Wi-Fi latency, packet loss,
  firewalls/router isolation and more than 2 human players were not tested.
- **Gyroscope** aiming, **gamepad** bindings and **audio** quality (headless uses a dummy audio driver).
- **Mobile Vulkan renderer** on screen, and real-time frame rate on phones.
- **Full-length matches** with default timings (tests use shortened limits).
