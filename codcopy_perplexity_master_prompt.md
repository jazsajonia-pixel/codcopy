# MASTER PROMPT: CODM-INSPIRED MOBILE FPS GAME — GODOT 4.7.3

## ROLE AND OBJECTIVE

Act as a senior Godot game developer, 3D FPS gameplay programmer, mobile game UI/UX designer, gameplay systems engineer, and technical artist.

Your mission is to build a functional, playable Call of Duty: Mobile (CODM)-inspired MVP using Godot Engine 4.7.3, with the project saved in my existing GitHub repository named `codcopy`.

The goal is to recreate the broad gameplay experience and major systems of a modern mobile military FPS, inspired by CODM's Multiplayer and Battle Royale modes. Use original or legally reusable assets and original branding. Do not use leaked, extracted, or unauthorized proprietary CODM assets.

Do not stop at a proposal, design document, mockup, or tutorial. Research, implement, integrate, test, and document the actual game files using the repository tools available to you.

## 1. FIRST: INSPECT THE REPOSITORY AND ENVIRONMENT

Before making changes:

1. Locate and inspect the `codcopy` repository.
2. Determine whether it is empty, partially developed, or already contains a Godot project.
3. Check the installed Godot version and available development tools.
4. Inspect the existing folder structure, scenes, scripts, assets, and project configuration.
5. Preserve useful existing work and avoid overwriting unrelated files.
6. Create a short implementation plan, then begin building immediately.

Use Godot 4.7.3-compatible APIs and project settings. If that exact engine version or an execution environment is unavailable, do not falsely claim compatibility testing. Identify the limitation and avoid silently switching to incompatible APIs.

## 2. RESEARCH AND COLLECT FREE GAME ASSETS

Search the web for real, downloadable assets that are free to use in a game. Do not merely list asset websites: identify suitable individual assets, verify their licenses, and integrate them into the project whenever the tools and permissions allow.

Prioritize:

- Kenney: https://kenney.nl/assets
- Poly Haven: https://polyhaven.com
- Quaternius: https://quaternius.com
- OpenGameArt: https://opengameart.org
- ambientCG: https://ambientcg.com
- Sketchfab: https://sketchfab.com — filter for downloadable assets and verify the individual license.
- Mixamo: https://www.mixamo.com — verify the applicable usage terms before using its characters or animations.
- Godot Asset Library: https://godotengine.org/asset-library/

Find suitable free assets for:

- Rigged, animated, low-poly or optimized 3D military-style characters.
- First-person arms, hands, and weapon-holding animations.
- Assault rifles, SMGs, shotguns, sniper rifles, pistols, and melee weapons.
- Reloading, firing, aiming, sprinting, jumping, crouching, sliding, and death animations.
- Military bases, urban environments, industrial zones, forests, deserts, roads, buildings, and terrain.
- Weapon icons, character portraits, inventory icons, UI elements, and crosshairs.
- Gunshots, reloads, footsteps, explosions, bullet impacts, ambient environments, UI sounds, and music.
- Parachutes, vehicles, loot containers, armor, ammunition, grenades, and equipment.
- Skyboxes, materials, textures, terrain assets, and environmental props.

### Asset requirements

For every selected asset, record:

- Asset name and direct download or source URL.
- License and permitted use.
- Attribution requirements.
- File format and compatibility with Godot.
- Any conversion or optimization required.

Prefer CC0, public-domain, or other clearly permissive assets. Never assume an asset is free simply because it can be downloaded.

Use GLB/glTF where appropriate. Convert or optimize unsupported assets when necessary. If an asset cannot be downloaded automatically, provide the exact link and a clearly documented import location.

Create an `ASSET_CREDITS.md` file containing the sources and licenses of every external asset.

If a suitable asset cannot be found, create a simple original placeholder rather than blocking development.

## 3. GAME STRUCTURE AND MENUS

Create a polished, responsive mobile FPS interface inspired by the usability of CODM without copying its proprietary artwork or branding.

Implement:

- Main menu and home screen.
- Player profile and level.
- Multiplayer mode selection.
- Battle Royale mode selection.
- Loadout and weapon customization.
- Operator/character selection.
- Weapon inventory and equipment screens.
- Settings.
- Matchmaking or match-launch screen.
- Match loading screen.
- In-game HUD.
- Match results, kills, deaths, assists, score, and rewards.
- Pause menu, resume, restart, and return-to-menu controls.
- Basic progression, experience, unlocks, and local save data.
- Sound, graphics, and gameplay settings.

Use clean military-themed visuals, readable typography, consistent spacing, responsive layouts, and appropriate touch targets. Avoid UI that only looks functional: buttons must perform their intended actions.

## 4. MULTIPLAYER FPS MODE

Build a playable first-person multiplayer-style mode with functional combat and bots.

