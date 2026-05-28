extends RefCounted
class_name VictoriaWebContext

const CACHE_TTL_SECONDS := 1800

var http_request: HTTPRequest
var web_cache: Dictionary = {}
var last_web_turn: int = -999

func attach_http_request(request_node: HTTPRequest) -> void:
	http_request = request_node

func direct_calendar_answer(user_input: String) -> String:
	var text: String = user_input.strip_edges()
	if text.is_empty():
		return ""

	var year_patterns: Array[String] = [
		"今年", "现在是哪一年", "现在是几几年", "当前年份", "今年是几几年", "现在年份"
	]
	var date_patterns: Array[String] = [
		"今天几号", "今天是几月几号", "今天日期", "现在日期", "今天星期几", "今天周几", "今天礼拜几"
	]
	var time_patterns: Array[String] = [
		"现在几点", "当前时间", "现在时间", "现在几时"
	]

	var now: Dictionary = Time.get_datetime_dict_from_system()
	var year: int = int(now.get("year", 1970))
	var month: int = int(now.get("month", 1))
	var day: int = int(now.get("day", 1))
	var hour: int = int(now.get("hour", 0))
	var minute: int = int(now.get("minute", 0))
	var weekday_idx: int = int(now.get("weekday", 0))
	var weekday_map: Array[String] = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
	var weekday: String = weekday_map[clampi(weekday_idx, 0, weekday_map.size() - 1)]

	if _contains_any(text, year_patterns):
		return "哥哥，现在是%s年。" % str(year)
	if _contains_any(text, date_patterns):
		return "哥哥，今天是%s年%s月%s日，%s。" % [str(year), str(month), str(day), weekday]
	if _contains_any(text, time_patterns):
		return "现在是%02d:%02d，%s。" % [hour, minute, weekday]
	return ""

func fetch_web_context(user_input: String, chat_history: Array, web_enabled: bool = true) -> String:
	if not web_enabled:
		return ""
	if not should_web_search(user_input, chat_history):
		return ""

	var query: String = build_web_query(user_input)
	if query.length() < 2:
		return ""

	var cache_key: String = "v2|" + query
	var now_ts: int = int(Time.get_unix_time_from_system())
	if web_cache.has(cache_key):
		var entry_v: Variant = web_cache.get(cache_key, {})
		if typeof(entry_v) == TYPE_DICTIONARY:
			var entry: Dictionary = entry_v
			var ts: int = int(entry.get("ts", 0))
			var cached_text: String = String(entry.get("text", ""))
			if (now_ts - ts) < CACHE_TTL_SECONDS and not cached_text.is_empty():
				last_web_turn = int(chat_history.size() / 2)
				return cached_text

	var context: String = ""
	if is_weather_query(user_input):
		context = await fetch_weather_context(user_input)
	else:
		context = await fetch_baidu_context(query)

	if context.is_empty():
		return ""

	web_cache[cache_key] = {"ts": now_ts, "text": context}
	last_web_turn = int(chat_history.size() / 2)
	return context

func should_web_search(user_input: String, chat_history: Array) -> bool:
	var text: String = user_input.strip_edges()
	if text.length() < 4:
		return false
	var turn_id: int = int(chat_history.size() / 2)
	if turn_id - last_web_turn < 2:
		return false

	var explicit_web: Array[String] = ["查一下", "搜一下", "检索", "网上", "互联网", "热搜", "新闻"]
	var external_topics: Array[String] = [
		"天气", "气温", "台风", "地震", "新闻", "热搜", "比赛", "比分", "联赛", "股价", "汇率",
		"电影", "票房", "发布会", "航班", "高铁", "通告", "国际", "世界", "疫情"
	]
	var ask_markers: Array[String] = ["？", "?", "吗", "呢", "多少", "几点", "是什么", "是谁", "怎么样", "最新", "今天", "现在"]
	var in_room_topics: Array[String] = ["早餐", "午饭", "晚饭", "夜宵", "吃什么", "做饭", "睡觉", "洗澡", "哥哥", "维多利亚"]

	var has_explicit: bool = _contains_any(text, explicit_web)
	var has_external_topic: bool = _contains_any(text, external_topics)
	var has_question: bool = _contains_any(text, ask_markers)
	var mostly_room_topic: bool = _contains_any(text, in_room_topics) and not has_external_topic

	if has_explicit:
		return true
	if has_external_topic and has_question and not mostly_room_topic:
		return true
	return false

