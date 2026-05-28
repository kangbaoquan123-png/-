extends Control

const GAME_SCENE_PATH := "res://node_2d.tscn"
const MENU_HOVER_PREFIX := "▶ "
const USER_PREFS_SCRIPT := preload("res://scripts/core/victoria_user_prefs.gd")
const SLOT_SAVE_DIR := "user://save_slots"
const SLOT_SAVE_PAGE_COUNT := 9
const SLOT_SAVE_COLS := 3
const SLOT_SAVE_ROWS := 2
const SLOT_SAVE_PER_PAGE := SLOT_SAVE_COLS * SLOT_SAVE_ROWS
const SLOT_SAVE_MAX := SLOT_SAVE_PAGE_COUNT * SLOT_SAVE_PER_PAGE
const ENABLE_TEMPLATE_LOAD_UI := false
const FONT_UI_PATH := "res://assets/fonts/SourceHanSansLite.ttf"
const FONT_DIALOGUE_PATH := "res://assets/fonts/LXGWWenKai-Regular.ttf"
const FONT_TITLE_PATH := "res://assets/fonts/SmileySans-Oblique.ttf"
const UI_HOVER_SOUND_PATH := "res://assets/audio/ui_hover.wav"
const UI_CLICK_SOUND_PATH := "res://assets/audio/ui_click.wav"
const UI_HOVER_DEBOUNCE_MS := 70
const UI_HOVER_GAIN_OFFSET_DB := -11.0
const UI_CLICK_GAIN_OFFSET_DB := 3.0
const DEFAULT_API_PROVIDER_ID := "deepseek"
const API_PROVIDER_PRESETS := [
	{
		"id": "deepseek",
		"label": "DeepSeek",
		"base_url": "https://api.deepseek.com/chat/completions",
		"model": "deepseek-chat"
	},
	{
		"id": "openai",
		"label": "OpenAI",
		"base_url": "https://api.openai.com/v1/chat/completions",
		"model": "gpt-4.1-mini"
	},
	{
		"id": "siliconflow",
		"label": "SiliconFlow",
		"base_url": "https://api.siliconflow.cn/v1/chat/completions",
		"model": "deepseek-ai/DeepSeek-V3"
	},
	{
		"id": "openrouter",
		"label": "OpenRouter",
		"base_url": "https://openrouter.ai/api/v1/chat/completions",
		"model": "openai/gpt-4.1-mini"
	},
	{
		"id": "gemini",
		"label": "Gemini",
		"base_url": "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
		"model": "gemini-2.5-flash"
	},
	{
		"id": "custom",
		"label": "自定义",
		"base_url": "",
		"model": ""
	}
]

const MENU_LABELS := {
	"start": "开始游戏",
	"load": "读取游戏",
	"settings": "设置",
	"about": "关于",
	"help": "帮助",
	"quit": "退出"
}

const INFO_PAGES := {
	"about": {
		"title": "关于",
		"body": "《维多利亚》Godot 迁移版。\n\n当前阶段目标：先完成可见模块闭环，再做细节打磨。"
	},
	"help": {
		"title": "帮助",
		"body": "操作说明：\n- 主菜单：鼠标左键点击选项。\n- 对话推进：点击屏幕继续。\n- 对话发送：回车发送。\n- 游戏内菜单：可进行保存/读取/设置。"
	}
}

@onready var start_button: Button = $导航根/导航盒/开始按钮
@onready var load_button: Button = $导航根/导航盒/读取按钮
@onready var settings_button: Button = $导航根/导航盒/设置按钮
@onready var about_button: Button = $导航根/导航盒/关于按钮
@onready var help_button: Button = $导航根/导航盒/帮助按钮
@onready var quit_button: Button = $导航根/导航盒/退出按钮
@onready var template_continue_button: Button = get_node_or_null(
	"模板主菜单/标题画布/标题界面/右侧布局/右侧边距/内容列/菜单按钮边距/菜单按钮居中器/菜单按钮列/继续按钮"
) as Button
@onready var template_new_game_button: Button = get_node_or_null(
	"模板主菜单/标题画布/标题界面/右侧布局/右侧边距/内容列/菜单按钮边距/菜单按钮居中器/菜单按钮列/新游戏按钮"
) as Button
@onready var template_options_button: Button = get_node_or_null(
	"模板主菜单/标题画布/标题界面/右侧布局/右侧边距/内容列/菜单按钮边距/菜单按钮居中器/菜单按钮列/选项按钮"
) as Button
@onready var template_credits_button: Button = get_node_or_null(
	"模板主菜单/标题画布/标题界面/右侧布局/右侧边距/内容列/菜单按钮边距/菜单按钮居中器/菜单按钮列/制作信息按钮"
) as Button
@onready var template_help_button: Button = get_node_or_null(
	"模板主菜单/标题画布/标题界面/右侧布局/右侧边距/内容列/菜单按钮边距/菜单按钮居中器/菜单按钮列/帮助按钮"
) as Button
@onready var template_quit_button: Button = get_node_or_null(
	"模板主菜单/标题画布/标题界面/右侧布局/右侧边距/内容列/菜单按钮边距/菜单按钮居中器/菜单按钮列/退出按钮"
) as Button
@onready var template_menu_click_layer: Control = $模板菜单点击层

@onready var overlay_layer: CanvasLayer = $覆盖画布
@onready var settings_overlay: Control = $设置界面
@onready var settings_backdrop_button: Button = $设置界面/背景按钮
@onready var bgm_slider: HSlider = $设置界面/设置根/设置盒/音乐行/音乐滑条
@onready var bgm_value_label: Label = $设置界面/设置根/设置盒/音乐行/音乐数值
@onready var sfx_slider: HSlider = $设置界面/设置根/设置盒/音效行/音效滑条
@onready var sfx_value_label: Label = $设置界面/设置根/设置盒/音效行/音效数值
@onready var display_button: Button = $设置界面/设置根/设置盒/显示模式按钮
@onready var api_reconfig_button: Button = $设置界面/设置根/设置盒/重填API按钮
@onready var settings_close_button: Button = $设置界面/设置根/设置盒/设置返回按钮

@onready var info_overlay: Control = $信息界面
@onready var info_backdrop_button: Button = $信息界面/背景按钮
@onready var info_title_label: Label = $信息界面/信息根/信息盒/信息标题
@onready var info_body_label: RichTextLabel = $信息界面/信息根/信息盒/信息正文
@onready var info_close_button: Button = $信息界面/信息根/信息盒/信息操作行/信息返回按钮

@onready var load_overlay: Control = $读取界面
@onready var load_backdrop_button: Button = $读取界面/背景按钮
@onready var template_load_ui: Control = $读取界面/模板读取界面
@onready var legacy_load_panel_bg: ColorRect = $读取界面/读取面板背景
@onready var legacy_load_root: MarginContainer = $读取界面/读取根
@onready var load_page_prev_button: Button = $读取界面/读取根/读取盒/读取页码行/读取上一页按钮
@onready var load_page_label: Label = $读取界面/读取根/读取盒/读取页码行/读取页码标签
@onready var load_page_next_button: Button = $读取界面/读取根/读取盒/读取页码行/读取下一页按钮
@onready var load_info_label: Label = $读取界面/读取根/读取盒/读取说明标签
@onready var load_enter_button: Button = $读取界面/读取根/读取盒/读取操作行/载入按钮
@onready var load_close_button: Button = $读取界面/读取根/读取盒/读取操作行/读取返回按钮