Implement:

### Match systems
- Team Deathmatch as the primary mode.
- Free-for-All as an additional mode if feasible.
- Configurable match timer, score limit, kill feed, team scores, and respawning.
- Friendly and enemy identification.
- Bots that populate matches and keep the mode playable offline.
- Match start, active gameplay, victory/defeat, and results screens.

### First-person player controller
- First-person camera and mouse/touch look.
- Walking, running, sprinting, jumping, crouching, and sliding.
- ADS (aim down sights).
- Smooth acceleration, deceleration, and camera movement.
- Camera bob, recoil, weapon sway, and FOV settings.
- Collision detection, falling, death, and respawn.
- Weapon switching and equipment usage.

Make movement responsive and tune it for mobile devices.

### Gunplay
Implement functional weapon systems, not decorative weapon models:

- Hitscan or projectile-based firing as appropriate.
- Fire rate, damage, range, recoil, spread, and accuracy.
- Hip fire and ADS.
- Reloading with magazine and reserve ammunition.
- Empty-magazine behavior.
- Weapon switching and firing animations.
- Hit markers, hit reactions, kill notifications, and damage feedback.
- Headshots and damage multipliers.
- Muzzle flashes, shell casings where practical, bullet impacts, and tracer effects where appropriate.
- Suppressors or attachments when supported.
- Grenades and tactical equipment.
- Weapon-specific sounds and reload timing.

Create configurable weapon data so adding or balancing weapons does not require rewriting the entire combat system.

## 5. WEAPON LOADOUT AND CUSTOMIZATION

Create a working loadout system with:

- Primary weapon selection.
- Secondary weapon selection.
- Melee weapon.
- Lethal and tactical equipment.
- Weapon categories.
- Weapon statistics and comparison.
- Weapon skins or material variations.
- Attachment slots such as optics, muzzle, barrel, grip, magazine, and stock where appropriate.
- Magazine capacity and ammunition information.
- Loadout selection before a match.
- Persistence of player-selected loadouts.

Implement several distinct starter weapons with different characteristics. Add more only when the core weapon pipeline is reliable.

Unlocks can use local progression for the MVP; do not require paid items or real-money systems.

## 6. BATTLE ROYALE MODE

Build a separate, functional Battle Royale experience using an optimized map and the same shared player, weapon, inventory, and combat systems where possible.

Implement:

- A large explorable map with recognizable terrain and distinct locations.
- A match lobby or pre-match waiting area.
- A deployment phase and parachute descent.
- A shrinking safe zone.
- Damage outside the safe zone.
- Lootable weapons, ammunition, armor, healing items, grenades, and equipment.
- Ground loot and supply containers.
- Inventory management and weapon swapping.
- Health and armor systems.
- Healing and consumable usage.
- A minimap and safe-zone indicator.
- Remaining-player counter.
- Kill feed and elimination handling.
- AI-controlled opponents.
- Death, spectating or simplified observation, and match-end screens.
- Victory conditions when only one player or team remains.
- Basic vehicles only if performance and implementation time permit.

Use bots to make Battle Royale playable without online matchmaking. The bots must be able to explore, collect or equip weapons where practical, engage enemies, take damage, and be eliminated.

The MVP does not need a CODM-sized world. Build a smaller, well-designed map with multiple points of interest, cover, buildings, loot locations, and meaningful combat distances. Prioritize a complete playable match over map size.

## 7. MOBILE HUD AND TOUCH CONTROLS

The game must be designed for Android touchscreen gameplay, not simply a desktop FPS with a mobile label.

Implement:

- Left virtual joystick for movement.
- Right-side swipe area for camera rotation.
- Fire button.
- ADS button.
- Jump button.
- Crouch and slide controls.
- Reload button.
- Weapon-switch buttons.
- Grenade and equipment buttons.
- Interact and loot buttons for Battle Royale.
- Sprint behavior.
- Context-sensitive interaction.
- Configurable HUD layout.

Provide a HUD customization screen where players can:

- Drag and reposition supported controls.
- Resize buttons.
- Adjust button opacity.
- Restore the default layout.
- Save and reload their layout.
- Configure control visibility where appropriate.

Ensure touch controls work simultaneously. Prevent UI button presses from accidentally rotating the camera or moving the player. Support different aspect ratios and screen sizes, including phones with notches and safe areas.

Use virtual joystick and touch-drag input patterns appropriate for mobile FPS games.

## 8. SENSITIVITY AND GAMEPLAY SETTINGS

Create a working settings menu with persistent configuration.

Include:

