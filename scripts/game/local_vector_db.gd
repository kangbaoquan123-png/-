extends RefCounted
class_name LocalVectorDB

const DB_DIR := "user://vector_memory"
const DB_FILE := "victoria_memory.sqlite"
const TABLE_NAME := "victoria_memory"
const MANIFEST_FILE := "user://vector_memory/local_manifest.json"
const USER_MODEL_DIR := "user://models"
const MAX_MANIFEST_ITEMS := 3000
const COPY_CHUNK_SIZE := 4 * 1024 * 1024
const MODEL_ENV_KEYS: Array[String] = [
	"VICTORIA_EMBED_MODEL_PATH",
	"GODOT_LLM_EMBED_MODEL_PATH",
	"LLM_EMBED_MODEL_PATH"
]
const MODEL_CANDIDATES: Array[String] = [
	"res://models/bge-small-zh-v1.5.gguf",
	"res://models/bge-small-zh-v1.5-q8_0.gguf",
	"res://models/bge-small-en-v1.5.gguf",
	"res://models/bge-small-en-v1.5-q8_0.gguf",
	"user://models/bge-small-zh-v1.5.gguf",
	"user://models/bge-small-en-v1.5.gguf"
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

var _llm_db: Object = null
var _embedder: Object = null
var _llm_enabled: bool = false
var _embedder_ready: bool = false
var _init_attempted: bool = false
var _manifest_loaded: bool = false
var _manifest: Array[Dictionary] = []
var _model_path: String = ""
var _status_text: String = "本地关键词回退(待初始化)"
var _status_color: String = "#f3b35f"
var _last_error: String = ""


func backend_status() -> String:
	return _status_text


func backend_color() -> String:
	return _status_color


func backend_error() -> String:
	return _last_error


func close_backend() -> void:
	if _llm_db != null and _llm_db.has_method("close_db"):
		_llm_db.call("close_db")
	_llm_db = null
	_embedder = null
	_llm_enabled = false
	_embedder_ready = false
	_init_attempted = false


func ensure_ready() -> void:
	_ensure_manifest_loaded()
	if _init_attempted:
		return
	_init_attempted = true

	if not ClassDB.class_exists("LlmDB") or not ClassDB.class_exists("GDEmbedding") or not ClassDB.class_exists("LlmDBMetaData"):
		_set_status("本地关键词回退(插件未启用)", "#f3b35f", "未检测到 LlmDB/GDEmbedding 类")
		return

	_model_path = _resolve_model_path()
	if _model_path.is_empty():
		_set_status("本地关键词回退(未配置嵌入模型)", "#f3b35f", "未找到本地 embedding 模型文件")
		return

	var db_obj: Object = _instantiate("LlmDB")
	if db_obj == null:
		_set_status("本地关键词回退(LlmDB实例化失败)", "#f3b35f", "无法实例化 LlmDB")
		return

	_llm_db = db_obj
	_llm_db.call("set_model_path", _model_path)
	_llm_db.call("set_n_threads", maxi(1, OS.get_processor_count() / 2))
	var db_dir_abs: String = ProjectSettings.globalize_path(DB_DIR)
	DirAccess.make_dir_recursive_absolute(db_dir_abs)
	_llm_db.call("set_db_dir", db_dir_abs)
	_llm_db.call("set_db_file", DB_FILE)
	_llm_db.call("set_table_name", TABLE_NAME)
	_configure_meta_columns(_llm_db)
	_llm_db.call("open_db")
	_llm_db.call("calibrate_embedding_size")
	var emb_size: int = _to_int(_llm_db.call("get_embedding_size"), -1)
	if emb_size <= 0:
		_llm_db = null
		_set_status("本地关键词回退(模型加载失败)", "#f3b35f", "LlmDB embedding_size 无效，请检查模型路径")
		return
	_llm_db.call("create_llm_tables")
	var table_ready: bool = bool(_llm_db.call("has_table", TABLE_NAME))
	if not table_ready:
		_llm_db = null
		_set_status("本地关键词回退(向量表创建失败)", "#f3b35f", "LlmDB has_table=false")
		return

	_llm_enabled = true
	_setup_embedder()
	_set_status("本地向量(LlmDB)", "#7bd88f", "")


func store_memory(text: String, metadata: Dictionary) -> bool:
	ensure_ready()
	var clean_text: String = String(text).strip_edges()
	if clean_text.is_empty():
		return false
	if _looks_like_corrupted_text(clean_text):
		return false

	var full_meta: Dictionary = _normalize_metadata(metadata, clean_text)
	if _is_duplicate_record(clean_text, full_meta):
		return false

	if _llm_enabled and _llm_db != null:
		var db_meta: Dictionary = {
			"id": String(full_meta.get("id", "")),
			"playthrough_id": String(full_meta.get("playthrough_id", "")),
			"day": _to_int(full_meta.get("day"), 1),
			"importance": _to_int(full_meta.get("importance"), 5),
			"created_at_ts": _to_int(full_meta.get("created_at_ts"), int(Time.get_unix_time_from_system())),
			"keywords": String(full_meta.get("keywords", "")),
			"kind": String(full_meta.get("kind", "dialogue"))
		}
		_llm_db.call("store_text_by_meta", db_meta, clean_text)

	_manifest.append({
		"text": clean_text,
		"metadata": full_meta
	})
	while _manifest.size() > MAX_MANIFEST_ITEMS:
		_manifest.pop_front()
	_save_manifest()
	return true


func search_similar(query: String, top_k: int, playthrough_id: String = "") -> Array[Dictionary]:
	ensure_ready()
	var clean_query: String = String(query).strip_edges()
	if clean_query.is_empty():
		return []
	var limit: int = maxi(1, top_k)
	var pid: String = String(playthrough_id).strip_edges()
	var candidates: Array[Dictionary] = []

	if _llm_enabled and _llm_db != null:
		var where_clause: String = ""
		if not pid.is_empty():
			where_clause = "playthrough_id='%s'" % _escape_sql(pid)
		var result_v: Variant = _llm_db.call("retrieve_similar_texts", clean_query, where_clause, limit * 2)
		var result_texts: Array[String] = _variant_to_string_array(result_v)
		for text in result_texts:
			var clean_text: String = String(text).strip_edges()
			if clean_text.is_empty():
				continue
			if _looks_like_corrupted_text(clean_text):
				continue
			var meta: Dictionary = _find_manifest_metadata(clean_text, pid)
			candidates.append({
				"text": clean_text,
				"semantic": _semantic_score(clean_query, clean_text),
				"metadata": meta
			})

	if candidates.is_empty():
		candidates = _fallback_manifest_search(clean_query, limit * 3, pid)

	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: float = float(a.get("semantic", 0.0))
		var score_b: float = float(b.get("semantic", 0.0))
		if is_equal_approx(score_a, score_b):
			var day_a: int = _to_int((a.get("metadata", {}) as Dictionary).get("day", 0), 0)
			var day_b: int = _to_int((b.get("metadata", {}) as Dictionary).get("day", 0), 0)
			return day_a > day_b
		return score_a > score_b
	)

	var deduped: Array[Dictionary] = []
	var seen: Dictionary = {}
	for item in candidates:
		var text_key: String = String(item.get("text", ""))
		if text_key.is_empty() or seen.has(text_key):
			continue
		seen[text_key] = true
		deduped.append(item)
		if deduped.size() >= limit:
			break
	return deduped


