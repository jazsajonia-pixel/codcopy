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
| Offline Team Deathmatch (5v5), Domination (5v5) and Free-For-All (8) vs bots | Playable, tested headless end-to-end |
| Offline Battle Royale (8-20 operators), Solo / Duo / Squad with AI teammates | Playable, tested headless end-to-end |
| Drivable vehicles (BR) | Implemented; physics tested headless, driven with injected touch input |
| LAN Team Deathmatch (2+ humans + bots) | Implemented; tested with **two processes on one machine** (localhost), not across real devices |
| Touch controls + HUD editor | Implemented; multi-touch verified with injected touch events (not on a physical phone) |
| Keyboard/mouse | Implemented; used for desktop play |
| Gamepad | Basic bindings exist; not tested with real hardware |
| Internet multiplayer | **Not implemented.** No servers, matchmaking or accounts; LAN only |
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
- The interact button changes with context: PICK / OPEN near loot, DRIVE / RIDE near a vehicle, REVIVE (hold) near a downed teammate.
- **Driving**: the joystick steers and accelerates, drag the right side to orbit the chase camera, BRAKE = handbrake,
  EXIT gets out. Weapon buttons are hidden while driving.
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
| Enter / exit vehicle | F or E | Handbrake | Space (while driving) |
| Revive teammate | hold F or E | | |

Click the game window to capture the mouse.

## Features

### Front end
- Main menu with profile name, level, XP bar, credits, and a 3D operator preview.
- Multiplayer select (mode, map, bot difficulty), Battle Royale select (Solo / Duo / Squad, lobby size, difficulty),
  Online (LAN) page (host, join by IP, player list, map, START LAN TEAM DEATHMATCH).
- **Loadout editor**: 3 saved loadouts; primary, secondary, melee, lethal, tactical; per-weapon attachments
  (optic, muzzle, barrel, grip, magazine, stock) and skins; stat bars with +/- comparison to the previous choice.
- **Operators**: 12 operators with 3D preview, unlocked by level.
- **Settings** (only settings that actually affect the game are shown): control scheme, sprint mode, ADS tap/hold,
  invert Y, aim assist (touch), simple-mode auto-fire, gyroscope (mobile only), camera / mouse / ADS / per-optic sensitivity,
  master / music / effects volume, graphics preset, render scale, shadows, effects quality, MSAA, FPS cap, FOV, FPS counter,
  enemy highlight color, hit marker size, camera shake, touch button size & opacity.
