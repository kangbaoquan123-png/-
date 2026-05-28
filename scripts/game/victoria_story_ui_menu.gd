extends "res://scripts/game/victoria_story_ui_builder.gd"

const MAIN_MENU_SCENE_PATH := "res://main_menu.tscn"
var slot_thumb_texture_cache: Dictionary = {}
var game_menu_background: TextureRect
var game_menu_bg_blur_material: ShaderMaterial
var save_slot_confirm_overlay: ColorRect
var save_slot_confirm_panel: PanelContainer
var save_slot_confirm_title: Label
var save_slot_confirm_hint: Label
var save_slot_confirm_accept_button: Button
var save_slot_confirm_cancel_button: Button
var pending_save_slot: int = -1
var pending_slot_action: String = ""

func _build_game_menu_ui(root: Control) -> void:
	var panel_v: Node = _require_ui_node(root, "游戏菜单面板")
	if not (panel_v is PanelContainer):
		push_error("UI node type mismatch: 游戏菜单面板")
		return
	game_menu_panel = panel_v as PanelContainer
	game_menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_menu_panel.visible = false
	game_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	game_menu_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.0, 0.0, 0.0, 0.0)))

	var bg_v: Node = _require_ui_node(game_menu_panel, "游戏菜单背景")
	if not (bg_v is TextureRect):
		push_error("UI node type mismatch: 游戏菜单背景")
		return
	var menu_bg: TextureRect = bg_v as TextureRect
	game_menu_background = menu_bg
	menu_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_bg.stretch_mode = TextureRect.STRETCH_SCALE
	var menu_bg_v: Variant = load("res://assets/gui/overlay/game_menu.png")
	if menu_bg_v is Texture2D:
		menu_bg.texture = menu_bg_v as Texture2D
	_ensure_game_menu_bg_blur_material()

	var content_margin_v: Node = _require_ui_node(game_menu_panel, "游戏菜单内容边距")
	if not (content_margin_v is MarginContainer):
		push_error("UI node type mismatch: 游戏菜单内容边距")
		return
	var content_margin: MarginContainer = content_margin_v as MarginContainer
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 64)
	content_margin.add_theme_constant_override("margin_top", 180)
	content_margin.add_theme_constant_override("margin_right", 42)
	content_margin.add_theme_constant_override("margin_bottom", 40)

	var shell_v: Node = _require_ui_node(content_margin, "游戏菜单框架")
	if not (shell_v is HBoxContainer):
		push_error("UI node type mismatch: 游戏菜单框架")
		return
	var shell: HBoxContainer = shell_v as HBoxContainer
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 64)

	var nav_box_v: Node = _require_ui_node(shell, "游戏菜单导航盒")
	if not (nav_box_v is VBoxContainer):
		push_error("UI node type mismatch: 游戏菜单导航盒")
		return
	game_menu_nav_box = nav_box_v as VBoxContainer
	game_menu_nav_box.custom_minimum_size = Vector2(320.0, 0.0)
	game_menu_nav_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_menu_nav_box.add_theme_constant_override("separation", 12)

	game_menu_nav_buttons.clear()
	var nav_defs: Array[Dictionary] = [
		{"node": "导航历史", "key": "history"},
		{"node": "导航保存", "key": "save"},
		{"node": "导航读取", "key": "load"},
		{"node": "导航设置", "key": "settings"},
		{"node": "导航关于", "key": "about"},
		{"node": "导航帮助", "key": "help"}
	]
	for nav_def in nav_defs:
		var node_name: String = String(nav_def.get("node", ""))
		var nav_key: String = String(nav_def.get("key", ""))
		if node_name.is_empty() or nav_key.is_empty():
			continue
		var nav_btn_v: Node = _require_ui_node(game_menu_nav_box, node_name)
		if not (nav_btn_v is Button):
			push_error("UI node type mismatch: %s" % node_name)
			return
		var nav_btn: Button = nav_btn_v as Button
		nav_btn.flat = true
		nav_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ui_theme_v2 != null:
			nav_btn.theme = ui_theme_v2
		nav_btn.theme_type_variation = VAR_MENU_NAV_BUTTON
		_apply_font(nav_btn, 34)
		_bind_hover_feedback(nav_btn, Color(1.04, 1.04, 1.04, 1.0), 0.09)
		var nav_callable: Callable = Callable(self, "_on_game_menu_nav_pressed").bind(nav_key)
		if not nav_btn.pressed.is_connected(nav_callable):
			nav_btn.pressed.connect(nav_callable)
		game_menu_nav_buttons[nav_key] = nav_btn

	var nav_spacer_v: Node = _require_ui_node(game_menu_nav_box, "导航占位")
	if not (nav_spacer_v is Control):
		push_error("UI node type mismatch: 导航占位")
		return
	var nav_spacer: Control = nav_spacer_v as Control
	nav_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var return_btn_v: Node = _require_ui_node(game_menu_nav_box, "导航返回")
	if not (return_btn_v is Button):
		push_error("UI node type mismatch: 导航返回")
		return
	var return_btn: Button = return_btn_v as Button
	_style_room_button(return_btn, 24)
	var close_callable: Callable = Callable(self, "_close_modal_panels")
	if not return_btn.pressed.is_connected(close_callable):
		return_btn.pressed.connect(close_callable)

	var content_box_v: Node = _require_ui_node(shell, "游戏菜单内容盒")
	if not (content_box_v is VBoxContainer):
		push_error("UI node type mismatch: 游戏菜单内容盒")
		return
	var content_box: VBoxContainer = content_box_v as VBoxContainer
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 10)

	var title_v: Node = _require_ui_node(content_box, "游戏菜单标题")
	if not (title_v is Label):
		push_error("UI node type mismatch: 游戏菜单标题")
		return
	game_menu_title = title_v as Label
	if ui_theme_v2 != null:
		game_menu_title.theme = ui_theme_v2
	game_menu_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_apply_font(game_menu_title, 68)

	var page_frame_v: Node = _require_ui_node(content_box, "游戏菜单页面框")
	if not (page_frame_v is PanelContainer):
		push_error("UI node type mismatch: 游戏菜单页面框")
		return
	var page_frame: PanelContainer = page_frame_v as PanelContainer
	page_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.0, 0.0, 0.0, 0.45)))

	var page_margin_v: Node = _require_ui_node(page_frame, "游戏菜单页面边距")
	if not (page_margin_v is MarginContainer):
		push_error("UI node type mismatch: 游戏菜单页面边距")
		return
	var page_margin: MarginContainer = page_margin_v as MarginContainer
	page_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_margin.add_theme_constant_override("margin_left", 22)
	page_margin.add_theme_constant_override("margin_top", 18)
	page_margin.add_theme_constant_override("margin_right", 22)
	page_margin.add_theme_constant_override("margin_bottom", 18)

	var page_root_v: Node = _require_ui_node(page_margin, "游戏菜单页面根")
	if not (page_root_v is Control):
		push_error("UI node type mismatch: 游戏菜单页面根")
		return
	var page_root: Control = page_root_v as Control
	page_root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var page_history_v: Node = _require_ui_node(page_root, "历史页面")
	if not (page_history_v is VBoxContainer):
		push_error("UI node type mismatch: 历史页面")
		return
	var page_history: VBoxContainer = page_history_v as VBoxContainer
	page_history.visible = false
	page_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_history.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var history_text_v: Node = _require_ui_node(page_history, "历史文本")
	if not (history_text_v is RichTextLabel):
		push_error("UI node type mismatch: 历史文本")
		return
	history_text = history_text_v as RichTextLabel
	history_text.bbcode_enabled = true
	history_text.scroll_active = true
	_apply_font(history_text, 19)

	var page_save_v: Node = _require_ui_node(page_root, "保存页面")
	if not (page_save_v is VBoxContainer):
		push_error("UI node type mismatch: 保存页面")
		return
	var page_save: VBoxContainer = page_save_v as VBoxContainer
	page_save.visible = false
	page_save.add_theme_constant_override("separation", 12)
	page_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_save.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var save_info_v: Node = _require_ui_node(page_save, "保存说明标签")
	if not (save_info_v is Label):
		push_error("UI node type mismatch: 保存说明标签")
		return
	save_info_label = save_info_v as Label
	save_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(save_info_label, 18)

	var save_page_v: Node = _require_ui_node(page_save, "保存页码标签")
	if not (save_page_v is Label):
		push_error("UI node type mismatch: 保存页码标签")
		return
	save_page_label = save_page_v as Label
	save_page_label.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86))
	_apply_font(save_page_label, 18)

	var save_grid_v: Node = _require_ui_node(page_save, "保存槽位网格")
	if not (save_grid_v is GridContainer):
		push_error("UI node type mismatch: 保存槽位网格")
		return
	save_grid_ref = save_grid_v as GridContainer
	save_grid_ref.columns = SLOT_SAVE_COLS
	save_grid_ref.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_grid_ref.size_flags_vertical = Control.SIZE_EXPAND_FILL
	save_grid_ref.add_theme_constant_override("h_separation", 24)
	save_grid_ref.add_theme_constant_override("v_separation", 24)
	save_slot_buttons.clear()
	var save_cell_idx: int = 0
	for child in save_grid_ref.get_children():
		if save_cell_idx >= SLOT_SAVE_PER_PAGE:
			break
		if not (child is Button):
			continue
		var save_slot_button: Button = child as Button
		if not _bind_slot_entry_button(save_slot_button, save_cell_idx, true):
			return
		save_slot_buttons.append(save_slot_button)
		save_cell_idx += 1
	if save_slot_buttons.size() < SLOT_SAVE_PER_PAGE:
		push_error("保存槽位网格 missing slot buttons, expected %s but got %s." % [str(SLOT_SAVE_PER_PAGE), str(save_slot_buttons.size())])
		return

	var save_controls_v: Node = _require_ui_node(page_save, "保存分页按钮")
	if not (save_controls_v is GridContainer):
		push_error("UI node type mismatch: 保存分页按钮")
		return
	var save_controls: GridContainer = save_controls_v as GridContainer
	save_page_buttons_ref = save_controls
	save_controls.columns = 5
	save_controls.add_theme_constant_override("h_separation", 8)
	save_controls.add_theme_constant_override("v_separation", 8)
	for child_v in save_controls.get_children():
		if not (child_v is Button):
			continue
		var save_page_btn: Button = child_v as Button
		var save_page_text: String = save_page_btn.text.strip_edges()
		if not save_page_text.is_valid_int():
			continue
		var save_page_n: int = int(save_page_text)
		_style_compact_menu_button(save_page_btn, 15)
		save_page_btn.custom_minimum_size = Vector2(38.0, 34.0)
		var save_page_callable: Callable = Callable(self, "_on_save_page_pressed").bind(save_page_n)
		if not save_page_btn.pressed.is_connected(save_page_callable):
			save_page_btn.pressed.connect(save_page_callable)

	var save_row_v: Node = _require_ui_node(page_save, "保存操作行")
	if not (save_row_v is HBoxContainer):
		push_error("UI node type mismatch: 保存操作行")
		return
	var save_row: HBoxContainer = save_row_v as HBoxContainer
	save_row.visible = false
	save_row.add_theme_constant_override("separation", 10)
	var save_btn_v: Node = _require_ui_node(save_row, "保存执行按钮")
	if not (save_btn_v is Button):
		push_error("UI node type mismatch: 保存执行按钮")
		return
	var save_btn: Button = save_btn_v as Button
	_style_compact_menu_button(save_btn, 18)
	save_btn.custom_minimum_size = Vector2(140.0, 40.0)
	var save_action_callable: Callable = Callable(self, "_on_save_panel_save_pressed")
	if not save_btn.pressed.is_connected(save_action_callable):
		save_btn.pressed.connect(save_action_callable)

	var page_load_v: Node = _require_ui_node(page_root, "读取页面")
	if not (page_load_v is VBoxContainer):
		push_error("UI node type mismatch: 读取页面")
		return
	var page_load: VBoxContainer = page_load_v as VBoxContainer
	page_load.visible = false
	page_load.add_theme_constant_override("separation", 12)
	page_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_load.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var load_info_v: Node = _require_ui_node(page_load, "读取说明标签")
	if not (load_info_v is Label):
		push_error("UI node type mismatch: 读取说明标签")
		return
	load_info_label = load_info_v as Label
	load_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(load_info_label, 18)

	var load_page_v: Node = _require_ui_node(page_load, "读取页码标签")
	if not (load_page_v is Label):
		push_error("UI node type mismatch: 读取页码标签")
		return
	load_page_label = load_page_v as Label
	load_page_label.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86))
	_apply_font(load_page_label, 18)

	var load_grid_v: Node = _require_ui_node(page_load, "读取槽位网格")
	if not (load_grid_v is GridContainer):
		push_error("UI node type mismatch: 读取槽位网格")
		return
	load_grid_ref = load_grid_v as GridContainer
	load_grid_ref.columns = SLOT_SAVE_COLS
	load_grid_ref.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_grid_ref.size_flags_vertical = Control.SIZE_EXPAND_FILL
	load_grid_ref.add_theme_constant_override("h_separation", 24)
	load_grid_ref.add_theme_constant_override("v_separation", 24)
	load_slot_buttons.clear()
	var load_cell_idx: int = 0
	for child2 in load_grid_ref.get_children():
		if load_cell_idx >= SLOT_SAVE_PER_PAGE:
			break
		if not (child2 is Button):
			continue
		var load_slot_button: Button = child2 as Button
		if not _bind_slot_entry_button(load_slot_button, load_cell_idx, false):
			return
		load_slot_buttons.append(load_slot_button)
		load_cell_idx += 1
	if load_slot_buttons.size() < SLOT_SAVE_PER_PAGE:
		push_error("读取槽位网格 missing slot buttons, expected %s but got %s." % [str(SLOT_SAVE_PER_PAGE), str(load_slot_buttons.size())])
		return

	var load_controls_v: Node = _require_ui_node(page_load, "读取分页按钮")
	if not (load_controls_v is GridContainer):
		push_error("UI node type mismatch: 读取分页按钮")
		return
	var load_controls: GridContainer = load_controls_v as GridContainer
	load_page_buttons_ref = load_controls
	load_controls.columns = 5
	load_controls.add_theme_constant_override("h_separation", 8)
	load_controls.add_theme_constant_override("v_separation", 8)
	for child_v2 in load_controls.get_children():
		if not (child_v2 is Button):
			continue
		var load_page_btn: Button = child_v2 as Button
		var load_page_text: String = load_page_btn.text.strip_edges()
		if not load_page_text.is_valid_int():
			continue
		var load_page_n: int = int(load_page_text)
		_style_compact_menu_button(load_page_btn, 15)
		load_page_btn.custom_minimum_size = Vector2(38.0, 34.0)
		var load_page_callable: Callable = Callable(self, "_on_load_page_pressed").bind(load_page_n)
		if not load_page_btn.pressed.is_connected(load_page_callable):
			load_page_btn.pressed.connect(load_page_callable)

	var load_row_v: Node = _require_ui_node(page_load, "读取操作行")
	if not (load_row_v is HBoxContainer):
		push_error("UI node type mismatch: 读取操作行")
		return
	var load_row: HBoxContainer = load_row_v as HBoxContainer
	load_row.visible = false
	load_row.add_theme_constant_override("separation", 10)
	var load_btn_v: Node = _require_ui_node(load_row, "读取执行按钮")
	if not (load_btn_v is Button):
		push_error("UI node type mismatch: 读取执行按钮")
		return
	var load_btn: Button = load_btn_v as Button
	_style_compact_menu_button(load_btn, 18)
	load_btn.custom_minimum_size = Vector2(140.0, 40.0)
	var load_action_callable: Callable = Callable(self, "_on_save_panel_load_pressed")
	if not load_btn.pressed.is_connected(load_action_callable):
		load_btn.pressed.connect(load_action_callable)

	var page_settings_v: Node = _require_ui_node(page_root, "设置页面")
	if not (page_settings_v is VBoxContainer):
		push_error("UI node type mismatch: 设置页面")
		return
	var page_settings: VBoxContainer = page_settings_v as VBoxContainer
	page_settings.visible = false
	page_settings.add_theme_constant_override("separation", 16)
	page_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var bgm_label_v: Node = _require_ui_node(page_settings, "音乐音量标签")
	if not (bgm_label_v is Label):
		push_error("UI node type mismatch: 音乐音量标签")
		return
	var bgm_label: Label = bgm_label_v as Label
	_apply_font(bgm_label, 20)

	var bgm_slider_v: Node = _require_ui_node(page_settings, "音乐音量滑条")
	if not (bgm_slider_v is HSlider):
		push_error("UI node type mismatch: 音乐音量滑条")
		return
	bgm_slider = bgm_slider_v as HSlider
	bgm_slider.min_value = 0
	bgm_slider.max_value = 100
	bgm_slider.step = 1
	var bgm_callable: Callable = Callable(self, "_on_bgm_slider_changed")
	if not bgm_slider.value_changed.is_connected(bgm_callable):
		bgm_slider.value_changed.connect(bgm_callable)

	var sfx_label_v: Node = _require_ui_node(page_settings, "音效音量标签")
	if not (sfx_label_v is Label):
		push_error("UI node type mismatch: 音效音量标签")
		return
	var sfx_label: Label = sfx_label_v as Label
	_apply_font(sfx_label, 20)

	var sfx_slider_v: Node = _require_ui_node(page_settings, "音效音量滑条")
	if not (sfx_slider_v is HSlider):
		push_error("UI node type mismatch: 音效音量滑条")
		return
	sfx_slider = sfx_slider_v as HSlider
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.step = 1
	var sfx_callable: Callable = Callable(self, "_on_sfx_slider_changed")
	if not sfx_slider.value_changed.is_connected(sfx_callable):
		sfx_slider.value_changed.connect(sfx_callable)

	var mode_help_v: Node = _require_ui_node(page_settings, "模式说明标签")
	if not (mode_help_v is Label):
		push_error("UI node type mismatch: 模式说明标签")
		return
	var mode_help: Label = mode_help_v as Label
	mode_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(mode_help, 16)

	var settings_row_v: Node = _require_ui_node(page_settings, "设置操作行")
	if not (settings_row_v is HBoxContainer):
		push_error("UI node type mismatch: 设置操作行")
		return
	var settings_row: HBoxContainer = settings_row_v as HBoxContainer
	settings_row.add_theme_constant_override("separation", 10)

	var settings_display_v: Node = _require_ui_node(settings_row, "显示模式按钮")
	if not (settings_display_v is Button):
		push_error("UI node type mismatch: 显示模式按钮")
		return
	settings_display_button = settings_display_v as Button
	_style_compact_menu_button(settings_display_button, 15)
	settings_display_button.custom_minimum_size = Vector2(152.0, 36.0)
	var display_callable: Callable = Callable(self, "_on_settings_display_pressed")
	if not settings_display_button.pressed.is_connected(display_callable):
		settings_display_button.pressed.connect(display_callable)

	var settings_skip_v: Node = _require_ui_node(settings_row, "快进模式按钮")
	if not (settings_skip_v is Button):
		push_error("UI node type mismatch: 快进模式按钮")
		return
	settings_skip_button = settings_skip_v as Button
	_style_compact_menu_button(settings_skip_button, 15)
	settings_skip_button.custom_minimum_size = Vector2(152.0, 36.0)
	var skip_callable: Callable = Callable(self, "_on_settings_skip_pressed")
	if not settings_skip_button.pressed.is_connected(skip_callable):
		settings_skip_button.pressed.connect(skip_callable)

	var settings_auto_v: Node = _require_ui_node(settings_row, "自动模式按钮")
	if not (settings_auto_v is Button):
		push_error("UI node type mismatch: 自动模式按钮")
		return
	settings_auto_button = settings_auto_v as Button
	_style_compact_menu_button(settings_auto_button, 15)
	settings_auto_button.custom_minimum_size = Vector2(152.0, 36.0)
	var auto_callable: Callable = Callable(self, "_on_settings_auto_pressed")
	if not settings_auto_button.pressed.is_connected(auto_callable):
		settings_auto_button.pressed.connect(auto_callable)

	var settings_return_v: Node = _require_ui_node(settings_row, "返回主菜单按钮")
	if not (settings_return_v is Button):
		push_error("UI node type mismatch: 返回主菜单按钮")
		return
	settings_return_main_menu_button = settings_return_v as Button
	_style_compact_menu_button(settings_return_main_menu_button, 15)
	settings_return_main_menu_button.custom_minimum_size = Vector2(176.0, 36.0)
	var return_main_menu_callable: Callable = Callable(self, "_on_settings_return_main_menu_pressed")
	if not settings_return_main_menu_button.pressed.is_connected(return_main_menu_callable):
		settings_return_main_menu_button.pressed.connect(return_main_menu_callable)

	var confirm_overlay_v: Node = _require_ui_node(root, "主菜单确认遮罩")
	if not (confirm_overlay_v is ColorRect):
		push_error("UI node type mismatch: 主菜单确认遮罩")
		return
	main_menu_confirm_overlay = confirm_overlay_v as ColorRect
	main_menu_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	main_menu_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main_menu_confirm_overlay.visible = false
	var confirm_overlay_input_callable: Callable = Callable(self, "_on_main_menu_confirm_overlay_input")
	if not main_menu_confirm_overlay.gui_input.is_connected(confirm_overlay_input_callable):
		main_menu_confirm_overlay.gui_input.connect(confirm_overlay_input_callable)

	var confirm_panel_v: Node = _require_ui_node(main_menu_confirm_overlay, "主菜单确认面板")
	if not (confirm_panel_v is PanelContainer):
		push_error("UI node type mismatch: 主菜单确认面板")
		return
	main_menu_confirm_panel = confirm_panel_v as PanelContainer
	main_menu_confirm_panel.visible = false
	main_menu_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	main_menu_confirm_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.02, 0.02, 0.96)))

	var confirm_title_v: Node = _require_ui_node(main_menu_confirm_panel, "主菜单确认边距/主菜单确认盒/主菜单确认标题")
	if not (confirm_title_v is Label):
		push_error("UI node type mismatch: 主菜单确认标题")
		return
	main_menu_confirm_title = confirm_title_v as Label
	main_menu_confirm_title.text = "回到主菜单"
	_apply_font(main_menu_confirm_title, 24)

	var confirm_hint_v: Node = _require_ui_node(main_menu_confirm_panel, "主菜单确认边距/主菜单确认盒/主菜单确认提示")
	if not (confirm_hint_v is Label):
		push_error("UI node type mismatch: 主菜单确认提示")
		return
	main_menu_confirm_hint = confirm_hint_v as Label
	main_menu_confirm_hint.text = "要先保存当前进度吗？"
	main_menu_confirm_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(main_menu_confirm_hint, 17)

	var confirm_save_v: Node = _require_ui_node(main_menu_confirm_panel, "主菜单确认边距/主菜单确认盒/主菜单确认操作行/确认保存返回按钮")
	if not (confirm_save_v is Button):
		push_error("UI node type mismatch: 确认保存返回按钮")
		return
	main_menu_confirm_save_button = confirm_save_v as Button
	main_menu_confirm_save_button.text = "保存并返回"
	_style_compact_menu_button(main_menu_confirm_save_button, 16)
	main_menu_confirm_save_button.custom_minimum_size = Vector2(170.0, 40.0)
	var confirm_save_callable: Callable = Callable(self, "_on_main_menu_confirm_save_pressed")
	if not main_menu_confirm_save_button.pressed.is_connected(confirm_save_callable):
		main_menu_confirm_save_button.pressed.connect(confirm_save_callable)

	var confirm_no_save_v: Node = _require_ui_node(main_menu_confirm_panel, "主菜单确认边距/主菜单确认盒/主菜单确认操作行/确认不保存返回按钮")
	if not (confirm_no_save_v is Button):
		push_error("UI node type mismatch: 确认不保存返回按钮")
		return
	main_menu_confirm_no_save_button = confirm_no_save_v as Button
	main_menu_confirm_no_save_button.text = "不保存返回"
	_style_compact_menu_button(main_menu_confirm_no_save_button, 16)
	main_menu_confirm_no_save_button.custom_minimum_size = Vector2(170.0, 40.0)
	var confirm_no_save_callable: Callable = Callable(self, "_on_main_menu_confirm_no_save_pressed")
	if not main_menu_confirm_no_save_button.pressed.is_connected(confirm_no_save_callable):
		main_menu_confirm_no_save_button.pressed.connect(confirm_no_save_callable)

	var confirm_cancel_v: Node = _require_ui_node(main_menu_confirm_panel, "主菜单确认边距/主菜单确认盒/主菜单确认操作行/确认取消按钮")
	if not (confirm_cancel_v is Button):
		push_error("UI node type mismatch: 确认取消按钮")
		return
	main_menu_confirm_cancel_button = confirm_cancel_v as Button
	main_menu_confirm_cancel_button.text = "取消"
	_style_compact_menu_button(main_menu_confirm_cancel_button, 16)
	main_menu_confirm_cancel_button.custom_minimum_size = Vector2(170.0, 40.0)
	var confirm_cancel_callable: Callable = Callable(self, "_on_main_menu_confirm_cancel_pressed")
	if not main_menu_confirm_cancel_button.pressed.is_connected(confirm_cancel_callable):
		main_menu_confirm_cancel_button.pressed.connect(confirm_cancel_callable)

	var save_confirm_overlay_v: Node = _require_ui_node(root, "存档确认遮罩")
	if not (save_confirm_overlay_v is ColorRect):
		push_error("UI node type mismatch: 存档确认遮罩")
		return
	save_slot_confirm_overlay = save_confirm_overlay_v as ColorRect
	save_slot_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	save_slot_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	save_slot_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	save_slot_confirm_overlay.visible = false
	var save_confirm_overlay_callable: Callable = Callable(self, "_on_save_slot_confirm_overlay_input")
	if not save_slot_confirm_overlay.gui_input.is_connected(save_confirm_overlay_callable):
		save_slot_confirm_overlay.gui_input.connect(save_confirm_overlay_callable)

	var save_confirm_panel_v: Node = _require_ui_node(save_slot_confirm_overlay, "存档确认面板")
	if not (save_confirm_panel_v is PanelContainer):
		push_error("UI node type mismatch: 存档确认面板")
		return
	save_slot_confirm_panel = save_confirm_panel_v as PanelContainer
	save_slot_confirm_panel.visible = false
	save_slot_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	save_slot_confirm_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.02, 0.02, 0.96)))

	var save_confirm_title_v: Node = _require_ui_node(save_slot_confirm_panel, "存档确认边距/存档确认盒/存档确认标题")
	if not (save_confirm_title_v is Label):
		push_error("UI node type mismatch: 存档确认标题")
		return
	save_slot_confirm_title = save_confirm_title_v as Label
	save_slot_confirm_title.text = "\u786e\u8ba4\u4fdd\u5b58"
	_apply_font(save_slot_confirm_title, 24)

	var save_confirm_hint_v: Node = _require_ui_node(save_slot_confirm_panel, "存档确认边距/存档确认盒/存档确认提示")
	if not (save_confirm_hint_v is Label):
		push_error("UI node type mismatch: 存档确认提示")
		return
	save_slot_confirm_hint = save_confirm_hint_v as Label
	save_slot_confirm_hint.text = "\u662f\u5426\u4fdd\u5b58\u5230\u8be5\u69fd\u4f4d\uff1f"
	save_slot_confirm_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(save_slot_confirm_hint, 17)

	var save_confirm_accept_v: Node = _require_ui_node(save_slot_confirm_panel, "存档确认边距/存档确认盒/存档确认操作行/存档确认按钮")
	if not (save_confirm_accept_v is Button):
		push_error("UI node type mismatch: 存档确认按钮")
		return
	save_slot_confirm_accept_button = save_confirm_accept_v as Button
	save_slot_confirm_accept_button.text = "\u786e\u8ba4\u4fdd\u5b58"
	_style_compact_menu_button(save_slot_confirm_accept_button, 16)
	save_slot_confirm_accept_button.custom_minimum_size = Vector2(170.0, 40.0)
	var save_confirm_accept_callable: Callable = Callable(self, "_on_save_slot_confirm_accept_pressed")
	if not save_slot_confirm_accept_button.pressed.is_connected(save_confirm_accept_callable):
		save_slot_confirm_accept_button.pressed.connect(save_confirm_accept_callable)

	var save_confirm_cancel_v: Node = _require_ui_node(save_slot_confirm_panel, "存档确认边距/存档确认盒/存档确认操作行/存档取消按钮")
	if not (save_confirm_cancel_v is Button):
		push_error("UI node type mismatch: 存档取消按钮")
		return
	save_slot_confirm_cancel_button = save_confirm_cancel_v as Button
	save_slot_confirm_cancel_button.text = "\u53d6\u6d88"
	_style_compact_menu_button(save_slot_confirm_cancel_button, 16)
	save_slot_confirm_cancel_button.custom_minimum_size = Vector2(170.0, 40.0)
	var save_confirm_cancel_callable: Callable = Callable(self, "_on_save_slot_confirm_cancel_pressed")
	if not save_slot_confirm_cancel_button.pressed.is_connected(save_confirm_cancel_callable):
		save_slot_confirm_cancel_button.pressed.connect(save_confirm_cancel_callable)

	var page_about_v: Node = _require_ui_node(page_root, "关于页面")
	if not (page_about_v is VBoxContainer):
		push_error("UI node type mismatch: 关于页面")
		return
	var page_about: VBoxContainer = page_about_v as VBoxContainer
	page_about.visible = false
	page_about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_about.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var about_text_v: Node = _require_ui_node(page_about, "关于文本")
	if not (about_text_v is RichTextLabel):
		push_error("UI node type mismatch: 关于文本")
		return
	var about_text: RichTextLabel = about_text_v as RichTextLabel
	about_text.bbcode_enabled = true
	about_text.fit_content = false
	_apply_font(about_text, 18)

	var page_help_v: Node = _require_ui_node(page_root, "帮助页面")
	if not (page_help_v is VBoxContainer):
		push_error("UI node type mismatch: 帮助页面")
		return
	var page_help: VBoxContainer = page_help_v as VBoxContainer
	page_help.visible = false
	page_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_help.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var help_text_v: Node = _require_ui_node(page_help, "帮助文本")
	if not (help_text_v is RichTextLabel):
		push_error("UI node type mismatch: 帮助文本")
		return
	var help_text: RichTextLabel = help_text_v as RichTextLabel
	help_text.bbcode_enabled = true
	help_text.fit_content = false
	_apply_font(help_text, 18)

	game_menu_pages.clear()
	game_menu_pages["history"] = page_history
	game_menu_pages["save"] = page_save
	game_menu_pages["load"] = page_load
	game_menu_pages["settings"] = page_settings
	game_menu_pages["about"] = page_about
	game_menu_pages["help"] = page_help
	_switch_game_menu_page("history")