func _setup_embedder() -> void:
	var embedder_obj: Object = _instantiate("GDEmbedding")
	if embedder_obj == null:
		_embedder = null
		_embedder_ready = false
		return
	_embedder = embedder_obj
	_embedder.call("set_model_path", _model_path)
	_embedder.call("set_n_threads", maxi(1, OS.get_processor_count() / 2))
	var probe_v: Variant = _embedder.call("compute_embedding", "测试")
	var probe_size: int = _packed_float_count(probe_v)
	_embedder_ready = probe_size > 0


func _configure_meta_columns(db_obj: Object) -> void:
	var meta_builder: Object = _instantiate("LlmDBMetaData")
	if meta_builder == null:
		return
	var meta_array: Array = [
		meta_builder.call("create_text", "id"),
		meta_builder.call("create_text", "playthrough_id"),
		meta_builder.call("create_int", "day"),
		meta_builder.call("create_int", "importance"),
		meta_builder.call("create_int", "created_at_ts"),
		meta_builder.call("create_text", "keywords"),
		meta_builder.call("create_text", "kind")
	]
	db_obj.set("meta", meta_array)


func _normalize_metadata(metadata: Dictionary, text: String) -> Dictionary:
	var now_ts: int = int(Time.get_unix_time_from_system())
	var day: int = _to_int(metadata.get("day"), 1)
	var importance: int = clampi(_to_int(metadata.get("importance"), 5), 0, 10)
	var playthrough_id: String = String(metadata.get("playthrough_id", "default")).strip_edges()
	if playthrough_id.is_empty():
		playthrough_id = "default"
	var kind: String = String(metadata.get("kind", "dialogue")).strip_edges()
	if kind.is_empty():
		kind = "dialogue"
	var keywords: Array[String] = _normalize_keywords(metadata.get("keywords"))
	var keywords_joined: String = "、".join(keywords)
	var created_at_ts: int = _to_int(metadata.get("created_at_ts"), now_ts)
	var id: String = String(metadata.get("id", "")).strip_edges()
	if id.is_empty():
		id = "mem_%s_%s" % [str(day), text.sha256_text().substr(0, 12)]
	return {
		"id": id,
		"text": text,
		"day": day,
		"importance": importance,
		"keywords": keywords_joined,
		"time_anchor": String(metadata.get("time_anchor", "")).strip_edges(),
		"created_at_ts": created_at_ts,
		"playthrough_id": playthrough_id,
		"kind": kind,
		"love_score": _to_int(metadata.get("love_score"), 0)
	}