@onready var load_slot_buttons: Array[Button] = [
	$读取界面/读取根/读取盒/读取网格/读取槽位1,
	$读取界面/读取根/读取盒/读取网格/读取槽位2,
	$读取界面/读取根/读取盒/读取网格/读取槽位3,
	$读取界面/读取根/读取盒/读取网格/读取槽位4,
	$读取界面/读取根/读取盒/读取网格/读取槽位5,
	$读取界面/读取根/读取盒/读取网格/读取槽位6
]
@onready var template_load_root: Node = get_node_or_null("读取界面/模板读取界面/读取界面根")
@onready var template_load_top_close_button: Button = get_node_or_null(
	"读取界面/模板读取界面/读取界面根/右上区域/右上按钮列/顶部返回按钮"
) as Button

var info_page_key: String = ""
var load_page: int = 1
var load_selected_slot: int = 0
var load_slot_cache: Dictionary = {}
var use_template_load_ui: bool = false
var template_menu_hover_button: Button = null
var api_key_dialog: Control = null
var api_provider_option: OptionButton = null
var api_base_url_input: LineEdit = null
var api_model_input: LineEdit = null
var api_key_input: LineEdit = null
var api_key_error_label: Label = null
var api_hint_label: Label = null
var api_key_confirm_button: Button = null
var api_dialog_updating: bool = false
var start_game_after_key_confirm: bool = false
var ui_sfx_player: AudioStreamPlayer = null
var ui_hover_stream: AudioStream = null
var ui_click_stream: AudioStream = null
var ui_last_hover_tick_msec: int = -1000
var menu_font_ui: FontFile = null
var menu_font_dialogue: FontFile = null
var menu_font_title: FontFile = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_menu_fonts()
	_setup_ui_sfx()
	_move_overlays_to_canvas_layer()
	_configure_load_overlay_mode()
	_bind_template_load_ui_if_present()
	_apply_main_menu_text_style()
	_apply_overlay_styles()
	_connect_main_menu_signals()
	_setup_template_menu_click_proxies()
	_connect_overlay_signals()
	_refresh_settings_overlay()
	_refresh_load_overlay()
	if not resized.is_connected(_on_root_resized):
		resized.connect(_on_root_resized)
	_request_template_menu_proxy_sync()


func _process(_delta: float) -> void:
	if _is_any_overlay_open():
		_clear_template_menu_hover()
		return
	_update_template_menu_hover_at(get_viewport().get_mouse_position())


func _on_start_pressed() -> void:
	if _requires_startup_api_key():
		_open_api_key_dialog_for_start()
		return
	_launch_game_with_menu_page("", true)


func _on_load_pressed() -> void:
	_open_load_overlay()


func _on_settings_pressed() -> void:
	_close_info_overlay()
	_close_load_overlay()
	settings_overlay.visible = true
	_refresh_settings_overlay()


func _on_about_pressed() -> void:
	_open_info_overlay("about")


func _on_help_pressed() -> void:
	_open_info_overlay("help")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	if api_key_dialog != null and api_key_dialog.visible:
		if key_event.keycode == KEY_ESCAPE:
			_on_api_key_dialog_canceled()
			_close_api_key_dialog()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			_on_api_key_dialog_confirmed()
			get_viewport().set_input_as_handled()
			return
	if _is_any_overlay_open():
		if key_event.keycode == KEY_ESCAPE:
			_close_overlays()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			if load_overlay.visible:
				_on_load_enter_pressed()
			else:
				_close_overlays()
			get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_on_start_pressed()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_ESCAPE:
		_on_quit_pressed()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _is_any_overlay_open():
		_clear_template_menu_hover()
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_template_menu_hover_at(motion.position)
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var action: String = _template_menu_action_at(mouse_event.position)
	if action.is_empty():
		return
	get_viewport().set_input_as_handled()
	_activate_template_menu_action(action)


func _gui_input(event: InputEvent) -> void:
	if _is_any_overlay_open():
		_clear_template_menu_hover()
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_template_menu_hover_at(motion.position)
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var action: String = _template_menu_action_at(mouse_event.position)
	if action.is_empty():
		return
	accept_event()
	_activate_template_menu_action(action)


func _apply_main_menu_text_style() -> void:
	var menu_buttons: Array[Button] = [
		start_button,
		load_button,
		settings_button,
		about_button,
		help_button,
		quit_button,
		template_continue_button,
		template_new_game_button,
		template_options_button,
		template_credits_button,
		template_help_button,
		template_quit_button
	]
	var clear_style: StyleBoxEmpty = StyleBoxEmpty.new()
	for button in menu_buttons:
		if button == null:
			continue
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_button_font(button, 38, "title")
		if button == start_button or button == load_button or button == settings_button or button == about_button or button == help_button or button == quit_button:
			button.flat = true
			_apply_clear_button_style(button, clear_style)
	start_button.text = String(MENU_LABELS.get("start", start_button.text))
	load_button.text = String(MENU_LABELS.get("load", load_button.text))
	settings_button.text = String(MENU_LABELS.get("settings", settings_button.text))
	about_button.text = String(MENU_LABELS.get("about", about_button.text))
	help_button.text = String(MENU_LABELS.get("help", help_button.text))
	quit_button.text = String(MENU_LABELS.get("quit", quit_button.text))
	if template_continue_button != null:
		template_continue_button.text = String(MENU_LABELS.get("load", template_continue_button.text))
	if template_new_game_button != null:
		template_new_game_button.text = String(MENU_LABELS.get("start", template_new_game_button.text))
	if template_options_button != null:
		template_options_button.text = String(MENU_LABELS.get("settings", template_options_button.text))
	if template_credits_button != null:
		template_credits_button.text = String(MENU_LABELS.get("about", template_credits_button.text))
	if template_help_button != null:
		template_help_button.text = String(MENU_LABELS.get("help", template_help_button.text))
	if template_quit_button != null:
		template_quit_button.text = String(MENU_LABELS.get("quit", template_quit_button.text))
	var template_buttons: Array[Button] = [
		template_continue_button,
		template_new_game_button,
		template_options_button,
		template_credits_button,
		template_help_button,
		template_quit_button
	]
	for button in template_buttons:
		_configure_template_menu_button(button)


func _apply_overlay_styles() -> void:
	var clear_style: StyleBoxEmpty = StyleBoxEmpty.new()
	_apply_clear_button_style(settings_backdrop_button, clear_style)
	_apply_clear_button_style(info_backdrop_button, clear_style)
	_apply_clear_button_style(load_backdrop_button, clear_style)

	_apply_secondary_button_style(display_button)
	_apply_secondary_button_style(api_reconfig_button)
	_apply_secondary_button_style(settings_close_button)
	_apply_secondary_button_style(info_close_button)
	if not use_template_load_ui:
		_apply_secondary_button_style(load_page_prev_button)
		_apply_secondary_button_style(load_page_next_button)
		_apply_secondary_button_style(load_enter_button)
		_apply_secondary_button_style(load_close_button)

	var info_body_style: StyleBoxFlat = _make_flat_style(
		Color(0.04, 0.04, 0.04, 0.82), Color(0.26, 0.26, 0.26, 1.0), 1, 4, 14, 12, 14, 12
	)
	info_body_label.add_theme_stylebox_override("normal", info_body_style)
	_apply_label_font(info_title_label, 34, "title")
	_apply_richtext_font(info_body_label, 24, "dialogue")
	_apply_label_font(load_page_label, 22, "ui")
	_apply_label_font(load_info_label, 22, "dialogue")
	_apply_label_font(bgm_value_label, 22, "ui")
	_apply_label_font(sfx_value_label, 22, "ui")


func _connect_main_menu_signals() -> void:
	_connect_button_pressed(start_button, _on_start_pressed)
	_connect_button_pressed(load_button, _on_load_pressed)
	_connect_button_pressed(settings_button, _on_settings_pressed)
	_connect_button_pressed(about_button, _on_about_pressed)
	_connect_button_pressed(help_button, _on_help_pressed)
	_connect_button_pressed(quit_button, _on_quit_pressed)
	_connect_button_pressed(template_new_game_button, _on_start_pressed)
	_connect_button_pressed(template_continue_button, _on_load_pressed)
	_connect_button_pressed(template_options_button, _on_settings_pressed)
	_connect_button_pressed(template_credits_button, _on_about_pressed)
	_connect_button_pressed(template_help_button, _on_help_pressed)
	_connect_button_pressed(template_quit_button, _on_quit_pressed)


