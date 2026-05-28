extends RefCounted
class_name VictoriaState

const ROOM_CONTEXTS := {
	"sister_room": {
		"name": "妹妹的房间",
		"style": "这是维多利亚自己的卧室，整体简洁温馨，分为收纳、学习和休息三个区域。空间偏日式简约，带一点年轻人的个性化装饰，聊天氛围应自然、亲近、带生活感。",
		"rules": "在这里可自然提到书桌、衣柜、床铺、窗边、海报等卧室元素；不要凭空提到客厅沙发、电视、厨房灶台或哥哥房间里的物品。除非哥哥追问或当前动作强相关，不要反复提同一件物品（例如多肉植物）。"
	},
	"living_room": {
		"name": "客厅",
		"style": "这是一间明亮的现代简约客厅，整体偏日式北欧风，适合放松、闲聊和一起做轻松的小事。氛围温和、开阔，有明显的居家感。",
		"rules": "在这里可自然提到沙发、茶几、电视柜、窗边、地毯等客厅元素；不要把这里说成卧室或厨房。除非哥哥追问细节，不要连续重复同一物件名。"
	},
	"kitchen": {
		"name": "\u53a8\u623f",
		"style": "\u8fd9\u662f\u505a\u996d\u548c\u51c6\u5907\u996e\u54c1\u7684\u5730\u65b9\uff0c\u7a7a\u6c14\u91cc\u53ef\u4ee5\u6709\u6c34\u6c7d\u3001\u9910\u5177\u58f0\u548c\u98df\u7269\u9999\u6c14\uff0c\u9002\u5408\u505a\u996d\u3001\u5012\u6c34\u3001\u51c6\u5907\u70b9\u5fc3\u6216\u56f4\u7ed5\u9910\u98df\u5c55\u5f00\u81ea\u7136\u4e92\u52a8\u3002",
		"rules": "\u53ea\u6709\u5728\u8fd9\u91cc\u6216\u8bdd\u9898\u81ea\u7136\u8f6c\u5230\u505a\u996d\u65f6\uff0c\u624d\u4e3b\u52a8\u63cf\u5199\u5f00\u706b\u3001\u9505\u3001\u7076\u53f0\u3001\u9910\u5177\u7b49\u52a8\u4f5c\uff1b\u4e0d\u8981\u628a\u53a8\u623f\u8bf4\u6210\u5367\u5ba4\u6216\u5ba2\u5385\u3002"
	},
	"player_room": {
		"name": "\u54e5\u54e5\u7684\u623f\u95f4",
		"style": "\u8fd9\u662f\u54e5\u54e5\u7684\u79c1\u4eba\u7a7a\u95f4\uff0c\u7ef4\u591a\u5229\u4e9a\u4f1a\u66f4\u62d8\u8c28\u3001\u66f4\u6ce8\u610f\u5206\u5bf8\uff1b\u597d\u611f\u5ea6\u9ad8\u65f6\u53ef\u4ee5\u8868\u73b0\u51fa\u60f3\u9760\u8fd1\u4f46\u53c8\u6015\u6253\u6270\u7684\u4f9d\u8d56\u611f\u3002",
		"rules": "\u5728\u8fd9\u91cc\u53ef\u4ee5\u63d0\u5230\u54e5\u54e5\u7684\u4e66\u684c\u3001\u7535\u8111\u3001\u6905\u5b50\u3001\u5e8a\u94fa\u548c\u4e2a\u4eba\u7269\u54c1\uff0c\u4f46\u4e0d\u8981\u8868\u73b0\u5f97\u50cf\u5979\u5b8c\u5168\u62e5\u6709\u8fd9\u4e2a\u623f\u95f4\uff1b\u4f4e\u597d\u611f\u65f6\u5c24\u5176\u8981\u514b\u5236\u3002"
	}
}
const VICTORIA_ACTIVE_ROOMS: Array[String] = ["sister_room", "living_room", "kitchen"]
const VICTORIA_PERIOD_SWITCH_CHANCE := 0.30
const DEFAULT_MONEY_BALANCE := 1000

