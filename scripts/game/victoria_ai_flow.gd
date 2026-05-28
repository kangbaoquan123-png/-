extends "res://scripts/game/victoria_story_ui.gd"

const USER_PREFS_SCRIPT := preload("res://scripts/core/victoria_user_prefs.gd")
const DEFAULT_API_PROVIDER_ID := "deepseek"
const API_PROVIDER_DEFAULTS := {
	"deepseek": {
		"base_url": "https://api.deepseek.com/chat/completions",
		"model": "deepseek-chat"
	},
	"openai": {
		"base_url": "https://api.openai.com/v1/chat/completions",
		"model": "gpt-4.1-mini"
	},
	"siliconflow": {
		"base_url": "https://api.siliconflow.cn/v1/chat/completions",
		"model": "deepseek-ai/DeepSeek-V3"
	},
	"openrouter": {
		"base_url": "https://openrouter.ai/api/v1/chat/completions",
		"model": "openai/gpt-4.1-mini"
	},
	"gemini": {
		"base_url": "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
		"model": "gemini-2.5-flash"
	},
	"custom": {
		"base_url": "",
		"model": ""
	}
}
const API_PROVIDER_ENV_KEYS := {
	"deepseek": ["DEEPSEEK_API_KEY", "API_KEY"],
	"openai": ["OPENAI_API_KEY", "API_KEY"],
	"siliconflow": ["SILICONFLOW_API_KEY", "API_KEY"],
	"openrouter": ["OPENROUTER_API_KEY", "API_KEY"],
	"gemini": ["GEMINI_API_KEY", "GOOGLE_API_KEY", "API_KEY"],
	"custom": ["API_KEY"]
}
const SESSION_ROLLBACK_DIR := "user://session_rollback"
const BASELINE_RUNTIME_BACKUP := "user://session_rollback/runtime_save_baseline.json"
const BASELINE_VECTOR_DB_BACKUP := "user://session_rollback/vector_memory_baseline.sqlite"
const BASELINE_VECTOR_MANIFEST_BACKUP := "user://session_rollback/vector_manifest_baseline.json"
const VECTOR_DB_FILE := "user://vector_memory/victoria_memory.sqlite"
const VECTOR_MANIFEST_FILE := "user://vector_memory/local_manifest.json"
const BLACKJACK_TARGET := 21
const BLACKJACK_DEALER_STAND := 17
const BLACKJACK_CARD_WIDTH := 112.0
const BLACKJACK_CARD_HEIGHT := 156.0
const BLACKJACK_CARD_CORNER := 12
const BLACKJACK_CARD_FLIGHT_DURATION := 0.48
const BLACKJACK_CARD_SETTLE_DURATION := 0.24
const BLACKJACK_DEAL_STEP_DELAY := 0.48
const BLACKJACK_DEAL_SETTLE_DELAY := 0.42
const BLACKJACK_REVEAL_PAUSE := 0.86
const BLACKJACK_DEALER_DRAW_PAUSE := 0.62
const BLACKJACK_RESULT_PAUSE := 0.78
const BLACKJACK_HIT_DRAW_PAUSE := 0.38
const BLACKJACK_DISCARD_FLY_DURATION := 0.76
const BLACKJACK_DISCARD_FLY_STAGGER := 0.04
const BLACKJACK_BET_OPTIONS: Array[int] = [5, 10, 50, 100, 200, 500]
const BLACKJACK_DEFAULT_BET := 10
const BLACKJACK_NATURAL_MULTIPLIER := 1.5
const BLACKJACK_MAX_PROBES := 2
const BLACKJACK_TRUST_DELTA_FELL_FOR_BLUFF := -8
const BLACKJACK_TRUST_DELTA_CAUGHT_LIE := -3
const BLACKJACK_TRUST_DELTA_TRUTH_HELP := 6
const BLACKJACK_RECENT_STYLE_MEMORY := 12
const AI_MIN_THINK_ONLINE_SECONDS := 0.0
const AI_MIN_THINK_OFFLINE_SECONDS := 0.0
const AI_REPLY_DEDUP_LOOKBACK := 14
var transition_click_waiting: bool = false
var transition_click_token: int = 0
var session_baseline_ready: bool = false
var blackjack_refresh_token: int = 0
var blackjack_discard_visual_locked: bool = false
var blackjack_round_money_applied: bool = false
var blackjack_last_money_delta: int = 0
var blackjack_probe_count: int = 0
var blackjack_round_claim_history: Array[Dictionary] = []
var blackjack_round_social_resolved: bool = false

func _on_next_pressed() -> void:
	if modal_ui_open:
		return
	if blackjack_active:
		return
	if state.room_nav_open:
		state.room_nav_open = false
		if has_method("_refresh_room_nav_ui"):
			call("_refresh_room_nav_ui")
		return
	if transition_active:
		return
	if ai_waiting_active:
		# AI 回复中时，点击屏幕不应打断“思考中”状态。
		return
	if typing_active:
		_complete_typewriter()
		_update_interaction_state(false)
		if has_method("_refresh_chat_prompt"):
			call("_refresh_chat_prompt")
		return
	if waiting_for_choice:
		return
	if mode == "chat" and _show_next_reply_segment_if_any():
		return
	if pending_shift_after_line:
		pending_shift_after_line = false
		await _run_shift_time_sequence()
		return
	if mode == "chat" and pending_period_intro:
		pending_period_intro = false
		await _maybe_run_period_initiative()
		return
	if mode == "chat":
		# Keep VN-style click flow in chat mode: click to clear current line, then focus input.
		if dialogue_label != null and not dialogue_label.text.strip_edges().is_empty():
			dialogue_label.text = ""
		if speaker_label != null and speaker_label.visible:
			speaker_label.visible = false
			speaker_label.text = ""
		if input_line != null and input_line.editable:
			input_line.grab_focus()
		_update_interaction_state(false)
		if has_method("_refresh_chat_prompt"):
			call("_refresh_chat_prompt")
		return
	if mode == "story":
		_advance_story()


func _consume_transition_click_from_input() -> bool:
	if not transition_click_waiting:
		return false
	transition_click_token += 1
	return true


func _wait_for_transition_click() -> void:
	transition_click_waiting = true
	var token_before: int = transition_click_token
	while transition_click_token == token_before:
		await get_tree().process_frame
	transition_click_waiting = false


func _on_input_submitted(_text: String) -> void:
	_on_send_pressed()


func _on_send_pressed() -> void:
	if mode != "chat":
		return
	if blackjack_active:
		await _handle_blackjack_chat_submit()
		return
	if modal_ui_open or state.room_nav_open:
		return
	if typing_active or waiting_for_choice or not queued_reply_segments.is_empty():
		return
	if not state.victoria_is_here():
		if has_method("_show_notify"):
			call("_show_notify", "这个房间暂时没有可以对话的人。")
		return
	var player_text: String = input_line.text.strip_edges()
	if player_text.is_empty():
		_show_line("维多利亚", "唔……这种时候突然沉默，会让我心慌的。哥哥？", false)
		input_line.clear()
		state.input_live_text = ""
		return
	input_line.clear()
	state.input_live_text = ""

	var direct_answer: String = web_service.direct_calendar_answer(player_text)
	if not direct_answer.is_empty():
		_show_line("维多利亚", direct_answer, false)
		state.chat_history.append({"role": "user", "content": player_text, "day": state.living_days})
		state.chat_history.append({"role": "assistant", "content": direct_answer, "day": state.living_days})
		_set_api_status("本地时间直答(未走API)", "#7bd88f")
		_record_turn_debug(player_text, direct_answer, 0, "日常", "", false, "calendar_direct")
		_push_debug_event("命中时间/日期直答")
		_update_hud()
		_save_runtime_state()
		return

	if player_text in ["拜拜", "再见", "我先去忙了", "结束这轮"]:
		_queue_end_turn_exit()
		return

	var room_target: String = state.room_request_target(player_text)
	if not room_target.is_empty():
		var move_with_victoria: bool = state.room_request_with_victoria(player_text)
		await _switch_room_with_immersion(room_target, move_with_victoria)
		return

	if state.love_score >= 60 and not state.stage_60_triggered:
		state.stage_60_triggered = true
		_show_line("维多利亚", "哥哥……你会一直看着我的，对吗？无论我变成什么样子……？", false)
		_push_debug_event("触发好感60阶段剧情")
		_update_hud()
		return

	await _handle_ai_turn(player_text)


func _on_end_turn_pressed() -> void:
	if mode != "chat" or not _end_turn_ready():
		return
	if modal_ui_open or state.room_nav_open:
		return
	if ai_waiting_active or waiting_for_choice:
		return
	_push_debug_event("玩家点击结束交互")
	_queue_end_turn_exit()


func _queue_end_turn_exit() -> void:
	state.exit_count += 1
	_push_debug_event("玩家主动结束当前轮")
	if state.victoria_is_here():
		_show_line("维多利亚", "唔……哥哥要先忙别的事了吗？那我会在这里乖乖等你回来。", false)
		_complete_typewriter()
	else:
		# 妹妹不在当前房间时，结束交互不插入她的台词。
		if dialogue_label != null:
			dialogue_label.text = ""
		if speaker_label != null:
			speaker_label.visible = false
			speaker_label.text = ""
	pending_shift_after_line = true
	_update_hud()
	_update_interaction_state(false)
	_save_runtime_state()


func _on_room_button_pressed() -> void:
	if mode != "chat":
		return
	if blackjack_active:
		return
	if has_method("_toggle_room_nav"):
		call("_toggle_room_nav")


func _on_call_victoria_button_pressed() -> void:
	if mode != "chat":
		return
	if blackjack_active:
		return
	if modal_ui_open or state.room_nav_open:
		return
	if transition_active or waiting_for_choice or ai_waiting_active or typing_active:
		return
	if not queued_reply_segments.is_empty() or pending_shift_after_line or pending_period_intro:
		return
	if state.victoria_is_here():
		if character_rect != null and not character_rect.visible:
			_set_character_by_mood("日常")
		_show_line("维多利亚", "我现在就在你身边啊", false)
		return
	transition_active = true
	_update_interaction_state(false)
	_play_footstep()
	await get_tree().create_timer(0.28).timeout
	state.victoria_location = state.current_location
	_apply_scene_by_state()
	await _play_victoria_arrival_animation("日常")
	transition_active = false
	_show_line("维多利亚", "哥哥，我过来了。", false)
	_push_debug_event("妹妹被叫到了%s" % state.current_location)
	_update_hud()
	_save_runtime_state()


func _play_victoria_arrival_animation(mood: String = "日常") -> void:
	if character_rect == null:
		_set_character_by_mood(mood)
		return
	_set_character_by_mood(mood)
	character_rect.visible = true
	var target_position: Vector2 = character_rect.position
	var target_alpha: float = clampf(character_rect.modulate.a, 0.0, 1.0)
	character_rect.position = target_position + Vector2(72.0, 18.0)
	character_rect.modulate = Color(
		character_rect.modulate.r,
		character_rect.modulate.g,
		character_rect.modulate.b,
		0.0
	)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(character_rect, "position", target_position + Vector2(-8.0, 0.0), 0.24)
	tween.parallel().tween_property(character_rect, "modulate:a", target_alpha, 0.24)
	tween.chain().tween_property(character_rect, "position", target_position, 0.10)
	await tween.finished


func _on_play_game_button_pressed() -> void:
	if mode != "chat":
		return
	if blackjack_active:
		return
	if state.current_location != "living_room":
		if has_method("_show_notify"):
			call("_show_notify", "只有在客厅才能玩21点。")
		return
	if not state.victoria_is_here():
		if has_method("_show_notify"):
			call("_show_notify", "妹妹不在客厅时，不能开始21点。")
		return
	if modal_ui_open or state.room_nav_open:
		return
	if transition_active or waiting_for_choice or ai_waiting_active or typing_active:
		return
	if state.money_balance < _blackjack_min_bet():
		if has_method("_show_notify"):
			call("_show_notify", "余额不足，至少需要%s才能下注。" % _money_text(_blackjack_min_bet()))
		return
	_open_blackjack_game()


func _blackjack_chat_input_ready() -> bool:
	if not blackjack_active:
		return false
	if blackjack_animating or blackjack_round_over or blackjack_reveal_dealer:
		return false
	if blackjack_dealer_cards.size() < 2:
		return false
	return blackjack_probe_count < BLACKJACK_MAX_PROBES


func _handle_blackjack_chat_submit() -> void:
	if blackjack_input_line == null:
		return
	var player_text: String = blackjack_input_line.text.strip_edges()
	blackjack_input_line.clear()
	state.input_live_text = ""
	blackjack_input_line.release_focus()
	if player_text.is_empty():
		blackjack_status_text = "你轻轻抿了抿唇，却还没真正把试探说出口。"
		_blackjack_refresh_panel()
		return
	if not _blackjack_chat_input_ready():
		if blackjack_round_over:
			blackjack_status_text = "这局已经结束了，先继续下一局吧。"
		elif blackjack_animating or blackjack_reveal_dealer:
			blackjack_status_text = "现在正在亮牌和发牌，先等等她的动作。"
		else:
			blackjack_status_text = "这局已经被你问够了，先决定要牌还是停牌吧。"
		_blackjack_refresh_panel()
		return
	var claim: Dictionary = _blackjack_build_probe_claim(player_text)
	blackjack_probe_count += 1
	claim["probe_index"] = blackjack_probe_count
	blackjack_round_claim_history.append(claim)
	_blackjack_register_probe_style(String(claim.get("probe_style", "")))
	_increment_blackjack_read_profile("probe_count")
	if bool(claim.get("player_exposed", false)):
		_increment_blackjack_read_profile("shared_hand_info_count")
	blackjack_animating = true
	blackjack_status_text = "维多利亚正在斟酌你的试探……"
	_blackjack_refresh_panel()
	var online_reply: String = await _blackjack_generate_probe_reply_online(player_text, claim)
	var reply_source: String = "online"
	if online_reply.is_empty():
		reply_source = "local_fallback"
		_set_api_status("牌桌博弈(本地规则)", "#d0b8ff")
	else:
		var online_usable: bool = _blackjack_online_reply_usable(online_reply, player_text, claim)
		if online_usable:
			claim["response_text"] = online_reply
		else:
			reply_source = "local_fallback"
			_set_api_status("牌桌博弈(本地规则)", "#d0b8ff")
			_push_debug_event("21点在线回复被判定为指代偏移/不符合约束，已回退本地台词")
	blackjack_animating = false
	blackjack_status_text = "维多利亚：%s" % String(claim.get("response_text", ""))
	_push_debug_event("21点套话[%s] -> %s" % [
		String(claim.get("probe_style", "")),
		String(claim.get("mode", ""))
	])
	_push_debug_event("21点套话回复来源: %s" % reply_source)
	_blackjack_refresh_panel()
	_save_runtime_state()


func _blackjack_generate_probe_reply_online(player_text: String, claim: Dictionary) -> String:
	var api_config: Dictionary = _resolve_api_config()
	var api_key: String = String(api_config.get("api_key", "")).strip_edges()
	var base_url: String = String(api_config.get("base_url", "")).strip_edges()
	var model_name: String = String(api_config.get("model", "")).strip_edges()
	if api_key.is_empty() or base_url.is_empty() or model_name.is_empty():
		return ""

	var probe_mode: String = String(claim.get("mode", ""))
	var probe_style: String = String(claim.get("probe_style", ""))
	var spoken_value: int = int(claim.get("spoken_value", 0))
	var spoken_bucket: String = String(claim.get("spoken_bucket", ""))
	var truth_value: int = int(claim.get("truth_value", 0))
	var truth_bucket: String = String(claim.get("truth_bucket", ""))
	var dealer_up_value: int = int(claim.get("dealer_up_value", 0))
	var player_points: int = int(claim.get("player_points_before", _blackjack_hand_value(blackjack_player_cards)))
	var constraint_text: String = _blackjack_probe_constraint_text(probe_mode, spoken_value, spoken_bucket)
	var bucket_text: String = _blackjack_bucket_readable(spoken_bucket if not spoken_bucket.is_empty() else truth_bucket)

	var system_prompt: String = ""
	system_prompt += "你是维多利亚，正在和哥哥玩21点。"
	system_prompt += "只输出维多利亚会说的话，1~2句中文，语气自然。"
	system_prompt += "不要输出解释、标签、括号系统提示、JSON、markdown。"
	system_prompt += "保持“体贴+细腻+自然+轻微占有欲”，拒绝百依百顺，允许镜像试探。"
	system_prompt += "哥哥发言中的“你”是指维多利亚，“我”是指哥哥；你必须直接回答自己的想法，不要把主语反转成“哥哥想…吗”。"
	system_prompt += "当哥哥说“你的牌”时，你必须围绕“我的牌”回应，绝不能改写成“哥哥的牌…吗”。"
	system_prompt += "错误示例：哥哥的牌很大吗？正确示例：我这张偏大，你先别贪。"

	var user_prompt: String = ""
	user_prompt += "【指代约定】本轮里“你”=维多利亚，“我”=哥哥。\n"
	user_prompt += "【玩家刚说】%s\n" % player_text
	user_prompt += "【牌桌状态】玩家当前约%d点；庄家明牌点值%d；本局已试探%d/%d次。\n" % [
		player_points,
		dealer_up_value,
		blackjack_probe_count,
		BLACKJACK_MAX_PROBES
	]
	user_prompt += "【本轮策略】风格=%s，模式=%s。\n" % [probe_style, probe_mode]
	user_prompt += "【约束】%s\n" % constraint_text
	if not bucket_text.is_empty():
		user_prompt += "【区间提示】%s\n" % bucket_text
	user_prompt += "请按约束输出维多利亚的最终台词。"

	var messages: Array = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	var raw: String = await _request_chat_completion(messages, api_config, 0.75)
	return _blackjack_sanitize_online_reply(raw, player_text)


func _blackjack_probe_constraint_text(mode: String, spoken_value: int, spoken_bucket: String) -> String:
	match mode:
		"truth_exact":
			return "你必须明确说出一个具体数字，并且这个数字必须是 %d。" % spoken_value
		"lie_exact":
			return "你必须明确说出一个具体数字，并且这个数字必须是 %d。不要承认在说谎。" % spoken_value
		"truth_range":
			return "不要说具体数字，只能给区间暗示。区间必须与“%s”一致。" % _blackjack_bucket_readable(spoken_bucket)
		"lie_range":
			return "不要说具体数字，只能给区间暗示。区间必须与“%s”一致。不要承认在误导。" % _blackjack_bucket_readable(spoken_bucket)
		"counter_probe":
			return "不要透露底牌数字或区间，转而反问、施压或镜像试探。"
		_:
			return "保持神秘与分寸，不要透露底牌数字或区间。"


func _blackjack_bucket_readable(bucket: String) -> String:
	match bucket:
		"low":
			return "偏小（2~4）"
		"mid":
			return "中间（5~7）"
		"high":
			return "偏大（8~11）"
		_:
			return ""


func _blackjack_sanitize_online_reply(raw: String, player_text: String = "") -> String:
	var text: String = String(raw).replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	if text.is_empty():
		return ""
	var lines: Array[String] = []
	for line in text.split("\n", false):
		var l: String = String(line).strip_edges()
		if l.is_empty():
			continue
		if l.begins_with("[M:") or l.begins_with("[P:") or l.begins_with("[W:"):
			continue
		lines.append(l)
	if lines.is_empty():
		return ""
	var merged: String = " ".join(lines).strip_edges()
	if merged.begins_with("维多利亚："):
		merged = merged.trim_prefix("维多利亚：").strip_edges()
	merged = _blackjack_soft_fix_subject_flip(merged, player_text)
	if merged.length() > 120:
		merged = merged.substr(0, 120).strip_edges()
	return merged


func _blackjack_soft_fix_subject_flip(reply: String, player_text: String) -> String:
	var fixed: String = String(reply).strip_edges()
	var source: String = String(player_text).strip_edges()
	if fixed.is_empty() or source.is_empty():
		return fixed
	if source.find("你的牌") >= 0 and fixed.find("哥哥的牌") >= 0:
		fixed = fixed.replace("哥哥的牌", "我的牌")
	if source.find("你想") >= 0 and fixed.find("哥哥想") >= 0:
		fixed = fixed.replace("哥哥想", "我想")
	if source.find("你现在") >= 0 and fixed.find("哥哥现在") >= 0:
		fixed = fixed.replace("哥哥现在", "我现在")
	return fixed


func _blackjack_online_reply_usable(reply: String, player_text: String, claim: Dictionary) -> bool:
	var clean: String = String(reply).strip_edges()
	if clean.is_empty():
		return false
	if _blackjack_has_subject_misfire(clean, player_text):
		return false
	var mode: String = String(claim.get("mode", "")).strip_edges()
	var spoken_value: int = int(claim.get("spoken_value", 0))
	var spoken_bucket: String = String(claim.get("spoken_bucket", "")).strip_edges()
	match mode:
		"truth_exact", "lie_exact":
			if spoken_value <= 0:
				return false
			if clean.find(str(spoken_value)) < 0:
				return false
		"truth_range", "lie_range":
			if not _blackjack_reply_matches_bucket(clean, spoken_bucket):
				return false
		"counter_probe":
			if clean.find("哥哥") < 0 and clean.find("你") < 0:
				return false
		_:
			pass
	return true


func _blackjack_has_subject_misfire(reply: String, player_text: String) -> bool:
	var clean: String = String(reply).replace(" ", "").replace("\n", "").strip_edges()
	var source: String = String(player_text).replace(" ", "").replace("\n", "").strip_edges()
	if clean.is_empty():
		return true
	var hard_hits: Array[String] = [
		"你是说哥哥",
		"哥哥是说你",
		"哥哥想吃",
		"哥哥想问",
		"哥哥想要",
		"哥哥想说"
	]
	for phrase in hard_hits:
		if clean.find(phrase) >= 0:
			return true
	if source.find("你的牌") >= 0 and clean.find("哥哥的牌") >= 0:
		return true
	if source.find("你想") >= 0 and clean.find("哥哥想") >= 0:
		return true
	if source.find("你现在") >= 0 and clean.find("哥哥现在") >= 0 and clean.find("吗") >= 0:
		return true
	return false


