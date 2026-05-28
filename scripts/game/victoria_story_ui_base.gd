extends "res://scripts/game/victoria_scene_audio.gd"

var ui_canvas: CanvasLayer
var ui_root: Control
var playfield_masks: Array[ColorRect] = []
var stage_border_lines: Array[ColorRect] = []
var dialogue_border_lines: Array[ColorRect] = []
var stage_frame_panel: PanelContainer
var dialogue_frame_panel: PanelContainer
var stage_corner_mask: ColorRect
var dialogue_corner_mask: ColorRect
var quick_menu_box: HBoxContainer
var ui_font: FontFile
var dialogue_font: FontFile
var title_font: FontFile
var ui_theme_v2: Theme
var room_button_idle: Texture2D
var room_button_hover: Texture2D
var love_track_holder: Control
var hud_panel_ref: PanelContainer
var love_panel_ref: PanelContainer
var dialogue_panel_ref: PanelContainer
var menu_overlay_mask: ColorRect
var game_menu_panel: PanelContainer
var game_menu_title: Label
var game_menu_nav_box: VBoxContainer
var game_menu_nav_buttons: Dictionary = {}
var game_menu_pages: Dictionary = {}
var game_menu_current_page: String = ""
var history_text: RichTextLabel
var bgm_slider: HSlider
var sfx_slider: HSlider
var settings_display_button: Button
var settings_skip_button: Button
var settings_auto_button: Button
var settings_return_main_menu_button: Button
var main_menu_confirm_overlay: ColorRect
var main_menu_confirm_panel: PanelContainer
var main_menu_confirm_title: Label
var main_menu_confirm_hint: Label
var main_menu_confirm_save_button: Button
var main_menu_confirm_no_save_button: Button
var main_menu_confirm_cancel_button: Button
var save_info_label: Label
var load_info_label: Label
var save_page_label: Label
var load_page_label: Label
var save_grid_ref: GridContainer
var load_grid_ref: GridContainer
var save_page_buttons_ref: GridContainer
var load_page_buttons_ref: GridContainer
var save_slot_buttons: Array[Button] = []
var load_slot_buttons: Array[Button] = []
var save_page_index: int = 1
var load_page_index: int = 1
var save_selected_slot: int = 1
var load_selected_slot: int = 1
var quick_menu_buttons: Dictionary = {}
var cached_layout: Dictionary = {}
var ui_scale: float = 1.0
var runtime_theme_ready: bool = false
var use_scene_tree_layout: bool = true
var modal_fade_tween: Tween
var hover_tweens: Dictionary = {}

const VAR_COMPACT_BUTTON := "VictoriaCompactButton"
const VAR_MENU_NAV_BUTTON := "VictoriaMenuNavButton"
const VAR_QUICK_BUTTON := "VictoriaQuickButton"
const VAR_WEB_BUTTON := "VictoriaWebButton"
const VAR_END_TURN_BUTTON := "VictoriaEndTurnButton"
const VAR_ROOM_BUTTON := "VictoriaRoomButton"
const VAR_INPUT_PANEL := "VictoriaInputPanel"
const VAR_INPUT_LINE := "VictoriaInputLine"
const VAR_CHOICE_BUTTON := "VictoriaChoiceButton"
const VAR_SLOT_EMPTY := "VictoriaSlotEmpty"
const VAR_SLOT_USED := "VictoriaSlotUsed"
const VAR_SLOT_EMPTY_SELECTED := "VictoriaSlotEmptySelected"
const VAR_SLOT_USED_SELECTED := "VictoriaSlotUsedSelected"
const OUTER_FRAME_BORDER_WIDTH := 2
const OUTER_FRAME_RADIUS := 14
const CORNER_MASK_SHADER_CODE := """
shader_type canvas_item;
uniform vec2 panel_size = vec2(100.0, 100.0);
uniform float radius_px : hint_range(0.0, 64.0) = 14.0;
uniform vec4 mask_color : source_color = vec4(0.015, 0.015, 0.015, 1.0);

void fragment() {
	vec2 p = UV * panel_size;
	float r = min(radius_px, min(panel_size.x, panel_size.y) * 0.5);
	bool outside = false;

	if (p.x < r && p.y < r) {
		outside = distance(p, vec2(r, r)) > r;
	} else if (p.x > panel_size.x - r && p.y < r) {
		outside = distance(p, vec2(panel_size.x - r, r)) > r;
	} else if (p.x < r && p.y > panel_size.y - r) {
		outside = distance(p, vec2(r, panel_size.y - r)) > r;
	} else if (p.x > panel_size.x - r && p.y > panel_size.y - r) {
		outside = distance(p, vec2(panel_size.x - r, panel_size.y - r)) > r;
	}

	COLOR = outside ? mask_color : vec4(0.0, 0.0, 0.0, 0.0);
}
"""


func _save_runtime_state() -> void:
	# Implemented in victoria_ai_flow.gd.
	pass
func _load_ui_resources() -> void:
	var font_v: Variant = load("res://assets/fonts/SourceHanSansLite.ttf")
	if font_v is FontFile:
		ui_font = font_v as FontFile
	var dialogue_font_v: Variant = load("res://assets/fonts/LXGWWenKai-Regular.ttf")
	if dialogue_font_v is FontFile:
		dialogue_font = dialogue_font_v as FontFile
	var title_font_v: Variant = load("res://assets/fonts/SmileySans-Oblique.ttf")
	if title_font_v is FontFile:
		title_font = title_font_v as FontFile
	if dialogue_font == null:
		dialogue_font = ui_font
	if title_font == null:
		title_font = ui_font
	var theme_v: Variant = load("res://ui_base_theme_v2/ui_base_theme.tres")
	if theme_v is Theme:
		ui_theme_v2 = theme_v as Theme
	var idle_v: Variant = load("res://assets/gui/button/living_room_btn_idle.png")
	if idle_v is Texture2D:
		room_button_idle = idle_v as Texture2D
	var hover_v: Variant = load("res://assets/gui/button/living_room_btn_hover.png")
	if hover_v is Texture2D:
		room_button_hover = hover_v as Texture2D
	# User requested not to use image assets from ui_base_theme_v2.
	_apply_runtime_theme_variations()


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