const TOPIC_BUCKETS := {
	"checkin": [
		"先确认哥哥当下状态，再给一小句贴心回应。",
		"从情绪观察切入，问他现在是累、烦，还是还算轻松。",
		"先做简短关心，再顺着他的回答继续聊。"
	],
	"daily": [
		"从今天的微小日常切入，不要上来就讲餐食。",
		"聊一个轻松生活点，比如刚做完的小事、窗外见闻或家里变化。",
		"用自然口吻聊近况，避免固定模板开场。"
	],
	"plan": [
		"围绕接下来半天的小安排展开，语气自然、可商量。",
		"给出一个轻量计划点，让哥哥可以接话或调整。",
		"从“待会做什么”切入，但不要变成命令语气。"
	],
	"hobby": [
		"从轻兴趣切入，如书影音、游戏、音乐或小爱好。",
		"聊最近想看的内容或想做的小事，保持轻松氛围。",
		"用一个兴趣点打开话题，再观察哥哥是否愿意延展。"
	],
	"emotion": [
		"先共情哥哥情绪，再给一句不夸张的陪伴回应。",
		"用温和语气处理情绪话题，不要说教。",
		"若哥哥状态低落，优先安抚和陪伴，再轻微推进话题。"
	],
	"playful": [
		"给一个轻微撒娇或斗嘴点，但不要过火。",
		"用带一点俏皮感的回应活跃气氛，保持分寸。",
		"可以小小调侃哥哥，但要留出温柔回弹。"
	],
	"room": [
		"结合当前房间做一句自然场景过渡，不堆物件细节。",
		"从现在所在空间的体验感切入，轻描淡写即可。",
		"借当前环境开话头，但避免反复点名同一物品。"
	],
	"meal": [
		"仅在情境确实自然时，轻提要不要吃点东西。",
		"如果要提餐食，保持简短，不要连续两轮都提。",
		"餐食只能作为辅话题，不要霸占整轮对话。"
	]
}
const DEFAULT_OBSERVED_LOG := "你是我的哥哥，是我在这个世界上唯一连接的人。"
const DEFAULT_CURRENT_ATTITUDE := "你目前对哥哥保持着小心翼翼的依赖，试图扮演一个完美的妹妹来讨他欢心。"
const MOJIBAKE_MARKERS: Array[String] = [
	"锛",
	"銆",
	"鈥",
	"鍝",
	"鎴",
	"浣",
	"闄",
	"澶",
	"涓",
	"鏄",
	"鐨",
	"绗",
	"姣"
]

var love_score: int = 0
var money_balance: int = DEFAULT_MONEY_BALANCE
var living_days: int = 1
var current_cycle_seconds: int = 480
var display_time: String = "08:00"
var time_period_name: String = "早上"

var prologue_done: bool = false
var stage_60_triggered: bool = false
var truth_revealed: bool = false
var daily_greeted: bool = false
var dialogue_counter: int = 0
var exit_count: int = 0
var period_initiative_done: bool = false
var period_transition_pending: bool = false
var debug_panel_open: bool = false
var debug_current_loaded_slot: String = ""
var debug_current_loaded_slot_pid: String = ""
var debug_last_saved_slot: String = ""
var debug_last_saved_slot_pid: String = ""
var debug_last_turn_info: Dictionary = {}
var debug_last_summary_info: Dictionary = {}
var debug_event_log: Array = []
var api_status: String = "本地向量(待机)"
var api_color: String = "#cccccc"
var input_live_text: String = ""
var night_music_active: bool = false
var web_search_enabled: bool = true
var bgm_volume_percent: float = 82.5
var sfx_volume_percent: float = 100.0
var v_sprite_file: String = "everyday.png"
var v_sprite_zoom: float = 1.0
var v_sprite_yoffset: int = 340
var v_sprite_alpha: float = 1.0
var v_sprite_mood: String = "日常"
var v_reply_expression_profile: Dictionary = {
	"mood": "日常",
	"sprite": "everyday.png",
	"zoom": 1.0,
	"yoffset": 340,
	"alpha": 1.0
}

var current_location: String = "sister_room"
var victoria_location: String = "sister_room"
var room_nav_open: bool = false
var room_switch_skip_prompt: bool = false

var observed_log: String = DEFAULT_OBSERVED_LOG
var current_attitude: String = DEFAULT_CURRENT_ATTITUDE
var attitude_last_update_day: int = 0
var last_load_sanitized: bool = false

var chat_history: Array = []
var pending_summaries: Array = []
var pending_memory_records: Array = []
var pending_vector_records: Array = []
var pending_vector_mid_archives: Array = []
var memory_facts: Dictionary = {}
var mid_memory_entries: Array = []
var long_term_memory_entries: Array = []
var recent_topic_tags: Array = []

var playthrough_id: String = ""
var player_id: String = ""
var timeline_id: String = ""
var slot_id: String = "runtime_save"
var save_cutoff_ts: int = 0
var visible_timeline_ids: Array[String] = []
var memory_schema_version: int = 3
var blackjack_bluff_history: Array = []
var blackjack_player_read_profile: Dictionary = {
	"fell_for_bluff_count": 0,
	"caught_lie_count": 0,
	"truth_help_count": 0,
	"shared_hand_info_count": 0,
	"probe_count": 0
}
var blackjack_trust_score: int = 50
var blackjack_recent_probe_styles: Array[String] = []

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	_ensure_memory_identity()
	refresh_time()

func _ensure_memory_identity() -> void:
	var now_ts: int = int(Time.get_unix_time_from_system())
	if playthrough_id.is_empty():
		playthrough_id = "save_%s" % str(now_ts)
	if player_id.is_empty():
		player_id = "local_player"
	if timeline_id.is_empty():
		timeline_id = "timeline_root"
	if visible_timeline_ids.is_empty():
		visible_timeline_ids = [timeline_id]
	if save_cutoff_ts <= 0:
		save_cutoff_ts = now_ts