func _blackjack_reply_matches_bucket(reply: String, bucket: String) -> bool:
	var clean: String = String(reply).strip_edges()
	if clean.is_empty():
		return false
	match bucket:
		"low":
			return _blackjack_text_contains_any(clean, ["小", "不高", "偏小", "没那么高"])
		"mid":
			return _blackjack_text_contains_any(clean, ["中间", "不上不下", "不高不低", "中等"])
		"high":
			return _blackjack_text_contains_any(clean, ["高", "偏大", "不低", "紧张"])
		_:
			return true


func _blackjack_build_probe_claim(player_text: String) -> Dictionary:
	var probe_style: String = _blackjack_classify_probe(player_text)
	var player_exposed: bool = _blackjack_player_shared_hand_info(player_text)
	var hidden_card: Dictionary = _blackjack_hidden_card()
	var truth_value: int = _blackjack_card_point_value(hidden_card)
	var truth_bucket: String = _blackjack_bucket_for_value(truth_value)
	var repeat_pressure: int = _blackjack_probe_repeat_pressure(probe_style)
	var reply_mode: String = _blackjack_choose_reply_mode(probe_style, player_exposed, repeat_pressure)
	var spoken_value: int = 0
	var spoken_bucket: String = ""
	var is_truth: bool = false
	match reply_mode:
		"truth_exact":
			spoken_value = truth_value
			is_truth = true
		"lie_exact":
			spoken_value = _blackjack_fake_card_value(truth_value)
		"truth_range":
			spoken_bucket = truth_bucket
			is_truth = true
		"lie_range":
			spoken_bucket = _blackjack_fake_bucket(truth_bucket)
		_:
			pass
	var response_text: String = _blackjack_render_probe_reply(
		reply_mode,
		probe_style,
		truth_value,
		spoken_value,
		spoken_bucket,
		player_exposed
	)
	return {
		"probe_style": probe_style,
		"player_text": player_text,
		"player_exposed": player_exposed,
		"mode": reply_mode,
		"is_truth": is_truth,
		"trust_before": clampi(state.blackjack_trust_score, 0, 100),
		"repeat_pressure": repeat_pressure,
		"truth_value": truth_value,
		"truth_bucket": truth_bucket,
		"spoken_value": spoken_value,
		"spoken_bucket": spoken_bucket,
		"claim_direction": _blackjack_claim_direction(reply_mode, spoken_value, spoken_bucket),
		"player_points_before": _blackjack_hand_value(blackjack_player_cards),
		"dealer_up_value": _blackjack_card_point_value(blackjack_dealer_cards[0]) if not blackjack_dealer_cards.is_empty() else 0,
		"response_text": response_text,
		"action_after": ""
	}


func _blackjack_classify_probe(text: String) -> String:
	var raw: String = text.replace(" ", "").replace("\n", "").strip_edges()
	if _blackjack_text_contains_any(raw, ["骗我", "说谎", "假话", "诈我", "唬我", "真的假的", "骗", "胡说"]):
		return "callout"
	if _blackjack_text_contains_any(raw, ["不敢", "心虚", "牌烂", "怕了", "没种", "怂", "输不起"]):
		return "taunt"
	if _blackjack_text_contains_any(raw, ["交换", "条件", "下局让你", "我就", "我会", "请你", "答应你"]):
		return "deal"
	if _blackjack_text_contains_any(raw, ["求你", "拜托", "最好了", "最喜欢", "乖", "疼我", "告诉我嘛"]):
		return "flatter"
	if _blackjack_text_contains_any(raw, ["不会是", "是不是", "我猜", "应该是", "不大吧", "不高吧", "挺大吧", "很小吧"]):
		return "soft_probe"
	if _blackjack_player_shared_hand_info(raw):
		return "self_reveal"
	return "small_talk"


func _blackjack_player_shared_hand_info(text: String) -> bool:
	var raw: String = text.replace(" ", "").replace("\n", "").strip_edges()
	if _blackjack_text_contains_any(raw, ["我现在", "我这手", "我手里", "我有", "我这边", "我的是"]):
		return true
	if raw.find("点") >= 0 and raw.find("我") >= 0:
		return true
	return false


func _blackjack_text_contains_any(text: String, needles: Array[String]) -> bool:
	for needle in needles:
		if text.find(needle) >= 0:
			return true
	return false


func _blackjack_choose_reply_mode(probe_style: String, player_exposed: bool, repeat_pressure: int = 0) -> String:
	var love: int = state.love_score
	var trust_score: int = clampi(state.blackjack_trust_score, 0, 100)
	var roll: float = rng.randf()
	var mode: String = "refuse_soft"
	match probe_style:
		"flatter":
			if love >= 70:
				if roll < 0.28:
					mode = "truth_exact"
				elif roll < 0.72:
					mode = "truth_range"
				else:
					mode = "refuse_soft"
			else:
				if roll < 0.20:
					mode = "truth_range"
				elif roll < 0.68:
					mode = "lie_range"
				else:
					mode = "refuse_soft"
		"deal":
			if love >= 72 and roll < 0.22:
				mode = "truth_exact"
			elif roll < 0.58:
				mode = "counter_probe"
			elif love >= 45:
				mode = "truth_range"
			else:
				mode = "lie_range"
		"taunt":
			mode = "lie_exact" if roll < 0.62 else "lie_range"
		"callout":
			if roll < 0.42:
				mode = "counter_probe"
			elif love >= 55 and roll < 0.66:
				mode = "truth_range"
			else:
				mode = "lie_range"
		"soft_probe":
			if love >= 50:
				if roll < 0.24:
					mode = "truth_exact"
				elif roll < 0.64:
					mode = "truth_range"
				elif roll < 0.84:
					mode = "counter_probe"
				else:
					mode = "lie_range"
			else:
				if roll < 0.18:
					mode = "truth_range"
				elif roll < 0.52:
					mode = "counter_probe"
				else:
					mode = "lie_exact"
		"self_reveal":
			if roll < 0.56:
				mode = "lie_range"
			elif roll < 0.82:
				mode = "lie_exact"
			else:
				mode = "counter_probe"
		_:
			mode = "refuse_soft" if roll < 0.58 else "counter_probe"
	if player_exposed:
		if mode == "truth_exact" and rng.randf() < 0.70:
			mode = "lie_range"
		elif mode == "truth_range" and rng.randf() < 0.38:
			mode = "counter_probe"
	if blackjack_probe_count >= 1:
		if mode == "truth_exact" and rng.randf() < 0.62:
			mode = "truth_range"
		elif mode == "lie_exact" and rng.randf() < 0.35:
			mode = "lie_range"
	if trust_score >= 70:
		if mode == "lie_exact" and rng.randf() < 0.58:
			mode = "truth_range"
		elif mode == "lie_range" and rng.randf() < 0.40:
			mode = "truth_range"
		elif mode == "counter_probe" and (probe_style == "flatter" or probe_style == "deal") and rng.randf() < 0.25:
			mode = "truth_range"
	elif trust_score <= 35:
		var distrust_rate: float = clampf(0.30 + float(35 - trust_score) * 0.014, 0.30, 0.72)
		if mode == "truth_exact" and rng.randf() < distrust_rate:
			mode = "lie_range"
		elif mode == "truth_range" and rng.randf() < distrust_rate:
			mode = "counter_probe"
	if repeat_pressure > 0:
		var punish_rate: float = clampf(0.26 + float(repeat_pressure) * 0.18, 0.26, 0.82)
		if mode == "truth_exact" and rng.randf() < punish_rate + 0.12:
			mode = "lie_range"
		elif mode == "truth_range" and rng.randf() < punish_rate:
			mode = "counter_probe"
		elif rng.randf() < punish_rate * 0.55:
			mode = "counter_probe"
	return mode


func _blackjack_probe_repeat_pressure(probe_style: String) -> int:
	var style: String = String(probe_style).strip_edges()
	if style.is_empty():
		return 0
	var recent: Array[String] = state.blackjack_recent_probe_styles
	if recent.is_empty():
		return 0
	var streak: int = 0
	for i in range(recent.size() - 1, -1, -1):
		var prev_style: String = String(recent[i]).strip_edges()
		if prev_style != style:
			break
		streak += 1
	var total_same: int = 0
	var start_idx: int = maxi(0, recent.size() - 6)
	for j in range(start_idx, recent.size()):
		if String(recent[j]).strip_edges() == style:
			total_same += 1
	var pressure: int = 0
	if streak >= 1:
		pressure += 1
	if streak >= 2:
		pressure += 1
	if total_same >= 3:
		pressure += 1
	return clampi(pressure, 0, 3)


func _blackjack_register_probe_style(probe_style: String) -> void:
	var style: String = String(probe_style).strip_edges()
	if style.is_empty():
		return
	state.blackjack_recent_probe_styles.append(style)
	while state.blackjack_recent_probe_styles.size() > BLACKJACK_RECENT_STYLE_MEMORY:
		state.blackjack_recent_probe_styles.pop_front()


func _blackjack_hidden_card() -> Dictionary:
	if blackjack_dealer_cards.size() < 2:
		return {}
	return blackjack_dealer_cards[blackjack_dealer_cards.size() - 1]


func _blackjack_card_point_value(card: Dictionary) -> int:
	var rank: int = int(card.get("rank", 1))
	if rank == 1:
		return 11
	if rank >= 10:
		return 10
	return rank


func _blackjack_bucket_for_value(value: int) -> String:
	if value <= 4:
		return "low"
	if value <= 7:
		return "mid"
	return "high"


