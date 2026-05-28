extends RefCounted
class_name VictoriaMemoryModel

const MID_MEMORY_WINDOW_DAYS := 10

var last_recalled_days: Array[int] = []
var last_mid_days: Array[int] = []
var last_fact_days: Array[int] = []
var last_long_term_hits: Array[Dictionary] = []
var last_mid_hits: Array[Dictionary] = []
var last_fact_prompt_text: String = ""
var last_mid_prompt_text: String = ""

func query_memory(state: VictoriaState, player_text: String) -> String:
	last_recalled_days.clear()
	last_long_term_hits.clear()

	var entries: Array = state.long_term_memory_entries
	if entries.is_empty():
		return ""

	var current_day: int = state.living_days
	var user_tokens: Dictionary = _tokens(player_text)
	var reranked: Array = []

	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var text: String = String(item.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		var day: int = _to_int(item.get("day"), current_day)
		var importance: int = clampi(_to_int(item.get("importance"), 5), 0, 10)
		var keywords: Array[String] = _normalize_keywords(item.get("keywords"))
		var keyword_hit: float = _keyword_hit_score(user_tokens, keywords, text)
		var semantic: float = _simple_semantic_score(user_tokens, text)
		if semantic < 0.60:
			continue
		var day_gap: int = maxi(0, current_day - day)
		var time_decay: float = minf(0.15, 0.03 * float(day_gap))
		var final_score: float = (0.70 * semantic) + (0.20 * (float(importance) / 10.0)) + (0.10 * keyword_hit) - time_decay
		reranked.append({
			"day": day,
			"text": text,
			"importance": importance,
			"keywords": keywords,
			"semantic": semantic,
			"final_score": final_score
		})

	if reranked.is_empty():
		return "\n【记忆碎片】此刻你没有什么特别的联想。"

	reranked.sort_custom(func(a, b): return float(a.get("final_score", 0.0)) > float(b.get("final_score", 0.0)))
	var top: Array = reranked.slice(0, min(3, reranked.size()))
	for item in top:
		last_recalled_days.append(_to_int(item.get("day"), current_day))
		last_long_term_hits.append(item)

	var lines: Array[String] = []
	for item in top:
		var kw_show: String = "无"
		var kws: Array = item.get("keywords", [])
		if kws.size() > 0:
			kw_show = "、".join(kws.slice(0, min(3, kws.size())))
		lines.append("- (权重%s|关键词%s) %s" % [
			str(item.get("importance", 5)),
			kw_show,
			String(item.get("text", ""))
		])

	return "\n【记忆碎片被触发】你刚才不由自主地想起了这些与哥哥相关的往事：\n%s\n请自然地融入这些回忆，让回应充满真实感。" % "\n".join(lines)

func update_facts_from_user_input(state: VictoriaState, user_input: String) -> void:
	for pref in _extract_preference_items(user_input):
		var subject: String = String(pref.get("subject", ""))
		if subject.is_empty():
			continue
		var fact_key: String = "pref::%s" % subject
		_update_memory_fact(
			state,
			fact_key,
			subject,
			_to_int(pref.get("importance"), 6),
			"preference",
			String(pref.get("sentiment", "like"))
		)

func build_fact_memory_prompt(state: VictoriaState) -> String:
	var facts: Dictionary = state.memory_facts
	if facts.is_empty():
		last_fact_days.clear()
		last_fact_prompt_text = ""
		return ""

	var pref_items: Array = []
	for key in facts.keys():
		var rec: Dictionary = facts[key] as Dictionary
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var fact_type: String = String(rec.get("fact_type", ""))
		if fact_type != "preference" and not String(key).begins_with("pref::"):
			continue
		var value: String = String(rec.get("value", "")).strip_edges()
		if value.is_empty():
			continue
		pref_items.append({
			"value": value,
			"sentiment": String(rec.get("sentiment", "like")),
			"day": _to_int(rec.get("day"), state.living_days),
			"importance": clampi(_to_int(rec.get("importance"), 5), 0, 10),
			"created_at_ts": _to_int(rec.get("created_at_ts"), 0)
		})

	if pref_items.is_empty():
		last_fact_days.clear()
		last_fact_prompt_text = ""
		return ""

	pref_items.sort_custom(func(a, b):
		if int(a.get("day", 0)) == int(b.get("day", 0)):
			return int(a.get("importance", 0)) > int(b.get("importance", 0))
		return int(a.get("day", 0)) > int(b.get("day", 0))
	)

	var lines: Array[String] = []
	var seen: Dictionary = {}
	last_fact_days.clear()
	for item in pref_items:
		var dedupe_key: String = "%s::%s" % [String(item.get("sentiment", "like")), String(item.get("value", ""))]
		if seen.has(dedupe_key):
			continue
		seen[dedupe_key] = true
		var sentiment: String = String(item.get("sentiment", "like"))
		if sentiment == "like":
			lines.append("哥哥喜欢%s" % String(item.get("value", "")))
		elif sentiment == "neutral":
			lines.append("哥哥对%s无感" % String(item.get("value", "")))
		else:
			lines.append("哥哥不喜欢%s" % String(item.get("value", "")))
		last_fact_days.append(_to_int(item.get("day"), state.living_days))
		if lines.size() >= 6:
			break

	last_fact_prompt_text = "；".join(lines)
	return last_fact_prompt_text

func update_mid_memory(state: VictoriaState, dialogues: Array, records: Array) -> Array:
	if dialogues.is_empty() and records.is_empty():
		return []

	var entry: Dictionary = _build_mid_memory_entry(state, dialogues, records)
	if entry.is_empty():
		return []

	var filtered: Array = []
	for item in state.mid_memory_entries:
		if _to_int(item.get("day"), 0) != _to_int(entry.get("day"), state.living_days):
			filtered.append(item)
	filtered.append(entry)
	filtered.sort_custom(func(a, b): return int(a.get("day", 0)) < int(b.get("day", 0)))

	var archived: Array = []
	var min_day: int = maxi(1, state.living_days - MID_MEMORY_WINDOW_DAYS + 1)
	var kept: Array = []
	for item in filtered:
		if _to_int(item.get("day"), 0) < min_day:
			archived.append(item)
		else:
			kept.append(item)

	if kept.size() > MID_MEMORY_WINDOW_DAYS:
		var overflow: int = kept.size() - MID_MEMORY_WINDOW_DAYS
		for i in range(overflow):
			archived.append(kept[i])
		kept = kept.slice(overflow, kept.size())

	state.mid_memory_entries = kept
	archive_mid_memory_entries(state, archived)
	return archived

func build_mid_memory_prompt(state: VictoriaState, player_text: String, max_items: int = 3) -> String:
	last_mid_days.clear()
	last_mid_hits.clear()
	last_mid_prompt_text = ""
	if state.mid_memory_entries.is_empty():
		return ""

	var current_day: int = state.living_days
	var user_tokens: Dictionary = _tokens(player_text)
	var candidates: Array = []
	for entry in state.mid_memory_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var day: int = _to_int(entry.get("day"), 0)
		if day <= 0 or day >= current_day:
			continue
		var summary: String = String(entry.get("summary", ""))
		var keywords: Array[String] = _normalize_keywords(entry.get("keywords"))
		var importance: int = clampi(_to_int(entry.get("importance"), 5), 0, 10)
		var day_gap: int = current_day - day
		if day_gap > MID_MEMORY_WINDOW_DAYS:
			continue

		var keyword_hit: float = _keyword_hit_score(user_tokens, keywords, summary)
		var recency_score: float = maxf(0.0, 1.0 - 0.15 * float(maxi(0, day_gap - 1)))
		var importance_score: float = float(importance) / 10.0
		var final_score: float = (0.55 * keyword_hit) + (0.30 * importance_score) + (0.15 * recency_score)
		candidates.append({
			"day": day,
			"summary": summary,
			"keywords": keywords,
			"importance": importance,
			"final_score": final_score,
			"keyword_hit": keyword_hit
		})

	if candidates.is_empty():
		return ""

	candidates.sort_custom(func(a, b): return float(a.get("final_score", 0.0)) > float(b.get("final_score", 0.0)))
	var selected: Array = candidates.slice(0, min(max_items, candidates.size()))
	selected.sort_custom(func(a, b): return int(a.get("day", 0)) > int(b.get("day", 0)))

	var lines: Array[String] = []
	for item in selected:
		last_mid_days.append(_to_int(item.get("day"), current_day))
		last_mid_hits.append(item)
		var kw_show: String = "无"
		var kws: Array = item.get("keywords", [])
		if kws.size() > 0:
			kw_show = "、".join(kws.slice(0, min(4, kws.size())))
		lines.append("- 第%s天：%s（关键词：%s）" % [
			str(item.get("day", 0)),
			String(item.get("summary", "")),
			kw_show
		])

	last_mid_prompt_text = "\n".join(lines)
	return last_mid_prompt_text

func archive_mid_memory_entries(state: VictoriaState, entries: Array) -> int:
	var count: int = 0
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var summary: String = String(item.get("summary", "")).strip_edges()
		if summary.length() < 4:
			continue
		state.long_term_memory_entries.append({
			"id": "mid_day_%s_%s" % [str(_to_int(item.get("day"), state.living_days)), str(Time.get_unix_time_from_system())],
			"text": summary.substr(0, min(180, summary.length())),
			"day": _to_int(item.get("day"), state.living_days),
			"importance": clampi(_to_int(item.get("importance"), 5), 0, 10),
			"keywords": _normalize_keywords(item.get("keywords")),
			"time_anchor": "day_%s_mid_summary" % str(_to_int(item.get("day"), state.living_days)),
			"created_at_ts": _to_int(item.get("created_at_ts"), int(Time.get_unix_time_from_system())),
			"kind": "mid_memory_archive"
		})
		count += 1
	return count

func upsert_memory_records(state: VictoriaState, records: Array) -> int:
	var count: int = 0
	var seen: Dictionary = {}
	for rec in records:
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var text: String = String(rec.get("text", "")).strip_edges()
		if text.length() < 3:
			continue
		if seen.has(text):
			continue
		seen[text] = true
		state.long_term_memory_entries.append({
			"id": "mem_%s_%s" % [str(_to_int(rec.get("day"), state.living_days)), str(Time.get_unix_time_from_system())],
			"text": text.substr(0, min(180, text.length())),
			"day": _to_int(rec.get("day"), state.living_days),
			"love_score": _to_int(rec.get("love_score"), state.love_score),
			"importance": clampi(_to_int(rec.get("importance"), 5), 0, 10),
			"keywords": _normalize_keywords(rec.get("keywords")),
			"time_anchor": String(rec.get("time_anchor", "")),
			"created_at_ts": _to_int(rec.get("created_at_ts"), int(Time.get_unix_time_from_system())),
			"kind": "dialogue"
		})
		count += 1
	return count

func _build_mid_memory_entry(state: VictoriaState, dialogues: Array, records: Array) -> Dictionary:
	if dialogues.is_empty() and records.is_empty():
		return {}

	var keywords: Array[String] = _collect_mid_memory_keywords(dialogues, records)
	var summary: String = _fallback_mid_memory_summary(dialogues, records, keywords)
	if summary.is_empty():
		return {}

	var importance: int = 5
	for rec in records:
		if typeof(rec) == TYPE_DICTIONARY:
			importance = max(importance, _to_int(rec.get("importance"), 5))
	importance = clampi(importance, 4, 10)

	return {
		"day": state.living_days,
		"summary": summary.substr(0, min(140, summary.length())),
		"keywords": keywords,
		"importance": importance,
		"created_at_ts": int(Time.get_unix_time_from_system())
	}

func _collect_mid_memory_keywords(dialogues: Array, records: Array) -> Array[String]:
	var keywords: Array[String] = []
	for rec in records:
		if typeof(rec) == TYPE_DICTIONARY:
			keywords.append_array(_normalize_keywords(rec.get("keywords")))
	if keywords.size() >= 4:
		return _dedupe_keywords(keywords).slice(0, min(8, keywords.size()))

	var merged: String = ""
	for line in dialogues:
		merged += String(line) + "\n"
	for rec in records:
		if typeof(rec) == TYPE_DICTIONARY:
			merged += String(rec.get("text", "")) + "\n"

	var token_list: Dictionary = _tokens(merged)
	for token in token_list:
		if token.length() >= 2 and token.length() <= 10:
			keywords.append(token)
	return _dedupe_keywords(keywords).slice(0, min(8, keywords.size()))

func _fallback_mid_memory_summary(dialogues: Array, records: Array, keywords: Array[String]) -> String:
	if records.size() > 0:
		var important: Array = records.duplicate()
		important.sort_custom(func(a, b): return _to_int(a.get("importance"), 5) > _to_int(b.get("importance"), 5))
		var fragments: Array[String] = []
		for rec in important:
			if typeof(rec) != TYPE_DICTIONARY:
				continue
			var text: String = String(rec.get("text", "")).strip_edges()
			if text.is_empty():
				continue
			if text.length() > 32:
				text = text.substr(0, 32).rstrip("，。！？,.!? ") + "..."
			fragments.append(text)
			if fragments.size() >= 2:
				break
		if fragments.size() > 0:
			return "最近这一天，哥哥和你主要聊到%s。" % "；".join(fragments)

	if keywords.size() > 0:
		return "最近这一天，你们的相处主要围绕%s展开。" % "、".join(keywords.slice(0, min(3, keywords.size())))
	if dialogues.size() > 0:
		return "最近这一天，你和哥哥有过几次交流，整体相处仍在慢慢推进。"
	return ""

func _extract_preference_items(text: String) -> Array:
	var items: Array = []
	if text.strip_edges().is_empty():
		return items
	var seen: Dictionary = {}
	var re_book_like: RegEx = RegEx.new()
	re_book_like.compile("我(?:最近|这阵子|这段时间)?(?:在)?(?:看|追|读)?《([^》\\n]{1,20})》")
	for m in re_book_like.search_all(text):
		_push_preference_item(items, seen, "like", m.get_string(1), 8)

	var re_book_dislike: RegEx = RegEx.new()
	re_book_dislike.compile("我(?:最近|这阵子|这段时间)?(?:不太|不怎么|不想)?(?:看|追|读)?《([^》\\n]{1,20})》")
	for m in re_book_dislike.search_all(text):
		_push_preference_item(items, seen, "dislike", m.get_string(1), 8)

	var strong_patterns: Array = [
		{"regex": "我对\\s*([^\\s，。！？,.!?]{1,20})\\s*过敏", "sentiment": "dislike", "importance": 10},
		{"regex": "我对\\s*([^\\s，。！？,.!?]{1,24})\\s*(?:有点)?无感", "sentiment": "neutral", "importance": 8},
		{"regex": "我(?:最近|这阵子|这段时间)?\\s*(?:有点|有些|开始)?迷上了\\s*([^\\s，。！？,.!?]{1,24})", "sentiment": "like", "importance": 9},
		{"regex": "我(?:最近|这阵子|这段时间)?\\s*(?:对)?\\s*([^\\s，。！？,.!?]{1,24})\\s*上头了", "sentiment": "like", "importance": 8}
	]
	for def in strong_patterns:
		var re: RegEx = RegEx.new()
		re.compile(String(def.get("regex", "")))
		for m in re.search_all(text):
			_push_preference_item(
				items,
				seen,
				String(def.get("sentiment", "like")),
				m.get_string(1),
				_to_int(def.get("importance"), 6)
			)

	var fix_patterns: Array = [
		{"regex": "(?:之前|以前|原来)[^，。！？]{0,12}(?:不吃|不喜欢|讨厌)\\s*([^\\s，。！？,.!?]{1,24})[^，。！？]{0,18}(?:现在|后来)[^，。！？]{0,8}(?:能|可以)?吃了?", "sentiment": "like", "importance": 10},
		{"regex": "(?:但|不过|可是)?\\s*现在(?:我)?(?:已经|也)?(?:能|可以)?\\s*吃\\s*([^\\s，。！？,.!?]{1,24})", "sentiment": "like", "importance": 10},
		{"regex": "(?:但|不过|可是)?\\s*现在(?:我)?(?:已经|也)?(?:不吃|不喜欢|讨厌)\\s*([^\\s，。！？,.!?]{1,24})", "sentiment": "dislike", "importance": 10},
		{"regex": "(?:但|不过|可是)?\\s*现在(?:我)?(?:已经|也)?(?:对)?\\s*([^\\s，。！？,.!?]{1,24})\\s*无感", "sentiment": "neutral", "importance": 10}
	]
	for def in fix_patterns:
		var re_fix: RegEx = RegEx.new()
		re_fix.compile(String(def.get("regex", "")))
		for m in re_fix.search_all(text):
			_push_preference_item(items, seen, String(def.get("sentiment", "like")), m.get_string(1), _to_int(def.get("importance"), 10))

	var clauses: Array = []
	var merged: String = text.replace("，", "|").replace("。", "|").replace("！", "|").replace("？", "|")
	merged = merged.replace(",", "|").replace(".", "|").replace("!", "|").replace("?", "|").replace("；", "|").replace(";", "|").replace("、", "|")
	clauses = merged.split("|", false)

	var positive_patterns: Array = [
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*最喜欢\\s*([^\\s，。！？,.!?]{1,24})", "score": 9},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*最爱\\s*([^\\s，。！？,.!?]{1,24})", "score": 9},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*超喜欢\\s*([^\\s，。！？,.!?]{1,24})", "score": 8},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*迷上了\\s*([^\\s，。！？,.!?]{1,24})", "score": 9},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*上头了\\s*([^\\s，。！？,.!?]{1,24})", "score": 8},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*偏好\\s*([^\\s，。！？,.!?]{1,24})", "score": 8},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*喜欢\\s*([^\\s，。！？,.!?]{1,24})", "score": 7},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*爱吃\\s*([^\\s，。！？,.!?]{1,24})", "score": 7},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*爱听\\s*([^\\s，。！？,.!?]{1,24})", "score": 7},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*爱玩\\s*([^\\s，。！？,.!?]{1,24})", "score": 7},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*想吃\\s*([^\\s，。！？,.!?]{1,24})", "score": 6}
	]
	var negative_patterns: Array = [
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*不喜欢\\s*([^\\s，。！？,.!?]{1,24})", "score": 8},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*讨厌\\s*([^\\s，。！？,.!?]{1,24})", "score": 9},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*不爱\\s*([^\\s，。！？,.!?]{1,24})", "score": 8},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*不吃\\s*([^\\s，。！？,.!?]{1,24})", "score": 8}
	]
	var neutral_patterns: Array = [
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*对\\s*([^\\s，。！？,.!?]{1,24})\\s*无感", "score": 8},
		{"regex": "我(?:真的|比较|特别|一直|最近)?\\s*无感\\s*([^\\s，。！？,.!?]{1,24})", "score": 7}
	]
	for clause in clauses:
		var part: String = String(clause).strip_edges()
		if part.is_empty():
			continue
		for def in negative_patterns:
			var re_neg: RegEx = RegEx.new()
			re_neg.compile(String(def.get("regex", "")))
			var neg_m: RegExMatch = re_neg.search(part)
			if neg_m != null:
				_push_preference_item(items, seen, "dislike", neg_m.get_string(1), _to_int(def.get("score"), 8))
		for def in neutral_patterns:
			var re_neu: RegEx = RegEx.new()
			re_neu.compile(String(def.get("regex", "")))
			var neu_m: RegExMatch = re_neu.search(part)
			if neu_m != null:
				_push_preference_item(items, seen, "neutral", neu_m.get_string(1), _to_int(def.get("score"), 7))
		for def in positive_patterns:
			var re_pos: RegEx = RegEx.new()
			re_pos.compile(String(def.get("regex", "")))
			var pos_m: RegExMatch = re_pos.search(part)
			if pos_m != null:
				_push_preference_item(items, seen, "like", pos_m.get_string(1), _to_int(def.get("score"), 7))
	return items