func _ensure_game_menu_bg_blur_material() -> void:
	if game_menu_background == null:
		return
	if game_menu_bg_blur_material == null:
		var blur_shader: Shader = Shader.new()
		blur_shader.code = """
shader_type canvas_item;
uniform float blur_px : hint_range(0.0, 6.0) = 0.0;

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	tex_size = max(tex_size, vec2(1.0));
	vec2 step_uv = vec2(1.0) / tex_size;
	vec2 offset = vec2(step_uv.x * blur_px, step_uv.y * blur_px);

	vec4 sum = texture(TEXTURE, UV) * 0.227027;
	sum += texture(TEXTURE, UV + vec2(offset.x, 0.0)) * 0.1945946;
	sum += texture(TEXTURE, UV - vec2(offset.x, 0.0)) * 0.1945946;
	sum += texture(TEXTURE, UV + vec2(0.0, offset.y)) * 0.1945946;
	sum += texture(TEXTURE, UV - vec2(0.0, offset.y)) * 0.1945946;
	sum += texture(TEXTURE, UV + offset) * 0.1216216;
	sum += texture(TEXTURE, UV - offset) * 0.1216216;
	sum += texture(TEXTURE, UV + vec2(offset.x, -offset.y)) * 0.1216216;
	sum += texture(TEXTURE, UV + vec2(-offset.x, offset.y)) * 0.1216216;
	COLOR = sum;
}
"""
		game_menu_bg_blur_material = ShaderMaterial.new()
		game_menu_bg_blur_material.shader = blur_shader
	game_menu_background.material = game_menu_bg_blur_material
	_set_game_menu_background_blur(false)