func _blackjack_fake_card_value(truth_value: int) -> int:
	var candidates: Array[int] = []
	for delta in [-3, -2, -1, 1, 2, 3]:
		var candidate: int = clampi(truth_value + delta, 2, 11)
		if candidate == truth_value:
			continue
		if not candidates.has(candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		candidates = [3, 4, 6, 7, 8, 10]
		candidates.erase(truth_value)
	if candidates.is_empty():
		return 7 if truth_value == 10 else 10
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _blackjack_fake_bucket(truth_bucket: String) -> String:
	match truth_bucket:
		"low":
			return "high" if rng.randf() < 0.75 else "mid"
		"high":
			return "low" if rng.randf() < 0.75 else "mid"
		_:
			return "low" if rng.randf() < 0.5 else "high"


func _blackjack_claim_direction(reply_mode: String, spoken_value: int, spoken_bucket: String) -> String:
	if reply_mode == "counter_probe" or reply_mode == "refuse_soft":
		return "neutral"
	var bucket: String = spoken_bucket
	if bucket.is_empty():
		bucket = _blackjack_bucket_for_value(spoken_value)
	match bucket:
		"low":
			return "safe"
		"high":
			return "danger"
		_:
			return "neutral"


func _blackjack_render_probe_reply(
	reply_mode: String,
	probe_style: String,
	truth_value: int,
	spoken_value: int,
	spoken_bucket: String,
	player_exposed: bool
) -> String:
	var templates: Array[String] = []
	match reply_mode:
		"truth_exact":
			templates = [
				"如果哥哥非要问的话……那张是%d。",
				"嗯，我盖着的这张是%d。可别说我没提醒你。",
				"好吧，只说这一次——是%d。"
			]
			return _blackjack_pick_reply(templates) % spoken_value
		"lie_exact":
			if probe_style == "taunt":
				templates = [
					"既然哥哥这么激我，那我就告诉你，是%d。",
					"唔，我这张也没多大呀，也就%d。"
				]
			else:
				templates = [
					"想知道呀？那我告诉你，是%d。",
					"那张不高哦，大概是%d。"
				]
			return _blackjack_pick_reply(templates) % spoken_value
		"truth_range":
			return _blackjack_truth_range_reply(spoken_bucket)
		"lie_range":
			return _blackjack_lie_range_reply(spoken_bucket)
		"counter_probe":
			if player_exposed:
				templates = [
					"哥哥都快把自己的点数交代完了，还想继续从我这边套呀？",
					"你先把自己的牌都露给我了，现在才想来问我，会不会太迟了一点？"
				]
			else:
				templates = [
					"哥哥先告诉我，你现在是不是已经开始犹豫了？",
					"你问我之前，不如先说说……你现在那边是不是不太稳呀？",
					"想从我这里套到底牌之前，哥哥要不要先坦白一下自己的想法？"
				]
			return _blackjack_pick_reply(templates)
		_:
			if truth_value >= 8:
				templates = [
					"这种事怎么能直接告诉你嘛，我还想看哥哥会不会自己读出来呢。",
					"不告诉你。要是现在就说穿了，牌桌就不好玩了。"
				]
			else:
				templates = [
					"唔，这个可不能直接讲。",
					"不行，这种秘密要翻牌的时候才知道。"
				]
			return _blackjack_pick_reply(templates)


func _blackjack_truth_range_reply(bucket: String) -> String:
	var templates: Array[String] = []
	match bucket:
		"low":
			templates = [
				"不高，没你想得那么吓人。",
				"偏小一点，哥哥不用光看着我这边发抖。"
			]
		"high":
			templates = [
				"偏大一点，哥哥最好别太贪心。",
				"这张不算温柔哦，你最好认真一点看牌。"
			]
		_:
			templates = [
				"中间吧，不算特别夸张。",
				"大概是个不上不下的数字。"
			]
	return _blackjack_pick_reply(templates)


func _blackjack_lie_range_reply(bucket: String) -> String:
	var templates: Array[String] = []
	match bucket:
		"low":
			templates = [
				"挺小的，你要是想再拿一张也不是不行。",
				"没那么高啦，哥哥现在收手会不会太可惜了？"
			]
		"high":
			templates = [
				"有点高哦，哥哥最好先收着。",
				"这张会让人紧张呢，我要是哥哥，就不会乱动了。"
			]
		_:
			templates = [
				"中间那种吧，怎么选都得自己承担后果哦。",
				"不高不低，哥哥可别想让我替你做决定。"
			]
	return _blackjack_pick_reply(templates)


func _blackjack_pick_reply(templates: Array[String]) -> String:
	if templates.is_empty():
		return ""
	return templates[rng.randi_range(0, templates.size() - 1)]


func _increment_blackjack_read_profile(key: String, amount: int = 1) -> void:
	var current: int = int(state.blackjack_player_read_profile.get(key, 0))
	state.blackjack_player_read_profile[key] = current + amount


func _blackjack_reset_social_round_state() -> void:
	blackjack_probe_count = 0
	blackjack_round_claim_history.clear()
	blackjack_round_social_resolved = false
	if blackjack_input_line != null:
		blackjack_input_line.clear()
		blackjack_input_line.release_focus()
	state.input_live_text = ""


func _blackjack_min_bet() -> int:
	return BLACKJACK_BET_OPTIONS[0] if not BLACKJACK_BET_OPTIONS.is_empty() else 1


func _blackjack_clamp_selected_bet() -> void:
	var best: int = 0
	for denom in BLACKJACK_BET_OPTIONS:
		if denom <= state.money_balance and denom > best:
			best = denom
	if blackjack_selected_bet > 0 and blackjack_selected_bet <= state.money_balance:
		return
	blackjack_selected_bet = best


func _blackjack_breath_pause(seconds: float) -> bool:
	if seconds <= 0.0:
		return blackjack_active
	await get_tree().create_timer(seconds).timeout
	if not blackjack_active:
		blackjack_animating = false
		return false
	return true


func _on_blackjack_bet_chip_pressed(denom: int) -> void:
	if not blackjack_active:
		return
	if denom <= 0:
		return
	if denom > state.money_balance:
		if has_method("_show_notify"):
			call("_show_notify", "余额不足，无法选择%s下注。" % _money_text(denom))
		return
	blackjack_selected_bet = denom
	if blackjack_round_over or blackjack_player_cards.is_empty():
		blackjack_status_text = "已选择下注 %s，按 Enter 或 Space 开始下一局。" % _money_text(blackjack_selected_bet)
	else:
		blackjack_status_text = "已切换下注 %s，将在下一局生效。" % _money_text(blackjack_selected_bet)
	_blackjack_refresh_panel()


func _open_blackjack_game() -> void:
	if blackjack_panel == null:
		if has_method("_show_notify"):
			call("_show_notify", "21点面板未绑定，无法开始。")
		return
	if blackjack_selected_bet <= 0:
		blackjack_selected_bet = BLACKJACK_DEFAULT_BET
	_blackjack_clamp_selected_bet()
	if blackjack_selected_bet <= 0:
		if has_method("_show_notify"):
			call("_show_notify", "余额不足，无法开始21点。")
		return
	blackjack_round_bet = blackjack_selected_bet
	blackjack_active = true
	blackjack_round_over = false
	blackjack_reveal_dealer = false
	blackjack_animating = false
	blackjack_status_text = ""
	blackjack_discard_visual_locked = false
	blackjack_last_player_count = 0
	blackjack_last_dealer_count = 0
	blackjack_last_reveal_dealer = false
	blackjack_round_money_applied = false
	blackjack_last_money_delta = 0
	blackjack_rules_open = false
	_blackjack_reset_social_round_state()
	blackjack_status_text = "请选择筹码并开始。当前下注 %s" % _money_text(blackjack_selected_bet)
	if state.room_nav_open:
		state.room_nav_open = false
		if has_method("_refresh_room_nav_ui"):
			call("_refresh_room_nav_ui")
	if typing_active:
		_complete_typewriter()
	if dialogue_label != null:
		dialogue_label.text = ""
	if speaker_label != null:
		speaker_label.visible = false
		speaker_label.text = ""
	if input_line != null:
		input_line.clear()
	if blackjack_deck.is_empty() and blackjack_discard_cards.is_empty():
		_blackjack_reset_deck()
	blackjack_panel.visible = true
	_blackjack_refresh_deck_visual()
	_blackjack_pop_panel()
	_sync_period_music(0.4)
	_blackjack_start_round()
	_update_interaction_state(false)


func _close_blackjack_game(show_notify: bool = true) -> void:
	if not blackjack_active and (blackjack_panel == null or not blackjack_panel.visible):
		return
	blackjack_active = false
	blackjack_round_over = false
	blackjack_reveal_dealer = false
	blackjack_animating = false
	blackjack_status_text = ""
	blackjack_discard_visual_locked = false
	_blackjack_archive_current_round_cards(false)
	blackjack_player_cards.clear()
	blackjack_dealer_cards.clear()
	blackjack_last_player_count = 0
	blackjack_last_dealer_count = 0
	blackjack_last_reveal_dealer = false
	blackjack_round_money_applied = false
	blackjack_last_money_delta = 0
	blackjack_rules_open = false
	_blackjack_reset_social_round_state()
	if blackjack_draw_particles != null:
		blackjack_draw_particles.emitting = false
	if blackjack_result_particles != null:
		blackjack_result_particles.emitting = false
	if blackjack_panel != null:
		blackjack_panel.visible = false
	_blackjack_refresh_deck_visual()
	_sync_period_music(0.4)
	_update_interaction_state(false)
	if show_notify and has_method("_show_notify"):
		call("_show_notify", "已结束21点。")


func _blackjack_start_round() -> void:
	if not blackjack_active:
		return
	_blackjack_clamp_selected_bet()
	if blackjack_selected_bet <= 0:
		blackjack_round_over = true
		blackjack_animating = false
		blackjack_status_text = "余额不足，无法开始新一局。"
		_blackjack_refresh_panel()
		return
	blackjack_round_bet = blackjack_selected_bet
	_blackjack_reset_transient_visual_state()
	var archive_delay: float = _blackjack_archive_current_round_cards(true)
	if blackjack_deck.size() < 4:
		if not _blackjack_rebuild_deck_from_discard():
			_blackjack_reset_deck()
	blackjack_player_cards.clear()
	blackjack_dealer_cards.clear()
	blackjack_reveal_dealer = false
	blackjack_round_over = false
	blackjack_animating = true
	blackjack_last_player_count = 0
	blackjack_last_dealer_count = 0
	blackjack_last_reveal_dealer = false
	blackjack_round_money_applied = false
	blackjack_last_money_delta = 0
	_blackjack_reset_social_round_state()
	blackjack_status_text = "正在洗牌... 本局下注 %s" % _money_text(blackjack_round_bet)
	_blackjack_refresh_panel()
	var first_deal_delay: float = maxf(0.32, archive_delay + 0.16)
	if not (await _blackjack_breath_pause(first_deal_delay)):
		return
	blackjack_status_text = "发牌中... 本局下注 %s" % _money_text(blackjack_round_bet)
	blackjack_player_cards.append(_blackjack_draw_card())
	_blackjack_panel_punch()
	_blackjack_refresh_panel()
	if not (await _blackjack_breath_pause(BLACKJACK_DEAL_STEP_DELAY)):
		return
	blackjack_dealer_cards.append(_blackjack_draw_card())
	_blackjack_panel_punch()
	_blackjack_refresh_panel()
	if not (await _blackjack_breath_pause(BLACKJACK_DEAL_STEP_DELAY)):
		return
	blackjack_player_cards.append(_blackjack_draw_card())
	_blackjack_panel_punch()
	_blackjack_refresh_panel()
	if not (await _blackjack_breath_pause(BLACKJACK_DEAL_STEP_DELAY)):
		return
	blackjack_dealer_cards.append(_blackjack_draw_card())
	_blackjack_panel_punch()
	_blackjack_refresh_panel()
	if not (await _blackjack_breath_pause(BLACKJACK_DEAL_SETTLE_DELAY)):
		return

	var player_points: int = _blackjack_hand_value(blackjack_player_cards)
	var dealer_points: int = _blackjack_hand_value(blackjack_dealer_cards)
	if player_points == BLACKJACK_TARGET or dealer_points == BLACKJACK_TARGET:
		blackjack_reveal_dealer = true
		blackjack_status_text = "亮牌确认中..."
		_blackjack_refresh_panel()
		if not (await _blackjack_breath_pause(BLACKJACK_REVEAL_PAUSE)):
			return
		if player_points == BLACKJACK_TARGET and dealer_points == BLACKJACK_TARGET:
			_blackjack_apply_round_outcome("draw", "双方都是21点，平局。")
		elif player_points == BLACKJACK_TARGET:
			_blackjack_apply_round_outcome("win", "黑杰克！你赢了。", true)
		else:
			_blackjack_apply_round_outcome("lose", "庄家黑杰克，这局你输了。")
	else:
		blackjack_animating = false
		blackjack_status_text = "发牌完成：要牌或停牌（本局下注 %s）。" % _money_text(blackjack_round_bet)
		_blackjack_refresh_panel()


func _blackjack_reset_deck() -> void:
	blackjack_deck.clear()
	blackjack_discard_cards.clear()
	blackjack_discard_visual_locked = false
	for suit_idx in range(4):
		for rank in range(1, 14):
			blackjack_deck.append({
				"rank": rank,
				"suit": suit_idx
			})
	for i in range(blackjack_deck.size() - 1, 0, -1):
		var swap_idx: int = rng.randi_range(0, i)
		var temp_card: Dictionary = blackjack_deck[i]
		blackjack_deck[i] = blackjack_deck[swap_idx]
		blackjack_deck[swap_idx] = temp_card
	_blackjack_refresh_deck_visual()


func _blackjack_rebuild_deck_from_discard() -> bool:
	if blackjack_discard_cards.is_empty():
		return false
	blackjack_deck.clear()
	for card in blackjack_discard_cards:
		blackjack_deck.append(card.duplicate(true))
	blackjack_discard_cards.clear()
	for i in range(blackjack_deck.size() - 1, 0, -1):
		var swap_idx: int = rng.randi_range(0, i)
		var temp_card: Dictionary = blackjack_deck[i]
		blackjack_deck[i] = blackjack_deck[swap_idx]
		blackjack_deck[swap_idx] = temp_card
	_blackjack_refresh_deck_visual()
	if has_method("_show_notify"):
		call("_show_notify", "牌堆用尽，已自动洗牌继续。")
	return true


func _blackjack_archive_current_round_cards(animate: bool = true) -> float:
	if blackjack_player_cards.is_empty() and blackjack_dealer_cards.is_empty():
		return 0.0
	var archive_count: int = blackjack_player_cards.size() + blackjack_dealer_cards.size()
	var source_points: Array[Vector2] = _blackjack_collect_archive_source_points()
	for card in blackjack_player_cards:
		blackjack_discard_cards.append(card.duplicate(true))
	for card2 in blackjack_dealer_cards:
		blackjack_discard_cards.append(card2.duplicate(true))
	if (not animate) or archive_count <= 0:
		blackjack_discard_visual_locked = false
		_blackjack_refresh_deck_visual()
		return 0.0
	blackjack_discard_visual_locked = true
	_blackjack_animate_archive_to_discard(source_points, archive_count)
	var refresh_delay: float = BLACKJACK_DISCARD_FLY_DURATION + BLACKJACK_DISCARD_FLY_STAGGER * 2.0 + 0.16
	_blackjack_schedule_unlock_discard_visual(refresh_delay)
	return refresh_delay


func _blackjack_draw_card() -> Dictionary:
	if blackjack_deck.is_empty():
		if not _blackjack_rebuild_deck_from_discard():
			_blackjack_reset_deck()
	if blackjack_deck.is_empty():
		return {"rank": 1, "suit": 0}
	var last_idx: int = blackjack_deck.size() - 1
	var card: Dictionary = blackjack_deck[last_idx]
	blackjack_deck.remove_at(last_idx)
	if has_method("_play_blackjack_deal_sfx"):
		call("_play_blackjack_deal_sfx")
	_blackjack_refresh_deck_visual()
	_blackjack_pulse_deck_stack()
	var deck_edge: Vector2 = _blackjack_card_edge_point(_blackjack_deck_world_position(), Vector2.LEFT)
	_blackjack_emit_draw_particles(deck_edge, Color(0.84, 0.90, 1.0, 1.0), 0.7, Vector2.LEFT)
	return card


func _blackjack_hand_value(cards: Array[Dictionary]) -> int:
	var total: int = 0
	var aces: int = 0
	for card in cards:
		var rank: int = int(card.get("rank", 1))
		if rank == 1:
			total += 11
			aces += 1
		elif rank >= 10:
			total += 10
		else:
			total += rank
	while total > BLACKJACK_TARGET and aces > 0:
		total -= 10
		aces -= 1
	return total


func _blackjack_card_rank_text(rank: int) -> String:
	match rank:
		1:
			return "A"
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
		_:
			return str(rank)


func _blackjack_card_suit_symbol(suit: int) -> String:
	match suit:
		0:
			return "♠"
		1:
			return "♥"
		2:
			return "♣"
		3:
			return "♦"
		_:
			return "♠"


func _blackjack_card_suit_color(suit: int) -> Color:
	if suit == 1 or suit == 3:
		return Color(0.92, 0.24, 0.24, 1.0)
	return Color(0.10, 0.10, 0.10, 1.0)


func _blackjack_cards_to_text(cards: Array[Dictionary], hide_last: bool = false) -> String:
	if cards.is_empty():
		return "-"
	var parts: Array[String] = []
	for idx in range(cards.size()):
		if hide_last and idx == cards.size() - 1:
			parts.append("【??】")
		else:
			var card: Dictionary = cards[idx]
			var rank: int = int(card.get("rank", 1))
			var suit: int = int(card.get("suit", 0))
			parts.append("【%s%s】" % [_blackjack_card_suit_symbol(suit), _blackjack_card_rank_text(rank)])
	return " ".join(parts)


func _blackjack_card_display(card: Dictionary) -> String:
	var rank: int = int(card.get("rank", 1))
	var suit: int = int(card.get("suit", 0))
	return "%s%s" % [_blackjack_card_suit_symbol(suit), _blackjack_card_rank_text(rank)]


func _blackjack_make_card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = BLACKJACK_CARD_CORNER
	style.corner_radius_top_right = BLACKJACK_CARD_CORNER
	style.corner_radius_bottom_left = BLACKJACK_CARD_CORNER
	style.corner_radius_bottom_right = BLACKJACK_CARD_CORNER
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	style.shadow_size = 11
	style.shadow_offset = Vector2(0.0, 5.0)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _blackjack_build_stack_card(
	index: int,
	stack_count: int,
	bg_color: Color,
	border_color: Color,
	symbol_color: Color,
	is_discard: bool = false
) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(BLACKJACK_CARD_WIDTH, BLACKJACK_CARD_HEIGHT)
	card.size = card.custom_minimum_size
	card.pivot_offset = card.custom_minimum_size * 0.5
	var depth_index: int = stack_count - index - 1
	card.position = Vector2(10.0 + float(depth_index) * 4.0, 22.0 - float(depth_index) * 3.0)
	if is_discard:
		card.rotation_degrees = 2.0 - float(depth_index) * 0.6
	else:
		card.rotation_degrees = -2.0 + float(depth_index) * 0.6
	card.add_theme_stylebox_override(
		"panel",
		_blackjack_make_card_style(bg_color, border_color)
	)
	var symbol: Label = Label.new()
	symbol.text = "✦"
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ui_font != null:
		symbol.add_theme_font_override("font", ui_font)
	symbol.add_theme_font_size_override("font_size", 42)
	symbol.add_theme_color_override("font_color", symbol_color)
	card.add_child(symbol)
	return card


func _blackjack_refresh_deck_visual() -> void:
	_blackjack_reposition_deck_area()
	if blackjack_deck_stack_layer != null:
		while blackjack_deck_stack_layer.get_child_count() > 0:
			var stale: Node = blackjack_deck_stack_layer.get_child(blackjack_deck_stack_layer.get_child_count() - 1)
			blackjack_deck_stack_layer.remove_child(stale)
			stale.queue_free()
		var remain: int = blackjack_deck.size()
		var stack_count: int = 0
		if remain > 0:
			stack_count = clampi(ceili(float(remain) / 13.0), 1, 4)
		for i in range(stack_count):
			blackjack_deck_stack_layer.add_child(
				_blackjack_build_stack_card(
					i,
					stack_count,
					Color(0.12, 0.16, 0.28, 1.0),
					Color(0.70, 0.78, 0.98, 0.95),
					Color(0.90, 0.94, 1.0, 0.95)
				)
			)
	if blackjack_discard_stack_layer != null:
		if not blackjack_discard_visual_locked:
			while blackjack_discard_stack_layer.get_child_count() > 0:
				var stale2: Node = blackjack_discard_stack_layer.get_child(blackjack_discard_stack_layer.get_child_count() - 1)
				blackjack_discard_stack_layer.remove_child(stale2)
				stale2.queue_free()
			var used_count: int = blackjack_discard_cards.size()
			var discard_stack_count: int = 0
			if used_count > 0:
				discard_stack_count = clampi(ceili(float(used_count) / 13.0), 1, 4)
			if discard_stack_count <= 0:
				var empty_discard: PanelContainer = _blackjack_build_stack_card(
					0,
					1,
					Color(0.12, 0.12, 0.12, 0.28),
					Color(0.80, 0.80, 0.80, 0.30),
					Color(0.95, 0.95, 0.95, 0.35),
					true
				)
				empty_discard.modulate = Color(1.0, 1.0, 1.0, 0.45)
				blackjack_discard_stack_layer.add_child(empty_discard)
			else:
				for j in range(discard_stack_count):
					blackjack_discard_stack_layer.add_child(
						_blackjack_build_stack_card(
							j,
							discard_stack_count,
							Color(0.24, 0.13, 0.13, 1.0),
							Color(0.96, 0.70, 0.70, 0.96),
							Color(1.0, 0.90, 0.90, 0.98),
							true
						)
					)
	if blackjack_deck_count_label != null:
		blackjack_deck_count_label.text = "牌堆 %s · 弃牌 %s" % [str(blackjack_deck.size()), str(blackjack_discard_cards.size())]


func _blackjack_reposition_deck_area() -> void:
	if blackjack_panel == null or blackjack_deck_area == null:
		return
	blackjack_deck_area.set_as_top_level(true)
	var panel_size: Vector2 = blackjack_panel.size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = get_viewport().get_visible_rect().size
	var panel_origin: Vector2 = blackjack_panel.get_global_transform().origin
	var deck_area_size: Vector2 = panel_size
	blackjack_deck_area.size = deck_area_size
	var area_global: Vector2 = panel_origin
	blackjack_deck_area.global_position = area_global
	var stack_size: Vector2 = Vector2(172.0, 236.0)
	var stack_top: float = area_global.y + deck_area_size.y * 0.5 - stack_size.y * 0.5
	var side_margin: float = 76.0
	if blackjack_deck_stack_layer != null:
		blackjack_deck_stack_layer.set_as_top_level(true)
		blackjack_deck_stack_layer.size = stack_size
		blackjack_deck_stack_layer.global_position = Vector2(area_global.x + side_margin, stack_top)
	if blackjack_discard_stack_layer != null:
		blackjack_discard_stack_layer.set_as_top_level(true)
		blackjack_discard_stack_layer.size = stack_size
		blackjack_discard_stack_layer.global_position = Vector2(
			area_global.x + deck_area_size.x - side_margin - stack_size.x,
			stack_top
		)
	if blackjack_deck_count_label != null:
		blackjack_deck_count_label.set_as_top_level(true)
		var label_size: Vector2 = Vector2(320.0, 34.0)
		blackjack_deck_count_label.size = label_size
		var label_x: float = area_global.x + deck_area_size.x - side_margin - label_size.x
		var label_y: float = stack_top - label_size.y - 10.0
		label_y = maxf(area_global.y + 8.0, label_y)
		blackjack_deck_count_label.global_position = Vector2(
			label_x,
			label_y
		)


func _blackjack_schedule_unlock_discard_visual(delay: float) -> void:
	if not is_inside_tree():
		return
	var safe_delay: float = maxf(0.0, delay)
	blackjack_refresh_token += 1
	var token: int = blackjack_refresh_token
	get_tree().create_timer(safe_delay).timeout.connect(
		Callable(self, "_blackjack_unlock_discard_visual_if_token").bind(token),
		CONNECT_ONE_SHOT
	)


func _blackjack_unlock_discard_visual_if_token(token: int) -> void:
	if token != blackjack_refresh_token:
		return
	blackjack_discard_visual_locked = false
	_blackjack_refresh_deck_visual()


func _blackjack_pulse_deck_stack() -> void:
	if blackjack_deck_stack_layer == null:
		return
	var count: int = blackjack_deck_stack_layer.get_child_count()
	if count <= 0:
		return
	var top_v: Variant = blackjack_deck_stack_layer.get_child(count - 1)
	if not (top_v is Control):
		return
	var top_card: Control = top_v as Control
	top_card.scale = Vector2(1.06, 1.06)
	top_card.modulate = Color(1.0, 1.0, 1.0, 0.84)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(top_card, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(top_card, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)


func _blackjack_deck_world_position() -> Vector2:
	if blackjack_deck_stack_layer != null and blackjack_deck_stack_layer.get_child_count() > 0:
		var top_v: Variant = blackjack_deck_stack_layer.get_child(blackjack_deck_stack_layer.get_child_count() - 1)
		if top_v is Control:
			var top_card: Control = top_v as Control
			return top_card.get_global_transform().origin + top_card.size * 0.5
	if blackjack_deck_area != null:
		return blackjack_deck_area.get_global_transform().origin + blackjack_deck_area.size * 0.5
	if blackjack_panel != null:
		return blackjack_panel.get_global_transform().origin + blackjack_panel.size * 0.5
	return Vector2.ZERO


func _blackjack_discard_world_position() -> Vector2:
	if blackjack_discard_stack_layer != null and blackjack_discard_stack_layer.get_child_count() > 0:
		var top_v: Variant = blackjack_discard_stack_layer.get_child(blackjack_discard_stack_layer.get_child_count() - 1)
		if top_v is Control:
			var top_card: Control = top_v as Control
			return top_card.get_global_transform().origin + top_card.size * 0.5
	if blackjack_discard_stack_layer != null:
		return blackjack_discard_stack_layer.get_global_transform().origin + blackjack_discard_stack_layer.size * 0.5
	if blackjack_deck_area != null:
		return blackjack_deck_area.get_global_transform().origin + blackjack_deck_area.size * Vector2(0.78, 0.5)
	return _blackjack_deck_world_position() + Vector2(160.0, 0.0)


func _blackjack_collect_archive_source_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	_blackjack_append_area_card_centers(blackjack_player_cards_area, points)
	_blackjack_append_area_card_centers(blackjack_dealer_cards_area, points)
	if points.is_empty():
		points.append(_blackjack_deck_world_position())
	return points


func _blackjack_append_area_card_centers(area: Control, points: Array[Vector2]) -> void:
	if area == null:
		return
	var has_card: bool = false
	for node in area.get_children():
		if node is Control:
			var card: Control = node as Control
			points.append(card.get_global_transform().origin + card.size * 0.5)
			has_card = true
	if not has_card:
		points.append(area.get_global_transform().origin + area.size * 0.5)


func _blackjack_animate_archive_to_discard(source_points: Array[Vector2], archive_count: int) -> void:
	if archive_count <= 0 or blackjack_panel == null:
		return
	_blackjack_reposition_deck_area()
	var points: Array[Vector2] = source_points
	if points.is_empty():
		points.append(_blackjack_deck_world_position())
	var animate_count: int = mini(archive_count, 10)
	for i in range(animate_count):
		var src_base: Vector2 = points[i % points.size()]
		_blackjack_spawn_discard_fly_card(src_base, i)


func _blackjack_spawn_discard_fly_card(start_world: Vector2, order: int) -> void:
	if blackjack_discard_stack_layer == null:
		return
	var half_size: Vector2 = Vector2(BLACKJACK_CARD_WIDTH * 0.5, BLACKJACK_CARD_HEIGHT * 0.5)
	var area_xform: Transform2D = blackjack_discard_stack_layer.get_global_transform()
	var area_inv: Transform2D = area_xform.affine_inverse()
	var start_local: Vector2 = area_inv * start_world - half_size
	var fly_card: PanelContainer = _blackjack_build_stack_card(
		0,
		1,
		Color(0.24, 0.13, 0.13, 1.0),
		Color(0.96, 0.70, 0.70, 0.96),
		Color(1.0, 0.90, 0.90, 0.98),
		true
	)
	fly_card.z_index = 34
	fly_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_card.position = Vector2(10.0, 22.0)
	fly_card.rotation_degrees = 2.0
	fly_card.set_meta("card_index", order)
	blackjack_discard_stack_layer.add_child(fly_card)
	var delay: float = 0.04 + float(order % 3) * 0.06
	_blackjack_animate_draw_to_slot(fly_card, blackjack_discard_stack_layer, start_local, delay)
	var cleanup_delay: float = delay + BLACKJACK_DISCARD_FLY_DURATION + 0.06
	get_tree().create_timer(cleanup_delay).timeout.connect(
		Callable(self, "_blackjack_queue_free_if_valid").bind(fly_card),
		CONNECT_ONE_SHOT
	)


func _blackjack_queue_free_if_valid(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


func _blackjack_card_edge_point(world_center: Vector2, direction: Vector2) -> Vector2:
	var dir: Vector2 = direction
	if dir.length() <= 0.001:
		dir = Vector2.LEFT
	else:
		dir = dir.normalized()
	var rx: float = BLACKJACK_CARD_WIDTH * 0.5
	var ry: float = BLACKJACK_CARD_HEIGHT * 0.5
	var k: float = 1.0 / maxf(absf(dir.x) / rx, absf(dir.y) / ry)
	return world_center + dir * k


func _blackjack_local_edge_offset(direction: Vector2) -> Vector2:
	var dir: Vector2 = direction
	if dir.length() <= 0.001:
		dir = Vector2.LEFT
	else:
		dir = dir.normalized()
	var rx: float = BLACKJACK_CARD_WIDTH * 0.5
	var ry: float = BLACKJACK_CARD_HEIGHT * 0.5
	var k: float = 1.0 / maxf(absf(dir.x) / rx, absf(dir.y) / ry)
	return dir * k


func _blackjack_spawn_draw_trail(start_world: Vector2, mid_world: Vector2, end_world: Vector2, tint: Color) -> void:
	if blackjack_panel == null:
		return
	var panel_inv: Transform2D = blackjack_panel.get_global_transform().affine_inverse()
	var trail: Line2D = Line2D.new()
	trail.z_index = 29
	trail.width = 9.0
	trail.default_color = Color(tint.r, tint.g, tint.b, 0.62)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.antialiased = true
	var segment_count: int = 16
	for i in range(segment_count + 1):
		var t: float = float(i) / float(segment_count)
		var world_point: Vector2 = _blackjack_quadratic_bezier(start_world, mid_world, end_world, t)
		trail.add_point(panel_inv * world_point)
	blackjack_panel.add_child(trail)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(trail, "modulate:a", 0.18, 0.05)
	tween.chain().tween_property(trail, "modulate:a", 0.0, 0.24)
	tween.parallel().tween_property(trail, "width", 2.0, 0.24)
	tween.chain().tween_callback(Callable(trail, "queue_free"))


func _blackjack_start_flight_trail(card_node: Control, flight_dir: Vector2, tint: Color) -> void:
	if card_node == null:
		return
	if card_node.has_meta("flight_trail"):
		var old_trail_v: Variant = card_node.get_meta("flight_trail")
		if old_trail_v is GPUParticles2D:
			(old_trail_v as GPUParticles2D).queue_free()
	var emitter: GPUParticles2D = GPUParticles2D.new()
	emitter.name = "飞行轨迹粒子"
	emitter.z_index = -1
	emitter.amount = 48
	emitter.lifetime = 0.28
	emitter.one_shot = false
	emitter.local_coords = false
	var center: Vector2 = Vector2(BLACKJACK_CARD_WIDTH * 0.5, BLACKJACK_CARD_HEIGHT * 0.5)
	emitter.position = center + _blackjack_local_edge_offset(-flight_dir)
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	var dir_norm: Vector2 = (-flight_dir).normalized()
	if dir_norm.length() <= 0.001:
		dir_norm = Vector2.RIGHT
	mat.direction = Vector3(dir_norm.x, dir_norm.y, 0.0)
	mat.spread = 20.0
	mat.gravity = Vector3(0.0, 0.0, 0.0)
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 88.0
	mat.scale_min = 0.30
	mat.scale_max = 0.88
	mat.color = Color(tint.r, tint.g, tint.b, 0.86)
	emitter.process_material = mat
	card_node.add_child(emitter)
	card_node.set_meta("flight_trail", emitter)
	emitter.emitting = true


func _blackjack_stop_flight_trail(card_node: Control) -> void:
	if card_node == null:
		return
	if not card_node.has_meta("flight_trail"):
		return
	var trail_v: Variant = card_node.get_meta("flight_trail")
	if not (trail_v is GPUParticles2D):
		return
	var emitter: GPUParticles2D = trail_v as GPUParticles2D
	card_node.set_meta("flight_trail", null)
	emitter.emitting = false
	var tween: Tween = create_tween()
	tween.tween_interval(0.20)
	tween.tween_callback(Callable(emitter, "queue_free"))


func _blackjack_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t)


func _blackjack_set_card_flight_position(t: float, card_node: Control, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	if card_node == null:
		return
	card_node.position = _blackjack_quadratic_bezier(p0, p1, p2, clampf(t, 0.0, 1.0))


func _blackjack_emit_draw_particles(world_pos: Vector2, tint: Color = Color(0.92, 0.96, 1.0, 1.0), amount_scale: float = 1.0, burst_direction: Vector2 = Vector2.UP) -> void:
	if blackjack_draw_particles == null:
		return
	blackjack_draw_particles.global_position = world_pos
	if blackjack_draw_particles.process_material is ParticleProcessMaterial:
		var draw_material: ParticleProcessMaterial = blackjack_draw_particles.process_material as ParticleProcessMaterial
		draw_material.color = tint
		var dir: Vector2 = burst_direction
		if dir.length() <= 0.001:
			dir = Vector2.UP
		else:
			dir = dir.normalized()
		draw_material.direction = Vector3(dir.x, dir.y, 0.0)
	blackjack_draw_particles.amount = maxi(10, int(roundf(28.0 * maxf(0.35, amount_scale))))
	blackjack_draw_particles.emitting = false
	blackjack_draw_particles.restart()
	blackjack_draw_particles.emitting = true


func _blackjack_build_card_face(card: Dictionary, hidden: bool, is_dealer: bool = false) -> PanelContainer:
	var face: PanelContainer = PanelContainer.new()
	face.custom_minimum_size = Vector2(BLACKJACK_CARD_WIDTH, BLACKJACK_CARD_HEIGHT)
	face.size = face.custom_minimum_size
	face.mouse_filter = Control.MOUSE_FILTER_STOP
	face.pivot_offset = face.custom_minimum_size * 0.5
	face.set_meta("is_dealer_card", is_dealer)

	var front: Control = Control.new()
	front.name = "正面层"
	front.set_anchors_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(front)

	var inner_frame: Panel = Panel.new()
	inner_frame.name = "card_inner_frame"
	inner_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_frame.offset_left = 7.0
	inner_frame.offset_top = 7.0
	inner_frame.offset_right = -7.0
	inner_frame.offset_bottom = -7.0
	var inner_style: StyleBoxFlat = StyleBoxFlat.new()
	inner_style.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	inner_style.border_color = Color(0.72, 0.70, 0.64, 0.34)
	inner_style.set_border_width_all(1)
	inner_style.corner_radius_top_left = 8
	inner_style.corner_radius_top_right = 8
	inner_style.corner_radius_bottom_left = 8
	inner_style.corner_radius_bottom_right = 8
	inner_frame.add_theme_stylebox_override("panel", inner_style)
	front.add_child(inner_frame)

	var corner_left: Label = Label.new()
	corner_left.name = "角标左上"
	corner_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	corner_left.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	corner_left.position = Vector2(10.0, 8.0)
	corner_left.size = Vector2(54.0, 42.0)
	corner_left.autowrap_mode = TextServer.AUTOWRAP_OFF
	front.add_child(corner_left)

	var center: Label = Label.new()
	center.name = "中心字"
	center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.autowrap_mode = TextServer.AUTOWRAP_OFF
	front.add_child(center)

	var corner_right: Label = Label.new()
	corner_right.name = "角标右下"
	corner_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner_right.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	corner_right.position = Vector2(BLACKJACK_CARD_WIDTH - 64.0, BLACKJACK_CARD_HEIGHT - 54.0)
	corner_right.size = Vector2(54.0, 42.0)
	corner_right.rotation_degrees = 180.0
	corner_right.autowrap_mode = TextServer.AUTOWRAP_OFF
	front.add_child(corner_right)

	var back: ColorRect = ColorRect.new()
	back.name = "背面层"
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.offset_left = 7.0
	back.offset_top = 7.0
	back.offset_right = -7.0
	back.offset_bottom = -7.0
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(back)

	var back_frame: Panel = Panel.new()
	back_frame.name = "card_back_frame"
	back_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	var back_frame_style: StyleBoxFlat = StyleBoxFlat.new()
	back_frame_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	back_frame_style.border_color = Color(0.78, 0.84, 1.0, 0.26)
	back_frame_style.set_border_width_all(2)
	back_frame_style.corner_radius_top_left = 7
	back_frame_style.corner_radius_top_right = 7
	back_frame_style.corner_radius_bottom_left = 7
	back_frame_style.corner_radius_bottom_right = 7
	back_frame.add_theme_stylebox_override("panel", back_frame_style)
	back.add_child(back_frame)

	var back_symbol: Label = Label.new()
	back_symbol.name = "背面图案"
	back_symbol.text = "✦"
	back_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back_symbol.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(back_symbol)

	for label in [corner_left, center, corner_right, back_symbol]:
		if ui_font != null:
			label.add_theme_font_override("font", ui_font)
	corner_left.add_theme_font_size_override("font_size", 23)
	center.add_theme_font_size_override("font_size", 56)
	corner_right.add_theme_font_size_override("font_size", 23)
	back_symbol.add_theme_font_size_override("font_size", 52)
	_blackjack_apply_card_visual(face, card, hidden)

	var hover_enter_callable: Callable = Callable(self, "_on_blackjack_card_hover_enter").bind(face)
	if not face.mouse_entered.is_connected(hover_enter_callable):
		face.mouse_entered.connect(hover_enter_callable)
	var hover_exit_callable: Callable = Callable(self, "_on_blackjack_card_hover_exit").bind(face)
	if not face.mouse_exited.is_connected(hover_exit_callable):
		face.mouse_exited.connect(hover_exit_callable)
	return face


func _blackjack_apply_card_visual(card_node: PanelContainer, card: Dictionary, hidden: bool) -> void:
	if card_node == null:
		return
	var front_v: Node = card_node.get_node_or_null("正面层")
	var back_v: Node = card_node.get_node_or_null("背面层")
	if not (front_v is Control) or not (back_v is ColorRect):
		return
	var front: Control = front_v as Control
	var back: ColorRect = back_v as ColorRect
	var suit: int = int(card.get("suit", 0))
	var rank_text: String = _blackjack_card_rank_text(int(card.get("rank", 1)))
	var suit_text: String = _blackjack_card_suit_symbol(suit)
	var suit_color: Color = _blackjack_card_suit_color(suit)
	var front_bg: Color = Color(0.995, 0.982, 0.940, 1.0)
	var front_border: Color = Color(0.70, 0.66, 0.56, 1.0)
	var back_bg: Color = Color(0.055, 0.095, 0.180, 1.0)
	var back_border: Color = Color(0.56, 0.66, 0.92, 0.82)
	if hidden:
		card_node.add_theme_stylebox_override("panel", _blackjack_make_card_style(back_bg, back_border))
	else:
		card_node.add_theme_stylebox_override("panel", _blackjack_make_card_style(front_bg, front_border))
	back.color = Color(0.08, 0.13, 0.25, 0.96)
	back.add_theme_color_override("color", Color(0.08, 0.13, 0.25, 0.96))
	var corner_left_v: Node = front.get_node_or_null("角标左上")
	var center_v: Node = front.get_node_or_null("中心字")
	var corner_right_v: Node = front.get_node_or_null("角标右下")
	var back_symbol_v: Node = back.get_node_or_null("背面图案")
	if corner_left_v is Label:
		var left_label: Label = corner_left_v as Label
		left_label.text = "%s\n%s" % [rank_text, suit_text]
		left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left_label.add_theme_color_override("font_color", suit_color)
		left_label.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.92, 0.58))
		left_label.add_theme_constant_override("outline_size", 1)
	if center_v is Label:
		var center_label: Label = center_v as Label
		center_label.text = suit_text
		center_label.add_theme_color_override("font_color", suit_color)
		center_label.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.92, 0.42))
		center_label.add_theme_constant_override("outline_size", 1)
		center_label.add_theme_font_size_override("font_size", 50)
	if corner_right_v is Label:
		var right_label: Label = corner_right_v as Label
		right_label.text = ""
		right_label.visible = false
	if back_symbol_v is Label:
		var back_symbol: Label = back_symbol_v as Label
		back_symbol.text = "✦"
		back_symbol.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.92))
		back_symbol.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.09, 0.80))
		back_symbol.add_theme_constant_override("outline_size", 2)
	front.visible = not hidden
	back.visible = hidden
	card_node.set_meta("face_down", hidden)


