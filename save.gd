extends RefCounted
# Сохранение прогресса: файл на телефоне (user://save.cfg).

const PATH := "user://save.cfg"


static func load_data() -> Dictionary:
	var d: Dictionary = {"mission1_done": false, "mission2_done": false, "glory": 0, "shadow": 0, "coins_kept": false, "m1_glory": 0, "m1_shadow": 0, "m2_glory": 0, "m2_shadow": 0}
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in d.keys():
			d[k] = cfg.get_value("progress", k, d[k])
	return d


static func write(d: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in d.keys():
		cfg.set_value("progress", k, d[k])
	cfg.save(PATH)


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


# Какую миссию играть по кнопке «Продолжить».
static func next_mission(d: Dictionary) -> int:
	if not bool(d.get("mission1_done", false)):
		return 1
	return 2
