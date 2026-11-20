extends CanvasLayer
# Сенсорное управление: джойстик слева, камера справа, кнопки прыжка и приседа.

signal jump_pressed
signal crouch_changed(is_crouching: bool)
signal look_moved(amount: Vector2)
signal aim_toggled(on: bool)
signal fire_pressed
signal interact_pressed
signal menu_pressed
signal arrow_type_changed(arrow_type: int)

const STICK_RADIUS := 110.0
const KNOB_RADIUS := 46.0
const DEAD_ZONE := 0.12
const JUMP_RADIUS := 72.0
const CROUCH_RADIUS := 58.0
const BOW_RADIUS := 58.0
const TYPE_RADIUS := 50.0
const INTERACT_RADIUS := 66.0
const MENU_RADIUS := 38.0

# Вектор движения: x вправо, y вперёд-назад (вверх по экрану = минус).
var move_vector: Vector2 = Vector2.ZERO

var _stick_id: int = -1
var _look_id: int = -1
var _stick_center: Vector2 = Vector2.ZERO
var _stick_pos: Vector2 = Vector2.ZERO
var _crouching: bool = false
var _jump_flash: float = 0.0

var _overlay = null
var _info: Label
var _hint: Label
var _hint_time: float = 0.0
var _light: Label
var _obj: Label
var _msg: Label
var _msg_time: float = 0.0
var suspicion: float = 0.0
var _lit: bool = false
var _noise: int = -1
var _aiming: bool = false
var _arrow_type: int = 0
var _crosshair_hot: bool = false
var _bow_lbl: Label
var _type_lbl: Label
var _fire_lbl: Label
var _ammo_lbl: Label
var _interact_lbl: Label
var _menu_lbl: Label
var _interact_text: String = ""


# Холст, на котором рисуются джойстик и кнопки.
class Overlay extends Control:
	var hud = null

	func _draw() -> void:
		if hud != null:
			hud.draw_overlay(self)


func _ready() -> void:
	layer = 10

	_overlay = Overlay.new()
	_overlay.hud = self
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	_info = Label.new()
	_info.position = Vector2(24.0, 14.0)
	_style_label(_info, 22)
	add_child(_info)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false
	_style_label(_hint, 20)
	add_child(_hint)
	add_to_group("hud")

	_light = Label.new()
	_light.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_light, 20)
	add_child(_light)

	_obj = Label.new()
	_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_obj, 20)
	add_child(_obj)

	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_msg, 34)
	_msg.visible = false
	add_child(_msg)

	_bow_lbl = _make_button_label("Лук")
	_type_lbl = _make_button_label("Обычная")
	_fire_lbl = _make_button_label("Огонь")
	_fire_lbl.visible = false
	_menu_lbl = _make_button_label("Меню")
	_interact_lbl = _make_button_label("")
	_interact_lbl.visible = false
	_ammo_lbl = Label.new()
	_ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_ammo_lbl, 20)
	add_child(_ammo_lbl)


func set_suspicion(v: float) -> void:
	suspicion = v


func set_state(lit: bool, noise: int) -> void:
	if lit == _lit and noise == _noise and _light.text != "":
		return
	_lit = lit
	_noise = noise
	var words := "На свету" if lit else "В тени"
	var sound := "тихо"
	if noise == 1:
		sound = "шаги слышно рядом"
	elif noise == 2:
		sound = "ШУМНО: слышно издалека"
	_light.text = words + " · " + sound
	var warm := lit or noise == 2
	_light.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35) if warm else Color(0.6, 0.8, 1.0))


func set_ammo(normal: int, noise: int, stun: int = 0) -> void:
	_ammo_lbl.text = "Стрелы: боевые %d · шумовые %d · оглушающие %d" % [normal, noise, stun]


# Подсказка внизу экрана на несколько секунд (во время диалога прячется).
func show_hint(text: String, seconds: float) -> void:
	_hint.text = text
	_hint_time = seconds
	_hint.visible = true


func hide_hint() -> void:
	_hint_time = 0.0
	_hint.visible = false


# Кнопка действия («Взять», «Взломать»): пустой текст — кнопка скрыта.
func set_interact(text: String) -> void:
	if text == _interact_text:
		return
	_interact_text = text
	_interact_lbl.text = text
	_interact_lbl.visible = text != ""


func set_aim_hot(hot: bool) -> void:
	_crosshair_hot = hot


func cancel_aim() -> void:
	if _aiming:
		_aiming = false
		aim_toggled.emit(false)


func set_objective(text: String) -> void:
	_obj.text = text


func show_message(text: String, seconds: float) -> void:
	_msg.text = text
	_msg_time = seconds


func _notification(what: int) -> void:
	# Если игру свернули посреди касания, сбрасываем джойстик, чтобы Робин не бежал сам.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_stick_id = -1
		_look_id = -1
		move_vector = Vector2.ZERO


func _make_button_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(150.0, 30.0)
	_style_label(l, 20)
	add_child(l)
	return l


