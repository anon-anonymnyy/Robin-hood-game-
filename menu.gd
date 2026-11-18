extends Control
# Главное меню: продолжить, новая игра, выбор миссии.

const SaveScript = preload("res://save.gd")

var _info: Label


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(0.10, 0.22, 0.14, 0.35)
	glow.anchor_left = 0.0
	glow.anchor_right = 1.0
	glow.anchor_top = 0.55
	glow.anchor_bottom = 1.0
	add_child(glow)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(680.0, 0.0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "Робин Гуд"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Не тот кошелёк"
	sub.add_theme_font_size_override("font_size", 34)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var d: Dictionary = SaveScript.load_data()
	var has_save: bool = SaveScript.has_save()
	var next: int = SaveScript.next_mission(d)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 22)
	_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if has_save:
		_info.text = "Слава %d · Тень %d" % [int(d["glory"]), int(d["shadow"])]
	else:
		_info.text = "Сохранений пока нет"
	box.add_child(_info)

	var cont := _make_button("Продолжить: миссия %d" % next, Color(0.16, 0.34, 0.2))
	cont.disabled = not has_save
	cont.pressed.connect(_start_mission.bind(next))
	box.add_child(cont)

	var new_game := _make_button("Новая игра", Color(0.16, 0.26, 0.38))
	new_game.pressed.connect(_new_game)
	box.add_child(new_game)

	var m1 := _make_button("Миссия 1: Побег из кабинета", Color(0.2, 0.2, 0.3))
	m1.pressed.connect(_start_mission.bind(1))
	box.add_child(m1)

	var m2 := _make_button("Миссия 2: Деревня должников", Color(0.2, 0.2, 0.3))
	m2.pressed.connect(_start_mission.bind(2))
	box.add_child(m2)

	var ver := Label.new()
	ver.text = "Тестовая сборка 0.9"
	ver.add_theme_font_size_override("font_size", 18)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ver)


func _make_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, 72.0)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_stylebox_override("normal", _style(col))
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _style(col.lightened(0.3)))
	b.add_theme_stylebox_override("disabled", _style(Color(0.15, 0.15, 0.18, 0.7)))
	return b


func _style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(1, 1, 1, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	return sb


func _new_game() -> void:
	SaveScript.clear()
	_start_mission(1)


func _start_mission(n: int) -> void:
	if n == 1:
		get_tree().change_scene_to_file("res://main.tscn")
	else:
		get_tree().change_scene_to_file("res://mission2.tscn")
