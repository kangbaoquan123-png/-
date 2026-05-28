extends SceneTree
func _initialize() -> void:
	var n=(load("res://node_2d.tscn") as PackedScene).instantiate(); root.add_child(n)
	for i in range(2): await process_frame
	var bg: TextureRect=n.get_node("界面画布/界面根/背景图")
	for m in [0,1,2,3,4,5]:
		bg.expand_mode = m
		for s in [0,2,3,4,5,6]:
			bg.stretch_mode = s
			await process_frame
			print("m",m," s",s," size=",bg.get_global_rect().size)
	print("offs",bg.offset_left,bg.offset_top,bg.offset_right,bg.offset_bottom)
	quit()