- Camera sensitivity.
- ADS sensitivity.
- Optional per-optic sensitivity.
- Gyroscope aiming only if supported by the available Godot/mobile input setup.
- Invert vertical look.
- Aim behavior and aim-assist options.
- Sprint behavior.
- Auto-fire or firing assistance only if intentionally implemented.
- HUD button size and opacity.
- Master volume, music volume, and SFX volume.
- Graphics quality presets.
- Resolution scaling and 3D render scaling.
- Shadows, effects, and post-processing options.
- Frame-rate target options appropriate to the device.
- Basic accessibility and visual feedback options.

Do not expose settings that have no effect. Persist the values using a suitable configuration or save-data system.

## 9. BOT AI

Create reusable bot AI for both game modes.

Bots should support:

- Patrol and exploration.
- Enemy detection using distance, line of sight, and field of view.
- Navigation around obstacles.
- Moving toward combat or objectives.
- Choosing targets.
- Shooting with configurable accuracy and reaction time.
- Reloading.
- Taking cover when practical.
- Retreating or repositioning at low health.
- Taking damage, dying, and respawning in Multiplayer.
- Looting or equipping available items in Battle Royale where feasible.

Use NavigationAgent3D and suitable Godot navigation systems. Avoid giving bots perfect aim, unlimited ammunition, or impossible knowledge of the player's location.

Implement adjustable bot difficulty, reaction time, accuracy, aggression, and movement behavior.

## 10. AUDIO, ANIMATIONS, AND GAME FEEL

Integrate free, legally usable audio and animations.

Include:

- Weapon-specific gunfire.
- Reload sounds.
- Footsteps.
- Jump, landing, and sliding sounds.
- Hit and elimination feedback.
- Explosions and grenade sounds.
- UI interaction sounds.
- Background music for menus where suitable.
- Environmental ambience.
- First-person weapon animations.
- Third-person character locomotion.
- Shooting, reloading, jumping, crouching, death, and parachuting animations where available.

Use AudioStreamPlayer and AudioStreamPlayer3D appropriately. Configure attenuation, spatial audio, and sound levels.

If suitable animation assets are unavailable, use procedural movement, simple animation trees, or basic original animations. Do not let missing animation assets prevent functional gameplay.

## 11. CAMERA, VISUAL EFFECTS, AND PERFORMANCE

Create an optimized, attractive low-to-mid-fidelity 3D style suitable for mobile hardware.

Implement:

- First-person gameplay camera.
- ADS camera behavior.
- FOV settings.
- Recoil and camera shake.
- Smooth transitions between gameplay states.
- Third-person character presentation where appropriate.
- Death and match-result camera behavior.
- Basic muzzle flashes, impact effects, explosions, and particles.
- Directional lighting, baked or simplified lighting where practical, and optimized shadows.
- Level-of-detail strategies, occlusion or visibility optimization where appropriate, and sensible draw-call management.

Prioritize stable performance over realistic graphics. Provide Low, Medium, and High graphics presets where feasible.

Avoid unnecessarily large textures, excessive polygon counts, expensive real-time lighting, and uncontrolled particle spawning. Use object pooling for frequently spawned projectiles, effects, or other objects when useful.

## 12. GAME ARCHITECTURE

Use a modular, maintainable Godot project structure. Adapt it to the existing repository instead of creating duplicate systems.

Suggested structure:

- `project.godot`
- `scenes/menus/`
- `scenes/player/`
- `scenes/weapons/`
- `scenes/enemies/`
- `scenes/multiplayer/`
- `scenes/battle_royale/`
- `scenes/maps/`
- `scenes/ui/`
- `scripts/player/`
- `scripts/weapons/`
- `scripts/ai/`
- `scripts/multiplayer/`
- `scripts/battle_royale/`
- `scripts/inventory/`
- `scripts/settings/`
- `scripts/ui/`
- `resources/weapons/`
- `resources/items/`
- `assets/characters/`
- `assets/weapons/`
- `assets/maps/`
- `assets/animations/`
- `assets/audio/`
- `assets/ui/`
- `tests/`
- `docs/`
- `ASSET_CREDITS.md`
- `README.md`

Use reusable scenes, signals, resources, and data-driven configuration. Separate gameplay logic, UI, weapon data, bot behavior, and save data.

Avoid giant scripts that control the entire game. Use appropriate input actions and document the important systems.

## 13. ONLINE MULTIPLAYER: CLEARLY DEFINE THE MVP

The first priority is a complete offline-playable experience using bots.

Also assess the feasibility of actual online multiplayer. If possible, implement a small networking foundation with server-authoritative movement, combat validation, player synchronization, and a basic join/host flow.

Do not label bots as real online players.

If online multiplayer cannot be completed reliably within the available environment, implement clean networking boundaries and document the exact remaining work. Do not fabricate servers, matchmaking, or multiplayer functionality.

Keep the codebase ready for future online play without making the offline game dependent on a remote server.

## 14. REPOSITORY AND IMPLEMENTATION RULES

