extends Node
func _ready():
	var p := OperatorPreview.new()
	add_child(p)
	await get_tree().process_frame
	p.set_operator("op_ranger", "ar_m4k")
	for i in 5: await get_tree().process_frame
	var acc := [null]
	ActorModel._visible_aabb(p.model, Transform3D.IDENTITY, acc)
	print("scale ", p.model.model.scale, " aabb ", acc[0], " op ", GameDB.get_operator("op_ranger").model)
	var am := ActorModel.new(); add_child(am); am.setup(GameDB.get_operator("op_ranger").model)
	var acc2 := [null]; ActorModel._visible_aabb(am, Transform3D.IDENTITY, acc2)
	print("direct ", am.model.scale, acc2[0])
	get_tree().quit()
