extends "res://scripts/game/victoria_base.gd"

var texture_cache: Dictionary = {}
var failed_texture_paths: Dictionary = {}
var character_tone_material: ShaderMaterial
var ui_sfx_player: AudioStreamPlayer
var ui_hover_stream: AudioStream
var ui_click_stream: AudioStream
var blackjack_sfx_player: AudioStreamPlayer
var blackjack_deal_stream: AudioStream
var blackjack_bgm_stream: AudioStream
var ui_last_hover_tick_msec: int = -1000
const UI_HOVER_DEBOUNCE_MS := 70
const UI_HOVER_GAIN_OFFSET_DB := -11.0
const UI_CLICK_GAIN_OFFSET_DB := 2.8
const BLACKJACK_DEAL_SFX_PATH := "res://assets/audio/kp.wav"
const BLACKJACK_DEAL_GAIN_OFFSET_DB := -3.0
const BLACKJACK_BGM_PATH := "res://assets/audio/the_dealer_s_hour.mp3"

const CHARACTER_TONE_SHADER_CODE := """
shader_type canvas_item;

uniform vec3 tone_tint = vec3(1.0, 1.0, 1.0);
uniform float tone_brightness = 0.0;

vec3 linear_to_srgb(vec3 c) {
	bvec3 low = lessThanEqual(c, vec3(0.0031308));
	vec3 hi = vec3(1.055) * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - vec3(0.055);
	vec3 lo = c * vec3(12.92);
	return mix(hi, lo, vec3(low));
}

vec3 srgb_to_linear(vec3 c) {
	bvec3 low = lessThanEqual(c, vec3(0.04045));
	vec3 hi = pow(max((c + vec3(0.055)) / vec3(1.055), vec3(0.0)), vec3(2.4));
	vec3 lo = c / vec3(12.92);
	return mix(hi, lo, vec3(low));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	// Match Ren'Py matrixcolor in sRGB: TintMatrix * BrightnessMatrix.
	vec3 srgb = linear_to_srgb(c.rgb);
	srgb = clamp(srgb * tone_tint + vec3(tone_brightness) * tone_tint * c.aaa, 0.0, 1.0);
	c.rgb = srgb_to_linear(srgb);
	COLOR = c;
}
"""

func _load_audio() -> void:
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	if ResourceLoader.exists("res://assets/audio/footstep.ogg"):
		footstep_stream = load("res://assets/audio/footstep.ogg")
	if ResourceLoader.exists("res://assets/audio/ui_hover.wav"):
		ui_hover_stream = load("res://assets/audio/ui_hover.wav")
	elif ResourceLoader.exists("res://assets/audio/hover.wav"):
		ui_hover_stream = load("res://assets/audio/hover.wav")
	if ResourceLoader.exists("res://assets/audio/ui_click.wav"):
		ui_click_stream = load("res://assets/audio/ui_click.wav")
	elif ResourceLoader.exists("res://assets/audio/cilck.wav"):
		ui_click_stream = load("res://assets/audio/cilck.wav")
	elif ResourceLoader.exists("res://assets/audio/click.wav"):
		ui_click_stream = load("res://assets/audio/click.wav")

	ui_sfx_player = AudioStreamPlayer.new()
	add_child(ui_sfx_player)
	blackjack_sfx_player = AudioStreamPlayer.new()
	add_child(blackjack_sfx_player)
	if ResourceLoader.exists(BLACKJACK_DEAL_SFX_PATH):
		blackjack_deal_stream = load(BLACKJACK_DEAL_SFX_PATH)
	elif FileAccess.file_exists(BLACKJACK_DEAL_SFX_PATH):
		blackjack_deal_stream = AudioStreamWAV.load_from_file(BLACKJACK_DEAL_SFX_PATH)
	if ResourceLoader.exists(BLACKJACK_BGM_PATH):
		blackjack_bgm_stream = load(BLACKJACK_BGM_PATH)
	elif FileAccess.file_exists(BLACKJACK_BGM_PATH):
		blackjack_bgm_stream = AudioStreamMP3.load_from_file(BLACKJACK_BGM_PATH)

	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.volume_db = _bgm_target_db()
	music_player.finished.connect(_on_music_finished)

	ambience_player = AudioStreamPlayer.new()
	add_child(ambience_player)
	ambience_player.volume_db = _user_bgm_adjusted_db(_cicada_volume_for_current_time())
	ambience_player.finished.connect(_on_ambience_finished)
	_apply_audio_volume_preferences()