func _blackjack_layout_cards(area: Control, animate: bool = true) -> void:
	if area == null:
		return
	var cards: Array = area.get_children()
	var count: int = cards.size()
	if count <= 0:
		return
	var card_w: float = BLACKJACK_CARD_WIDTH
	var card_h: float = BLACKJACK_CARD_HEIGHT
	var max_span: float = maxf(320.0, area.size.x - 40.0)
	var step: float = 92.0
	if count > 1:
		step = minf(step, (max_span - card_w) / float(count - 1))
	step = clampf(step, 44.0, 92.0)
	var span: float = card_w + step * float(maxi(0, count - 1))
	var start_x: float = (area.size.x - span) * 0.5
	var base_y: float = (area.size.y - card_h) * 0.5
	var mid: float = float(count - 1) * 0.5
	for i in range(count):
		var node_v: Variant = cards[i]
		if not (node_v is Control):
			continue
		var node: Control = node_v as Control
		var depth_offset: float = absf(float(i) - mid) * 3.0
		var target_pos: Vector2 = Vector2(roundf(start_x + float(i) * step), roundf(base_y + depth_offset))
		var target_rot: float = (float(i) - mid) * 5.4
		node.set_meta("base_pos", target_pos)
		node.set_meta("base_rot", target_rot)
		if bool(node.get_meta("hovered", false)):
			continue
		if animate:
			var tween: Tween = create_tween()
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(node, "position", target_pos, 0.16)
			tween.parallel().tween_property(node, "rotation_degrees", target_rot, 0.16)
		else:
			node.position = target_pos
			node.rotation_degrees = target_rot


func _blackjack_deck_anchor_in_area(area: Control) -> Vector2:
	if area == null:
		return Vector2.ZERO
	if blackjack_deck_stack_layer != null and blackjack_deck_stack_layer.get_child_count() > 0:
		var top_node_v: Variant = blackjack_deck_stack_layer.get_child(blackjack_deck_stack_layer.get_child_count() - 1)
		if top_node_v is Control:
			var top_node: Control = top_node_v as Control
			var top_global: Vector2 = top_node.get_global_transform().origin
			var area_global_xform: Transform2D = area.get_global_transform()
			return area_global_xform.affine_inverse() * top_global
	if blackjack_deck_stack_layer != null:
		var stack_anchor: Vector2 = Vector2(
			blackjack_deck_stack_layer.size.x * 0.5 - BLACKJACK_CARD_WIDTH * 0.5,
			blackjack_deck_stack_layer.size.y * 0.5 - BLACKJACK_CARD_HEIGHT * 0.5
		)
		var stack_global_xform: Transform2D = blackjack_deck_stack_layer.get_global_transform()
		var fallback_global: Vector2 = stack_global_xform * stack_anchor
		var fallback_area_xform: Transform2D = area.get_global_transform()
		return fallback_area_xform.affine_inverse() * fallback_global
	if blackjack_panel == null:
		return Vector2(area.size.x * 0.5 - BLACKJACK_CARD_WIDTH * 0.5, 16.0)
	var panel_anchor: Vector2 = Vector2(blackjack_panel.size.x * 0.5 - BLACKJACK_CARD_WIDTH * 0.5, 130.0)
	var panel_global_xform: Transform2D = blackjack_panel.get_global_transform()
	var area_global_xform: Transform2D = area.get_global_transform()
	var global_anchor: Vector2 = panel_global_xform * panel_anchor
	return area_global_xform.affine_inverse() * global_anchor


func _blackjack_animate_draw_to_slot(
	card_node: Control,
	area: Control,
	start_pos_override: Variant = null,
	delay_override: float = -1.0
) -> void:
	if card_node == null or area == null:
		return
	var target_pos: Vector2 = card_node.position
	var target_rot: float = card_node.rotation_degrees
	var start_pos: Vector2 = _blackjack_deck_anchor_in_area(area)
	if start_pos_override is Vector2:
		start_pos = start_pos_override
	card_node.position = start_pos
	card_node.scale = Vector2(0.76, 0.76)
	card_node.rotation_degrees = rng.randf_range(-18.0, 18.0)
	card_node.modulate = Color(1.0, 1.0, 1.0, 0.22)
	var sequence_index: int = int(card_node.get_meta("card_index", 0))
	var draw_delay: float = 0.04 + float(sequence_index % 3) * 0.06
	if delay_override >= 0.0:
		draw_delay = delay_override
	var arc_peak: float = 66.0 + clampf(absf(target_pos.x - start_pos.x) * 0.12, 0.0, 38.0)
	var mid_pos: Vector2 = start_pos.lerp(target_pos, 0.5) + Vector2(0.0, -arc_peak)
	var half_size: Vector2 = Vector2(BLACKJACK_CARD_WIDTH * 0.5, BLACKJACK_CARD_HEIGHT * 0.5)
	var area_xform: Transform2D = area.get_global_transform()
	var start_world: Vector2 = area_xform * (start_pos + half_size)
	var mid_world: Vector2 = area_xform * (mid_pos + half_size)
	var end_world: Vector2 = area_xform * (target_pos + half_size)
	var flight_dir: Vector2 = end_world - start_world
	var start_edge_world: Vector2 = _blackjack_card_edge_point(start_world, flight_dir)
	var end_edge_world: Vector2 = _blackjack_card_edge_point(end_world, -flight_dir)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(draw_delay)
	tween.tween_callback(Callable(self, "_blackjack_spawn_draw_trail").bind(start_edge_world, mid_world, end_edge_world, Color(0.86, 0.92, 1.0, 1.0)))
	tween.parallel().tween_callback(Callable(self, "_blackjack_start_flight_trail").bind(card_node, flight_dir, Color(0.86, 0.92, 1.0, 1.0)))
	tween.parallel().tween_callback(Callable(self, "_blackjack_emit_draw_particles").bind(start_edge_world, Color(0.86, 0.92, 1.0, 1.0), 0.45, -flight_dir))
	tween.tween_method(
		Callable(self, "_blackjack_set_card_flight_position").bind(card_node, start_pos, mid_pos, target_pos),
		0.0,
		1.0,
		BLACKJACK_CARD_FLIGHT_DURATION
	)
	tween.parallel().tween_property(card_node, "scale", Vector2(0.92, 0.92), BLACKJACK_CARD_FLIGHT_DURATION * 0.55)
	tween.parallel().tween_property(card_node, "modulate", Color(1.0, 1.0, 1.0, 0.82), BLACKJACK_CARD_FLIGHT_DURATION * 0.48)
	tween.chain().tween_property(card_node, "scale", Vector2.ONE, BLACKJACK_CARD_SETTLE_DURATION)
	tween.parallel().tween_property(card_node, "rotation_degrees", target_rot, BLACKJACK_CARD_SETTLE_DURATION)
	tween.parallel().tween_property(card_node, "modulate", Color(1.0, 1.0, 1.0, 1.0), BLACKJACK_CARD_SETTLE_DURATION)
	tween.chain().tween_callback(Callable(self, "_blackjack_stop_flight_trail").bind(card_node))
	tween.parallel().tween_callback(Callable(self, "_blackjack_emit_draw_particles").bind(end_edge_world, Color(1.0, 1.0, 1.0, 1.0), 0.52, flight_dir))


func _blackjack_flip_card_to_front(card_node: PanelContainer, card: Dictionary) -> void:
	if card_node == null:
		return
	card_node.scale.x = 1.0
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card_node, "scale", Vector2(0.92, 0.94), 0.10)
	tween.chain().tween_property(card_node, "scale:x", 0.06, 0.14)
	tween.tween_callback(Callable(self, "_blackjack_apply_card_visual").bind(card_node, card, false))
	tween.tween_property(card_node, "scale:x", 1.08, 0.16)
	tween.parallel().tween_property(card_node, "modulate", Color(1.0, 1.0, 1.0, 0.88), 0.10)
	tween.chain().tween_property(card_node, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(card_node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)


func _blackjack_sync_card_area(area: Control, cards: Array[Dictionary], hide_last: bool, is_dealer: bool, previous_count: int, reveal_now: bool) -> void:
	if area == null:
		return
	while area.get_child_count() > cards.size():
		var stale: Node = area.get_child(area.get_child_count() - 1)
		area.remove_child(stale)
		stale.queue_free()
	for idx in range(cards.size()):
		var hidden: bool = hide_last and idx == cards.size() - 1
		var card_node: PanelContainer
		var created_now: bool = false
		if idx < area.get_child_count() and area.get_child(idx) is PanelContainer:
			card_node = area.get_child(idx) as PanelContainer
		else:
			card_node = _blackjack_build_card_face(cards[idx], hidden, is_dealer)
			area.add_child(card_node)
			created_now = true
		var was_hidden: bool = bool(card_node.get_meta("face_down", hidden))
		if created_now:
			_blackjack_apply_card_visual(card_node, cards[idx], hidden)
		elif was_hidden and not hidden:
			_blackjack_flip_card_to_front(card_node, cards[idx])
		else:
			_blackjack_apply_card_visual(card_node, cards[idx], hidden)
		card_node.set_meta("card_data", cards[idx].duplicate(true))
		card_node.set_meta("card_index", idx)
		card_node.set_meta("is_dealer_card", is_dealer)
	_blackjack_layout_cards(area, false)
	var new_from: int = maxi(0, previous_count)
	if cards.size() > new_from:
		for idx2 in range(new_from, cards.size()):
			if idx2 < area.get_child_count() and area.get_child(idx2) is Control:
				_blackjack_animate_draw_to_slot(area.get_child(idx2) as Control, area)
	elif reveal_now:
		# 仅翻开暗牌，不改变位置。
		_blackjack_layout_cards(area, true)


func _blackjack_pulse_last_card(area: Control) -> void:
	if area == null:
		return
	var count: int = area.get_child_count()
	if count <= 0:
		return
	var last_v: Variant = area.get_child(count - 1)
	if not (last_v is Control):
		return
	_blackjack_pulse_label(last_v as Control, Color(1.0, 1.0, 1.0, 1.0), 0.85)


func _on_blackjack_card_hover_enter(card_node: PanelContainer) -> void:
	if card_node == null:
		return
	if not blackjack_active or blackjack_animating:
		return
	if bool(card_node.get_meta("is_dealer_card", false)):
		return
	if bool(card_node.get_meta("face_down", false)):
		return
	card_node.set_meta("hovered", true)
	var base_pos_v: Variant = card_node.get_meta("base_pos", card_node.position)
	var base_pos: Vector2 = card_node.position
	if base_pos_v is Vector2:
		base_pos = base_pos_v
	var base_rot: float = float(card_node.get_meta("base_rot", card_node.rotation_degrees))
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_node, "position", base_pos + Vector2(0.0, -24.0), 0.12)
	tween.parallel().tween_property(card_node, "rotation_degrees", base_rot * 0.35, 0.12)
	tween.parallel().tween_property(card_node, "scale", Vector2(1.10, 1.10), 0.12)


func _on_blackjack_card_hover_exit(card_node: PanelContainer) -> void:
	if card_node == null:
		return
	card_node.set_meta("hovered", false)
	var base_pos_v: Variant = card_node.get_meta("base_pos", card_node.position)
	var base_pos: Vector2 = card_node.position
	if base_pos_v is Vector2:
		base_pos = base_pos_v
	var base_rot: float = float(card_node.get_meta("base_rot", card_node.rotation_degrees))
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_node, "position", base_pos, 0.12)
	tween.parallel().tween_property(card_node, "rotation_degrees", base_rot, 0.12)
	tween.parallel().tween_property(card_node, "scale", Vector2.ONE, 0.12)


func _blackjack_refresh_panel() -> void:
	if blackjack_status_label == null or blackjack_dealer_label == null or blackjack_dealer_cards_label == null:
		return
	if blackjack_player_label == null or blackjack_player_cards_label == null:
		return
	var previous_player_count: int = blackjack_last_player_count
	var previous_dealer_count: int = blackjack_last_dealer_count
	var dealer_reveal_now: bool = blackjack_reveal_dealer and not blackjack_last_reveal_dealer
	var player_points: int = _blackjack_hand_value(blackjack_player_cards)
	var dealer_points_text: String = "庄家  ? 点"
	if blackjack_reveal_dealer:
		var dealer_points: int = _blackjack_hand_value(blackjack_dealer_cards)
		dealer_points_text = "庄家  %s 点" % str(dealer_points)
	else:
		var preview: Array[Dictionary] = []
		if not blackjack_dealer_cards.is_empty():
			preview.append(blackjack_dealer_cards[0])
		var preview_points: int = _blackjack_hand_value(preview)
		dealer_points_text = "庄家  %s + ?" % str(preview_points)
	blackjack_dealer_label.text = dealer_points_text
	blackjack_dealer_cards_label.text = "庄家手牌：%s" % _blackjack_cards_to_text(blackjack_dealer_cards, not blackjack_reveal_dealer)
	blackjack_player_label.text = "玩家  %s 点   下注 %s" % [
		str(player_points),
		_money_text(blackjack_round_bet)
	]
	blackjack_player_cards_label.text = "你的手牌：%s" % _blackjack_cards_to_text(blackjack_player_cards, false)
	_blackjack_sync_card_area(
		blackjack_dealer_cards_area,
		blackjack_dealer_cards,
		not blackjack_reveal_dealer,
		true,
		previous_dealer_count,
		dealer_reveal_now
	)
	_blackjack_sync_card_area(
		blackjack_player_cards_area,
		blackjack_player_cards,
		false,
		false,
		previous_player_count,
		false
	)
	if blackjack_dealer_cards_area != null:
		blackjack_dealer_cards_area.visible = true
	if blackjack_player_cards_area != null:
		blackjack_player_cards_area.visible = true
	if blackjack_dealer_cards_label != null:
		blackjack_dealer_cards_label.visible = false
	if blackjack_player_cards_label != null:
		blackjack_player_cards_label.visible = false
	_blackjack_refresh_trust_bar()
	blackjack_status_label.text = _blackjack_status_display_text()
	if blackjack_input_panel != null:
		blackjack_input_panel.visible = blackjack_active
	if blackjack_input_line != null:
		blackjack_input_line.visible = blackjack_active
		blackjack_input_line.editable = _blackjack_chat_input_ready()
		if blackjack_round_over:
			blackjack_input_line.placeholder_text = "这局结束了，继续下一局吧"
		elif blackjack_animating or blackjack_reveal_dealer:
			blackjack_input_line.placeholder_text = "等她先把这轮动作做完……"
		elif blackjack_probe_count >= BLACKJACK_MAX_PROBES:
			blackjack_input_line.placeholder_text = "这局已经问够了"
		else:
			blackjack_input_line.placeholder_text = "试着套妹妹的底牌……"
	if blackjack_hit_button != null:
		blackjack_hit_button.text = "下一局  (Enter)" if blackjack_round_over else "要牌  (Enter)"
	if blackjack_stand_button != null:
		blackjack_stand_button.text = "下一局  (Space)" if blackjack_round_over else "停牌  (Space)"
	if blackjack_new_round_button != null:
		blackjack_new_round_button.text = "新一局  (N)"
	if blackjack_close_button != null:
		blackjack_close_button.text = "结束  (Esc)"
	# Keep deal flow stable: avoid extra pulse tween fighting with flight tween.
	_blackjack_apply_status_style(blackjack_round_over or dealer_reveal_now)
	blackjack_last_player_count = blackjack_player_cards.size()
	blackjack_last_dealer_count = blackjack_dealer_cards.size()
	blackjack_last_reveal_dealer = blackjack_reveal_dealer
	var has_valid_bet: bool = blackjack_selected_bet > 0 and blackjack_selected_bet <= state.money_balance
	if blackjack_hit_button != null:
		blackjack_hit_button.disabled = blackjack_animating or not blackjack_active or not has_valid_bet
	if blackjack_stand_button != null:
		blackjack_stand_button.disabled = blackjack_animating or not blackjack_active or not has_valid_bet
	if blackjack_new_round_button != null:
		blackjack_new_round_button.disabled = blackjack_animating or not blackjack_active or not has_valid_bet
	if blackjack_close_button != null:
		blackjack_close_button.disabled = not blackjack_active
	_blackjack_refresh_bet_ui()


