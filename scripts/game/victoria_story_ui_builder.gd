extends "res://scripts/game/victoria_story_ui_base.gd"

const HUD_MONEY_ICON_PATH := "res://assets/gui/icons/coin_yen.png"
const LOVE_HEART_ICON_PATH := "res://assets/gui/icons/heart_outline.png"
const HUD_ICON_SIZE := 30.0
const LOVE_ICON_SIZE := 26.0
const BLACKJACK_BET_DENOMS: Array[int] = [5, 10, 50, 100, 200, 500]

func _require_ui_node(parent: Node, path: String) -> Node:
	var node: Node = parent.get_node_or_null(path)
	if node == null:
		push_error("UI node missing: %s" % path)
	return node


func _ensure_stat_icon(parent: Control, name: String, icon_path: String, size_px: float, tint: Color = Color(1.0, 1.0, 1.0, 1.0)) -> TextureRect:
	var icon_v: Node = parent.get_node_or_null(name)
	var icon: TextureRect
	if icon_v is TextureRect:
		icon = icon_v as TextureRect
	else:
		icon = TextureRect.new()
		icon.name = name
		parent.add_child(icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(size_px, size_px)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	icon.texture = _load_texture_flexible(icon_path)
	return icon


func _load_texture_flexible(path: String) -> Texture2D:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		var image: Image = Image.load_from_file(absolute_path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	var loaded_v: Variant = load(path)
	if loaded_v is Texture2D:
		return loaded_v as Texture2D
	return null


func _build_chip_gradient_texture() -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.98, 0.86, 0.90),
		Color(0.98, 0.83, 0.42, 0.62),
		Color(0.90, 0.64, 0.18, 0.00)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.56, 1.0])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _build_chip_glow_texture() -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.95, 0.70, 0.00),
		Color(1.0, 0.93, 0.62, 0.00),
		Color(1.0, 0.84, 0.34, 0.66),
		Color(1.0, 0.76, 0.18, 0.00)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.72, 0.86, 1.0])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _ensure_circle_clip_material(rect: TextureRect) -> void:
	if rect == null:
		return
	var mat_v: Variant = rect.material
	if mat_v is ShaderMaterial:
		return
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment(){\n\tvec2 delta = UV - vec2(0.5);\n\tif (length(delta) > 0.5) {\n\t\tdiscard;\n\t}\n\tCOLOR = texture(TEXTURE, UV);\n}\n"
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat


func _ensure_blackjack_table_surface(panel: PanelContainer) -> void:
	var surface_v: Node = panel.get_node_or_null("blackjack_table_surface")
	var surface: ColorRect
	if surface_v is ColorRect:
		surface = surface_v as ColorRect
	else:
		surface = ColorRect.new()
		surface.name = "blackjack_table_surface"
		panel.add_child(surface)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	surface.offset_left = 0.0
	surface.offset_top = 0.0
	surface.offset_right = 0.0
	surface.offset_bottom = 0.0
	surface.z_index = -20
	surface.color = Color(0.02, 0.10, 0.075, 1.0)
	var mat_v: Variant = surface.material
	if not (mat_v is ShaderMaterial):
		var shader: Shader = Shader.new()
		shader.code = "shader_type canvas_item;\n\nfloat hash(vec2 p) {\n\treturn fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);\n}\n\nvoid fragment() {\n\tvec2 uv = UV;\n\tfloat radial = distance(uv, vec2(0.5, 0.48));\n\tfloat spotlight = smoothstep(0.82, 0.18, radial);\n\tfloat vignette = smoothstep(0.42, 0.96, radial);\n\tfloat grain = hash(floor(uv * vec2(360.0, 210.0))) - 0.5;\n\tvec3 edge = vec3(0.006, 0.030, 0.026);\n\tvec3 felt = vec3(0.020, 0.145, 0.100);\n\tvec3 warm = vec3(0.115, 0.190, 0.125);\n\tvec3 color = mix(edge, felt, spotlight);\n\tcolor = mix(color, warm, 0.18 * spotlight);\n\tcolor -= vignette * 0.16;\n\tcolor += grain * 0.020;\n\tCOLOR = vec4(color, 1.0);\n}\n"
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		surface.material = mat
	surface.move_to_front()
	panel.move_child(surface, 0)


func _ensure_money_display_row(hud_box: VBoxContainer) -> void:
	var money_row_v: Node = hud_box.get_node_or_null("金钱行")
	var money_row: HBoxContainer
	if money_row_v is HBoxContainer:
		money_row = money_row_v as HBoxContainer
	else:
		money_row = HBoxContainer.new()
		money_row.name = "金钱行"
		hud_box.add_child(money_row)
	money_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	money_row.add_theme_constant_override("separation", 12)
	money_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var target_index: int = clampi(mood_label.get_index() + 1, 0, hud_box.get_child_count() - 1)
	if money_row.get_parent() == hud_box and money_row.get_index() != target_index:
		hud_box.move_child(money_row, target_index)

	_ensure_stat_icon(money_row, "金钱图标", HUD_MONEY_ICON_PATH, HUD_ICON_SIZE)

	var money_label_v: Node = money_row.get_node_or_null("金钱数值标签")
	if money_label_v is Label:
		money_value_label = money_label_v as Label
	else:
		money_value_label = Label.new()
		money_value_label.name = "金钱数值标签"
		money_row.add_child(money_value_label)
	money_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_apply_font(money_value_label, 26)


func _ensure_love_header_icon(love_box: VBoxContainer, love_title: Label) -> void:
	var icon_wrap_v: Node = love_box.get_node_or_null("好感图标行")
	var icon_wrap: HBoxContainer
	if icon_wrap_v is HBoxContainer:
		icon_wrap = icon_wrap_v as HBoxContainer
	else:
		icon_wrap = HBoxContainer.new()
		icon_wrap.name = "好感图标行"
		love_box.add_child(icon_wrap)
	icon_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_wrap.add_theme_constant_override("separation", 0)
	icon_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if icon_wrap.get_parent() == love_box and icon_wrap.get_index() != 0:
		love_box.move_child(icon_wrap, 0)
	_ensure_stat_icon(icon_wrap, "好感图标", LOVE_HEART_ICON_PATH, LOVE_ICON_SIZE, Color(1.0, 0.82, 0.88, 1.0))
	love_title.visible = false
	love_title.text = ""
	love_title.custom_minimum_size = Vector2.ZERO


func _configure_blackjack_particle_nodes() -> void:
	if blackjack_draw_particles != null:
		var draw_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
		draw_material.direction = Vector3(0.0, -1.0, 0.0)
		draw_material.spread = 38.0
		draw_material.gravity = Vector3(0.0, 220.0, 0.0)
		draw_material.initial_velocity_min = 120.0
		draw_material.initial_velocity_max = 190.0
		draw_material.angular_velocity_min = -8.0
		draw_material.angular_velocity_max = 8.0
		draw_material.scale_min = 1.1
		draw_material.scale_max = 1.8
		draw_material.color = Color(0.95, 0.98, 1.0, 0.92)
		blackjack_draw_particles.process_material = draw_material
		blackjack_draw_particles.emitting = false
		blackjack_draw_particles.one_shot = true
		blackjack_draw_particles.local_coords = false
		blackjack_draw_particles.amount = 28
		blackjack_draw_particles.lifetime = 0.34
	if blackjack_result_particles != null:
		var result_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
		result_material.direction = Vector3(0.0, -1.0, 0.0)
		result_material.spread = 180.0
		result_material.gravity = Vector3(0.0, 280.0, 0.0)
		result_material.initial_velocity_min = 160.0
		result_material.initial_velocity_max = 260.0
		result_material.angular_velocity_min = -16.0
		result_material.angular_velocity_max = 16.0
		result_material.scale_min = 1.1
		result_material.scale_max = 2.2
		result_material.color = Color(0.95, 0.95, 0.95, 0.95)
		blackjack_result_particles.process_material = result_material
		blackjack_result_particles.emitting = false
		blackjack_result_particles.one_shot = true
		blackjack_result_particles.local_coords = false
		blackjack_result_particles.amount = 120
		blackjack_result_particles.lifetime = 0.65