func _bgm_target_db() -> float:
	return lerpf(-45.0, -5.0, clampf(state.bgm_volume_percent / 100.0, 0.0, 1.0))


func _sfx_target_db() -> float:
	return lerpf(-40.0, 0.0, clampf(state.sfx_volume_percent / 100.0, 0.0, 1.0))


func _user_bgm_adjusted_db(base_db: float) -> float:
	var baseline_db: float = -12.0
	return clampf(base_db + (_bgm_target_db() - baseline_db), -50.0, 6.0)


func _apply_audio_volume_preferences() -> void:
	if music_player != null:
		music_player.volume_db = _bgm_target_db()
	if ambience_player != null:
		ambience_player.volume_db = _user_bgm_adjusted_db(_cicada_volume_for_current_time())
	if sfx_player != null:
		sfx_player.volume_db = _sfx_target_db()
	if ui_sfx_player != null:
		ui_sfx_player.volume_db = _sfx_target_db() - 2.0
	if blackjack_sfx_player != null:
		blackjack_sfx_player.volume_db = _sfx_target_db() + BLACKJACK_DEAL_GAIN_OFFSET_DB


func _play_ui_hover_sfx() -> void:
	if ui_sfx_player == null or ui_hover_stream == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - ui_last_hover_tick_msec < UI_HOVER_DEBOUNCE_MS:
		return
	ui_last_hover_tick_msec = now_ms
	ui_sfx_player.volume_db = _sfx_target_db() + UI_HOVER_GAIN_OFFSET_DB
	ui_sfx_player.pitch_scale = 0.90
	ui_sfx_player.stream = ui_hover_stream
	ui_sfx_player.play()


func _play_ui_click_sfx() -> void:
	if ui_sfx_player == null or ui_click_stream == null:
		return
	ui_sfx_player.volume_db = _sfx_target_db() + UI_CLICK_GAIN_OFFSET_DB
	ui_sfx_player.pitch_scale = 1.0
	ui_sfx_player.stream = ui_click_stream
	ui_sfx_player.play()


func _play_blackjack_deal_sfx() -> void:
	if blackjack_sfx_player == null or blackjack_deal_stream == null:
		return
	blackjack_sfx_player.volume_db = _sfx_target_db() + BLACKJACK_DEAL_GAIN_OFFSET_DB
	blackjack_sfx_player.pitch_scale = rng.randf_range(0.96, 1.04)
	blackjack_sfx_player.stream = blackjack_deal_stream
	blackjack_sfx_player.play()


func _expression_profile_for_reply(mood: String, cue: String, user_text: String, reply_text: String) -> Dictionary:
	var sprite_key: String = reply_parser.sprite_key_from_mood(mood, cue, user_text, reply_text)
	var normalized_cue: String = cue.strip_edges().to_lower()
	var profile: Dictionary = {
		"sprite": sprite_key,
		"zoom": 1.0,
		"yoffset": VictoriaSceneConfig.CHAR_BASE_YOFFSET,
		"alpha": 1.0
	}
	match normalized_cue:
		"shy_lang":
			profile["zoom"] = 1.03
			profile["yoffset"] = 334.0
		"shy_touch":
			profile["zoom"] = 1.05
			profile["yoffset"] = 328.0
		"worry":
			profile["zoom"] = 1.0
			profile["yoffset"] = 342.0
		"excite":
			profile["zoom"] = 1.02
			profile["yoffset"] = 336.0
		"tsun":
			profile["zoom"] = 1.01
			profile["yoffset"] = 338.0
		_:
			match sprite_key:
				"shy":
					profile["zoom"] = 1.03
					profile["yoffset"] = 334.0
				"shy2":
					profile["zoom"] = 1.05
					profile["yoffset"] = 328.0
				"cross":
					profile["zoom"] = 1.02
					profile["yoffset"] = 336.0
				"dislike":
					profile["zoom"] = 1.01
					profile["yoffset"] = 338.0
				"worry":
					profile["zoom"] = 1.0
					profile["yoffset"] = 342.0
	return profile


