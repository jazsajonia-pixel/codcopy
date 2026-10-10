# Test Report

Environment for every result below: **Godot 4.7.2-stable (Linux x86_64)**, headless, `--fixed-fps 60`
(simulated time, not real time), run in a cloud Linux container on 10 Oct 2026. Godot 4.7.3 does not exist yet, so
nothing was tested on it. Screenshots were rendered under Xvfb with `--rendering-driver opengl3` (Compatibility),
**not** the Mobile Vulkan renderer the project is configured for.

## Tests that were run

| Suite | Command (`godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- <suite>`) | Result |
|---|---|---|
| Script/scene check | `godot --headless -s res://tests/check_scripts.gd` | 79 resources loaded, 0 failures |
| `unit` | weapons load with models/sounds; attachment modifiers; fire rate (RPM) timing; semi-auto needs trigger release; reload refills from reserve; damage falloff; inventory slots/swap; BR ammo pools; heal/plate caps; XP/levels/unlocks; profile, settings and HUD layout save/load; TDM/FFA score limits and time limit; safe-zone shrink & damage; armor absorbs 75%; no friendly fire; settings page has 5 tabs | **42 passed, 0 failed** |
| `menus` | all 9 main-menu pages open; loadout change persists; LAN host on localhost then leave; HUD editor move/save/reset | **14 passed, 0 failed** |
| `tdm` | full Team Deathmatch on Outpost (shortened score limit), player driven by a test autopilot | **5 passed, 0 failed** — e.g. ended 9-12, player 146 shots, K/D/A 1/2/3, results screen reached |
| `ffa` | full Free-For-All on Crossroads | **5 passed, 0 failed** — player 216 shots, K/D/A 2/3/4 |
| `br` | full Battle Royale on Isla Verde (shortened phase timings): boarding, jump, parachute landing, looting a weapon, zone advancing, bot eliminations, placement | **8 passed, 0 failed** (placement varied 2nd-9th across runs) |
| `touch` | injected `InputEventScreenTouch/Drag`: touch scheme activates; holding a HUD button does not rotate the camera; FIRE holds the trigger; joystick moves while another finger fires; look area rotates the camera; releasing clears input; pause button opens pause; resume works | **9 passed, 0 failed** |

Match tests check: the match starts, bots move (navmesh paths), kills reach the kill feed, the player fights,
the match ends by rules, and the results screen gets correct stats.

### Visual checks (screenshots, opengl3 under Xvfb at 1280x720)

Reviewed by eye: main menu, loadout, settings, operators, HUD editor, TDM keyboard HUD, TDM touch HUD, BR aircraft,
parachute, BR ground, results. Bugs found and fixed this way: HUD overlay had zero size (crosshair drawn at the
corner), minimap not clipped, aircraft camera inside the fuselage, zone wall tinting the sky, overlapping touch
buttons, loadout list overflowing the screen. Screenshots are in [`docs/screenshots/`](screenshots/).

### Known warnings

- `ObjectDB instances leaked at exit` when the headless test runner quits mid-scene (harmless; test-only exit path).
- Navmesh bake warning that agent height was rounded up to the cell height.

## Not verified (no claims made)

- **Android**: no APK was built (no JDK/Android SDK/export templates in the environment). The export preset loads,
  and the export command fails only on the missing SDK. Install, launch, performance, thermal, and memory on phones are untested.
- **Physical touchscreens**: multi-touch was only tested with synthetic events. Real finger behavior, palm rejection,
  and the safe-area (notch) layout on actual devices are untested.
- **Gyroscope** aiming: code reads `Input.get_gyroscope()`; untested without a device.
- **Mobile Vulkan renderer**: the configured renderer was never rendered on screen here (only opengl3 for screenshots).
- **Real-time frame rate**: headless FPS numbers in the logs are meaningless for phones.
- **Full-length matches** with default timings (8-minute TDM, full BR zone schedule) were not run end to end; tests use shortened limits.
- **Gamepad** bindings: not tested with hardware.
- **LAN between two machines**: only localhost host/leave was tested. No gameplay is networked.
- **Audio** playback quality (headless uses a dummy audio driver).