func _connect_overlay_signals() -> void:
	settings_backdrop_button.pressed.connect(_close_settings_overlay)
	settings_close_button.pressed.connect(_close_settings_overlay)
	_bind_button_sfx(settings_backdrop_button)
	_bind_button_sfx(settings_close_button)
	_connect_button_pressed(api_reconfig_button, _open_api_reconfig_dialog)
	display_button.pressed.connect(_on_display_button_pressed)
	_bind_button_sfx(display_button)
	bgm_slider.value_changed.connect(_on_bgm_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)

	info_backdrop_button.pressed.connect(_close_info_overlay)
	info_close_button.pressed.connect(_close_info_overlay)
	_bind_button_sfx(info_backdrop_button)
	_bind_button_sfx(info_close_button)

	load_backdrop_button.pressed.connect(_close_load_overlay)
	load_close_button.pressed.connect(_close_load_overlay)
	_bind_button_sfx(load_backdrop_button)
	_bind_button_sfx(load_close_button)
	if template_load_top_close_button != null:
		template_load_top_close_button.pressed.connect(_close_load_overlay)
		_bind_button_sfx(template_load_top_close_button)
	load_page_prev_button.pressed.connect(_on_load_page_prev_pressed)
	load_page_next_button.pressed.connect(_on_load_page_next_pressed)
	load_enter_button.pressed.connect(_on_load_enter_pressed)
	_bind_button_sfx(load_page_prev_button)
	_bind_button_sfx(load_page_next_button)
	_bind_button_sfx(load_enter_button)
	for i in range(load_slot_buttons.size()):
		var slot_button: Button = load_slot_buttons[i]
		var slot_index: int = i + 1
		slot_button.pressed.connect(Callable(self, "_on_load_slot_pressed").bind(slot_index))
		_bind_button_sfx(slot_button)


func _refresh_settings_overlay() -> void:
	var bgm_value: int = int(round(clampf(float(bgm_slider.value), 0.0, 100.0)))
	var sfx_value: int = int(round(clampf(float(sfx_slider.value), 0.0, 100.0)))
	bgm_value_label.text = "%d%%" % bgm_value
	sfx_value_label.text = "%d%%" % sfx_value
	var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	display_button.text = "显示：%s" % ("全屏" if fullscreen else "窗口")


func _on_display_button_pressed() -> void:
	var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_settings_overlay()


func _on_bgm_slider_changed(_value: float) -> void:
	_refresh_settings_overlay()


func _on_sfx_slider_changed(_value: float) -> void:
	_refresh_settings_overlay()
	_apply_ui_sfx_volume()


func _requires_startup_api_key() -> bool:
	return not _is_api_config_valid(_load_saved_api_config())


func _load_saved_api_config() -> Dictionary:
	var config_v: Variant = USER_PREFS_SCRIPT.load_api_config()
	if config_v is Dictionary:
		return config_v as Dictionary
	return {
		"provider": DEFAULT_API_PROVIDER_ID,
		"api_key": String(USER_PREFS_SCRIPT.load_deepseek_api_key()).strip_edges(),
		"base_url": "https://api.deepseek.com/chat/completions",
		"model": "deepseek-chat"
	}


func _is_api_config_valid(config: Dictionary) -> bool:
	var api_key: String = String(config.get("api_key", "")).strip_edges()
	var base_url: String = String(config.get("base_url", "")).strip_edges()
	var model: String = String(config.get("model", "")).strip_edges()
	return not api_key.is_empty() and not base_url.is_empty() and not model.is_empty()


func _open_api_key_dialog_for_start() -> void:
	_open_api_config_dialog(true)


func _open_api_reconfig_dialog() -> void:
	_open_api_config_dialog(false)


func _open_api_config_dialog(start_after_confirm: bool) -> void:
	_build_api_key_dialog()
	start_game_after_key_confirm = start_after_confirm
	_apply_api_config_to_dialog(_load_saved_api_config())
	_refresh_api_dialog_copy()
	_refresh_api_key_confirm_button()
	_set_api_key_dialog_error("")
	if api_key_dialog != null:
		api_key_dialog.visible = true
	call_deferred("_focus_api_key_input")


func _build_api_key_dialog() -> void:
	if api_key_dialog != null:
		return
	api_key_dialog = Control.new()
	api_key_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	api_key_dialog.offset_left = 0.0
	api_key_dialog.offset_top = 0.0
	api_key_dialog.offset_right = 0.0
	api_key_dialog.offset_bottom = 0.0
	api_key_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	api_key_dialog.visible = false
	if overlay_layer != null:
		overlay_layer.add_child(api_key_dialog)
	else:
		add_child(api_key_dialog)

	var backdrop_button: Button = Button.new()
	backdrop_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop_button.offset_left = 0.0
	backdrop_button.offset_top = 0.0
	backdrop_button.offset_right = 0.0
	backdrop_button.offset_bottom = 0.0
	backdrop_button.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop_button.focus_mode = Control.FOCUS_NONE
	backdrop_button.flat = true
	backdrop_button.text = ""
	_apply_clear_button_style(backdrop_button, StyleBoxEmpty.new())
	api_key_dialog.add_child(backdrop_button)

	var dim_layer: ColorRect = ColorRect.new()
	dim_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_layer.offset_left = 0.0
	dim_layer.offset_top = 0.0
	dim_layer.offset_right = 0.0
	dim_layer.offset_bottom = 0.0
	dim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_layer.color = Color(0.0, 0.0, 0.0, 0.58)
	api_key_dialog.add_child(dim_layer)

	var center_box: CenterContainer = CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_box.offset_left = 0.0
	center_box.offset_top = 0.0
	center_box.offset_right = 0.0
	center_box.offset_bottom = 0.0
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	api_key_dialog.add_child(center_box)

	var dialog_panel: PanelContainer = PanelContainer.new()
	dialog_panel.custom_minimum_size = Vector2(860.0, 460.0)
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog_panel.add_theme_stylebox_override(
		"panel",
		_make_flat_style(Color(0.11, 0.11, 0.11, 0.96), Color(0.35, 0.35, 0.35, 1.0), 1, 6, 0, 0, 0, 0)
	)
	center_box.add_child(dialog_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	dialog_panel.add_child(margin)

	var content_box: VBoxContainer = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	content_box.add_theme_constant_override("separation", 12)
	margin.add_child(content_box)

	var title_label: Label = Label.new()
	title_label.text = "\u914d\u7f6e\u5bf9\u8bdd API"
	_apply_label_font(title_label, 30, "title")
	content_box.add_child(title_label)

	api_hint_label = Label.new()
	api_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_label_font(api_hint_label, 18, "dialogue")
	content_box.add_child(api_hint_label)

	var provider_row: HBoxContainer = HBoxContainer.new()
	provider_row.add_theme_constant_override("separation", 12)
	content_box.add_child(provider_row)

	var provider_label: Label = Label.new()
	provider_label.custom_minimum_size = Vector2(136.0, 0.0)
	provider_label.text = "\u670d\u52a1\u5546"
	_apply_label_font(provider_label, 19, "ui")
	provider_row.add_child(provider_label)

	api_provider_option = OptionButton.new()
	api_provider_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	provider_row.add_child(api_provider_option)
	for preset_v in API_PROVIDER_PRESETS:
		if not (preset_v is Dictionary):
			continue
		var preset: Dictionary = preset_v as Dictionary
		var index: int = api_provider_option.get_item_count()
		api_provider_option.add_item(String(preset.get("label", "")))
		api_provider_option.set_item_metadata(index, String(preset.get("id", "custom")))

	var base_row: HBoxContainer = HBoxContainer.new()
	base_row.add_theme_constant_override("separation", 12)
	content_box.add_child(base_row)

	var base_label: Label = Label.new()
	base_label.custom_minimum_size = Vector2(136.0, 0.0)
	base_label.text = "\u63a5\u53e3\u5730\u5740"
	_apply_label_font(base_label, 19, "ui")
	base_row.add_child(base_label)

	api_base_url_input = LineEdit.new()
	api_base_url_input.placeholder_text = "https://api.example.com/v1/chat/completions"
	api_base_url_input.clear_button_enabled = true
	api_base_url_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_row.add_child(api_base_url_input)

	var model_row: HBoxContainer = HBoxContainer.new()
	model_row.add_theme_constant_override("separation", 12)
	content_box.add_child(model_row)

	var model_label: Label = Label.new()
	model_label.custom_minimum_size = Vector2(136.0, 0.0)
	model_label.text = "\u6a21\u578b"
	_apply_label_font(model_label, 19, "ui")
	model_row.add_child(model_label)

	api_model_input = LineEdit.new()
	api_model_input.placeholder_text = "deepseek-chat / gpt-4.1-mini"
	api_model_input.clear_button_enabled = true
	api_model_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_row.add_child(api_model_input)

	var key_row: HBoxContainer = HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 12)
	content_box.add_child(key_row)

	var key_label: Label = Label.new()
	key_label.custom_minimum_size = Vector2(136.0, 0.0)
	key_label.text = "API Key"
	_apply_label_font(key_label, 19, "ui")
	key_row.add_child(key_label)

	api_key_input = LineEdit.new()
	api_key_input.placeholder_text = "sk-xxxxxxxx"
	api_key_input.secret = true
	api_key_input.clear_button_enabled = true
	api_key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(api_key_input)

	api_key_error_label = Label.new()
	api_key_error_label.visible = false
	api_key_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	api_key_error_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
	_apply_label_font(api_key_error_label, 17, "ui")
	content_box.add_child(api_key_error_label)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 10)
	content_box.add_child(action_row)

	var cancel_button: Button = Button.new()
	cancel_button.text = "\u53d6\u6d88"
	cancel_button.custom_minimum_size = Vector2(120.0, 40.0)
	_apply_secondary_button_style(cancel_button)
	action_row.add_child(cancel_button)

	api_key_confirm_button = Button.new()
	api_key_confirm_button.custom_minimum_size = Vector2(180.0, 40.0)
	_apply_secondary_button_style(api_key_confirm_button)
	action_row.add_child(api_key_confirm_button)

	backdrop_button.pressed.connect(_on_api_key_dialog_canceled)
	cancel_button.pressed.connect(_on_api_key_dialog_canceled)
	api_key_confirm_button.pressed.connect(_on_api_key_dialog_confirmed)
	_bind_button_sfx(backdrop_button)
	_bind_button_sfx(cancel_button)
	_bind_button_sfx(api_key_confirm_button)
	api_provider_option.item_selected.connect(_on_api_provider_selected)
	api_base_url_input.text_changed.connect(_on_api_config_text_changed)
	api_model_input.text_changed.connect(_on_api_config_text_changed)
	api_key_input.text_changed.connect(_on_api_config_text_changed)
	api_key_input.text_submitted.connect(_on_api_key_text_submitted)
	_refresh_api_key_confirm_button()