func _apply_character_expression(profile: Dictionary) -> void:
	var sprite_key: String = String(profile.get("sprite", "everyday"))
	var zoom: float = float(profile.get("zoom", 1.0))
	var yoffset: float = float(profile.get("yoffset", VictoriaSceneConfig.CHAR_BASE_YOFFSET))
	var alpha: float = clampf(float(profile.get("alpha", 1.0)), 0.0, 1.0)
	var mood_name: String = String(profile.get("mood", latest_mood)).strip_edges()
	if mood_name.is_empty():
		mood_name = latest_mood
	_set_character_key(sprite_key)
	character_rect.modulate = Color(1.0, 1.0, 1.0, alpha)
	_apply_character_time_tone()
	state.v_sprite_file = "%s.png" % sprite_key
	state.v_sprite_zoom = zoom
	state.v_sprite_yoffset = int(round(yoffset))
	state.v_sprite_alpha = alpha
	state.v_sprite_mood = mood_name
	state.v_reply_expression_profile = {
		"mood": mood_name,
		"sprite": sprite_key,
		"zoom": zoom,
		"yoffset": yoffset,
		"alpha": alpha
	}
	if has_method("_apply_ui_layout"):
		call("_apply_ui_layout")


func _period_music_for_current_time() -> String:
	var hour: int = int(state.current_cycle_seconds / 60) % 24
	if hour >= 6 and hour < 11:
		return String(VictoriaSceneConfig.PERIOD_MUSIC.get("morning", ""))
	if hour >= 11 and hour < 14:
		return String(VictoriaSceneConfig.PERIOD_MUSIC.get("noon", ""))
	if hour >= 14 and hour < 18:
		return String(VictoriaSceneConfig.PERIOD_MUSIC.get("afternoon", ""))
	return String(VictoriaSceneConfig.PERIOD_MUSIC.get("night", ""))


func _cicada_volume_for_current_time() -> float:
	var hour: int = int(state.current_cycle_seconds / 60)
	if hour >= 6 and hour < 11:
		return -20.0
	if hour >= 11 and hour < 14:
		return -14.0
	if hour >= 14 and hour < 18:
		return -12.0
	return -22.0


func _cicada_track() -> String:
	if ResourceLoader.exists(VictoriaSceneConfig.CICADA_PRIMARY):
		return VictoriaSceneConfig.CICADA_PRIMARY
	if ResourceLoader.exists(VictoriaSceneConfig.CICADA_FALLBACK):
		return VictoriaSceneConfig.CICADA_FALLBACK
	return ""


func _sync_period_music(fade: float = 0.5) -> void:
	if blackjack_active and blackjack_bgm_stream != null:
		var should_switch_blackjack: bool = current_music_path != BLACKJACK_BGM_PATH or music_player == null or not music_player.playing
		if music_player != null and should_switch_blackjack:
			music_player.stream = blackjack_bgm_stream
			music_player.play()
			music_player.volume_db = -45.0
		_fade_player_to(music_player, _bgm_target_db(), fade)
		current_music_path = BLACKJACK_BGM_PATH
		_fade_player_to(ambience_player, -50.0, fade)
		current_ambience_path = ""
		return

	var music_path: String = _period_music_for_current_time()
	_play_loop_track(music_player, music_path, current_music_path, _bgm_target_db(), fade, true)

	var cicada_path: String = _cicada_track()
	var target_db: float = _user_bgm_adjusted_db(_cicada_volume_for_current_time())
	if cicada_path.is_empty():
		_fade_player_to(ambience_player, -50.0, fade)
		current_ambience_path = ""
	else:
		_play_loop_track(ambience_player, cicada_path, current_ambience_path, target_db, fade, false)
		_fade_player_to(ambience_player, target_db, fade)


func _play_loop_track(player: AudioStreamPlayer, path: String, current_path: String, target_db: float, fade: float, save_to_music: bool) -> void:
	if player == null:
		return
	if path.is_empty() or not ResourceLoader.exists(path):
		return

	var should_switch: bool = path != current_path
	if should_switch or not player.playing:
		var stream: AudioStream = load(path)
		if stream == null:
			return
		player.stream = stream
		player.play()
		player.volume_db = -45.0

	_fade_player_to(player, target_db, fade)
	if save_to_music:
		current_music_path = path
	else:
		current_ambience_path = path


