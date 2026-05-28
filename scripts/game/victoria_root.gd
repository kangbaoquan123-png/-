extends "res://scripts/game/victoria_ai_flow.gd"

func _ready() -> void:
	rng.randomize()
	_build_ui()
	_load_audio()
	if has_method("_sync_settings_ui_from_audio"):
		call("_sync_settings_ui_from_audio")
	http_request = HTTPRequest.new()
	http_request.timeout = 180.0
	add_child(http_request)
	memory_http_request = HTTPRequest.new()
	memory_http_request.timeout = 120.0
	add_child(memory_http_request)
	memory_service.attach_http_request(memory_http_request)
	web_http_request = HTTPRequest.new()
	web_http_request.timeout = 30.0
	add_child(web_http_request)
	web_service.attach_http_request(web_http_request)
	var startup_menu_page: String = _consume_startup_menu_page()
	var startup_load_slot_index: int = _consume_startup_load_slot_index()
	var startup_force_new_game: bool = _consume_startup_force_new_game()

	if not _load_story():
		_show_line("系统", "加载剧情文件失败：data/prologue_story.json", true)
		return

	var loaded_requested_slot: bool = false
	if startup_load_slot_index > 0:
		loaded_requested_slot = _load_from_slot(startup_load_slot_index)
	var loaded_runtime_state: bool = false
	if not loaded_requested_slot and startup_load_slot_index <= 0 and not startup_force_new_game:
		loaded_runtime_state = _load_runtime_state()

	if loaded_requested_slot or loaded_runtime_state:
		# Default to clean player-facing UI each launch; debug can still be opened via F8.
		state.debug_panel_open = false
		state.slot_id = "runtime_save"
		mode = "chat"
		current_label = "main_room"
		current_index = 0
		_apply_scene_by_state()
		var restored_profile: Dictionary = state.v_reply_expression_profile.duplicate(true) if typeof(state.v_reply_expression_profile) == TYPE_DICTIONARY else {}
		if not restored_profile.is_empty():
			var restored_sprite: String = String(restored_profile.get("sprite", "")).strip_edges()
			if restored_sprite.ends_with(".png"):
				restored_sprite = restored_sprite.trim_suffix(".png")
			if restored_sprite.is_empty():
				restored_sprite = "everyday"
			restored_profile["sprite"] = restored_sprite
			if not restored_profile.has("mood"):
				restored_profile["mood"] = state.v_sprite_mood
			_apply_character_expression(restored_profile)
		else:
			_set_character_by_mood(latest_mood)
		_sync_period_music(0.2)
		if loaded_requested_slot:
			_show_line("系统", "已读取存档槽 %s，可以继续游戏。" % str(startup_load_slot_index), true)
		else:
			if runtime_state_was_sanitized:
				_show_line("系统", "检测到旧存档文本异常，已自动清理损坏记忆缓存。现在可以正常对话了。", true)
			else:
				_show_line("系统", "已恢复上次进度，你可以继续聊天。", true)
		_update_hud()
		_update_interaction_state(false)
		if mode == "chat" and not state.period_initiative_done:
			pending_period_intro = true
		if runtime_state_was_sanitized:
			_save_runtime_state()
		if has_method("_capture_unsaved_baseline"):
			call("_capture_unsaved_baseline")
		_open_requested_game_menu(startup_menu_page)
		return

	_jump_to_label(String(story_data.get("start_label", "")))
	state.debug_panel_open = false
	state.slot_id = "runtime_save"
	state.refresh_save_cutoff()
	_apply_scene_by_state()
	_set_character_by_mood("日常")
	_sync_period_music(0.2)
	_update_hud()
	_update_interaction_state(false)
	_advance_story()
	if has_method("_capture_unsaved_baseline"):
		call("_capture_unsaved_baseline")
	if startup_load_slot_index > 0 and not loaded_requested_slot:
		_show_notify("未找到存档槽 %s，已进入新游戏。" % str(startup_load_slot_index))
	_open_requested_game_menu(startup_menu_page)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_method("_restore_unsaved_baseline"):
			call("_restore_unsaved_baseline")


