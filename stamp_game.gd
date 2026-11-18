extends CanvasLayer
# Мини-игра «поставь печать»: белая полоска ходит туда-сюда, нажми «ПЕЧАТЬ!», когда она в зелёной зоне.

signal finished

const BAR_W := 640.0
const BAR_H := 46.0
const HOLDER_W := 720.0
const HOLDER_H := 330.0

var _t: float = 0.0
var _zone_start: float = 0.4
var _zone_w: float = 0.16
var _fails: int = 0
var _done_timer: float = 0.0
var _running: bool = false

var _root: Control
var _holder: Control
var _zone: ColorRect
var _mark: ColorRect
var _info: Label
var _btn: Button


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_holder = Control.new()
	_holder.size = Vector2(HOLDER_W, HOLDER_H)
	_root.add_child(_holder)

	var panel := Panel.new()
	panel.size = Vector2(HOLDER_W, HOLDER_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.14, 0.95)
	sb.border_color = Color(1, 1, 1, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	_holder.add_child(panel)

	var title := Label.new()
	title.text = "Поставь печать шерифа!"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20.0, 14.0)
	title.size = Vector2(HOLDER_W - 40.0, 44.0)
	_holder.add_child(title)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 22)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.position = Vector2(30.0, 64.0)
	_info.size = Vector2(HOLDER_W - 60.0, 60.0)
	_holder.add_child(_info)

	var bar := ColorRect.new()
	bar.color = Color(0.2, 0.2, 0.26)
	bar.position = Vector2((HOLDER_W - BAR_W) * 0.5, 140.0)
	bar.size = Vector2(BAR_W, BAR_H)
	_holder.add_child(bar)

	_zone = ColorRect.new()
	_zone.color = Color(0.25, 0.8, 0.35)
	_zone.size = Vector2(BAR_W * _zone_w, BAR_H)
	bar.add_child(_zone)

	_mark = ColorRect.new()
	_mark.color = Color(1, 1, 1)
	_mark.size = Vector2(10.0, BAR_H + 20.0)
	_mark.position = Vector2(0.0, -10.0)
	bar.add_child(_mark)

	_btn = Button.new()
	_btn.text = "ПЕЧАТЬ!"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.add_theme_font_size_override("font_size", 32)
	_btn.position = Vector2(210.0, 234.0)
	_btn.size = Vector2(300.0, 72.0)
	_btn.add_theme_stylebox_override("normal", _style(Color(0.7, 0.2, 0.18, 0.95)))
	_btn.add_theme_stylebox_override("hover", _style(Color(0.8, 0.28, 0.22, 0.95)))
	_btn.add_theme_stylebox_override("pressed", _style(Color(0.9, 0.4, 0.3, 1.0)))
	_btn.pressed.connect(_on_press)
	_holder.add_child(_btn)


func _style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	return sb


func is_active() -> bool:
	return visible


func start() -> void:
	var vp := get_viewport().get_visible_rect().size
	_holder.position = (vp - Vector2(HOLDER_W, HOLDER_H)) * 0.5
	_t = 0.0
	_fails = 0
	_done_timer = 0.0
	_running = true
	_btn.disabled = false
	_new_zone()
	_info.text = "Нажми, когда белая полоска окажется в зелёной зоне."
	visible = true
	get_tree().paused = true


func _new_zone() -> void:
	_zone_w = minf(0.16 + 0.04 * float(_fails), 0.32)
	_zone_start = randf_range(0.12, 0.88 - _zone_w)
	_zone.size = Vector2(BAR_W * _zone_w, BAR_H)
	_zone.position = Vector2(BAR_W * _zone_start, 0.0)


func _mark_pos() -> float:
	return 0.5 + 0.5 * sin(_t)


func _process(delta: float) -> void:
	if not visible:
		return
	if _done_timer > 0.0:
		_done_timer -= delta
		if _done_timer <= 0.0:
			_close()
		return
	_t += delta * 2.3
	_mark.position.x = _mark_pos() * (BAR_W - 10.0)


func _on_press() -> void:
	if not _running or _done_timer > 0.0:
		return
	var p := (_mark.position.x + 5.0) / BAR_W
	if p >= _zone_start and p <= _zone_start + _zone_w:
		_running = false
		_btn.disabled = true
		_info.text = "Оттиск чистый! Печать на месте."
		_done_timer = 0.9
	else:
		_fails += 1
		_info.text = "Смазано! Попробуй ещё раз."
		_new_zone()


func _close() -> void:
	visible = false
	get_tree().paused = false
	finished.emit()
