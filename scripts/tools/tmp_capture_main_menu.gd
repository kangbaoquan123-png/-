extends SceneTree


func _initialize() -> void:
	var packed_v: Variant = load("res://main_menu.tscn")
	if not (packed_v is PackedScene):
		quit(1)
		return
	var node: Node = (packed_v as PackedScene).instantiate()
	root.add_child(node)
	for i in range(40):
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err: int = img.save_png("C:/baidunetdiskdownload/main_menu_capture.png")
	print("save", err)
	quit(0)