func _blackjack_refresh_trust_bar() -> void:
	if blackjack_trust_track == null or blackjack_trust_fill == null:
		return
	blackjack_trust_track.visible = blackjack_active
	blackjack_trust_fill.visible = blackjack_active
	if blackjack_trust_text_label != null:
		blackjack_trust_text_label.visible = blackjack_active
	if blackjack_balance_label != null:
		blackjack_balance_label.visible = blackjack_active
	if not blackjack_active:
		return
	# `二十一点面板` is a PanelContainer; direct children can be stretched by container layout.
	# Force trust bar to an explicit compact viewport-space rect so it never expands to full screen.
	var vp_size: Vector2 = get_viewport_rect().size
	var ui_s: float = clampf(minf(vp_size.x / 1920.0, vp_size.y / 1080.0), 0.70, 1.30)
	var track_w: float = roundf(108.0 * ui_s)
	var track_h: float = roundf(18.0 * ui_s)
	var margin_right: float = roundf(96.0 * ui_s)
	var margin_top: float = roundf(18.0 * ui_s)
	var track_left: float = maxf(8.0, vp_size.x - track_w - margin_right)
	blackjack_trust_track.top_level = true
	blackjack_trust_track.custom_minimum_size = Vector2(track_w, track_h)
	blackjack_trust_track.anchor_left = 0.0
	blackjack_trust_track.anchor_top = 0.0
	blackjack_trust_track.anchor_right = 0.0
	blackjack_trust_track.anchor_bottom = 0.0
	blackjack_trust_track.offset_left = track_left
	blackjack_trust_track.offset_top = margin_top
	blackjack_trust_track.offset_right = track_left + track_w
	blackjack_trust_track.offset_bottom = margin_top + track_h
	blackjack_trust_track.z_index = 220
	if blackjack_trust_text_label != null:
		var trust_label_w: float = roundf(64.0 * ui_s)
		var trust_label_gap: float = roundf(8.0 * ui_s)
		var trust_label_h: float = roundf(track_h + 4.0 * ui_s)
		blackjack_trust_text_label.top_level = true
		blackjack_trust_text_label.anchor_left = 0.0
		blackjack_trust_text_label.anchor_top = 0.0
		blackjack_trust_text_label.anchor_right = 0.0
		blackjack_trust_text_label.anchor_bottom = 0.0
		blackjack_trust_text_label.offset_left = maxf(8.0, track_left - trust_label_gap - trust_label_w)
		blackjack_trust_text_label.offset_top = maxf(0.0, margin_top - 2.0 * ui_s)
		blackjack_trust_text_label.offset_right = blackjack_trust_text_label.offset_left + trust_label_w
		blackjack_trust_text_label.offset_bottom = blackjack_trust_text_label.offset_top + trust_label_h
		blackjack_trust_text_label.z_index = 220
		blackjack_trust_text_label.text = "信任度"
	if blackjack_balance_label != null:
		var balance_w: float = roundf(280.0 * ui_s)
		var balance_h: float = roundf(34.0 * ui_s)
		var balance_x: float = roundf(26.0 * ui_s)
		var balance_y: float = roundf(18.0 * ui_s)
		blackjack_balance_label.top_level = true
		blackjack_balance_label.anchor_left = 0.0
		blackjack_balance_label.anchor_top = 0.0
		blackjack_balance_label.anchor_right = 0.0
		blackjack_balance_label.anchor_bottom = 0.0
		blackjack_balance_label.offset_left = balance_x
		blackjack_balance_label.offset_top = balance_y
		blackjack_balance_label.offset_right = balance_x + balance_w
		blackjack_balance_label.offset_bottom = balance_y + balance_h
		blackjack_balance_label.z_index = 220
		blackjack_balance_label.text = "余额 %s" % _money_text(state.money_balance)
	var trust_ratio: float = clampf(float(state.blackjack_trust_score) / 100.0, 0.0, 1.0)
	var inner_width: float = maxf(2.0, blackjack_trust_track.size.x - 4.0)
	var fill_width: float = maxf(2.0, inner_width * trust_ratio)
	blackjack_trust_fill.anchor_left = 0.0
	blackjack_trust_fill.anchor_right = 0.0
	blackjack_trust_fill.anchor_top = 0.0
	blackjack_trust_fill.anchor_bottom = 1.0
	blackjack_trust_fill.offset_left = 2.0
	blackjack_trust_fill.offset_top = 2.0
	blackjack_trust_fill.offset_right = 2.0 + fill_width
	blackjack_trust_fill.offset_bottom = -2.0
	var low_color: Color = Color(0.72, 0.38, 0.34, 0.96)
	var high_color: Color = Color(0.89, 0.73, 0.44, 0.98)
	var trust_color: Color = low_color.lerp(high_color, trust_ratio)
	if blackjack_trust_fill is Panel:
		var trust_fill_panel: Panel = blackjack_trust_fill as Panel
		trust_fill_panel.self_modulate = trust_color
	elif blackjack_trust_fill is ColorRect:
		var trust_fill_rect: ColorRect = blackjack_trust_fill as ColorRect
		trust_fill_rect.color = trust_color


func _blackjack_status_display_text() -> String:
	var base_text: String = blackjack_status_text.strip_edges()
	if base_text.is_empty():
		base_text = "牌桌安静了下来，只剩你们彼此试探。"
	if not blackjack_active:
		return base_text
	if blackjack_round_over:
		return base_text
	if blackjack_animating or blackjack_reveal_dealer:
		return base_text
	var remaining: int = maxi(0, BLACKJACK_MAX_PROBES - blackjack_probe_count)
	if remaining > 0:
		return "%s\n（下方还可以再试着套话 %s 次）" % [base_text, str(remaining)]
	return "%s\n（这局已经问够了，先决定要牌还是停牌吧）" % base_text


func _blackjack_refresh_bet_ui() -> void:
	var has_map: bool = typeof(blackjack_bet_buttons) == TYPE_DICTIONARY and not blackjack_bet_buttons.is_empty()
	if not has_map:
		return

	var selected_changed: bool = blackjack_last_selected_bet_fx != blackjack_selected_bet
	for denom_key in blackjack_bet_buttons.keys():
		var btn_v: Variant = blackjack_bet_buttons.get(denom_key)
		if not (btn_v is Button):
			continue
		var btn: Button = btn_v as Button
		var denom: int = int(denom_key)
		var affordable: bool = denom <= state.money_balance
		var selected: bool = denom == blackjack_selected_bet and affordable

		btn.disabled = blackjack_animating or not blackjack_active or not affordable
		if selected:
			btn.modulate = Color(1.0, 0.98, 0.88, 1.0)
			if selected_changed:
				_blackjack_play_chip_select_fx(btn)
			else:
				btn.scale = Vector2(1.06, 1.06)
		elif affordable:
			btn.modulate = Color(0.95, 0.95, 0.95, 1.0)
			btn.scale = Vector2.ONE
		else:
			btn.modulate = Color(0.62, 0.62, 0.62, 0.9)
			btn.scale = Vector2.ONE

		var gradient_v: Node = btn.get_node_or_null("bet_chip_gradient")
		if gradient_v is TextureRect:
			var gradient_rect: TextureRect = gradient_v as TextureRect
			if selected:
				gradient_rect.modulate = Color(1.0, 0.96, 0.76, 0.78)
			elif affordable:
				gradient_rect.modulate = Color(0.98, 0.98, 0.98, 0.34)
			else:
				gradient_rect.modulate = Color(0.72, 0.72, 0.72, 0.20)

		var glow_v: Node = btn.get_node_or_null("bet_chip_glow")
		if glow_v is TextureRect:
			var glow_rect: TextureRect = glow_v as TextureRect
			glow_rect.visible = selected
			glow_rect.modulate = Color(1.0, 0.92, 0.55, 0.80) if selected else Color(1.0, 1.0, 1.0, 0.0)

		var amount_v: Node = btn.get_node_or_null("bet_amount_label")
		if amount_v is Label:
			var amount_label: Label = amount_v as Label
			amount_label.text = str(denom)
			if selected:
				amount_label.add_theme_color_override("font_color", Color(0.22, 0.12, 0.03, 1.0))
				amount_label.add_theme_color_override("font_outline_color", Color(1.0, 0.94, 0.74, 1.0))
			elif affordable:
				amount_label.add_theme_color_override("font_color", Color(0.30, 0.18, 0.05, 0.98))
				amount_label.add_theme_color_override("font_outline_color", Color(0.95, 0.88, 0.66, 0.88))
			else:
				amount_label.add_theme_color_override("font_color", Color(0.34, 0.34, 0.34, 0.95))
				amount_label.add_theme_color_override("font_outline_color", Color(0.72, 0.72, 0.72, 0.80))

	blackjack_last_selected_bet_fx = blackjack_selected_bet
	if blackjack_bet_hint_label != null:
		blackjack_bet_hint_label.visible = false


func _blackjack_play_chip_select_fx(btn: Button) -> void:
	if btn == null:
		return
	var old_tween_v: Variant = btn.get_meta("chip_select_tween", null)
	if old_tween_v is Tween:
		(old_tween_v as Tween).kill()
	btn.scale = Vector2(0.96, 0.96)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.11)
	tween.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.15)
	btn.set_meta("chip_select_tween", tween)


func _blackjack_pulse_label(target: Control, flash_color: Color, scale_from: float = 0.94) -> void:
	if target == null:
		return
	target.scale = Vector2(scale_from, scale_from)
	target.modulate = Color(flash_color.r, flash_color.g, flash_color.b, 0.56)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, 0.23)
	tween.parallel().tween_property(target, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.27)


func _blackjack_reset_transient_visual_state() -> void:
	for target in [
		blackjack_panel,
		blackjack_status_label,
		blackjack_player_cards_area,
		blackjack_dealer_cards_area,
		blackjack_player_label,
		blackjack_dealer_label
	]:
		if target is Control:
			var control: Control = target as Control
			control.scale = Vector2.ONE
			control.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _blackjack_status_color() -> Color:
	if blackjack_status_text.find("赢") >= 0:
		return Color(0.72, 0.95, 0.72)
	if blackjack_status_text.find("输") >= 0:
		return Color(0.98, 0.72, 0.72)
	if blackjack_status_text.find("平局") >= 0:
		return Color(0.97, 0.90, 0.66)
	return Color(0.90, 0.90, 0.90)


func _blackjack_apply_status_style(with_pulse: bool = false) -> void:
	if blackjack_status_label == null:
		return
	blackjack_status_label.add_theme_color_override("font_color", _blackjack_status_color())
	if with_pulse:
		_blackjack_pulse_label(blackjack_status_label, Color(0.97, 0.97, 0.97, 1.0), 0.97)


func _blackjack_pop_panel() -> void:
	if blackjack_panel == null:
		return
	blackjack_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(blackjack_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)
	if blackjack_status_label != null:
		_blackjack_pulse_label(blackjack_status_label, Color(0.95, 0.95, 0.95, 1.0), 0.96)


func _blackjack_panel_punch() -> void:
	if blackjack_status_label != null:
		_blackjack_pulse_label(blackjack_status_label, Color(0.97, 0.97, 0.97, 1.0), 0.95)


func _blackjack_finish_round() -> void:
	var player_points: int = _blackjack_hand_value(blackjack_player_cards)
	var dealer_points: int = _blackjack_hand_value(blackjack_dealer_cards)
	var outcome: String = "draw"
	var base_message: String = "平局。"
	if player_points > BLACKJACK_TARGET:
		outcome = "lose"
		base_message = "你爆牌了，这局你输。"
	elif dealer_points > BLACKJACK_TARGET:
		outcome = "win"
		base_message = "庄家爆牌，这局你赢。"
	elif player_points > dealer_points:
		outcome = "win"
		base_message = "你赢了这局。"
	elif player_points < dealer_points:
		outcome = "lose"
		base_message = "庄家点数更高，这局你输。"
	_blackjack_apply_round_outcome(outcome, base_message)


func _blackjack_apply_round_outcome(outcome: String, base_message: String, natural_blackjack: bool = false) -> void:
	blackjack_animating = false
	blackjack_round_over = true
	var social_summary: String = _blackjack_resolve_round_social_result(outcome)
	var requested_delta: int = _blackjack_money_delta_for_outcome(outcome, natural_blackjack)
	var applied_delta: int = blackjack_last_money_delta
	if not blackjack_round_money_applied:
		applied_delta = state.apply_money_change(requested_delta)
		blackjack_last_money_delta = applied_delta
		blackjack_round_money_applied = true
		_update_hud()
		_save_runtime_state()
		_push_debug_event("21点结算 -> %s 下注%s 变动%s，余额%s" % [
			outcome,
			_money_text(blackjack_round_bet),
			_signed_money_text(applied_delta),
			_money_text(state.money_balance)
		])
	var resolved_message: String = base_message
	if not social_summary.is_empty():
		resolved_message = "%s %s" % [resolved_message, social_summary]
	blackjack_status_text = "%s%s（按 Enter / Space 继续下一局）" % [
		resolved_message,
		_blackjack_money_suffix(applied_delta, requested_delta, blackjack_round_bet)
	]
	_blackjack_refresh_panel()
	_blackjack_play_round_result_fx(outcome)


func _blackjack_register_claim_followup(action_name: String) -> void:
	if blackjack_round_claim_history.is_empty():
		return
	for idx in range(blackjack_round_claim_history.size()):
		var claim: Dictionary = blackjack_round_claim_history[idx]
		var action_after: String = String(claim.get("action_after", ""))
		if action_after.is_empty():
			claim["action_after"] = action_name
			blackjack_round_claim_history[idx] = claim


func _blackjack_resolve_round_social_result(outcome: String) -> String:
	if blackjack_round_social_resolved:
		return ""
	blackjack_round_social_resolved = true
	if blackjack_round_claim_history.is_empty():
		return ""
	var player_points: int = _blackjack_hand_value(blackjack_player_cards)
	var dealer_points: int = _blackjack_hand_value(blackjack_dealer_cards)
	var summary_text: String = ""
	var summary_priority: int = -1
	var trust_delta_requested: int = 0
	var truth_claim_count: int = 0
	var lie_claim_count: int = 0
	var actionable_claim_count: int = 0
	for idx in range(blackjack_round_claim_history.size()):
		var claim: Dictionary = blackjack_round_claim_history[idx]
		var mode: String = String(claim.get("mode", ""))
		if mode == "counter_probe" or mode == "refuse_soft":
			continue
		actionable_claim_count += 1
		var direction: String = String(claim.get("claim_direction", "neutral"))
		var action_after: String = String(claim.get("action_after", ""))
		var is_truth: bool = bool(claim.get("is_truth", false))
		if is_truth:
			truth_claim_count += 1
		else:
			lie_claim_count += 1
		var fell_for_bluff: bool = false
		var caught_lie: bool = false
		var truth_help: bool = false
		if not action_after.is_empty():
			if is_truth:
				truth_help = _blackjack_claim_supported_good_result(direction, action_after, outcome)
			else:
				fell_for_bluff = _blackjack_claim_caused_bad_result(direction, action_after, outcome)
				caught_lie = not fell_for_bluff
		claim["fell_for_bluff"] = fell_for_bluff
		claim["caught_lie"] = caught_lie
		claim["truth_help"] = truth_help
		blackjack_round_claim_history[idx] = claim
		if fell_for_bluff:
			_increment_blackjack_read_profile("fell_for_bluff_count")
			trust_delta_requested += BLACKJACK_TRUST_DELTA_FELL_FOR_BLUFF
			if summary_priority < 3:
				summary_priority = 3
				if action_after == "hit":
					summary_text = "她刚才把底牌说小了，果然把你带着多拿了一张。"
				else:
					summary_text = "她刚才故意把底牌说重了，成功把你压住了节奏。"
		elif caught_lie:
			_increment_blackjack_read_profile("caught_lie_count")
			trust_delta_requested += BLACKJACK_TRUST_DELTA_CAUGHT_LIE
			if summary_priority < 2:
				summary_priority = 2
				summary_text = "她刚才果然在故意误导你，不过这次没骗成。"
		elif truth_help:
			_increment_blackjack_read_profile("truth_help_count")
			trust_delta_requested += BLACKJACK_TRUST_DELTA_TRUTH_HELP
			if summary_priority < 1:
				summary_priority = 1
				summary_text = "她刚才那句提示，倒真没骗你。"
		_blackjack_push_social_history_entry(claim, outcome, player_points, dealer_points)
	if trust_delta_requested == 0 and actionable_claim_count > 0:
		if outcome == "win" and truth_claim_count > 0:
			trust_delta_requested += 2
		elif outcome == "lose" and lie_claim_count > 0:
			trust_delta_requested -= 2
		elif truth_claim_count > lie_claim_count:
			trust_delta_requested += 1
		elif lie_claim_count > truth_claim_count:
			trust_delta_requested -= 1
	var trust_delta_applied: int = _blackjack_apply_trust_delta(trust_delta_requested)
	if trust_delta_applied != 0:
		_push_debug_event("21点信任变化 %s -> %s（%s）" % [
			str(clampi(state.blackjack_trust_score - trust_delta_applied, 0, 100)),
			str(clampi(state.blackjack_trust_score, 0, 100)),
			_blackjack_signed_number_text(trust_delta_applied)
		])
	return summary_text


func _blackjack_apply_trust_delta(delta: int) -> int:
	if delta == 0:
		return 0
	var before: int = clampi(state.blackjack_trust_score, 0, 100)
	var after: int = clampi(before + delta, 0, 100)
	state.blackjack_trust_score = after
	return after - before


func _blackjack_signed_number_text(value: int) -> String:
	if value > 0:
		return "+%s" % str(value)
	return str(value)


func _blackjack_claim_caused_bad_result(direction: String, action_after: String, outcome: String) -> bool:
	if outcome != "lose":
		return false
	if direction == "safe" and action_after == "hit":
		return true
	if direction == "danger" and action_after == "stand":
		return true
	return false


func _blackjack_claim_supported_good_result(direction: String, action_after: String, outcome: String) -> bool:
	if outcome == "lose":
		return false
	if direction == "safe" and action_after == "hit":
		return true
	if direction == "danger" and action_after == "stand":
		return true
	return false


func _blackjack_push_social_history_entry(claim: Dictionary, outcome: String, player_points: int, dealer_points: int) -> void:
	var entry: Dictionary = {
		"day": state.living_days,
		"time": state.display_time,
		"outcome": outcome,
		"mode": String(claim.get("mode", "")),
		"probe_style": String(claim.get("probe_style", "")),
		"is_truth": bool(claim.get("is_truth", false)),
		"action_after": String(claim.get("action_after", "")),
		"fell_for_bluff": bool(claim.get("fell_for_bluff", false)),
		"caught_lie": bool(claim.get("caught_lie", false)),
		"truth_help": bool(claim.get("truth_help", false)),
		"trust_before": int(claim.get("trust_before", clampi(state.blackjack_trust_score, 0, 100))),
		"repeat_pressure": int(claim.get("repeat_pressure", 0)),
		"truth_value": int(claim.get("truth_value", 0)),
		"spoken_value": int(claim.get("spoken_value", 0)),
		"spoken_bucket": String(claim.get("spoken_bucket", "")),
		"player_points": player_points,
		"dealer_points": dealer_points
	}
	state.blackjack_bluff_history.append(entry)
	while state.blackjack_bluff_history.size() > 24:
		state.blackjack_bluff_history.pop_front()


func _blackjack_money_delta_for_outcome(outcome: String, natural_blackjack: bool = false) -> int:
	var bet: int = maxi(0, blackjack_round_bet)
	if bet <= 0:
		return 0
	match outcome:
		"win":
			if natural_blackjack:
				return int(round(float(bet) * BLACKJACK_NATURAL_MULTIPLIER))
			return bet
		"lose":
			return -bet
		_:
			return 0


func _blackjack_money_suffix(applied_delta: int, requested_delta: int, bet: int) -> String:
	if applied_delta > 0:
		return " 下注%s，金钱%s，当前余额%s。" % [_money_text(bet), _signed_money_text(applied_delta), _money_text(state.money_balance)]
	if applied_delta < 0:
		return " 下注%s，金钱%s，当前余额%s。" % [_money_text(bet), _signed_money_text(applied_delta), _money_text(state.money_balance)]
	if requested_delta < 0:
		return " 当前余额%s，已经没有更多可扣的了。" % _money_text(state.money_balance)
	return " 当前余额%s。" % _money_text(state.money_balance)