func refresh_save_cutoff() -> void:
	save_cutoff_ts = int(Time.get_unix_time_from_system())
	if visible_timeline_ids.is_empty():
		visible_timeline_ids = [timeline_id]

func refresh_time() -> void:
	var total: int = int(current_cycle_seconds)
	if total < 0:
		total = 0
	var hour: int = int(total / 60) % 24
	var minute: int = total % 60
	display_time = "%02d:%02d" % [hour, minute]
	time_period_name = _period_name_from_hour(hour)

func randomize_victoria_location(exclude_room: String = "player_room") -> void:
	var candidates: Array[String] = []
	for room_key in VICTORIA_ACTIVE_ROOMS:
		if room_key == exclude_room:
			continue
		if ROOM_CONTEXTS.has(room_key):
			candidates.append(room_key)
	if candidates.is_empty():
		victoria_location = "sister_room"
		return
	victoria_location = candidates[rng.randi_range(0, candidates.size() - 1)]

func victoria_is_here() -> bool:
	return current_location == victoria_location

func maybe_switch_victoria_location(chance: float = VICTORIA_PERIOD_SWITCH_CHANCE) -> bool:
	var probability: float = clampf(chance, 0.0, 1.0)
	if rng.randf() >= probability:
		return false
	var candidates: Array[String] = []
	for room_key in VICTORIA_ACTIVE_ROOMS:
		if room_key == victoria_location:
			continue
		if ROOM_CONTEXTS.has(room_key):
			candidates.append(room_key)
	if candidates.is_empty():
		return false
	victoria_location = candidates[rng.randi_range(0, candidates.size() - 1)]
	return true

func _period_name_from_hour(hour: int) -> String:
	if hour >= 6 and hour < 11:
		return "早上"
	if hour >= 11 and hour < 14:
		return "中午"
	if hour >= 14 and hour < 18:
		return "下午"
	return "晚上"

func apply_love_change(delta: int) -> void:
	love_score = clamp(love_score + delta, 0, 100)


func apply_money_change(delta: int) -> int:
	var before: int = money_balance
	money_balance = maxi(0, money_balance + delta)
	return money_balance - before

func v_love_stage_attitude() -> String:
	if love_score < 30:
		return "你们仍在建立安全感。你先观察、再靠近；若哥哥敷衍，你会本能收起热情，用礼貌和克制保护自己。"
	if love_score < 70:
		return "你们进入熟悉阶段。你会更自然地撒娇、斗嘴与试探边界；被忽视时会小别扭，但仍愿意主动修复关系。"
	return "你已深度依恋哥哥。你表达会更亲密、更在意回应速度与专注度；若被冷落会明显不安，但不会失去分寸。"

func v_long_term_attitude() -> String:
	var text: String = String(current_attitude).strip_edges()
	if text.is_empty():
		return "你对哥哥保持着谨慎依赖，会根据长期相处结果慢慢调整自己的表达方式。"
	return text

func is_text_corrupted(text: String) -> bool:
	return _looks_like_mojibake_text(text)

func v_room_context_text() -> String:
	var info: Dictionary = ROOM_CONTEXTS.get(current_location, ROOM_CONTEXTS["sister_room"])
	return "【当前所在房间】%s\n【房间样式】%s\n【场景约束】%s\n【描写尺度】房间描述只作为背景认知，不要每句话都堆物品和颜色细节。日常聊天时点到为止，例如说“沙发”“地毯”“书桌”即可；只有哥哥主动询问环境、角色正在使用某件物品，或需要营造氛围时，才补充更具体的外观描述。\n【防复读】同一轮及相邻几轮对话中，避免重复提同一件具体物品名；若非必要，不要反复点名“多肉植物”这类细节。\n【括号动作写法】若你要用括号补充动作、表情、停顿或心理波动，只能写你自己的即时反应，要像少女本人正在说话时顺手带出的动作，不要写成第三人称旁白或镜头说明。可以写“（轻轻拉了拉袖口）”“（偷偷看你一眼）”，禁止写“（她看向窗边）”“（少女坐在沙发上）”“（房间里很安静）”。" % [
		String(info.get("name", "妹妹的房间")),
		String(info.get("style", "")),
		String(info.get("rules", ""))
	]

func v_meal_rule_text() -> String:
	if time_period_name == "早上":
		return "当前是早上。若提到餐食，请使用“早餐”，避免“午饭/晚饭”。"
	if time_period_name == "中午":
		return "当前是中午。若提到餐食，请使用“午饭”，禁止说“早餐”。"
	if time_period_name == "下午":
		return "当前是下午。若提到餐食，可用“午饭/下午茶”，禁止说“早餐”。"
	return "当前是晚上。若提到餐食，请使用“晚饭/夜宵”，禁止说“早餐/午饭”。"