func _focus_api_key_input() -> void:
	if api_key_input != null:
		api_key_input.grab_focus()


func _refresh_api_dialog_copy() -> void:
	if api_hint_label != null:
		if start_game_after_key_confirm:
			api_hint_label.text = "\u9996\u6b21\u5f00\u59cb\u6e38\u620f\u524d\u9700\u8981\u5148\u914d\u7f6e API\uff0c\u4fdd\u5b58\u540e\u4f1a\u81ea\u52a8\u8bb0\u4f4f\u3002"
		else:
			api_hint_label.text = "\u4f60\u53ef\u4ee5\u5728\u8fd9\u91cc\u968f\u65f6\u91cd\u586b API \u914d\u7f6e\uff0c\u4fdd\u5b58\u540e\u7acb\u5373\u751f\u6548\u3002"
	if api_key_confirm_button != null:
		api_key_confirm_button.text = "\u786e\u8ba4\u5e76\u5f00\u59cb" if start_game_after_key_confirm else "\u4fdd\u5b58\u914d\u7f6e"


func _api_preset_for_provider(provider_id: String) -> Dictionary:
	var wanted: String = String(provider_id).strip_edges().to_lower()
	for preset_v in API_PROVIDER_PRESETS:
		if not (preset_v is Dictionary):
			continue
		var preset: Dictionary = preset_v as Dictionary
		if String(preset.get("id", "")).strip_edges().to_lower() == wanted:
			return preset
	for preset_v in API_PROVIDER_PRESETS:
		if not (preset_v is Dictionary):
			continue
		var preset: Dictionary = preset_v as Dictionary
		if String(preset.get("id", "")).strip_edges().to_lower() == DEFAULT_API_PROVIDER_ID:
			return preset
	return {
		"id": DEFAULT_API_PROVIDER_ID,
		"label": "DeepSeek",
		"base_url": "https://api.deepseek.com/chat/completions",
		"model": "deepseek-chat"
	}


func _selected_api_provider_id() -> String:
	if api_provider_option == null or api_provider_option.get_item_count() <= 0:
		return DEFAULT_API_PROVIDER_ID
	var idx: int = api_provider_option.selected
	if idx < 0 or idx >= api_provider_option.get_item_count():
		idx = 0
	var meta: Variant = api_provider_option.get_item_metadata(idx)
	var provider_id: String = String(meta).strip_edges().to_lower()
	if provider_id.is_empty():
		provider_id = DEFAULT_API_PROVIDER_ID
	return provider_id


func _set_api_provider_selection(provider_id: String) -> void:
	if api_provider_option == null:
		return
	var wanted: String = String(provider_id).strip_edges().to_lower()
	for i in range(api_provider_option.get_item_count()):
		var meta: Variant = api_provider_option.get_item_metadata(i)
		if String(meta).strip_edges().to_lower() == wanted:
			api_provider_option.select(i)
			return
	api_provider_option.select(0)


func _apply_api_config_to_dialog(config: Dictionary) -> void:
	if api_provider_option == null:
		return
	api_dialog_updating = true
	var provider_id: String = String(config.get("provider", DEFAULT_API_PROVIDER_ID)).strip_edges().to_lower()
	if provider_id.is_empty():
		provider_id = DEFAULT_API_PROVIDER_ID
	_set_api_provider_selection(provider_id)
	var preset: Dictionary = _api_preset_for_provider(provider_id)
	if api_base_url_input != null:
		var base_url: String = String(config.get("base_url", preset.get("base_url", ""))).strip_edges()
		api_base_url_input.text = base_url
	if api_model_input != null:
		var model: String = String(config.get("model", preset.get("model", ""))).strip_edges()
		api_model_input.text = model
	if api_key_input != null:
		api_key_input.text = String(config.get("api_key", "")).strip_edges()
	api_dialog_updating = false


func _on_api_provider_selected(_index: int) -> void:
	if api_dialog_updating:
		return
	var provider_id: String = _selected_api_provider_id()
	var preset: Dictionary = _api_preset_for_provider(provider_id)
	var base_default: String = String(preset.get("base_url", "")).strip_edges()
	var model_default: String = String(preset.get("model", "")).strip_edges()
	if api_base_url_input != null and not base_default.is_empty():
		api_base_url_input.text = base_default
	if api_model_input != null and not model_default.is_empty():
		api_model_input.text = model_default
	_on_api_config_text_changed("")


func _on_api_config_text_changed(_new_text: String) -> void:
	_set_api_key_dialog_error("")
	_refresh_api_key_confirm_button()