func _signed_money_text(amount: int) -> String:
	if amount > 0:
		return "+%s" % str(amount)
	if amount < 0:
		return "-%s" % str(abs(amount))
	return "0"


func _money_text(amount: int) -> String:
	return "¥%s" % str(maxi(0, amount))


func _blackjack_play_round_result_fx(outcome: String) -> void:
	var flash_color: Color = Color(0.96, 0.93, 0.78, 1.0)
	match outcome:
		"win":
			flash_color = Color(0.82, 0.98, 0.82, 1.0)
		"lose":
			flash_color = Color(0.98, 0.80, 0.80, 1.0)
		_:
			flash_color = Color(0.96, 0.93, 0.78, 1.0)
	_blackjack_emit_result_particles(outcome, flash_color)
	if blackjack_status_label != null:
		_blackjack_pulse_label(blackjack_status_label, flash_color, 0.90)
	if blackjack_panel != null:
		blackjack_panel.modulate = flash_color
		var panel_tween: Tween = create_tween()
		panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		panel_tween.tween_property(blackjack_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.26)
	match outcome:
		"win":
			if blackjack_player_label != null:
				_blackjack_pulse_label(blackjack_player_label, Color(0.84, 1.0, 0.84, 1.0), 0.94)
		"lose":
			if blackjack_dealer_label != null:
				_blackjack_pulse_label(blackjack_dealer_label, Color(1.0, 0.84, 0.84, 1.0), 0.94)
		_:
			if blackjack_player_label != null:
				_blackjack_pulse_label(blackjack_player_label, flash_color, 0.96)
			if blackjack_dealer_label != null:
				_blackjack_pulse_label(blackjack_dealer_label, flash_color, 0.96)


func _blackjack_emit_result_particles(outcome: String, tint: Color) -> void:
	if blackjack_result_particles == null:
		return
	var burst_pos: Vector2 = Vector2.ZERO
	if blackjack_status_label != null:
		burst_pos = blackjack_status_label.get_global_transform().origin + blackjack_status_label.size * 0.5
	elif blackjack_panel != null:
		burst_pos = blackjack_panel.get_global_transform().origin + blackjack_panel.size * 0.5
	blackjack_result_particles.global_position = burst_pos
	if blackjack_result_particles.process_material is ParticleProcessMaterial:
		var result_material: ParticleProcessMaterial = blackjack_result_particles.process_material as ParticleProcessMaterial
		result_material.color = tint
	var burst_amount: int = 110
	match outcome:
		"win":
			burst_amount = 148
		"lose":
			burst_amount = 98
		_:
			burst_amount = 116
	blackjack_result_particles.amount = burst_amount
	blackjack_result_particles.emitting = false
	blackjack_result_particles.restart()
	blackjack_result_particles.emitting = true


func _on_blackjack_hit_pressed() -> void:
	if not blackjack_active or blackjack_animating:
		return
	if blackjack_round_over:
		_blackjack_start_round()
		return
	_blackjack_register_claim_followup("hit")
	blackjack_animating = true
	blackjack_status_text = "你正在要牌..."
	_blackjack_refresh_panel()
	if not (await _blackjack_breath_pause(BLACKJACK_HIT_DRAW_PAUSE * 0.55)):
		return
	blackjack_player_cards.append(_blackjack_draw_card())
	_blackjack_panel_punch()
	blackjack_status_text = "你抽到一张牌..."
	_blackjack_refresh_panel()
	if not (await _blackjack_breath_pause(BLACKJACK_HIT_DRAW_PAUSE)):
		return
	var player_points: int = _blackjack_hand_value(blackjack_player_cards)
	if player_points > BLACKJACK_TARGET:
		blackjack_reveal_dealer = true
		blackjack_status_text = "你爆牌了，庄家亮牌中..."
		_blackjack_refresh_panel()
		if not (await _blackjack_breath_pause(BLACKJACK_REVEAL_PAUSE)):
			return
		_blackjack_finish_round()
		return
	if player_points == BLACKJACK_TARGET:
		blackjack_status_text = "21点，庄家准备亮牌..."
		_blackjack_refresh_panel()
		if not (await _blackjack_breath_pause(BLACKJACK_DEAL_SETTLE_DELAY)):
			return
		blackjack_animating = false
		_on_blackjack_stand_pressed()
		return
	blackjack_animating = false
	blackjack_status_text = "继续：要牌或停牌。"
	_blackjack_refresh_panel()


func _on_blackjack_stand_pressed() -> void:
	if not blackjack_active or blackjack_animating:
		return
	if blackjack_round_over:
		_blackjack_start_round()
		return
	_blackjack_register_claim_followup("stand")
	blackjack_animating = true
	blackjack_reveal_dealer = true
	blackjack_status_text = "庄家开牌中..."
	_blackjack_refresh_panel()
	if not (await _blackjack_breath_pause(BLACKJACK_REVEAL_PAUSE)):
		return
	while _blackjack_hand_value(blackjack_dealer_cards) < BLACKJACK_DEALER_STAND:
		blackjack_dealer_cards.append(_blackjack_draw_card())
		_blackjack_panel_punch()
		blackjack_status_text = "庄家补牌中..."
		_blackjack_refresh_panel()
		if not (await _blackjack_breath_pause(BLACKJACK_DEALER_DRAW_PAUSE)):
			return
	blackjack_status_text = "庄家停牌，结算中..."
	_blackjack_refresh_panel()
	if not (await _blackjack_breath_pause(BLACKJACK_RESULT_PAUSE)):
		return
	_blackjack_finish_round()


func _on_blackjack_new_round_pressed() -> void:
	if not blackjack_active or blackjack_animating:
		return
	_blackjack_start_round()


func _on_blackjack_rules_button_pressed() -> void:
	if not blackjack_active:
		return
	blackjack_rules_open = not blackjack_rules_open
	_update_interaction_state(false)


func _on_blackjack_close_pressed() -> void:
	_close_blackjack_game()


func _switch_room_with_immersion(target_room: String, move_with_victoria: bool = false) -> void:
	if blackjack_active:
		_close_blackjack_game(false)
	state.room_nav_open = false
	if has_method("_refresh_room_nav_ui"):
		call("_refresh_room_nav_ui")
	var room_name: String = _room_line_name(target_room)
	var victoria_here_before: bool = state.victoria_is_here()
	if target_room == state.current_location:
		if victoria_here_before:
			_show_line("维多利亚", "唔……我们现在就在%s啊。" % room_name, false)
		else:
			_show_line("旁白", "你现在就在%s。" % room_name, true)
		return
	if typing_active:
		_complete_typewriter()
	if move_with_victoria and victoria_here_before:
		_show_line("维多利亚", "嗯，我和你一起去%s。" % room_name, false)
	elif victoria_here_before:
		_show_line("维多利亚", "嗯，下次再聊吧，哥哥。", false)
	else:
		_show_line("旁白", "你走向%s。" % room_name, true)
	_complete_typewriter()
	await _fade_to_black(0.55)
	_play_footstep()
	await get_tree().create_timer(0.35).timeout
	state.current_location = target_room
	if move_with_victoria:
		state.victoria_location = target_room
	state.refresh_time()
	_apply_scene_by_state()
	_sync_period_music(0.4)
	if state.victoria_is_here():
		_set_character_by_mood("日常")
	elif character_rect != null:
		character_rect.visible = false
	await _fade_from_black(0.45)
	if state.victoria_is_here():
		if move_with_victoria and victoria_here_before:
			_show_line("维多利亚", "我们到了。哥哥要先在这里做什么？", false)
		else:
			_show_line("维多利亚", "哥哥，你来啦。", false)
	_push_debug_event("切换房间 -> %s" % target_room)
	_update_hud()
	_save_runtime_state()


func _room_line_name(room_key: String) -> String:
	match room_key:
		"living_room":
			return "客厅"
		"sister_room":
			return "卧室"
		"kitchen":
			return "厨房"
		"player_room":
			return "你的房间"
		_:
			return "那边"

func _run_shift_time_sequence() -> void:
	if mode != "chat":
		return
	transition_active = true
	transition_click_waiting = false
	queued_reply_segments.clear()
	pending_exit_after_segments = false
	if typing_active:
		_complete_typewriter()
	var was_night: bool = state.time_period_name == "晚上"
	var victoria_here_before: bool = state.victoria_is_here()
	if was_night:
		_fade_out_cicada(0.35)
	if dialogue_label != null:
		dialogue_label.text = ""
	if speaker_label != null:
		speaker_label.visible = false
		speaker_label.text = ""
	await _fade_to_black(0.6)

	if was_night:
		# Night ending always transitions to the player's bedroom with lights-off fixed frame.
		state.current_location = "player_room"
		_set_background_key("player_room_night_alt")
		if character_rect != null:
			character_rect.visible = false
		await _fade_from_black(0.45)
		var night_lines: Array[String] = [
			"夜深了，公寓里渐渐安静下来了。",
			"我回到房间，在模糊睡意中，似乎感觉门外有一道目光停留了许久……",
			"（正在进行今日记忆神经拓扑同步……）"
		]
		for i in range(night_lines.size()):
			_show_line("旁白", night_lines[i], true)
			_complete_typewriter()
			await _wait_for_transition_click()
		if dialogue_label != null:
			dialogue_label.text = ""
		if speaker_label != null:
			speaker_label.visible = false
			speaker_label.text = ""
		_set_summary_waiting(true)
		await _summarize_pending_dialogues(true, true)
		_set_summary_waiting(false)
		_show_line("旁白", "......", true)
		_complete_typewriter()
		await _wait_for_transition_click()
		await _fade_to_black(0.45)

	var shift_result: Dictionary = state.shift_time_logic()
	var victoria_here_after: bool = state.victoria_is_here()
	var victoria_arrived_this_shift: bool = (not was_night) and (not victoria_here_before) and victoria_here_after
	var arrival_transition_text: String = ""
	if victoria_arrived_this_shift:
		var room_name: String = _room_line_name(state.current_location)
		arrival_transition_text = "走廊传来轻轻的脚步声，维多利亚出现在%s门口。她像是刚好也来找你。" % room_name
	_apply_scene_by_state()
	if state.victoria_is_here():
		_set_character_by_mood("日常")
	elif character_rect != null:
		character_rect.visible = false
	_sync_period_music(0.65)
	await _fade_from_black(0.55)

	if was_night:
		_show_line("旁白", "新的一天开始了。", true)
	else:
		var lines: Array = shift_result.get("narration", [])
		var transition_lines: Array[String] = []
		for line_v in lines:
			var line_text: String = String(line_v).strip_edges()
			if not line_text.is_empty():
				transition_lines.append(line_text)
		if transition_lines.is_empty():
			transition_lines.append("时间悄悄过去了一阵。")
		if not arrival_transition_text.is_empty():
			_play_footstep()
			transition_lines.append(arrival_transition_text)
			_push_debug_event("时段切换后在%s遇到妹妹" % state.current_location)
		_show_line("旁白", "\n".join(transition_lines), true)

	_update_love_visual(0)
	_push_debug_event("时段推进 -> 第%s天 %s (%s)" % [
		str(state.living_days),
		state.display_time,
		state.time_period_name
	])
	_update_hud()
	pending_period_intro = true
	transition_active = false
	transition_click_waiting = false
	_save_runtime_state()


func _set_summary_waiting(active: bool) -> void:
	if active:
		ai_waiting_active = true
		waiting_indicator_accum = 0.0
		ai_waiting_message = "维多利亚正在整理今天的记忆"
		if ai_waiting_label != null:
			ai_waiting_label.visible = true
			ai_waiting_label.text = "%s." % ai_waiting_message
		return
	ai_waiting_active = false
	waiting_indicator_accum = 0.0
	if ai_waiting_label != null:
		ai_waiting_label.visible = false


func _handle_ai_turn(player_text: String) -> void:
	queued_reply_segments.clear()
	pending_exit_after_segments = false
	_update_interaction_state(true)
	_set_api_status("准备请求", "#7ca6ff")

	var topic_plan: Dictionary = state.v_topic_plan(player_text, false)
	var topic_hint: String = String(topic_plan.get("hint", ""))
	var topic_recent: String = String(topic_plan.get("recent", "\u65e0"))
	var segment_preference: String = "\u0031\u6bb5" if rng.randi_range(0, 1) == 0 else "\u0032\u6bb5"
	var web_context: String = await web_service.fetch_web_context(player_text, state.chat_history, state.web_search_enabled)
	if not web_context.strip_edges().is_empty():
		_push_debug_event("联网命中: 已补充外部事实")

	memory_model.update_facts_from_user_input(state, player_text)
	var retrieved_memory: String = await memory_service.query_long_term_memory(state, memory_model, player_text)
	if retrieved_memory.is_empty():
		retrieved_memory = memory_model.query_memory(state, player_text)
	var fact_prompt: String = memory_model.build_fact_memory_prompt(state)
	var mid_prompt: String = memory_model.build_mid_memory_prompt(state, player_text)

	var victoria_prompt: String = prompt_builder.build_victoria_prompt(
		state,
		topic_hint,
		topic_recent,
		segment_preference,
		fact_prompt,
		mid_prompt,
		retrieved_memory,
		web_context
	)
	await _run_ai_turn_with_prompt(player_text, victoria_prompt, true, true, web_context)


func _run_ai_turn_with_prompt(player_text: String, system_prompt: String, include_recent_history: bool = true, count_dialogue: bool = true, web_context: String = "") -> void:
	var turn_start_msec: int = Time.get_ticks_msec()
	var raw_reply: String = await _generate_ai_reply(player_text, system_prompt, include_recent_history)
	await _enforce_ai_min_think_time(turn_start_msec)
	if String(raw_reply).strip_edges().is_empty():
		var api_cfg: Dictionary = _resolve_api_config()
		var api_ready: bool = not String(api_cfg.get("api_key", "")).strip_edges().is_empty() and not String(api_cfg.get("base_url", "")).strip_edges().is_empty() and not String(api_cfg.get("model", "")).strip_edges().is_empty()
		if api_ready:
			_set_api_status("在线对话请求失败", "#ff6b6b", true)
			if has_method("_show_notify"):
				call("_show_notify", "在线对话请求失败，请检查网络或接口地址。")
		else:
			_set_api_status("本地向量 + 在线对话未连接", "#f3b35f", true)
			if has_method("_show_notify"):
				call("_show_notify", "请先在设置里填写可用API，再进行对话。")
		_update_hud()
		_update_interaction_state(false)
		return

	var finish_data: Dictionary = reply_parser.extract_finish_signal(raw_reply)
	var should_exit: bool = bool(finish_data.get("should_exit", false))
	var cleaned: String = String(finish_data.get("reply", "")).strip_edges()

	var cue_data: Dictionary = reply_parser.extract_expression_cue(cleaned)
	var expression_cue: String = String(cue_data.get("cue", ""))
	cleaned = String(cue_data.get("reply", "")).strip_edges()

	var mood_data: Dictionary = reply_parser.extract_mood_marker(cleaned)
	latest_mood = String(mood_data.get("mood", "\u65e5\u5e38"))
	cleaned = String(mood_data.get("reply", "")).strip_edges()

	var love_data: Dictionary = reply_parser.extract_love_change(cleaned)
	var love_change: int = int(love_data.get("change", 0))
	cleaned = String(love_data.get("reply", "")).strip_edges()

	var memory_hint: Dictionary = reply_parser.extract_memory_hint(cleaned)
	var importance: int = int(memory_hint.get("importance", 5))
	var keywords_value: Variant = memory_hint.get("keywords", [])
	var keywords: Array = keywords_value if typeof(keywords_value) == TYPE_ARRAY else []
	cleaned = String(memory_hint.get("reply", "")).strip_edges()

	cleaned = reply_parser.normalize_reply_by_time(cleaned, state.time_period_name)
	cleaned = memory_model.normalize_relative_time_terms(state, cleaned)
	cleaned = _repair_pronoun_and_meal_reply(player_text, cleaned)
	cleaned = _avoid_same_reply_on_repeated_input(player_text, cleaned)
	cleaned = _ensure_unique_reply_text(player_text, cleaned)
	if cleaned.is_empty():
		cleaned = "\uff08\u5979\u8f7b\u8f7b\u70b9\u5934\uff09\u55ef\uff0c\u6211\u5728\u542c\u3002"

	state.apply_love_change(love_change)
	_update_love_visual(love_change)
	var expression_profile: Dictionary = _expression_profile_for_reply(latest_mood, expression_cue, player_text, cleaned)
	expression_profile["mood"] = latest_mood
	_apply_character_expression(expression_profile)

	state.current_cycle_seconds += rng.randi_range(2, 5)
	state.refresh_time()
	_apply_scene_by_state()
	_sync_period_music(0.35)

	var anchor: String = "\u7b2c%s\u5929 %s %s" % [str(state.living_days), state.display_time, state.time_period_name]
	state.pending_summaries.append("[%s]\n\u54e5\u54e5: %s\n\u7ef4\u591a\u5229\u4e9a: %s" % [anchor, player_text, cleaned])
	state.pending_memory_records.append({
		"text": cleaned,
		"day": state.living_days,
		"love_score": state.love_score,
		"importance": importance,
		"keywords": keywords,
		"time_anchor": anchor,
		"created_at_ts": int(Time.get_unix_time_from_system())
	})
	state.chat_history.append({"role": "user", "content": player_text, "day": state.living_days})
	state.chat_history.append({"role": "assistant", "content": cleaned, "day": state.living_days})

	if count_dialogue:
		state.dialogue_counter += 1
		if state.dialogue_counter >= MEMORY_TRIGGER_COUNT:
			state.dialogue_counter = 0
			await _summarize_pending_dialogues(true, false)

	var segments: Array[String] = _split_reply_segments(cleaned)
	var first_segment: String = cleaned
	queued_reply_segments.clear()
	if not segments.is_empty():
		first_segment = segments[0]
		for i in range(1, segments.size()):
			queued_reply_segments.append(segments[i])
	_show_line("\u7ef4\u591a\u5229\u4e9a", first_segment, false)
	pending_exit_after_segments = should_exit and not queued_reply_segments.is_empty()
	if should_exit and queued_reply_segments.is_empty():
		pending_shift_after_line = true

	var turn_source: String = "ai_online" if String(state.api_status).find("在线") >= 0 else "ai_fallback"
	_record_turn_debug(
		player_text,
		cleaned,
		love_change,
		latest_mood,
		expression_cue,
		not web_context.strip_edges().is_empty(),
		turn_source
	)
	_push_debug_event("完成一轮对话: 好感%s, 分段%s" % [str(love_change), str(maxi(1, segments.size()))])
	_update_hud()
	_update_interaction_state(false)

	_save_runtime_state()


func _enforce_ai_min_think_time(turn_start_msec: int) -> void:
	var floor_sec: float = _current_ai_min_think_seconds()
	if floor_sec <= 0.0:
		return
	var elapsed_msec: int = maxi(0, Time.get_ticks_msec() - turn_start_msec)
	var floor_msec: int = int(roundf(floor_sec * 1000.0))
	if elapsed_msec >= floor_msec:
		return
	var wait_msec: int = floor_msec - elapsed_msec
	await get_tree().create_timer(float(wait_msec) / 1000.0).timeout


func _current_ai_min_think_seconds() -> float:
	var status_text: String = String(state.api_status)
	if status_text.find("在线") >= 0:
		return AI_MIN_THINK_ONLINE_SECONDS
	return AI_MIN_THINK_OFFLINE_SECONDS


func _show_next_reply_segment_if_any() -> bool:
	if queued_reply_segments.is_empty():
		return false
	var next_segment: String = ""
	while next_segment.is_empty() and not queued_reply_segments.is_empty():
		next_segment = String(queued_reply_segments.pop_front()).strip_edges()
	if next_segment.is_empty():
		if queued_reply_segments.is_empty() and pending_exit_after_segments:
			pending_exit_after_segments = false
			pending_shift_after_line = true
		return false
	_show_line("\u7ef4\u591a\u5229\u4e9a", next_segment, false)
	if queued_reply_segments.is_empty() and pending_exit_after_segments:
		pending_exit_after_segments = false
		pending_shift_after_line = true
	_update_interaction_state(false)
	_save_runtime_state()
	return true


func _split_reply_segments(reply_text: String) -> Array[String]:
	var normalized: String = reply_text.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	if normalized.is_empty():
		return []
	var parts: Array[String] = []
	var blocks: Array[String] = []
	var current_lines: Array[String] = []
	for line in normalized.split("\n", false):
		var raw_line: String = String(line)
		if raw_line.strip_edges().is_empty():
			if not current_lines.is_empty():
				blocks.append("\n".join(current_lines))
				current_lines.clear()
			continue
		current_lines.append(raw_line)
	if not current_lines.is_empty():
		blocks.append("\n".join(current_lines))

	if blocks.is_empty():
		blocks.append(normalized)

	for block in blocks:
		var compact: String = String(block).replace("\n", "").strip_edges()
		if not compact.is_empty():
			parts.append(compact)
	if parts.is_empty():
		parts.append(normalized.replace("\n", "").strip_edges())
	return parts