func _set_game_menu_background_blur(enabled: bool) -> void:
	if game_menu_bg_blur_material == null:
		return
	game_menu_bg_blur_material.set_shader_parameter("blur_px", 2.2 if enabled else 0.0)


func _animate_popup_open(overlay: ColorRect, panel: PanelContainer) -> void:
	if overlay == null or panel == null:
		return
	overlay.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2(0.96, 0.96)
	panel.pivot_offset = panel.size * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "self_modulate:a", 1.0, 0.14)
	tween.tween_property(panel, "self_modulate:a", 1.0, 0.14)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.14)


func _open_game_menu(page_key: String) -> void:
	if game_menu_panel == null or menu_overlay_mask == null:
		return
	if modal_fade_tween != null:
		modal_fade_tween.kill()
		modal_fade_tween = null
	_close_save_slot_confirm()
	_close_main_menu_return_confirm()
	if state.room_nav_open:
		state.room_nav_open = false
		_refresh_room_nav_ui()
	menu_overlay_mask.visible = true
	game_menu_panel.visible = true
	menu_overlay_mask.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	game_menu_panel.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	modal_ui_open = true
	_refresh_game_menu_content()
	_switch_game_menu_page(page_key)
	menu_overlay_mask.move_to_front()
	game_menu_panel.move_to_front()
	modal_fade_tween = create_tween()
	modal_fade_tween.set_parallel(true)
	modal_fade_tween.tween_property(menu_overlay_mask, "self_modulate:a", 1.0, 0.16)
	modal_fade_tween.tween_property(game_menu_panel, "self_modulate:a", 1.0, 0.16)
	modal_fade_tween.chain().tween_callback(Callable(self, "_clear_modal_fade_tween"))
	_apply_ui_layout()
	_update_interaction_state(false)