- Loading screen (tips; the match scene is loaded synchronously after the screen is drawn), results screen (outcome, K/D/A, score, headshots, accuracy, XP, credits,
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
- **First-person arms**: rigged CC0 arms ([WRAD Arms](https://github.com/wwwriks/wrad-arms)) posed with two-bone IK
  onto each gun's grip, trigger and support points. The support hand follows the magazine on reloads, works the pump
  or bolt between shots, and there are poses for throwing, healing / plating, knife jabs and unarmed punches.
  Pale or dark skin can be chosen in Settings > Graphics, and the sleeves are tinted to match the operator.

![First-person arms during a reload](docs/screenshots/arms_reload.jpg)

### Multiplayer (offline vs bots)
- **Team Deathmatch** (5v5, first to 40 or 8 minutes), **Domination** (5v5, flags A/B/C, first to 100) and
  **Free-For-All** (8 players, first to 20).
- Domination: stand in a flag's ring to capture it (faster with more teammates, frozen while contested); each held
  flag scores a point every 2 s. Bots push flags their team doesn't own and defend otherwise. Flag strip on the HUD
  and flags on the minimap.
- **UAV scorestreak**: 3 kills without dying reveals the enemy team on the minimap for 20 s (bots get it too).
- Maps: **Outpost** (desert compound) and **Crossroads** (urban intersection), built procedurally from Kenney kits.
- Pre-match countdown, spawn selection away from enemies, 3.5 s respawn, spawn protection, radar pings when firing unsuppressed.

![Domination: holding flag B](docs/screenshots/domination.jpg)

### LAN Team Deathmatch (experimental)
- One device hosts (**Online (LAN) > HOST LAN LOBBY**); others enter the host's IP and **JOIN** (port 24680, same Wi-Fi/LAN).
- The host picks Outpost or Crossroads and presses **START**. Every device loads the same map; teams alternate by join
  order and empty slots are filled with AI bots simulated on the host. Bots are always tagged `[BOT]`; humans show their
  profile name.
- How it works: each device simulates only its own player and sends its state 20 times per second; the host simulates
  the bots and relays everyone's state; other players are interpolated "puppets". The **host is authoritative** for
  health, deaths, kills, scores, respawns, the timer and the end of the match. Clients report their hits to the host,
  which checks them (sender owns the attacker, plausible distance/damage, rate limit) before applying damage.
- Shots and explosions are replayed as effects for everyone. If a player leaves, their puppet is removed; if the
  host leaves, clients get a "host disconnected" result and return to the menu. The pause menu doesn't stop a LAN match.
- Not provided: internet play, NAT traversal, dedicated servers, lag compensation, client-side damage prediction or
  anti-cheat. On high-latency networks shots can register late.

![LAN lobby](docs/screenshots/lan_lobby.jpg)

### Battle Royale (offline vs bots)
- **Isla Verde**: 400 m island with terrain, water and six POIs (Harbor Town, Depot, Farmstead, Radar Hill, Crossing, Pine Ridge).
- Boarding countdown, aircraft flight path, jump, free-fall, parachute (auto-deploys at low altitude or press JUMP).
- Ground loot (weapons + matching ammo, armor tiers 1-3, medkits, bandages, armor plates, grenades), supply crates at POIs, death boxes.
- 2-weapon inventory with swapping, shared ammo pools, health + armor, timed healing/plating.
- 5-phase shrinking safe zone with escalating damage, next-circle preview on minimap and full map (M).
- Alive counter, kill feed, placement, victory when last alive (or last squad standing).
- **Squads**: Solo, Duo or Squad (4). Your teammates are AI bots labelled `[BOT]`. In duos/squads a lethal hit knocks
  you **down** instead of killing you while a squadmate is still standing: you crawl, can't use weapons, and bleed out
  in 30 s. A teammate revives you by holding interact for 4 s. If the whole squad is down, the squad is eliminated.
  AI teammates jump with you, follow you, revive you and each other, and ride along as passengers when you drive.
  After you are eliminated you spectate a living teammate. HUD squad panel shows each teammate's health / DOWNED / OUT.
- **Vehicles**: 12 drivable vehicles on Isla Verde (SUV, sedan, pickup truck, patrol cruiser, van; Kenney Car Kit
  models) with real suspension physics, seats for passengers, a chase camera, an engine sound, health, smoke when
  damaged, and an explosion when destroyed (occupants are thrown out and take damage). Running over enemies hurts
  them; teammates and empty rolling cars don't. Bullets and explosions damage vehicles and pass part of the damage
  to the people inside. Vehicles show on the minimap. Bots don't drive (they only ride with you).

![Driving on Isla Verde](docs/screenshots/br_vehicle.jpg)
![Downed in a squad match](docs/screenshots/br_squad_downed.jpg)

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
scripts/player/            Player controller, input state, first-person view model and IK arms
scripts/ai/                Bot AI
scripts/combat/            Actor base class (health/armor/weapons), hitscan/melee/explosions
scripts/weapons/           WeaponData resource, WeaponInstance runtime, grenades
scripts/inventory/         Inventory (MP loadouts and BR pickups)
scripts/maps/              MapBuilder + Outpost, Crossroads, Isla Verde
scripts/multiplayer/       MatchBase, TDM/DOM/FFA rules and match, Domination flags,
                           NetworkManager (LAN lobby), NetSync (LAN match replication)
scripts/battle_royale/     BR match (solo/duo/squad), safe zone, loot, supply crates
scripts/vehicles/          Drivable vehicles (VehicleBody3D)
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
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- flow    # menu -> loading screen -> match with touch HUD (MP + BR + driving)
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- vehicle # vehicle physics, enter/exit, damage, run-over
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- squad   # BR squads: knock-down, revive, wipe, spectate
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- br_squad # full autoplayed squad BR match
godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- dom     # Domination + UAV
tests/run_net_test.sh                                                  # LAN TDM: host + client processes on localhost
```
Run them one at a time (they share the `user://test_tmp` folder). Exit code 0 means pass. The LAN test runs in real
time (about 2 minutes) and compares the final scores seen by the host and the client.
Results of the last run are in [docs/TEST_REPORT.md](docs/TEST_REPORT.md).

## Android export (not yet verified)

The repo includes an Android preset (`export_presets.cfg`: arm64-v8a, landscape sensor orientation, immersive mode,
INTERNET + ACCESS_NETWORK_STATE permissions for LAN play). To build an APK:

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

- **No internet play.** LAN Team Deathmatch only (same local network, host's IP typed in). There are no servers,
  accounts or matchmaking. LAN play was tested with two game processes on one machine, **not** between separate
  phones/PCs; Wi-Fi latency, packet loss and firewalls were not tested. Only TDM is networked (not Domination, FFA or BR).
- LAN has no lag compensation or anti-cheat; the host's validation only rejects implausible hit reports.
- Not tested on physical Android/iOS hardware; touch input was verified with synthetic events only.
- Low-poly CC0 art; arms have no hand-animated clips (poses are procedural IK), simple aircraft/parachute meshes.
- Character models have no per-weapon animations; third-person weapon holding is approximate. Downed bots are shown
  by tilting their model (no crawl animation).
- Bots never drive vehicles; there are no boats or helicopters. Vehicle handling is arcade-simple.
- One scorestreak (UAV) only; no ranked mode, no Hardpoint/Search & Destroy.
- Bot tactics are basic (simple cover selection, no squad tactics beyond follow / revive). Bots can occasionally get stuck on geometry.
- Gamepad bindings exist but were not tested with hardware.

## Next steps

1. Build and profile on real Android devices (low/medium/high presets), then tune draw distance and bot counts.
2. Test LAN play between real devices on Wi-Fi; add lag compensation and network Domination/FFA.
3. Hand-authored arm animations and weapon-specific third-person poses; crawl animation for downed operators.
4. Bots that drive, more maps and modes (Hardpoint), more scorestreaks.
