extends RefCounted
class_name VictoriaMemoryService

const VECTOR_QUERY_TOP_K := 12
const VECTOR_SEMANTIC_MIN := 0.60
const UPSERT_MAX_BATCH := 12
const VECTOR_MIN_IMPORTANCE := 4
const VECTOR_MAX_TEXT_LENGTH := 140
const VECTOR_MAX_SUMMARY_SENTENCES := 2
const MIN_MEANINGFUL_CHARS := 8
const LOCAL_VECTOR_DB_SCRIPT := preload("res://scripts/game/local_vector_db.gd")
const ACK_SHORT_PHRASES: Array[String] = [
	"嗯",
	"嗯嗯",
	"好",
	"好的",
	"知道了",
	"收到",
	"我知道了",
	"我记住了",
	"慢慢来",
	"我们慢慢来",
	"好吗",
	"我在听",
	"在呢"
]
const SYSTEM_HINT_PHRASES: Array[String] = [
	"系统提示",
	"请选择",
	"点击继续",
	"触发主动搭话",
	"正在思考",
	"正在整理",
	"summary",
	"debug"
]
const MOJIBAKE_MARKERS: Array[String] = [
	"锛",
	"銆",
	"鈥",
	"闂",
	"娴",
	"閿",
	"鏃",
	"鍦",
	"鍙"
]

var http_request: HTTPRequest
var vector_db: Variant = LOCAL_VECTOR_DB_SCRIPT.new()


func attach_http_request(request_node: HTTPRequest) -> void:
	# Kept for compatibility with the existing startup wiring.
	http_request = request_node


func query_long_term_memory(state: VictoriaState, memory_model: VictoriaMemoryModel, player_text: String) -> String:
	memory_model.last_recalled_days.clear()
	memory_model.last_long_term_hits.clear()
	var clean_text: String = String(player_text).strip_edges()
	if clean_text.is_empty():
		_apply_backend_status(state)
		return ""

	var rows: Array[Dictionary] = _vector_search(clean_text, VECTOR_QUERY_TOP_K, state.playthrough_id)
	_apply_backend_status(state)
	if rows.is_empty():
		return ""

	var current_day: int = state.living_days
	var user_tokens: Dictionary = memory_model._tokens(clean_text)
	var reranked: Array[Dictionary] = []
	for row in rows:
		var text: String = String(row.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		if _looks_like_corrupted_text(text, state):
			continue
		if _is_low_value_text(text):
			continue
		var meta_v: Variant = row.get("metadata", {})
		var meta: Dictionary = meta_v if typeof(meta_v) == TYPE_DICTIONARY else {}

		var semantic: float = float(row.get("semantic", 0.0))
		if semantic <= 0.0:
			semantic = memory_model._simple_semantic_score(user_tokens, text)
		if semantic < VECTOR_SEMANTIC_MIN:
			continue

		var day: int = memory_model._to_int(meta.get("day"), current_day)
		var importance: int = clampi(memory_model._to_int(meta.get("importance"), 5), 0, 10)
		var keywords: Array[String] = memory_model._normalize_keywords(meta.get("keywords"))
		var keyword_hit: float = memory_model._keyword_hit_score(user_tokens, keywords, text)
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
	reranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: float = float(a.get("final_score", 0.0))
		var score_b: float = float(b.get("final_score", 0.0))
		if is_equal_approx(score_a, score_b):
			return float(a.get("semantic", 0.0)) > float(b.get("semantic", 0.0))
		return score_a > score_b
	)

	var top: Array = reranked.slice(0, min(3, reranked.size()))
	for item_v in top:
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v
		memory_model.last_recalled_days.append(memory_model._to_int(item.get("day"), current_day))
		memory_model.last_long_term_hits.append(item)

	var lines: Array[String] = []
	for item_v2 in top:
		if typeof(item_v2) != TYPE_DICTIONARY:
			continue
		var item2: Dictionary = item_v2
		var kw_show: String = "无"
		var kws_v: Variant = item2.get("keywords", [])
		if typeof(kws_v) == TYPE_ARRAY:
			var kws: Array = kws_v
			if kws.size() > 0:
				kw_show = "、".join(kws.slice(0, min(3, kws.size())))
		lines.append("- (权重%s|关键词%s) %s" % [
			str(item2.get("importance", 5)),
			kw_show,
			String(item2.get("text", ""))
		])
	if lines.is_empty():
		return ""
	return "\n【记忆碎片被触发】你刚才不由自主地想起了这些与哥哥相关的往事：\n%s\n请自然地融入这些回忆，让回应充满真实感。" % "\n".join(lines)