Work directly with the existing `codcopy` repository using the tools available to you.

- Save all project files, scripts, scenes, assets, documentation, and configuration in the repository.
- Make real file changes rather than returning code snippets only.
- Use small, logical commits or checkpoints if Git operations are available.
- Never overwrite unrelated work without inspection.
- Do not commit secrets, API keys, private credentials, or unnecessary large generated files.
- Avoid downloading assets from suspicious websites.
- Verify that downloaded files are valid and suitable for their intended use.
- Document any assets that still require manual download or import.
- Keep the project openable in Godot 4.7.3.
- Ensure the main scene is configured correctly.
- Keep the README updated with setup, controls, features, limitations, and Android export instructions.

If you cannot access the GitHub repository directly, explain the actual access limitation and provide the precise steps needed to connect it. Never claim to have modified or pushed files you could not access.

## 15. TESTING AND QUALITY ASSURANCE

Test each subsystem before integrating the next one.

Verify:

- The project opens and imports without critical errors.
- The main menu loads.
- Menu navigation and settings work.
- A match starts and ends correctly.
- Player movement, aiming, firing, reloading, and weapon switching work.
- Hit detection and damage are correct.
- Bots can navigate, fight, die, and respawn.
- Multiplayer score and timer logic work.
- Battle Royale deployment, loot, inventory, safe zone, and victory conditions work.
- Touch controls work on a touchscreen or through the closest available test environment.
- HUD customization and sensitivity settings persist.
- Audio plays correctly.
- No missing resources, broken scene references, or invalid scripts remain.
- Performance is reasonable for a mobile-oriented game.

Use automated tests, headless Godot checks, editor validation, or actual device testing where available. Clearly distinguish tests that were run from tests that remain unverified.

Do not claim Android compatibility merely because the game runs on desktop.

## 16. DEVELOPMENT PRIORITIES

Build in this order:

**Phase 1 — Project foundation**
- Repository inspection.
- Project setup.
- Asset research.
- Main menu.
- Player controller.
- Basic map and camera.

**Phase 2 — Core FPS gameplay**
- Weapons.
- Shooting and damage.
- Reloading.
- Health and death.
- Bots.
- Team Deathmatch.
- Respawning and match results.

**Phase 3 — Mobile experience**
- Touch controls.
- HUD.
- HUD editor.
- Sensitivity and settings.
- Audio and animations.
- Save data.

**Phase 4 — Battle Royale**
- BR map.
- Deployment and parachute.
- Loot and inventory.
- Armor and healing.
- Shrinking zone.
- BR bots and victory conditions.

**Phase 5 — Content and polish**
- More weapons.
- More characters and animations.
- Better maps and environments.
- Additional game modes.
- Improved effects, sound, and UI.
- Graphics presets and performance tuning.

**Phase 6 — Networking and release preparation**
- Assess or implement online multiplayer.
- Android export configuration.
- Final project validation.
- Documentation and remaining-task report.

You may adjust this order when technical dependencies require it, but always keep the project in a working state.

## 17. IMPORTANT EXECUTION RULES

1. Do not attempt to create every feature in one enormous, untested code-generation step.
2. Work incrementally, test each phase, and preserve working functionality.
3. Do not stop after writing a plan. Start implementing the first phase.
4. Reuse assets and shared systems wherever practical.
5. Prioritize playable systems over decorative placeholders.
6. If a feature is too expensive or technically impractical, implement a smaller functional version and document the limitation.
7. Do not invent asset links, licenses, test results, or repository changes.
8. Do not waste time recreating functionality that already exists in the repository.
9. Keep all implementation work inside `codcopy` unless a necessary tool-generated temporary file is clearly outside the project.
10. At the end of every phase, report completed features, files changed, tests performed, unresolved issues, and the next implementation step.

## FINAL ACCEPTANCE CRITERIA

The MVP is successful when:

- The project opens in Godot 4.7.3.
- A player can launch the game and navigate a functional menu.
- A playable first-person Team Deathmatch against bots works from start to finish.
- The player can move, aim, shoot, reload, switch weapons, die, and respawn.
- Weapons, loadouts, and settings are functional rather than visual mockups.
- Mobile touchscreen controls and customizable HUD functionality are implemented.
- A separate playable Battle Royale mode includes deployment, loot, combat, a shrinking safe zone, AI opponents, and victory conditions.
- Sound, animations, visual feedback, and performance optimizations are integrated to the extent supported by the available assets and development environment.
- Player settings and basic progression persist across sessions.
- The repository contains the actual game project, asset credits, setup instructions, and a truthful test report.

**Begin by inspecting `codcopy`, verifying the development environment, and identifying the first batch of free assets. Then implement and validate Phase 1. Continue through the phases without waiting for another prompt unless access, permissions, or a genuinely blocking decision requires my input.**
