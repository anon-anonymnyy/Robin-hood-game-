extends CanvasLayer
# Диалоги с выбором. Пока идёт разговор, игра стоит на паузе.
# Реплика: {"who": "Робин", "text": "..."}.
# Реплика с выбором: добавь "choices": [{"text": "...", "effect": "glory" или "shadow", "reply": [реплики]}].
# Нажатие по экрану: дописать текст сразу / перейти к следующей реплике.

signal choice_made(effect: String)

const NAME_COLORS := {
	"Робин": Color(0.55, 0.95, 0.55),
	"Мэриан": Color(1.0, 0.7, 0.85),
	"Гай": Color(1.0, 0.6, 0.45),
	"Шериф": Color(1.0, 0.85, 0.4),
}
const CHARS_PER_SECOND := 55.0

var _queue: Array = []
var _on_done: Callable = Callable()
var _current: Dictionary = {}
var _typing: bool = false
var _showing_choices: bool = false
var _shown: float = 0.0

var _root: Control
var _name_lbl: Label
var _tag_lbl: Label
var _text_lbl: Label
var _hint_lbl: Label
var _choices_box: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui_input)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var box := VBoxContainer.new()
	box.anchor_left = 0.08
	box.anchor_right = 0.92
	box.anchor_top = 0.2
	box.anchor_bottom = 0.95
	box.offset_left = 0.0
	box.offset_right = 0.0
	box.offset_top = 0.0
	box.offset_bottom = 0.0
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	_root.add_child(box)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	_choices_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_choices_box)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.14, 0.92)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sb)
	box.add_child(panel)

	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(row)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 28)
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_name_lbl)

	_tag_lbl = Label.new()
	_tag_lbl.add_theme_font_size_override("font_size", 24)
	_tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_tag_lbl)

	_text_lbl = Label.new()
	_text_lbl.add_theme_font_size_override("font_size", 28)
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.custom_minimum_size = Vector2(0.0, 96.0)
	_text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_text_lbl)

	_hint_lbl = Label.new()
	_hint_lbl.add_theme_font_size_override("font_size", 18)
	_hint_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_hint_lbl)


# Запускает разговор. on_done вызывается, когда реплики кончились и игра снова пошла.
func start(lines: Array, on_done: Callable = Callable()) -> void:
	if lines.is_empty():
		return
	_queue = lines.duplicate()
	_on_done = on_done
	_tag_lbl.text = ""
	visible = true
	get_tree().paused = true
	_next()


func is_active() -> bool:
	return visible


func _next() -> void:
	if _queue.is_empty():
		_close()
		return
	_current = _queue.pop_front()
	var who: String = _current.get("who", "")
	_name_lbl.text = who
	_name_lbl.add_theme_color_override("font_color", NAME_COLORS.get(who, Color(1, 1, 1)))
	_text_lbl.text = _current.get("text", "")
	_text_lbl.visible_characters = 0
	_shown = 0.0
	_typing = true
	_showing_choices = false
	_hint_lbl.text = ""


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	_shown += CHARS_PER_SECOND * delta
	var total := _text_lbl.text.length()
	if _shown >= total:
		_finish_typing()
	else:
		_text_lbl.visible_characters = int(_shown)


func _finish_typing() -> void:
	_typing = false
	_text_lbl.visible_characters = -1
	if _current.has("choices"):
		_show_choices()
	else:
		_hint_lbl.text = "Нажми, чтобы продолжить"


func _show_choices() -> void:
	_showing_choices = true
	_hint_lbl.text = "Выбери ответ"
	var choices: Array = _current["choices"]
	for c in choices:
		var data: Dictionary = c
		var b := Button.new()
		b.text = data.get("text", "...")
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0.0, 68.0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_stylebox_override("normal", _button_style(Color(0.16, 0.30, 0.20, 0.95)))
		b.add_theme_stylebox_override("hover", _button_style(Color(0.20, 0.38, 0.25, 0.95)))
		b.add_theme_stylebox_override("pressed", _button_style(Color(0.30, 0.55, 0.35, 1.0)))
		b.pressed.connect(_on_choice.bind(data))
		_choices_box.add_child(b)


func _button_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


func _on_choice(data: Dictionary) -> void:
	if not _showing_choices:
		return
	_showing_choices = false
	for ch in _choices_box.get_children():
		ch.queue_free()
	var effect: String = data.get("effect", "")
	if effect == "glory":
		_tag_lbl.text = "Слава +1"
		_tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	elif effect == "shadow":
		_tag_lbl.text = "Тень +1"
		_tag_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	if effect != "":
		choice_made.emit(effect)
	var reply: Array = data.get("reply", [])
	for i in range(reply.size() - 1, -1, -1):
		_queue.push_front(reply[i])
	_next()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_tap()


func _tap() -> void:
	if _showing_choices:
		return
	if _typing:
		_finish_typing()
	else:
		_next()


func _close() -> void:
	visible = false
	_typing = false
	_showing_choices = false
	_tag_lbl.text = ""
	get_tree().paused = false
	if _on_done.is_valid():
		var cb := _on_done
		_on_done = Callable()
		cb.call()
