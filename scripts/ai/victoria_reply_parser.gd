extends RefCounted
class_name VictoriaReplyParser

func _normalize_digit_text(text: String) -> String:
	var normalized: String = text
	normalized = normalized.replace("０", "0")
	normalized = normalized.replace("１", "1")
	normalized = normalized.replace("２", "2")
	normalized = normalized.replace("３", "3")
	normalized = normalized.replace("４", "4")
	normalized = normalized.replace("５", "5")
	normalized = normalized.replace("６", "6")
	normalized = normalized.replace("７", "7")
	normalized = normalized.replace("８", "8")
	normalized = normalized.replace("９", "9")
	return normalized.strip_edges()

func extract_finish_signal(reply: String) -> Dictionary:
	var regex: RegEx = RegEx.new()
	regex.compile("(\\[\\s*FINISH\\s*\\]|【\\s*FINISH\\s*】)")
	var should_exit: bool = regex.search(reply) != null
	var cleaned: String = regex.sub(reply, "", true).strip_edges()
	return {"should_exit": should_exit, "reply": cleaned}

func extract_love_change(reply: String) -> Dictionary:
	var marker_pattern: RegEx = RegEx.new()
	marker_pattern.compile("[\\(（]\\s*([+\\-＋－])\\s*([0-9０-９]+)\\s*[\\)）]")
	var matches: Array = marker_pattern.search_all(reply)
	var total_change: int = 0
	var cleaned: String = reply

	if matches.size() > 0:
		for m in matches:
			var sign: String = m.get_string(1)
			var amount: int = int(_normalize_digit_text(m.get_string(2)))
			total_change += -amount if sign == "-" or sign == "－" else amount
		cleaned = marker_pattern.sub(reply, "", true).strip_edges()
	else:
		var fallback_pattern: RegEx = RegEx.new()
		fallback_pattern.compile("好感度(?:变化)?\\s*[:：]?\\s*([+\\-＋－])\\s*([0-9０-９]+)")
		var f: RegExMatch = fallback_pattern.search(reply)
		if f != null:
			var sign2: String = f.get_string(1)
			var amount2: int = int(_normalize_digit_text(f.get_string(2)))
			total_change = -amount2 if sign2 == "-" or sign2 == "－" else amount2
			cleaned = fallback_pattern.sub(reply, "", true).strip_edges()

	return {
		"change": total_change,
		"reply": cleaned
	}

func extract_memory_hint(reply: String) -> Dictionary:
	var marker_pattern: RegEx = RegEx.new()
	marker_pattern.compile("\\[\\s*W\\s*[:：]\\s*([0-9０-９]{1,2})\\s*,\\s*K\\s*[:：]\\s*([^\\]]*)\\]")
	var matches: Array = marker_pattern.search_all(reply)
	var importance: int = 5
	var keywords: Array[String] = []
	var cleaned: String = reply

	if matches.size() > 0:
		var last: RegExMatch = matches[matches.size() - 1]
		importance = clampi(int(_normalize_digit_text(last.get_string(1))), 0, 10)
		keywords = _normalize_keywords(last.get_string(2))
		cleaned = marker_pattern.sub(reply, "", true).strip_edges()

	return {
		"importance": importance,
		"keywords": keywords,
		"reply": cleaned
	}

func extract_mood_marker(reply: String) -> Dictionary:
	var regex: RegEx = RegEx.new()
	regex.compile("^\\s*(?:\\[\\s*M\\s*[:：]\\s*([^\\]\\r\\n]{1,20})\\s*\\]|【\\s*M\\s*[:：]\\s*([^】\\r\\n]{1,20})\\s*】)\\s*")
	var m: RegExMatch = regex.search(reply)
	var mood: String = ""
	var cleaned: String = reply
	if m != null:
		mood = _normalize_mood_label(m.get_string(1) if not m.get_string(1).is_empty() else m.get_string(2))
		cleaned = reply.substr(m.get_end()).strip_edges()
	if mood.is_empty():
		mood = _fallback_mood_from_text(cleaned)
	return {
		"mood": mood,
		"reply": cleaned
	}