func _process(delta: float) -> void:
	if ai_waiting_active and ai_waiting_label != null:
		waiting_indicator_accum += delta
		var dots: int = int(floor(waiting_indicator_accum * 2.6)) % 4
		ai_waiting_label.text = "%s%s" % [ai_waiting_message, ".".repeat(dots)]

	if typing_active:
		typing_accumulator += delta * TYPEWRITER_CPS
		var next_chars: int = int(floor(typing_accumulator))
		if next_chars > typing_visible_chars:
			typing_visible_chars = min(next_chars, typing_full_text.length())
			dialogue_label.text = typing_full_text.substr(0, typing_visible_chars)
			if typing_visible_chars >= typing_full_text.length():
				typing_active = false
				typing_accumulator = 0.0
		if typing_active:
			return

	if not quick_skip_enabled and not quick_auto_enabled:
		quick_advance_accum = 0.0
		return
	if modal_ui_open or state.room_nav_open:
		quick_advance_accum = 0.0
		return
	if transition_active:
		quick_advance_accum = 0.0
		return
	if waiting_for_choice or ai_waiting_active:
		quick_advance_accum = 0.0
		return
	var interval: float = 0.08 if quick_skip_enabled else 1.1
	quick_advance_accum += delta
	if quick_advance_accum < interval:
		return
	quick_advance_accum = 0.0
	_on_next_pressed()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		if modal_ui_open:
			return
		if _consume_transition_click_from_input():
			get_viewport().set_input_as_handled()
			return
		if blackjack_active:
			var blackjack_hovered: Control = get_viewport().gui_get_hovered_control()
			if not _is_click_on_interactive_control(blackjack_hovered):
				get_viewport().set_input_as_handled()
			return
		var hovered: Control = get_viewport().gui_get_hovered_control()
		if _is_click_on_interactive_control(hovered):
			return
		_on_next_pressed()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	if blackjack_active:
		match key_event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				var blackjack_chat_ready: bool = blackjack_input_line != null and blackjack_input_line.visible and blackjack_input_line.editable
				var blackjack_chat_text: String = ""
				if blackjack_input_line != null:
					blackjack_chat_text = blackjack_input_line.text.strip_edges()
				if blackjack_chat_ready and (blackjack_input_line.has_focus() or not blackjack_chat_text.is_empty()):
					_on_send_pressed()
				elif has_method("_on_blackjack_hit_pressed"):
					call("_on_blackjack_hit_pressed")
				get_viewport().set_input_as_handled()
				return
			KEY_SPACE:
				if has_method("_on_blackjack_stand_pressed"):
					call("_on_blackjack_stand_pressed")
				get_viewport().set_input_as_handled()
				return
			KEY_N:
				if has_method("_on_blackjack_new_round_pressed"):
					call("_on_blackjack_new_round_pressed")
				get_viewport().set_input_as_handled()
				return
			KEY_ESCAPE:
				if has_method("_on_blackjack_close_pressed"):
					call("_on_blackjack_close_pressed")
				get_viewport().set_input_as_handled()
				return
	if key_event.keycode == KEY_ESCAPE and modal_ui_open:
		if has_method("_close_modal_panels"):
			call("_close_modal_panels")
			get_viewport().set_input_as_handled()
		return
	if (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER) and not modal_ui_open:
		if _consume_transition_click_from_input():
			get_viewport().set_input_as_handled()
			return
		if mode == "chat" and input_line != null and input_line.editable:
			_on_send_pressed()
			get_viewport().set_input_as_handled()
		else:
			_on_next_pressed()
			get_viewport().set_input_as_handled()
		return
	match key_event.keycode:
		KEY_F2:
			_on_web_toggle_pressed()
			get_viewport().set_input_as_handled()
		KEY_F8:
			if DEBUG_UI_ENABLED:
				_on_debug_toggle_pressed()
				get_viewport().set_input_as_handled()


func _is_click_on_interactive_control(control: Control) -> bool:
	var current: Node = control
	while current != null:
		if current == input_line:
			return true
		if current == input_row_margin_ref:
			return true
		if current == blackjack_panel:
			return true
		if current is Button or current is LineEdit or current is HSlider or current is ScrollBar or current is PopupMenu:
			return true
		current = current.get_parent()
	return false


func _consume_startup_menu_page() -> String:
	var context: Node = get_node_or_null("/root/VictoriaLaunchContext")
	if context != null and context.has_method("consume_startup_menu_page"):
		return String(context.call("consume_startup_menu_page")).strip_edges()
	return ""


func _consume_startup_load_slot_index() -> int:
	var context: Node = get_node_or_null("/root/VictoriaLaunchContext")
	if context != null and context.has_method("consume_startup_load_slot_index"):
		return int(context.call("consume_startup_load_slot_index"))
	return 0


func _consume_startup_force_new_game() -> bool:
	var context: Node = get_node_or_null("/root/VictoriaLaunchContext")
	if context != null and context.has_method("consume_startup_force_new_game"):
		return bool(context.call("consume_startup_force_new_game"))
	return false


func _open_requested_game_menu(page: String) -> void:
	if page.is_empty():
		return
	if has_method("_open_game_menu"):
		call_deferred("_open_game_menu", page)