func _fallback_manifest_search(query: String, top_k: int, playthrough_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in _manifest:
		var text: String = String(item.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		if _looks_like_corrupted_text(text):
			continue
		var meta_v: Variant = item.get("metadata", {})
		if typeof(meta_v) != TYPE_DICTIONARY:
			continue
		var meta: Dictionary = meta_v
		var pid: String = String(meta.get("playthrough_id", "")).strip_edges()
		if not playthrough_id.is_empty() and pid != playthrough_id:
			continue
		var semantic: float = _semantic_score(query, text)
		if semantic <= 0.0:
			semantic = _simple_overlap_score(query, text)
		if semantic < 0.12:
			continue
		out.append({
			"text": text,
			"semantic": semantic,
			"metadata": meta
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("semantic", 0.0)) > float(b.get("semantic", 0.0))
	)
	if out.size() <= top_k:
		return out
	return out.slice(0, top_k)


func _semantic_score(query: String, text: String) -> float:
	if _embedder_ready and _embedder != null:
		var sim_v: Variant = _embedder.call("similarity_cos_string", query, text)
		if typeof(sim_v) == TYPE_FLOAT or typeof(sim_v) == TYPE_INT:
			var raw: float = float(sim_v)
			return clampf((raw + 1.0) * 0.5, 0.0, 1.0)
	return _simple_overlap_score(query, text)


func _simple_overlap_score(query: String, text: String) -> float:
	var q_tokens: Dictionary = _to_token_dict(query)
	if q_tokens.is_empty():
		return 0.0
	var hit: int = 0
	for token in q_tokens.keys():
		var t: String = String(token)
		if t.is_empty():
			continue
		if text.find(t) >= 0:
			hit += 1
	if hit <= 0:
		return 0.0
	return minf(1.0, 0.45 + 0.12 * float(hit))


func _to_token_dict(text: String) -> Dictionary:
	var out: Dictionary = {}
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
		_emit_token(buffer, out)
		buffer = ""
	_emit_token(buffer, out)
	return out


func _emit_token(buffer: String, out: Dictionary) -> void:
	var clean: String = String(buffer).strip_edges()
	if clean.length() >= 2:
		out[clean] = true


func _variant_to_string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		for item in arr:
			var text: String = String(item).strip_edges()
			if not text.is_empty():
				out.append(text)
		return out
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		var p_arr: PackedStringArray = value
		for item2 in p_arr:
			var text2: String = String(item2).strip_edges()
			if not text2.is_empty():
				out.append(text2)
	return out


func _find_manifest_metadata(text: String, playthrough_id: String) -> Dictionary:
	for i in range(_manifest.size() - 1, -1, -1):
		var item: Dictionary = _manifest[i]
		var item_text: String = String(item.get("text", "")).strip_edges()
		if item_text != text:
			continue
		var meta_v: Variant = item.get("metadata", {})
		if typeof(meta_v) != TYPE_DICTIONARY:
			continue
		var meta: Dictionary = meta_v
		var pid: String = String(meta.get("playthrough_id", "")).strip_edges()
		if playthrough_id.is_empty() or pid == playthrough_id:
			return meta
	return {}


func _is_duplicate_record(text: String, metadata: Dictionary) -> bool:
	var pid: String = String(metadata.get("playthrough_id", "")).strip_edges()
	var kind: String = String(metadata.get("kind", "")).strip_edges()
	for item in _manifest:
		var item_text: String = String(item.get("text", "")).strip_edges()
		if item_text != text:
			continue
		var meta_v: Variant = item.get("metadata", {})
		if typeof(meta_v) != TYPE_DICTIONARY:
			continue
		var old_meta: Dictionary = meta_v
		var old_pid: String = String(old_meta.get("playthrough_id", "")).strip_edges()
		var old_kind: String = String(old_meta.get("kind", "")).strip_edges()
		if old_pid == pid and old_kind == kind:
			return true
	return false


func _ensure_manifest_loaded() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	_manifest.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DB_DIR))
	if not FileAccess.file_exists(MANIFEST_FILE):
		return
	var file: FileAccess = FileAccess.open(MANIFEST_FILE, FileAccess.READ)
	if file == null:
		return
	var raw_text: String = file.get_as_text()
	if raw_text.strip_edges().is_empty():
		return
	var parser: JSON = JSON.new()
	if parser.parse(raw_text) != OK:
		return
	var data_v: Variant = parser.data
	if typeof(data_v) != TYPE_ARRAY:
		return
	var data: Array = data_v
	for item_v in data:
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v
		var text: String = String(item.get("text", "")).strip_edges()
		var meta_v: Variant = item.get("metadata", {})
		if text.is_empty() or typeof(meta_v) != TYPE_DICTIONARY:
			continue
		if _looks_like_corrupted_text(text):
			continue
		_manifest.append({
			"text": text,
			"metadata": meta_v
		})
	_purge_corrupted_manifest_entries()