func _fade_player_to(player: AudioStreamPlayer, target_db: float, duration: float) -> void:
	if player == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, maxf(0.01, duration))


func _on_music_finished() -> void:
	if music_player == null:
		return
	if current_music_path == BLACKJACK_BGM_PATH and blackjack_bgm_stream != null:
		music_player.stream = blackjack_bgm_stream
		music_player.play()
		music_player.volume_db = _bgm_target_db()
		return
	if current_music_path.is_empty() or not ResourceLoader.exists(current_music_path):
		return
	music_player.stream = load(current_music_path)
	music_player.play()
	music_player.volume_db = _bgm_target_db()


func _on_ambience_finished() -> void:
	if ambience_player == null:
		return
	if current_ambience_path.is_empty() or not ResourceLoader.exists(current_ambience_path):
		return
	ambience_player.stream = load(current_ambience_path)
	ambience_player.play()
	ambience_player.volume_db = _user_bgm_adjusted_db(_cicada_volume_for_current_time())


func _fade_out_cicada(fade: float = 1.0) -> void:
	if ambience_player == null:
		return
	_fade_player_to(ambience_player, -50.0, fade)


func _play_footstep() -> void:
	if sfx_player == null or footstep_stream == null:
		return
	sfx_player.volume_db = _sfx_target_db()
	sfx_player.stream = footstep_stream
	sfx_player.play()


func _fade_to_black(duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1.0), duration)
	await tween.finished


func _fade_from_black(duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0.0), duration)
	await tween.finished


func _apply_scene_by_state() -> void:
	var room_map: Dictionary = VictoriaSceneConfig.ROOM_BG_KEYS.get(state.current_location, VictoriaSceneConfig.ROOM_BG_KEYS["sister_room"])
	var key: String = String(room_map.get(state.time_period_name, room_map.get("\u665a\u4e0a", "sister_room_night")))
	_set_background_key(key)
	_apply_character_time_tone()

func _set_background_key(background_key: String) -> void:
	var path: String = String(VictoriaSceneConfig.BG_TEXTURES.get(background_key, ""))
	if path.is_empty():
		background_rect.texture = null
		return
	var locked_bg_pos: Vector2 = background_rect.position
	var locked_bg_size: Vector2 = background_rect.size
	var texture: Texture2D = _load_texture_safe(path)
	if texture == null:
		for fallback_key in _background_fallback_candidates(background_key):
			var fallback_path: String = String(VictoriaSceneConfig.BG_TEXTURES.get(fallback_key, ""))
			if fallback_path.is_empty():
				continue
			texture = _load_texture_safe(fallback_path)
			if texture != null:
				break
	background_rect.texture = texture
	# Keep stage-framed background size from scene tree; assigning texture may force source size.
	if locked_bg_size.x > 0.0 and locked_bg_size.y > 0.0:
		background_rect.position = locked_bg_pos
		background_rect.size = locked_bg_size
	_apply_background_stretch_mode(background_key)


func _apply_background_stretch_mode(background_key: String) -> void:
	if background_rect == null:
		return
	# Kitchen/player_room source images are narrower than 16:9, so use covered to avoid side gaps.
	var covered: bool = (
		background_key.begins_with("living_room")
		or background_key.begins_with("kitchen")
		or background_key.begins_with("player_room")
	)
	if covered:
		background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _set_character_key(char_key: String) -> void:
	var key: String = char_key
	if not VictoriaSceneConfig.CHAR_TEXTURES.has(key):
		key = "everyday"
	var path: String = String(VictoriaSceneConfig.CHAR_TEXTURES.get(key, ""))
	if path.is_empty():
		character_rect.visible = false
		return
	var texture: Texture2D = _load_texture_safe(path)
	if texture == null:
		character_rect.visible = false
		return
	character_rect.texture = texture
	character_rect.scale = Vector2.ONE
	character_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	character_rect.visible = true
	_apply_character_time_tone()