func _on_api_key_text_submitted(_text: String) -> void:
	if api_key_dialog == null or not api_key_dialog.visible:
		return
	_on_api_key_dialog_confirmed()


func _on_api_key_dialog_confirmed() -> void:
	if api_key_input == null or api_base_url_input == null or api_model_input == null:
		return
	var provider_id: String = _selected_api_provider_id()
	var preset: Dictionary = _api_preset_for_provider(provider_id)
	var base_url: String = api_base_url_input.text.strip_edges()
	var model: String = api_model_input.text.strip_edges()
	var clean_key: String = api_key_input.text.strip_edges()
	if base_url.is_empty():
		base_url = String(preset.get("base_url", "")).strip_edges()
	if model.is_empty():
		model = String(preset.get("model", "")).strip_edges()
	if clean_key.is_empty():
		_set_api_key_dialog_error("\u8bf7\u8f93\u5165\u6709\u6548\u7684 API Key\u3002")
		_refresh_api_key_confirm_button()
		return
	if base_url.is_empty() or model.is_empty():
		_set_api_key_dialog_error("\u8bf7\u8865\u5168\u63a5\u53e3\u5730\u5740\u4e0e\u6a21\u578b\u3002")
		_refresh_api_key_confirm_button()
		return
	var save_ok: bool = bool(USER_PREFS_SCRIPT.save_api_config({
		"provider": provider_id,
		"api_key": clean_key,
		"base_url": base_url,
		"model": model
	}))
	if not save_ok:
		_set_api_key_dialog_error("\u4fdd\u5b58\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u672c\u5730 user:// \u5199\u5165\u6743\u9650\u3002")
		return
	_set_api_key_dialog_error("")
	if api_key_dialog != null:
		api_key_dialog.hide()
	if start_game_after_key_confirm:
		start_game_after_key_confirm = false
		_launch_game_with_menu_page("", true)


func _on_api_key_dialog_canceled() -> void:
	_close_api_key_dialog()


func _set_api_key_dialog_error(message: String) -> void:
	if api_key_error_label == null:
		return
	var clean_msg: String = String(message).strip_edges()
	api_key_error_label.text = clean_msg
	api_key_error_label.visible = not clean_msg.is_empty()


func _refresh_api_key_confirm_button() -> void:
	if api_key_confirm_button == null:
		return
	var can_confirm: bool = (
		api_key_input != null
		and api_base_url_input != null
		and api_model_input != null
		and not api_key_input.text.strip_edges().is_empty()
		and not api_base_url_input.text.strip_edges().is_empty()
		and not api_model_input.text.strip_edges().is_empty()
	)
	api_key_confirm_button.disabled = not can_confirm


func _close_api_key_dialog() -> void:
	start_game_after_key_confirm = false
	if api_key_dialog != null and api_key_dialog.visible:
		api_key_dialog.visible = false
	_set_api_key_dialog_error("")


func _open_info_overlay(page_key: String) -> void:
	var info_v: Variant = INFO_PAGES.get(page_key, null)
	if info_v == null or not (info_v is Dictionary):
		return
	_close_settings_overlay()
	_close_load_overlay()
	var info: Dictionary = info_v as Dictionary
	info_page_key = page_key
	info_title_label.text = String(info.get("title", "说明"))
	info_body_label.text = String(info.get("body", ""))
	info_overlay.visible = true


func _close_info_overlay() -> void:
	info_overlay.visible = false
	info_page_key = ""


func _open_load_overlay() -> void:
	_close_settings_overlay()
	_close_info_overlay()
	_configure_load_overlay_mode()
	load_overlay.visible = true
	_refresh_load_overlay()


func _close_load_overlay() -> void:
	load_overlay.visible = false


func _on_load_page_prev_pressed() -> void:
	if load_page <= 1:
		return
	load_page -= 1
	load_selected_slot = 0
	_refresh_load_overlay()


func _on_load_page_next_pressed() -> void:
	if load_page >= SLOT_SAVE_PAGE_COUNT:
		return
	load_page += 1
	load_selected_slot = 0
	_refresh_load_overlay()


func _on_load_slot_pressed(slot_local_index: int) -> void:
	var slot_index: int = (load_page - 1) * SLOT_SAVE_PER_PAGE + slot_local_index
	var snapshot: Dictionary = _get_slot_snapshot(slot_index)
	if snapshot.is_empty():
		load_selected_slot = 0
		load_info_label.text = "槽位 %d 为空。" % slot_index
	else:
		load_selected_slot = slot_index
		var day_v: int = int(snapshot.get("living_days", 0))
		var period_v: String = String(snapshot.get("time_period_name", ""))
		var time_v: String = String(snapshot.get("display_time", "--:--"))
		var love_v: int = int(snapshot.get("love_score", 0))
		load_info_label.text = "已选择槽位 %d：第 %d 天 | %s %s | 好感 %d" % [slot_index, day_v, period_v, time_v, love_v]
	_refresh_load_overlay()


func _on_load_enter_pressed() -> void:
	if not load_overlay.visible:
		return
	if load_selected_slot <= 0:
		load_info_label.text = "请先选择一个存档槽。"
		return
	var snapshot: Dictionary = _get_slot_snapshot(load_selected_slot)
	if snapshot.is_empty():
		load_info_label.text = "该槽位为空，无法载入。"
		return
	_launch_game_with_load_slot(load_selected_slot)


func _refresh_load_overlay() -> void:
	load_slot_cache.clear()
	load_page = clampi(load_page, 1, SLOT_SAVE_PAGE_COUNT)
	load_page_label.text = "第 %d / %d 页" % [load_page, SLOT_SAVE_PAGE_COUNT]
	load_page_prev_button.disabled = load_page <= 1
	load_page_next_button.disabled = load_page >= SLOT_SAVE_PAGE_COUNT

	var page_start: int = (load_page - 1) * SLOT_SAVE_PER_PAGE
	for i in range(load_slot_buttons.size()):
		var slot_button: Button = load_slot_buttons[i]
		var slot_index: int = page_start + i + 1
		var snapshot: Dictionary = _get_slot_snapshot(slot_index)
		load_slot_cache[slot_index] = snapshot
		_apply_load_slot_button(slot_button, slot_index, snapshot, load_selected_slot == slot_index)
	var selected_snapshot_v: Variant = load_slot_cache.get(load_selected_slot, {})
	var selected_snapshot: Dictionary = {}
	if selected_snapshot_v is Dictionary:
		selected_snapshot = selected_snapshot_v as Dictionary
	load_enter_button.disabled = load_selected_slot <= 0 or selected_snapshot.is_empty()


func _apply_load_slot_button(slot_button: Button, slot_index: int, snapshot: Dictionary, selected: bool) -> void:
	if use_template_load_ui:
		_update_template_load_slot(slot_button, slot_index, snapshot, selected)
		return
	var has_data: bool = not snapshot.is_empty()
	var line1: String = "槽位 %02d" % slot_index
	var line2: String = "空"
	var line3: String = ""
	if has_data:
		var day_v: int = int(snapshot.get("living_days", 0))
		var period_v: String = String(snapshot.get("time_period_name", ""))
		var time_v: String = String(snapshot.get("display_time", "--:--"))
		var love_v: int = int(snapshot.get("love_score", 0))
		line2 = "第 %d 天 · %s %s" % [day_v, period_v, time_v]
		line3 = "好感 %d · %s" % [love_v, _format_unix_ts(int(snapshot.get("saved_at_ts", 0)))]
	slot_button.text = "%s\n%s\n%s" % [line1, line2, line3]
	_apply_load_slot_button_style(slot_button, has_data, selected)