func _place_label(l: Label, center: Vector2) -> void:
	l.size = Vector2(150.0, 30.0)
	l.position = center - Vector2(75.0, 15.0)


func _style_label(l: Label, font_size: int) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size


func _jump_center() -> Vector2:
	var s := _vp()
	return Vector2(s.x - 140.0, s.y - 170.0)


func _crouch_center() -> Vector2:
	var s := _vp()
	return Vector2(s.x - 320.0, s.y - 105.0)


func _bow_center() -> Vector2:
	var s := _vp()
	return Vector2(s.x - 140.0, s.y - 345.0)


func _type_center() -> Vector2:
	var s := _vp()
	return Vector2(s.x - 320.0, s.y - 250.0)


# Кнопка «Огонь» слева над джойстиком (появляется только в прицеле).
func _fire_center() -> Vector2:
	var s := _vp()
	return Vector2(150.0, s.y - 440.0)


# После диалога (игра стояла на паузе) сбрасываем касания, чтобы стик не «залип».
func reset_touches() -> void:
	_stick_id = -1
	_look_id = -1
	move_vector = Vector2.ZERO


func _menu_center() -> Vector2:
	var s := _vp()
	return Vector2(s.x - 60.0, 135.0)


func _interact_center() -> Vector2:
	var s := _vp()
	return Vector2(s.x - 470.0, s.y - 170.0)


func _rest_stick_center() -> Vector2:
	var s := _vp()
	return Vector2(210.0, s.y - 190.0)


func _process(delta: float) -> void:
	var vp := _vp()
	_info.text = "Тест 0.9 ·%d FPS · %s · 3D x%.2f" % [int(Engine.get_frames_per_second()), RenderingServer.get_video_adapter_name(), get_viewport().scaling_3d_scale]
	if _hint_time > 0.0:
		_hint_time -= delta
		if _hint_time <= 0.0:
			_hint.visible = false
	_hint.position = Vector2(0.0, vp.y - 70.0)
	_hint.size = Vector2(vp.x, 40.0)
	_light.position = Vector2(0.0, 40.0)
	_light.size = Vector2(vp.x, 28.0)
	_obj.position = Vector2(0.0, 70.0)
	_obj.size = Vector2(vp.x, 28.0)
	_msg_time = maxf(_msg_time - delta, 0.0)
	_msg.visible = _msg_time > 0.0
	_msg.position = Vector2(vp.x * 0.15, vp.y * 0.28)
	_msg.size = Vector2(vp.x * 0.7, 120.0)
	_jump_flash = maxf(_jump_flash - delta * 4.0, 0.0)
	_place_label(_bow_lbl, _bow_center())
	_place_label(_type_lbl, _type_center())
	_place_label(_fire_lbl, _fire_center())
	_place_label(_interact_lbl, _interact_center())
	_place_label(_menu_lbl, _menu_center())
	_fire_lbl.visible = _aiming
	_bow_lbl.text = "Отмена" if _aiming else "Лук"
	_type_lbl.text = ["Боевая", "Шумовая", "Оглушающая"][_arrow_type]
	_ammo_lbl.position = Vector2(vp.x - 524.0, 14.0)
	_ammo_lbl.size = Vector2(500.0, 30.0)
	_overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touch_drag(d.index, d.position, d.relative)


func _touch_down(id: int, pos: Vector2) -> void:
	if pos.distance_to(_menu_center()) <= MENU_RADIUS:
		menu_pressed.emit()
		return
	if _interact_text != "" and pos.distance_to(_interact_center()) <= INTERACT_RADIUS:
		_jump_flash = 1.0
		interact_pressed.emit()
		return
	if _aiming and pos.distance_to(_fire_center()) <= JUMP_RADIUS:
		_jump_flash = 1.0
		fire_pressed.emit()
		return
	if pos.distance_to(_jump_center()) <= JUMP_RADIUS:
		_jump_flash = 1.0
		jump_pressed.emit()
		return
	if pos.distance_to(_bow_center()) <= BOW_RADIUS:
		_aiming = not _aiming
		aim_toggled.emit(_aiming)
		return
	if pos.distance_to(_type_center()) <= TYPE_RADIUS:
		_arrow_type = (_arrow_type + 1) % 3
		arrow_type_changed.emit(_arrow_type)
		return
	if pos.distance_to(_crouch_center()) <= CROUCH_RADIUS:
		_crouching = not _crouching
		crouch_changed.emit(_crouching)
		return
	if pos.x < _vp().x * 0.5:
		if _stick_id == -1:
			_stick_id = id
			_stick_center = pos
			_stick_pos = pos
			move_vector = Vector2.ZERO
	else:
		if _look_id == -1:
			_look_id = id


func _touch_up(id: int) -> void:
	if id == _stick_id:
		_stick_id = -1
		move_vector = Vector2.ZERO
	elif id == _look_id:
		_look_id = -1