func _push_preference_item(items: Array, seen: Dictionary, sentiment: String, raw_subject: String, importance: int) -> void:
	var subject: String = _normalize_preference_subject(raw_subject)
	if subject.is_empty():
		return
	var normalized_sentiment: String = sentiment if sentiment in ["like", "dislike", "neutral"] else "like"
	var key: String = "%s::%s" % [normalized_sentiment, subject]
	if seen.has(key):
		return
	seen[key] = true
	items.append({
		"sentiment": normalized_sentiment,
		"subject": subject,
		"importance": clampi(_to_int(importance, 6), 0, 10)
	})

func _normalize_preference_subject(raw: String) -> String:
	var text: String = _trim_punctuation(raw.strip_edges())
	text = text.replace("《", "").replace("》", "")
	var re_prefix: RegEx = RegEx.new()
	re_prefix.compile("^(?:吃|喝|看|玩|用|听|穿|做|读|追|买)+")
	text = re_prefix.sub(text, "", false)
	var re_suffix: RegEx = RegEx.new()
	re_suffix.compile("(?:这本书|这本小说|这本|这个|这种|这一款|这款)$")
	text = re_suffix.sub(text, "", false)
	text = text.strip_edges()
	var tail_chars: String = "的了啊呀呢嘛吧"
	while not text.is_empty() and tail_chars.find(text.substr(text.length() - 1, 1)) >= 0:
		text = text.substr(0, text.length() - 1).strip_edges()
	if text.length() < 2:
		return ""
	if text in ["你", "我", "哥哥", "妹妹", "这个", "那个", "东西"]:
		return ""
	return text.substr(0, min(20, text.length()))

