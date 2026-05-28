extends SceneTree
func _initialize() -> void:
	var n=(load("res://node_2d.tscn") as PackedScene).instantiate(); root.add_child(n)
	for i in range(10): await process_frame
	var bg: TextureRect=n.get_node("界面画布/界面根/背景图")
	print("scale=",bg.scale," custom_min=",bg.custom_minimum_size," min=",bg.get_minimum_size())
	print("global",bg.get_global_rect()," parent",(bg.get_parent() as Control).size)
	quit()

