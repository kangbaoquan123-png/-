extends RefCounted

const PREFS_PATH := "user://victoria_player_prefs.cfg"
const API_SECTION := "api"
const DEEPSEEK_KEY_FIELD := "deepseek_api_key"
const API_PROVIDER_FIELD := "provider"
const API_KEY_FIELD := "api_key"
const API_BASE_URL_FIELD := "base_url"
const API_MODEL_FIELD := "model"

const DEFAULT_PROVIDER := "deepseek"
const PROVIDER_DEFAULTS := {
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


static func default_api_config() -> Dictionary:
	var base_defaults_v: Variant = PROVIDER_DEFAULTS.get(DEFAULT_PROVIDER, {})
	var base_defaults: Dictionary = base_defaults_v if base_defaults_v is Dictionary else {}
	return {
		"provider": DEFAULT_PROVIDER,
		"api_key": "",
		"base_url": String(base_defaults.get("base_url", "")),
		"model": String(base_defaults.get("model", ""))
	}


static func _provider_defaults(provider: String) -> Dictionary:
	var key: String = String(provider).strip_edges().to_lower()
	if key.is_empty():
		key = DEFAULT_PROVIDER
	var defaults_v: Variant = PROVIDER_DEFAULTS.get(key, PROVIDER_DEFAULTS.get("custom", {}))
	return defaults_v if defaults_v is Dictionary else {}


static func load_api_config() -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	var load_err: int = cfg.load(PREFS_PATH)
	var defaults: Dictionary = default_api_config()
	if load_err != OK:
		return defaults

	var provider: String = String(cfg.get_value(API_SECTION, API_PROVIDER_FIELD, defaults.get("provider", DEFAULT_PROVIDER))).strip_edges().to_lower()
	if provider.is_empty():
		provider = DEFAULT_PROVIDER
	var provider_defaults: Dictionary = _provider_defaults(provider)
	var legacy_key: String = String(cfg.get_value(API_SECTION, DEEPSEEK_KEY_FIELD, "")).strip_edges()
	var api_key: String = String(cfg.get_value(API_SECTION, API_KEY_FIELD, legacy_key)).strip_edges()
	var base_url: String = String(cfg.get_value(API_SECTION, API_BASE_URL_FIELD, provider_defaults.get("base_url", ""))).strip_edges()
	var model: String = String(cfg.get_value(API_SECTION, API_MODEL_FIELD, provider_defaults.get("model", ""))).strip_edges()

	return {
		"provider": provider,
		"api_key": api_key,
		"base_url": base_url,
		"model": model
	}


static func save_api_config(cfg_input: Dictionary) -> bool:
	var provider: String = String(cfg_input.get("provider", DEFAULT_PROVIDER)).strip_edges().to_lower()
	if provider.is_empty():
		provider = DEFAULT_PROVIDER
	var provider_defaults: Dictionary = _provider_defaults(provider)
	var api_key: String = String(cfg_input.get("api_key", "")).strip_edges()
	var base_url: String = String(cfg_input.get("base_url", provider_defaults.get("base_url", ""))).strip_edges()
	var model: String = String(cfg_input.get("model", provider_defaults.get("model", ""))).strip_edges()
	if api_key.is_empty() or base_url.is_empty() or model.is_empty():
		return false

	var cfg: ConfigFile = ConfigFile.new()
	var _load_err: int = cfg.load(PREFS_PATH)
	cfg.set_value(API_SECTION, API_PROVIDER_FIELD, provider)
	cfg.set_value(API_SECTION, API_KEY_FIELD, api_key)
	cfg.set_value(API_SECTION, API_BASE_URL_FIELD, base_url)
	cfg.set_value(API_SECTION, API_MODEL_FIELD, model)
	if provider == "deepseek":
		cfg.set_value(API_SECTION, DEEPSEEK_KEY_FIELD, api_key)
	return cfg.save(PREFS_PATH) == OK


static func load_deepseek_api_key() -> String:
	var config: Dictionary = load_api_config()
	var api_key: String = String(config.get("api_key", "")).strip_edges()
	if not api_key.is_empty():
		return api_key
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PREFS_PATH) != OK:
		return ""
	return String(cfg.get_value(API_SECTION, DEEPSEEK_KEY_FIELD, "")).strip_edges()


static func save_deepseek_api_key(raw_key: String) -> bool:
	var clean_key: String = String(raw_key).strip_edges()
	if clean_key.is_empty():
		return false
	return save_api_config({
		"provider": "deepseek",
		"api_key": clean_key,
		"base_url": "https://api.deepseek.com/chat/completions",
		"model": "deepseek-chat"
	})
