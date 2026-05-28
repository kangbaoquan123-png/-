extends Node2D

const STORY_FILE := "res://data/prologue_story.json"
const RUNTIME_SAVE_FILE := "user://victoria_runtime_save.json"
const SLOT_SAVE_DIR := "user://save_slots"
const SLOT_SAVE_PAGE_COUNT := 9
const SLOT_SAVE_COLS := 3
const SLOT_SAVE_ROWS := 2
const SLOT_SAVE_PER_PAGE := SLOT_SAVE_COLS * SLOT_SAVE_ROWS
const SLOT_SAVE_MAX := SLOT_SAVE_PAGE_COUNT * SLOT_SAVE_PER_PAGE
const MEMORY_TRIGGER_COUNT := 5
const TYPEWRITER_CPS := 32.0
const PROACTIVE_TRIGGER_RATE := 0.25
const ATTITUDE_UPDATE_MIN_DAY_GAP := 2
const DEFAULT_DEEPSEEK_API_KEY := ""
const DEBUG_UI_ENABLED := false

var story_data: Dictionary = {}
var current_label: String = ""
var current_index: int = 0
var waiting_for_choice: bool = false
var mode: String = "story"

var state: VictoriaState = VictoriaState.new()
var memory_model: VictoriaMemoryModel = VictoriaMemoryModel.new()
var memory_service: VictoriaMemoryService = VictoriaMemoryService.new()
var web_service: VictoriaWebContext = VictoriaWebContext.new()
var reply_parser: VictoriaReplyParser = VictoriaReplyParser.new()
var prompt_builder: VictoriaPromptBuilder = VictoriaPromptBuilder.new()

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var background_rect: TextureRect
var character_rect: TextureRect
var fade_rect: ColorRect

var hud_label: Label
var mood_label: Label
var speaker_label: Label
var dialogue_label: Label
var chat_prompt_label: Label
var status_label: Label
var money_value_label: Label

var love_value_label: Label
var love_percent_label: Label
var love_fill: ColorRect
var love_track_height: float = 260.0

var choices_box: VBoxContainer
var next_button: Button
var input_line: LineEdit
var input_row_margin_ref: Control
var send_button: Button
var end_turn_button: Button
var room_button: Button
var play_game_button: Button
var blackjack_panel: PanelContainer
var blackjack_rules_button: Button
var blackjack_rules_panel: PanelContainer
var blackjack_rules_label: Label
var blackjack_status_label: Label
var blackjack_dealer_label: Label
var blackjack_dealer_cards_label: Label
var blackjack_dealer_cards_area: Control
var blackjack_player_label: Label
var blackjack_player_cards_label: Label
var blackjack_player_cards_area: Control
var blackjack_trust_track: Control
var blackjack_trust_fill: Control
var blackjack_trust_text_label: Label
var blackjack_balance_label: Label
var blackjack_deck_area: Control
var blackjack_deck_stack_layer: Control
var blackjack_deck_count_label: Label
var blackjack_draw_particles: GPUParticles2D
var blackjack_result_particles: GPUParticles2D
var blackjack_input_panel: PanelContainer
var blackjack_input_line: LineEdit
var blackjack_hit_button: Button
var blackjack_stand_button: Button
var blackjack_new_round_button: Button
var blackjack_close_button: Button
var blackjack_bet_buttons: Dictionary = {}
var blackjack_bet_hint_label: Label
var web_toggle_button: Button
var debug_toggle_button: Button
var room_nav_button: Button
var call_victoria_button: Button
var room_nav_panel: PanelContainer
var room_nav_list: VBoxContainer
var room_nav_mask: ColorRect
var debug_panel: PanelContainer
var debug_label: Label
var notify_panel: PanelContainer
var notify_label: Label
var notify_timer: Timer
var ai_waiting_label: Label

var typing_active: bool = false
var typing_full_text: String = ""
var typing_visible_chars: int = 0
var typing_accumulator: float = 0.0
var ai_waiting_active: bool = false
var ai_waiting_message: String = "维多利亚正在思考"
var waiting_indicator_accum: float = 0.0
var quick_skip_enabled: bool = false
var quick_auto_enabled: bool = false
var quick_advance_accum: float = 0.0
var modal_ui_open: bool = false

var pending_shift_after_line: bool = false
var pending_period_intro: bool = false
var transition_active: bool = false
var latest_mood: String = "日常"
var queued_reply_segments: Array[String] = []
var pending_exit_after_segments: bool = false

var sfx_player: AudioStreamPlayer
var footstep_stream: AudioStream
var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var http_request: HTTPRequest
var memory_http_request: HTTPRequest
var web_http_request: HTTPRequest
var current_music_path: String = ""
var current_ambience_path: String = ""
var runtime_state_was_sanitized: bool = false
var blackjack_active: bool = false
var blackjack_round_over: bool = false
var blackjack_reveal_dealer: bool = false
var blackjack_animating: bool = false
var blackjack_status_text: String = ""
var blackjack_deck: Array[Dictionary] = []
var blackjack_player_cards: Array[Dictionary] = []
var blackjack_dealer_cards: Array[Dictionary] = []
var blackjack_discard_cards: Array[Dictionary] = []
var blackjack_last_player_count: int = 0
var blackjack_last_dealer_count: int = 0
var blackjack_last_reveal_dealer: bool = false
var blackjack_discard_stack_layer: Control
var blackjack_selected_bet: int = 10
var blackjack_round_bet: int = 10
var blackjack_last_selected_bet_fx: int = -1
var blackjack_rules_open: bool = false