func upsert_dialogue_records(state: VictoriaState, memory_model: VictoriaMemoryModel, records: Array) -> int:
	if records.is_empty():
		_apply_backend_status(state)
		return 0
	var selected: Array = records
	if selected.size() > UPSERT_MAX_BATCH:
		selected = selected.slice(selected.size() - UPSERT_MAX_BATCH, selected.size())

	var upsert_count: int = 0
	var accepted_norms: Array[String] = []
	for rec_v in selected:
		if typeof(rec_v) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = rec_v
		var text: String = String(rec.get("text", "")).strip_edges()
		var importance: int = clampi(memory_model._to_int(rec.get("importance"), 5), 0, 10)
		var keywords: Array[String] = memory_model._normalize_keywords(rec.get("keywords"))
		var prepared: String = _prepare_text_for_vector(text, keywords, importance, state)
		if prepared.is_empty():
			continue
		var dedupe_key: String = _normalize_for_dedupe(prepared)
		if _is_duplicate_candidate(dedupe_key, accepted_norms):
			continue
		accepted_norms.append(dedupe_key)
		var day: int = memory_model._to_int(rec.get("day"), state.living_days)
		var metadata: Dictionary = {
			"id": "mem_%s_%s" % [str(day), prepared.sha256_text().substr(0, 16)],
			"playthrough_id": state.playthrough_id,
			"text": prepared.substr(0, min(VECTOR_MAX_TEXT_LENGTH, prepared.length())),
			"day": day,
			"love_score": memory_model._to_int(rec.get("love_score"), state.love_score),
			"importance": importance,
			"keywords": keywords,
			"time_anchor": String(rec.get("time_anchor", "")),
			"created_at_ts": memory_model._to_int(rec.get("created_at_ts"), int(Time.get_unix_time_from_system())),
			"kind": "dialogue"
		}
		if _vector_store_memory(prepared, metadata):
			upsert_count += 1
	_apply_backend_status(state)
	return upsert_count


func upsert_mid_archives(state: VictoriaState, memory_model: VictoriaMemoryModel, entries: Array) -> int:
	if entries.is_empty():
		_apply_backend_status(state)
		return 0
	var upsert_count: int = 0
	var accepted_norms: Array[String] = []
	for item_v in entries:
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v
		var summary: String = String(item.get("summary", "")).strip_edges()
		var importance: int = clampi(memory_model._to_int(item.get("importance"), 5), 0, 10)
		var keywords: Array[String] = memory_model._normalize_keywords(item.get("keywords"))
		var prepared: String = _prepare_text_for_vector(summary, keywords, importance, state)
		if prepared.is_empty():
			continue
		var dedupe_key: String = _normalize_for_dedupe(prepared)
		if _is_duplicate_candidate(dedupe_key, accepted_norms):
			continue
		accepted_norms.append(dedupe_key)
		var day: int = memory_model._to_int(item.get("day"), state.living_days)
		var metadata: Dictionary = {
			"id": "mid_%s_%s" % [str(day), prepared.sha256_text().substr(0, 16)],
			"playthrough_id": state.playthrough_id,
			"text": prepared.substr(0, min(VECTOR_MAX_TEXT_LENGTH, prepared.length())),
			"day": day,
			"importance": importance,
			"keywords": keywords,
			"time_anchor": "day_%s_mid_summary" % str(day),
			"created_at_ts": memory_model._to_int(item.get("created_at_ts"), int(Time.get_unix_time_from_system())),
			"kind": "mid_memory_archive"
		}
		if _vector_store_memory(prepared, metadata):
			upsert_count += 1
	_apply_backend_status(state)
	return upsert_count