func _trim_punctuation(text: String) -> String:
	var out: String = text
	var punct: String = "，。！？,.!?~～：:；; "
	while not out.is_empty() and punct.find(out.substr(0, 1)) >= 0:
		out = out.substr(1)
	while not out.is_empty() and punct.find(out.substr(out.length() - 1, 1)) >= 0:
		out = out.substr(0, out.length() - 1)
	return out

func _update_memory_fact(state: VictoriaState, key: String, value: String, importance: int, fact_type: String = "generic", sentiment: String = "like") -> void:
	if key.is_empty() or value.is_empty():
		return
	var facts: Dictionary = state.memory_facts.duplicate(true)
	var current: Dictionary = facts.get(key, {})
	var current_day: int = state.living_days
	var old_day: int = _to_int(current.get("day"), 0)
	var old_importance: int = _to_int(current.get("importance"), 5)
	var new_importance: int = clampi(importance, 0, 10)
	var should_replace: bool = current.is_empty() or current_day > old_day or (current_day == old_day and new_importance >= old_importance)
	if should_replace:
		facts[key] = {
			"value": value,
			"day": current_day,
			"importance": new_importance,
			"time_anchor": _time_anchor(state),
			"created_at_ts": int(Time.get_unix_time_from_system()),
			"fact_type": fact_type,
			"sentiment": sentiment if sentiment in ["like", "dislike", "neutral"] else "like"
		}
		state.memory_facts = facts