func _on_game_menu_nav_pressed(page_key: String) -> void:
	_switch_game_menu_page(page_key)



func _switch_game_menu_page(page_key: String) -> void:
	var target: String = page_key if game_menu_pages.has(page_key) else "history"
	_set_game_menu_background_blur(target == "settings")
	var title_map: Dictionary = {
		"history": "历史",
		"save": "保存",
		"load": "读取游戏",
		"settings": "设置",
		"about": "关于",
		"help": "帮助"
	}
	game_menu_current_page = target
	if game_menu_title != null:
		game_menu_title.text = String(title_map.get(target, "菜单"))
	for key_v in game_menu_pages.keys():
		var page_v: Variant = game_menu_pages.get(key_v, null)
		if page_v is Control:
			(page_v as Control).visible = String(key_v) == target
	for key_v2 in game_menu_nav_buttons.keys():
		var btn_v: Variant = game_menu_nav_buttons.get(key_v2, null)
		if btn_v is Button:
			var selected: bool = String(key_v2) == target
			var nav_btn: Button = btn_v as Button
			nav_btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95) if selected else Color(0.72, 0.72, 0.72))
			nav_btn.add_theme_color_override("font_hover_color", Color(0.98, 0.98, 0.98))



func _refresh_game_menu_content() -> void:
	_rebuild_history_panel()
	_refresh_save_panel()
	_sync_settings_ui_from_audio()