func _apply_backend_status(state: VictoriaState) -> void:
	if state == null:
		return
	state.api_status = _vector_backend_status()
	state.api_color = _vector_backend_color()


func _vector_search(query: String, top_k: int, playthrough_id: String) -> Array[Dictionary]:
	if typeof(vector_db) == TYPE_NIL:
		return []
	var result_v: Variant = vector_db.call("search_similar", query, top_k, playthrough_id)
	if typeof(result_v) != TYPE_ARRAY:
		return []
	var out: Array[Dictionary] = []
	var arr: Array = result_v
	for item_v in arr:
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		out.append(item_v)
	return out


func _vector_store_memory(text: String, metadata: Dictionary) -> bool:
	if typeof(vector_db) == TYPE_NIL:
		return false
	var ok_v: Variant = vector_db.call("store_memory", text, metadata)
	return bool(ok_v)


func _vector_backend_status() -> String:
	if typeof(vector_db) == TYPE_NIL:
		return "本地关键词回退"
	var status_v: Variant = vector_db.call("backend_status")
	var status: String = String(status_v).strip_edges()
	return status if not status.is_empty() else "本地关键词回退"


func _vector_backend_color() -> String:
	if typeof(vector_db) == TYPE_NIL:
		return "#f3b35f"
	var color_v: Variant = vector_db.call("backend_color")
	var color: String = String(color_v).strip_edges()
	return color if not color.is_empty() else "#f3b35f"


func _prepare_text_for_vector(raw_text: String, keywords: Array[String], importance: int, state: VictoriaState) -> String:
	if importance < VECTOR_MIN_IMPORTANCE:
		return ""
	var text: String = _normalize_memory_text(raw_text)
	if text.length() < 3:
		return ""
	if _looks_like_corrupted_text(text, state):
		return ""
	if _is_system_style_text(text):
		return ""
	if _is_low_value_text(text):
		return ""
	var summarized: String = _compress_for_vector(text, keywords, VECTOR_MAX_TEXT_LENGTH)
	if summarized.is_empty():
		return ""
	if _looks_like_corrupted_text(summarized, state):
		return ""
	if _is_system_style_text(summarized):
		return ""
	if _is_low_value_text(summarized):
		return ""
	return summarized


func _normalize_memory_text(text: String) -> String:
	var out: String = String(text).replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	while out.find("\n\n\n") >= 0:
		out = out.replace("\n\n\n", "\n\n")
	while out.find("  ") >= 0:
		out = out.replace("  ", " ")
	return out


func _is_system_style_text(text: String) -> bool:
	var clean: String = String(text).strip_edges()
	if clean.is_empty():
		return true
	var lower: String = clean.to_lower()
	if lower.begins_with("[system") or lower.begins_with("system:") or lower.begins_with("debug:"):
		return true
	for marker in SYSTEM_HINT_PHRASES:
		if clean.find(marker) >= 0:
			return true
	return false


func _is_low_value_text(text: String) -> bool:
	var core: String = _normalize_for_dedupe(text)
	if core.is_empty():
		return true
	if core.length() < MIN_MEANINGFUL_CHARS:
		return true
	for phrase in ACK_SHORT_PHRASES:
		var key: String = _normalize_for_dedupe(phrase)
		if key.is_empty():
			continue
		if core == key:
			return true
		if core.length() <= 16 and core.find(key) >= 0:
			return true
	if core.length() >= 10 and core.length() % 2 == 0:
		var half: int = int(core.length() / 2)
		if core.substr(0, half) == core.substr(half, half):
			return true
	return false