func v_finish_rule_text() -> String:
	if love_score < 35:
		return "当前好感较低：若哥哥明显收尾（如“再见/我先去忙”），你可以更主动结束，并在句末加 [FINISH]。"
	if love_score >= 70:
		return "当前好感较高：除非哥哥明确说要走，否则禁止主动加 [FINISH]；告别时要有不舍感。"
	return "当前好感中等：仅在哥哥明确结束话题时，才在句末加 [FINISH]。"

func room_request_target(text: String) -> String:
	var raw: String = text.replace(" ", "").replace("\n", "")
	if raw.is_empty():
		return ""
	var move_words: Array = ["去", "到", "回", "进", "换", "走", "带我", "过去", "移动"]
	var has_move_intent: bool = false
	for word in move_words:
		if raw.find(word) >= 0:
			has_move_intent = true
			break
	if not has_move_intent:
		return ""

	if _contains_any(raw, ["客厅", "大厅"]):
		return "living_room"
	if _contains_any(raw, ["厨房", "灶台"]):
		return "kitchen"
	if _contains_any(raw, ["我的房间", "我房间", "我的卧室", "我卧室", "哥哥的房间", "哥哥房间", "自己的房间", "自己房间"]):
		return "player_room"
	if _contains_any(raw, ["你的卧室", "你卧室", "你的房间", "你房间", "妹妹的卧室", "妹妹卧室", "妹妹的房间", "妹妹房间", "维多利亚的房间", "维多利亚房间", "卧室"]):
		return "sister_room"
	return ""


func room_request_with_victoria(text: String) -> bool:
	var raw: String = text.replace(" ", "").replace("\n", "")
	if raw.is_empty():
		return false
	if _contains_any(raw, ["我们", "咱们", "一起", "一块", "跟我", "陪我", "带你"]):
		return true
	# 兼容口语：比如“走吧，去客厅”，在同房间对话时默认妹妹会理解为结伴。
	if _contains_any(raw, ["走吧", "去吧", "过去吧", "回去吧"]):
		return true
	return false

func _contains_any(text: String, words: Array) -> bool:
	for item in words:
		if text.find(String(item)) >= 0:
			return true
	return false

func _recent_topic_groups(max_items: int = 8) -> Array[String]:
	var cleaned: Array[String] = []
	for item in recent_topic_tags:
		var text: String = String(item).strip_edges()
		if not text.is_empty():
			cleaned.append(text)
	if cleaned.size() <= max_items:
		return cleaned
	var out: Array[String] = []
	for i in range(cleaned.size() - max_items, cleaned.size()):
		out.append(cleaned[i])
	return out

func _push_topic_group(group: String, max_items: int = 8) -> void:
	var g: String = String(group).strip_edges()
	if g.is_empty():
		return
	var history: Array[String] = _recent_topic_groups(max_items)
	history.append(g)
	recent_topic_tags = history
	while recent_topic_tags.size() > max_items:
		recent_topic_tags.pop_front()

