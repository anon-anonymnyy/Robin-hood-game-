extends CanvasLayer
# Заставка на чёрном фоне: начало и конец миссий. Игра на паузе, пока заставка на экране.

var _root: Control
var _title: Label
var _sub: Label
var _body: Label
var _btns: VBoxContainer
var _on_done: Callable = Callable()
var _auto: float = 0.0
var _closing: bool = false
var _tw: Tween = null


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui_input)
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(820.0, 0.0)
	box.add_theme_constant_override("separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 54)
	_title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title)

	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 34)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_sub)

	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 26)
	_body.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_body)

	_btns = VBoxContainer.new()
	_btns.add_theme_constant_override("separation", 12)
	_btns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_btns)


# buttons: [{"text": "...", "cb": Callable}]. Без кнопок заставка закрывается сама через auto_seconds
# (или по нажатию) и вызывает on_done.
func show_card(title: String, sub: String, body: String, buttons: Array, auto_seconds: float = 0.0, on_done: Callable = Callable()) -> void:
	_title.text = title
	_sub.text = sub
	_body.text = body
	_on_done = on_done
	_auto = auto_seconds
	_closing = false
	for ch in _btns.get_children():
		ch.queue_free()
	for b in buttons:
		var data: Dictionary = b
		var btn := Button.new()
		btn.text = data.get("text", "...")
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0.0, 70.0)
		btn.add_theme_font_size_override("font_size", 28)
		btn.add_theme_stylebox_override("normal", _style(Color(0.16, 0.34, 0.2)))
		btn.add_theme_stylebox_override("hover", _style(Color(0.2, 0.42, 0.25)))
		btn.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.55, 0.35)))
		var cb: Callable = data.get("cb", Callable())
		btn.pressed.connect(_on_button.bind(cb))
		_btns.add_child(btn)
	visible = true
	get_tree().paused = true
	_root.modulate.a = 0.0
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_root, "modulate:a", 1.0, 0.6)


func is_active() -> bool:
	return visible


func _style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(1, 1, 1, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	return sb


func _process(delta: float) -> void:
	if not visible or _closing or _auto <= 0.0:
		return
	_auto -= delta
	if _auto <= 0.0:
		_dismiss()


func _on_gui_input(event: InputEvent) -> void:
	if _auto <= 0.0 or _closing:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_dismiss()


func _dismiss() -> void:
	if _closing:
		return
	_closing = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_root, "modulate:a", 0.0, 0.5)
	_tw.tween_callback(_finish_dismiss)


func _finish_dismiss() -> void:
	visible = false
	get_tree().paused = false
	if _on_done.is_valid():
		var cb := _on_done
		_on_done = Callable()
		cb.call()


func _on_button(cb: Callable) -> void:
	visible = false
	get_tree().paused = false
	if cb.is_valid():
		cb.call()
