class_name DifficultyRow
extends HBoxContainer
## Easy / Normal / Hard bot difficulty toggle, persisted in settings.


static func make() -> DifficultyRow:
	return DifficultyRow.new()


func _ready() -> void:
	var btns := {}
	for d in ["easy", "normal", "hard"]:
		var b := UITheme.button(d.capitalize(), func():
			SaveManager.set_setting("bots", "difficulty", d)
			SaveManager.save_settings()
			for k in btns.keys():
				btns[k].set_pressed_no_signal(k == d), Vector2(160, 60), "select")
		b.toggle_mode = true
		b.set_pressed_no_signal(SaveManager.get_setting("bots", "difficulty", "normal") == d)
		btns[d] = b
		add_child(b)