func _save_manifest() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DB_DIR))
	var file: FileAccess = FileAccess.open(MANIFEST_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_manifest))


func _purge_corrupted_manifest_entries() -> void:
	if _manifest.is_empty():
		return
	var filtered: Array[Dictionary] = []
	var touched: bool = false
	for item in _manifest:
		var text: String = String(item.get("text", "")).strip_edges()
		if text.is_empty() or _looks_like_corrupted_text(text):
			touched = true
			continue
		filtered.append(item)
	if touched:
		_manifest = filtered
		_save_manifest()


func _looks_like_corrupted_text(text: String) -> bool:
	var raw: String = String(text).strip_edges()
	if raw.is_empty():
		return false
	if raw.find(char(0xfffd)) >= 0:
		return true
	var marker_hits: int = 0
	for marker in MOJIBAKE_MARKERS:
		if raw.find(marker) >= 0:
			marker_hits += 1
	if marker_hits >= 3 and raw.length() >= 8:
		return true
	return false


func _resolve_model_path() -> String:
	for env_key in MODEL_ENV_KEYS:
		var raw_env: String = String(OS.get_environment(env_key)).strip_edges()
		var normalized: String = _normalize_existing_path(raw_env)
		if not normalized.is_empty():
			return normalized
	for candidate in MODEL_CANDIDATES:
		var normalized_candidate: String = _normalize_existing_path(candidate)
		if not normalized_candidate.is_empty():
			return normalized_candidate
	var discovered: String = _discover_model_from_default_dirs()
	if not discovered.is_empty():
		return discovered
	var external: String = _discover_model_next_to_executable()
	if not external.is_empty():
		return external
	return ""


func _normalize_existing_path(raw: String) -> String:
	var path: String = String(raw).strip_edges()
	if path.is_empty():
		return ""
	if not path.to_lower().ends_with(".gguf"):
		return ""
	if path.begins_with("res://") or path.begins_with("user://"):
		if path.begins_with("res://"):
			var materialized: String = _materialize_res_model(path)
			if not materialized.is_empty():
				return materialized
			return ""
		var abs_user_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or FileAccess.file_exists(abs_user_path):
			return abs_user_path
		return ""
	if FileAccess.file_exists(path):
		return path
	var maybe_abs: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(maybe_abs):
		return maybe_abs
	return ""


