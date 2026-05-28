extends "res://scripts/game/victoria_story_ui_menu.gd"

func _load_story() -> bool:
	if not FileAccess.file_exists(STORY_FILE):
		push_error("Story file missing: %s" % STORY_FILE)
		return false
	var file: FileAccess = FileAccess.open(STORY_FILE, FileAccess.READ)
	if file == null:
		push_error("Unable to open story file: %s" % STORY_FILE)
		return false
	var parser: JSON = JSON.new()
	var err: int = parser.parse(file.get_as_text())
	if err != OK:
		push_error("Story JSON parse error: %s" % parser.get_error_message())
		return false
	if typeof(parser.data) != TYPE_DICTIONARY:
		push_error("Story JSON root must be a dictionary.")
		return false
	story_data = parser.data
	return story_data.has("labels")



func _jump_to_label(label_name: String) -> void:
	var labels: Dictionary = story_data.get("labels", {})
	if label_name.is_empty() or not labels.has(label_name):
		_show_line("系统", "跳转失败：找不到标签 %s" % label_name, true)
		mode = "locked"
		return
	current_label = label_name
	current_index = 0



func _current_commands() -> Array:
	var labels: Dictionary = story_data.get("labels", {})
	if not labels.has(current_label):
		return []
	var value: Variant = labels[current_label]
	if typeof(value) != TYPE_ARRAY:
		return []
	return value as Array



func _advance_story() -> void:
	if mode != "story" or waiting_for_choice:
		return

	var guard: int = 0
	while guard < 1200:
		guard += 1
		var commands: Array = _current_commands()
		if commands.is_empty():
			_show_line("系统", "当前标签没有可执行命令：%s" % current_label, true)
			mode = "locked"
			return
		if current_index >= commands.size():
			_show_line("系统", "剧情片段结束：%s" % current_label, true)
			mode = "locked"
			return

		var command: Variant = commands[current_index]
		current_index += 1
		if typeof(command) != TYPE_DICTIONARY:
			continue
		var cmd: Dictionary = command
		match String(cmd.get("type", "")):
			"scene":
				_set_background_key(String(cmd.get("background", "")))
			"show_character":
				_set_character_key(String(cmd.get("character", "everyday")))
			"hide_character":
				character_rect.visible = false
			"set":
				_apply_set_command(cmd)
			"narration":
				_show_line("旁白", String(cmd.get("text", "")), true)
				return
			"say":
				_show_line(String(cmd.get("speaker", "维多利亚")), String(cmd.get("text", "")), false)
				return
			"choice":
				_present_choices(cmd)
				return
			"jump":
				_jump_to_label(String(cmd.get("target", "")))
			"enter_chat":
				mode = "chat"
				var silent_enter: bool = bool(cmd.get("silent", false))
				if not silent_enter:
					_show_line("系统", String(cmd.get("text", "你可以自由聊天了。")), true)
				pending_period_intro = true
				_update_interaction_state()
				return
			"end":
				_show_line("系统", String(cmd.get("text", "剧情结束。")), true)
				mode = "locked"
				_update_interaction_state()
				return
			_:
				push_warning("Unknown command type: %s" % String(cmd.get("type", "")))
	_update_hud()



func _apply_set_command(command: Dictionary) -> void:
	var key: String = String(command.get("key", ""))
	if key.is_empty():
		return
	var op: String = String(command.get("operation", "set"))
	var value: Variant = command.get("value")
	var refresh_scene: bool = false
	var sync_audio: bool = false
	match key:
		"love_score":
			if op == "add":
				state.love_score += int(value)
			else:
				state.love_score = int(value)
			state.love_score = clamp(state.love_score, 0, 100)
		"living_days":
			state.living_days = int(value)
		"current_cycle_seconds":
			if op == "add":
				state.current_cycle_seconds += int(value)
			else:
				state.current_cycle_seconds = int(value)
			state.refresh_time()
			refresh_scene = true
			sync_audio = true
		"time_period_name":
			state.time_period_name = String(value)
			refresh_scene = true
			sync_audio = true
		"current_location":
			state.current_location = String(value)
			refresh_scene = true
		"prologue_done":
			state.prologue_done = bool(value)
		"daily_greeted":
			state.daily_greeted = bool(value)
		"period_initiative_done":
			state.period_initiative_done = bool(value)
		_:
			pass
	if refresh_scene:
		_apply_scene_by_state()
	if sync_audio:
		_sync_period_music(0.3)
	_update_hud()
	_update_love_visual(0)