func _compress_for_vector(text: String, keywords: Array[String], max_len: int) -> String:
	var clean: String = _normalize_memory_text(text)
	if clean.length() <= max_len:
		return clean
	var sentence_wrapped: Array[Dictionary] = []
	var sentences: Array[String] = _split_sentences(clean)
	for idx in range(sentences.size()):
		var sentence: String = String(sentences[idx]).strip_edges()
		if sentence.length() < 4:
			continue
		if _is_system_style_text(sentence) or _is_low_value_text(sentence):
			continue
		sentence_wrapped.append({
			"text": sentence,
			"idx": idx,
			"score": _sentence_score(sentence, keywords)
		})
	if sentence_wrapped.is_empty():
		return clean.substr(0, min(max_len, clean.length())).strip_edges()
	sentence_wrapped.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var picked: Array[Dictionary] = sentence_wrapped.slice(0, min(VECTOR_MAX_SUMMARY_SENTENCES, sentence_wrapped.size()))
	picked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("idx", 0)) < int(b.get("idx", 0))
	)
	var parts: Array[String] = []
	for item in picked:
		parts.append(String(item.get("text", "")).strip_edges())
	var merged: String = "；".join(parts).strip_edges()
	if merged.is_empty():
		merged = clean.substr(0, min(max_len, clean.length())).strip_edges()
	if merged.length() > max_len:
		merged = merged.substr(0, max_len).strip_edges()
	return merged


func _split_sentences(text: String) -> Array[String]:
	var out: Array[String] = []
	var buffer: String = ""
	for i in range(text.length()):
		var ch: String = text.substr(i, 1)
		buffer += ch
		if ch == "。" or ch == "！" or ch == "？" or ch == "；" or ch == "!" or ch == "?" or ch == ";" or ch == "\n":
			var piece: String = buffer.strip_edges()
			if not piece.is_empty():
				out.append(piece)
			buffer = ""
	var tail: String = buffer.strip_edges()
	if not tail.is_empty():
		out.append(tail)
	return out


func _sentence_score(sentence: String, keywords: Array[String]) -> float:
	var score: float = clampf(float(sentence.length()) / 36.0, 0.2, 1.4)
	for kw in keywords:
		var token: String = String(kw).strip_edges()
		if token.is_empty():
			continue
		if sentence.find(token) >= 0:
			score += 0.65
	if sentence.find("哥哥") >= 0:
		score += 0.15
	if sentence.find("记得") >= 0 or sentence.find("以后") >= 0 or sentence.find("习惯") >= 0:
		score += 0.15
	return score


func _normalize_for_dedupe(text: String) -> String:
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


func _is_duplicate_candidate(norm_text: String, seen_norms: Array[String]) -> bool:
	if norm_text.is_empty():
		return true
	for old in seen_norms:
		if norm_text == old:
			return true
		var min_len: int = mini(norm_text.length(), old.length())
		if min_len < 12:
			continue
		if norm_text.find(old) >= 0 or old.find(norm_text) >= 0:
			var ratio: float = float(min_len) / float(maxi(norm_text.length(), old.length()))
			if ratio >= 0.88:
				return true
	return false


func _looks_like_corrupted_text(text: String, state: VictoriaState) -> bool:
	var raw: String = String(text).strip_edges()
	if raw.is_empty():
		return false
	if raw.find(char(0xfffd)) >= 0:
		return true
	if state != null and state.has_method("_looks_like_mojibake_text"):
		var state_check: Variant = state.call("_looks_like_mojibake_text", raw)
		if bool(state_check):
			return true
	var marker_hits: int = 0
	for marker in MOJIBAKE_MARKERS:
		if raw.find(marker) >= 0:
			marker_hits += 1
	if marker_hits >= 3 and raw.length() >= 8:
		return true
	return false
