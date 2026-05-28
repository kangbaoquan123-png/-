extends SceneTree
func _initialize() -> void:
	var n=(load("res://node_2d.tscn") as PackedScene).instantiate()
	root.add_child(n)
	for i in range(30):
		await process_frame
	var masks = n.get("playfield_masks")
	for m in masks:
		print(m.name, m.offset_left, m.offset_top, m.offset_right, m.offset_bottom, " color=", m.color)
	var bg=n.get("background_rect")
	print("bg rect",bg.offset_left,bg.offset_top,bg.offset_right,bg.offset_bottom,"vis",bg.visible)
	quit()