func _update_template_load_slot(slot_button: Button, slot_index: int, snapshot: Dictionary, selected: bool) -> void:
	var has_data: bool = not snapshot.is_empty()
	var meta_label: Label = slot_button.get_node_or_null("横向内容/信息边距/信息列/上行标签") as Label
	var title_label: Label = slot_button.get_node_or_null("横向内容/信息边距/信息列/下行标签") as Label
	_apply_label_font(meta_label, 18, "ui")
	_apply_label_font(title_label, 24, "dialogue")
	if meta_label != null:
		if has_data:
			var day_v: int = int(snapshot.get("living_days", 0))
			var period_v: String = String(snapshot.get("time_period_name", ""))
			var time_v: String = String(snapshot.get("display_time", "--:--"))
			meta_label.text = "第 %d 天  %s %s" % [day_v, period_v, time_v]
		else:
			meta_label.text = "槽位 %02d  空" % slot_index
	if title_label != null:
		if has_data:
			var love_v: int = int(snapshot.get("love_score", 0))
			var saved_at: String = _format_unix_ts(int(snapshot.get("saved_at_ts", 0)))
			title_label.text = "好感 %d  |  %s" % [love_v, saved_at]
		else:
			title_label.text = "未保存"
	slot_button.text = ""
	_apply_load_slot_button_style(slot_button, has_data, selected)


func _apply_load_slot_button_style(slot_button: Button, has_data: bool, selected: bool) -> void:
	_apply_button_font(slot_button, 20, "ui")
	if use_template_load_ui:
		slot_button.flat = false
		slot_button.disabled = false
		slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has_data else Control.CURSOR_ARROW
		slot_button.modulate = Color(1.0, 0.92, 0.9, 1.0) if selected else Color(1.0, 1.0, 1.0, 1.0)
		return
	var normal_bg: Color = Color(0.08, 0.08, 0.08, 0.95) if has_data else Color(0.05, 0.05, 0.05, 0.75)
	var normal_border: Color = Color(0.34, 0.34, 0.34, 1.0) if has_data else Color(0.18, 0.18, 0.18, 0.9)
	if selected:
		normal_bg = Color(0.16, 0.11, 0.11, 0.98)
		normal_border = Color(0.86, 0.44, 0.44, 1.0)
	var normal: StyleBoxFlat = _make_flat_style(normal_bg, normal_border, 1, 4, 12, 10, 12, 10)
	var hover: StyleBoxFlat = _make_flat_style(
		Color(normal_bg.r + 0.04, normal_bg.g + 0.04, normal_bg.b + 0.04, normal_bg.a),
		Color(0.60, 0.60, 0.60, 1.0),
		1,
		4,
		12,
		10,
		12,
		10
	)
	slot_button.flat = false
	slot_button.disabled = false
	slot_button.add_theme_stylebox_override("normal", normal)
	slot_button.add_theme_stylebox_override("hover", hover)
	slot_button.add_theme_stylebox_override("pressed", hover)
	slot_button.add_theme_stylebox_override("focus", hover)
	slot_button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0) if has_data else Color(0.58, 0.58, 0.58, 1.0))
	slot_button.add_theme_color_override("font_hover_color", Color(1, 0.96, 0.96, 1))
	slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has_data else Control.CURSOR_ARROW


func _launch_game_with_menu_page(page: String, force_new_game: bool = false) -> void:
	var context: Node = get_node_or_null("/root/VictoriaLaunchContext")
	if context != null:
		if context.has_method("set_startup_menu_page"):
			context.call("set_startup_menu_page", page)
		if context.has_method("set_startup_load_slot_index"):
			context.call("set_startup_load_slot_index", 0)
		if context.has_method("set_startup_force_new_game"):
			context.call("set_startup_force_new_game", force_new_game)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _launch_game_with_load_slot(slot_index: int) -> void:
	var context: Node = get_node_or_null("/root/VictoriaLaunchContext")
	if context != null:
		if context.has_method("set_startup_menu_page"):
			context.call("set_startup_menu_page", "")
		if context.has_method("set_startup_load_slot_index"):
			context.call("set_startup_load_slot_index", slot_index)
		if context.has_method("set_startup_force_new_game"):
			context.call("set_startup_force_new_game", false)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _close_settings_overlay() -> void:
	settings_overlay.visible = false


func _close_overlays() -> void:
	_close_settings_overlay()
	_close_info_overlay()
	_close_load_overlay()
	_close_api_key_dialog()


func _is_any_overlay_open() -> bool:
	return settings_overlay.visible or info_overlay.visible or load_overlay.visible or (api_key_dialog != null and api_key_dialog.visible)


func _bind_template_load_ui_if_present() -> void:
	if not ENABLE_TEMPLATE_LOAD_UI:
		use_template_load_ui = false
		return
	if template_load_root == null:
		return
	var page_prev_v: Variant = load_overlay.get_node_or_null("模板读取界面/读取界面根/居中盒/外边距/读取盒/读取页码行/读取上一页按钮")
	var page_label_v: Variant = load_overlay.get_node_or_null("模板读取界面/读取界面根/居中盒/外边距/读取盒/读取页码行/读取页码标签")
	var page_next_v: Variant = load_overlay.get_node_or_null("模板读取界面/读取界面根/居中盒/外边距/读取盒/读取页码行/读取下一页按钮")
	var info_label_v: Variant = load_overlay.get_node_or_null("模板读取界面/读取界面根/居中盒/外边距/读取盒/读取说明标签")
	var enter_btn_v: Variant = load_overlay.get_node_or_null("模板读取界面/读取界面根/居中盒/外边距/读取盒/读取操作行/载入按钮")
	var close_btn_v: Variant = load_overlay.get_node_or_null("模板读取界面/读取界面根/居中盒/外边距/读取盒/读取操作行/读取返回按钮")
	var slot_paths: PackedStringArray = [
		"模板读取界面/读取界面根/居中盒/外边距/读取盒/存档滚动区/滚动边距/槽位列表/槽位1条目/条目按钮",
		"模板读取界面/读取界面根/居中盒/外边距/读取盒/存档滚动区/滚动边距/槽位列表/槽位2条目/条目按钮",
		"模板读取界面/读取界面根/居中盒/外边距/读取盒/存档滚动区/滚动边距/槽位列表/槽位3条目/条目按钮",
		"模板读取界面/读取界面根/居中盒/外边距/读取盒/存档滚动区/滚动边距/槽位列表/槽位4条目/条目按钮",
		"模板读取界面/读取界面根/居中盒/外边距/读取盒/存档滚动区/滚动边距/槽位列表/槽位5条目/条目按钮",
		"模板读取界面/读取界面根/居中盒/外边距/读取盒/存档滚动区/滚动边距/槽位列表/槽位6条目/条目按钮"
	]
	var template_slots: Array[Button] = []
	for path in slot_paths:
		var node_v: Variant = load_overlay.get_node_or_null(path)
		if node_v is Button:
			template_slots.append(node_v as Button)
	if not (page_prev_v is Button and page_label_v is Label and page_next_v is Button and info_label_v is Label and enter_btn_v is Button and close_btn_v is Button):
		return
	if template_slots.size() != SLOT_SAVE_PER_PAGE:
		return
	load_page_prev_button = page_prev_v as Button
	load_page_label = page_label_v as Label
	load_page_next_button = page_next_v as Button
	load_info_label = info_label_v as Label
	load_enter_button = enter_btn_v as Button
	load_close_button = close_btn_v as Button
	load_slot_buttons = template_slots
	use_template_load_ui = true


func _configure_load_overlay_mode() -> void:
	if template_load_ui != null:
		template_load_ui.visible = ENABLE_TEMPLATE_LOAD_UI
		template_load_ui.mouse_filter = (
			Control.MOUSE_FILTER_STOP if ENABLE_TEMPLATE_LOAD_UI else Control.MOUSE_FILTER_IGNORE
		)
	if legacy_load_panel_bg != null:
		legacy_load_panel_bg.visible = not ENABLE_TEMPLATE_LOAD_UI
	if legacy_load_root != null:
		legacy_load_root.visible = not ENABLE_TEMPLATE_LOAD_UI