func _set_character_by_mood(mood: String) -> void:
	var sprite_key: String = "everyday"
	match mood:
		"\u5bb3\u7f9e":
			sprite_key = "shy"
		"\u6fc0\u52a8":
			sprite_key = "cross"
		"\u6492\u5a07\u7684\u751f\u6c14":
			sprite_key = "dislike"
		"\u62c5\u5fe7", "\u6d88\u6781":
			sprite_key = "worry"
	_apply_character_expression({
		"mood": mood,
		"sprite": sprite_key,
		"zoom": 1.0,
		"yoffset": VictoriaSceneConfig.CHAR_BASE_YOFFSET,
		"alpha": 1.0
	})


func _ensure_character_tone_material() -> ShaderMaterial:
	if character_tone_material != null:
		return character_tone_material
	var shader := Shader.new()
	shader.code = CHARACTER_TONE_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	character_tone_material = material
	return character_tone_material


func _character_time_tone_profile() -> Dictionary:
	var hour: int = int(state.current_cycle_seconds / 60) % 24
	if hour >= 6 and hour < 11:
		return {"enabled": false}
	if hour >= 11 and hour < 14:
		return {"enabled": false}
	if hour >= 14 and hour < 18:
		# Afternoon: slightly warm.
		return {"enabled": true, "tint": Color("fff1df"), "brightness": 0.0}
	# Night: slightly cool.
	return {"enabled": true, "tint": Color("dbe5ff"), "brightness": -0.015}


func _apply_character_time_tone() -> void:
	if character_rect == null:
		return
	var tone: Dictionary = _character_time_tone_profile()
	if not bool(tone.get("enabled", false)):
		character_rect.material = null
		return
	var tint: Color = tone.get("tint", Color.WHITE)
	var brightness: float = float(tone.get("brightness", 0.0))
	var material: ShaderMaterial = _ensure_character_tone_material()
	material.set_shader_parameter("tone_tint", Vector3(tint.r, tint.g, tint.b))
	material.set_shader_parameter("tone_brightness", brightness)
	character_rect.material = material


