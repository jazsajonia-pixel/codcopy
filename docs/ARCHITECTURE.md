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
- `Bot` — finite-state AI (patrol, investigate, engage, cover, heal, loot, zone, parachute) using
  `NavigationAgent3D`, perception (FOV cone + raycasts, smoke blocks LOS), difficulty-scaled reaction and aim error.

## Matches

- `MatchBase` — spawns actors, kill feed, scoring hooks, stats, results hand-off, pause.
- `MatchRules` — pure logic for TDM/FFA (score limits, time limit, winner); unit-tested without a scene.
- `MPMatch` — TDM/FFA flow: countdown, spawn selection, respawns.
- `BRMatch` — phases BOARDING → PLANE → ACTIVE → OVER; aircraft path, drop, loot spawning, `SafeZone`, crates, death boxes, placements.
- Maps (`scripts/maps/`) derive from `GameMap`, built by `MapBuilder` (terrain, CC0 kit props, colliders, spawns, navmesh bake).

## UI

- `main_menu.gd` + `pages/*` — each page is its own script; `UITheme` builds the shared theme.
- `hud.gd` (labels, bars, kill feed, scoreboard, pause), `hud_overlay.gd` (custom-drawn crosshair, hit markers, damage
  indicators, scope), `minimap.gd`, `touch_controls.gd` (per-finger ownership, floating joystick, editable layout),
  `hud_editor.gd`.
- `loading_screen.gd` uses `ResourceLoader.load_threaded_request`.

## Online roadmap (not implemented)

1. Use `NetworkManager` lobby to start a LAN TDM: host is authoritative, clients send `PlayerInput` snapshots.
2. Replicate actors with `MultiplayerSynchronizer` (position, rotation, health, weapon state) and interpolate.
3. Server-side hit validation with lag compensation (rewind hitboxes by client RTT).
4. Dedicated server export (`--headless`) and a separate matchmaking/accounts service; only after that should any UI mention online play.
Until then the game only offers offline play against labelled AI bots.