func _touch_drag(id: int, pos: Vector2, rel: Vector2) -> void:
	if id == _stick_id:
		var off := pos - _stick_center
		if off.length() > STICK_RADIUS:
			off = off.normalized() * STICK_RADIUS
		_stick_pos = _stick_center + off
		var v := off / STICK_RADIUS
		if v.length() < DEAD_ZONE:
			v = Vector2.ZERO
		move_vector = v
	elif id == _look_id:
		look_moved.emit(rel)


# Вызывается из Overlay во время отрисовки.
func draw_overlay(c: Control) -> void:
	# Шкала подозрения стражи (вверху по центру)
	if suspicion > 0.01:
		var bw := 360.0
		var bx := _vp().x * 0.5 - bw * 0.5
		var s := clampf(suspicion, 0.0, 1.0)
		c.draw_rect(Rect2(bx - 3.0, 11.0, bw + 6.0, 24.0), Color(0, 0, 0, 0.45))
		c.draw_rect(Rect2(bx, 14.0, bw * s, 18.0), Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.15, 0.1), s))

	# Джойстик
	if _stick_id != -1:
		c.draw_circle(_stick_center, STICK_RADIUS, Color(1, 1, 1, 0.10))
		c.draw_arc(_stick_center, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.40), 3.0)
		c.draw_circle(_stick_pos, KNOB_RADIUS, Color(1, 1, 1, 0.45))
	else:
		var rest := _rest_stick_center()
		c.draw_circle(rest, STICK_RADIUS, Color(1, 1, 1, 0.05))
		c.draw_arc(rest, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 3.0)
		c.draw_circle(rest, KNOB_RADIUS, Color(1, 1, 1, 0.14))

	# Кнопка прыжка
	var jc := _jump_center()
	c.draw_circle(jc, JUMP_RADIUS, Color(1, 1, 1, 0.14 + _jump_flash * 0.3))
	c.draw_arc(jc, JUMP_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0)
	c.draw_colored_polygon(PackedVector2Array([jc + Vector2(0, -26), jc + Vector2(26, 16), jc + Vector2(-26, 16)]), Color(1, 1, 1, 0.8))

	# Кнопка «Огонь» слева (только в прицеле)
	if _aiming:
		var fc := _fire_center()
		c.draw_circle(fc, JUMP_RADIUS, Color(1, 1, 1, 0.14 + _jump_flash * 0.3))
		c.draw_arc(fc, JUMP_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0)
		c.draw_circle(fc, JUMP_RADIUS - 10.0, Color(0.9, 0.2, 0.15, 0.55))

	# Кнопка меню (вверху справа)
	var mc := _menu_center()
	c.draw_circle(mc, MENU_RADIUS, Color(1, 1, 1, 0.12))
	c.draw_arc(mc, MENU_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)

	# Кнопка действия (золотая)
	if _interact_text != "":
		var ic := _interact_center()
		c.draw_circle(ic, INTERACT_RADIUS, Color(1.0, 0.8, 0.25, 0.45 + _jump_flash * 0.3))
		c.draw_arc(ic, INTERACT_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)

	# Кнопка приседа (горит жёлтым, пока Робин присел)
	var cc := _crouch_center()
	var fill := Color(1.0, 0.85, 0.3, 0.45) if _crouching else Color(1, 1, 1, 0.14)
	c.draw_circle(cc, CROUCH_RADIUS, fill)
	c.draw_arc(cc, CROUCH_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0)
	c.draw_colored_polygon(PackedVector2Array([cc + Vector2(-22, -14), cc + Vector2(22, -14), cc + Vector2(0, 20)]), Color(1, 1, 1, 0.8))

	# Кнопка лука (горит жёлтым в режиме прицеливания)
	var bc := _bow_center()
	c.draw_circle(bc, BOW_RADIUS, Color(1.0, 0.85, 0.3, 0.45) if _aiming else Color(1, 1, 1, 0.14))
	c.draw_arc(bc, BOW_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0)

	# Кнопка выбора стрелы (синяя — шумовая)
	var tc := _type_center()
	c.draw_circle(tc, TYPE_RADIUS, [Color(1, 1, 1, 0.14), Color(0.5, 0.75, 1.0, 0.35), Color(0.4, 1.0, 0.5, 0.35)][_arrow_type])
	c.draw_arc(tc, TYPE_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0)

	# Прицел в центре экрана (краснеет, когда автоприцел поймал стражника)
	if _aiming:
		var mid := _vp() * 0.5
		var col := Color(1.0, 0.25, 0.2, 0.95) if _crosshair_hot else Color(1, 1, 1, 0.85)
		c.draw_arc(mid, 16.0, 0.0, TAU, 32, col, 3.0)
		c.draw_circle(mid, 3.0, col)
		c.draw_line(mid + Vector2(-30, 0), mid + Vector2(-20, 0), col, 3.0)
		c.draw_line(mid + Vector2(20, 0), mid + Vector2(30, 0), col, 3.0)
		c.draw_line(mid + Vector2(0, -30), mid + Vector2(0, -20), col, 3.0)
		c.draw_line(mid + Vector2(0, 20), mid + Vector2(0, 30), col, 3.0)