func _apply_runtime_theme_variations() -> void:
	if runtime_theme_ready:
		return
	if ui_theme_v2 == null:
		ui_theme_v2 = Theme.new()
	else:
		ui_theme_v2 = ui_theme_v2.duplicate(true)

	var compact_normal: StyleBoxFlat = _make_flat_style(
		Color(0.10, 0.10, 0.10, 0.92), Color(0.62, 0.62, 0.62, 0.75), 1, 8, 10, 8, 10, 8
	)
	var compact_hover: StyleBoxFlat = _make_flat_style(
		Color(0.16, 0.16, 0.16, 0.95), Color(0.95, 0.95, 0.95, 0.92), 1, 8, 10, 8, 10, 8
	)
	for name in ["normal", "hover", "focus", "pressed", "disabled"]:
		var compact_style: StyleBoxFlat = compact_normal
		if name != "normal":
			compact_style = compact_hover
		ui_theme_v2.set_stylebox(name, VAR_COMPACT_BUTTON, compact_style)
	ui_theme_v2.set_color("font_color", VAR_COMPACT_BUTTON, Color(0.86, 0.86, 0.86))
	ui_theme_v2.set_color("font_hover_color", VAR_COMPACT_BUTTON, Color(1.0, 1.0, 1.0))
	ui_theme_v2.set_color("font_pressed_color", VAR_COMPACT_BUTTON, Color(1.0, 1.0, 1.0))

	var nav_normal: StyleBoxFlat = _make_flat_style(
		Color(1.0, 1.0, 1.0, 0.02), Color(1.0, 1.0, 1.0, 0.0), 0, 6, 12, 8, 12, 8
	)
	var nav_hover: StyleBoxFlat = _make_flat_style(
		Color(1.0, 1.0, 1.0, 0.08), Color(0.92, 0.92, 0.92, 0.6), 1, 6, 12, 8, 12, 8
	)
	ui_theme_v2.set_stylebox("normal", VAR_MENU_NAV_BUTTON, nav_normal)
	ui_theme_v2.set_stylebox("disabled", VAR_MENU_NAV_BUTTON, nav_normal)
	for name2 in ["hover", "focus", "pressed"]:
		ui_theme_v2.set_stylebox(name2, VAR_MENU_NAV_BUTTON, nav_hover)
	ui_theme_v2.set_color("font_color", VAR_MENU_NAV_BUTTON, Color(0.72, 0.72, 0.72))
	ui_theme_v2.set_color("font_hover_color", VAR_MENU_NAV_BUTTON, Color(0.96, 0.96, 0.96))
	ui_theme_v2.set_color("font_pressed_color", VAR_MENU_NAV_BUTTON, Color(0.96, 0.96, 0.96))

	var quick_normal: StyleBoxFlat = _make_flat_style(
		Color(0.01, 0.01, 0.01, 0.56), Color(1.0, 1.0, 1.0, 0.08), 1, 12, 12, 5, 12, 5
	)
	var quick_hover: StyleBoxFlat = _make_flat_style(
		Color(0.05, 0.05, 0.05, 0.78), Color(1.0, 1.0, 1.0, 0.26), 1, 12, 12, 5, 12, 5
	)
	ui_theme_v2.set_stylebox("normal", VAR_QUICK_BUTTON, quick_normal)
	ui_theme_v2.set_stylebox("disabled", VAR_QUICK_BUTTON, quick_normal)
	for name3 in ["hover", "focus", "pressed"]:
		ui_theme_v2.set_stylebox(name3, VAR_QUICK_BUTTON, quick_hover)
	ui_theme_v2.set_color("font_color", VAR_QUICK_BUTTON, Color(0.70, 0.70, 0.70))
	ui_theme_v2.set_color("font_hover_color", VAR_QUICK_BUTTON, Color(0.96, 0.96, 0.96))
	ui_theme_v2.set_color("font_pressed_color", VAR_QUICK_BUTTON, Color(0.96, 0.96, 0.96))

	var web_style: StyleBoxFlat = _make_flat_style(
		Color(0.0, 0.0, 0.0, 0.60), Color(0, 0, 0, 0), 0, 6, 12, 6, 12, 6
	)
	for name4 in ["normal", "hover", "focus", "pressed", "disabled"]:
		ui_theme_v2.set_stylebox(name4, VAR_WEB_BUTTON, web_style)
	ui_theme_v2.set_color("font_color", VAR_WEB_BUTTON, Color(1.0, 1.0, 1.0))
	ui_theme_v2.set_color("font_hover_color", VAR_WEB_BUTTON, Color(1.0, 0.88, 0.88))
	ui_theme_v2.set_color("font_pressed_color", VAR_WEB_BUTTON, Color(1.0, 0.88, 0.88))

	var end_normal: StyleBoxFlat = _make_flat_style(
		Color(0.0, 0.0, 0.0, 0.56), Color(0.96, 0.96, 0.96, 0.95), 2, 4, 10, 5, 10, 5
	)
	var end_hover: StyleBoxFlat = _make_flat_style(
		Color(0.06, 0.06, 0.06, 0.72), Color(0.98, 0.98, 0.98, 1.0), 2, 4, 10, 5, 10, 5
	)
	for name5 in ["normal", "disabled"]:
		ui_theme_v2.set_stylebox(name5, VAR_END_TURN_BUTTON, end_normal)
	for name5h in ["hover", "focus", "pressed"]:
		ui_theme_v2.set_stylebox(name5h, VAR_END_TURN_BUTTON, end_hover)
	ui_theme_v2.set_color("font_color", VAR_END_TURN_BUTTON, Color(1.0, 1.0, 1.0))
	ui_theme_v2.set_color("font_hover_color", VAR_END_TURN_BUTTON, Color(1.0, 0.4, 0.4))
	ui_theme_v2.set_color("font_pressed_color", VAR_END_TURN_BUTTON, Color(1.0, 0.4, 0.4))

	var input_panel_style: StyleBoxFlat = _make_flat_style(
		Color(0.04, 0.04, 0.04, 0.96), Color(0.92, 0.92, 0.92, 0.25), 1, 3, 0, 0, 0, 0
	)
	ui_theme_v2.set_stylebox("panel", VAR_INPUT_PANEL, input_panel_style)
	var input_line_style: StyleBoxFlat = _make_flat_style(
		Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0, 0, 0
	)
	ui_theme_v2.set_stylebox("normal", VAR_INPUT_LINE, input_line_style)
	ui_theme_v2.set_stylebox("focus", VAR_INPUT_LINE, input_line_style)
	ui_theme_v2.set_stylebox("read_only", VAR_INPUT_LINE, input_line_style)
	ui_theme_v2.set_color("font_color", VAR_INPUT_LINE, Color(0.95, 0.95, 0.95))
	ui_theme_v2.set_color("font_placeholder_color", VAR_INPUT_LINE, Color(0.58, 0.58, 0.58))

	var room_normal: StyleBox = null
	var room_hover: StyleBox = null
	if room_button_idle != null and room_button_hover != null:
		var room_normal_tex: StyleBoxTexture = StyleBoxTexture.new()
		room_normal_tex.texture = room_button_idle
		var room_hover_tex: StyleBoxTexture = StyleBoxTexture.new()
		room_hover_tex.texture = room_button_hover
		room_normal = room_normal_tex
		room_hover = room_hover_tex
	else:
		room_normal = _make_flat_style(Color(0.88, 0.88, 0.88, 0.95), Color(0, 0, 0, 0), 0, 18, 10, 6, 10, 6)
		room_hover = _make_flat_style(Color(0.95, 0.95, 0.95, 1.0), Color(0, 0, 0, 0), 0, 18, 10, 6, 10, 6)
	ui_theme_v2.set_stylebox("normal", VAR_ROOM_BUTTON, room_normal)
	ui_theme_v2.set_stylebox("pressed", VAR_ROOM_BUTTON, room_normal)
	ui_theme_v2.set_stylebox("disabled", VAR_ROOM_BUTTON, room_normal)
	ui_theme_v2.set_stylebox("hover", VAR_ROOM_BUTTON, room_hover)
	ui_theme_v2.set_stylebox("focus", VAR_ROOM_BUTTON, room_hover)
	ui_theme_v2.set_color("font_color", VAR_ROOM_BUTTON, Color(0.07, 0.07, 0.07))
	ui_theme_v2.set_color("font_hover_color", VAR_ROOM_BUTTON, Color(0.0, 0.0, 0.0))
	ui_theme_v2.set_color("font_pressed_color", VAR_ROOM_BUTTON, Color(0.0, 0.0, 0.0))

	var choice_normal: StyleBoxFlat = _make_flat_style(
		Color(0.02, 0.02, 0.02, 0.94), Color(0.84, 0.84, 0.84, 1.0), 2, 8, 14, 12, 14, 12
	)
	var choice_hover: StyleBoxFlat = _make_flat_style(
		Color(0.07, 0.07, 0.07, 0.95), Color(0.84, 0.84, 0.84, 1.0), 2, 8, 14, 12, 14, 12
	)
	for name6 in ["normal", "disabled"]:
		ui_theme_v2.set_stylebox(name6, VAR_CHOICE_BUTTON, choice_normal)
	for name7 in ["hover", "focus", "pressed"]:
		ui_theme_v2.set_stylebox(name7, VAR_CHOICE_BUTTON, choice_hover)
	ui_theme_v2.set_color("font_color", VAR_CHOICE_BUTTON, Color(0.86, 0.86, 0.86))
	ui_theme_v2.set_color("font_hover_color", VAR_CHOICE_BUTTON, Color(1.0, 1.0, 1.0))
	ui_theme_v2.set_color("font_pressed_color", VAR_CHOICE_BUTTON, Color(1.0, 1.0, 1.0))

	var slot_empty_normal: StyleBoxFlat = _make_flat_style(
		Color(0.03, 0.03, 0.03, 0.93), Color(0.25, 0.25, 0.25, 1.0), 2, 8, 10, 10, 10, 10
	)
	var slot_used_normal: StyleBoxFlat = _make_flat_style(
		Color(0.03, 0.03, 0.03, 0.93), Color(0.52, 0.52, 0.52, 1.0), 2, 8, 10, 10, 10, 10
	)
	var slot_empty_selected: StyleBoxFlat = _make_flat_style(
		Color(0.03, 0.03, 0.03, 0.93), Color(0.95, 0.75, 0.82, 1.0), 2, 8, 10, 10, 10, 10
	)
	var slot_used_selected: StyleBoxFlat = _make_flat_style(
		Color(0.03, 0.03, 0.03, 0.93), Color(0.95, 0.75, 0.82, 1.0), 2, 8, 10, 10, 10, 10
	)
	var slot_empty_hover: StyleBoxFlat = _make_flat_style(
		Color(0.08, 0.08, 0.08, 0.95), Color(0.25, 0.25, 0.25, 1.0), 2, 8, 10, 10, 10, 10
	)
	var slot_used_hover: StyleBoxFlat = _make_flat_style(
		Color(0.08, 0.08, 0.08, 0.95), Color(0.52, 0.52, 0.52, 1.0), 2, 8, 10, 10, 10, 10
	)
	var slot_selected_hover: StyleBoxFlat = _make_flat_style(
		Color(0.08, 0.08, 0.08, 0.95), Color(0.95, 0.75, 0.82, 1.0), 2, 8, 10, 10, 10, 10
	)
	_set_slot_variation_styles(VAR_SLOT_EMPTY, slot_empty_normal, slot_empty_hover)
	_set_slot_variation_styles(VAR_SLOT_USED, slot_used_normal, slot_used_hover)
	_set_slot_variation_styles(VAR_SLOT_EMPTY_SELECTED, slot_empty_selected, slot_selected_hover)
	_set_slot_variation_styles(VAR_SLOT_USED_SELECTED, slot_used_selected, slot_selected_hover)

	runtime_theme_ready = true


