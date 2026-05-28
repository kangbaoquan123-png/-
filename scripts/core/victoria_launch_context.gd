extends Node

var startup_menu_page: String = ""
var startup_load_slot_index: int = 0
var startup_force_new_game: bool = false


func consume_startup_menu_page() -> String:
	var page: String = startup_menu_page
	startup_menu_page = ""
	return page


func set_startup_menu_page(page: String) -> void:
	startup_menu_page = String(page).strip_edges()


func consume_startup_load_slot_index() -> int:
	var slot_index: int = startup_load_slot_index
	startup_load_slot_index = 0
	return slot_index


func set_startup_load_slot_index(slot_index: int) -> void:
	startup_load_slot_index = max(slot_index, 0)


func consume_startup_force_new_game() -> bool:
	var force_new: bool = startup_force_new_game
	startup_force_new_game = false
	return force_new


func set_startup_force_new_game(force_new: bool) -> void:
	startup_force_new_game = force_new
