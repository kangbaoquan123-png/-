extends SceneTree

func _initialize() -> void:
	var packed_v: Variant = load("res://node_2d.tscn")
	if not (packed_v is PackedScene):
		quit(1)
		return
	var node: Node = (packed_v as PackedScene).instantiate()
	root.add_child(node)
	for i in range(40):
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("C:/baidunetdiskdownload/维多利亚/frame_capture.png")
	print("saved")
	quit(0)