func _set_slot_variation_styles(variation: String, normal_style: StyleBoxFlat, hover_style: StyleBoxFlat) -> void:
	ui_theme_v2.set_stylebox("normal", variation, normal_style)
	ui_theme_v2.set_stylebox("disabled", variation, normal_style)
	ui_theme_v2.set_stylebox("hover", variation, hover_style)
	ui_theme_v2.set_stylebox("pressed", variation, hover_style)
	ui_theme_v2.set_stylebox("focus", variation, hover_style)


func _panel_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	if color.a > 0.1:
		style.set_border_width_all(1)
		style.border_color = Color(1.0, 1.0, 1.0, minf(0.30, color.a * 0.35))
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.shadow_color = Color(0.0, 0.0, 0.0, minf(0.42, color.a * 0.65))
		style.shadow_size = 6
		style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _configure_corner_mask(mask: ColorRect, radius_px: float, color: Color) -> void:
	if mask == null:
		return
	mask.visible = true
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.color = Color(1.0, 1.0, 1.0, 1.0)
	var material_v: Variant = mask.material
	var material: ShaderMaterial
	if material_v is ShaderMaterial:
		material = material_v as ShaderMaterial
	else:
		var shader: Shader = Shader.new()
		shader.code = CORNER_MASK_SHADER_CODE
		material = ShaderMaterial.new()
		material.shader = shader
		mask.material = material
	material.set_shader_parameter("radius_px", radius_px)
	material.set_shader_parameter("mask_color", color)
	material.set_shader_parameter("panel_size", Vector2(maxf(1.0, mask.size.x), maxf(1.0, mask.size.y)))