func _move_overlays_to_canvas_layer() -> void:
	if overlay_layer == null:
		return
	var overlays: Array[Control] = [settings_overlay, info_overlay, load_overlay]
	for overlay in overlays:
		if overlay == null or overlay.get_parent() == overlay_layer:
			continue
		var is_visible: bool = overlay.visible
		overlay.reparent(overlay_layer, false)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.offset_left = 0.0
		overlay.offset_top = 0.0
		overlay.offset_right = 0.0
		overlay.offset_bottom = 0.0
		overlay.visible = is_visible


func _load_menu_fonts() -> void:
	var ui_font_v: Variant = load(FONT_UI_PATH)
	if ui_font_v is FontFile:
		menu_font_ui = ui_font_v as FontFile
	var dialogue_font_v: Variant = load(FONT_DIALOGUE_PATH)
	if dialogue_font_v is FontFile:
		menu_font_dialogue = dialogue_font_v as FontFile
	var title_font_v: Variant = load(FONT_TITLE_PATH)
	if title_font_v is FontFile:
		menu_font_title = title_font_v as FontFile
	if menu_font_dialogue == null:
		menu_font_dialogue = menu_font_ui
	if menu_font_title == null:
		menu_font_title = menu_font_ui


func _apply_button_font(button: Button, size: int, role: String = "ui") -> void:
	if button == null:
		return
	var target_font: FontFile = menu_font_ui
	match role:
		"dialogue":
			if menu_font_dialogue != null:
				target_font = menu_font_dialogue
		"title":
			if menu_font_title != null:
				target_font = menu_font_title
	if target_font != null:
		button.add_theme_font_override("font", target_font)
	button.add_theme_font_size_override("font_size", size)


func _apply_label_font(label: Label, size: int, role: String = "ui") -> void:
	if label == null:
		return
	var target_font: FontFile = menu_font_ui
	match role:
		"dialogue":
			if menu_font_dialogue != null:
				target_font = menu_font_dialogue
		"title":
			if menu_font_title != null:
				target_font = menu_font_title
	if target_font != null:
		label.add_theme_font_override("font", target_font)
	label.add_theme_font_size_override("font_size", size)


func _apply_richtext_font(text_node: RichTextLabel, size: int, role: String = "dialogue") -> void:
	if text_node == null:
		return
	var target_font: FontFile = menu_font_dialogue
	if role == "title" and menu_font_title != null:
		target_font = menu_font_title
	elif role == "ui" and menu_font_ui != null:
		target_font = menu_font_ui
	if target_font != null:
		text_node.add_theme_font_override("normal_font", target_font)
	text_node.add_theme_font_size_override("normal_font_size", size)


func _setup_ui_sfx() -> void:
	ui_sfx_player = AudioStreamPlayer.new()
	add_child(ui_sfx_player)
	if ResourceLoader.exists(UI_HOVER_SOUND_PATH):
		ui_hover_stream = load(UI_HOVER_SOUND_PATH)
	if ResourceLoader.exists(UI_CLICK_SOUND_PATH):
		ui_click_stream = load(UI_CLICK_SOUND_PATH)
	_apply_ui_sfx_volume()


func _apply_ui_sfx_volume() -> void:
	if ui_sfx_player == null:
		return
	var sfx_percent: float = clampf(float(sfx_slider.value), 0.0, 100.0)
	ui_sfx_player.volume_db = lerpf(-40.0, 0.0, sfx_percent / 100.0) - 2.0


func _play_ui_hover_sfx() -> void:
	if ui_sfx_player == null or ui_hover_stream == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - ui_last_hover_tick_msec < UI_HOVER_DEBOUNCE_MS:
		return
	ui_last_hover_tick_msec = now_ms
	_apply_ui_sfx_volume()
	ui_sfx_player.volume_db += UI_HOVER_GAIN_OFFSET_DB
	ui_sfx_player.pitch_scale = 0.90
	ui_sfx_player.stream = ui_hover_stream
	ui_sfx_player.play()


func _play_ui_click_sfx() -> void:
	if ui_sfx_player == null or ui_click_stream == null:
		return
	_apply_ui_sfx_volume()
	ui_sfx_player.volume_db += UI_CLICK_GAIN_OFFSET_DB
	ui_sfx_player.pitch_scale = 1.0
	ui_sfx_player.stream = ui_click_stream
	ui_sfx_player.play()


func _bind_button_sfx(button: Button) -> void:
	if button == null:
		return
	var hover_callable: Callable = Callable(self, "_on_any_button_hovered")
	if not button.mouse_entered.is_connected(hover_callable):
		button.mouse_entered.connect(hover_callable)
	var click_callable: Callable = Callable(self, "_on_any_button_pressed")
	if not button.pressed.is_connected(click_callable):
		button.pressed.connect(click_callable)


func _on_any_button_hovered() -> void:
	_play_ui_hover_sfx()


func _on_any_button_pressed() -> void:
	_play_ui_click_sfx()


func _connect_button_pressed(button: Button, callback: Callable) -> void:
	if button == null:
		return
	_bind_button_sfx(button)
	if button.pressed.is_connected(callback):
		return
	button.pressed.connect(callback)


func _configure_template_menu_button(button: Button) -> void:
	if button == null:
		return
	var base_text: String = button.text
	if base_text.begins_with(MENU_HOVER_PREFIX):
		base_text = base_text.trim_prefix(MENU_HOVER_PREFIX)
	button.set_meta("menu_base_text", base_text)
	button.text = base_text
	button.icon = null
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, 320.0), maxf(button.custom_minimum_size.y, 76.0))
	_apply_button_font(button, 38, "title")
	button.add_theme_constant_override("h_separation", 16)


func _setup_template_menu_click_proxies() -> void:
	if template_menu_click_layer == null:
		return
	template_menu_click_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	var clear_style: StyleBoxEmpty = StyleBoxEmpty.new()
	var pairs: Array[Array] = [
		[load_button, template_continue_button],
		[start_button, template_new_game_button],
		[settings_button, template_options_button],
		[about_button, template_credits_button],
		[help_button, template_help_button],
		[quit_button, template_quit_button]
	]
	for pair_v in pairs:
		var pair: Array = pair_v
		if pair.size() < 2:
			continue
		var proxy_v: Variant = pair[0]
		var visual_v: Variant = pair[1]
		if not (proxy_v is Button) or not (visual_v is Button):
			continue
		var proxy: Button = proxy_v as Button
		var visual: Button = visual_v as Button
		if proxy.get_parent() != template_menu_click_layer:
			proxy.reparent(template_menu_click_layer, false)
		proxy.visible = true
		proxy.text = ""
		proxy.icon = null
		proxy.flat = true
		proxy.focus_mode = Control.FOCUS_NONE
		proxy.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		proxy.mouse_filter = Control.MOUSE_FILTER_STOP
		proxy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		proxy.set_anchors_preset(Control.PRESET_TOP_LEFT)
		proxy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		proxy.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_apply_clear_button_style(proxy, clear_style)
		if not proxy.mouse_entered.is_connected(Callable(self, "_on_template_menu_button_mouse_entered").bind(visual)):
			proxy.mouse_entered.connect(Callable(self, "_on_template_menu_button_mouse_entered").bind(visual))
		if not proxy.mouse_exited.is_connected(Callable(self, "_on_template_menu_button_mouse_exited").bind(visual)):
			proxy.mouse_exited.connect(Callable(self, "_on_template_menu_button_mouse_exited").bind(visual))
		if not proxy.focus_entered.is_connected(Callable(self, "_on_template_menu_button_focus_entered").bind(visual)):
			proxy.focus_entered.connect(Callable(self, "_on_template_menu_button_focus_entered").bind(visual))
		if not proxy.focus_exited.is_connected(Callable(self, "_on_template_menu_button_focus_exited").bind(visual)):
			proxy.focus_exited.connect(Callable(self, "_on_template_menu_button_focus_exited").bind(visual))
	_request_template_menu_proxy_sync()


