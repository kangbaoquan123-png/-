extends RefCounted
class_name VictoriaSceneConfig

const PERIOD_MUSIC := {
	"morning": "res://assets/audio/Morning.mp3",
	"noon": "res://assets/audio/noon.mp3",
	"afternoon": "res://assets/audio/Afternoon.mp3",
	"night": "res://assets/audio/linen_and_needle.mp3"
}
const CICADA_PRIMARY := "res://assets/audio/cicada_16.wav"
const CICADA_FALLBACK := "res://assets/audio/cicada.wav"

const BG_TEXTURES := {
	"sister_room_morning": "res://assets/backgrounds/sister_room_morning.png",
	"sister_room_afternoon": "res://assets/backgrounds/sister_room_afternoon.png",
	"sister_room_night": "res://assets/backgrounds/sister_room_night.png",
	"living_room_morning": "res://assets/backgrounds/living_room_morning.png",
	"living_room_afternoon": "res://assets/backgrounds/living_room_afternoon.jpg",
	"living_room_night": "res://assets/backgrounds/living_room_night.jpg",
	"kitchen_morning": "res://assets/backgrounds/kitchen_morning.jpg",
	"kitchen_afternoon": "res://assets/backgrounds/kitchen_afternoon.jpg",
	"kitchen_night": "res://assets/backgrounds/kitchen_night.jpg",
	"player_room_morning": "res://assets/backgrounds/player_room_morning.jpg",
	"player_room_afternoon": "res://assets/backgrounds/player_room_afternoon.jpg",
	"player_room_night": "res://assets/backgrounds/player_room_night.jpg",
	"player_room_night_alt": "res://assets/backgrounds/player_room_night_alt.jpg"
}

const ROOM_BG_KEYS := {
	"sister_room": {
		"\u65e9\u4e0a": "sister_room_morning",
		"\u4e2d\u5348": "sister_room_morning",
		"\u4e0b\u5348": "sister_room_afternoon",
		"\u665a\u4e0a": "sister_room_night"
	},
	"living_room": {
		"\u65e9\u4e0a": "living_room_morning",
		"\u4e2d\u5348": "living_room_morning",
		"\u4e0b\u5348": "living_room_afternoon",
		"\u665a\u4e0a": "living_room_night"
	},
	"kitchen": {
		"\u65e9\u4e0a": "kitchen_morning",
		"\u4e2d\u5348": "kitchen_morning",
		"\u4e0b\u5348": "kitchen_afternoon",
		"\u665a\u4e0a": "kitchen_night"
	},
	"player_room": {
		"\u65e9\u4e0a": "player_room_morning",
		"\u4e2d\u5348": "player_room_morning",
		"\u4e0b\u5348": "player_room_afternoon",
		"\u665a\u4e0a": "player_room_night"
	}
}

const CHAR_TEXTURES := {
	"everyday": "res://assets/characters/everyday.png",
	"shy": "res://assets/characters/shy.png",
	"shy2": "res://assets/characters/shy2.png",
	"dislike": "res://assets/characters/dislike.png",
	"cross": "res://assets/characters/cross.png",
	"worry": "res://assets/characters/worry.png"
}

const CHAR_BASE_OFFSET_TOP := 70.0
const CHAR_BASE_OFFSET_BOTTOM := -200.0
const CHAR_BASE_YOFFSET := 340.0