func _apply_corner_mask_rect(mask: ColorRect, rect: Rect2, radius_px: float) -> void:
	if mask == null:
		return
	_set_rect_layout(mask, rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	var material_v: Variant = mask.material
	if material_v is ShaderMaterial:
		var material: ShaderMaterial = material_v as ShaderMaterial
		material.set_shader_parameter("panel_size", Vector2(maxf(1.0, rect.size.x), maxf(1.0, rect.size.y)))
		material.set_shader_parameter("radius_px", radius_px)


func _sync_corner_masks_from_current_layout() -> void:
	if background_rect != null and stage_corner_mask != null:
		_apply_corner_mask_rect(stage_corner_mask, background_rect.get_rect(), float(OUTER_FRAME_RADIUS))
	if dialogue_panel_ref != null and dialogue_corner_mask != null:
		_apply_corner_mask_rect(dialogue_corner_mask, dialogue_panel_ref.get_rect(), float(OUTER_FRAME_RADIUS))


func _current_ui_scale() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var scale_by_w: float = viewport_size.x / 1920.0
	var scale_by_h: float = viewport_size.y / 1080.0
	return clampf(minf(scale_by_w, scale_by_h), 0.60, 1.0)


func _scaled_font_size(base_size: int) -> int:
	return maxi(11, int(round(float(base_size) * ui_scale)))


func _resolve_font_by_role(role: String) -> FontFile:
	match role:
		"dialogue":
			if dialogue_font != null:
				return dialogue_font
		"title":
			if title_font != null:
				return title_font
		_:
			pass
	return ui_font


func _apply_font(control: Control, size: int, role: String = "ui") -> void:
	control.set_meta("_base_font_size", size)
	control.set_meta("_font_role", role)
	var target_font: FontFile = _resolve_font_by_role(role)
	if target_font != null:
		control.add_theme_font_override("font", target_font)
	control.add_theme_font_size_override("font_size", _scaled_font_size(size))


func _bind_hover_feedback(control: Control, hover_color: Color = Color(1.06, 1.06, 1.06, 1.0), duration: float = 0.10) -> void:
	if control == null:
		return
	control.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	var enter_callable: Callable = Callable(self, "_on_hover_feedback_enter").bind(control, hover_color, duration)
	if not control.mouse_entered.is_connected(enter_callable):
		control.mouse_entered.connect(enter_callable)
	var exit_callable: Callable = Callable(self, "_on_hover_feedback_exit").bind(control, duration + 0.03)
	if not control.mouse_exited.is_connected(exit_callable):
		control.mouse_exited.connect(exit_callable)
	if control is BaseButton:
		var btn: BaseButton = control as BaseButton
		var click_callable: Callable = Callable(self, "_on_click_feedback_pressed")
		if not btn.pressed.is_connected(click_callable):
			btn.pressed.connect(click_callable)


func _on_hover_feedback_enter(control: Control, hover_color: Color, duration: float) -> void:
	if has_method("_play_ui_hover_sfx"):
		call("_play_ui_hover_sfx")
	_animate_hover_feedback(control, hover_color, duration)


func _on_hover_feedback_exit(control: Control, duration: float) -> void:
	_animate_hover_feedback(control, Color(1.0, 1.0, 1.0, 1.0), duration)


func _on_click_feedback_pressed() -> void:
	if has_method("_play_ui_click_sfx"):
		call("_play_ui_click_sfx")


func _animate_hover_feedback(control: Control, target_color: Color, duration: float) -> void:
	if control == null or not is_instance_valid(control):
		return
	var key: int = control.get_instance_id()
	if hover_tweens.has(key):
		var old_tween_v: Variant = hover_tweens.get(key, null)
		if old_tween_v is Tween:
			(old_tween_v as Tween).kill()
	var tween: Tween = create_tween()
	hover_tweens[key] = tween
	tween.tween_property(control, "self_modulate", target_color, duration)
	tween.finished.connect(Callable(self, "_clear_hover_tween").bind(key))


func _clear_hover_tween(key: int) -> void:
	hover_tweens.erase(key)


func _refresh_scaled_fonts(root_control: Control) -> void:
	if root_control == null:
		return
	if root_control.has_meta("_base_font_size"):
		var base_size: int = int(root_control.get_meta("_base_font_size", 16))
		root_control.add_theme_font_size_override("font_size", _scaled_font_size(base_size))
	for child_v in root_control.get_children():
		if child_v is Control:
			_refresh_scaled_fonts(child_v as Control)


func _style_room_button(button: Button, font_size: int) -> void:
	if ui_theme_v2 != null:
		button.theme = ui_theme_v2
	button.theme_type_variation = VAR_ROOM_BUTTON
	_apply_font(button, font_size)
	_bind_hover_feedback(button, Color(1.03, 1.03, 1.03, 1.0), 0.10)


func _style_compact_menu_button(button: Button, font_size: int) -> void:
	if ui_theme_v2 != null:
		button.theme = ui_theme_v2
	button.theme_type_variation = VAR_COMPACT_BUTTON
	_apply_font(button, font_size)
	_bind_hover_feedback(button, Color(1.04, 1.04, 1.04, 1.0), 0.10)


func _bind_slot_entry_button(slot_btn: Button, cell_idx: int, is_save: bool) -> bool:
	if ui_theme_v2 != null:
		slot_btn.theme = ui_theme_v2
	slot_btn.theme_type_variation = VAR_SLOT_EMPTY
	slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_btn.custom_minimum_size = Vector2(268.0, 248.0)
	slot_btn.text = ""
	slot_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_btn.focus_mode = Control.FOCUS_NONE
	_bind_hover_feedback(slot_btn, Color(1.05, 1.05, 1.05, 1.0), 0.10)

	var card_box_v: Node = slot_btn.get_node_or_null("卡片盒")
	if not (card_box_v is VBoxContainer):
		push_error("UI node type mismatch: %s/卡片盒" % slot_btn.name)
		return false
	var card_box: VBoxContainer = card_box_v as VBoxContainer
	card_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_box.add_theme_constant_override("separation", 6)

	var thumb_v: Node = card_box.get_node_or_null("缩略图底")
	if not (thumb_v is ColorRect):
		push_error("UI node type mismatch: %s/卡片盒/缩略图底" % slot_btn.name)
		return false
	var thumb: ColorRect = thumb_v as ColorRect
	thumb.custom_minimum_size = Vector2(0.0, 182.0)
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb.color = Color(0.12, 0.12, 0.12, 1.0)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.clip_contents = true

	var thumb_preview_v: Node = thumb.get_node_or_null("缩略图底Preview")
	var thumb_preview: TextureRect
	if thumb_preview_v is TextureRect:
		thumb_preview = thumb_preview_v as TextureRect
	else:
		thumb_preview = TextureRect.new()
		thumb_preview.name = "缩略图底Preview"
		thumb.add_child(thumb_preview)
		thumb.move_child(thumb_preview, 0)
	thumb_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb_preview.offset_left = 0.0
	thumb_preview.offset_top = 0.0
	thumb_preview.offset_right = 0.0
	thumb_preview.offset_bottom = 0.0
	thumb_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb_preview.texture = null

	var thumb_label_v: Node = thumb.get_node_or_null("缩略图标签")
	if not (thumb_label_v is Label):
		push_error("UI node type mismatch: %s/卡片盒/缩略图底/缩略图标签" % slot_btn.name)
		return false
	var thumb_label: Label = thumb_label_v as Label
	thumb_label.text = "SLOT"
	thumb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thumb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thumb_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_apply_font(thumb_label, 14)
	thumb.move_child(thumb_label, thumb.get_child_count() - 1)

	var info_box_v: Node = card_box.get_node_or_null("信息盒")
	if not (info_box_v is VBoxContainer):
		push_error("UI node type mismatch: %s/卡片盒/信息盒" % slot_btn.name)
		return false
	var info_box: VBoxContainer = info_box_v as VBoxContainer
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_theme_constant_override("separation", 2)

	var line_top_v: Node = info_box.get_node_or_null("信息上行")
	var line_mid_v: Node = info_box.get_node_or_null("信息中行")
	var line_bottom_v: Node = info_box.get_node_or_null("信息下行")
	if not (line_top_v is Label) or not (line_mid_v is Label) or not (line_bottom_v is Label):
		push_error("UI node type mismatch: %s/卡片盒/信息盒/Line*" % slot_btn.name)
		return false
	var line_top: Label = line_top_v as Label
	var line_mid: Label = line_mid_v as Label
	var line_bottom: Label = line_bottom_v as Label

	line_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_top.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
	_apply_font(line_top, 15)

	line_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_mid.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_mid.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	_apply_font(line_mid, 13)

	line_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_bottom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_bottom.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	_apply_font(line_bottom, 12)

	slot_btn.set_meta("slot_thumb", thumb)
	slot_btn.set_meta("slot_thumb_preview", thumb_preview)
	slot_btn.set_meta("slot_thumb_label", thumb_label)
	slot_btn.set_meta("slot_line_top", line_top)
	slot_btn.set_meta("slot_line_mid", line_mid)
	slot_btn.set_meta("slot_line_bottom", line_bottom)

	var slot_callable: Callable
	if is_save:
		slot_callable = Callable(self, "_on_save_slot_pressed").bind(cell_idx)
	else:
		slot_callable = Callable(self, "_on_load_slot_pressed").bind(cell_idx)
	if not slot_btn.pressed.is_connected(slot_callable):
		slot_btn.pressed.connect(slot_callable)
	return true


func _set_rect_layout(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = x
	control.offset_top = y
	control.offset_right = x + w
	control.offset_bottom = y + h


func _compute_ui_layout() -> Dictionary:
	var sw: float = get_viewport_rect().size.x
	var sh: float = get_viewport_rect().size.y
	# Keep integer geometry to avoid sub-pixel seams (the thin center line issue).
	var top_margin: float = maxf(18.0, floorf(sh * 0.03))
	var bottom_margin: float = maxf(14.0, floorf(sh * 0.02))
	var gap: float = maxf(14.0, floorf(sh * 0.02))

	var dialogue_height: float = clampf(floorf(sh * 0.24), 140.0, 240.0)
	var max_stage_height: float = maxf(250.0, sh - top_margin - gap - dialogue_height - bottom_margin)
	var stage_width: float = floorf(max_stage_height * 16.0 / 9.0)
	stage_width = minf(stage_width, floorf(sw * 0.74))
	stage_width = maxf(stage_width, floorf(sw * 0.58))
	var stage_height: float = floorf(stage_width * 9.0 / 16.0)
	var total_height: float = stage_height + gap + dialogue_height
	var stage_top: float = maxf(top_margin, floorf((sh - total_height - bottom_margin) * 0.5))
	var stage_left: float = floorf((sw - stage_width) * 0.5)
	var stage_right: float = stage_left + stage_width
	var stage_bottom: float = stage_top + stage_height
	var dialogue_top: float = stage_bottom + gap
	if dialogue_top + dialogue_height + bottom_margin > sh:
		dialogue_height = maxf(110.0, sh - dialogue_top - bottom_margin)
	var dialogue_bottom: float = dialogue_top + dialogue_height
	return {
		"sw": sw,
		"sh": sh,
		"stage_width": stage_width,
		"stage_height": stage_height,
		"stage_left": stage_left,
		"stage_right": stage_right,
		"stage_top": stage_top,
		"stage_bottom": stage_bottom,
		"dialogue_top": dialogue_top,
		"dialogue_bottom": dialogue_bottom,
		"dialogue_height": dialogue_height
	}


func _apply_ui_layout() -> void:
	if use_scene_tree_layout:
		_sync_corner_masks_from_current_layout()
		_apply_character_projection_scene_tree()
		return
	cached_layout = _compute_ui_layout()
	var sw: float = float(cached_layout.get("sw", 1920.0))
	var sh: float = float(cached_layout.get("sh", 1080.0))
	var s: float = ui_scale
	var stage_left: float = float(cached_layout.get("stage_left", 0.0))
	var stage_right: float = float(cached_layout.get("stage_right", sw))
	var stage_top: float = float(cached_layout.get("stage_top", 0.0))
	var stage_bottom: float = float(cached_layout.get("stage_bottom", sh))
	var stage_width: float = float(cached_layout.get("stage_width", sw))
	var stage_height: float = float(cached_layout.get("stage_height", sh))
	var dialogue_top: float = float(cached_layout.get("dialogue_top", stage_bottom))
	var dialogue_bottom: float = float(cached_layout.get("dialogue_bottom", sh))
	var dialogue_height: float = float(cached_layout.get("dialogue_height", 200.0))

	# Keep the playable visual area centered in the stage frame.
	if background_rect != null:
		# Add 1px overlap at bottom to prevent a seam line between stage and mask.
		_set_rect_layout(background_rect, stage_left, stage_top, stage_width, stage_height + 1.0)
	if character_rect != null:
		# Match Ren'Py sprite projection: character is composed in 1920x1080 space,
		# then the whole stage is scaled and moved to the centered playfield.
		var sprite_zoom: float = 1.0
		var sprite_yoffset: float = VictoriaSceneConfig.CHAR_BASE_YOFFSET
		if state != null:
			sprite_zoom = maxf(0.1, float(state.v_sprite_zoom))
			sprite_yoffset = float(state.v_sprite_yoffset)
		var tex_size: Vector2 = Vector2(768.0, 1376.0)
		if character_rect.texture != null:
			tex_size = character_rect.texture.get_size()
		var stage_zoom: float = stage_width / 1920.0
		var raw_w: float = tex_size.x * sprite_zoom
		var raw_h: float = tex_size.y * sprite_zoom
		var raw_x: float = (1920.0 - raw_w) * 0.5
		var raw_y: float = (1080.0 - raw_h) + sprite_yoffset
		var draw_x: float = stage_left + raw_x * stage_zoom
		var draw_y: float = stage_top + raw_y * stage_zoom
		var draw_w: float = raw_w * stage_zoom
		var draw_h: float = raw_h * stage_zoom
		character_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		character_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_set_rect_layout(
			character_rect,
			roundf(draw_x),
			roundf(draw_y),
			roundf(draw_w),
			roundf(draw_h)
		)

	if playfield_masks.size() >= 4:
		_set_rect_layout(playfield_masks[0], 0.0, 0.0, sw, stage_top)
		_set_rect_layout(playfield_masks[1], 0.0, stage_bottom + 1.0, sw, maxf(0.0, sh - stage_bottom - 1.0))
		_set_rect_layout(playfield_masks[2], 0.0, stage_top, stage_left, stage_height + 1.0)
		_set_rect_layout(playfield_masks[3], stage_right, stage_top, sw - stage_right, stage_height + 1.0)

	if stage_border_lines.size() >= 4:
		_set_rect_layout(stage_border_lines[0], stage_left - 2.0, stage_top - 2.0, stage_width + 4.0, 2.0)
		_set_rect_layout(stage_border_lines[1], stage_left - 2.0, stage_bottom, stage_width + 4.0, 2.0)
		_set_rect_layout(stage_border_lines[2], stage_left - 2.0, stage_top - 2.0, 2.0, stage_height + 4.0)
		_set_rect_layout(stage_border_lines[3], stage_right, stage_top - 2.0, 2.0, stage_height + 4.0)
	if stage_frame_panel != null:
		_set_rect_layout(stage_frame_panel, stage_left - 2.0, stage_top - 2.0, stage_width + 4.0, stage_height + 4.0)

	if dialogue_border_lines.size() >= 4:
		_set_rect_layout(dialogue_border_lines[0], stage_left - 2.0, dialogue_top - 2.0, stage_width + 4.0, 2.0)
		_set_rect_layout(dialogue_border_lines[1], stage_left - 2.0, dialogue_bottom, stage_width + 4.0, 2.0)
		_set_rect_layout(dialogue_border_lines[2], stage_left - 2.0, dialogue_top - 2.0, 2.0, dialogue_height + 4.0)
		_set_rect_layout(dialogue_border_lines[3], stage_right, dialogue_top - 2.0, 2.0, dialogue_height + 4.0)
	if dialogue_frame_panel != null:
		_set_rect_layout(dialogue_frame_panel, stage_left - 2.0, dialogue_top - 2.0, stage_width + 4.0, dialogue_height + 4.0)
	_apply_corner_mask_rect(stage_corner_mask, Rect2(stage_left, stage_top, stage_width, stage_height + 1.0), float(OUTER_FRAME_RADIUS))
	_apply_corner_mask_rect(dialogue_corner_mask, Rect2(stage_left, dialogue_top, stage_width, dialogue_height), float(OUTER_FRAME_RADIUS))

	_set_rect_layout(dialogue_panel_ref, stage_left, dialogue_top, stage_width, dialogue_height)
	var text_width: float = maxf(220.0, stage_width - 120.0)
	var text_left: float = (stage_width - text_width) * 0.5
	if speaker_label != null:
		_set_rect_layout(speaker_label, text_left, dialogue_height * 0.16 - 20.0 * s, text_width, 42.0 * s)
	var has_name: bool = speaker_label != null and speaker_label.visible and not speaker_label.text.strip_edges().is_empty()
	var dialogue_text_y: float = dialogue_height * (0.44 if has_name else 0.34)
	if dialogue_label != null:
		_set_rect_layout(dialogue_label, text_left, dialogue_text_y, text_width, maxf(48.0, dialogue_height * 0.26))
	if chat_prompt_label != null:
		_set_rect_layout(chat_prompt_label, text_left, dialogue_height * 0.24 - 16.0 * s, text_width, 34.0 * s)
	if choices_box != null:
		var item_count: int = maxi(1, choices_box.get_child_count())
		var estimated_item_height: float = 64.0
		var estimated_gap: float = 12.0
		var total_height: float = float(item_count) * estimated_item_height + float(maxi(0, item_count - 1)) * estimated_gap
		var choice_top: float = maxf(stage_top + 16.0, stage_bottom - total_height - 20.0)
		var choice_width: float = minf(stage_width, maxf(420.0, 1185.0 * s))
		var choice_left: float = stage_left + (stage_width - choice_width) * 0.5
		_set_rect_layout(choices_box, choice_left, choice_top, choice_width, total_height)

	var panel_top: float = stage_top + 26.0 * s
	var outer_margin: float = 12.0 * s
	var panel_gap: float = 12.0 * s
	var left_side_width: float = stage_left
	var right_side_width: float = sw - stage_right
	var max_panel_width: float = minf(left_side_width, right_side_width) - outer_margin - panel_gap
	var panel_width: float = clampf(max_panel_width, 94.0 * s, 220.0 * s)
	var left_panel_x: float = maxf(outer_margin, stage_left - panel_width - panel_gap)
	var right_panel_x: float = minf(sw - panel_width - outer_margin, stage_right + panel_gap)
	var panel_h: float = maxf(172.0 * s, minf(stage_height - 36.0 * s, 420.0 * s))
	_set_rect_layout(hud_panel_ref, left_panel_x, panel_top, panel_width, panel_h)
	_set_rect_layout(love_panel_ref, right_panel_x, panel_top, panel_width, panel_h)

	love_track_height = clampf(stage_height * 0.62, 240.0, 340.0)
	if love_track_holder != null:
		love_track_holder.custom_minimum_size = Vector2(40.0, love_track_height)

	var quick_menu_height: float = 0.0
	if quick_menu_box != null:
		var quick_size: Vector2 = quick_menu_box.get_combined_minimum_size()
		quick_menu_height = quick_size.y
		var quick_x: float = (sw - quick_size.x) * 0.5
		var quick_y: float = dialogue_top + dialogue_height - 14.0 - quick_size.y
		_set_rect_layout(quick_menu_box, quick_x, quick_y, quick_size.x, quick_size.y)
	if ai_waiting_label != null:
		_set_rect_layout(ai_waiting_label, stage_left, dialogue_top + dialogue_height * 0.32, stage_width, 36.0)

	var nav_btn_w: float = clampf(stage_width * 0.23, 144.0, 196.0)
	var nav_btn_h: float = 46.0 * s
	var nav_btn_gap: float = 10.0 * s
	var nav_btn_x: float = stage_right - nav_btn_w - 14.0 * s
	var nav_btn_y: float = stage_top + stage_height * 0.38
	var call_btn_y: float = nav_btn_y + nav_btn_h + nav_btn_gap
	_set_rect_layout(room_nav_button, nav_btn_x, nav_btn_y, nav_btn_w, nav_btn_h)
	_set_rect_layout(call_victoria_button, nav_btn_x, call_btn_y, nav_btn_w, nav_btn_h)
	_set_rect_layout(room_nav_panel, nav_btn_x, call_btn_y + nav_btn_h + 8.0 * s, nav_btn_w, 228.0 * s)
	_set_rect_layout(
		web_toggle_button,
		stage_left + stage_width - 230.0 * s,
		dialogue_top + 8.0 * s,
		220.0 * s,
		34.0 * s
	)
	var end_turn_w: float = 190.0 * s
	var end_turn_h: float = 42.0 * s
	var end_turn_x: float = sw * 0.98 - end_turn_w
	var end_turn_y: float = sh * 0.95 - end_turn_h
	_set_rect_layout(end_turn_button, end_turn_x, end_turn_y, end_turn_w, end_turn_h)
	if blackjack_trust_track != null:
		# Lock trust bar to a compact top-right capsule footprint.
		var trust_w: float = 124.0 * s
		var trust_h: float = 22.0 * s
		var trust_x: float = sw - trust_w - 102.0 * s
		var trust_y: float = 20.0 * s
		_set_rect_layout(blackjack_trust_track, trust_x, trust_y, trust_w, trust_h)

	var debug_x: float = maxf(12.0 * s, stage_left - 332.0 * s)
	var debug_y: float = minf(sh - 40.0, stage_top + 118.0)
	var debug_h: float = maxf(220.0 * s, sh - debug_y - 24.0 * s)
	_set_rect_layout(debug_panel, debug_x, debug_y, 320.0 * s, debug_h)
	_set_rect_layout(notify_panel, sw * 0.5 - 210.0 * s, 22.0 * s, 420.0 * s, 44.0 * s)
	var nav_width: float = clampf(sw * 0.19, 208.0, 320.0)
	if sw < 1200.0:
		nav_width = 200.0
	if game_menu_panel != null:
		_set_rect_layout(game_menu_panel, 0.0, 0.0, sw, sh)
		var menu_margin_v: Node = game_menu_panel.get_node_or_null("游戏菜单内容边距")
		if menu_margin_v is MarginContainer:
			var menu_margin: MarginContainer = menu_margin_v as MarginContainer
			menu_margin.add_theme_constant_override("margin_left", int(round(64.0 * s)))
			menu_margin.add_theme_constant_override("margin_top", int(round(180.0 * s)))
			menu_margin.add_theme_constant_override("margin_right", int(round(42.0 * s)))
			menu_margin.add_theme_constant_override("margin_bottom", int(round(40.0 * s)))
		var menu_shell_v: Node = game_menu_panel.get_node_or_null("游戏菜单内容边距/游戏菜单框架")
		if menu_shell_v is HBoxContainer:
			var menu_shell: HBoxContainer = menu_shell_v as HBoxContainer
			menu_shell.add_theme_constant_override("separation", int(round(64.0 * s)))
		var page_margin_v: Node = game_menu_panel.get_node_or_null("游戏菜单内容边距/游戏菜单框架/游戏菜单内容盒/游戏菜单页面框/游戏菜单页面边距")
		if page_margin_v is MarginContainer:
			var page_margin: MarginContainer = page_margin_v as MarginContainer
			page_margin.add_theme_constant_override("margin_left", int(round(22.0 * s)))
			page_margin.add_theme_constant_override("margin_top", int(round(18.0 * s)))
			page_margin.add_theme_constant_override("margin_right", int(round(22.0 * s)))
			page_margin.add_theme_constant_override("margin_bottom", int(round(18.0 * s)))
	if game_menu_nav_box != null:
		game_menu_nav_box.custom_minimum_size = Vector2(nav_width, 0.0)
	var slot_cols: int = 3
	if sw < 1480.0 or sh < 780.0:
		slot_cols = 2
	if sw < 1080.0 or sh < 640.0:
		slot_cols = 1
	if save_grid_ref != null:
		save_grid_ref.columns = slot_cols
	if load_grid_ref != null:
		load_grid_ref.columns = slot_cols
	var page_button_cols: int = 5
	if sw < 1420.0:
		page_button_cols = 4
	if sw < 1080.0:
		page_button_cols = 3
	if save_page_buttons_ref != null:
		save_page_buttons_ref.columns = page_button_cols
	if load_page_buttons_ref != null:
		load_page_buttons_ref.columns = page_button_cols
	if input_row_margin_ref != null:
		# Match Ren'Py input screen geometry: fixed field inside dialogue box.
		var input_frame_x: float = 48.0
		var input_frame_y: float = dialogue_height * 0.56 - 11.0
		var input_frame_w: float = maxf(180.0, stage_width - 96.0)
		var input_frame_h: float = maxf(44.0, 58.0 * s)
		var input_bottom_limit: float = dialogue_height - 8.0
		if quick_menu_height > 0.0:
			input_bottom_limit = minf(input_bottom_limit, dialogue_height - quick_menu_height - 22.0)
		if input_frame_y + input_frame_h > input_bottom_limit:
			input_frame_y = input_bottom_limit - input_frame_h
		input_frame_y = maxf(34.0, input_frame_y)
		_set_rect_layout(input_row_margin_ref, input_frame_x, input_frame_y, input_frame_w, input_frame_h)
	var menu_margin_left: float = round(64.0 * s)
	var menu_margin_right: float = round(42.0 * s)
	var shell_spacing: float = round(64.0 * s)
	var page_inner_margin: float = round(22.0 * s)
	var slot_gap: float = 24.0
	var slot_area_w: float = sw - menu_margin_left - menu_margin_right - shell_spacing - nav_width - page_inner_margin * 2.0
	var slot_card_w: float = clampf(
		(slot_area_w - slot_gap * float(maxi(0, slot_cols - 1))) / float(maxi(1, slot_cols)),
		220.0,
		380.0
	)
	var slot_card_h: float = clampf(slot_card_w * 1.02, 220.0, 360.0)
	for btn in save_slot_buttons:
		if btn != null:
			btn.custom_minimum_size = Vector2(slot_card_w, slot_card_h)
	for btn2 in load_slot_buttons:
		if btn2 != null:
			btn2.custom_minimum_size = Vector2(slot_card_w, slot_card_h)
	_refresh_chat_prompt()
	_update_love_visual(0)


func _apply_character_projection_scene_tree() -> void:
	if character_rect == null or background_rect == null:
		return
	# Keep Ren'Py-like projection for sprite size/position while scene tree drives UI layout.
	var stage_rect: Rect2 = background_rect.get_rect()
	if stage_rect.size.x <= 1.0 or stage_rect.size.y <= 1.0:
		return
	var sprite_zoom: float = 1.0
	var sprite_yoffset: float = VictoriaSceneConfig.CHAR_BASE_YOFFSET
	if state != null:
		sprite_zoom = maxf(0.1, float(state.v_sprite_zoom))
		sprite_yoffset = float(state.v_sprite_yoffset)
	var tex_size: Vector2 = Vector2(768.0, 1376.0)
	if character_rect.texture != null:
		tex_size = character_rect.texture.get_size()
	var stage_zoom: float = stage_rect.size.x / 1920.0
	var raw_w: float = tex_size.x * sprite_zoom
	var raw_h: float = tex_size.y * sprite_zoom
	var raw_x: float = (1920.0 - raw_w) * 0.5
	var raw_y: float = (1080.0 - raw_h) + sprite_yoffset
	var draw_x: float = stage_rect.position.x + raw_x * stage_zoom
	var draw_y: float = stage_rect.position.y + raw_y * stage_zoom
	var draw_w: float = raw_w * stage_zoom
	var draw_h: float = raw_h * stage_zoom
	character_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_set_rect_layout(character_rect, roundf(draw_x), roundf(draw_y), roundf(draw_w), roundf(draw_h))


func _on_viewport_size_changed() -> void:
	if ui_root == null:
		return
	var old_scale: float = ui_scale
	ui_scale = _current_ui_scale()
	if absf(old_scale - ui_scale) > 0.001:
		_refresh_scaled_fonts(ui_root)
	_apply_ui_layout()
	_refresh_room_nav_ui()


func _style_input_font(new_text: String) -> void:
	if input_line == null:
		return
	var compact: String = String(new_text).replace(" ", "").replace("\n", "").strip_edges()
	var text_length: int = compact.length()
	var size: int = 28
	if text_length > 52:
		size = 22
	elif text_length > 34:
		size = 24
	elif text_length > 18:
		size = 26
	_apply_font(input_line, size)


func _refresh_chat_prompt() -> void:
	if chat_prompt_label == null:
		return
	# Keep prompt label fully disabled; Ren'Py original has no extra input hint text.
	chat_prompt_label.visible = false


func _on_quick_menu_pressed(action_key: String) -> void:
	match action_key:
		"qsave":
			_save_runtime_state()
			_show_notify("已保存")
		"save":
			if has_method("_open_game_menu"):
				call("_open_game_menu", "save")
		"qload":
			if has_method("_load_quick_runtime_state"):
				call("_load_quick_runtime_state")
		"rollback":
			if typing_active:
				if has_method("_complete_typewriter"):
					call("_complete_typewriter")
			else:
				_show_notify("当前回合不可回退")
		"history":
			if has_method("_open_game_menu"):
				call("_open_game_menu", "history")
		"skip":
			quick_skip_enabled = not quick_skip_enabled
			if quick_skip_enabled:
				quick_auto_enabled = false
			_refresh_quick_menu_captions()
			_show_notify("快进%s" % ("开启" if quick_skip_enabled else "关闭"))
		"auto":
			quick_auto_enabled = not quick_auto_enabled
			if quick_auto_enabled:
				quick_skip_enabled = false
			_refresh_quick_menu_captions()
			_show_notify("自动%s" % ("开启" if quick_auto_enabled else "关闭"))
		"prefs":
			if has_method("_open_game_menu"):
				call("_open_game_menu", "settings")
		_:
			_show_notify("功能还在迁移中")


func _refresh_quick_menu_captions() -> void:
	var caption_map: Dictionary = {
		"rollback": "回退",
		"history": "历史",
		"skip": "快进",
		"auto": "自动",
		"save": "保存",
		"qsave": "快存",
		"qload": "快读",
		"prefs": "设置"
	}
	for key in quick_menu_buttons.keys():
		var button_v: Variant = quick_menu_buttons.get(key, null)
		if not (button_v is Button):
			continue
		var btn: Button = button_v as Button
		btn.text = String(caption_map.get(String(key), btn.text))


func _set_quick_menu_enabled(enabled: bool) -> void:
	for key in quick_menu_buttons.keys():
		var button_v: Variant = quick_menu_buttons.get(key, null)
		if button_v is Button:
			(button_v as Button).disabled = not enabled


func _open_modal_panel(_panel: PanelContainer) -> void:
	# Legacy adapter: old modal entry points now route to full game menu.
	if has_method("_open_game_menu"):
		call("_open_game_menu", "history")


func _close_modal_panels() -> void:
	if has_method("_close_save_slot_confirm"):
		var closed_save_confirm: Variant = call("_close_save_slot_confirm")
		if typeof(closed_save_confirm) == TYPE_BOOL and bool(closed_save_confirm):
			return
	if has_method("_close_main_menu_return_confirm"):
		var closed_confirm: Variant = call("_close_main_menu_return_confirm")
		if typeof(closed_confirm) == TYPE_BOOL and bool(closed_confirm):
			return
	modal_ui_open = false
	if modal_fade_tween != null:
		modal_fade_tween.kill()
		modal_fade_tween = null
	if menu_overlay_mask == null or game_menu_panel == null:
		if menu_overlay_mask != null:
			menu_overlay_mask.visible = false
		if game_menu_panel != null:
			game_menu_panel.visible = false
		_update_interaction_state(false)
		return
	if not menu_overlay_mask.visible and not game_menu_panel.visible:
		_update_interaction_state(false)
		return
	menu_overlay_mask.visible = true
	game_menu_panel.visible = true
	modal_fade_tween = create_tween()
	modal_fade_tween.set_parallel(true)
	modal_fade_tween.tween_property(menu_overlay_mask, "self_modulate:a", 0.0, 0.12)
	modal_fade_tween.tween_property(game_menu_panel, "self_modulate:a", 0.0, 0.12)
	modal_fade_tween.chain().tween_callback(Callable(self, "_finalize_modal_panels_closed"))
	_update_interaction_state(false)


func _finalize_modal_panels_closed() -> void:
	if menu_overlay_mask != null:
		menu_overlay_mask.visible = false
		menu_overlay_mask.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	if game_menu_panel != null:
		game_menu_panel.visible = false
		game_menu_panel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	modal_fade_tween = null


func _clear_modal_fade_tween() -> void:
	modal_fade_tween = null


func _on_menu_overlay_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		if has_method("_is_save_slot_confirm_open") and bool(call("_is_save_slot_confirm_open")):
			if has_method("_close_save_slot_confirm"):
				call("_close_save_slot_confirm")
			return
		if has_method("_is_main_menu_return_confirm_open") and bool(call("_is_main_menu_return_confirm_open")):
			if has_method("_close_main_menu_return_confirm"):
				call("_close_main_menu_return_confirm")
			return
		_close_modal_panels()


func _on_input_text_changed(new_text: String) -> void:
	state.input_live_text = new_text
	_style_input_font(new_text)


func _on_blackjack_input_text_changed(new_text: String) -> void:
	state.input_live_text = new_text
	_style_blackjack_input_font(new_text)


func _style_blackjack_input_font(new_text: String) -> void:
	if blackjack_input_line == null:
		return
	var compact: String = String(new_text).replace(" ", "").replace("\n", "").strip_edges()
	var text_length: int = compact.length()
	var size: int = 24
	if text_length > 30:
		size = 20
	elif text_length > 18:
		size = 22
	_apply_font(blackjack_input_line, size)


func _on_blackjack_input_submitted(_text: String) -> void:
	if has_method("_on_send_pressed"):
		call("_on_send_pressed")


func _on_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if input_line == null or not input_line.editable:
		return
	input_line.grab_focus()
	var font: Font = input_line.get_theme_font("font")
	if font == null:
		return
	var font_size: int = input_line.get_theme_font_size("font_size")
	var content: String = input_line.text
	var best_pos: int = 0
	var best_dist: float = INF
	var probe_x: float = maxf(0.0, mouse_event.position.x - 8.0)
	for i in range(content.length() + 1):
		var prefix: String = content.substr(0, i)
		var width: float = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var dist: float = absf(probe_x - width)
		if dist < best_dist:
			best_dist = dist
			best_pos = i
	input_line.set_caret_column(best_pos)


func _on_blackjack_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if blackjack_input_line == null or not blackjack_input_line.editable:
		return
	blackjack_input_line.grab_focus()


func _on_web_toggle_pressed() -> void:
	state.web_search_enabled = not state.web_search_enabled
	var flag: String = "开启" if state.web_search_enabled else "关闭"
	_show_notify("联网检索：%s" % flag)
	if has_method("_push_debug_event"):
		call("_push_debug_event", "联网检索已%s" % flag)
	_update_hud()
	_save_runtime_state()


func _on_debug_toggle_pressed() -> void:
	if not DEBUG_UI_ENABLED:
		state.debug_panel_open = false
		_update_hud()
		return
	state.debug_panel_open = not state.debug_panel_open
	_show_notify("调试面板：%s" % ("开启" if state.debug_panel_open else "关闭"))
	if has_method("_push_debug_event"):
		call("_push_debug_event", "调试面板%s" % ("开启" if state.debug_panel_open else "关闭"))
	_update_hud()
	_save_runtime_state()


func _show_notify(message: String, duration: float = 2.0) -> void:
	if notify_panel == null or notify_label == null:
		return
	var text: String = message.strip_edges()
	if text.is_empty():
		return
	notify_label.text = text
	notify_panel.visible = true
	if notify_timer != null:
		notify_timer.start(maxf(0.2, duration))


func _on_notify_timeout() -> void:
	if notify_panel != null:
		notify_panel.visible = false


func _on_room_nav_button_pressed() -> void:
	_toggle_room_nav()


func _on_room_nav_mask_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if state.room_nav_open:
		state.room_nav_open = false
		_refresh_room_nav_ui()


func _toggle_room_nav() -> void:
	if not _room_nav_available():
		_show_notify("暂无可切换房间")
		state.room_nav_open = false
		_refresh_room_nav_ui()
		return
	if not state.room_nav_open and _room_navigation_items().is_empty():
		_show_notify("暂无可切换房间")
		return
	state.room_nav_open = not state.room_nav_open
	_refresh_room_nav_ui()


func _room_nav_available() -> bool:
	return mode == "chat" and not blackjack_active and not modal_ui_open


func _room_navigation_items() -> Array[Dictionary]:
	var room_defs: Array[Dictionary] = [
		{"key": "sister_room", "caption": "去妹妹的房间"},
		{"key": "living_room", "caption": "去客厅"},
		{"key": "kitchen", "caption": "去厨房"},
		{"key": "player_room", "caption": "去你的房间"}
	]
	var items: Array[Dictionary] = []
	for item in room_defs:
		var room_key: String = String(item.get("key", ""))
		if room_key == state.current_location:
			continue
		if not _room_has_assets(room_key):
			continue
		items.append(item)
	return items


func _room_has_assets(room_key: String) -> bool:
	if not VictoriaSceneConfig.ROOM_BG_KEYS.has(room_key):
		return false
	var room_map_v: Variant = VictoriaSceneConfig.ROOM_BG_KEYS.get(room_key, {})
	if typeof(room_map_v) != TYPE_DICTIONARY:
		return false
	var room_map: Dictionary = room_map_v
	for period in ["早上", "中午", "下午", "晚上"]:
		var bg_key: String = String(room_map.get(period, ""))
		if bg_key.is_empty():
			continue
		var bg_path: String = String(VictoriaSceneConfig.BG_TEXTURES.get(bg_key, ""))
		if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
			return true
	return false


func _refresh_room_nav_ui() -> void:
	if room_nav_button == null or room_nav_panel == null or room_nav_mask == null or room_nav_list == null:
		return
	if not cached_layout.is_empty():
		_apply_ui_layout()
	var available: bool = _room_nav_available()
	var items: Array[Dictionary] = _room_navigation_items()
	if not available:
		state.room_nav_open = false
	room_nav_button.disabled = not available or items.is_empty()
	room_nav_button.text = "去其他房间"
	if room_nav_button.disabled:
		room_nav_button.text = "暂无可切换房间"

	for child in room_nav_list.get_children():
		child.queue_free()
	for item in items:
		var room_btn: Button = Button.new()
		room_btn.text = String(item.get("caption", "去其他房间"))
		_style_room_button(room_btn, 18)
		room_btn.custom_minimum_size = Vector2(0.0, 46.0)
		room_btn.pressed.connect(Callable(self, "_on_room_nav_item_pressed").bind(String(item.get("key", ""))))
		room_nav_list.add_child(room_btn)

	var nav_height: float = float(maxi(1, items.size())) * 56.0
	nav_height = minf(nav_height, 320.0)
	room_nav_panel.offset_bottom = room_nav_panel.offset_top + nav_height

	var show_panel: bool = available and state.room_nav_open and not items.is_empty()
	room_nav_button.visible = available and not show_panel
	if call_victoria_button != null:
		call_victoria_button.disabled = not available
		call_victoria_button.visible = available and not show_panel
	room_nav_panel.visible = show_panel
	room_nav_mask.visible = show_panel


func _on_room_nav_item_pressed(target_room: String) -> void:
	state.room_nav_open = false
	_refresh_room_nav_ui()
	if has_method("_switch_room_with_immersion"):
		call_deferred("_switch_room_with_immersion", target_room)