func _time_anchor(state: VictoriaState) -> String:
	return "第%s天 %s %s" % [str(state.living_days), state.display_time, state.time_period_name]

func _normalize_keywords(raw: Variant) -> Array[String]:
	var tokens: Array = []
	if typeof(raw) == TYPE_ARRAY:
		tokens = raw
	elif typeof(raw) == TYPE_STRING:
		var merged: String = String(raw)
		merged = merged.replace("，", "|").replace(",", "|").replace("、", "|").replace("/", "|").replace("\\", "|")
		merged = merged.replace("\n", "|").replace("\t", "|").replace(" ", "|")
		tokens = merged.split("|", false)
	var out: Array[String] = []
	var seen: Dictionary = {}
	for token in tokens:
		var t: String = String(token).strip_edges()
		if t.is_empty() or t.length() > 20:
			continue
		if seen.has(t):
			continue
		seen[t] = true
		out.append(t)
	if out.size() > 8:
		var limited: Array[String] = []
		for i in range(0, 8):
			limited.append(out[i])
		return limited
	return out

func _dedupe_keywords(tokens: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for token in tokens:
		if seen.has(token):
			continue
		seen[token] = true
		out.append(token)
	return out

func _tokens(text: String) -> Dictionary:
	var token_dict: Dictionary = {}
	var buffer: String = ""
	for i in range(text.length()):
		var code: int = text.unicode_at(i)
		var is_ascii_digit: bool = code >= 48 and code <= 57
		var is_ascii_upper: bool = code >= 65 and code <= 90
		var is_ascii_lower: bool = code >= 97 and code <= 122
		var is_cjk: bool = code >= 0x4e00 and code <= 0x9fff
		if is_ascii_digit or is_ascii_upper or is_ascii_lower or is_cjk:
			buffer += String.chr(code)
			continue
		_emit_token_buffer(buffer, token_dict)
		buffer = ""
	_emit_token_buffer(buffer, token_dict)
	return token_dict


func _emit_token_buffer(buffer: String, out: Dictionary) -> void:
	var working: String = buffer
	while working.length() >= 8:
		out[working.substr(0, 8)] = true
		working = working.substr(8)
	if working.length() >= 2:
		out[working] = true

func _keyword_hit_score(user_tokens: Dictionary, keywords: Array[String], memory_text: String) -> float:
	if user_tokens.is_empty():
		return 0.0
	for kw in keywords:
		if user_tokens.has(kw):
			return 1.0
		if not kw.is_empty() and memory_text.find(kw) >= 0:
			for t in user_tokens.keys():
				if kw.find(String(t)) >= 0:
					return 1.0
	return 0.0

func _simple_semantic_score(user_tokens: Dictionary, text: String) -> float:
	if user_tokens.is_empty():
		return 0.5
	var hit: int = 0
	for token in user_tokens.keys():
		if text.find(String(token)) >= 0:
			hit += 1
	if hit == 0:
		return 0.4
	return min(1.0, 0.55 + 0.12 * float(hit))

func normalize_relative_time_terms(state: VictoriaState, reply: String) -> String:
	var text: String = String(reply)
	if text.is_empty():
		return text
	var current_day: int = state.living_days
	var has_past_vector_memory: bool = false
	for d in last_recalled_days:
		if d < current_day:
			has_past_vector_memory = true
			break
	var has_past_fact_memory: bool = false
	for d in last_fact_days:
		if d < current_day:
			has_past_fact_memory = true
			break
	var preference_cues: Array[String] = ["喜欢", "不喜欢", "偏好", "爱吃", "讨厌", "过敏", "口味", "爱看", "爱听", "迷上", "上头", "无感", "你说过", "你提过", "你告诉过"]
	var references_preference: bool = false
	for cue in preference_cues:
		if text.find(cue) >= 0:
			references_preference = true
			break
	var has_past_memory: bool = has_past_vector_memory or (has_past_fact_memory and references_preference)
	if not has_past_memory:
		return text
	var normalized: String = text
	var replacements: Array = [
		["你刚刚说", "你之前说"],
		["你刚才说", "你之前说"],
		["你刚刚提到", "你之前提到"],
		["你刚才提到", "你之前提到"],
		["你刚刚告诉我", "你之前告诉我"],
		["你刚才告诉我", "你之前告诉我"],
		["刚刚你说", "之前你说"],
		["刚才你说", "之前你说"],
		["刚刚提过", "之前提过"],
		["刚才提过", "之前提过"]
	]
	for item in replacements:
		var src: String = String(item[0])
		var dst: String = String(item[1])
		normalized = normalized.replace(src, dst)
	return normalized

func _to_int(value: Variant, default_value: int = 0) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING and String(value).is_valid_int():
		return int(value)
	return int(default_value)
