extends SceneTree

func _initialize() -> void:
	var packed_v: Variant = load("res://node_2d.tscn")
	if not (packed_v is PackedScene):
		print("[smoke] scene load failed")
		quit(1)
		return
	var packed: PackedScene = packed_v as PackedScene
	var game_node: Node = packed.instantiate()
	root.add_child(game_node)

	for i in range(12):
		await process_frame

	var guard: int = 0
	while String(game_node.get("mode")) != "chat" and guard < 180:
		if game_node.has_method("_on_next_pressed"):
			game_node.call("_on_next_pressed")
		await process_frame
		guard += 1

	if String(game_node.get("mode")) != "chat":
		print("[smoke] cannot enter chat mode")
		quit(2)
		return

	await _ensure_input_ready(game_node)

	var prompts: Array[String] = ["现在几点", "今天几号", "今天星期几"]
	for prompt in prompts:
		await _send_prompt(game_node, prompt)

	game_node.call("_open_game_menu", "save")
	for j in range(4):
		await process_frame
	game_node.call("_on_save_page_pressed", 2)
	game_node.call("_on_save_slot_pressed", 0)
	game_node.call("_on_save_panel_save_pressed")
	for k in range(4):
		await process_frame
	game_node.call("_on_game_menu_nav_pressed", "load")
	game_node.call("_on_load_page_pressed", 2)
	game_node.call("_on_load_slot_pressed", 0)
	game_node.call("_on_game_menu_nav_pressed", "settings")
	game_node.call("_on_settings_skip_pressed")
	game_node.call("_on_settings_auto_pressed")
	game_node.call("_on_settings_display_pressed")
	game_node.call("_on_settings_display_pressed")
	game_node.call("_close_modal_panels")
	for m in range(3):
		await process_frame

	game_node.call("_toggle_room_nav")
	await process_frame
	game_node.call("_on_next_pressed")
	await process_frame

	await _ensure_input_ready(game_node)
	game_node.call("_on_end_turn_pressed")
	for n in range(10):
		await process_frame
	if bool(game_node.get("typing_active")):
		game_node.call("_on_next_pressed")
		await process_frame
	game_node.call("_on_next_pressed")

	for t in range(240):
		await process_frame
		if bool(game_node.get("typing_active")):
			game_node.call("_on_next_pressed")
		elif _dialogue_has_text(game_node) and bool(game_node.get("pending_period_intro")):
			game_node.call("_on_next_pressed")

	var state_v: Variant = game_node.get("state")
	if state_v != null:
		print("[smoke] day=", state_v.living_days, " period=", state_v.time_period_name, " time=", state_v.display_time)
	print("[smoke] done")
	quit(0)


func _ensure_input_ready(game_node: Node) -> void:
	for i in range(24):
		if _input_ready(game_node):
			return
		game_node.call("_on_next_pressed")
		await process_frame


func _input_ready(game_node: Node) -> bool:
	var input_v: Variant = game_node.get("input_line")
	if not (input_v is LineEdit):
		return false
	var input_line: LineEdit = input_v as LineEdit
	var row_v: Variant = game_node.get("input_row_margin_ref")
	if not (row_v is Control):
		return false
	var row: Control = row_v as Control
	return input_line.editable and row.visible


func _dialogue_has_text(game_node: Node) -> bool:
	var dialogue_v: Variant = game_node.get("dialogue_label")
	if not (dialogue_v is Label):
		return false
	var dialogue_label: Label = dialogue_v as Label
	return not dialogue_label.text.strip_edges().is_empty()


func _send_prompt(game_node: Node, prompt: String) -> void:
	await _ensure_input_ready(game_node)
	var input_v: Variant = game_node.get("input_line")
	if not (input_v is LineEdit):
		return
	var input_line: LineEdit = input_v as LineEdit
	input_line.text = prompt
	game_node.call("_on_send_pressed")
	for i in range(14):
		await process_frame
	if bool(game_node.get("typing_active")):
		game_node.call("_on_next_pressed")
		await process_frame
	print("[smoke] sent=", prompt)