func _maybe_run_period_initiative() -> void:
	if mode != "chat":
		return
	if state.period_initiative_done:
		return
	state.period_initiative_done = true
	if not state.victoria_is_here():
		if has_method("_show_notify"):
			call("_show_notify", "当前房间暂时没有可以对话的人。")
		_update_hud()
		_update_interaction_state(false)
		_save_runtime_state()
		return

	if state.living_days <= 1:
		_show_line("\u65c1\u767d", "\u4eca\u5929\u662f\u540c\u5c45\u7b2c\u4e00\u5929\uff0c\u7ef4\u591a\u5229\u4e9a\u770b\u8d77\u6765\u8fd8\u6709\u4e9b\u62d8\u8c28\uff0c\u50cf\u662f\u5728\u7b49\u4f60\u5148\u5f00\u53e3\u3002", true)
		_update_hud()
		_save_runtime_state()
		return

	var proactive_roll: float = rng.randf()
	if proactive_roll < PROACTIVE_TRIGGER_RATE:
		var topic_plan: Dictionary = state.v_topic_plan("\uff08\u4e3b\u52a8\u5f00\u573a\uff09", true)
		var topic_hint: String = String(topic_plan.get("hint", ""))
		var topic_recent: String = String(topic_plan.get("recent", "\u65e0"))
		var initiative_prompt: String = _build_initiative_prompt(topic_hint, topic_recent)
		queued_reply_segments.clear()
		pending_exit_after_segments = false
		if typing_active:
			_complete_typewriter()
		if dialogue_label != null:
			dialogue_label.text = ""
		if speaker_label != null:
			speaker_label.visible = false
			speaker_label.text = ""
		if has_method("_refresh_chat_prompt"):
			call("_refresh_chat_prompt")
		_update_interaction_state(true)
		await _run_ai_turn_with_prompt("\uff08\u4f60\u770b\u5230\u54e5\u54e5\u8d70\u8fdb\u4e86\u623f\u95f4\uff09", initiative_prompt, false, false)
	else:
		_show_line("\u65c1\u767d", "\u7ef4\u591a\u5229\u4e9a\u62ac\u773c\u770b\u4e86\u770b\u4f60\uff0c\u50cf\u662f\u5728\u7b49\u4f60\u5148\u5f00\u53e3\u3002", true)
		_update_hud()
		_update_interaction_state(false)

	_save_runtime_state()


func _build_initiative_prompt(topic_hint: String, topic_recent: String) -> String:
	var synthetic_input: String = "\uff08\u4e3b\u52a8\u5f00\u573a\uff09"
	var retrieved_memory: String = memory_model.query_memory(state, synthetic_input)
	var fact_prompt: String = memory_model.build_fact_memory_prompt(state)
	var mid_prompt: String = memory_model.build_mid_memory_prompt(state, synthetic_input)
	var base_prompt: String = prompt_builder.build_victoria_prompt(
		state,
		topic_hint,
		topic_recent,
		"1\u6bb5",
		fact_prompt,
		mid_prompt,
		retrieved_memory
	)
	var lines: Array[String] = []
	lines.append(base_prompt)
	lines.append("\u3010\u8ffd\u52a0\u4efb\u52a1\uff1a\u4e3b\u52a8\u5f00\u573a\u3011")
	lines.append("- \u73b0\u5728\u662f%s\uff0c\u8bf7\u4e3b\u52a8\u5f00\u542f\u4e00\u6bb5\u81ea\u7136\u3001\u7b80\u77ed\u7684\u5bf9\u8bdd\uff0c\u4e0d\u8981\u7b49\u54e5\u54e5\u5148\u8bf4\u8bdd\u3002" % state.time_period_name)
	lines.append("- \u8fd9\u662f\u65b0\u65f6\u6bb5\u5f00\u573a\uff0c\u4e0d\u8981\u627f\u63a5\u4e0a\u4e00\u65f6\u6bb5\u672a\u5b8c\u6210\u7684\u52a8\u4f5c\u6216\u53f0\u8bcd\uff08\u4f8b\u5982\u2018\u6c64\u5feb\u597d\u4e86\u2019\uff09\u3002")
	lines.append("- \u82e5\u65e0\u5fc5\u8981\uff0c\u4e0d\u8981\u91cd\u590d\u6628\u5929\u5df2\u8bf4\u8fc7\u7684\u5177\u4f53\u5b89\u6392/\u539f\u8bdd\uff1b\u5982\u679c\u91cd\u590d\u8bdd\u9898\uff0c\u5fc5\u987b\u6362\u5207\u5165\u89d2\u5ea6\u3002")
	lines.append("- \u53e5\u9996\u8f93\u51fa [M:\u60c5\u7eea]\uff0c\u53ef\u9009 [P:\u4fe1\u53f7]\uff1b\u53e5\u672b\u8f93\u51fa (+2)/(-3) \u4e0e [W:\u6743\u91cd,K:\u5173\u952e\u8bcd]\u3002")
	return "\n".join(lines)


func _summarize_pending_dialogues(update_attitude: bool = true, flush_vector: bool = false) -> void:
	var has_dialogues: bool = not state.pending_summaries.is_empty()
	var has_records: bool = not state.pending_memory_records.is_empty()
	if not has_dialogues and not has_records:
		var vector_count_only: int = 0
		if flush_vector:
			vector_count_only = await _flush_pending_vectors()
		state.debug_last_summary_info = {
			"day": state.living_days,
			"dialogue_count": 0,
			"record_count": 0,
			"archived_count": 0,
			"mid_summary": "",
			"observed_log": state.observed_log,
			"dialogues": 0,
			"records": 0,
			"archived_mid_entries": 0,
			"vector_upserts": vector_count_only,
			"updated_memory": false,
			"updated_attitude": false
		}
		return

	var dialogues: Array = state.pending_summaries.duplicate(true)
	var records: Array = state.pending_memory_records.duplicate(true)
	state.pending_summaries.clear()
	state.pending_memory_records.clear()
	var memory_updated: bool = false
	var attitude_updated: bool = false

	if dialogues.size() > 8:
		dialogues = dialogues.slice(dialogues.size() - 8, dialogues.size())
	if records.size() > 12:
		records = records.slice(records.size() - 12, records.size())

	var summary_api_config: Dictionary = _resolve_api_config()
	var summary_api_key: String = String(summary_api_config.get("api_key", "")).strip_edges()
	var summary_base_url: String = String(summary_api_config.get("base_url", "")).strip_edges()
	var summary_model: String = String(summary_api_config.get("model", "")).strip_edges()
	var summary_api_ready: bool = not summary_api_key.is_empty() and not summary_base_url.is_empty() and not summary_model.is_empty()
	if not dialogues.is_empty() and summary_api_ready:
		var summary_prompt: String = ""
		summary_prompt += "\u4f60\u662f\u7ef4\u591a\u5229\u4e9a\u7684\u6f5c\u610f\u8bc6\u6574\u7406\u6a21\u5757\u3002\u8bf7\u57fa\u4e8e\u4ee5\u4e0b\u6700\u65b0\u5bf9\u8bdd\uff0c\u66f4\u65b0\u4f60\u7684\u89c2\u5bdf\u65e5\u5fd7\u3002\n"
		summary_prompt += "\u3010\u8981\u6c42\u3011\n"
		summary_prompt += "1. \u52a1\u5fc5\u5c06\u66f4\u65b0\u540e\u7684\u65e5\u5fd7\u603b\u5b57\u6570\u4e25\u683c\u538b\u7f29\u5728 300 \u5b57\u4ee5\u5185\u3002\n"
		summary_prompt += "2. \u63d0\u70bc\u5bf9\u54e5\u54e5\u6700\u6838\u5fc3\u7684\u60c5\u611f\u8ba4\u77e5\u548c\u5173\u952e\u4e8b\u4ef6\uff0c\u679c\u65ad\u5408\u5e76\u540c\u7c7b\u9879\uff0c\u5220\u6389\u5df2\u7ecf\u8fc7\u671f\u7684\u751f\u6d3b\u7410\u4e8b\u3002\n"
		summary_prompt += "3. \u4e0d\u8981\u628a\u4e00\u6b21\u6027\u7684\u9910\u98df\u63d0\u8bae\u3001\u51fa\u95e8\u5efa\u8bae\u3001\u4e34\u65f6\u5b89\u6392\u3001\u5df2\u7ecf\u8bf4\u8fc7\u5c31\u8fc7\u671f\u7684\u751f\u6d3b\u53f0\u8bcd\u5199\u8fdb\u957f\u671f\u89c2\u5bdf\u65e5\u5fd7\u3002\n"
		summary_prompt += "4. \u89c2\u5bdf\u65e5\u5fd7\u5e94\u4f18\u5148\u4fdd\u7559\u7a33\u5b9a\u504f\u597d\u3001\u5173\u7cfb\u53d8\u5316\u3001\u60c5\u7eea\u6a21\u5f0f\u3001\u6027\u683c\u5224\u65ad\u548c\u4ecd\u4f1a\u6301\u7eed\u5f71\u54cd\u76f8\u5904\u7684\u4e8b\u4ef6\u3002\n"
		summary_prompt += "\u3010\u957f\u671f\u504f\u79fb\u4efb\u52a1\u3011\u8bf7\u57fa\u4e8e\u4eca\u5929\u4e92\u52a8\uff0c\u7ed9\u51fa\u2018\u957f\u671f\u4e92\u52a8\u504f\u79fb\u2019\u7684\u5fae\u8c03\u5efa\u8bae\uff0850\u5b57\u4ee5\u5185\uff09\u3002\n"
		summary_prompt += "\u6ce8\u610f\uff1a\u53ea\u80fd\u505a\u7f13\u6162\u504f\u79fb\uff0c\u4e0d\u80fd\u5927\u8d77\u5927\u843d\uff1b\u7edd\u5bf9\u4e0d\u80fd\u6539\u53d8\u5979\u6df1\u7231\u54e5\u54e5\u4e14\u5bb3\u6015\u88ab\u629b\u5f03\u7684\u5e95\u5c42\u6027\u683c\u3002\n"
		summary_prompt += "\u8bf7\u5c06\u5efa\u8bae\u8f93\u51fa\u5728 <attitude> \u6807\u7b7e\u5185\u3002\n"
		summary_prompt += "\u3010\u6700\u65b0\u5bf9\u8bdd\u3011\n%s\n" % "\n".join(dialogues)
		summary_prompt += "\u3010\u5f53\u524d\u8bb0\u5fc6\u3011\n%s" % state.observed_log

		var summary_messages: Array = []
		summary_messages.append({"role": "user", "content": summary_prompt})
		var api_reply: String = await _request_chat_completion(summary_messages, summary_api_config, 0.3)
		if not api_reply.is_empty():
			var parsed: Dictionary = _extract_summary_outputs(api_reply)
			var new_memory: String = String(parsed.get("memory", "")).strip_edges()
			var new_attitude: String = String(parsed.get("attitude", "")).strip_edges()
			if not new_memory.is_empty():
				state.observed_log = new_memory
				memory_updated = true
			if update_attitude and not new_attitude.is_empty() and _should_apply_long_term_attitude():
				state.current_attitude = new_attitude
				state.attitude_last_update_day = state.living_days
				attitude_updated = true

	var archived_entries: Array = memory_model.update_mid_memory(state, dialogues, records)
	memory_model.upsert_memory_records(state, records)
	if not records.is_empty():
		state.pending_vector_records.append_array(records)
	if not archived_entries.is_empty():
		state.pending_vector_mid_archives.append_array(archived_entries)
	_trim_vector_backlog(220)
	var vector_upserts: int = 0
	if flush_vector:
		vector_upserts = await _flush_pending_vectors()
	var latest_mid_summary: String = ""
	if not state.mid_memory_entries.is_empty():
		var last_mid_v: Variant = state.mid_memory_entries[state.mid_memory_entries.size() - 1]
		if typeof(last_mid_v) == TYPE_DICTIONARY:
			latest_mid_summary = String((last_mid_v as Dictionary).get("summary", ""))
	state.debug_last_summary_info = {
		"day": state.living_days,
		"dialogue_count": dialogues.size(),
		"record_count": records.size(),
		"archived_count": archived_entries.size(),
		"mid_summary": latest_mid_summary,
		"observed_log": state.observed_log,
		"dialogues": dialogues.size(),
		"records": records.size(),
		"archived_mid_entries": archived_entries.size(),
		"vector_upserts": vector_upserts,
		"updated_memory": memory_updated,
		"updated_attitude": attitude_updated
	}
	_push_debug_event("记忆总结: 对话%s, 记录%s, 归档%s, 向量%s" % [
		str(dialogues.size()),
		str(records.size()),
		str(archived_entries.size()),
		str(vector_upserts)
	])


func _trim_vector_backlog(max_items: int = 220) -> void:
	if state.pending_vector_records.size() > max_items:
		state.pending_vector_records = state.pending_vector_records.slice(state.pending_vector_records.size() - max_items, state.pending_vector_records.size())
	if state.pending_vector_mid_archives.size() > max_items:
		state.pending_vector_mid_archives = state.pending_vector_mid_archives.slice(state.pending_vector_mid_archives.size() - max_items, state.pending_vector_mid_archives.size())


func _flush_pending_vectors() -> int:
	var upserts: int = 0
	if not state.pending_vector_mid_archives.is_empty():
		upserts += int(await memory_service.upsert_mid_archives(state, memory_model, state.pending_vector_mid_archives))
		state.pending_vector_mid_archives.clear()
	if not state.pending_vector_records.is_empty():
		upserts += int(await memory_service.upsert_dialogue_records(state, memory_model, state.pending_vector_records))
		state.pending_vector_records.clear()
	return upserts


func _api_provider_defaults(provider_id: String) -> Dictionary:
	var key: String = String(provider_id).strip_edges().to_lower()
	if key.is_empty():
		key = DEFAULT_API_PROVIDER_ID
	var defaults_v: Variant = API_PROVIDER_DEFAULTS.get(key, API_PROVIDER_DEFAULTS.get("custom", {}))
	return defaults_v if defaults_v is Dictionary else {}


func _resolve_api_config() -> Dictionary:
	var config: Dictionary = {}
	var loaded_v: Variant = USER_PREFS_SCRIPT.load_api_config()
	if loaded_v is Dictionary:
		config = loaded_v as Dictionary

	var provider_id: String = String(config.get("provider", DEFAULT_API_PROVIDER_ID)).strip_edges().to_lower()
	if provider_id.is_empty():
		provider_id = DEFAULT_API_PROVIDER_ID
	var defaults: Dictionary = _api_provider_defaults(provider_id)
	var base_url: String = String(config.get("base_url", defaults.get("base_url", ""))).strip_edges()
	var model: String = String(config.get("model", defaults.get("model", ""))).strip_edges()
	var api_key: String = String(config.get("api_key", "")).strip_edges()

	if api_key.is_empty():
		var env_names_v: Variant = API_PROVIDER_ENV_KEYS.get(provider_id, API_PROVIDER_ENV_KEYS.get("custom", []))
		if env_names_v is Array:
			var env_names: Array = env_names_v as Array
			for env_name_v in env_names:
				var env_name: String = String(env_name_v).strip_edges()
				if env_name.is_empty():
					continue
				var env_value: String = String(OS.get_environment(env_name)).strip_edges()
				if not env_value.is_empty():
					api_key = env_value
					break
	if api_key.is_empty() and provider_id == "deepseek":
		api_key = String(DEFAULT_DEEPSEEK_API_KEY).strip_edges()

	if base_url.is_empty():
		base_url = String(OS.get_environment("API_BASE_URL")).strip_edges()
	if model.is_empty():
		model = String(OS.get_environment("API_MODEL")).strip_edges()

	return {
		"provider": provider_id,
		"api_key": api_key,
		"base_url": base_url,
		"model": model
	}


func _extract_summary_outputs(api_reply: String) -> Dictionary:
	var text: String = String(api_reply).strip_edges()
	var attitude: String = ""
	var regex: RegEx = RegEx.new()
	regex.compile("<attitude>([\\s\\S]*?)</attitude>")
	var match: RegExMatch = regex.search(text)
	if match != null:
		attitude = String(match.get_string(1)).strip_edges()
		text = String(regex.sub(text, "\n", true)).strip_edges()
	return {
		"memory": text,
		"attitude": attitude
	}


func _should_apply_long_term_attitude() -> bool:
	var day: int = state.living_days
	var last_update_day: int = state.attitude_last_update_day
	return (day - last_update_day) >= ATTITUDE_UPDATE_MIN_DAY_GAP


func _generate_ai_reply(user_text: String, system_prompt: String, include_recent_history: bool = true) -> String:
	var api_config: Dictionary = _resolve_api_config()
	var api_key: String = String(api_config.get("api_key", "")).strip_edges()
	var base_url: String = String(api_config.get("base_url", "")).strip_edges()
	var model_name: String = String(api_config.get("model", "")).strip_edges()
	if api_key.is_empty() or base_url.is_empty() or model_name.is_empty():
		_set_api_status("本地向量 + 在线对话未连接", "#f3b35f", true)
		return ""

	var now: Dictionary = Time.get_datetime_dict_from_system()
	var final_prompt: String = system_prompt
	final_prompt += "\n\u3010\u73b0\u5b9e\u65e5\u671f\u6821\u51c6\u3011\u5f53\u524d\u73b0\u5b9e\u65e5\u671f\u4e3a%s-%02d-%02d\uff0c\u5f53\u524d\u5e74\u4efd\u4e3a%s\u3002\u82e5\u54e5\u54e5\u95ee\u73b0\u5b9e\u65f6\u95f4/\u5e74\u4efd\uff0c\u5fc5\u987b\u4ee5\u6b64\u4e3a\u51c6\u3002" % [
		str(now.get("year", 1970)),
		int(now.get("month", 1)),
		int(now.get("day", 1)),
		str(now.get("year", 1970))
	]
	final_prompt += "\n\u3010\u8bb0\u5fc6\u65f6\u95f4\u89c4\u5219\u3011\u4f60\u4f1a\u770b\u5230\u6309\u65f6\u95f4\u987a\u5e8f\u6574\u7406\u8fc7\u7684\u5386\u53f2\u8bb0\u5f55\u3002\u8de8\u5929\u5185\u5bb9\u90fd\u5c5e\u4e8e\u8fc7\u53bb\u8bb0\u5fc6\uff0c\u5fc5\u987b\u7528\u2018\u4e4b\u524d/\u524d\u51e0\u5929/\u90a3\u6b21\u2019\u6765\u8868\u8ff0\uff1b\u53ea\u6709\u5f53\u524d\u5929\u6570\u4e14\u521a\u53d1\u751f\u7684\u5185\u5bb9\uff0c\u624d\u53ef\u4ee5\u7528\u2018\u521a\u624d/\u521a\u521a\u2019\u3002\u4e25\u7981\u628a\u524d\u4e00\u5929\u7684\u4e8b\u8bf4\u6210\u2018\u521a\u624d\u2019\u3002"
	final_prompt += "\n【人称与指代硬规则】哥哥发言中“你/你这边”默认指维多利亚，“我/我这边”默认指哥哥。必须直接以维多利亚第一人称作答，禁止主语反转成“哥哥想…吗/哥哥是说你…吗”。"
	var room_anchor: String = _build_room_anchor_text()
	if not room_anchor.is_empty():
		final_prompt += room_anchor

	var messages: Array = []
	messages.append({"role": "system", "content": final_prompt})
	if include_recent_history:
		var recent_history: Array = _recent_history_for_model(20, 3)
		for item in recent_history:
			messages.append(item)
	var user_message: String = user_text
	if not room_anchor.is_empty():
		user_message = room_anchor + "\n\u3010\u54e5\u54e5\u672c\u8f6e\u53d1\u8a00\u3011" + user_text
	messages.append({"role": "user", "content": user_message})

	var content: String = await _request_chat_completion(messages, api_config, 0.6)
	if content.is_empty():
		_set_api_status("在线对话不可用", "#f3b35f", true)
		return ""
	return content