func build_web_query(user_input: String) -> String:
	var text: String = user_input.strip_edges()
	var cleanup := RegEx.new()
	cleanup.compile("(帮我|麻烦你|请你|可以|能不能|告诉我|你知道吗|你知道|查一下|搜一下|检索一下|网上|互联网)")
	text = cleanup.sub(text, " ", true)
	text = text.replace("“", " ").replace("”", " ").replace("‘", " ").replace("’", " ")
	text = text.replace("\"", " ").replace("'", " ")
	text = text.replace("（", " ").replace("）", " ")
	text = text.replace("【", " ").replace("】", " ")
	text = text.replace("[", " ").replace("]", " ")
	text = text.strip_edges()
	while text.find("  ") >= 0:
		text = text.replace("  ", " ")
	if text.length() > 64:
		text = text.substr(0, 64)
	return text.strip_edges()

func is_weather_query(user_input: String) -> bool:
	var text: String = user_input
	return text.find("天气") >= 0 or text.find("气温") >= 0 or text.find("温度") >= 0 or text.find("下雨") >= 0

func fetch_weather_context(user_input: String) -> String:
	var location: String = extract_weather_location(user_input)
	if location.is_empty():
		location = "上海"
	var encoded: String = location.uri_encode()
	var url: String = "https://wttr.in/%s?format=j1" % encoded
	var response: Dictionary = await request_json(url)
	if not bool(response.get("ok", false)):
		return ""
	var body_v: Variant = response.get("body", {})
	if typeof(body_v) != TYPE_DICTIONARY:
		return ""
	var body: Dictionary = body_v
	var current_v: Variant = body.get("current_condition", [])
	if typeof(current_v) != TYPE_ARRAY:
		return ""
	var current_arr: Array = current_v
	if current_arr.is_empty():
		return ""
	var current_item_v: Variant = current_arr[0]
	if typeof(current_item_v) != TYPE_DICTIONARY:
		return ""
	var current: Dictionary = current_item_v
	var temp_c: String = String(current.get("temp_C", "?"))
	var feels_c: String = String(current.get("FeelsLikeC", "?"))
	var humidity: String = String(current.get("humidity", "?"))
	var desc: String = ""
	var desc_v: Variant = current.get("weatherDesc", [])
	if typeof(desc_v) == TYPE_ARRAY:
		var desc_arr: Array = desc_v
		if not desc_arr.is_empty() and typeof(desc_arr[0]) == TYPE_DICTIONARY:
			desc = String((desc_arr[0] as Dictionary).get("value", ""))

	if desc.is_empty():
		return "- [天气|实时] %s 当前%s°C，体感%s°C，湿度%s%%。" % [location, temp_c, feels_c, humidity]
	return "- [天气|实时] %s 当前%s，%s°C，体感%s°C，湿度%s%%。" % [location, desc, temp_c, feels_c, humidity]