func _slot_index_from_cell(page_index: int, cell_index: int) -> int:
	return (page_index - 1) * SLOT_SAVE_PER_PAGE + cell_index + 1



func _format_saved_ts(unix_ts: int) -> String:
	if unix_ts <= 0:
		return "--"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_ts)
	return "%04d-%02d-%02d %02d:%02d" % [
		int(dt.get("year", 0)),
		int(dt.get("month", 0)),
		int(dt.get("day", 0)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0))
	]




func _load_slot_thumb_texture(snapshot: Dictionary) -> Texture2D:
	var rel_path: String = String(snapshot.get("thumbnail_rel_path", "")).strip_edges()
	if rel_path.is_empty():
		return null
	if not FileAccess.file_exists(rel_path):
		return null
	var cache_key: String = "%s#%s" % [rel_path, str(int(snapshot.get("saved_at_ts", 0)))]
	var cached_v: Variant = slot_thumb_texture_cache.get(cache_key, null)
	if cached_v is Texture2D:
		return cached_v as Texture2D
	var image: Image = Image.new()
	if image.load(rel_path) != OK:
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	slot_thumb_texture_cache[cache_key] = texture
	return texture


func _refresh_slot_buttons(is_save_page: bool) -> void:
	var page_index: int = save_page_index
	var selected_slot: int = save_selected_slot
	var page_label: Label = save_page_label
	var buttons: Array[Button] = save_slot_buttons
	if not is_save_page:
		page_index = load_page_index
		selected_slot = load_selected_slot
		page_label = load_page_label
		buttons = load_slot_buttons
	if page_label != null:
		page_label.text = "第 %s 页（选中槽位：%s）" % [str(page_index), str(selected_slot)]
	for cell_idx in range(buttons.size()):
		var btn: Button = buttons[cell_idx]
		var slot_index: int = _slot_index_from_cell(page_index, cell_idx)
		var snapshot: Dictionary = {}
		if has_method("_get_slot_snapshot"):
			var snapshot_v: Variant = call("_get_slot_snapshot", slot_index)
			if typeof(snapshot_v) == TYPE_DICTIONARY:
				snapshot = snapshot_v as Dictionary
		var has_data: bool = not snapshot.is_empty()
		var line_top: String = "槽位 %02d" % slot_index
		var line_mid: String = "空存档位"
		var line_bottom: String = "点击%s" % ("保存" if is_save_page else "读取")
		if has_data:
			line_mid = _format_saved_ts(int(snapshot.get("saved_at_ts", 0)))
			line_bottom = "第%s天 %s %s  好感%s" % [
				str(int(snapshot.get("living_days", 0))),
				String(snapshot.get("display_time", "--:--")),
				String(snapshot.get("time_period_name", "")),
				str(int(snapshot.get("love_score", 0)))
			]
		var top_v: Variant = btn.get_meta("slot_line_top", null)
		if top_v is Label:
			(top_v as Label).text = line_top
		var mid_v: Variant = btn.get_meta("slot_line_mid", null)
		if mid_v is Label:
			(mid_v as Label).text = line_mid
		var bottom_v: Variant = btn.get_meta("slot_line_bottom", null)
		if bottom_v is Label:
			(bottom_v as Label).text = line_bottom
		var thumb_v: Variant = btn.get_meta("slot_thumb", null)
		var preview_texture: Texture2D = null
		if has_data:
			preview_texture = _load_slot_thumb_texture(snapshot)
		if thumb_v is ColorRect:
			var thumb: ColorRect = thumb_v as ColorRect
			var card_h: float = btn.size.y
			if card_h <= 1.0:
				card_h = btn.custom_minimum_size.y
			var target_thumb_h: float = clampf(card_h * 0.74, 168.0, 236.0)
			thumb.custom_minimum_size = Vector2(0.0, target_thumb_h)
			thumb.clip_contents = true
			if preview_texture != null:
				thumb.color = Color(0.08, 0.08, 0.08, 1.0)
			else:
				thumb.color = Color(0.16, 0.16, 0.16, 1.0) if has_data else Color(0.10, 0.10, 0.10, 1.0)
		var thumb_preview_v: Variant = btn.get_meta("slot_thumb_preview", null)
		if thumb_preview_v is TextureRect:
			var thumb_preview: TextureRect = thumb_preview_v as TextureRect
			thumb_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
			thumb_preview.offset_left = 0.0
			thumb_preview.offset_top = 0.0
			thumb_preview.offset_right = 0.0
			thumb_preview.offset_bottom = 0.0
			thumb_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			thumb_preview.texture = preview_texture
		var thumb_label_v: Variant = btn.get_meta("slot_thumb_label", null)
		if thumb_label_v is Label:
			var thumb_label: Label = thumb_label_v as Label
			if preview_texture != null:
				thumb_label.text = ""
			else:
				thumb_label.text = "USED" if has_data else "EMPTY"
		var selected: bool = slot_index == selected_slot
		if selected:
			btn.theme_type_variation = VAR_SLOT_USED_SELECTED if has_data else VAR_SLOT_EMPTY_SELECTED
		else:
			btn.theme_type_variation = VAR_SLOT_USED if has_data else VAR_SLOT_EMPTY