func _load_texture_safe(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if failed_texture_paths.has(path):
		# Allow retrial for mislabeled *.png assets (some backgrounds are actually jpg data).
		if path.to_lower().ends_with(".png"):
			failed_texture_paths.erase(path)
		else:
			return null
	if texture_cache.has(path):
		var cached: Variant = texture_cache.get(path, null)
		if cached is Texture2D:
			return cached as Texture2D

	for candidate_path in _texture_path_candidates(path):
		var candidate_cached: Variant = texture_cache.get(candidate_path, null)
		if candidate_cached is Texture2D:
			texture_cache[path] = candidate_cached
			return candidate_cached as Texture2D

		var abs_path: String = ProjectSettings.globalize_path(candidate_path)
		var lower_path: String = candidate_path.to_lower()
		if FileAccess.file_exists(abs_path) and (lower_path.ends_with(".png") or lower_path.ends_with(".jpg") or lower_path.ends_with(".jpeg") or lower_path.ends_with(".webp")):
			if lower_path.ends_with(".png") and not _has_png_signature(abs_path):
				continue
			var image: Image = Image.load_from_file(abs_path)
			if image != null and not image.is_empty():
				var runtime_texture: ImageTexture = ImageTexture.create_from_image(image)
				texture_cache[path] = runtime_texture
				texture_cache[candidate_path] = runtime_texture
				return runtime_texture

		var loaded: Variant = ResourceLoader.load(candidate_path)
		if loaded is Texture2D:
			var tex: Texture2D = loaded as Texture2D
			texture_cache[path] = tex
			texture_cache[candidate_path] = tex
			return tex

	failed_texture_paths[path] = true
	return null


func _texture_path_candidates(path: String) -> Array[String]:
	var candidates: Array[String] = [path]
	var lower_path: String = path.to_lower()
	if lower_path.ends_with(".png"):
		var base_path: String = path.substr(0, path.length() - 4)
		for ext in [".jpg", ".jpeg", ".webp"]:
			var alt_path: String = base_path + ext
			if not candidates.has(alt_path):
				candidates.append(alt_path)
	return candidates

func _has_png_signature(abs_path: String) -> bool:
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return false
	if file.get_length() < 8:
		return false
	var bytes: PackedByteArray = file.get_buffer(8)
	if bytes.size() < 8:
		return false
	return bytes[0] == 137 and bytes[1] == 80 and bytes[2] == 78 and bytes[3] == 71 and bytes[4] == 13 and bytes[5] == 10 and bytes[6] == 26 and bytes[7] == 10


func _background_fallback_candidates(background_key: String) -> Array[String]:
	match background_key:
		"living_room_night":
			return ["living_room_afternoon", "living_room_morning", "sister_room_night"]
		"sister_room_night":
			return ["sister_room_afternoon", "sister_room_morning"]
		"kitchen_night":
			return ["kitchen_afternoon", "kitchen_morning", "living_room_night"]
		"player_room_night":
			return ["player_room_night_alt", "player_room_afternoon", "player_room_morning", "sister_room_night"]
		"player_room_night_alt":
			return ["player_room_night", "player_room_afternoon", "player_room_morning", "sister_room_night"]
		"living_room_afternoon":
			return ["living_room_morning", "sister_room_afternoon"]
		"sister_room_afternoon":
			return ["sister_room_morning", "living_room_afternoon"]
		"kitchen_afternoon":
			return ["kitchen_morning", "living_room_afternoon"]
		"player_room_afternoon":
			return ["player_room_morning", "sister_room_afternoon"]
		_:
			return ["sister_room_morning"]


func _update_love_visual(delta: int) -> void:
	var value: int = clampi(state.love_score, 0, 100)
	love_value_label.text = str(value)
	love_percent_label.text = "%s%%" % str(value)
	var fill_h: float = love_track_height * (float(value) / 100.0)
	love_fill.offset_top = -fill_h
	love_fill.offset_bottom = 0

	if delta > 0:
		love_fill.color = Color(1.0, 0.64, 0.78, 1.0)
		var tween_up: Tween = create_tween()
		tween_up.tween_property(love_fill, "color", Color(1.0, 0.45, 0.65, 1.0), 0.45)
	elif delta < 0:
		love_fill.color = Color(0.95, 0.35, 0.45, 1.0)
		var tween_down: Tween = create_tween()
		tween_down.tween_property(love_fill, "color", Color(1.0, 0.45, 0.65, 1.0), 0.65)
	else:
		love_fill.color = Color(1.0, 0.45, 0.65, 1.0)


func _update_hud() -> void:
	hud_label.text = "同居 %s DAYS" % str(state.living_days)
	mood_label.text = "%s %s" % [state.display_time, state.time_period_name]
	if money_value_label != null:
		money_value_label.text = "¥%s" % str(maxi(0, state.money_balance))
	status_label.text = "网络状态 %s\n读档 %s" % [
		state.api_status,
		state.debug_current_loaded_slot if not state.debug_current_loaded_slot.is_empty() else "-"
	]
	if web_toggle_button != null:
		web_toggle_button.text = "联网检索：%s" % ("开" if state.web_search_enabled else "关")
	if debug_toggle_button != null:
		debug_toggle_button.text = "调试%s" % ("开" if state.debug_panel_open else "关")
		debug_toggle_button.visible = DEBUG_UI_ENABLED
	if debug_panel != null:
		debug_panel.visible = DEBUG_UI_ENABLED and state.debug_panel_open
	if debug_label != null:
		debug_label.text = _build_debug_text() if DEBUG_UI_ENABLED else ""
	if has_method("_refresh_room_nav_ui"):
		call("_refresh_room_nav_ui")
	_update_love_visual(0)


func _base_chat_action_ready() -> bool:
	if mode != "chat":
		return false
	if blackjack_active:
		return false
	if modal_ui_open or waiting_for_choice:
		return false
	if state.room_nav_open:
		return false
	if transition_active:
		return false
	if ai_waiting_active or typing_active:
		return false
	if not queued_reply_segments.is_empty():
		return false
	if pending_shift_after_line or pending_period_intro:
		return false
	return true


func _chat_input_ready() -> bool:
	if not _base_chat_action_ready():
		return false
	if not state.victoria_is_here():
		return false
	return true


func _end_turn_ready() -> bool:
	return _base_chat_action_ready()


func _update_interaction_state(waiting_ai: bool = false) -> void:
	if waiting_ai:
		if not ai_waiting_active:
			waiting_indicator_accum = 0.0
		ai_waiting_active = true
		ai_waiting_message = "维多利亚正在思考"
		if ai_waiting_label != null:
			ai_waiting_label.visible = true
			ai_waiting_label.text = "%s." % ai_waiting_message
	else:
		ai_waiting_active = false
		waiting_indicator_accum = 0.0
		if ai_waiting_label != null:
			ai_waiting_label.visible = false

	var chat_enabled: bool = _chat_input_ready()
	var end_turn_enabled: bool = _end_turn_ready()
	var play_game_enabled: bool = end_turn_enabled and state.current_location == "living_room" and state.victoria_is_here() and not blackjack_active
	var blackjack_chat_enabled: bool = blackjack_active and has_method("_blackjack_chat_input_ready") and bool(call("_blackjack_chat_input_ready"))
	var dialogue_visible: bool = dialogue_label != null and not dialogue_label.text.strip_edges().is_empty()
	var show_input_field: bool = chat_enabled and not dialogue_visible
	if not state.victoria_is_here():
		if character_rect != null:
			character_rect.visible = false
	elif character_rect != null and not character_rect.visible and not transition_active:
		_set_character_by_mood("日常")
	if input_line != null:
		input_line.editable = show_input_field
	if input_row_margin_ref != null:
		input_row_margin_ref.visible = show_input_field
	if send_button != null:
		send_button.disabled = not chat_enabled
	if room_button != null:
		room_button.disabled = not end_turn_enabled
		room_button.visible = end_turn_enabled
	if play_game_button != null:
		play_game_button.disabled = not play_game_enabled
		play_game_button.visible = play_game_enabled
	if call_victoria_button != null:
		call_victoria_button.disabled = not end_turn_enabled
		call_victoria_button.visible = end_turn_enabled and not state.room_nav_open
	if blackjack_panel != null:
		blackjack_panel.visible = blackjack_active
	if blackjack_rules_button != null:
		blackjack_rules_button.visible = blackjack_active
		blackjack_rules_button.disabled = not blackjack_active
		blackjack_rules_button.text = "收起规则" if blackjack_rules_open else "规则说明"
	if blackjack_rules_panel != null:
		blackjack_rules_panel.visible = blackjack_active and blackjack_rules_open
	if blackjack_input_panel != null:
		blackjack_input_panel.visible = blackjack_active
	if blackjack_input_line != null:
		blackjack_input_line.editable = blackjack_chat_enabled
		blackjack_input_line.placeholder_text = "试着套妹妹的底牌……" if blackjack_chat_enabled else "现在先等这一轮动作结束"
	if end_turn_button != null:
		end_turn_button.disabled = not end_turn_enabled
		end_turn_button.visible = end_turn_enabled
	if web_toggle_button != null:
		web_toggle_button.disabled = not chat_enabled
		web_toggle_button.visible = chat_enabled
	if debug_toggle_button != null:
		debug_toggle_button.disabled = true if not DEBUG_UI_ENABLED else not chat_enabled
	if has_method("_set_quick_menu_enabled"):
		call("_set_quick_menu_enabled", not waiting_ai and not modal_ui_open and not blackjack_active)
	if has_method("_refresh_chat_prompt"):
		call("_refresh_chat_prompt")
	if next_button != null:
		next_button.visible = false
	if has_method("_refresh_room_nav_ui"):
		call("_refresh_room_nav_ui")
	if waiting_ai and state.room_nav_open:
		state.room_nav_open = false
		if has_method("_refresh_room_nav_ui"):
			call("_refresh_room_nav_ui")
	if waiting_ai and room_nav_button != null:
		room_nav_button.disabled = true
	if waiting_ai and call_victoria_button != null:
		call_victoria_button.disabled = true
	if not waiting_ai:
		_update_hud()


func _build_debug_text() -> String:
	var lines: Array[String] = []
	lines.append("API状态: %s (%s)" % [state.api_status, state.api_color])
	lines.append("联网检索: %s" % ("开启" if state.web_search_enabled else "关闭"))
	lines.append("场景: %s / %s / 第%s天" % [state.current_location, state.time_period_name, str(state.living_days)])
	lines.append("金钱: ¥%s" % str(maxi(0, state.money_balance)))
	lines.append("读取槽: %s | 保存槽: %s" % [
		state.debug_current_loaded_slot if not state.debug_current_loaded_slot.is_empty() else "-",
		state.debug_last_saved_slot if not state.debug_last_saved_slot.is_empty() else "-"
	])
	lines.append("立绘: %s | x%s | y%s | a%s" % [
		state.v_sprite_file,
		str(state.v_sprite_zoom),
		str(state.v_sprite_yoffset),
		str(state.v_sprite_alpha)
	])

	var turn_info_v: Variant = state.debug_last_turn_info
	if typeof(turn_info_v) == TYPE_DICTIONARY:
		var turn_info: Dictionary = turn_info_v
		if not turn_info.is_empty():
			lines.append("--- 最近一轮 ---")
			lines.append("输入: %s" % String(turn_info.get("player_text", "")))
			lines.append("回复: %s" % String(turn_info.get("reply_text", "")))
			lines.append("好感变化: %s | 情绪:%s | 表情:%s" % [
				str(turn_info.get("love_change", 0)),
				String(turn_info.get("mood", "")),
				String(turn_info.get("expression_cue", ""))
			])
			lines.append("来源: %s" % String(turn_info.get("source", "")))
			lines.append("联网命中: %s | 分段:%s" % [
				"是" if bool(turn_info.get("web_hit", false)) else "否",
				str(turn_info.get("segment_count", 1))
			])
			var fact_prompt: String = String(turn_info.get("fact_prompt", "")).strip_edges()
			if not fact_prompt.is_empty():
				lines.append("事实命中: %s" % fact_prompt)
			var mid_hits_v: Variant = turn_info.get("mid_hits", [])
			if typeof(mid_hits_v) == TYPE_ARRAY:
				var mid_hits: Array = mid_hits_v
				if not mid_hits.is_empty() and typeof(mid_hits[0]) == TYPE_DICTIONARY:
					var mid0: Dictionary = mid_hits[0]
					lines.append("中期命中: 第%s天 W%s %s" % [
						str(mid0.get("day", 0)),
						str(mid0.get("importance", 0)),
						String(mid0.get("summary", ""))
					])
			var long_hits_v: Variant = turn_info.get("long_hits", [])
			if typeof(long_hits_v) == TYPE_ARRAY:
				var long_hits: Array = long_hits_v
				if not long_hits.is_empty() and typeof(long_hits[0]) == TYPE_DICTIONARY:
					var long0: Dictionary = long_hits[0]
					lines.append("长期命中: 第%s天 W%s %s" % [
						str(long0.get("day", 0)),
						str(long0.get("importance", 0)),
						String(long0.get("text", ""))
					])

	var summary_info_v: Variant = state.debug_last_summary_info
	if typeof(summary_info_v) == TYPE_DICTIONARY:
		var summary_info: Dictionary = summary_info_v
		if not summary_info.is_empty():
			lines.append("--- 最近总结 ---")
			lines.append("第%s天 | 对话:%s 记录:%s 归档:%s 向量:%s" % [
				str(summary_info.get("day", 0)),
				str(summary_info.get("dialogue_count", summary_info.get("dialogues", 0))),
				str(summary_info.get("record_count", summary_info.get("records", 0))),
				str(summary_info.get("archived_count", summary_info.get("archived_mid_entries", 0))),
				str(summary_info.get("vector_upserts", 0))
			])
			var mid_summary: String = String(summary_info.get("mid_summary", "")).strip_edges()
			if not mid_summary.is_empty():
				lines.append("中期摘要: %s" % mid_summary)

	var event_log_v: Variant = state.debug_event_log
	if typeof(event_log_v) == TYPE_ARRAY:
		var event_log: Array = event_log_v
		if not event_log.is_empty():
			lines.append("--- 事件日志 ---")
			var from_idx: int = maxi(0, event_log.size() - 6)
			for i in range(from_idx, event_log.size()):
				lines.append(String(event_log[i]))

	return "\n".join(lines)
