extends SceneTree
func _initialize() -> void:
	var n = (load("res://node_2d.tscn") as PackedScene).instantiate()
	root.add_child(n)
	for i in range(2):
		await process_frame
	var bg: TextureRect = n.get_node("界面画布/界面根/背景图")
	bg.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	await process_frame
	print("bg expand=", bg.expand_mode, " stretch=", bg.stretch_mode)
	print("bg offsets=", bg.offset_left, ",", bg.offset_top, ",", bg.offset_right, ",", bg.offset_bottom)
	print("bg size=", bg.size)
	quit()

