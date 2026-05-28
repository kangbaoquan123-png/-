extends SceneTree

const OUT_DIR := "C:/baidunetdiskdownload/blackjack_anim"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var log := FileAccess.open("C:/baidunetdiskdownload/blackjack_anim_log.txt", FileAccess.WRITE)
	if log != null:
		log.store_line("run start")
	var packed: PackedScene = load("res://node_2d.tscn")
	if packed == null:
		if log != null:
			log.store_line("scene load failed")
			log.close()
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.4).timeout
	if scene.has_method("_open_blackjack_game"):
		scene.call("_open_blackjack_game")
	await create_timer(0.9).timeout
	scene.blackjack_player_cards = [
		{"rank": 10, "suit": 0},
		{"rank": 7, "suit": 1},
		{"rank": 4, "suit": 2}
	]
	scene.blackjack_dealer_cards = [
		{"rank": 9, "suit": 3},
		{"rank": 6, "suit": 0},
		{"rank": 3, "suit": 1}
	]
	scene.blackjack_round_over = true
	scene.blackjack_reveal_dealer = true
	scene.blackjack_animating = false
	if scene.has_method("_blackjack_refresh_panel"):
		scene.call("_blackjack_refresh_panel")
	await create_timer(0.25).timeout
	if scene.has_method("_blackjack_start_round"):
		scene.call("_blackjack_start_round")
	for i in range(12):
		await create_timer(0.07).timeout
		var img: Image = root.get_texture().get_image()
		img.save_png("%s/frame_%02d.png" % [OUT_DIR, i])
	if log != null:
		log.store_line("saved")
		log.close()
	quit()