func _ensure_blackjack_bet_ui(blackjack_box: VBoxContainer, before_control: Control = null) -> void:
	var row_v: Node = blackjack_box.get_node_or_null("blackjack_bet_chip_row")
	var row: HBoxContainer
	if row_v is HBoxContainer:
		row = row_v as HBoxContainer
	else:
		row = HBoxContainer.new()
		row.name = "blackjack_bet_chip_row"
		blackjack_box.add_child(row)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0.0, 104.0)

	if row.get_parent() == blackjack_box:
		var target_index: int = blackjack_box.get_child_count() - 1
		if before_control != null and before_control.get_parent() == blackjack_box:
			target_index = maxi(0, before_control.get_index())
		if row.get_index() != target_index:
			blackjack_box.move_child(row, target_index)

	var coin_icon: Texture2D = _load_texture_flexible(HUD_MONEY_ICON_PATH)
	var chip_gradient_texture: Texture2D = _build_chip_gradient_texture()
	var chip_glow_texture: Texture2D = _build_chip_glow_texture()
	blackjack_bet_buttons.clear()
	for denom in BLACKJACK_BET_DENOMS:
		var btn: Button = row.get_node_or_null("chip_%s" % str(denom)) as Button
		if btn == null:
			btn = Button.new()
			btn.name = "chip_%s" % str(denom)
			row.add_child(btn)

		btn.theme_type_variation = ""
		btn.flat = true
		btn.text = ""
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(98.0, 98.0)
		btn.expand_icon = true
		btn.icon = coin_icon
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_constant_override("h_separation", 0)
		btn.add_theme_constant_override("icon_max_width", 88)
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 0.0))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.0))
		btn.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.0))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		var legacy_border_v: Node = btn.get_node_or_null("bet_chip_border")
		if legacy_border_v != null:
			legacy_border_v.queue_free()

		var gradient_v: Node = btn.get_node_or_null("bet_chip_gradient")
		var gradient_rect: TextureRect
		if gradient_v is TextureRect:
			gradient_rect = gradient_v as TextureRect
		else:
			gradient_rect = TextureRect.new()
			gradient_rect.name = "bet_chip_gradient"
			btn.add_child(gradient_rect)
		gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gradient_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		gradient_rect.offset_left = 14.0
		gradient_rect.offset_top = 14.0
		gradient_rect.offset_right = -14.0
		gradient_rect.offset_bottom = -14.0
		gradient_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gradient_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gradient_rect.texture = chip_gradient_texture
		gradient_rect.modulate = Color(1.0, 1.0, 1.0, 0.62)
		_ensure_circle_clip_material(gradient_rect)

		var glow_v: Node = btn.get_node_or_null("bet_chip_glow")
		var glow_rect: TextureRect
		if glow_v is TextureRect:
			glow_rect = glow_v as TextureRect
		else:
			glow_rect = TextureRect.new()
			glow_rect.name = "bet_chip_glow"
			btn.add_child(glow_rect)
		glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow_rect.offset_left = -6.0
		glow_rect.offset_top = -6.0
		glow_rect.offset_right = 6.0
		glow_rect.offset_bottom = 6.0
		glow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glow_rect.texture = chip_glow_texture
		glow_rect.modulate = Color(1.0, 0.94, 0.60, 0.0)
		glow_rect.visible = false
		_ensure_circle_clip_material(glow_rect)

		var amount_v: Node = btn.get_node_or_null("bet_amount_label")
		var amount_label: Label
		if amount_v is Label:
			amount_label = amount_v as Label
		else:
			amount_label = Label.new()
			amount_label.name = "bet_amount_label"
			btn.add_child(amount_label)
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		amount_label.offset_left = 0.0
		amount_label.offset_top = 0.0
		amount_label.offset_right = 0.0
		amount_label.offset_bottom = 0.0
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount_label.text = str(denom)
		amount_label.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		_apply_font(amount_label, 24)
		amount_label.add_theme_color_override("font_color", Color(0.28, 0.17, 0.05, 1.0))
		amount_label.add_theme_color_override("font_outline_color", Color(0.98, 0.92, 0.74, 0.95))
		amount_label.add_theme_constant_override("outline_size", 2)
		btn.move_child(gradient_rect, 0)
		btn.move_child(glow_rect, 1)
		amount_label.move_to_front()

		var on_chip: Callable = Callable(self, "_on_blackjack_bet_chip_pressed").bind(denom)
		if not btn.pressed.is_connected(on_chip):
			btn.pressed.connect(on_chip)
		blackjack_bet_buttons[denom] = btn

	blackjack_bet_hint_label = null