func v_topic_plan(player_text: String, proactive: bool = false) -> Dictionary:
	var text: String = String(player_text)
	var weights: Dictionary = {
		"checkin": 1.20,
		"daily": 1.10,
		"plan": 0.95,
		"hobby": 0.85,
		"emotion": 0.90,
		"playful": 0.70,
		"room": 0.70,
		"meal": 0.30
	}

	if time_period_name == "早上":
		weights["checkin"] += 0.40
		weights["plan"] += 0.30
		weights["meal"] += 0.08
	elif time_period_name == "中午":
		weights["daily"] += 0.25
		weights["plan"] += 0.20
		weights["meal"] += 0.12
	elif time_period_name == "下午":
		weights["hobby"] += 0.30
		weights["daily"] += 0.20
		weights["room"] += 0.15
	elif time_period_name == "晚上":
		weights["emotion"] += 0.35
		weights["playful"] += 0.20
		weights["meal"] += 0.10

	if current_location == "kitchen":
		weights["meal"] += 0.25
		weights["daily"] += 0.10
	elif current_location == "living_room":
		weights["daily"] += 0.15
		weights["room"] += 0.20
	elif current_location == "sister_room":
		weights["hobby"] += 0.12
		weights["emotion"] += 0.12
	elif current_location == "player_room":
		weights["checkin"] += 0.12
		weights["emotion"] += 0.08

	if love_score < 30:
		weights["checkin"] += 0.15
		weights["playful"] *= 0.75
	elif love_score >= 70:
		weights["playful"] += 0.18
		weights["emotion"] += 0.12

	if proactive:
		weights["checkin"] += 0.25
		weights["room"] += 0.12
		weights["meal"] *= 0.80

	if _contains_any(text, ["难受", "委屈", "烦", "压力", "累", "不开心", "崩溃", "痛苦"]):
		weights["emotion"] += 0.60
	if _contains_any(text, ["计划", "安排", "待会", "等下", "今天", "明天"]):
		weights["plan"] += 0.45
	if _contains_any(text, ["书", "电影", "剧", "动漫", "游戏", "音乐", "小说", "视频"]):
		weights["hobby"] += 0.55
	if _contains_any(text, ["房间", "客厅", "卧室", "厨房", "窗", "书桌", "床"]):
		weights["room"] += 0.45
	if _contains_any(text, ["吃", "饭", "早餐", "午饭", "晚饭", "夜宵", "做饭"]):
		weights["meal"] += 0.35

	var recent: Array[String] = _recent_topic_groups(8)
	var recent3: Array[String] = []
	var recent6: Array[String] = []
	for i in range(maxi(0, recent.size() - 3), recent.size()):
		recent3.append(recent[i])
	for i in range(maxi(0, recent.size() - 6), recent.size()):
		recent6.append(recent[i])

	for key in weights.keys():
		var group_name: String = String(key)
		if recent3.has(group_name):
			weights[group_name] = float(weights[group_name]) * 0.22
		elif recent6.has(group_name):
			weights[group_name] = float(weights[group_name]) * 0.60

	var meal_count_recent3: int = 0
	for item in recent3:
		if item == "meal":
			meal_count_recent3 += 1
	if meal_count_recent3 >= 1:
		weights["meal"] = float(weights["meal"]) * 0.20

	var group: String = _weighted_pick(weights, "daily")
	if group == "meal" and meal_count_recent3 >= 1:
		group = "daily"

	var seed_pool: Array = TOPIC_BUCKETS.get(group, TOPIC_BUCKETS["daily"])
	var seed: String = String(seed_pool[rng.randi_range(0, seed_pool.size() - 1)])
	var hint: String = "先紧贴回应哥哥当前输入，再自然延展到这个方向：%s" % seed
	if text.strip_edges().is_empty():
		hint = "请围绕这个方向自然开场：%s" % seed

	_push_topic_group(group, 8)
	var recent_show_list: Array[String] = _recent_topic_groups(4)

	var recent_show: String = "无"
	if recent_show_list.size() > 0:
		recent_show = "、".join(recent_show_list)

	return {
		"group": group,
		"hint": hint,
		"recent": recent_show
	}

func _weighted_pick(weight_map: Dictionary, fallback: String) -> String:
	var pairs: Array[Dictionary] = []
	var total: float = 0.0
	for key in weight_map.keys():
		var w: float = float(weight_map[key])
		if w > 0.0:
			pairs.append({"key": String(key), "weight": w})
			total += w
	if pairs.is_empty() or total <= 0.0:
		return fallback
	var roll: float = rng.randf() * total
	var upto: float = 0.0
	for pair in pairs:
		var w: float = float(pair.get("weight", 0.0))
		upto += w
		if roll <= upto:
			return String(pair.get("key", fallback))
	return String(pairs[pairs.size() - 1].get("key", fallback))

func shift_time_logic() -> Dictionary:
	exit_count = 0
	room_nav_open = false
	var old_period_name: String = time_period_name
	var result: Dictionary = {
		"night_rollover": false,
		"narration": []
	}

	if time_period_name == "晚上":
		result["night_rollover"] = true
		# Night rollover is always anchored in player's bedroom.
		current_location = "player_room"
		result["narration"] = [
			"夜深了，公寓里渐渐安静下来了。",
			"我回到房间，在模糊睡意中，似乎感觉门外有一道目光停留了许久……",
			"（正在进行今日记忆神经拓扑同步……）",
			"新的一天开始了。"
		]
		living_days += 1
		current_cycle_seconds = 480
		daily_greeted = false
		period_initiative_done = false
		period_transition_pending = true
	else:
		result["narration"] = ["时间悄悄过去了一阵。"]
		current_cycle_seconds += 240
		period_transition_pending = true
		period_initiative_done = false

	refresh_time()
	if old_period_name != time_period_name:
		maybe_switch_victoria_location(VICTORIA_PERIOD_SWITCH_CHANCE)
	if not ROOM_CONTEXTS.has(victoria_location) or victoria_location == "player_room":
		randomize_victoria_location("player_room")
	return result

