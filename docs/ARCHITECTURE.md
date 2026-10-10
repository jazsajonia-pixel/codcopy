# Architecture

Most content is built in code from small scripts; `.tscn` files are thin wrappers so the systems are easy to read,
diff and test.

## Autoloads (`scripts/autoload/`, plus NetworkManager)

| Autoload | Role |
|---|---|
| `SaveManager` | `user://profile.json` (name, XP, level, credits, unlocks, loadouts, operator, stats) and `user://settings.cfg` (all settings + touch HUD layout). Applies graphics/audio settings. |
| `GameDB` | Weapon, attachment, equipment, operator, skin and map tables; loads `resources/weapons/*.tres`. |
| `AudioManager` | Bus setup (Master/Music/SFX/UI), pooled 2D/3D one-shots, music. |
| `MatchConfig` | Settings for the next match (mode, map, difficulty, bot count) and the last match's results. |
| `Effects` | Tracers, impacts, muzzle flashes, explosions, smoke volumes (pooled). |
| `NetworkManager` | ENet LAN lobby: host, join, leave, peer names via RPC. No gameplay replication. |

## Gameplay

- `Actor` (`scripts/combat/actor.gd`, `CharacterBody3D`) — shared by the player and bots: health, armor, inventory,
  weapon firing, reload, grenades, melee, damage/death, spawn protection, flash blindness, stats.
- `Combat` — hitscan rays with spread, headshot detection (head hitbox), falloff, explosions with line-of-sight, melee.
- `WeaponData` (Resource) + `WeaponInstance` (runtime ammo/heat/bloom, attachments applied as multipliers).
- `Inventory` — two weapon slots + melee + lethal/tactical, BR ammo pools, meds/plates.
- `Player` — reads a `PlayerInput` state filled by keyboard/mouse, gamepad, or `TouchControls`; camera, ADS FOV,
  recoil, aim assist (touch only, slowdown + light magnetism), gyro, sprint/slide/crouch, `ViewModel` for first person.
- `FPArms` (`scripts/player/fp_arms.gd`) — rigged CC0 arms posed every frame with two-bone IK; `ViewModel` picks hand
  targets from named gun bones (trigger, rail, pump, magazine, bolt, slide) and drives reload/cycle/throw/heal poses.
- Squad knock-down lives in `Actor`: `can_be_downed` + `down_check`, `_knock()`, bleed-out in `tick_common`,
  `revive_tick(by, delta)` (single reviver, 4 s), `finish_off()`; signals `knocked` / `revived`.
- `Vehicle` (`scripts/vehicles/vehicle.gd`, `VehicleBody3D`) — Car Kit model with wheels moved under `VehicleWheel3D`,
  box collider, seats, `enter/exit/drive`, anti-roll torque, air drag, bumper `Area3D` for run-over damage (driver's
  enemies only), `take_vehicle_damage` (25% to occupants), explosion, chase camera. Vehicles don't collide with actors
  (layer 4 + world), actors do collide with vehicles.
- `Bot` — finite-state AI (patrol, investigate, engage, cover, heal, loot, zone, parachute, downed, revive, follow,
  mount) using
  `NavigationAgent3D`, perception (FOV cone + raycasts, smoke blocks LOS), difficulty-scaled reaction and aim error.

## Matches

- `MatchBase` — spawns actors, kill feed, scoring hooks, stats, results hand-off, pause.
- `MatchRules` — pure logic for TDM/Domination/FFA (score limits, `add_points`, time limit, winner); unit-tested without a scene.
- `MPMatch` — TDM/DOM/FFA flow: countdown, spawn selection, respawns; Domination flags (`DomFlag`, objective points
  for bots, `flag_states()` for HUD/minimap); LAN mode (see below). `MatchBase` also owns the UAV scorestreak.
- `BRMatch` — phases BOARDING → PLANE → ACTIVE → OVER; aircraft path, drop, loot spawning, `SafeZone`, crates, death
  boxes, vehicles, squads (teams of `br_squad_size`, teammates follow/drop with the player, wipe check, spectate,
  placement by squad).
- Maps (`scripts/maps/`) derive from `GameMap`, built by `MapBuilder` (terrain, CC0 kit props, colliders, spawns, navmesh bake).

## UI

- `main_menu.gd` + `pages/*` — each page is its own script; `UITheme` builds the shared theme.
- `hud.gd` (labels, bars, kill feed, scoreboard, pause), `hud_overlay.gd` (custom-drawn crosshair, hit markers, damage
  indicators, scope), `minimap.gd`, `touch_controls.gd` (per-finger ownership, floating joystick, editable layout),
  `hud_editor.gd`.
- `loading_screen.gd` draws the screen for two frames, then loads the match scene synchronously (threaded loading
  failed to resolve `hud.gd` on real runs, leaving matches without a HUD).

## LAN multiplayer

- `NetworkManager` (autoload) — ENet lobby (host / join by IP / peer list) and `start_lan_match()`: the host assigns
  teams (alternating by join order) and spawn slots, then `_begin` (RPC, call_local) configures `MatchConfig.net` and
  loads the match on every peer.
- `NetSync` (`scripts/multiplayer/net_sync.gd`, child of the match at `/root/MPMatch/NetSync` on every peer):
  - Clients send their own player state to the host (`_state`, 20 Hz, unreliable ordered).
  - The host sends one batch (`_bots`) with the host player, every bot, every remote player's latest state, the
    remote players' authoritative health/armor and the timer — only to peers whose match scene is loaded.
  - Remote actors are `Bot` nodes with `puppet = true` (AI off), interpolating to the received state.
  - Damage: a client hitting a puppet calls `report_hit` → host `_hit` validates (sender owns the attacker, attacker
    alive, distance < 260 m, amount ≤ 400, rate limit) and applies it. Host-side damage to a remote player's puppet is
    sent to its owner (`_hurt`) for the damage indicator.
  - Deaths (`_died`), respawns (`_respawn`), match end (`_end`) and player removal (`_remove`) are broadcast by the
    host; clients never run respawn timers or end the match themselves, so kill counts and scores stay identical.
  - Shots and explosions are replayed as effects (`_shot_fx`, `_explosion_fx`; client effects are relayed by the host).
- Bots use negative network ids; humans use their peer id.
- Not implemented: lag compensation, client-side prediction of damage, interest management, internet/NAT, dedicated
  servers, anti-cheat. Only TDM is networked.
