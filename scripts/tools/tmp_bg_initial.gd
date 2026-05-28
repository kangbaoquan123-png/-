extends SceneTree
func _initialize() -> void:
	var n=(load("res://node_2d.tscn") as PackedScene).instantiate(); root.add_child(n)
	for i in range(10): await process_frame
	var bg: TextureRect=n.get_node("界面画布/界面根/背景图")
	print("initial expand",bg.expand_mode,"stretch",bg.stretch_mode,"size",bg.get_global_rect().size)
	quit()