func to_dict() -> Dictionary:
	return {
		"love_score": love_score,
		"money_balance": money_balance,
		"living_days": living_days,
		"current_cycle_seconds": current_cycle_seconds,
		"display_time": display_time,
		"time_period_name": time_period_name,
		"prologue_done": prologue_done,
		"stage_60_triggered": stage_60_triggered,
		"truth_revealed": truth_revealed,
		"daily_greeted": daily_greeted,
		"dialogue_counter": dialogue_counter,
		"exit_count": exit_count,
		"period_initiative_done": period_initiative_done,
		"period_transition_pending": period_transition_pending,
		"debug_panel_open": debug_panel_open,
		"debug_current_loaded_slot": debug_current_loaded_slot,
		"debug_current_loaded_slot_pid": debug_current_loaded_slot_pid,
		"debug_last_saved_slot": debug_last_saved_slot,
		"debug_last_saved_slot_pid": debug_last_saved_slot_pid,
		"debug_last_turn_info": debug_last_turn_info.duplicate(true),
		"debug_last_summary_info": debug_last_summary_info.duplicate(true),
		"debug_event_log": debug_event_log.duplicate(true),
		"api_status": api_status,
		"api_color": api_color,
		"input_live_text": input_live_text,
		"night_music_active": night_music_active,
		"web_search_enabled": web_search_enabled,
		"bgm_volume_percent": bgm_volume_percent,
		"sfx_volume_percent": sfx_volume_percent,
		"v_sprite_file": v_sprite_file,
		"v_sprite_zoom": v_sprite_zoom,
		"v_sprite_yoffset": v_sprite_yoffset,
		"v_sprite_alpha": v_sprite_alpha,
		"v_sprite_mood": v_sprite_mood,
		"v_reply_expression_profile": v_reply_expression_profile.duplicate(true),
		"current_location": current_location,
		"victoria_location": victoria_location,
		"room_nav_open": room_nav_open,
		"room_switch_skip_prompt": room_switch_skip_prompt,
		"observed_log": observed_log,
		"current_attitude": current_attitude,
		"attitude_last_update_day": attitude_last_update_day,
		"chat_history": chat_history.duplicate(true),
		"pending_summaries": pending_summaries.duplicate(true),
		"pending_memory_records": pending_memory_records.duplicate(true),
		"pending_vector_records": pending_vector_records.duplicate(true),
		"pending_vector_mid_archives": pending_vector_mid_archives.duplicate(true),
		"memory_facts": memory_facts.duplicate(true),
		"mid_memory_entries": mid_memory_entries.duplicate(true),
		"long_term_memory_entries": _compact_long_term_entries(),
		"recent_topic_tags": recent_topic_tags.duplicate(true),
		"playthrough_id": playthrough_id,
		"player_id": player_id,
		"timeline_id": timeline_id,
		"slot_id": slot_id,
		"save_cutoff_ts": save_cutoff_ts,
		"visible_timeline_ids": visible_timeline_ids.duplicate(true),
		"memory_schema_version": memory_schema_version,
		"blackjack_bluff_history": blackjack_bluff_history.duplicate(true),
		"blackjack_player_read_profile": blackjack_player_read_profile.duplicate(true),
		"blackjack_trust_score": blackjack_trust_score,
		"blackjack_recent_probe_styles": blackjack_recent_probe_styles.duplicate(true)
	}

