extends HBoxContainer
## Operator select with 3D preview. Operators unlock by level.

var menu: Control
var preview: OperatorPreview
var info: Label
var grid: GridContainer
var shown := ""


func _ready() -> void:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	scroll.add_child(grid)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	add_child(right)
	preview = OperatorPreview.new()
	preview.custom_minimum_size = Vector2(340, 380)
	right.add_child(preview)
	info = UITheme.label("", 18)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(340, 0)
	right.add_child(info)
	right.add_child(UITheme.button("EQUIP", _equip, Vector2(340, 64), "confirm"))
	_build()
	_show.call_deferred(str(SaveManager.profile.operator))


func _build() -> void:
	for c in grid.get_children():
		c.queue_free()
	for o in GameDB.OPERATORS:
		var locked: bool = int(SaveManager.profile.level) < int(o.unlock)
		var t: String = o.name + ("\nLVL %d" % o.unlock if locked else "\n" + o.faction)
		if o.id == SaveManager.profile.operator:
			t += "  *"
		var b := UITheme.button(t, func(): _show(o.id), Vector2(170, 72), "select")
		b.add_theme_font_size_override("font_size", 17)
		b.modulate = Color(0.6, 0.6, 0.6) if locked else Color.WHITE
		grid.add_child(b)


func _show(id: String) -> void:
	shown = id
	var o := GameDB.get_operator(id)
	preview.set_operator(id, SaveManager.current_loadout().primary)
	var locked: bool = int(SaveManager.profile.level) < int(o.unlock)
	info.text = "%s\n%s faction\n%s%s" % [o.name, o.faction, o.bio, "\nUnlocks at level %d" % o.unlock if locked else ""]


func _equip() -> void:
	var o := GameDB.get_operator(shown)
	if int(SaveManager.profile.level) < int(o.unlock):
		AudioManager.ui("error")
		return
	SaveManager.profile.operator = shown
	SaveManager.save_profile()
	_build()
