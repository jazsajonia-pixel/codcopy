# Asset Credits

Every third-party file shipped in this repository is listed below with its source, license and any conversion applied.
No assets were extracted, ripped or copied from Call of Duty: Mobile or any other commercial game. Names, logos and
branding ("Strike Ops: Frontline", weapon and operator names) are original to this project.

License summary:

- **CC0 1.0** (public domain dedication) — https://creativecommons.org/publicdomain/zero/1.0/ — attribution not required; credited anyway.
- **CC BY 3.0** — https://creativecommons.org/licenses/by/3.0/ — attribution required (given below and in the in-game Credits page).

## 3D models

| Asset (repo path) | Source | Author | License | Format | Conversion / changes |
|---|---|---|---|---|---|
| `assets/weapons/guns/*.glb` (11 files: `Rifle_Assault_West/East`, `Rifle_Battle_East`, `SMG_Full_West`, `SMG_Compact_West`, `Shotgun_Pump_West`, `Shotgun_Auto_East`, `Sniper_Rifle_West/East`, `Pistol_Full_West`, `Pistol_Compact_East`) | [CC0 Flat Guns West](https://opengameart.org/content/cc0-flat-guns-west) and [CC0 Flat Guns East](https://opengameart.org/content/cc0-flat-guns-east) (OpenGameArt) | Pichuliru | CC0 | GLB | None to the files. Scaled/rotated at runtime; optional tint overlay for weapon skins. |
| `assets/weapons/grenade-a.glb`, `grenade-b.glb`, `assets/weapons/Textures/colormap.png` | [Blaster Kit](https://kenney.nl/assets/blaster-kit) | Kenney | CC0 | GLB + PNG | None. |
| `assets/characters/character-{male,female}-{a..f}.glb`, `assets/characters/Textures/colormap.png` | [Mini Characters](https://kenney.nl/assets/mini-characters) | Kenney | CC0 | GLB + PNG | None. Scaled 2.65x at runtime; built-in animations (idle, walk, sprint, die, holding-both, ...) used. |
| `assets/maps/city/*.glb` (building-a..h, building-skyscraper-a/b, detail-awning) + `Textures/colormap.png` | [City Kit (Commercial)](https://kenney.nl/assets/city-kit-commercial) | Kenney | CC0 | GLB + PNG | None. Scaled 9x at runtime; box colliders generated from mesh bounds. |
| `assets/maps/survival/*.glb` (barrel, box, box-large, chest, fence-fortified, rock-a/b/c, structure-metal, structure-metal-wall, tent, tree, tree-tall, tree-autumn) + `Textures/colormap.png` | [Survival Kit](https://kenney.nl/assets/survival-kit) | Kenney | CC0 | GLB + PNG | None. Scaled at runtime. `chest.glb` is used for BR supply crates. |
| `assets/vehicles/*.glb` (suv, truck, sedan, van, delivery, police, cone, box) + `Textures/colormap.png` | [Car Kit](https://kenney.nl/assets/car-kit) | Kenney | CC0 | GLB + PNG | None. Used as static cover props (vehicles are not drivable). |

| `assets/arms/arms.glb`, `arm_albedo_pale.png`, `arm_albedo_dark.png` (+ `LICENSE-CC0.txt`) | [WRAD Arms](https://github.com/wwwriks/wrad-arms) (also on [itch.io](https://wriks.itch.io/wrad-arms)), commit `f398724` | wriks | CC0 | GLB + PNG | None to the files. Posed at runtime with code-driven two-bone IK and finger curl; sleeves are procedural meshes attached to the arm bones. The asset has no animations; all first-person animations are procedural. |

Procedural content (no external asset): uniform sleeves on the first-person arms, house shells, walls, ramps, towers, terrain heightmap,
water plane, aircraft, parachute canopy, loot boxes, zone wall, all HUD graphics (crosshair, hit markers, minimap,
touch buttons) are generated in code.

## Textures and lighting

| Asset | Source | Author | License | Format | Conversion |
|---|---|---|---|---|---|
| `assets/textures/sky_kloofendal_1k.hdr` | [Kloofendal 48d Partly Cloudy (Pure Sky)](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky) | Poly Haven | CC0 | HDR (1k) | Renamed. Used as panorama sky + ambient light. |
| `assets/textures/aerial_grass_rock_diff_1k.jpg` | [Aerial Grass Rock](https://polyhaven.com/a/aerial_grass_rock) | Poly Haven | CC0 | JPG (1k diffuse) | Renamed only. |
| `assets/textures/concrete_floor_worn_001_diff_1k.jpg` | [Concrete Floor Worn 001](https://polyhaven.com/a/concrete_floor_worn_001) | Poly Haven | CC0 | JPG (1k diffuse) | None. |
| `assets/textures/dry_ground_01_diff_1k.jpg` | [Dry Ground 01](https://polyhaven.com/a/dry_ground_01) | Poly Haven | CC0 | JPG (1k diffuse) | None. |

## Audio

| Asset | Source | Author | License | Format | Conversion |
|---|---|---|---|---|---|
| `assets/audio/weapons/ar_shot.ogg`, `smg_shot.ogg`, `pistol_shot.ogg`, `sniper_shot.ogg`, `shotgun_shot.ogg`, `lmg_shot.ogg` | [Gunshot Sounds](https://opengameart.org/content/gunshot-sounds) (OpenGameArt) | Vincent Sevedge ("Tabasco") | **CC BY 3.0** (per the `creativecommons.txt` bundled in the download: "Copyright (c) 2009 Vincent Sevedge ... Creative Commons Attribution 3.0 Unported"; the OpenGameArt page lists CC0 — the stricter bundled license is followed) | WAV -> OGG Vorbis | Single shots trimmed with ffmpeg from `sks.wav`, `cz.wav`, `mosin.wav`, `shotty.wav`; down-mixed to mono; fade-out added; `smg_shot` pitched up 15%, `lmg_shot` pitched down 12%. |
| `assets/audio/weapons/reload_rifle.ogg`, `reload_pistol.ogg`, `shotgun_pump.ogg` | [Gun Reload Sounds](https://opengameart.org/content/gun-reload-sounds) | SpringySpringo | CC0 | WAV -> OGG | Mono, re-encoded (`assaultriflereload1_0.wav`, `gunreload1.wav`, `shotguncock_0.wav`). |
| `assets/audio/sfx/hitmarker.ogg`, `killconfirm.ogg`, `bullet_impact.ogg`, `land.ogg`, `loot_pickup.ogg`, `melee.ogg`, `assets/audio/footsteps/footstep_{concrete,grass}_00{0-4}.ogg` | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 | OGG | Renamed (from impactMetal_light_000, impactPlate_heavy_000, impactGeneric_light_000/002, impactPlank_medium_000, impactMetal_medium_000, footstep_*). |
| `assets/audio/sfx/explosion.ogg`, `explosion_low.ogg`, `zone_warning.ogg` | [Sci-Fi Sounds](https://kenney.nl/assets/sci-fi-sounds) | Kenney | CC0 | OGG | Renamed (from explosionCrunch_000, lowFrequency_explosion_000, forceField_000). |
| `assets/audio/ui/*.ogg` (click_001/002, confirmation_001, back_001, error_001, select_001, switch_002, toggle_001) | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 | OGG | None. |
| `assets/audio/music/menu_music.ogg`, `assets/audio/ambience/wind.ogg`, `assets/audio/weapons/dryfire.ogg` | Original, generated for this project (procedural synthesis with Python/NumPy, encoded with ffmpeg) | This project | Same license as the project code | OGG | — |

## Engine and fonts

- [Godot Engine](https://godotengine.org) — MIT license, (c) Godot Engine contributors. The UI uses Godot's built-in default font.

## Evaluated but not used

- [Quaternius Ultimate Gun Pack](https://opengameart.org/content/low-poly-guns-pack) (CC0) — FBX only; Flat Guns GLB used instead.
- Kenney Blocky Characters, Kenney Crosshair Pack, Kenney Prototype Textures (CC0) — downloaded during research, not shipped.
- Mixamo was not used.