func _on_save_page_pressed(page_n: int) -> void:
	save_page_index = clampi(page_n, 1, SLOT_SAVE_PAGE_COUNT)
	save_selected_slot = _slot_index_from_cell(save_page_index, 0)
	_refresh_slot_buttons(true)



func _on_load_page_pressed(page_n: int) -> void:
	load_page_index = clampi(page_n, 1, SLOT_SAVE_PAGE_COUNT)
	load_selected_slot = _slot_index_from_cell(load_page_index, 0)
	_refresh_slot_buttons(false)



func _on_save_slot_pressed(cell_idx: int) -> void:
	save_selected_slot = _slot_index_from_cell(save_page_index, cell_idx)
	_refresh_slot_buttons(true)
	_open_save_slot_confirm(save_selected_slot)



func _on_load_slot_pressed(cell_idx: int) -> void:
	load_selected_slot = _slot_index_from_cell(load_page_index, cell_idx)
	_refresh_slot_buttons(false)
	_open_load_slot_confirm(load_selected_slot)



func _rebuild_history_panel() -> void:
	if history_text == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	for item_v in state.chat_history:
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v
		var role: String = String(item.get("role", "user"))
		var content: String = String(item.get("content", "")).strip_edges()
		if content.is_empty():
			continue
		var label: String = "哥哥" if role == "user" else "维多利亚"
		lines.append("[color=#ffffff]%s[/color]  %s" % [label, content])
	if lines.is_empty():
		history_text.text = "暂无历史对话。"
	else:
		history_text.text = "\n\n".join(lines)



