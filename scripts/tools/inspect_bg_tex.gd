extends SceneTree

func _initialize() -> void:
	var n = (load("res://node_2d.tscn") as PackedScene).instantiate()
	root.add_child(n)
	for i in range(40):
		await process_frame
	var tex = n.get("background_rect").texture
	print("tex=",tex)
	if tex != null:
		print("size=",tex.get_width(),"x",tex.get_height())
		if tex is ImageTexture:
			(tex as ImageTexture).get_image().save_png("C:/baidunetdiskdownload/维多利亚/bg_from_runtime.png")
			print("saved_runtime_bg")
	print("loc=", n.get("state").current_location, " period=", n.get("state").time_period_name)
	quit(0)

