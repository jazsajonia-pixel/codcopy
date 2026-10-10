# Strike Ops: Frontline

An original, playable mobile-first military FPS MVP built with **Godot 4.7**, inspired by the structure of
Call of Duty: Mobile (multiplayer modes, loadouts, Battle Royale, touch HUD). All branding, names and code are
original; all third-party assets are CC0 / CC BY and listed in [ASSET_CREDITS.md](ASSET_CREDITS.md).
Not affiliated with or endorsed by Activision.

> **Engine version note.** The brief asked for Godot **4.7.3**. At the time of writing that version does not exist —
> the latest stable release is [4.7.2-stable (18 Aug 2026)](https://github.com/godotengine/godot/releases).
> The project was built and tested with **Godot 4.7.2-stable**. It uses no 4.7.2-specific features, so a future
> 4.7.3 maintenance release should open it unchanged, but that has **not** been tested.

![Team Deathmatch on Outpost with the touch HUD](docs/screenshots/tdm_touch.jpg)

## Status at a glance

| Area | State |
|---|---|
| Offline Team Deathmatch (5v5) and Free-For-All (8) vs bots | Playable, tested headless end-to-end |
| Offline Battle Royale (8-20 operators) on Isla Verde | Playable, tested headless end-to-end |
| Touch controls + HUD editor | Implemented; multi-touch verified with injected touch events (not on a physical phone) |
| Keyboard/mouse | Implemented; used for desktop play |
| Gamepad | Basic bindings exist; not tested with real hardware |
| Online multiplayer | **Not implemented.** Only an experimental ENet LAN lobby (host/join/peer list) exists |
| Android build | Export preset included; **APK not built or tested** (no Android SDK/JDK in the build environment) |

## Getting started

1. Install Godot 4.7.x (standard build, not .NET) from https://godotengine.org/download.
2. Clone: `git clone https://github.com/jazsajonia-pixel/codcopy.git`
3. Open Godot, **Import** `codcopy/project.godot`. The first import takes a minute (GLB/texture import).
4. Press **F5**. The main scene is `res://scenes/menus/main_menu.tscn`.

Renderer: Mobile (Vulkan). On machines without Vulkan, run with `--rendering-driver opengl3`.

## Controls

### Touch (default on touchscreen devices)
- **Left side**: floating movement joystick. Push fully forward to auto-sprint; drag past the top to lock sprint.
- **Right side**: drag anywhere empty to look. Dragging on **FIRE** or **ADS** also aims (fire-and-steer).
- Buttons: FIRE (right, plus optional left FIRE), ADS, JUMP, CROUCH (tap while sprinting to slide), RELOAD, SWAP,
  FRAG (lethal), TACT (tactical), KNIFE (melee), PICK/OPEN (appears near loot), SPRINT, HEAL / PLATE (BR only), TAB (scoreboard), II (pause).
- Each finger is owned by exactly one control, so pressing a button never rotates the camera, and fire + move + look work simultaneously.
- Layout respects the device safe area (notches/cut-outs).
- **HUD editor** (Home > HUD LAYOUT, or Settings > Controls): drag to move, slider to resize, opacity, show/hide per button, Reset, Save. Saved to `user://settings.cfg`.

### Keyboard & mouse
| Action | Key | Action | Key |
|---|---|---|---|
| Move | WASD / arrows | Fire / ADS | LMB / RMB |
| Jump | Space | Crouch / slide | C or Ctrl |
| Sprint | Shift | Reload | R |
| Switch weapon | Q / 1 / 2 | Frag / tactical | G / T |
| Melee | V | Interact / loot | F or E |
| Heal / armor plate | H / X | Full map | M |
| Scoreboard | Tab (hold) | Pause | Esc / P |

Click the game window to capture the mouse.

## Features

### Front end
- Main menu with profile name, level, XP bar, credits, and a 3D operator preview.
- Multiplayer select (mode, map, bot difficulty), Battle Royale select (lobby size, difficulty).
- **Loadout editor**: 3 saved loadouts; primary, secondary, melee, lethal, tactical; per-weapon attachments
  (optic, muzzle, barrel, grip, magazine, stock) and skins; stat bars with +/- comparison to the previous choice.
- **Operators**: 12 operators with 3D preview, unlocked by level.
- **Settings** (only settings that actually affect the game are shown): control scheme, sprint mode, ADS tap/hold,
  invert Y, aim assist (touch), simple-mode auto-fire, gyroscope (mobile only), camera / mouse / ADS / per-optic sensitivity,
  master / music / effects volume, graphics preset, render scale, shadows, effects quality, MSAA, FPS cap, FOV, FPS counter,
  enemy highlight color, hit marker size, camera shake, touch button size & opacity.
- Loading screen (threaded load + tips), results screen (outcome, K/D/A, score, headshots, accuracy, XP, credits,
  level-ups, full scoreboard with bots labelled `[BOT]`), pause menu (resume, restart, sensitivity, quit).
- Progression: XP per kill/assist/score/win, levels up to 50, unlocks for weapons, attachments, operators and skins.
  Everything persists in `user://profile.json`. There are **no paid items**; credits are only a play reward.

### Gunplay
- 11 data-driven weapons (`resources/weapons/*.tres`): 2 ARs, 2 SMGs, LMG, 2 shotguns, bolt sniper, DMR, 2 pistols.
  Each defines damage, headshot multiplier, pellets, range/falloff, RPM, fire mode (auto / semi / pump / bolt),
  magazine, reserve, reload (tactical/empty), ADS time and FOV, hip/ADS/move spread, bloom, recoil and recovery, mobility.
- Hitscan with spread cone, damage falloff, headshots, wall penetration blocked, tracers, impacts, muzzle flash,
  hit markers (headshot/kill variants), damage direction indicators, kill feed, kill streak callouts.
- 15 attachments with real stat modifiers; suppressors hide you from the enemy radar.
- Frag, sticky charge, smoke (blocks bot vision), flash (blinds player and bots); melee knife/hatchet/baton.
- First-person view model with bob, sway, recoil kick, reload and switch animations, optic models, skin tint.

### Multiplayer (offline vs bots)
- **Team Deathmatch** (5v5, first to 40 or 8 minutes) and **Free-For-All** (8 players, first to 20).
- Maps: **Outpost** (desert compound) and **Crossroads** (urban intersection), built procedurally from Kenney kits.
- Pre-match countdown, spawn selection away from enemies, 3.5 s respawn, spawn protection, radar pings when firing unsuppressed.

### Battle Royale (offline vs bots)
- **Isla Verde**: 400 m island with terrain, water and six POIs (Harbor Town, Depot, Farmstead, Radar Hill, Crossing, Pine Ridge).
- Boarding countdown, aircraft flight path, jump, free-fall, parachute (auto-deploys at low altitude or press JUMP).
- Ground loot (weapons + matching ammo, armor tiers 1-3, medkits, bandages, armor plates, grenades), supply crates at POIs, death boxes.
- 2-weapon inventory with swapping, shared ammo pools, health + armor, timed healing/plating.
- 5-phase shrinking safe zone with escalating damage, next-circle preview on minimap and full map (M).
- Alive counter, kill feed, placement, victory when last alive.
- Vehicles are scenery only (not drivable) — not implemented for time/performance reasons.

### Bots
- States: patrol, investigate (hearing unsuppressed gunfire), engage, retreat to cover, heal, loot (BR), move to zone (BR), parachute (BR).
- Perception uses FOV cone + line of sight + view distance; smoke blocks vision; flashbangs blind them.
- Difficulty (easy / normal / hard) changes reaction time, aim error, FOV, view distance, burst length and aggression.
- Bots obey the same rules as the player: limited ammo and reloads, weapon spread/recoil, no wall-hacks.
- `NavigationRegion3D` navmesh baked at match start; `NavigationAgent3D` path following.

## Project layout

```
project.godot              Godot project (main scene: scenes/menus/main_menu.tscn)
export_presets.cfg         Android (arm64-v8a) export preset
scenes/                    Thin .tscn wrappers (menus, matches, maps, player, bot, HUD)
scripts/autoload/          SaveManager, GameDB, AudioManager, MatchConfig, Effects
scripts/player/            Player controller, input state, first-person view model
scripts/ai/                Bot AI
scripts/combat/            Actor base class (health/armor/weapons), hitscan/melee/explosions
scripts/weapons/           WeaponData resource, WeaponInstance runtime, grenades
scripts/inventory/         Inventory (MP loadouts and BR pickups)
scripts/maps/              MapBuilder + Outpost, Crossroads, Isla Verde
scripts/multiplayer/       MatchBase, TDM/FFA rules and match, NetworkManager (LAN lobby)
scripts/battle_royale/     BR match, safe zone, loot, supply crates
scripts/ui/                Menus, pages, HUD, touch controls, minimap, HUD editor
resources/weapons/         Weapon definitions (.tres) - edit these to tune gunplay
tests/                     Automated tests and screenshot helper
docs/                      Architecture notes, test report, screenshots
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the systems fit together.

## Running the tests

```bash
godot --headless -s res://tests/check_scripts.gd                       # parse/load every script & scene
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- unit    # 42 unit tests
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- menus   # menu pages, loadout, LAN host, HUD editor
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- tdm     # full TDM match, player driven by autopilot
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- ffa
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- br      # full BR match (shortened timings)
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- touch   # injected multi-touch input checks
```
Run them one at a time (they share the `user://test_tmp` folder). Exit code 0 means pass.
Results of the last run are in [docs/TEST_REPORT.md](docs/TEST_REPORT.md).

## Android export (not yet verified)

The repo includes an Android preset (`export_presets.cfg`: arm64-v8a, landscape sensor orientation, immersive mode,
INTERNET + ACCESS_NETWORK_STATE permissions for the LAN lobby). To build an APK:

1. Install **JDK 17** and the **Android SDK** (platform-tools, build-tools, an API 34+ platform), e.g. via Android Studio.
2. In Godot: **Editor > Editor Settings > Export > Android**, set the Java SDK path and Android SDK path.
3. **Editor > Manage Export Templates > Download and Install** (templates matching your Godot version).
4. Debug builds use Godot's auto-generated debug keystore. For release, create a keystore with `keytool` and fill
   *Keystore > Release* in the preset (keep `export_credentials.cfg` out of git — it is already ignored).
5. **Project > Export > Android > Export Project**, or from the command line:
   `godot --headless --export-debug "Android" build/StrikeOps-debug.apk`
6. Install with `adb install build/StrikeOps-debug.apk`.

In the authoring environment, step 5 fails with "A valid Java SDK path is required" because no JDK/SDK was installed,
so **no APK has been produced and the game has not been run on an Android device**. Expect to tune render scale,
bot count and BR lobby size for lower-end phones.

## Known limitations

- **No online play.** Teammates and opponents are always local AI bots and are labelled as bots. There are no servers,
  accounts or matchmaking. The LAN lobby only connects peers; it does not start or synchronise matches.
- Not tested on physical Android/iOS hardware; touch input was verified with synthetic events only.
- Placeholder art: low-poly CC0 kits, procedural first-person arms, simple aircraft/parachute meshes.
- Character models have no per-weapon animations; third-person weapon holding is approximate.
- Vehicles are static props. No squads/duos in BR, no killstreak rewards, no ranked mode.
- Bot tactics are basic (no team coordination, simple cover selection). Bots can occasionally get stuck on geometry.
- Gamepad bindings exist but were not tested with hardware.

## Next steps

1. Build and profile on real Android devices (low/medium/high presets), then tune draw distance and bot counts.
2. Networked gameplay on top of `NetworkManager`: server-authoritative movement/hit validation, replicated actors, LAN TDM first.
3. Proper first-person arms and animation set; weapon-specific third-person poses.
4. Drivable vehicles for BR, squads, more maps and modes (Domination, Hardpoint).