func extract_expression_cue(reply: String) -> Dictionary:
	var marker_pattern: RegEx = RegEx.new()
	marker_pattern.compile("(\\[\\s*P\\s*[:：]\\s*([^\\]\\r\\n]{1,20})\\s*\\]|【\\s*P\\s*[:：]\\s*([^】\\r\\n]{1,20})\\s*】)")
	var matches: Array = marker_pattern.search_all(reply)
	if matches.is_empty():
		return {"cue": "", "reply": reply}

	var last_match: RegExMatch = matches[matches.size() - 1]
	var raw: String = last_match.get_string(2) if not last_match.get_string(2).is_empty() else last_match.get_string(3)
	var normalized: String = raw.strip_edges().replace(" ", "")
	var alias: Dictionary = {
		"日常": "daily",
		"daily": "daily",
		"语言害羞": "shy_lang",
		"害羞": "shy_lang",
		"肢体害羞": "shy_touch",
		"触碰害羞": "shy_touch",
		"担忧": "worry",
		"worry": "worry",
		"激动": "excite",
		"兴奋": "excite",
		"excite": "excite",
		"撒娇生气": "tsun",
		"撒娇的生气": "tsun",
		"生气": "tsun",
		"tsun": "tsun"
	}
	var cue: String = String(alias.get(normalized, ""))
	var cleaned: String = marker_pattern.sub(reply, "", true).strip_edges()
	return {"cue": cue, "reply": cleaned}

func sprite_key_from_mood(mood: String, cue: String = "", user_text: String = "", reply_text: String = "") -> String:
	var normalized_cue: String = cue.strip_edges().to_lower()
	match normalized_cue:
		"daily":
			return "everyday"
		"shy_lang":
			return "shy"
		"shy_touch":
			return "shy2"
		"worry":
			return "worry"
		"excite":
			return "cross"
		"tsun":
			return "dislike"
		_:
			pass

	var normalized_mood: String = mood
	if normalized_mood == "害羞":
		var combined: String = user_text + " " + reply_text
		var touch_words: Array = ["抱", "抱抱", "拥抱", "亲", "亲亲", "接吻", "牵手", "摸头", "贴贴", "触碰"]
		for word in touch_words:
			if combined.find(word) >= 0:
				return "shy2"
		return "shy"
	if normalized_mood == "激动":
		return "cross"
	if normalized_mood == "撒娇的生气":
		return "dislike"
	if normalized_mood == "担忧" or normalized_mood == "消极":
		return "worry"
	return "everyday"

func _normalize_mood_label(raw: String) -> String:
	var text: String = raw.strip_edges().replace(" ", "")
	text = text.replace("情绪", "").replace("基调", "").replace("状态", "")
	var mood_alias: Dictionary = {
		"害羞": "害羞",
		"害臊": "害羞",
		"日常": "日常",
		"平静": "日常",
		"平淡": "日常",
		"普通": "日常",
		"激动": "激动",
		"兴奋": "激动",
		"撒娇的生气": "撒娇的生气",
		"撒娇生气": "撒娇的生气",
		"生气": "撒娇的生气",
		"担忧": "担忧",
		"担心": "担忧",
		"消极": "消极",
		"负面": "消极"
	}
	return String(mood_alias.get(text, ""))

func _fallback_mood_from_text(reply: String) -> String:
	var excite_count: int = reply.count("!") + reply.count("！")
	var ellipsis_count: int = reply.count("…") + reply.count("...")
	if excite_count >= 2 and excite_count >= ellipsis_count:
		return "激动"
	if ellipsis_count >= 2:
		return "消极"
	return "日常"

func normalize_reply_by_time(reply: String, period: String) -> String:
	var normalized: String = reply
	if period == "早上":
		normalized = normalized.replace("中午好", "早上好").replace("下午好", "早上好").replace("晚上好", "早上好")
		normalized = normalized.replace("午饭", "早餐").replace("晚饭", "早餐").replace("夜宵", "早餐")
	elif period == "中午":
		normalized = normalized.replace("早安", "中午好").replace("早上好", "中午好").replace("晚上好", "中午好")
		normalized = normalized.replace("晚饭", "午饭").replace("夜宵", "午饭")
	elif period == "下午":
		normalized = normalized.replace("早安", "下午好").replace("早上好", "下午好").replace("中午好", "下午好")
		normalized = normalized.replace("晚饭", "午饭").replace("夜宵", "下午茶")
	elif period == "晚上":
		normalized = normalized.replace("早安", "晚上好").replace("早上好", "晚上好")
		normalized = normalized.replace("中午好", "晚上好").replace("下午好", "晚上好")
		normalized = normalized.replace("午饭", "晚饭")

	if period == "中午" or period == "下午" or period == "晚上":
		var target: String = "午饭" if period == "中午" or period == "下午" else "晚饭"
		normalized = normalized.replace("早餐", target).replace("早饭", target)

	return normalized

func _normalize_keywords(raw: String) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for token in raw.split("|", false):
		for sub_token in token.split("、", false):
			var t: String = sub_token.strip_edges()
			if t.is_empty() or t.length() > 20:
				continue
			if seen.has(t):
				continue
			seen[t] = true
			out.append(t)
	return out