func _refresh_save_panel() -> void:
	var info_text: String = "当前进度：第%s天 %s %s | 好感度：%s" % [
		str(state.living_days),
		state.display_time,
		state.time_period_name,
		str(state.love_score)
	]
	if save_info_label != null:
		save_info_label.text = info_text
	if load_info_label != null:
		load_info_label.text = info_text
	_refresh_slot_buttons(true)
	_refresh_slot_buttons(false)



func _on_save_panel_save_pressed() -> void:
	if has_method("_save_to_slot") and bool(call("_save_to_slot", save_selected_slot)):
		_refresh_save_panel()
		_show_notify("已保存到槽位 %s" % str(save_selected_slot))
	else:
		_show_notify("保存失败")



func _on_save_panel_load_pressed() -> void:
	if has_method("_load_from_slot") and bool(call("_load_from_slot", load_selected_slot)):
		mode = "chat"
		_apply_scene_by_state()
		_set_character_by_mood(latest_mood)
		_sync_period_music(0.2)
		_update_hud()
		_update_interaction_state(false)
		_refresh_save_panel()
		_show_notify("已读取槽位 %s" % str(load_selected_slot))
	else:
		_show_notify("该槽位暂无存档")



func _load_quick_runtime_state() -> void:
	if has_method("_load_runtime_state") and bool(call("_load_runtime_state")):
		mode = "chat"
		_apply_scene_by_state()
		_set_character_by_mood(latest_mood)
		_sync_period_music(0.2)
		_update_hud()
		_update_interaction_state(false)
		_refresh_save_panel()
		_show_notify("已读取 runtime_save")
	else:
		_show_notify("无可用读档")



func _on_bgm_slider_changed(value: float) -> void:
	state.bgm_volume_percent = clampf(value, 0.0, 100.0)
	if has_method("_apply_audio_volume_preferences"):
		call("_apply_audio_volume_preferences")
	if has_method("_save_runtime_state"):
		call("_save_runtime_state")



func _on_sfx_slider_changed(value: float) -> void:
	state.sfx_volume_percent = clampf(value, 0.0, 100.0)
	if has_method("_apply_audio_volume_preferences"):
		call("_apply_audio_volume_preferences")
	if has_method("_save_runtime_state"):
		call("_save_runtime_state")



func _sync_settings_ui_from_audio() -> void:
	if bgm_slider != null:
		bgm_slider.value = clampf(state.bgm_volume_percent, 0.0, 100.0)
	if sfx_slider != null:
		sfx_slider.value = clampf(state.sfx_volume_percent, 0.0, 100.0)
	_refresh_settings_misc_buttons()