func _build_ui() -> void:
	_load_ui_resources()
	ui_scale = _current_ui_scale()

	var existing_canvas: Node = get_node_or_null("界面画布")
	if not (existing_canvas is CanvasLayer):
		push_error("Scene node missing: 界面画布")
		return
	ui_canvas = existing_canvas as CanvasLayer

	var root_v: Node = ui_canvas.get_node_or_null("界面根")
	if not (root_v is Control):
		push_error("Scene node missing: 界面画布/界面根")
		return
	var root: Control = root_v as Control
	ui_root = root
	# Force full-rect canvas at runtime to avoid editor-saved offsets shrinking the whole UI.
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.offset_left = 0.0
	ui_root.offset_top = 0.0
	ui_root.offset_right = 0.0
	ui_root.offset_bottom = 0.0

	var bg_v: Node = _require_ui_node(root, "背景图")
	if not (bg_v is TextureRect):
		push_error("UI node type mismatch: 背景图")
		return
	background_rect = bg_v as TextureRect
	if not use_scene_tree_layout:
		background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		background_rect.offset_left = 0.0
		background_rect.offset_top = 0.0
		background_rect.offset_right = 0.0
		background_rect.offset_bottom = 0.0
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var char_v: Node = _require_ui_node(root, "角色图")
	if not (char_v is TextureRect):
		push_error("UI node type mismatch: 角色图")
		return
	character_rect = char_v as TextureRect
	if not use_scene_tree_layout:
		character_rect.anchor_left = 0.5
		character_rect.anchor_right = 0.5
		character_rect.anchor_top = 0.0
		character_rect.anchor_bottom = 1.0
		character_rect.offset_left = -360.0
		character_rect.offset_right = 360.0
		character_rect.offset_top = VictoriaSceneConfig.CHAR_BASE_OFFSET_TOP
		character_rect.offset_bottom = VictoriaSceneConfig.CHAR_BASE_OFFSET_BOTTOM
	character_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var fade_v: Node = _require_ui_node(root, "淡入淡出遮罩")
	if not (fade_v is ColorRect):
		push_error("UI node type mismatch: 淡入淡出遮罩")
		return
	fade_rect = fade_v as ColorRect
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.offset_left = 0.0
	fade_rect.offset_top = 0.0
	fade_rect.offset_right = 0.0
	fade_rect.offset_bottom = 0.0
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	playfield_masks.clear()
	for name in ["上遮罩", "下遮罩", "左遮罩", "右遮罩"]:
		var mask_v: Node = _require_ui_node(root, name)
		if not (mask_v is ColorRect):
			push_error("UI node type mismatch: %s" % name)
			return
		var mask: ColorRect = mask_v as ColorRect
		mask.color = Color(0.015, 0.015, 0.015, 1.0)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		playfield_masks.append(mask)

	stage_border_lines.clear()
	for name in ["舞台上边框", "舞台下边框", "舞台左边框", "舞台右边框"]:
		var line_v: Node = _require_ui_node(root, name)
		if not (line_v is ColorRect):
			push_error("UI node type mismatch: %s" % name)
			return
		var line: ColorRect = line_v as ColorRect
		line.color = Color(0.85, 0.85, 0.85, 0.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.visible = false
		stage_border_lines.append(line)

	dialogue_border_lines.clear()
	for name in ["对话上边框", "对话下边框", "对话左边框", "对话右边框"]:
		var line_v2: Node = _require_ui_node(root, name)
		if not (line_v2 is ColorRect):
			push_error("UI node type mismatch: %s" % name)
			return
		var line2: ColorRect = line_v2 as ColorRect
		line2.color = Color(0.85, 0.85, 0.85, 0.0)
		line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line2.visible = false
		dialogue_border_lines.append(line2)

	stage_frame_panel = null
	var stage_frame_v: Node = root.get_node_or_null("舞台框")
	if stage_frame_v is PanelContainer:
		stage_frame_panel = stage_frame_v as PanelContainer
		stage_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_frame_panel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		stage_frame_panel.add_theme_stylebox_override(
			"panel",
			_make_flat_style(
				Color(0.0, 0.0, 0.0, 0.0),
				Color(0.92, 0.92, 0.92, 0.92),
				OUTER_FRAME_BORDER_WIDTH,
				OUTER_FRAME_RADIUS,
				0,
				0,
				0,
				0
			)
		)
	stage_corner_mask = null
	var stage_corner_mask_v: Node = root.get_node_or_null("舞台圆角遮罩")
	if stage_corner_mask_v is ColorRect:
		stage_corner_mask = stage_corner_mask_v as ColorRect
		_configure_corner_mask(stage_corner_mask, float(OUTER_FRAME_RADIUS), Color(0.015, 0.015, 0.015, 1.0))

	dialogue_frame_panel = null
	var dialogue_frame_v: Node = root.get_node_or_null("对话框")
	if dialogue_frame_v is PanelContainer:
		dialogue_frame_panel = dialogue_frame_v as PanelContainer
		dialogue_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dialogue_frame_panel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		dialogue_frame_panel.add_theme_stylebox_override(
			"panel",
			_make_flat_style(
				Color(0.0, 0.0, 0.0, 0.0),
				Color(0.92, 0.92, 0.92, 0.92),
				OUTER_FRAME_BORDER_WIDTH,
				OUTER_FRAME_RADIUS,
				0,
				0,
				0,
				0
			)
		)
	dialogue_corner_mask = null
	var dialogue_corner_mask_v: Node = root.get_node_or_null("对话圆角遮罩")
	if dialogue_corner_mask_v is ColorRect:
		dialogue_corner_mask = dialogue_corner_mask_v as ColorRect
		_configure_corner_mask(dialogue_corner_mask, float(OUTER_FRAME_RADIUS), Color(0.015, 0.015, 0.015, 1.0))

	var hud_panel_v: Node = _require_ui_node(root, "状态面板")
	if not (hud_panel_v is PanelContainer):
		push_error("UI node type mismatch: 状态面板")
		return
	hud_panel_ref = hud_panel_v as PanelContainer
	hud_panel_ref.self_modulate = Color(1.0, 1.0, 1.0, 0.92)
	hud_panel_ref.add_theme_stylebox_override(
		"panel",
		_make_flat_style(
			Color(0.03, 0.03, 0.03, 0.88),
			Color(0.92, 0.92, 0.92, 0.86),
			OUTER_FRAME_BORDER_WIDTH,
			10,
			6,
			6,
			6,
			6
		)
	)

	var hud_margin_v: Node = _require_ui_node(hud_panel_ref, "状态边距")
	if not (hud_margin_v is MarginContainer):
		push_error("UI node type mismatch: 状态边距")
		return
	var hud_margin: MarginContainer = hud_margin_v as MarginContainer
	hud_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_margin.add_theme_constant_override("margin_left", 16)
	hud_margin.add_theme_constant_override("margin_top", 14)
	hud_margin.add_theme_constant_override("margin_right", 16)
	hud_margin.add_theme_constant_override("margin_bottom", 14)

	var hud_box_v: Node = _require_ui_node(hud_margin, "状态盒")
	if not (hud_box_v is VBoxContainer):
		push_error("UI node type mismatch: 状态盒")
		return
	var hud_box: VBoxContainer = hud_box_v as VBoxContainer
	hud_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_box.add_theme_constant_override("separation", 6)

	var hud_label_v: Node = _require_ui_node(hud_box, "天数标签")
	if not (hud_label_v is Label):
		push_error("UI node type mismatch: 天数标签")
		return
	hud_label = hud_label_v as Label
	hud_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_apply_font(hud_label, 18)

	var mood_label_v: Node = _require_ui_node(hud_box, "情绪标签")
	if not (mood_label_v is Label):
		push_error("UI node type mismatch: 情绪标签")
		return
	mood_label = mood_label_v as Label
	mood_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_apply_font(mood_label, 30)

	var status_label_v: Node = _require_ui_node(hud_box, "状态标签")
	if not (status_label_v is Label):
		push_error("UI node type mismatch: 状态标签")
		return
	status_label = status_label_v as Label
	status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_apply_font(status_label, 12)
	_ensure_money_display_row(hud_box)

	var debug_btn_v: Node = _require_ui_node(hud_box, "调试切换按钮")
	if not (debug_btn_v is Button):
		push_error("UI node type mismatch: 调试切换按钮")
		return
	debug_toggle_button = debug_btn_v as Button
	_style_room_button(debug_toggle_button, 12)
	debug_toggle_button.visible = DEBUG_UI_ENABLED
	debug_toggle_button.disabled = not DEBUG_UI_ENABLED
	var debug_toggle_callable: Callable = Callable(self, "_on_debug_toggle_pressed")
	if not debug_toggle_button.pressed.is_connected(debug_toggle_callable):
		debug_toggle_button.pressed.connect(debug_toggle_callable)

	var love_panel_v: Node = _require_ui_node(root, "好感面板")
	if not (love_panel_v is PanelContainer):
		push_error("UI node type mismatch: 好感面板")
		return
	love_panel_ref = love_panel_v as PanelContainer
	love_panel_ref.self_modulate = Color(1.0, 1.0, 1.0, 0.92)
	love_panel_ref.add_theme_stylebox_override(
		"panel",
		_make_flat_style(
			Color(0.03, 0.03, 0.03, 0.88),
			Color(0.92, 0.92, 0.92, 0.86),
			OUTER_FRAME_BORDER_WIDTH,
			10,
			6,
			6,
			6,
			6
		)
	)

	var love_margin_v: Node = _require_ui_node(love_panel_ref, "好感边距")
	if not (love_margin_v is MarginContainer):
		push_error("UI node type mismatch: 好感边距")
		return
	var love_margin: MarginContainer = love_margin_v as MarginContainer
	love_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	love_margin.add_theme_constant_override("margin_left", 16)
	love_margin.add_theme_constant_override("margin_top", 14)
	love_margin.add_theme_constant_override("margin_right", 16)
	love_margin.add_theme_constant_override("margin_bottom", 14)

	var love_box_v: Node = _require_ui_node(love_margin, "好感盒")
	if not (love_box_v is VBoxContainer):
		push_error("UI node type mismatch: 好感盒")
		return
	var love_box: VBoxContainer = love_box_v as VBoxContainer
	love_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	love_box.alignment = BoxContainer.ALIGNMENT_CENTER
	love_box.add_theme_constant_override("separation", 6)

	var love_title_v: Node = _require_ui_node(love_box, "好感标题")
	if not (love_title_v is Label):
		push_error("UI node type mismatch: 好感标题")
		return
	var love_title: Label = love_title_v as Label
	love_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	love_title.text = "好感度"
	love_title.add_theme_color_override("font_color", Color(1, 1, 1))
	_apply_font(love_title, 18)
	_ensure_love_header_icon(love_box, love_title)

	var love_value_v: Node = _require_ui_node(love_box, "好感数值标签")
	if not (love_value_v is Label):
		push_error("UI node type mismatch: 好感数值标签")
		return
	love_value_label = love_value_v as Label
	love_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	love_value_label.add_theme_font_size_override("font_size", 42)
	love_value_label.add_theme_color_override("font_color", Color(1, 1, 1))

	var track_holder_v: Node = _require_ui_node(love_box, "好感轨道容器")
	if not (track_holder_v is Control):
		push_error("UI node type mismatch: 好感轨道容器")
		return
	love_track_holder = track_holder_v as Control
	love_track_holder.custom_minimum_size = Vector2(40, love_track_height)

	var track_v: Node = _require_ui_node(love_track_holder, "好感轨道")
	if not (track_v is ColorRect):
		push_error("UI node type mismatch: 好感轨道")
		return
	var track: ColorRect = track_v as ColorRect
	track.anchor_left = 0.5
	track.anchor_right = 0.5
	track.anchor_top = 0.0
	track.anchor_bottom = 1.0
	track.offset_left = -9
	track.offset_right = 9
	track.color = Color(0.06, 0.06, 0.06, 1.0)

	var love_fill_v: Node = _require_ui_node(love_track_holder, "好感填充")
	if not (love_fill_v is ColorRect):
		push_error("UI node type mismatch: 好感填充")
		return
	love_fill = love_fill_v as ColorRect
	love_fill.anchor_left = 0.5
	love_fill.anchor_right = 0.5
	love_fill.anchor_top = 1.0
	love_fill.anchor_bottom = 1.0
	love_fill.offset_left = -9
	love_fill.offset_right = 9
	love_fill.offset_top = 0
	love_fill.offset_bottom = 0
	love_fill.color = Color(1.0, 0.55, 0.72, 1.0)

	var love_percent_v: Node = _require_ui_node(love_box, "好感百分比标签")
	if not (love_percent_v is Label):
		push_error("UI node type mismatch: 好感百分比标签")
		return
	love_percent_label = love_percent_v as Label
	love_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	love_percent_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_apply_font(love_percent_label, 13)

	var dialogue_panel_v: Node = _require_ui_node(root, "对话面板")
	if not (dialogue_panel_v is PanelContainer):
		push_error("UI node type mismatch: 对话面板")
		return
	dialogue_panel_ref = dialogue_panel_v as PanelContainer
	if not use_scene_tree_layout:
		dialogue_panel_ref.anchor_left = 0.0
		dialogue_panel_ref.anchor_top = 1.0
		dialogue_panel_ref.anchor_right = 1.0
		dialogue_panel_ref.anchor_bottom = 1.0
		dialogue_panel_ref.offset_left = 18
		dialogue_panel_ref.offset_top = -300
		dialogue_panel_ref.offset_right = -18
		dialogue_panel_ref.offset_bottom = -16
	dialogue_panel_ref.self_modulate = Color(1.0, 1.0, 1.0, 0.96)
	dialogue_panel_ref.add_theme_stylebox_override(
		"panel",
		_make_flat_style(
			Color(0.02, 0.02, 0.02, 0.92),
			Color(0.0, 0.0, 0.0, 0.0),
			0,
			12,
			8,
			8,
			8,
			8
		)
	)

	var dialogue_overlay_v: Node = _require_ui_node(dialogue_panel_ref, "对话覆盖层")
	if not (dialogue_overlay_v is Control):
		push_error("UI node type mismatch: 对话覆盖层")
		return
	var dialogue_overlay: Control = dialogue_overlay_v as Control
	dialogue_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_overlay.mouse_filter = Control.MOUSE_FILTER_PASS

	var speaker_v: Node = _require_ui_node(dialogue_overlay, "说话人标签")
	if not (speaker_v is Label):
		push_error("UI node type mismatch: 说话人标签")
		return
	speaker_label = speaker_v as Label
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.93))
	speaker_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03, 0.95))
	speaker_label.add_theme_constant_override("outline_size", 2)
	_apply_font(speaker_label, 18, "dialogue")

	var dialogue_label_v: Node = _require_ui_node(dialogue_overlay, "对话文本")
	if not (dialogue_label_v is Label):
		push_error("UI node type mismatch: 对话文本")
		return
	dialogue_label = dialogue_label_v as Label
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialogue_label.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	dialogue_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.95))
	dialogue_label.add_theme_constant_override("outline_size", 2)
	_apply_font(dialogue_label, 27, "dialogue")

	var prompt_v: Node = _require_ui_node(dialogue_overlay, "输入提示标签")
	if not (prompt_v is Label):
		push_error("UI node type mismatch: 输入提示标签")
		return
	chat_prompt_label = prompt_v as Label
	chat_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chat_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chat_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chat_prompt_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	chat_prompt_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.90))
	chat_prompt_label.add_theme_constant_override("outline_size", 1)
	chat_prompt_label.text = ""
	_apply_font(chat_prompt_label, 22, "dialogue")
	chat_prompt_label.visible = false

	var choices_v: Node = root.get_node_or_null("舞台选项盒")
	if choices_v == null:
		# Backward-compat fallback for older scene trees.
		choices_v = dialogue_overlay.get_node_or_null("ChoicesBox")
	if not (choices_v is VBoxContainer):
		push_error("UI node type mismatch: 舞台选项盒/ChoicesBox")
		return
	choices_box = choices_v as VBoxContainer
	choices_box.visible = false
	choices_box.add_theme_constant_override("separation", 12)

	var input_panel_v: Node = _require_ui_node(dialogue_overlay, "输入框面板")
	if not (input_panel_v is PanelContainer):
		push_error("UI node type mismatch: 输入框面板")
		return
	input_row_margin_ref = input_panel_v as Control
	var input_field_panel: PanelContainer = input_panel_v as PanelContainer
	input_field_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Force a single visible input frame from the scene tree panel.
	input_field_panel.add_theme_stylebox_override(
		"panel",
		_make_flat_style(Color(0.04, 0.04, 0.04, 0.96), Color(0.92, 0.92, 0.92, 0.22), 1, 3, 0, 0, 0, 0)
	)
	if ui_theme_v2 != null:
		input_field_panel.theme = ui_theme_v2
	input_field_panel.theme_type_variation = VAR_INPUT_PANEL

	var input_margin_v: Node = _require_ui_node(input_field_panel, "输入框边距")
	if not (input_margin_v is MarginContainer):
		push_error("UI node type mismatch: 输入框边距")
		return
	var input_field_margin: MarginContainer = input_margin_v as MarginContainer
	input_field_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_field_margin.add_theme_constant_override("margin_left", 12)
	input_field_margin.add_theme_constant_override("margin_top", 6)
	input_field_margin.add_theme_constant_override("margin_right", 12)
	input_field_margin.add_theme_constant_override("margin_bottom", 6)

	var input_line_v: Node = _require_ui_node(input_field_margin, "输入框")
	if not (input_line_v is LineEdit):
		push_error("UI node type mismatch: 输入框")
		return
	input_line = input_line_v as LineEdit
	input_line.placeholder_text = ""
	input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var input_line_style: StyleBoxFlat = _make_flat_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0, 0, 0)
	input_line.add_theme_stylebox_override("normal", input_line_style)
	input_line.add_theme_stylebox_override("focus", input_line_style)
	input_line.add_theme_stylebox_override("read_only", input_line_style)
	input_line.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	input_line.add_theme_color_override("font_placeholder_color", Color(0.58, 0.58, 0.58))
	var input_gui_callable: Callable = Callable(self, "_on_input_gui_input")
	if not input_line.gui_input.is_connected(input_gui_callable):
		input_line.gui_input.connect(input_gui_callable)
	var input_change_callable: Callable = Callable(self, "_on_input_text_changed")
	if not input_line.text_changed.is_connected(input_change_callable):
		input_line.text_changed.connect(input_change_callable)
	var input_submit_callable: Callable = Callable(self, "_on_input_submitted")
	if not input_line.text_submitted.is_connected(input_submit_callable):
		input_line.text_submitted.connect(input_submit_callable)
	if ui_theme_v2 != null:
		input_line.theme = ui_theme_v2
	input_line.theme_type_variation = VAR_INPUT_LINE

	var send_btn_v: Node = _require_ui_node(root, "发送按钮")
	if not (send_btn_v is Button):
		push_error("UI node type mismatch: 发送按钮")
		return
	send_button = send_btn_v as Button
	send_button.visible = false

	var room_btn_v: Node = _require_ui_node(root, "房间按钮")
	if not (room_btn_v is Button):
		push_error("UI node type mismatch: 房间按钮")
		return
	room_button = room_btn_v as Button
	room_button.visible = false
	var room_btn_callable: Callable = Callable(self, "_on_room_button_pressed")
	if not room_button.pressed.is_connected(room_btn_callable):
		room_button.pressed.connect(room_btn_callable)

	var play_game_btn_v: Node = _require_ui_node(root, "玩游戏按钮")
	if not (play_game_btn_v is Button):
		push_error("UI node type mismatch: 玩游戏按钮")
		return
	play_game_button = play_game_btn_v as Button
	play_game_button.flat = false
	if ui_theme_v2 != null:
		play_game_button.theme = ui_theme_v2
	play_game_button.theme_type_variation = VAR_END_TURN_BUTTON
	_apply_font(play_game_button, 22)
	_bind_hover_feedback(play_game_button, Color(1.05, 1.05, 1.05, 1.0), 0.09)
	var play_game_callable: Callable = Callable(self, "_on_play_game_button_pressed")
	if not play_game_button.pressed.is_connected(play_game_callable):
		play_game_button.pressed.connect(play_game_callable)

	var next_btn_v: Node = _require_ui_node(root, "继续按钮")
	if not (next_btn_v is Button):
		push_error("UI node type mismatch: 继续按钮")
		return
	next_button = next_btn_v as Button
	next_button.visible = false

	var web_btn_v: Node = _require_ui_node(root, "联网切换按钮")
	if not (web_btn_v is Button):
		push_error("UI node type mismatch: 联网切换按钮")
		return
	web_toggle_button = web_btn_v as Button
	web_toggle_button.flat = true
	if ui_theme_v2 != null:
		web_toggle_button.theme = ui_theme_v2
	web_toggle_button.theme_type_variation = VAR_WEB_BUTTON
	_apply_font(web_toggle_button, 17)
	_bind_hover_feedback(web_toggle_button, Color(1.05, 1.05, 1.05, 1.0), 0.09)
	var web_pressed_callable: Callable = Callable(self, "_on_web_toggle_pressed")
	if not web_toggle_button.pressed.is_connected(web_pressed_callable):
		web_toggle_button.pressed.connect(web_pressed_callable)

	var end_btn_v: Node = _require_ui_node(root, "结束互动按钮")
	if not (end_btn_v is Button):
		push_error("UI node type mismatch: 结束互动按钮")
		return
	end_turn_button = end_btn_v as Button
	end_turn_button.flat = false
	if ui_theme_v2 != null:
		end_turn_button.theme = ui_theme_v2
	end_turn_button.theme_type_variation = VAR_END_TURN_BUTTON
	_apply_font(end_turn_button, 22)
	_bind_hover_feedback(end_turn_button, Color(1.05, 1.05, 1.05, 1.0), 0.09)
	var end_turn_callable: Callable = Callable(self, "_on_end_turn_pressed")
	if not end_turn_button.pressed.is_connected(end_turn_callable):
		end_turn_button.pressed.connect(end_turn_callable)

	var blackjack_panel_v: Node = _require_ui_node(root, "二十一点面板")
	if not (blackjack_panel_v is PanelContainer):
		push_error("UI node type mismatch: 二十一点面板")
		return
	blackjack_panel = blackjack_panel_v as PanelContainer
	blackjack_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackjack_panel.offset_left = 0.0
	blackjack_panel.offset_top = 0.0
	blackjack_panel.offset_right = 0.0
	blackjack_panel.offset_bottom = 0.0
	blackjack_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	blackjack_panel.self_modulate = Color(1.0, 1.0, 1.0, 0.98)
	blackjack_panel.add_theme_stylebox_override(
		"panel",
		_make_flat_style(
			Color(0.00, 0.00, 0.00, 1.00),
			Color(0.00, 0.00, 0.00, 0.00),
			0,
			0,
			0,
			0,
			0,
			0
		)
	)
	var blackjack_rules_btn_v: Node = root.get_node_or_null("二十一点规则按钮")
	if blackjack_rules_btn_v == null:
		blackjack_rules_btn_v = blackjack_panel.get_node_or_null("二十一点规则按钮")
	if blackjack_rules_btn_v is Button:
		blackjack_rules_button = blackjack_rules_btn_v as Button
	else:
		blackjack_rules_button = Button.new()
		blackjack_rules_button.name = "二十一点规则按钮"
		root.add_child(blackjack_rules_button)
	if blackjack_rules_button.get_parent() != root:
		blackjack_rules_button.reparent(root)
	blackjack_rules_button.anchor_left = 0.0
	blackjack_rules_button.anchor_top = 1.0
	blackjack_rules_button.anchor_right = 0.0
	blackjack_rules_button.anchor_bottom = 1.0
	blackjack_rules_button.offset_left = 24.0
	blackjack_rules_button.offset_top = -70.0
	blackjack_rules_button.offset_right = 186.0
	blackjack_rules_button.offset_bottom = -24.0
	blackjack_rules_button.text = "规则说明"
	blackjack_rules_button.visible = false
	blackjack_rules_button.z_index = 27
	blackjack_rules_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_compact_menu_button(blackjack_rules_button, 20)
	var blackjack_rules_btn_callable: Callable = Callable(self, "_on_blackjack_rules_button_pressed")
	if not blackjack_rules_button.pressed.is_connected(blackjack_rules_btn_callable):
		blackjack_rules_button.pressed.connect(blackjack_rules_btn_callable)
	var blackjack_rules_panel_v: Node = root.get_node_or_null("二十一点规则面板")
	if blackjack_rules_panel_v == null:
		blackjack_rules_panel_v = blackjack_panel.get_node_or_null("二十一点规则面板")
	if blackjack_rules_panel_v is PanelContainer:
		blackjack_rules_panel = blackjack_rules_panel_v as PanelContainer
	else:
		blackjack_rules_panel = PanelContainer.new()
		blackjack_rules_panel.name = "二十一点规则面板"
		root.add_child(blackjack_rules_panel)
	if blackjack_rules_panel.get_parent() != root:
		blackjack_rules_panel.reparent(root)
	blackjack_rules_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackjack_rules_panel.anchor_left = 1.0
	blackjack_rules_panel.anchor_top = 1.0
	blackjack_rules_panel.anchor_right = 1.0
	blackjack_rules_panel.anchor_bottom = 1.0
	blackjack_rules_panel.offset_left = -430.0
	blackjack_rules_panel.offset_top = -246.0
	blackjack_rules_panel.offset_right = -24.0
	blackjack_rules_panel.offset_bottom = -24.0
	blackjack_rules_panel.visible = false
	blackjack_rules_panel.z_index = 26
	blackjack_rules_panel.add_theme_stylebox_override(
		"panel",
		_make_flat_style(
			Color(0.02, 0.03, 0.04, 0.74),
			Color(0.95, 0.93, 0.86, 0.58),
			1,
			12,
			14,
			12,
			14,
			12
		)
	)
	var blackjack_rules_label_v: Node = blackjack_rules_panel.get_node_or_null("二十一点规则文本")
	if blackjack_rules_label_v is Label:
		blackjack_rules_label = blackjack_rules_label_v as Label
	else:
		blackjack_rules_label = Label.new()
		blackjack_rules_label.name = "二十一点规则文本"
		blackjack_rules_panel.add_child(blackjack_rules_label)
	blackjack_rules_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackjack_rules_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackjack_rules_label.offset_left = 0.0
	blackjack_rules_label.offset_top = 0.0
	blackjack_rules_label.offset_right = 0.0
	blackjack_rules_label.offset_bottom = 0.0
	blackjack_rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	blackjack_rules_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	blackjack_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blackjack_rules_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90, 0.98))
	blackjack_rules_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.56))
	blackjack_rules_label.add_theme_constant_override("outline_size", 1)
	blackjack_rules_label.add_theme_constant_override("line_spacing", 3)
	blackjack_rules_label.text = "21点规则说明\n1. 目标接近 21，超过 21 立即爆牌判负。\n2. 2-10 按面值；J/Q/K=10；A 自动按 1 或 11 取最优。\n3. 要牌=再拿一张；停牌=结束本回合。\n4. 庄家点数小于 17 必补牌，大于等于 17 停牌。\n5. 同点为平局；两张 21 点按 1.5 倍结算。"
	_apply_font(blackjack_rules_label, 18)
	_ensure_blackjack_table_surface(blackjack_panel)
	blackjack_panel.visible = false

	var deck_area_v: Node = _require_ui_node(blackjack_panel, "发牌堆区")
	if not (deck_area_v is Control):
		push_error("UI node type mismatch: 发牌堆区")
		return
	blackjack_deck_area = deck_area_v as Control
	blackjack_deck_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackjack_deck_area.set_as_top_level(true)
	blackjack_deck_area.anchor_left = 1.0
	blackjack_deck_area.anchor_top = 0.5
	blackjack_deck_area.anchor_right = 1.0
	blackjack_deck_area.anchor_bottom = 0.5
	blackjack_deck_area.offset_left = -420.0
	blackjack_deck_area.offset_top = -236.0
	blackjack_deck_area.offset_right = -24.0
	blackjack_deck_area.offset_bottom = 236.0
	blackjack_deck_area.add_theme_stylebox_override(
		"panel",
		_make_flat_style(
			Color(0.00, 0.00, 0.00, 0.00),
			Color(0.90, 0.90, 0.90, 0.00),
			0,
			16,
			8,
			8,
			8,
			8
		)
	)

	var deck_title_v: Node = _require_ui_node(blackjack_deck_area, "发牌堆标题")
	if deck_title_v is Label:
		var deck_title: Label = deck_title_v as Label
		deck_title.text = ""
		deck_title.visible = false

	var deck_stack_v: Node = _require_ui_node(blackjack_deck_area, "发牌堆卡片层")
	if not (deck_stack_v is Control):
		push_error("UI node type mismatch: 发牌堆卡片层")
		return
	blackjack_deck_stack_layer = deck_stack_v as Control
	blackjack_deck_stack_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackjack_deck_stack_layer.set_as_top_level(true)
	blackjack_deck_stack_layer.anchor_left = 0.0
	blackjack_deck_stack_layer.anchor_top = 0.5
	blackjack_deck_stack_layer.anchor_right = 0.0
	blackjack_deck_stack_layer.anchor_bottom = 0.5
	blackjack_deck_stack_layer.offset_left = 18.0
	blackjack_deck_stack_layer.offset_top = -118.0
	blackjack_deck_stack_layer.offset_right = 190.0
	blackjack_deck_stack_layer.offset_bottom = 118.0

	var discard_stack_v: Node = blackjack_deck_area.get_node_or_null("弃牌堆卡片层")
	if discard_stack_v == null:
		var discard_stack_new: Control = Control.new()
		discard_stack_new.name = "弃牌堆卡片层"
		discard_stack_new.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blackjack_deck_area.add_child(discard_stack_new)
		discard_stack_v = discard_stack_new
	if not (discard_stack_v is Control):
		push_error("UI node type mismatch: 弃牌堆卡片层")
		return
	blackjack_discard_stack_layer = discard_stack_v as Control
	blackjack_discard_stack_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackjack_discard_stack_layer.set_as_top_level(true)
	blackjack_discard_stack_layer.anchor_left = 1.0
	blackjack_discard_stack_layer.anchor_top = 0.5
	blackjack_discard_stack_layer.anchor_right = 1.0
	blackjack_discard_stack_layer.anchor_bottom = 0.5
	blackjack_discard_stack_layer.offset_left = -190.0
	blackjack_discard_stack_layer.offset_top = -118.0
	blackjack_discard_stack_layer.offset_right = -18.0
	blackjack_discard_stack_layer.offset_bottom = 118.0

	var deck_count_v: Node = _require_ui_node(blackjack_deck_area, "发牌堆剩余")
	if not (deck_count_v is Label):
		push_error("UI node type mismatch: 发牌堆剩余")
		return
	blackjack_deck_count_label = deck_count_v as Label
	blackjack_deck_count_label.anchor_top = 1.0
	blackjack_deck_count_label.anchor_right = 1.0
	blackjack_deck_count_label.anchor_bottom = 1.0
	blackjack_deck_count_label.offset_top = -42.0
	blackjack_deck_count_label.offset_bottom = -8.0
	blackjack_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	blackjack_deck_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blackjack_deck_count_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	blackjack_deck_count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	blackjack_deck_count_label.add_theme_constant_override("outline_size", 1)
	_apply_font(blackjack_deck_count_label, 20)

	var draw_particles_v: Node = _require_ui_node(blackjack_panel, "发牌粒子特效")
	if not (draw_particles_v is GPUParticles2D):
		push_error("UI node type mismatch: 发牌粒子特效")
		return
	blackjack_draw_particles = draw_particles_v as GPUParticles2D
	blackjack_draw_particles.visible = true
	blackjack_draw_particles.z_index = 30

	var result_particles_v: Node = _require_ui_node(blackjack_panel, "结算粒子特效")
	if not (result_particles_v is GPUParticles2D):
		push_error("UI node type mismatch: 结算粒子特效")
		return
	blackjack_result_particles = result_particles_v as GPUParticles2D
	blackjack_result_particles.visible = true
	blackjack_result_particles.z_index = 31
	_configure_blackjack_particle_nodes()

	var blackjack_margin_v: Node = _require_ui_node(blackjack_panel, "二十一点边距")
	if not (blackjack_margin_v is MarginContainer):
		push_error("UI node type mismatch: 二十一点边距")
		return
	var blackjack_margin: MarginContainer = blackjack_margin_v as MarginContainer
	blackjack_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackjack_margin.add_theme_constant_override("margin_left", 150)
	blackjack_margin.add_theme_constant_override("margin_top", 58)
	blackjack_margin.add_theme_constant_override("margin_right", 150)
	blackjack_margin.add_theme_constant_override("margin_bottom", 58)

	var blackjack_box_v: Node = _require_ui_node(blackjack_margin, "二十一点列")
	if not (blackjack_box_v is VBoxContainer):
		push_error("UI node type mismatch: 二十一点列")
		return
	var blackjack_box: VBoxContainer = blackjack_box_v as VBoxContainer
	blackjack_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackjack_box.add_theme_constant_override("separation", 12)

	var blackjack_title_v: Node = _require_ui_node(blackjack_box, "二十一点标题")
	if not (blackjack_title_v is Label):
		push_error("UI node type mismatch: 二十一点标题")
		return
	var blackjack_title: Label = blackjack_title_v as Label
	blackjack_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blackjack_title.text = "二十一点"
	blackjack_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	blackjack_title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 0.78))
	blackjack_title.add_theme_constant_override("outline_size", 2)
	_apply_font(blackjack_title, 44, "title")

	var blackjack_status_v: Node = _require_ui_node(blackjack_box, "二十一点状态")
	if not (blackjack_status_v is Label):
		push_error("UI node type mismatch: 二十一点状态")
		return
	blackjack_status_label = blackjack_status_v as Label
	blackjack_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blackjack_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blackjack_status_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.82))
	blackjack_status_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.02, 0.76))
	blackjack_status_label.add_theme_constant_override("outline_size", 2)
	_apply_font(blackjack_status_label, 26)

	var dealer_label_v: Node = _require_ui_node(blackjack_box, "庄家标签")
	if not (dealer_label_v is Label):
		push_error("UI node type mismatch: 庄家标签")
		return
	blackjack_dealer_label = dealer_label_v as Label
	blackjack_dealer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blackjack_dealer_label.add_theme_color_override("font_color", Color(0.90, 0.96, 0.90))
	blackjack_dealer_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.02, 0.78))
	blackjack_dealer_label.add_theme_constant_override("outline_size", 2)
	_apply_font(blackjack_dealer_label, 28)

	var dealer_cards_v: Node = _require_ui_node(blackjack_box, "庄家手牌")
	if not (dealer_cards_v is Label):
		push_error("UI node type mismatch: 庄家手牌")
		return
	blackjack_dealer_cards_label = dealer_cards_v as Label
	blackjack_dealer_cards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blackjack_dealer_cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blackjack_dealer_cards_label.add_theme_color_override("font_color", Color(0.84, 0.84, 0.84))
	_apply_font(blackjack_dealer_cards_label, 22)

	var dealer_cards_area_v: Node = _require_ui_node(blackjack_box, "庄家卡面区")
	if not (dealer_cards_area_v is Control):
		push_error("UI node type mismatch: 庄家卡面区")
		return
	blackjack_dealer_cards_area = dealer_cards_area_v as Control
	blackjack_dealer_cards_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackjack_dealer_cards_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blackjack_dealer_cards_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blackjack_dealer_cards_area.custom_minimum_size = Vector2(0.0, 236.0)

	var player_label_v: Node = _require_ui_node(blackjack_box, "玩家标签")
	if not (player_label_v is Label):
		push_error("UI node type mismatch: 玩家标签")
		return
	blackjack_player_label = player_label_v as Label
	blackjack_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blackjack_player_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	blackjack_player_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.02, 0.78))
	blackjack_player_label.add_theme_constant_override("outline_size", 2)
	_apply_font(blackjack_player_label, 28)

	var trust_track_v: Node = _require_ui_node(blackjack_panel, "信任条轨道")
	if not (trust_track_v is Control):
		push_error("UI node type mismatch: 信任条轨道")
		return
	blackjack_trust_track = trust_track_v as Control
	blackjack_trust_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackjack_trust_track.custom_minimum_size = Vector2(120.0, 18.0)
	if blackjack_trust_track is Panel:
		var trust_track_panel: Panel = blackjack_trust_track as Panel
		trust_track_panel.clip_contents = true
		trust_track_panel.add_theme_stylebox_override(
			"panel",
			_make_flat_style(
				Color(0.02, 0.05, 0.06, 0.82),
				Color(0.93, 0.84, 0.62, 0.34),
				2,
				999,
				0,
				0,
				0,
				0
			)
		)

	var trust_fill_v: Node = _require_ui_node(blackjack_trust_track, "信任条填充")
	if not (trust_fill_v is Control):
		push_error("UI node type mismatch: 信任条填充")
		return
	blackjack_trust_fill = trust_fill_v as Control
	blackjack_trust_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if blackjack_trust_fill is Panel:
		var trust_fill_panel: Panel = blackjack_trust_fill as Panel
		trust_fill_panel.add_theme_stylebox_override(
			"panel",
			_make_flat_style(
				Color(1.0, 1.0, 1.0, 1.0),
				Color(0, 0, 0, 0),
				0,
				999,
				0,
				0,
				0,
				0
			)
		)
		trust_fill_panel.self_modulate = Color(0.90, 0.72, 0.42, 0.96)
	elif blackjack_trust_fill is ColorRect:
		var trust_fill_rect: ColorRect = blackjack_trust_fill as ColorRect
		trust_fill_rect.color = Color(0.90, 0.72, 0.42, 0.96)

	var trust_text_v: Node = blackjack_panel.get_node_or_null("信任度标签")
	if trust_text_v is Label:
		blackjack_trust_text_label = trust_text_v as Label
	else:
		blackjack_trust_text_label = Label.new()
		blackjack_trust_text_label.name = "信任度标签"
		blackjack_panel.add_child(blackjack_trust_text_label)
	blackjack_trust_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackjack_trust_text_label.text = "信任度"
	blackjack_trust_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	blackjack_trust_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blackjack_trust_text_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.80))
	blackjack_trust_text_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.02, 0.78))
	blackjack_trust_text_label.add_theme_constant_override("outline_size", 1)
	_apply_font(blackjack_trust_text_label, 18)

	var balance_label_v: Node = blackjack_panel.get_node_or_null("二十一点余额标签")
	if balance_label_v is Label:
		blackjack_balance_label = balance_label_v as Label
	else:
		blackjack_balance_label = Label.new()
		blackjack_balance_label.name = "二十一点余额标签"
		blackjack_panel.add_child(blackjack_balance_label)
	blackjack_balance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackjack_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	blackjack_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blackjack_balance_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	blackjack_balance_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.02, 0.82))
	blackjack_balance_label.add_theme_constant_override("outline_size", 2)
	_apply_font(blackjack_balance_label, 24)

	var player_cards_v: Node = _require_ui_node(blackjack_box, "玩家手牌")
	if not (player_cards_v is Label):
		push_error("UI node type mismatch: 玩家手牌")
		return
	blackjack_player_cards_label = player_cards_v as Label
	blackjack_player_cards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blackjack_player_cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blackjack_player_cards_label.add_theme_color_override("font_color", Color(0.84, 0.84, 0.84))
	_apply_font(blackjack_player_cards_label, 22)

	var player_cards_area_v: Node = _require_ui_node(blackjack_box, "玩家卡面区")
	if not (player_cards_area_v is Control):
		push_error("UI node type mismatch: 玩家卡面区")
		return
	blackjack_player_cards_area = player_cards_area_v as Control
	blackjack_player_cards_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackjack_player_cards_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blackjack_player_cards_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blackjack_player_cards_area.custom_minimum_size = Vector2(0.0, 236.0)

	var blackjack_input_panel_v: Node = _require_ui_node(blackjack_box, "二十一点输入面板")
	if not (blackjack_input_panel_v is PanelContainer):
		push_error("UI node type mismatch: 二十一点输入面板")
		return
	blackjack_input_panel = blackjack_input_panel_v as PanelContainer
	blackjack_input_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blackjack_input_panel.custom_minimum_size = Vector2(0.0, 58.0)
	blackjack_input_panel.add_theme_stylebox_override(
		"panel",
		_make_flat_style(
			Color(0.02, 0.05, 0.05, 0.84),
			Color(0.98, 0.88, 0.60, 0.26),
			1,
			14,
			10,
			10,
			10,
			10
		)
	)

	var blackjack_input_margin_v: Node = _require_ui_node(blackjack_input_panel, "二十一点输入边距")
	if not (blackjack_input_margin_v is MarginContainer):
		push_error("UI node type mismatch: 二十一点输入边距")
		return
	var blackjack_input_margin: MarginContainer = blackjack_input_margin_v as MarginContainer
	blackjack_input_margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	var blackjack_input_line_v: Node = _require_ui_node(blackjack_input_margin, "二十一点输入框")
	if not (blackjack_input_line_v is LineEdit):
		push_error("UI node type mismatch: 二十一点输入框")
		return
	blackjack_input_line = blackjack_input_line_v as LineEdit
	blackjack_input_line.placeholder_text = "试着套妹妹的底牌……"
	blackjack_input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var blackjack_input_style: StyleBoxFlat = _make_flat_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0, 0, 0)
	blackjack_input_line.add_theme_stylebox_override("normal", blackjack_input_style)
	blackjack_input_line.add_theme_stylebox_override("focus", blackjack_input_style)
	blackjack_input_line.add_theme_stylebox_override("read_only", blackjack_input_style)
	blackjack_input_line.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	blackjack_input_line.add_theme_color_override("font_placeholder_color", Color(0.66, 0.66, 0.66))
	_apply_font(blackjack_input_line, 24)
	var blackjack_input_gui_callable: Callable = Callable(self, "_on_blackjack_input_gui_input")
	if not blackjack_input_line.gui_input.is_connected(blackjack_input_gui_callable):
		blackjack_input_line.gui_input.connect(blackjack_input_gui_callable)
	var blackjack_input_change_callable: Callable = Callable(self, "_on_blackjack_input_text_changed")
	if not blackjack_input_line.text_changed.is_connected(blackjack_input_change_callable):
		blackjack_input_line.text_changed.connect(blackjack_input_change_callable)
	var blackjack_input_submit_callable: Callable = Callable(self, "_on_blackjack_input_submitted")
	if not blackjack_input_line.text_submitted.is_connected(blackjack_input_submit_callable):
		blackjack_input_line.text_submitted.connect(blackjack_input_submit_callable)
	if ui_theme_v2 != null:
		blackjack_input_line.theme = ui_theme_v2
	blackjack_input_line.theme_type_variation = VAR_INPUT_LINE

	var blackjack_actions_v: Node = _require_ui_node(blackjack_box, "二十一点按钮行")
	if not (blackjack_actions_v is HBoxContainer):
		push_error("UI node type mismatch: 二十一点按钮行")
		return
	var blackjack_actions: HBoxContainer = blackjack_actions_v as HBoxContainer
	blackjack_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	blackjack_actions.add_theme_constant_override("separation", 20)
	_ensure_blackjack_bet_ui(blackjack_box, blackjack_actions)

	var hit_btn_v: Node = _require_ui_node(blackjack_actions, "要牌按钮")
	if not (hit_btn_v is Button):
		push_error("UI node type mismatch: 要牌按钮")
		return
	blackjack_hit_button = hit_btn_v as Button
	_style_compact_menu_button(blackjack_hit_button, 22)
	blackjack_hit_button.custom_minimum_size = Vector2(210.0, 58.0)
	var hit_callable: Callable = Callable(self, "_on_blackjack_hit_pressed")
	if not blackjack_hit_button.pressed.is_connected(hit_callable):
		blackjack_hit_button.pressed.connect(hit_callable)

	var stand_btn_v: Node = _require_ui_node(blackjack_actions, "停牌按钮")
	if not (stand_btn_v is Button):
		push_error("UI node type mismatch: 停牌按钮")
		return
	blackjack_stand_button = stand_btn_v as Button
	_style_compact_menu_button(blackjack_stand_button, 22)
	blackjack_stand_button.custom_minimum_size = Vector2(210.0, 58.0)
	var stand_callable: Callable = Callable(self, "_on_blackjack_stand_pressed")
	if not blackjack_stand_button.pressed.is_connected(stand_callable):
		blackjack_stand_button.pressed.connect(stand_callable)

	var new_round_btn_v: Node = _require_ui_node(blackjack_actions, "新一局按钮")
	if not (new_round_btn_v is Button):
		push_error("UI node type mismatch: 新一局按钮")
		return
	blackjack_new_round_button = new_round_btn_v as Button
	_style_compact_menu_button(blackjack_new_round_button, 22)
	blackjack_new_round_button.custom_minimum_size = Vector2(210.0, 58.0)
	var new_round_callable: Callable = Callable(self, "_on_blackjack_new_round_pressed")
	if not blackjack_new_round_button.pressed.is_connected(new_round_callable):
		blackjack_new_round_button.pressed.connect(new_round_callable)

	var close_btn_v: Node = _require_ui_node(blackjack_actions, "结束牌局按钮")
	if not (close_btn_v is Button):
		push_error("UI node type mismatch: 结束牌局按钮")
		return
	blackjack_close_button = close_btn_v as Button
	_style_compact_menu_button(blackjack_close_button, 22)
	blackjack_close_button.custom_minimum_size = Vector2(210.0, 58.0)
	var close_callable: Callable = Callable(self, "_on_blackjack_close_pressed")
	if not blackjack_close_button.pressed.is_connected(close_callable):
		blackjack_close_button.pressed.connect(close_callable)

	var quick_box_v: Node = _require_ui_node(root, "快捷菜单盒")
	if not (quick_box_v is HBoxContainer):
		push_error("UI node type mismatch: 快捷菜单盒")
		return
	quick_menu_box = quick_box_v as HBoxContainer
	quick_menu_box.add_theme_constant_override("separation", 18)
	quick_menu_buttons.clear()
	var quick_defs: Array[Dictionary] = [
		{"name": "快捷回退", "k": "rollback", "label": "回退"},
		{"name": "快捷历史", "k": "history", "label": "历史"},
		{"name": "快捷快进", "k": "skip", "label": "快进"},
		{"name": "快捷自动", "k": "auto", "label": "自动"},
		{"name": "快捷保存", "k": "save", "label": "保存"},
		{"name": "快捷快存", "k": "qsave", "label": "快存"},
		{"name": "快捷快读", "k": "qload", "label": "快读"},
		{"name": "快捷设置", "k": "prefs", "label": "设置"}
	]
	for def in quick_defs:
		var node_name: String = String(def.get("name", ""))
		var key: String = String(def.get("k", ""))
		var caption: String = String(def.get("label", ""))
		var quick_btn_v: Node = _require_ui_node(quick_menu_box, node_name)
		if not (quick_btn_v is Button):
			push_error("UI node type mismatch: %s" % node_name)
			return
		var quick_btn: Button = quick_btn_v as Button
		quick_btn.text = caption
		quick_btn.flat = true
		quick_btn.focus_mode = Control.FOCUS_NONE
		if ui_theme_v2 != null:
			quick_btn.theme = ui_theme_v2
		quick_btn.theme_type_variation = VAR_QUICK_BUTTON
		_apply_font(quick_btn, 16)
		_bind_hover_feedback(quick_btn, Color(1.06, 1.06, 1.06, 1.0), 0.09)
		var quick_callable: Callable = Callable(self, "_on_quick_menu_pressed").bind(key)
		if not quick_btn.pressed.is_connected(quick_callable):
			quick_btn.pressed.connect(quick_callable)
		quick_menu_buttons[key] = quick_btn

	var waiting_label_v: Node = _require_ui_node(root, "思考提示标签")
	if not (waiting_label_v is Label):
		push_error("UI node type mismatch: 思考提示标签")
		return
	ai_waiting_label = waiting_label_v as Label
	ai_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai_waiting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ai_waiting_label.add_theme_color_override("font_color", Color(0.76, 0.76, 0.76))
	ai_waiting_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
	ai_waiting_label.add_theme_constant_override("outline_size", 1)
	_apply_font(ai_waiting_label, 24)
	ai_waiting_label.visible = false

	var overlay_v: Node = _require_ui_node(root, "菜单遮罩")
	if not (overlay_v is ColorRect):
		push_error("UI node type mismatch: 菜单遮罩")
		return
	menu_overlay_mask = overlay_v as ColorRect
	menu_overlay_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_overlay_mask.color = Color(0, 0, 0, 0.45)
	menu_overlay_mask.visible = false
	menu_overlay_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	var menu_overlay_callable: Callable = Callable(self, "_on_menu_overlay_input")
	if not menu_overlay_mask.gui_input.is_connected(menu_overlay_callable):
		menu_overlay_mask.gui_input.connect(menu_overlay_callable)

	if has_method("_build_game_menu_ui"):
		call("_build_game_menu_ui", root)

	var room_mask_v: Node = _require_ui_node(root, "房间导航遮罩")
	if not (room_mask_v is ColorRect):
		push_error("UI node type mismatch: 房间导航遮罩")
		return
	room_nav_mask = room_mask_v as ColorRect
	room_nav_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	room_nav_mask.color = Color(0, 0, 0, 0.001)
	room_nav_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	room_nav_mask.visible = false
	var room_nav_mask_callable: Callable = Callable(self, "_on_room_nav_mask_input")
	if not room_nav_mask.gui_input.is_connected(room_nav_mask_callable):
		room_nav_mask.gui_input.connect(room_nav_mask_callable)

	var room_nav_btn_v: Node = _require_ui_node(root, "房间导航按钮")
	if not (room_nav_btn_v is Button):
		push_error("UI node type mismatch: 房间导航按钮")
		return
	room_nav_button = room_nav_btn_v as Button
	room_nav_button.text = "去其他房间"
	_style_room_button(room_nav_button, 19)
	var room_nav_btn_callable: Callable = Callable(self, "_on_room_nav_button_pressed")
	if not room_nav_button.pressed.is_connected(room_nav_btn_callable):
		room_nav_button.pressed.connect(room_nav_btn_callable)

	var call_victoria_btn_v: Node = _require_ui_node(root, "叫妹妹过来按钮")
	if not (call_victoria_btn_v is Button):
		push_error("UI node type mismatch: 叫妹妹过来按钮")
		return
	call_victoria_button = call_victoria_btn_v as Button
	call_victoria_button.text = "叫妹妹过来"
	_style_room_button(call_victoria_button, 19)
	var call_victoria_callable: Callable = Callable(self, "_on_call_victoria_button_pressed")
	if not call_victoria_button.pressed.is_connected(call_victoria_callable):
		call_victoria_button.pressed.connect(call_victoria_callable)

	var room_nav_panel_v: Node = _require_ui_node(root, "房间导航面板")
	if not (room_nav_panel_v is PanelContainer):
		push_error("UI node type mismatch: 房间导航面板")
		return
	room_nav_panel = room_nav_panel_v as PanelContainer
	room_nav_panel.self_modulate = Color(0.05, 0.05, 0.05, 0.94)
	room_nav_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.02, 0.02, 0.96)))
	room_nav_panel.visible = false

	var room_nav_margin_v: Node = _require_ui_node(room_nav_panel, "房间导航边距")
	if not (room_nav_margin_v is MarginContainer):
		push_error("UI node type mismatch: 房间导航边距")
		return
	var room_nav_margin: MarginContainer = room_nav_margin_v as MarginContainer
	room_nav_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	room_nav_margin.add_theme_constant_override("margin_left", 8)
	room_nav_margin.add_theme_constant_override("margin_top", 8)
	room_nav_margin.add_theme_constant_override("margin_right", 8)
	room_nav_margin.add_theme_constant_override("margin_bottom", 8)

	var room_nav_list_v: Node = _require_ui_node(room_nav_margin, "房间导航列表")
	if not (room_nav_list_v is VBoxContainer):
		push_error("UI node type mismatch: 房间导航列表")
		return
	room_nav_list = room_nav_list_v as VBoxContainer
	room_nav_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	room_nav_list.add_theme_constant_override("separation", 10)

	var debug_panel_v: Node = _require_ui_node(root, "调试面板")
	if not (debug_panel_v is PanelContainer):
		push_error("UI node type mismatch: 调试面板")
		return
	debug_panel = debug_panel_v as PanelContainer
	debug_panel.self_modulate = Color(0.05, 0.05, 0.05, 0.92)
	debug_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.02, 0.02, 0.96)))
	debug_panel.visible = DEBUG_UI_ENABLED and state.debug_panel_open

	var debug_margin_v: Node = _require_ui_node(debug_panel, "调试边距")
	if not (debug_margin_v is MarginContainer):
		push_error("UI node type mismatch: 调试边距")
		return
	var debug_margin: MarginContainer = debug_margin_v as MarginContainer
	debug_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_margin.add_theme_constant_override("margin_left", 12)
	debug_margin.add_theme_constant_override("margin_top", 10)
	debug_margin.add_theme_constant_override("margin_right", 12)
	debug_margin.add_theme_constant_override("margin_bottom", 10)

	var debug_label_v: Node = _require_ui_node(debug_margin, "调试标签")
	if not (debug_label_v is Label):
		push_error("UI node type mismatch: 调试标签")
		return
	debug_label = debug_label_v as Label
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_apply_font(debug_label, 13)
	debug_label.add_theme_color_override("font_color", Color(0.78, 0.95, 0.88))

	var notify_panel_v: Node = _require_ui_node(root, "提示面板")
	if not (notify_panel_v is PanelContainer):
		push_error("UI node type mismatch: 提示面板")
		return
	notify_panel = notify_panel_v as PanelContainer
	notify_panel.self_modulate = Color(0.02, 0.02, 0.02, 0.9)
	notify_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.02, 0.02, 0.9)))
	notify_panel.visible = false

	var notify_margin_v: Node = _require_ui_node(notify_panel, "提示边距")
	if not (notify_margin_v is MarginContainer):
		push_error("UI node type mismatch: 提示边距")
		return
	var notify_margin: MarginContainer = notify_margin_v as MarginContainer
	notify_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	notify_margin.add_theme_constant_override("margin_left", 12)
	notify_margin.add_theme_constant_override("margin_top", 8)
	notify_margin.add_theme_constant_override("margin_right", 12)
	notify_margin.add_theme_constant_override("margin_bottom", 8)

	var notify_label_v: Node = _require_ui_node(notify_margin, "提示标签")
	if not (notify_label_v is Label):
		push_error("UI node type mismatch: 提示标签")
		return
	notify_label = notify_label_v as Label
	notify_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notify_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notify_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	_apply_font(notify_label, 16)

	var notify_timer_v: Node = get_node_or_null("提示计时器")
	if not (notify_timer_v is Timer):
		push_error("Scene node missing: 提示计时器")
		return
	notify_timer = notify_timer_v as Timer
	notify_timer.one_shot = true
	var notify_timeout_callable: Callable = Callable(self, "_on_notify_timeout")
	if not notify_timer.timeout.is_connected(notify_timeout_callable):
		notify_timer.timeout.connect(notify_timeout_callable)

	var vp: Viewport = get_viewport()
	var vp_resize_callable: Callable = Callable(self, "_on_viewport_size_changed")
	if not vp.size_changed.is_connected(vp_resize_callable):
		vp.size_changed.connect(vp_resize_callable)

	_apply_ui_layout()
	_refresh_scaled_fonts(ui_root)
	_style_input_font(input_line.text)
	_refresh_quick_menu_captions()
	if has_method("_refresh_save_panel"):
		call("_refresh_save_panel")
	_refresh_room_nav_ui()
	_update_hud()