func _sync_template_menu_click_proxies() -> void:
	if template_menu_click_layer == null:
		return
	var pairs: Array[Array] = [
		[load_button, template_continue_button],
		[start_button, template_new_game_button],
		[settings_button, template_options_button],
		[about_button, template_credits_button],
		[help_button, template_help_button],
		[quit_button, template_quit_button]
	]
	for pair_v in pairs:
		var pair: Array = pair_v
		if pair.size() < 2:
			continue
		var proxy_v: Variant = pair[0]
		var visual_v: Variant = pair[1]
		if not (proxy_v is Button) or not (visual_v is Button):
			continue
		var proxy: Button = proxy_v as Button
		var visual: Button = visual_v as Button
		var rect: Rect2 = visual.get_global_rect()
		proxy.position = rect.position
		proxy.size = rect.size
		proxy.visible = visual.is_visible_in_tree()


func _on_root_resized() -> void:
	_request_template_menu_proxy_sync()


func _request_template_menu_proxy_sync() -> void:
	call_deferred("_sync_template_menu_click_proxies")
	_sync_template_menu_click_proxies_after_frame()


func _sync_template_menu_click_proxies_after_frame() -> void:
	await get_tree().process_frame
	_sync_template_menu_click_proxies()


func _on_template_menu_button_mouse_entered(button: Button) -> void:
	_set_template_menu_button_hover(button, true)


func _on_template_menu_button_mouse_exited(button: Button) -> void:
	_set_template_menu_button_hover(button, false)


func _on_template_menu_button_focus_entered(button: Button) -> void:
	_set_template_menu_button_hover(button, true)


func _on_template_menu_button_focus_exited(button: Button) -> void:
	_set_template_menu_button_hover(button, false)


func _set_template_menu_button_hover(button: Button, hovered: bool) -> void:
	if button == null:
		return
	var base_text: String = String(button.get_meta("menu_base_text", button.text))
	button.text = "%s%s" % [MENU_HOVER_PREFIX, base_text] if hovered else base_text


func _activate_template_menu_action(action: String) -> void:
	match action:
		"load":
			_on_load_pressed()
		"start":
			_on_start_pressed()
		"settings":
			_on_settings_pressed()
		"about":
			_on_about_pressed()
		"help":
			_on_help_pressed()
		"quit":
			_on_quit_pressed()


func _template_menu_action_at(position: Vector2) -> String:
	var pairs: Array[Array] = [
		["load", template_continue_button],
		["start", template_new_game_button],
		["settings", template_options_button],
		["about", template_credits_button],
		["help", template_help_button],
		["quit", template_quit_button]
	]
	for pair_v in pairs:
		var pair: Array = pair_v
		if pair.size() < 2 or not (pair[1] is Button):
			continue
		var button: Button = pair[1] as Button
		if button.is_visible_in_tree() and button.get_global_rect().has_point(position):
			return String(pair[0])
	return ""


func _update_template_menu_hover_at(position: Vector2) -> void:
	var hover_button: Button = null
	var buttons: Array[Button] = [
		template_continue_button,
		template_new_game_button,
		template_options_button,
		template_credits_button,
		template_help_button,
		template_quit_button
	]
	for button in buttons:
		if button == null:
			continue
		if button.is_visible_in_tree() and button.get_global_rect().has_point(position):
			hover_button = button
			break
	if hover_button == template_menu_hover_button:
		return
	if template_menu_hover_button != null:
		_set_template_menu_button_hover(template_menu_hover_button, false)
	template_menu_hover_button = hover_button
	if template_menu_hover_button != null:
		_set_template_menu_button_hover(template_menu_hover_button, true)


func _clear_template_menu_hover() -> void:
	if template_menu_hover_button == null:
		return
	_set_template_menu_button_hover(template_menu_hover_button, false)
	template_menu_hover_button = null


func _slot_id_from_index(slot_index: int) -> String:
	return "slot_%03d" % slot_index


func _slot_path_from_index(slot_index: int) -> String:
	if slot_index < 1 or slot_index > SLOT_SAVE_MAX:
		return ""
	return "%s/%s.json" % [SLOT_SAVE_DIR, _slot_id_from_index(slot_index)]


func _load_save_data_from_path(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parse: Variant = JSON.parse_string(text)
	if not (parse is Dictionary):
		return {}
	return parse as Dictionary


func _get_slot_snapshot(slot_index: int) -> Dictionary:
	var slot_path: String = _slot_path_from_index(slot_index)
	if slot_path.is_empty():
		return {}
	var data: Dictionary = _load_save_data_from_path(slot_path)
	if data.is_empty():
		return {}
	var state_data_v: Variant = data.get("state", {})
	if not (state_data_v is Dictionary):
		return {}
	var state_data: Dictionary = state_data_v as Dictionary
	return {
		"slot_index": slot_index,
		"slot_id": _slot_id_from_index(slot_index),
		"saved_at_ts": int(data.get("saved_at_ts", 0)),
		"living_days": int(state_data.get("living_days", 0)),
		"display_time": String(state_data.get("display_time", "--:--")),
		"time_period_name": String(state_data.get("time_period_name", "")),
		"love_score": int(state_data.get("love_score", 0)),
		"thumbnail_rel_path": String(data.get("thumbnail_rel_path", "")).strip_edges()
	}


func _format_unix_ts(ts: int) -> String:
	if ts <= 0:
		return "--"
	return String(Time.get_datetime_string_from_unix_time(ts, true))


func _make_flat_style(
	bg: Color,
	border: Color,
	border_w: int,
	radius: int,
	margin_left: float,
	margin_top: float,
	margin_right: float,
	margin_bottom: float
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin_left
	style.content_margin_top = margin_top
	style.content_margin_right = margin_right
	style.content_margin_bottom = margin_bottom
	return style


func _apply_clear_button_style(button: Button, clear_style: StyleBoxEmpty) -> void:
	if button == null:
		return
	button.flat = true
	button.add_theme_stylebox_override("normal", clear_style)
	button.add_theme_stylebox_override("hover", clear_style)
	button.add_theme_stylebox_override("pressed", clear_style)
	button.add_theme_stylebox_override("focus", clear_style)
	button.add_theme_stylebox_override("disabled", clear_style)


func _apply_secondary_button_style(button: Button) -> void:
	if button == null:
		return
	var normal: StyleBoxFlat = _make_flat_style(
		Color(0.06, 0.06, 0.06, 0.95), Color(0.34, 0.34, 0.34, 1.0), 1, 4, 10, 6, 10, 6
	)
	var hover: StyleBoxFlat = _make_flat_style(
		Color(0.11, 0.11, 0.11, 0.98), Color(0.52, 0.52, 0.52, 1.0), 1, 4, 10, 6, 10, 6
	)
	var pressed: StyleBoxFlat = _make_flat_style(
		Color(0.16, 0.16, 0.16, 1.0), Color(0.62, 0.62, 0.62, 1.0), 1, 4, 10, 6, 10, 6
	)
	var focus: StyleBoxFlat = _make_flat_style(
		Color(0.11, 0.11, 0.11, 0.98), Color(0.76, 0.76, 0.76, 1.0), 1, 4, 10, 6, 10, 6
	)
	var disabled: StyleBoxFlat = _make_flat_style(
		Color(0.04, 0.04, 0.04, 0.75), Color(0.20, 0.20, 0.20, 0.8), 1, 4, 10, 6, 10, 6
	)
	button.flat = false
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)
	_apply_button_font(button, 24, "ui")