func apply_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	love_score = int(data.get("love_score", love_score))
	money_balance = maxi(0, int(data.get("money_balance", money_balance)))
	living_days = int(data.get("living_days", living_days))
	current_cycle_seconds = int(data.get("current_cycle_seconds", current_cycle_seconds))
	display_time = String(data.get("display_time", display_time))
	time_period_name = String(data.get("time_period_name", time_period_name))
	prologue_done = bool(data.get("prologue_done", prologue_done))
	stage_60_triggered = bool(data.get("stage_60_triggered", stage_60_triggered))
	truth_revealed = bool(data.get("truth_revealed", truth_revealed))
	daily_greeted = bool(data.get("daily_greeted", daily_greeted))
	dialogue_counter = int(data.get("dialogue_counter", dialogue_counter))
	exit_count = int(data.get("exit_count", exit_count))
	period_initiative_done = bool(data.get("period_initiative_done", period_initiative_done))
	period_transition_pending = bool(data.get("period_transition_pending", period_transition_pending))
	debug_panel_open = bool(data.get("debug_panel_open", debug_panel_open))
	debug_current_loaded_slot = String(data.get("debug_current_loaded_slot", debug_current_loaded_slot))
	debug_current_loaded_slot_pid = String(data.get("debug_current_loaded_slot_pid", debug_current_loaded_slot_pid))
	debug_last_saved_slot = String(data.get("debug_last_saved_slot", debug_last_saved_slot))
	debug_last_saved_slot_pid = String(data.get("debug_last_saved_slot_pid", debug_last_saved_slot_pid))
	debug_last_turn_info = data.get("debug_last_turn_info", {}).duplicate(true) if typeof(data.get("debug_last_turn_info", {})) == TYPE_DICTIONARY else {}
	debug_last_summary_info = data.get("debug_last_summary_info", {}).duplicate(true) if typeof(data.get("debug_last_summary_info", {})) == TYPE_DICTIONARY else {}
	debug_event_log = data.get("debug_event_log", []).duplicate(true) if typeof(data.get("debug_event_log", [])) == TYPE_ARRAY else []
	api_status = String(data.get("api_status", api_status))
	api_color = String(data.get("api_color", api_color))
	input_live_text = String(data.get("input_live_text", input_live_text))
	night_music_active = bool(data.get("night_music_active", night_music_active))
	web_search_enabled = bool(data.get("web_search_enabled", web_search_enabled))
	bgm_volume_percent = clampf(float(data.get("bgm_volume_percent", bgm_volume_percent)), 0.0, 100.0)
	sfx_volume_percent = clampf(float(data.get("sfx_volume_percent", sfx_volume_percent)), 0.0, 100.0)
	v_sprite_file = String(data.get("v_sprite_file", v_sprite_file))
	v_sprite_zoom = float(data.get("v_sprite_zoom", v_sprite_zoom))
	v_sprite_yoffset = int(data.get("v_sprite_yoffset", v_sprite_yoffset))
	v_sprite_alpha = float(data.get("v_sprite_alpha", v_sprite_alpha))
	v_sprite_mood = String(data.get("v_sprite_mood", v_sprite_mood))
	v_reply_expression_profile = data.get("v_reply_expression_profile", {}).duplicate(true) if typeof(data.get("v_reply_expression_profile", {})) == TYPE_DICTIONARY else v_reply_expression_profile
	current_location = String(data.get("current_location", current_location))
	victoria_location = String(data.get("victoria_location", victoria_location))
	room_nav_open = bool(data.get("room_nav_open", room_nav_open))
	room_switch_skip_prompt = bool(data.get("room_switch_skip_prompt", room_switch_skip_prompt))
	observed_log = String(data.get("observed_log", observed_log))
	current_attitude = String(data.get("current_attitude", current_attitude))
	attitude_last_update_day = int(data.get("attitude_last_update_day", attitude_last_update_day))
	chat_history = data.get("chat_history", []).duplicate(true) if typeof(data.get("chat_history", [])) == TYPE_ARRAY else []
	pending_summaries = data.get("pending_summaries", []).duplicate(true) if typeof(data.get("pending_summaries", [])) == TYPE_ARRAY else []
	pending_memory_records = data.get("pending_memory_records", []).duplicate(true) if typeof(data.get("pending_memory_records", [])) == TYPE_ARRAY else []
	pending_vector_records = data.get("pending_vector_records", []).duplicate(true) if typeof(data.get("pending_vector_records", [])) == TYPE_ARRAY else []
	pending_vector_mid_archives = data.get("pending_vector_mid_archives", []).duplicate(true) if typeof(data.get("pending_vector_mid_archives", [])) == TYPE_ARRAY else []
	memory_facts = data.get("memory_facts", {}).duplicate(true) if typeof(data.get("memory_facts", {})) == TYPE_DICTIONARY else {}
	mid_memory_entries = data.get("mid_memory_entries", []).duplicate(true) if typeof(data.get("mid_memory_entries", [])) == TYPE_ARRAY else []
	long_term_memory_entries = data.get("long_term_memory_entries", []).duplicate(true) if typeof(data.get("long_term_memory_entries", [])) == TYPE_ARRAY else []
	long_term_memory_entries = _compact_long_term_entries()
	recent_topic_tags = data.get("recent_topic_tags", []).duplicate(true) if typeof(data.get("recent_topic_tags", [])) == TYPE_ARRAY else []
	playthrough_id = String(data.get("playthrough_id", playthrough_id))
	player_id = String(data.get("player_id", player_id))
	timeline_id = String(data.get("timeline_id", timeline_id))
	slot_id = String(data.get("slot_id", slot_id))
	save_cutoff_ts = int(data.get("save_cutoff_ts", save_cutoff_ts))
	var visible_v: Variant = data.get("visible_timeline_ids", [])
	if typeof(visible_v) == TYPE_ARRAY:
		visible_timeline_ids.clear()
		for item in visible_v:
			var tid: String = String(item).strip_edges()
			if not tid.is_empty():
				visible_timeline_ids.append(tid)
	else:
		visible_timeline_ids.clear()
	memory_schema_version = int(data.get("memory_schema_version", memory_schema_version))
	blackjack_bluff_history = data.get("blackjack_bluff_history", []).duplicate(true) if typeof(data.get("blackjack_bluff_history", [])) == TYPE_ARRAY else []
	blackjack_player_read_profile = data.get("blackjack_player_read_profile", blackjack_player_read_profile).duplicate(true) if typeof(data.get("blackjack_player_read_profile", blackjack_player_read_profile)) == TYPE_DICTIONARY else blackjack_player_read_profile.duplicate(true)
	blackjack_trust_score = int(data.get("blackjack_trust_score", blackjack_trust_score))
	var recent_styles_v: Variant = data.get("blackjack_recent_probe_styles", [])
	if typeof(recent_styles_v) == TYPE_ARRAY:
		blackjack_recent_probe_styles.clear()
		for style_v in recent_styles_v:
			var style: String = String(style_v).strip_edges()
			if not style.is_empty():
				blackjack_recent_probe_styles.append(style)
	else:
		blackjack_recent_probe_styles.clear()
	last_load_sanitized = _sanitize_loaded_runtime()
	_ensure_memory_identity()
	refresh_time()