func fetch_baidu_context(query: String) -> String:
	var response: Dictionary = await request_json("https://top.baidu.com/api/board?tab=realtime")
	if not bool(response.get("ok", false)):
		return ""
	var body_v: Variant = response.get("body", {})
	if typeof(body_v) != TYPE_DICTIONARY:
		return ""
	var body: Dictionary = body_v
	var data_v: Variant = body.get("data", {})
	if typeof(data_v) != TYPE_DICTIONARY:
		return ""
	var data: Dictionary = data_v
	var cards_v: Variant = data.get("cards", [])
	if typeof(cards_v) != TYPE_ARRAY:
		return ""
	var cards: Array = cards_v
	if cards.is_empty():
		return ""
	var card0_v: Variant = cards[0]
	if typeof(card0_v) != TYPE_DICTIONARY:
		return ""
	var card0: Dictionary = card0_v
	var items_v: Variant = card0.get("content", [])
	if typeof(items_v) != TYPE_ARRAY:
		return ""
	var items: Array = items_v
	if items.is_empty():
		return ""

	var query_tokens: Array[String] = _extract_query_tokens(query)
	var lines: Array[String] = []
	for i in range(min(50, items.size())):
		var item_v: Variant = items[i]
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v
		var word: String = _strip_html(String(item.get("word", item.get("query", ""))))
		var desc: String = _strip_html(String(item.get("desc", "")))
		var hot: String = String(item.get("hotScore", "")).strip_edges()
		if word.is_empty():
			continue
		var hay: String = word + " " + desc
		var hit_count: int = 0
		for tk in query_tokens:
			if tk.length() >= 2 and hay.find(tk) >= 0:
				hit_count += 1
		if hit_count < 1 and not _is_recent_marker(query):
			continue
		var hot_show: String = hot.substr(0, min(8, hot.length())) if not hot.is_empty() else "未知"
		var core: String = word.substr(0, min(28, word.length()))
		if not desc.is_empty():
			core += "：" + desc.substr(0, min(52, desc.length()))
		lines.append("- [百度热榜|热度%s] %s" % [hot_show, core])
		if lines.size() >= 2:
			break
	if lines.is_empty():
		return ""
	return "\n".join(lines)

func request_json(url: String) -> Dictionary:
	if http_request == null:
		return {"ok": false}
	var req_err: int = http_request.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if req_err != OK:
		return {"ok": false}
	var result: Array = await http_request.request_completed
	if result.size() < 4:
		return {"ok": false}
	var code: int = int(result[1])
	if code < 200 or code >= 300:
		return {"ok": false, "code": code}
	var body: PackedByteArray = result[3]
	var parser: JSON = JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		return {"ok": false, "code": code}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false, "code": code}
	return {"ok": true, "code": code, "body": parser.data}

func extract_weather_location(user_input: String) -> String:
	var text: String = user_input.strip_edges()
	if text.find("天气") < 0 and text.find("气温") < 0 and text.find("温度") < 0:
		return ""
	var cut: String = text
	if cut.find("天气") >= 0:
		cut = cut.substr(0, cut.find("天气"))
	elif cut.find("气温") >= 0:
		cut = cut.substr(0, cut.find("气温"))
	elif cut.find("温度") >= 0:
		cut = cut.substr(0, cut.find("温度"))
	var cleanup := RegEx.new()
	cleanup.compile("(帮我|麻烦你|请你|可以|能不能|告诉我|你知道吗|你知道|查一下|搜一下|检索一下|今天|现在|最近)")
	cut = cleanup.sub(cut, " ", true).strip_edges()
	var token_re := RegEx.new()
	token_re.compile("([A-Za-z]{2,20}|[\\u4e00-\\u9fff]{2,20})")
	var matches: Array = token_re.search_all(cut)
	if matches.is_empty():
		return ""
	var last: RegExMatch = matches[matches.size() - 1]
	return String(last.get_string(1)).strip_edges()

func _extract_query_tokens(query: String) -> Array[String]:
	var token_re := RegEx.new()
	token_re.compile("([A-Za-z0-9]{2,12}|[\\u4e00-\\u9fff]{2,12})")
	var matches: Array = token_re.search_all(query)
	var out: Array[String] = []
	for m_v in matches:
		if typeof(m_v) != TYPE_OBJECT:
			continue
		var m: RegExMatch = m_v
		var token: String = String(m.get_string(1)).strip_edges()
		if token.length() >= 2:
			out.append(token)
	return out

func _strip_html(text: String) -> String:
	var re := RegEx.new()
	re.compile("<[^>]+>")
	return re.sub(text, "", true).strip_edges()

func _is_recent_marker(text: String) -> bool:
	var markers: Array[String] = ["今天", "最新", "最近", "刚刚", "实时", "现在", "这周", "本周", "今日"]
	return _contains_any(text, markers)

func _contains_any(text: String, words: Array[String]) -> bool:
	for w in words:
		if text.find(w) >= 0:
			return true
	return false
