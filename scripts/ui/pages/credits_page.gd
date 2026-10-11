extends VBoxContainer
## Credits: original project + third-party asset attribution (full list in ASSET_CREDITS.md).

var menu: Control


func _ready() -> void:
	var t := RichTextLabel.new()
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.bbcode_enabled = true
	t.add_theme_font_size_override("normal_font_size", 18)
	t.text = """[b]Strike Ops: Frontline[/b] - an original, fan-made mobile FPS prototype built with Godot Engine. Not affiliated with or endorsed by Activision or any Call of Duty title; no assets from those games are used.

[b]3D models[/b]: Kenney (Blaster Kit, City Kit Commercial, Survival Kit, Mini Characters, Car Kit) - CC0. Flat Guns West / East by Pichuliru - CC0.
[b]Textures[/b]: Poly Haven (HDRI and ground/concrete textures) - CC0. Kenney Prototype Textures - CC0.
[b]UI[/b]: Kenney Crosshair Pack - CC0.
[b]Audio[/b]: Gunshot sounds by Vincent Sevedge (Tabasco) - CC-BY 3.0. Gun reload sounds by SpringySpringo - CC0. Kenney Impact, Interface and Sci-Fi Sounds - CC0. Menu music, wind ambience and dry-fire click generated for this project.
[b]Engine[/b]: Godot Engine - MIT license, (c) Godot Engine contributors.

Full list with URLs, licenses and conversions: ASSET_CREDITS.md in the repository."""
	add_child(t)