func _discover_model_from_default_dirs() -> String:
	var dirs: Array[String] = ["res://models", USER_MODEL_DIR]
	for dir_path in dirs:
		var resolved: String = _discover_first_gguf_in_dir(dir_path)
		if not resolved.is_empty():
			return resolved
	return ""


func _discover_first_gguf_in_dir(dir_path: String) -> String:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir() and name.to_lower().ends_with(".gguf"):
			var candidate: String = "%s/%s" % [dir_path, name]
			var resolved: String = _normalize_existing_path(candidate)
			if not resolved.is_empty():
				dir.list_dir_end()
				return resolved
		name = dir.get_next()
	dir.list_dir_end()
	return ""


func _discover_model_next_to_executable() -> String:
	var exe_path: String = String(OS.get_executable_path()).strip_edges()
	if exe_path.is_empty():
		return ""
	var model_dir_abs: String = "%s/models" % exe_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(model_dir_abs):
		return ""
	var files: PackedStringArray = DirAccess.get_files_at(model_dir_abs)
	for file_name in files:
		var candidate_file: String = String(file_name).strip_edges()
		if not candidate_file.to_lower().ends_with(".gguf"):
			continue
		var candidate_path: String = "%s/%s" % [model_dir_abs, candidate_file]
		if FileAccess.file_exists(candidate_path):
			return candidate_path
	return ""


func _materialize_res_model(res_path: String) -> String:
	if not FileAccess.file_exists(res_path):
		return ""
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		return abs_path
	var target_user_path: String = "%s/%s" % [USER_MODEL_DIR, res_path.get_file()]
	var target_abs_path: String = ProjectSettings.globalize_path(target_user_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_MODEL_DIR))
	if FileAccess.file_exists(target_user_path) and _file_size_safe(target_user_path) > 0:
		return target_abs_path
	if not _copy_file_path(res_path, target_user_path):
		return ""
	if FileAccess.file_exists(target_user_path) and _file_size_safe(target_user_path) > 0:
		return target_abs_path
	return ""


func _copy_file_path(from_path: String, to_path: String) -> bool:
	var reader: FileAccess = FileAccess.open(from_path, FileAccess.READ)
	if reader == null:
		return false
	var writer: FileAccess = FileAccess.open(to_path, FileAccess.WRITE)
	if writer == null:
		return false
	var total: int = reader.get_length()
	while reader.get_position() < total:
		var remain: int = total - reader.get_position()
		var chunk_size: int = mini(COPY_CHUNK_SIZE, remain)
		var chunk: PackedByteArray = reader.get_buffer(chunk_size)
		if chunk_size > 0 and chunk.is_empty():
			return false
		writer.store_buffer(chunk)
	writer.flush()
	return true


func _file_size_safe(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	return f.get_length()


func _instantiate(cls: String) -> Object:
	if not ClassDB.class_exists(cls):
		return null
	var obj_v: Variant = ClassDB.instantiate(cls)
	if obj_v is Object:
		return obj_v as Object
	return null


func _set_status(text: String, color: String, err: String) -> void:
	_status_text = text
	_status_color = color
	_last_error = err


func _packed_float_count(value: Variant) -> int:
	if typeof(value) == TYPE_PACKED_FLOAT32_ARRAY:
		var arr: PackedFloat32Array = value
		return arr.size()
	if typeof(value) == TYPE_PACKED_FLOAT64_ARRAY:
		var arr64: PackedFloat64Array = value
		return arr64.size()
	return 0


func _normalize_keywords(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	var source: Array = []
	if typeof(raw) == TYPE_ARRAY:
		source = raw
	elif typeof(raw) == TYPE_STRING:
		var text: String = String(raw)
		text = text.replace("，", "|").replace(",", "|").replace("、", "|").replace("/", "|").replace("\\", "|")
		text = text.replace("\n", "|").replace("\t", "|").replace(" ", "|")
		source = text.split("|", false)
	for item in source:
		var token: String = String(item).strip_edges()
		if token.is_empty() or token.length() > 20:
			continue
		if seen.has(token):
			continue
		seen[token] = true
		result.append(token)
		if result.size() >= 8:
			break
	return result


func _escape_sql(raw: String) -> String:
	return String(raw).replace("'", "''")


func _to_int(value: Variant, default_value: int = 0) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING and String(value).is_valid_int():
		return int(value)
	return default_value