func _request_chat_completion(messages: Array, api_config: Dictionary, temperature: float = 0.6) -> String:
	var api_key: String = String(api_config.get("api_key", "")).strip_edges()
	var base_url: String = String(api_config.get("base_url", "")).strip_edges()
	var model_name: String = String(api_config.get("model", "")).strip_edges()
	if api_key.is_empty():
		_push_debug_event("在线对话未启用：API Key 为空")
		return ""
	if base_url.is_empty() or model_name.is_empty():
		_push_debug_event("在线对话未启用：接口地址或模型为空")
		return ""
	_set_api_status("在线对话请求中", "#6ec1ff")

	var payload: Dictionary = {
		"model": model_name,
		"messages": messages,
		"temperature": temperature
	}
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key
	])
	var req_err: int = http_request.request(
		base_url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if req_err != OK:
		_set_api_status("请求失败(%s)" % str(req_err), "#ff6b6b", true)
		_push_debug_event("在线对话请求发起失败：%s" % str(req_err))
		return ""

	var result: Array = await http_request.request_completed
	if result.size() < 4:
		_set_api_status("请求失败(响应结构异常)", "#ff6b6b", true)
		_push_debug_event("在线对话响应结构异常")
		return ""
	var code: int = int(result[1])
	if code != 200:
		_set_api_status("请求失败(HTTP %s)" % str(code), "#ff6b6b", true)
		_push_debug_event("在线对话HTTP失败：%s" % str(code))
		return ""

	var body: PackedByteArray = result[3]
	var parser: JSON = JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		_set_api_status("请求失败(JSON解析错误)", "#ff6b6b", true)
		_push_debug_event("在线对话响应JSON解析失败")
		return ""
	if typeof(parser.data) != TYPE_DICTIONARY:
		_set_api_status("请求失败(响应体异常)", "#ff6b6b", true)
		_push_debug_event("在线对话响应体类型异常")
		return ""

	var data: Dictionary = parser.data
	var choices_v: Variant = data.get("choices", [])
	if typeof(choices_v) != TYPE_ARRAY:
		_set_api_status("请求失败(choices异常)", "#ff6b6b", true)
		_push_debug_event("在线对话响应choices字段异常")
		return ""
	var choices: Array = choices_v
	if choices.is_empty():
		_set_api_status("请求失败(无可用回复)", "#ff6b6b", true)
		_push_debug_event("在线对话响应无可用choices")
		return ""

	var first_v: Variant = choices[0]
	if typeof(first_v) != TYPE_DICTIONARY:
		_set_api_status("请求失败(message异常)", "#ff6b6b", true)
		_push_debug_event("在线对话首条choice类型异常")
		return ""
	var first: Dictionary = first_v
	var message_v: Variant = first.get("message", {})
	if typeof(message_v) != TYPE_DICTIONARY:
		_set_api_status("请求失败(message内容异常)", "#ff6b6b", true)
		_push_debug_event("在线对话message字段异常")
		return ""
	var message: Dictionary = message_v
	_set_api_status("本地向量和在线对话", "#7bd88f")
	_push_debug_event("在线对话请求成功")
	return String(message.get("content", "")).strip_edges()


func _build_room_anchor_text() -> String:
	return "\n【房间锚点】\n%s\n请把场景信息自然融入回复，避免反复堆砌同一物件。" % state.v_room_context_text()


func _recent_history_for_model(limit: int = 20, max_days: int = 3) -> Array:
	var history: Array = state.chat_history
	if history.is_empty():
		return []

	var has_day: bool = false
	for msg_v in history:
		if typeof(msg_v) != TYPE_DICTIONARY:
			continue
		var msg: Dictionary = msg_v
		var msg_day: int = int(msg.get("day", -1))
		if msg_day > 0:
			has_day = true
			break

	if not has_day:
		var no_day_selected: Array = []
		var from_idx: int = maxi(0, history.size() - 8)
		for i in range(from_idx, history.size()):
			if typeof(history[i]) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = history[i]
			no_day_selected.append({
				"role": String(item.get("role", "user")),
				"content": String(item.get("content", ""))
			})
		return no_day_selected

	var current_day: int = state.living_days
	var min_day: int = maxi(1, current_day - maxi(1, max_days) + 1)
	var selected: Array = []
	for i in range(history.size() - 1, -1, -1):
		if typeof(history[i]) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = history[i]
		var msg_day: int = int(item.get("day", -1))
		if msg_day <= 0:
			if selected.size() < 4:
				selected.append({
					"role": String(item.get("role", "user")),
					"content": String(item.get("content", ""))
				})
			continue
		if msg_day < min_day:
			break
		selected.append({
			"role": String(item.get("role", "user")),
			"content": String(item.get("content", ""))
		})
		if selected.size() >= limit:
			break
	selected.reverse()
	return selected


func _is_meal_query_text(text: String) -> bool:
	var raw: String = String(text).replace(" ", "").replace("\n", "").strip_edges()
	if raw.is_empty():
		return false
	return _offline_text_contains_any(raw, [
		"你想吃什么",
		"你想吃啥",
		"想吃什么",
		"想吃啥",
		"吃什么",
		"吃啥",
		"做什么吃",
		"做点什么",
		"午饭吃什么",
		"晚饭吃什么",
		"早餐吃什么",
		"要不要吃"
	])


func _offline_meal_reply_lines() -> Array[String]:
	var period: String = String(state.time_period_name)
	if period == "早上":
		return [
			"我想吃清淡一点，热牛奶配鸡蛋就很好。",
			"早上我想喝点粥，再配一份小煎蛋，可以吗？",
			"我想吃简单的早餐，面包和水果就够了。"
		]
	if period == "中午":
		return [
			"中午的话，我想吃番茄炒蛋，再来一点青菜。",
			"我想吃热一点的午饭，哥哥陪我一起吃面好不好？",
			"中午我想吃点家常菜，清淡一点就行。"
		]
	if period == "下午":
		return [
			"下午我更想吃点轻食，或者先来一杯热饮也好。",
			"这会儿我想吃点小点心，晚点再认真吃饭。",
			"下午我想吃清爽一点，你陪我慢慢吃好吗？"
		]
	return [
		"晚上我想吃热一点的，汤面或者炖菜都可以。",
		"晚饭我想和你一起吃点家常的，别太油就好。",
		"现在的话，我想吃点暖胃的，吃完我们再慢慢聊。"
	]


func _repair_pronoun_and_meal_reply(player_text: String, reply_text: String) -> String:
	var source: String = String(player_text).strip_edges()
	var fixed: String = String(reply_text).strip_edges()
	if fixed.is_empty():
		return fixed
	var src_no_space: String = source.replace(" ", "").replace("\n", "")
	var meal_query: bool = _is_meal_query_text(src_no_space)
	if meal_query:
		fixed = fixed.replace("哥哥想吃", "我想吃")
		fixed = fixed.replace("哥哥要吃", "我想吃")
		fixed = fixed.replace("哥哥想喝", "我想喝")
		fixed = fixed.replace("哥哥要喝", "我想喝")
		if fixed.find("哥哥想") >= 0 and fixed.find("吗") >= 0:
			fixed = fixed.replace("哥哥想", "我想")
		fixed = fixed.replace("我想要吃", "我想吃")
		fixed = fixed.replace("我想要喝", "我想喝")
		fixed = _force_meal_statement_tone(fixed)
		if String(state.current_location) == "kitchen":
			var generic_hit: bool = _offline_text_contains_any(fixed, [
				"我在听",
				"你继续说",
				"认真听",
				"别骗我",
				"别敷衍"
			])
			var meal_word_hit: bool = _offline_text_contains_any(fixed, [
				"吃",
				"喝",
				"早餐",
				"午饭",
				"晚饭",
				"夜宵",
				"粥",
				"面",
				"菜"
			])
			if generic_hit and not meal_word_hit:
				var lines: Array[String] = _offline_meal_reply_lines()
				if not lines.is_empty():
					fixed = lines[rng.randi_range(0, lines.size() - 1)]
	return fixed.strip_edges()


func _force_meal_statement_tone(text: String) -> String:
	var out: String = String(text).strip_edges()
	if out.is_empty():
		return out
	var self_meal_question: bool = (out.find("我想吃") >= 0 or out.find("我想喝") >= 0) and out.find("吗") >= 0
	if not self_meal_question:
		return out
	out = out.replace("吗？", "。")
	out = out.replace("吗?", "。")
	out = out.replace("吗，", "，")
	if out.ends_with("吗"):
		out = out.substr(0, out.length() - 1).strip_edges()
	if out.ends_with("？") or out.ends_with("?"):
		out = out.left(out.length() - 1).strip_edges()
	if not out.ends_with("。") and not out.ends_with("！") and not out.ends_with("!"):
		out += "。"
	return out


func _avoid_same_reply_on_repeated_input(player_text: String, reply_text: String) -> String:
	var candidate: String = String(reply_text).strip_edges()
	if candidate.is_empty():
		return candidate
	var pair: Dictionary = _last_user_assistant_pair()
	var last_user: String = String(pair.get("user", "")).strip_edges()
	var last_assistant: String = String(pair.get("assistant", "")).strip_edges()
	if last_user.is_empty() or last_assistant.is_empty():
		return candidate
	if _normalize_reply_for_dedupe(last_user) != _normalize_reply_for_dedupe(player_text):
		return candidate
	if _normalize_reply_for_dedupe(last_assistant) != _normalize_reply_for_dedupe(candidate):
		return candidate

	var variants: Array[String] = []
	if _is_meal_query_text(player_text):
		var meal_lines: Array[String] = _offline_meal_reply_lines()
		for meal_line_v in meal_lines:
			var meal_line: String = String(meal_line_v).strip_edges()
			if meal_line.is_empty():
				continue
			variants.append(meal_line)
	var core: String = candidate
	while core.ends_with("。") or core.ends_with("！") or core.ends_with("!"):
		core = core.left(core.length() - 1).strip_edges()
	variants.append("换个说法：%s。" % core)
	variants.append("%s。我这次用不同表达回答你。" % core)
	variants.append("%s。你问第二次，我就答得更直接一点。" % core)

	var last_norm: String = _normalize_reply_for_dedupe(last_assistant)
	for item_v in variants:
		var item: String = _repair_pronoun_and_meal_reply(player_text, String(item_v))
		item = _force_meal_statement_tone(item)
		if item.is_empty():
			continue
		var item_norm: String = _normalize_reply_for_dedupe(item)
		if item_norm.is_empty() or item_norm == last_norm:
			continue
		if not _is_reply_duplicate_text(item):
			return item

	var forced: String = candidate
	if not forced.ends_with("。") and not forced.ends_with("！") and not forced.ends_with("!"):
		forced += "。"
	forced += "（我换一种说法。）"
	return forced


func _last_user_assistant_pair() -> Dictionary:
	var last_assistant: String = ""
	var last_user: String = ""
	for i in range(state.chat_history.size() - 1, -1, -1):
		var item_v: Variant = state.chat_history[i]
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v
		var role: String = String(item.get("role", "")).strip_edges()
		var content: String = String(item.get("content", "")).strip_edges()
		if content.is_empty():
			continue
		if last_assistant.is_empty():
			if role == "assistant":
				last_assistant = content
			continue
		if role == "user":
			last_user = content
			break
	return {
		"user": last_user,
		"assistant": last_assistant
	}


func _ensure_unique_reply_text(player_text: String, reply_text: String) -> String:
	var candidate: String = String(reply_text).strip_edges()
	if candidate.is_empty():
		return candidate
	if not _is_reply_duplicate_text(candidate):
		return candidate

	var variants: Array[String] = []
	if _is_meal_query_text(player_text):
		variants.append_array(_offline_meal_reply_lines())
	var stripped: String = candidate
	while stripped.ends_with("。") or stripped.ends_with("！") or stripped.ends_with("!"):
		stripped = stripped.left(stripped.length() - 1).strip_edges()
	variants.append("%s。这次我认真说：我不是在敷衍你。" % stripped)
	variants.append("%s。换个说法，我会更直接一点。" % stripped)
	variants.append("%s。你刚才那句我听懂了，我按你的问题回答。" % stripped)

	for item in variants:
		var fixed: String = _repair_pronoun_and_meal_reply(player_text, String(item))
		if fixed.is_empty():
			continue
		if not _is_reply_duplicate_text(fixed):
			return fixed

	var forced: String = candidate
	if not forced.ends_with("。") and not forced.ends_with("！") and not forced.ends_with("!"):
		forced += "。"
	forced += "这次我换一种表达。"
	return forced


func _is_reply_duplicate_text(reply_text: String) -> bool:
	var normalized: String = _normalize_reply_for_dedupe(reply_text)
	if normalized.is_empty():
		return false
	var checked: int = 0
	for i in range(state.chat_history.size() - 1, -1, -1):
		if checked >= AI_REPLY_DEDUP_LOOKBACK:
			break
		var item_v: Variant = state.chat_history[i]
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v
		if String(item.get("role", "")).strip_edges() != "assistant":
			continue
		checked += 1
		var old_norm: String = _normalize_reply_for_dedupe(String(item.get("content", "")))
		if old_norm.is_empty():
			continue
		if old_norm == normalized:
			return true
		var min_len: int = mini(old_norm.length(), normalized.length())
		var max_len: int = maxi(old_norm.length(), normalized.length())
		if min_len >= 14 and max_len > 0:
			var overlap_ratio: float = float(min_len) / float(max_len)
			if overlap_ratio >= 0.92 and (old_norm.find(normalized) >= 0 or normalized.find(old_norm) >= 0):
				return true
	return false


func _normalize_reply_for_dedupe(text: String) -> String:
	var out: String = String(text).to_lower().strip_edges()
	var drop_chars: Array[String] = [
		" ",
		"\n",
		"\t",
		"，",
		"。",
		"！",
		"？",
		"；",
		"：",
		",",
		".",
		"!",
		"?",
		";",
		":",
		"（",
		"）",
		"(",
		")",
		"“",
		"”",
		"\"",
		"'"
	]
	for ch in drop_chars:
		out = out.replace(ch, "")
	return out


func _offline_text_contains_any(text: String, words: Array[String]) -> bool:
	for word in words:
		if text.find(word) >= 0:
			return true
	return false


func _set_api_status(status: String, color: String = "#cccccc", write_event: bool = false) -> void:
	state.api_status = status
	state.api_color = color
	if write_event:
		_push_debug_event("运行状态 -> %s" % status)


func _push_debug_event(event_text: String) -> void:
	var clean: String = event_text.strip_edges()
	if clean.is_empty():
		return
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var line: String = "[%02d:%02d:%02d] %s" % [
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
		int(now.get("second", 0)),
		clean
	]
	state.debug_event_log.append(line)
	while state.debug_event_log.size() > 30:
		state.debug_event_log.pop_front()


func _record_turn_debug(
	player_text: String,
	reply_text: String,
	love_change: int,
	mood: String,
	expression_cue: String,
	web_hit: bool,
	source: String
) -> void:
	var short_history_raw: Array = _recent_history_for_model(8, 3)
	var short_history: Array = []
	for msg_v in short_history_raw:
		if typeof(msg_v) != TYPE_DICTIONARY:
			continue
		var msg: Dictionary = msg_v
		var role: String = String(msg.get("role", "user"))
		var content: String = String(msg.get("content", "")).strip_edges()
		if content.is_empty():
			continue
		short_history.append("%s: %s" % [role, content])

	state.debug_last_turn_info = {
		"player_text": player_text,
		"reply_text": reply_text,
		"love_change": love_change,
		"mood": mood,
		"expression_cue": expression_cue,
		"web_hit": web_hit,
		"used_web": web_hit,
		"source": source,
		"playthrough_id": state.playthrough_id,
		"loaded_slot": state.debug_current_loaded_slot,
		"loaded_slot_pid": state.debug_current_loaded_slot_pid,
		"last_saved_slot": state.debug_last_saved_slot,
		"last_saved_slot_pid": state.debug_last_saved_slot_pid,
		"user_input": player_text,
		"short_history": short_history,
		"fact_prompt": memory_model.last_fact_prompt_text,
		"mid_prompt": memory_model.last_mid_prompt_text,
		"mid_hits": memory_model.last_mid_hits.duplicate(true),
		"long_hits": memory_model.last_long_term_hits.duplicate(true),
		"segment_count": maxi(1, _split_reply_segments(reply_text).size()),
		"saved_at_ts": int(Time.get_unix_time_from_system())
	}


func _slot_id_from_index(slot_index: int) -> String:
	return "slot_%03d" % slot_index


func _slot_path_from_index(slot_index: int) -> String:
	if slot_index < 1 or slot_index > SLOT_SAVE_MAX:
		return ""
	return "%s/%s.json" % [SLOT_SAVE_DIR, _slot_id_from_index(slot_index)]


func _ensure_slot_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_SAVE_DIR))


func _load_save_data_from_path(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var byte_size: int = int(file.get_length())
	if byte_size <= 0:
		return {}
	var raw: PackedByteArray = file.get_buffer(byte_size)
	if raw.is_empty():
		return {}
	var text: String = raw.get_string_from_utf8().strip_edges()
	if text.is_empty():
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data as Dictionary


func _apply_loaded_save_data(data: Dictionary, slot_id: String) -> bool:
	var state_data_v: Variant = data.get("state", {})
	if typeof(state_data_v) != TYPE_DICTIONARY:
		return false
	var state_data: Dictionary = state_data_v as Dictionary
	if state_data.is_empty():
		return false
	state.apply_dict(state_data)
	state.debug_current_loaded_slot = slot_id
	state.debug_current_loaded_slot_pid = state.playthrough_id
	runtime_state_was_sanitized = state.last_load_sanitized
	latest_mood = String(data.get("latest_mood", latest_mood))
	if state.is_text_corrupted(latest_mood) or not _is_valid_mood(latest_mood):
		latest_mood = "日常"
		runtime_state_was_sanitized = true
	return true


func _capture_unsaved_baseline() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SESSION_ROLLBACK_DIR))
	_copy_or_remove_user_file(RUNTIME_SAVE_FILE, BASELINE_RUNTIME_BACKUP)
	_copy_or_remove_user_file(VECTOR_DB_FILE, BASELINE_VECTOR_DB_BACKUP)
	_copy_or_remove_user_file(VECTOR_MANIFEST_FILE, BASELINE_VECTOR_MANIFEST_BACKUP)
	session_baseline_ready = true


func _restore_unsaved_baseline() -> void:
	if not session_baseline_ready:
		return
	var vector_db_v: Variant = memory_service.vector_db
	if typeof(vector_db_v) != TYPE_NIL and vector_db_v != null and vector_db_v.has_method("close_backend"):
		vector_db_v.call("close_backend")
	_restore_or_remove_user_file(BASELINE_RUNTIME_BACKUP, RUNTIME_SAVE_FILE)
	_restore_or_remove_user_file(BASELINE_VECTOR_DB_BACKUP, VECTOR_DB_FILE)
	_restore_or_remove_user_file(BASELINE_VECTOR_MANIFEST_BACKUP, VECTOR_MANIFEST_FILE)


func _copy_or_remove_user_file(src_path: String, dst_path: String) -> void:
	var src_abs: String = ProjectSettings.globalize_path(src_path)
	var dst_abs: String = ProjectSettings.globalize_path(dst_path)
	if FileAccess.file_exists(src_abs):
		_copy_abs_file(src_abs, dst_abs)
	else:
		_delete_user_file(dst_path)


func _restore_or_remove_user_file(backup_path: String, target_path: String) -> void:
	var backup_abs: String = ProjectSettings.globalize_path(backup_path)
	var target_abs: String = ProjectSettings.globalize_path(target_path)
	if FileAccess.file_exists(backup_abs):
		_copy_abs_file(backup_abs, target_abs)
	else:
		_delete_user_file(target_path)


func _copy_abs_file(src_abs: String, dst_abs: String) -> bool:
	var src: FileAccess = FileAccess.open(src_abs, FileAccess.READ)
	if src == null:
		return false
	var dst_dir_abs: String = dst_abs.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dst_dir_abs)
	var dst: FileAccess = FileAccess.open(dst_abs, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_buffer(src.get_buffer(src.get_length()))
	dst.flush()
	return true


func _delete_user_file(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return
	DirAccess.remove_absolute(abs_path)


func _save_data_to_path(path: String, slot_id: String) -> bool:
	if path.is_empty() or slot_id.is_empty():
		return false
	state.slot_id = slot_id
	state.refresh_save_cutoff()
	var thumbnail_rel_path: String = ""
	if slot_id.begins_with("slot_"):
		thumbnail_rel_path = _capture_slot_thumbnail(slot_id)
		if thumbnail_rel_path.is_empty():
			var old_data: Dictionary = _load_save_data_from_path(path)
			thumbnail_rel_path = String(old_data.get("thumbnail_rel_path", "")).strip_edges()
	var data: Dictionary = {
		"version": 1,
		"latest_mood": latest_mood,
		"saved_at_ts": int(Time.get_unix_time_from_system()),
		"state": state.to_dict()
	}
	if not thumbnail_rel_path.is_empty():
		data["thumbnail_rel_path"] = thumbnail_rel_path
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func _get_slot_snapshot(slot_index: int) -> Dictionary:
	var slot_path: String = _slot_path_from_index(slot_index)
	if slot_path.is_empty():
		return {}
	var data: Dictionary = _load_save_data_from_path(slot_path)
	if data.is_empty():
		return {}
	var state_data_v: Variant = data.get("state", {})
	if typeof(state_data_v) != TYPE_DICTIONARY:
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
		"playthrough_id": String(state_data.get("playthrough_id", "")),
		"thumbnail_rel_path": String(data.get("thumbnail_rel_path", "")).strip_edges()
	}


func _save_to_slot(slot_index: int) -> bool:
	if slot_index < 1 or slot_index > SLOT_SAVE_MAX:
		return false
	_ensure_slot_save_dir()
	var slot_id: String = _slot_id_from_index(slot_index)
	var slot_path: String = _slot_path_from_index(slot_index)
	if not _save_data_to_path(slot_path, slot_id):
		return false
	state.debug_last_saved_slot = slot_id
	state.debug_last_saved_slot_pid = state.playthrough_id
	_push_debug_event("已保存到存档槽 %s" % str(slot_index))
	return true


func _load_from_slot(slot_index: int) -> bool:
	if slot_index < 1 or slot_index > SLOT_SAVE_MAX:
		return false
	runtime_state_was_sanitized = false
	var slot_id: String = _slot_id_from_index(slot_index)
	var slot_path: String = _slot_path_from_index(slot_index)
	var data: Dictionary = _load_save_data_from_path(slot_path)
	if data.is_empty():
		return false
	if not _apply_loaded_save_data(data, slot_id):
		return false
	_capture_unsaved_baseline()
	_push_debug_event("已读取存档槽 %s" % str(slot_index))
	return true


func _load_runtime_state() -> bool:
	runtime_state_was_sanitized = false
	var data: Dictionary = _load_save_data_from_path(RUNTIME_SAVE_FILE)
	if data.is_empty():
		return false
	if not _apply_loaded_save_data(data, "runtime_save"):
		return false
	_capture_unsaved_baseline()
	_push_debug_event("已加载运行时存档 runtime_save")
	return true


func _slot_thumbnail_path(slot_id: String) -> String:
	var clean_slot_id: String = slot_id.strip_edges()
	if clean_slot_id.is_empty() or not clean_slot_id.begins_with("slot_"):
		return ""
	return "%s/%s_thumb.png" % [SLOT_SAVE_DIR, clean_slot_id]


func _capture_slot_thumbnail(slot_id: String) -> String:
	var rel_path: String = _slot_thumbnail_path(slot_id)
	if rel_path.is_empty():
		return ""
	if background_rect == null:
		return ""
	var bg_texture: Texture2D = background_rect.texture
	if bg_texture == null:
		return ""
	var screenshot: Image = bg_texture.get_image()
	if screenshot == null or screenshot.is_empty():
		return ""
	if screenshot.get_width() <= 1 or screenshot.get_height() <= 1:
		return ""
	if screenshot.get_width() > 960:
		var target_height: int = maxi(1, int(round(float(screenshot.get_height()) * (960.0 / float(screenshot.get_width())))))
		screenshot.resize(960, target_height, Image.INTERPOLATE_LANCZOS)
	var save_err: int = screenshot.save_png(ProjectSettings.globalize_path(rel_path))
	if save_err != OK:
		return ""
	return rel_path


func _is_valid_mood(mood: String) -> bool:
	var value: String = mood.strip_edges()
	if value.is_empty():
		return false
	return value == "日常" or value == "害羞" or value == "激动" or value == "撒娇的生气" or value == "担忧" or value == "消极"


func _save_runtime_state() -> void:
	if _save_data_to_path(RUNTIME_SAVE_FILE, "runtime_save"):
		state.debug_last_saved_slot = "runtime_save"
		state.debug_last_saved_slot_pid = state.playthrough_id