func _sanitize_loaded_runtime() -> bool:
	var touched: bool = false
	if not ROOM_CONTEXTS.has(current_location):
		current_location = "sister_room"
		touched = true
	if not ROOM_CONTEXTS.has(victoria_location) or victoria_location == "player_room":
		randomize_victoria_location("player_room")
		touched = true
	if truth_revealed:
		# 兼容旧档：移除旧版“真相结局锁定”状态，统一按普通妹妹设定继续游戏。
		truth_revealed = false
		touched = true

	if _looks_like_mojibake_text(observed_log):
		observed_log = DEFAULT_OBSERVED_LOG
		touched = true
	if _looks_like_mojibake_text(current_attitude):
		current_attitude = DEFAULT_CURRENT_ATTITUDE
		touched = true

	if _variant_contains_corrupted_text(chat_history):
		chat_history.clear()
		touched = true
	if _variant_contains_corrupted_text(pending_summaries):
		pending_summaries.clear()
		touched = true
	if _variant_contains_corrupted_text(pending_memory_records):
		pending_memory_records.clear()
		touched = true
	if _variant_contains_corrupted_text(pending_vector_records):
		pending_vector_records.clear()
		touched = true
	if _variant_contains_corrupted_text(pending_vector_mid_archives):
		pending_vector_mid_archives.clear()
		touched = true
	if _variant_contains_corrupted_text(memory_facts):
		memory_facts.clear()
		touched = true
	if _variant_contains_corrupted_text(debug_last_turn_info):
		debug_last_turn_info.clear()
		touched = true
	if _variant_contains_corrupted_text(debug_last_summary_info):
		debug_last_summary_info.clear()
		touched = true
	if _variant_contains_corrupted_text(debug_event_log):
		debug_event_log.clear()
		touched = true
	if _variant_contains_corrupted_text(mid_memory_entries):
		mid_memory_entries.clear()
		touched = true
	if _variant_contains_corrupted_text(long_term_memory_entries):
		long_term_memory_entries.clear()
		touched = true
	if _variant_contains_corrupted_text(recent_topic_tags):
		recent_topic_tags.clear()
		touched = true
	if _variant_contains_corrupted_text(blackjack_bluff_history):
		blackjack_bluff_history.clear()
		touched = true
	if _variant_contains_corrupted_text(blackjack_player_read_profile):
		blackjack_player_read_profile = {
			"fell_for_bluff_count": 0,
			"caught_lie_count": 0,
			"truth_help_count": 0,
			"shared_hand_info_count": 0,
			"probe_count": 0
		}
		touched = true
	if blackjack_trust_score < 0 or blackjack_trust_score > 100:
		blackjack_trust_score = clampi(blackjack_trust_score, 0, 100)
		touched = true
	if _variant_contains_corrupted_text(blackjack_recent_probe_styles):
		blackjack_recent_probe_styles.clear()
		touched = true
	while blackjack_recent_probe_styles.size() > 12:
		blackjack_recent_probe_styles.pop_front()
		touched = true

	return touched

func _variant_contains_corrupted_text(value: Variant, depth: int = 0) -> bool:
	if depth > 4:
		return false
	var value_type: int = typeof(value)
	if value_type == TYPE_STRING:
		return _looks_like_mojibake_text(String(value))
	if value_type == TYPE_ARRAY:
		var arr: Array = value
		for item in arr:
			if _variant_contains_corrupted_text(item, depth + 1):
				return true
		return false
	if value_type == TYPE_DICTIONARY:
		var dict: Dictionary = value
		for k in dict.keys():
			if _variant_contains_corrupted_text(k, depth + 1):
				return true
			if _variant_contains_corrupted_text(dict.get(k), depth + 1):
				return true
	return false

func _looks_like_mojibake_text(text: String) -> bool:
	var raw: String = text.strip_edges()
	if raw.is_empty():
		return false
	if raw.find(char(0xfffd)) >= 0:
		return true
	var marker_hits: int = 0
	for marker in MOJIBAKE_MARKERS:
		if raw.find(marker) >= 0:
			marker_hits += 1
	if marker_hits >= 2 and raw.length() >= 6:
		return true
	var odd_chunks: Array[String] = ["鍝ュ摜", "鎴戜滑", "浣犲", "锛堝", "銆"]
	for chunk in odd_chunks:
		if raw.find(chunk) >= 0:
			return true
	return false


func _compact_long_term_entries() -> Array:
	var compacted: Array = []
	for item_v in long_term_memory_entries:
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v
		var text: String = String(item.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		compacted.append({
			"id": String(item.get("id", "")).strip_edges(),
			"text": text.substr(0, min(180, text.length())),
			"day": int(item.get("day", living_days)),
			"importance": clampi(int(item.get("importance", 5)), 0, 10),
			"keywords": item.get("keywords", []),
			"time_anchor": String(item.get("time_anchor", "")),
			"created_at_ts": int(item.get("created_at_ts", int(Time.get_unix_time_from_system()))),
			"kind": String(item.get("kind", item.get("source", "dialogue")))
		})
	return compacted
