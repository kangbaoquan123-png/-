extends SceneTree
func _initialize() -> void:
	FileAccess.open('user://probe.txt', FileAccess.WRITE).store_string('ok')
	quit(0)