func _present_choices(command: Dictionary) -> void:
	_clear_choices()
	var choices: Variant = command.get("choices", [])
	if typeof(choices) != TYPE_ARRAY or choices.is_empty():
		_advance_story()
		return
	waiting_for_choice = true
	for entry in choices:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = entry
		var btn: Button = Button.new()
		btn.text = String(choice.get("text", "继续"))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0.0, 64.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if ui_theme_v2 != null:
			btn.theme = ui_theme_v2
		btn.theme_type_variation = VAR_CHOICE_BUTTON
		_apply_font(btn, 21)
		btn.pressed.connect(_on_choice_selected.bind(choice))
		choices_box.add_child(btn)
	choices_box.visible = true
	if next_button != null:
		next_button.disabled = true
	_update_interaction_state(false)



func _on_choice_selected(choice: Dictionary) -> void:
	if not waiting_for_choice:
		return
	waiting_for_choice = false
	_clear_choices()
	if typeof(choice.get("effects", {})) == TYPE_DICTIONARY:
		for key in choice["effects"].keys():
			var value: Variant = choice["effects"][key]
			if String(key) == "love_score":
				state.apply_love_change(int(value))
	_update_love_visual(0)
	var next: String = String(choice.get("next", ""))
	if next.is_empty():
		_show_line("系统", "选项缺少 next 标签。", true)
		mode = "locked"
		return
	_jump_to_label(next)
	_advance_story()
	_save_runtime_state()



func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()
	choices_box.visible = false
	if next_button != null:
		next_button.disabled = false
	_update_interaction_state(false)



func _show_line(speaker: String, text: String, narration: bool) -> void:
	var show_speaker: bool = (not narration) and (not speaker.strip_edges().is_empty())
	speaker_label.visible = show_speaker
	speaker_label.text = speaker if show_speaker else ""
	if show_speaker:
		speaker_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	_apply_dialogue_text_style(text, not narration and not speaker.strip_edges().is_empty())
	if not cached_layout.is_empty():
		_apply_ui_layout()
	_start_typewriter(text)
	# Any visible line should suppress the input field until player clears it.
	_update_interaction_state(false)
	_update_hud()



func _apply_dialogue_text_style(text: String, has_name: bool) -> void:
	var compact: String = String(text).replace(" ", "").replace("\n", "").strip_edges()
	var base: int = 27 if has_name else 29
	var minimum: int = 22 if has_name else 23
	var size: int = base
	if compact.length() > 44:
		var step: int = int((compact.length() - 44) / 24) + 1
		size = maxi(minimum, base - step)
	var spacing: int = maxi(3, 6 - maxi(0, int((base - size) / 2)))
	_apply_font(dialogue_label, size)
	dialogue_label.add_theme_constant_override("line_spacing", spacing)
	dialogue_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96) if has_name else Color(0.95, 0.95, 0.95))
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER



func _start_typewriter(text: String) -> void:
	typing_full_text = text
	typing_visible_chars = 0
	typing_accumulator = 0.0
	typing_active = true
	dialogue_label.text = ""
	_update_interaction_state(false)
	_refresh_chat_prompt()



func _complete_typewriter() -> void:
	if not typing_active:
		return
	typing_active = false
	typing_visible_chars = typing_full_text.length()
	dialogue_label.text = typing_full_text
	_update_interaction_state(false)
	_refresh_chat_prompt()