func _refresh_settings_misc_buttons() -> void:
	if settings_display_button != null:
		settings_display_button.text = "显示：%s" % ("全屏" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "窗口")
	if settings_skip_button != null:
		settings_skip_button.text = "快进默认：%s" % ("开" if quick_skip_enabled else "关")
	if settings_auto_button != null:
		settings_auto_button.text = "自动模式：%s" % ("开" if quick_auto_enabled else "关")
	if settings_return_main_menu_button != null:
		settings_return_main_menu_button.text = "回到主菜单"



func _on_settings_display_pressed() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	var is_fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_settings_misc_buttons()



func _on_settings_skip_pressed() -> void:
	quick_skip_enabled = not quick_skip_enabled
	if quick_skip_enabled:
		quick_auto_enabled = false
	_refresh_quick_menu_captions()
	_refresh_settings_misc_buttons()



func _on_settings_auto_pressed() -> void:
	quick_auto_enabled = not quick_auto_enabled
	if quick_auto_enabled:
		quick_skip_enabled = false
	_refresh_quick_menu_captions()
	_refresh_settings_misc_buttons()


func _on_settings_return_main_menu_pressed() -> void:
	_open_main_menu_return_confirm()



func _open_save_slot_confirm(slot_index: int) -> void:
	if slot_index < 1 or slot_index > SLOT_SAVE_MAX:
		return
	if save_slot_confirm_overlay == null or save_slot_confirm_panel == null:
		_on_save_panel_save_pressed()
		return
	pending_slot_action = "save"
	pending_save_slot = slot_index
	if save_slot_confirm_title != null:
		save_slot_confirm_title.text = "\u786e\u8ba4\u4fdd\u5b58"
	if save_slot_confirm_hint != null:
		save_slot_confirm_hint.text = "\u662f\u5426\u4fdd\u5b58\u5230\u69fd\u4f4d %s\uff1f" % str(slot_index)
	if save_slot_confirm_accept_button != null:
		save_slot_confirm_accept_button.text = "\u786e\u8ba4\u4fdd\u5b58"
	save_slot_confirm_overlay.visible = true
	save_slot_confirm_panel.visible = true
	save_slot_confirm_overlay.move_to_front()
	save_slot_confirm_panel.move_to_front()
	_animate_popup_open(save_slot_confirm_overlay, save_slot_confirm_panel)
	modal_ui_open = true
	_update_interaction_state(false)


func _open_load_slot_confirm(slot_index: int) -> void:
	if slot_index < 1 or slot_index > SLOT_SAVE_MAX:
		return
	if save_slot_confirm_overlay == null or save_slot_confirm_panel == null:
		_on_save_panel_load_pressed()
		return
	pending_slot_action = "load"
	pending_save_slot = slot_index
	if save_slot_confirm_title != null:
		save_slot_confirm_title.text = "\u786e\u8ba4\u8bfb\u53d6"
	if save_slot_confirm_hint != null:
		save_slot_confirm_hint.text = "\u662f\u5426\u8bfb\u53d6\u69fd\u4f4d %s\uff1f" % str(slot_index)
	if save_slot_confirm_accept_button != null:
		save_slot_confirm_accept_button.text = "\u786e\u8ba4\u8bfb\u53d6"
	save_slot_confirm_overlay.visible = true
	save_slot_confirm_panel.visible = true
	save_slot_confirm_overlay.move_to_front()
	save_slot_confirm_panel.move_to_front()
	_animate_popup_open(save_slot_confirm_overlay, save_slot_confirm_panel)
	modal_ui_open = true
	_update_interaction_state(false)


func _is_save_slot_confirm_open() -> bool:
	return save_slot_confirm_overlay != null and save_slot_confirm_overlay.visible


func _close_save_slot_confirm() -> bool:
	if save_slot_confirm_overlay == null:
		return false
	if not save_slot_confirm_overlay.visible:
		return false
	save_slot_confirm_overlay.visible = false
	if save_slot_confirm_panel != null:
		save_slot_confirm_panel.visible = false
	pending_save_slot = -1
	pending_slot_action = ""
	modal_ui_open = game_menu_panel != null and game_menu_panel.visible
	_update_interaction_state(false)
	return true


func _on_save_slot_confirm_overlay_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		_close_save_slot_confirm()


func _on_save_slot_confirm_accept_pressed() -> void:
	if pending_save_slot < 1:
		_close_save_slot_confirm()
		return
	var slot_index: int = pending_save_slot
	var action: String = pending_slot_action
	_close_save_slot_confirm()
	if action == "load":
		load_selected_slot = slot_index
		_on_save_panel_load_pressed()
	else:
		save_selected_slot = slot_index
		_on_save_panel_save_pressed()


func _on_save_slot_confirm_cancel_pressed() -> void:
	_close_save_slot_confirm()


func _open_main_menu_return_confirm() -> void:
	_close_save_slot_confirm()
	if main_menu_confirm_overlay == null or main_menu_confirm_panel == null:
		_show_notify("未找到主菜单确认弹窗节点。")
		return
	main_menu_confirm_overlay.visible = true
	main_menu_confirm_panel.visible = true
	main_menu_confirm_overlay.move_to_front()
	main_menu_confirm_panel.move_to_front()
	_animate_popup_open(main_menu_confirm_overlay, main_menu_confirm_panel)
	modal_ui_open = true
	_update_interaction_state(false)


func _is_main_menu_return_confirm_open() -> bool:
	return main_menu_confirm_overlay != null and main_menu_confirm_overlay.visible


func _close_main_menu_return_confirm() -> bool:
	if main_menu_confirm_overlay == null:
		return false
	if not main_menu_confirm_overlay.visible:
		return false
	main_menu_confirm_overlay.visible = false
	if main_menu_confirm_panel != null:
		main_menu_confirm_panel.visible = false
	modal_ui_open = game_menu_panel != null and game_menu_panel.visible
	_update_interaction_state(false)
	return true


func _on_main_menu_confirm_overlay_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		_close_main_menu_return_confirm()


func _on_main_menu_confirm_save_pressed() -> void:
	_return_to_main_menu(true)


func _on_main_menu_confirm_no_save_pressed() -> void:
	_return_to_main_menu(false)


func _on_main_menu_confirm_cancel_pressed() -> void:
	_close_main_menu_return_confirm()


func _return_to_main_menu(save_runtime: bool) -> void:
	_close_save_slot_confirm()
	if save_runtime:
		_save_runtime_state()
	elif has_method("_restore_unsaved_baseline"):
		call("_restore_unsaved_baseline")
	_close_main_menu_return_confirm()
	if menu_overlay_mask != null:
		menu_overlay_mask.visible = false
	if game_menu_panel != null:
		game_menu_panel.visible = false
	modal_ui_open = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

