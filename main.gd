extends Node3D
# Робин Гуд: Не тот кошелёк. Тестовая сборка 0.8.
# Миссия 1: кабинет шерифа (спящая стража, сундук с печатью), коридор с люстрой, двор замка и ворота.

const PlayerScript = preload("res://player.gd")
const HudScript = preload("res://hud.gd")
const GuardScript = preload("res://guard.gd")
const ArrowScript = preload("res://arrow.gd")
const DialogueScript = preload("res://dialogue.gd")

const SaveScript = preload("res://save.gd")
const NpcScript = preload("res://npc.gd")
const TitleScript = preload("res://title_card.gd")

const SPAWN := Vector3(0.0, 0.3, -12.5)
# Кабинет и коридор построены далеко от двора, по оси X.
const OX := 200.0
const OFFICE_SPAWN := Vector3(OX + 1.5, 0.3, -4.6)
const CHASE_SPAWN := Vector3(OX + 4.0, 0.3, -2.0)
const CHEST_POS := Vector3(OX + 6.0, 0.0, -4.5)
const DOOR_POS := Vector3(OX + 44.2, 0.0, 0.0)
const CHAND_X := OX + 30.0
const LOCK_TIME := 8.0
const STAGE_OFFICE := 0
const STAGE_CORRIDOR := 1
const STAGE_YARD := 2
const AMMO_NORMAL := 15
const AMMO_NOISE := 5
const AMMO_STUN := 5

const LOOK_SENSITIVITY := 0.006
const PITCH_MIN := -1.2
const PITCH_MAX := 0.55

var _player = null
var _hud = null
var _rig: Node3D
var _pitch_node: Node3D
var _yaw: float = PI
var _pitch: float = -0.35
var _guards: Array = []
var _torches: Array = []
var _won: bool = false
var _cam: Camera3D
var _arm: SpringArm3D
var _aiming: bool = false
var _aim_t: float = 0.0
var _arrow_type: int = 0
var _ammo_normal: int = AMMO_NORMAL
var _ammo_noise: int = AMMO_NOISE
var _ammo_stun: int = AMMO_STUN
var _kills: int = 0
var _card = null
var _shot_cd: float = 0.0
var _assist_on: bool = false
var _assist_point: Vector3 = Vector3.ZERO
var _target_hits: int = 0
var _dlg = null
var _glory: int = 0
var _shadow: int = 0
var _caught_count: int = 0
var _stuns: int = 0
var _stage: int = STAGE_OFFICE
var _has_pouch: bool = false
var _office_guards: Array = []
var _hall_door: StaticBody3D = null
var _end_door: StaticBody3D = null
var _chand: Node3D = null
var _rope_body: StaticBody3D = null
var _wreck: StaticBody3D = null
var _chand_fallen: bool = false
var _chand_tw: Tween = null
var _caught_frame: int = -1
var _picking: bool = false
var _lock_t: float = 0.0


func _ready() -> void:
	_build_environment()
	_build_world()
	_build_office()
	_spawn_player()
	_build_camera()
	_build_hud()
	_build_dialogue()
	_spawn_guards()
	_build_office_guards()
	_build_goal()
	_build_targets()
	_hud.set_ammo(_ammo_normal, _ammo_noise, _ammo_stun)
	_hud.set_objective("Цель: возьми добычу из сундука у восточной стены. Присев, ты идёшь бесшумно")
	_start_card("Миссия 1", "Побег из кабинета", "Ночь. Замок шерифа Ноттингема.", _play_intro)


func _process(delta: float) -> void:
	if _player == null:
		return
	_player.cam_yaw = _yaw
	var target: Vector3 = _player.global_position + Vector3(0.0, 1.5, 0.0)
	_rig.global_position = _rig.global_position.lerp(target, clampf(14.0 * delta, 0.0, 1.0))
	_rig.rotation.y = _yaw
	_pitch_node.rotation.x = _pitch

	# Прицеливание: камера приближается и уходит за правое плечо.
	_shot_cd = maxf(_shot_cd - delta, 0.0)
	_aim_t = move_toward(_aim_t, 1.0 if _aiming else 0.0, delta * 6.0)
	_arm.spring_length = lerpf(6.0, 3.0, _aim_t)
	# Камера смещена влево: Робин стоит правее центра, лук в левой руке хорошо виден.
	_arm.position.x = -0.9 * _aim_t
	_cam.fov = lerpf(70.0, 52.0, _aim_t)
	if _aiming:
		_update_assist()
	_hud.set_aim_hot(_aiming and _assist_on)

	_update_stage(delta)

	var worst := 0.0
	if not _won:
		for g in _all_guards():
			var s: float = g.suspicion
			worst = maxf(worst, s)
	_hud.set_suspicion(worst)
	_hud.set_state(_player.is_lit(), _player.noise_level())


func _on_look_moved(rel: Vector2) -> void:
	var k := LOOK_SENSITIVITY * (0.55 if _aiming else 1.0)
	_yaw -= rel.x * k
	_pitch = clampf(_pitch - rel.y * k, PITCH_MIN, PITCH_MAX)


# ---------- Игрок, камера, интерфейс ----------

func _spawn_player() -> void:
	_player = PlayerScript.new()
	_player.torch_positions = _torches
	add_child(_player)
	_player.respawn(OFFICE_SPAWN)


func _build_camera() -> void:
	_rig = Node3D.new()
	add_child(_rig)
	_rig.global_position = _player.global_position + Vector3(0.0, 1.5, 0.0)

	_pitch_node = Node3D.new()
	_rig.add_child(_pitch_node)

	# SpringArm не даёт камере уходить внутрь стен.
	var arm := SpringArm3D.new()
	arm.spring_length = 6.0
	arm.margin = 0.3
	arm.collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	arm.shape = sphere
	_pitch_node.add_child(arm)
	_arm = arm

	var cam := Camera3D.new()
	cam.near = 0.1
	cam.far = 150.0
	cam.fov = 70.0
	arm.add_child(cam)
	cam.current = true
	_cam = cam


func _build_hud() -> void:
	_hud = HudScript.new()
	add_child(_hud)
	_hud.connect("look_moved", _on_look_moved)
	_hud.connect("jump_pressed", Callable(_player, "queue_jump"))
	_hud.connect("crouch_changed", Callable(_player, "set_crouch"))
	_hud.connect("aim_toggled", _on_aim_toggled)
	_hud.connect("fire_pressed", _fire)
	_hud.connect("interact_pressed", _on_interact)
	_hud.connect("menu_pressed", _on_menu_pressed)
	_hud.connect("arrow_type_changed", _on_arrow_type)
	_player.hud = _hud


# ---------- Диалоги и выбор «Слава» / «Тень» ----------

func _build_dialogue() -> void:
	_dlg = DialogueScript.new()
	add_child(_dlg)
	_card = TitleScript.new()
	add_child(_card)
	_dlg.choice_made.connect(_on_choice_made)


func _on_menu_pressed() -> void:
	if _dlg.is_active():
		return
	_hud.cancel_aim()
	var lines: Array = [
		{"who": "Меню", "text": "Выйти в главное меню? Прогресс текущей миссии не сохранится.", "choices": [
			{"text": "Выйти в меню", "effect": "menu_exit", "reply": []},
			{"text": "Остаться в игре", "effect": "", "reply": []},
		]},
	]
	_dlg.start(lines, _after_dialogue)


func _go_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")


func _on_choice_made(effect: String) -> void:
	if effect == "menu_exit":
		call_deferred("_go_menu")
	elif effect == "glory":
		_glory += 1
	elif effect == "shadow":
		_shadow += 1


func _after_dialogue() -> void:
	_hud.reset_touches()


func _after_intro() -> void:
	_hud.reset_touches()
	_hud.show_hint("Бег шумит: стража слышит тебя. Присед (кнопка внизу справа) делает шаги бесшумными. «Лук» — прицел, слева появится «Огонь».", 14.0)


# Заставка с названием миссии; когда закроется — вызывает on_done.
func _start_card(title: String, sub: String, body: String, on_done: Callable) -> void:
	_card.show_card(title, sub, body, [], 3.2, on_done)


func _play_intro() -> void:
	var lines: Array = [
		{"who": "Робин", "text": "План простой: зашёл, взял золото, вышел. Что тут может пойти не так?"},
		{"who": "Робин", "text": "Двое стражников дремлют у стола. Хм... Как будем действовать?", "choices": [
			{"text": "Пройду мимо с гордо поднятой головой!", "effect": "glory", "reply": [
				{"who": "Робин", "text": "Если проснутся, хоть будет что вспомнить. Но лучше не будить."},
			]},
			{"text": "Пригнусь и проберусь тихо.", "effect": "shadow", "reply": [
				{"who": "Робин", "text": "Присед, тишина и ни одного скрипа. Я же профессионал. Почти."},
			]},
		]},
		{"who": "Робин", "text": "Сундук у восточной стены. Золото, я иду!"},
	]
	_dlg.start(lines, _after_intro)


func _play_caught_scene() -> void:
	var lines: Array = [
		{"who": "Гай", "text": "Попался! Наконец-то! Я почти... нет, правда, на этот раз я поймал!"},
		{"who": "Робин", "text": "Почти не считается, Гай. Давай заново?"},
	]
	_dlg.start(lines, _after_dialogue)


func _play_ending() -> void:
	# Мэриан ждёт в тени у ворот.
	var marian = NpcScript.new()
	marian.setup(Color(0.65, 0.25, 0.45), Color(0.25, 0.15, 0.08), "Мэриан", 2, false)
	marian.position = Vector3(4.6, 0.0, 24.2)
	marian.rotation_degrees.y = 90.0
	add_child(marian)
	var lines: Array = [
		{"who": "Мэриан", "text": "Псс! Робин! Я видела, как на стенах зажгли тревогу. Ты что, учудил что-то в кабинете шерифа?"},
		{"who": "Робин", "text": "Учудил. Смотри: это печать, которой шериф заверяет налоги. Я взял её вместо золота."},
		{"who": "Мэриан", "text": "Печать шерифа?! Робин, это же... Что ты собираешься с ней делать?", "choices": [
			{"text": "Раздам бедным! Пусть весь Ноттингем узнает!", "effect": "glory", "reply": [
				{"who": "Мэриан", "text": "Весь Ноттингем и вся стража заодно. Ты слышал слово «тайна»?"},
				{"who": "Робин", "text": "Слышал. Не запомнил."},
			]},
			{"text": "Тихо использую. Налоги исчезнут, а шериф не поймёт куда.", "effect": "shadow", "reply": [
				{"who": "Мэриан", "text": "Хм. Впервые план без дыр. Это подозрительно."},
				{"who": "Робин", "text": "Я сам в шоке."},
			]},
		]},
		{"who": "Мэриан", "text": "Идём скорее, пока стража не опомнилась. Я знаю деревню, где эта печать нужна больше всего."},
	]
	_dlg.start(lines, _finish_mission)


# Сколько стражников сейчас убито (после поимки их оживляют, и счёт обнуляется).
func _dead_count() -> int:
	var n := 0
	for g in _all_guards():
		if g.dead:
			n += 1
	return n


func _kill_bonuses() -> void:
	var k := _dead_count()
	if _caught_count == 0 and k == 0:
		_shadow += 1
	if k >= 3:
		_glory += 1


func _kills_text() -> String:
	var k := _dead_count()
	if k == 0:
		return "Никого не убито: лучник-пацифист."
	return "Стражников убито: %d." % k


func _finish_mission() -> void:
	_hud.reset_touches()
	_hud.set_interact("")
	_kill_bonuses()
	var title := "Загадочный Робин: и шум, и тишина"
	if _glory > _shadow:
		title = "Громкий Робин: о нём говорит весь город"
	elif _shadow > _glory:
		title = "Робин-Тень: его почти никто не видел"
	_save_progress()
	_card.show_card("Миссия 1 пройдена", "Слава %d · Тень %d" % [_glory, _shadow], "%s\n%s" % [title, _kills_text()], [
		{"text": "Дальше: миссия 2", "cb": _go_mission2},
		{"text": "В главное меню", "cb": _go_menu},
	])


func _go_mission2() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://mission2.tscn")


func _save_progress() -> void:
	var d: Dictionary = SaveScript.load_data()
	d["mission1_done"] = true
	d["m1_glory"] = _glory
	d["m1_shadow"] = _shadow
	d["glory"] = _glory + int(d["m2_glory"])
	d["shadow"] = _shadow + int(d["m2_shadow"])
	SaveScript.write(d)


# ---------- Этапы миссии: кабинет, коридор, двор ----------

func _all_guards() -> Array:
	return _guards + _office_guards


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _update_stage(delta: float) -> void:
	if _stage == STAGE_YARD or _won:
		return
	var pp: Vector3 = _player.global_position
	if _stage == STAGE_OFFICE and _has_pouch and pp.x > OX + 8.5:
		_stage = STAGE_CORRIDOR
		_hud.set_objective("Дверь в конце коридора заперта: взломай замок (8 сек). Пробеги под люстрой и сбей её стрелой, пока погоня под ней!")
		_hud.show_message("Беги вперёд! Люстра висит над коридором.", 3.0)

	var txt := ""
	if not _dlg.is_active():
		if not _has_pouch and _flat_dist(pp, CHEST_POS) < 2.4:
			txt = "Взять"
		elif _has_pouch and not _picking and _stage == STAGE_CORRIDOR and _flat_dist(pp, DOOR_POS) < 3.0:
			txt = "Взломать"
	_hud.set_interact(txt)

	if _picking:
		if _flat_dist(pp, DOOR_POS) > 3.6:
			_picking = false
			_hud.show_message("Ты отошёл от двери. Замок снова закрыт.", 2.0)
			_hud.set_objective("Вернись к двери и взломай замок. Стрелой в люстру останови погоню!")
		else:
			_lock_t += delta
			_hud.set_objective("Взламываю замок: %d%%" % int(clampf(_lock_t / LOCK_TIME, 0.0, 1.0) * 100.0))
			if _lock_t >= LOCK_TIME:
				_picking = false
				_enter_yard()


func _on_interact() -> void:
	if _stage == STAGE_YARD or _won or _dlg.is_active():
		return
	var pp: Vector3 = _player.global_position
	if not _has_pouch and _flat_dist(pp, CHEST_POS) < 2.4:
		_take_pouch()
	elif _has_pouch and not _picking and _stage == STAGE_CORRIDOR and _flat_dist(pp, DOOR_POS) < 3.0:
		_picking = true
		_lock_t = 0.0


func _take_pouch() -> void:
	_has_pouch = true
	_hud.set_interact("")
	_hud.cancel_aim()
	var lines: Array = [
		{"who": "Робин", "text": "Тяжёлый мешочек... нет, лёгкий. Это что, не золото? Печать?"},
		{"who": "Стражник", "text": "Эй! Кто тут шуршит?! Вор! ВОР!"},
		{"who": "Гай", "text": "Шериф! Печать пропала!"},
		{"who": "Шериф", "text": "Какая печать?! Та, что заверяет налоги?! Без неё я не могу поднять налоги даже на один пенни!"},
		{"who": "Робин", "text": "Так. Значит, у меня в руках все налоги Ноттингема. Отлично. Или нет. БЕЖИМ!"},
	]
	_dlg.start(lines, _start_chase)


func _start_chase() -> void:
	_hud.reset_touches()
	if _hall_door != null:
		_hall_door.queue_free()
		_hall_door = null
	for g in _office_guards:
		g.wake()
	_hud.set_objective("Беги по коридору к двери! Погоню останови стрелой в люстру")
	_hud.show_message("Тревога! Стража проснулась!", 2.5)


func _enter_yard() -> void:
	_stage = STAGE_YARD
	_hud.set_interact("")
	_hud.cancel_aim()
	for g in _office_guards:
		g.queue_free()
	_office_guards.clear()
	_player.respawn(SPAWN)
	_yaw = PI
	_pitch = -0.35
	_rig.global_position = SPAWN + Vector3(0.0, 1.5, 0.0)
	for g in _guards:
		g.active = true
		g.reset()
	_hud.set_objective("Цель: добеги до ворот на юге, не попавшись страже")
	var lines: Array = [
		{"who": "Робин", "text": "Двор! Весь в страже, но ворота на юге. Побежали, пока Гай ищет очки."},
	]
	_dlg.start(lines, _after_dialogue)


func _drop_chandelier() -> void:
	if _chand_fallen or _chand == null:
		return
	# Пока Робин не прошёл под люстрой, ронять её нельзя: она запрёт его вместе со стражей.
	if _player.global_position.x < CHAND_X + 1.5:
		_hud.show_message("Рано: люстра должна упасть позади тебя.", 2.0)
		return
	_chand_fallen = true
	if _rope_body != null:
		_rope_body.queue_free()
		_rope_body = null
	_chand_tw = create_tween()
	_chand_tw.tween_property(_chand, "position:y", -2.1, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_chand_tw.tween_callback(_chandelier_landed)


func _chandelier_landed() -> void:
	if _wreck != null or not _chand_fallen:
		return
	_wreck = StaticBody3D.new()
	_wreck.position = Vector3(CHAND_X, 0.8, 0.0)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.6, 4.0)
	cs.shape = shape
	_wreck.add_child(cs)
	add_child(_wreck)
	_hud.show_message("Люстра рухнула! Погоня застряла.", 3.0)


func _reset_chandelier() -> void:
	if _chand_tw != null and _chand_tw.is_valid():
		_chand_tw.kill()
	_chand_tw = null
	if _chand != null:
		_chand.queue_free()
		_chand = null
	if _wreck != null:
		_wreck.queue_free()
		_wreck = null
	_rope_body = null
	_chand_fallen = false
	_build_chandelier()


func _build_office_guards() -> void:
	var spots: Array = [Vector3(OX - 3.0, 0.3, 2.0), Vector3(OX - 5.0, 0.3, -1.5)]
	for sp in spots:
		var p: Vector3 = sp
		var g = GuardScript.new()
		g.waypoints = [p]
		g.player = _player
		g.asleep = true
		g.chase_speed = 3.8
		g.relentless = true
		g.position = p
		add_child(g)
		g.caught.connect(_on_caught)
		_office_guards.append(g)


# ---------- Кабинет шерифа и коридор ----------

func _build_office() -> void:
	var stone := Color(0.42, 0.40, 0.44)
	var wood := Color(0.40, 0.27, 0.15)
	var dark_wood := Color(0.26, 0.17, 0.10)
	var floor_col := Color(0.30, 0.22, 0.17)
	var H := 4.6

	# Пол и потолок.
	_add_box(Vector3(OX, -0.5, 0.0), Vector3(16.0, 1.0, 14.0), floor_col)
	_add_box(Vector3(OX, H + 0.25, 0.0), Vector3(16.0, 0.5, 14.0), stone)
	# Стены кабинета (восточная — с проёмом в коридор).
	_add_box(Vector3(OX, H * 0.5, -6.5), Vector3(16.0, H, 1.0), stone)
	_add_box(Vector3(OX, H * 0.5, 6.5), Vector3(16.0, H, 1.0), stone)
	_add_box(Vector3(OX - 7.5, H * 0.5, 0.0), Vector3(1.0, H, 14.0), stone)
	_add_box(Vector3(OX + 7.5, H * 0.5, -4.0), Vector3(1.0, H, 5.0), stone)
	_add_box(Vector3(OX + 7.5, H * 0.5, 4.0), Vector3(1.0, H, 5.0), stone)
	# Дверь в коридор: закрыта, пока Робин не возьмёт печать.
	_hall_door = _make_door(Vector3(OX + 7.5, 1.6, 0.0), Vector3(0.4, 3.2, 3.0), dark_wood)

	# Окно с лунным светом на северной стене.
	_add_deco(_box_mesh(Vector3(2.2, 2.4, 0.1)), Vector3(OX, 2.6, -5.95), Color(0.45, 0.6, 1.0), true)

	# Мебель: стол шерифа, стул, книжные шкафы, ковёр, сундук.
	_add_box(Vector3(OX - 2.0, 0.45, -4.2), Vector3(3.2, 0.9, 1.4), dark_wood)
	_add_box(Vector3(OX - 2.0, 0.4, -2.9), Vector3(0.7, 0.8, 0.7), wood)
	_add_box(Vector3(OX - 6.9, 1.6, -3.0), Vector3(0.6, 3.2, 5.0), wood)
	_add_box(Vector3(OX - 6.9, 1.6, 4.0), Vector3(0.6, 3.2, 4.0), wood)
	_add_deco(_cyl_mesh(2.4, 2.4, 0.03, 16), Vector3(OX - 1.0, 0.02, 1.0), Color(0.55, 0.12, 0.14))
	_add_box(Vector3(CHEST_POS.x, 0.4, CHEST_POS.z), Vector3(1.3, 0.8, 0.8), wood)
	_add_deco(_box_mesh(Vector3(1.3, 0.08, 0.8)), Vector3(CHEST_POS.x, 0.84, CHEST_POS.z), Color(1.0, 0.8, 0.2), true)
	# Свечи на столе и подсвеченные зоны.
	for cx in [-3.0, -1.0]:
		_add_deco(_cyl_mesh(0.05, 0.05, 0.3, 6), Vector3(OX + cx, 1.05, -4.2), Color(0.95, 0.9, 0.7))
		_add_deco(_cyl_mesh(0.0, 0.07, 0.14, 6), Vector3(OX + cx, 1.27, -4.2), Color(1.0, 0.65, 0.2), true)
	_torches.append(Vector3(OX - 2.0, 0.0, -3.0))
	_torches.append(Vector3(CHEST_POS.x, 0.0, CHEST_POS.z + 1.0))

	# Тёплый свет в кабинете (без теней, дёшево).
	_add_warm_light(Vector3(OX - 2.0, 2.6, -2.0), 9.0)
	_add_warm_light(Vector3(OX + 4.0, 2.8, 0.0), 8.0)

	# Коридор: от кабинета на восток до запертой двери.
	var corr_len := 38.0
	var cx0 := OX + 7.5 + corr_len * 0.5
	_add_box(Vector3(cx0, -0.5, 0.0), Vector3(corr_len, 1.0, 6.0), floor_col)
	_add_box(Vector3(cx0, H + 0.25, 0.0), Vector3(corr_len, 0.5, 6.0), stone)
	_add_box(Vector3(cx0, H * 0.5, -2.5), Vector3(corr_len, H, 1.0), stone)
	_add_box(Vector3(cx0, H * 0.5, 2.5), Vector3(corr_len, H, 1.0), stone)
	_add_box(Vector3(OX + 46.0, H * 0.5, 0.0), Vector3(1.0, H, 6.0), stone)
	_end_door = _make_door(Vector3(OX + 45.2, 1.6, 0.0), Vector3(0.5, 3.2, 2.4), dark_wood)
	_add_deco(_box_mesh(Vector3(0.1, 0.3, 0.3)), Vector3(OX + 44.9, 1.5, 0.6), Color(1.0, 0.8, 0.2), true)
	# Факелы вдоль коридора.
	for tx in [14.0, 22.0, 38.0]:
		for sz in [-1.9, 1.9]:
			_add_deco(_box_mesh(Vector3(0.1, 0.5, 0.1)), Vector3(OX + tx, 2.0, sz), Color(0.25, 0.17, 0.10))
			_add_deco(_cyl_mesh(0.0, 0.12, 0.3, 6), Vector3(OX + tx, 2.4, sz), Color(1.0, 0.6, 0.2), true)
	_torches.append(Vector3(OX + 16.0, 0.0, 0.0))
	_torches.append(Vector3(OX + 40.0, 0.0, 0.0))
	_add_warm_light(Vector3(OX + 16.0, 3.0, 0.0), 9.0)
	_add_warm_light(Vector3(OX + 40.0, 3.0, 0.0), 9.0)

	_build_chandelier()


func _make_door(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.material_override = _material(color)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body


func _add_warm_light(pos: Vector3, range_m: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0, 0.72, 0.4)
	l.light_energy = 1.3
	l.omni_range = range_m
	l.shadow_enabled = false
	add_child(l)


# Люстра над коридором: стрела в цепь (невидимая коллизия вокруг неё) обрушивает её.
func _build_chandelier() -> void:
	_chand = Node3D.new()
	_chand.position = Vector3(CHAND_X, 0.0, 0.0)
	add_child(_chand)
	var gold := Color(0.75, 0.6, 0.2)
	var chain := MeshInstance3D.new()
	chain.mesh = _cyl_mesh(0.04, 0.04, 1.7, 6)
	chain.material_override = _material(Color(0.3, 0.3, 0.32))
	chain.position = Vector3(0.0, 3.75, 0.0)
	_chand.add_child(chain)
	var ring := MeshInstance3D.new()
	ring.mesh = _cyl_mesh(1.0, 1.0, 0.14, 12)
	ring.material_override = _material(gold)
	ring.position = Vector3(0.0, 2.95, 0.0)
	_chand.add_child(ring)
	for i in range(6):
		var a := float(i) / 6.0 * TAU
		var c := MeshInstance3D.new()
		c.mesh = _cyl_mesh(0.06, 0.06, 0.28, 6)
		c.material_override = _material(Color(0.95, 0.9, 0.7))
		c.position = Vector3(cos(a) * 0.85, 3.16, sin(a) * 0.85)
		_chand.add_child(c)
		var f := MeshInstance3D.new()
		f.mesh = _cyl_mesh(0.0, 0.08, 0.16, 6)
		f.material_override = _material(Color(1.0, 0.65, 0.2), true)
		f.position = Vector3(cos(a) * 0.85, 3.38, sin(a) * 0.85)
		_chand.add_child(f)
	_rope_body = StaticBody3D.new()
	_rope_body.position = Vector3(0.0, 3.5, 0.0)
	_rope_body.add_to_group("rope")
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2.2, 1.8)
	cs.shape = shape
	_rope_body.add_child(cs)
	_chand.add_child(_rope_body)


# ---------- Лук ----------

func _on_aim_toggled(on: bool) -> void:
	_aiming = on
	_player.aiming = on


func _on_arrow_type(t: int) -> void:
	_arrow_type = t


# Автоприцел: если рядом с перекрестием виден стражник, целимся ему в грудь.
func _update_assist() -> void:
	_assist_on = false
	var from: Vector3 = _cam.global_position
	var fwd: Vector3 = -_cam.global_transform.basis.z
	var best := deg_to_rad(5.0)
	for g in _all_guards():
		if g.dead:
			continue
		var chest: Vector3 = g.global_position + Vector3(0.0, 1.1, 0.0)
		var to: Vector3 = chest - from
		var d := to.length()
		if d < 1.0 or d > 45.0:
			continue
		var ang := fwd.angle_to(to)
		if ang >= best:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, chest, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		best = ang
		_assist_on = true
		_assist_point = chest


func _fire() -> void:
	if not _aiming or _shot_cd > 0.0 or _won:
		return
	var left := _ammo_normal
	if _arrow_type == 1:
		left = _ammo_noise
	elif _arrow_type == 2:
		left = _ammo_stun
	if left <= 0:
		_hud.show_message("Стрелы этого типа кончились", 1.5)
		return
	if _arrow_type == 0:
		_ammo_normal -= 1
	elif _arrow_type == 1:
		_ammo_noise -= 1
	else:
		_ammo_stun -= 1
	_hud.set_ammo(_ammo_normal, _ammo_noise, _ammo_stun)
	_shot_cd = 0.45

	# Целимся туда, куда смотрит перекрестие камеры, и учитываем падение стрелы на лету.
	var from: Vector3 = _cam.global_position
	var fwd: Vector3 = -_cam.global_transform.basis.z
	var aim_pt: Vector3 = from + fwd * 60.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, aim_pt, 5))
	if not hit.is_empty():
		aim_pt = hit["position"]
	if _assist_on:
		aim_pt = _assist_point

	var head_dir := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var chest: Vector3 = _player.global_position + Vector3(0.0, 1.35, 0.0)
	var start: Vector3 = chest + head_dir * 0.7
	var wall := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(chest, start, 1))
	if not wall.is_empty():
		start = chest
	var flight := start.distance_to(aim_pt) / ArrowScript.SPEED
	aim_pt.y += 0.5 * ArrowScript.GRAVITY * flight * flight
	var dir := (aim_pt - start).normalized()

	var arrow = ArrowScript.new()
	arrow.setup(start, dir * ArrowScript.SPEED, _arrow_type)
	add_child(arrow)
	arrow.hit_something.connect(_on_arrow_hit)


func _on_arrow_hit(collider, pos: Vector3, kind: int) -> void:
	var radius := 22.0 if kind == 1 else 6.0
	if collider != null and collider.is_in_group("guards"):
		if kind == 0:
			collider.kill()
			_kills += 1
			_hud.show_message("Стражник прилёг отдохнуть. Навсегда.", 2.0)
		elif kind == 2:
			collider.stun()
			_stuns += 1
		radius = maxf(radius, 9.0)
	elif collider != null and collider.is_in_group("targets"):
		_target_hit(collider)
		return
	elif collider != null and collider.is_in_group("rope"):
		_drop_chandelier()
		return
	_make_noise(pos, radius, collider)


# Удар стрелы слышат стражники в радиусе: они идут проверять место удара.
func _make_noise(pos: Vector3, radius: float, skip) -> void:
	for g in _guards:
		if g == skip or g.dead:
			continue
		var d: float = g.global_position.distance_to(pos)
		if d < radius:
			g.hear(pos)


func _target_hit(body: Node) -> void:
	_target_hits += 1
	if body.has_meta("mat"):
		var m: StandardMaterial3D = body.get_meta("mat")
		var home := Color(0.9, 0.8, 0.25)
		m.albedo_color = Color(0.3, 1.0, 0.4)
		m.emission = Color(0.3, 1.0, 0.4)
		if body.has_meta("tween"):
			var old: Tween = body.get_meta("tween")
			if old != null and old.is_valid():
				old.kill()
		var tw := create_tween()
		tw.tween_property(m, "albedo_color", home, 0.8)
		tw.parallel().tween_property(m, "emission", home, 0.8)
		body.set_meta("tween", tw)
	if not _won:
		_hud.show_message("В яблочко! Мишеней поражено: %d" % _target_hits, 1.2)


# Три мишени у донжона для пристрелки (удар по мишени стража не слышит).
func _build_targets() -> void:
	var spots: Array = [Vector3(-7.0, 1.5, -8.5), Vector3(0.0, 1.5, -6.0), Vector3(7.0, 1.5, -8.5)]
	for s in spots:
		var p: Vector3 = s
		var body := StaticBody3D.new()
		body.position = p
		# Диск повёрнут лицом на север, к стартовой точке Робина.
		body.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		body.add_to_group("targets")

		var rings: Array = [[0.7, 0.0, Color(0.88, 0.88, 0.82)], [0.45, 0.03, Color(0.85, 0.15, 0.12)], [0.2, 0.06, Color(0.9, 0.8, 0.25)]]
		for r in rings:
			var radius: float = r[0]
			var off: float = r[1]
			var col: Color = r[2]
			var mesh := CylinderMesh.new()
			mesh.top_radius = radius
			mesh.bottom_radius = radius
			mesh.height = 0.08
			mesh.radial_segments = 24
			mesh.rings = 1
			var mat := _material(col)
			if radius < 0.3:
				mat.emission_enabled = true
				mat.emission = col
				mat.emission_energy_multiplier = 1.0
				body.set_meta("mat", mat)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.position = Vector3(0.0, off, 0.0)
			body.add_child(mi)

		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.7
		shape.height = 0.16
		cs.shape = shape
		cs.position = Vector3(0.0, 0.03, 0.0)
		body.add_child(cs)
		add_child(body)

		var post := _cyl_mesh(0.06, 0.06, 1.5, 8)
		_add_deco(post, Vector3(p.x, 0.75, p.z + 0.2), Color(0.35, 0.24, 0.13))


# ---------- Стража и цель миссии ----------

func _spawn_guards() -> void:
	var routes: Array = [
		[Vector3(-6.0, 0.0, -2.0), Vector3(16.0, 0.0, -2.0), Vector3(-16.0, 0.0, -2.0)],
		[Vector3(0.0, 0.0, 15.5), Vector3(0.0, 0.0, 21.0)],
		[Vector3(-4.0, 0.0, 4.0), Vector3(4.0, 0.0, 4.0), Vector3(4.0, 0.0, 11.0), Vector3(-4.0, 0.0, 11.0)],
		[Vector3(-14.0, 0.0, 13.5), Vector3(14.0, 0.0, 13.5), Vector3(14.0, 0.0, 19.5), Vector3(-14.0, 0.0, 19.5)],
	]
	for route in routes:
		var first: Vector3 = route[0]
		var g = GuardScript.new()
		g.waypoints = route
		g.player = _player
		g.position = first + Vector3(0.0, 0.3, 0.0)
		g.active = false
		add_child(g)
		g.caught.connect(_on_caught)
		_guards.append(g)


func _build_goal() -> void:
	# Зелёная светящаяся полоса у ворот и невидимая зона, в которую нужно войти.
	_add_deco(_box_mesh(Vector3(7.0, 0.04, 2.4)), Vector3(0.0, 0.04, 23.6), Color(0.3, 1.0, 0.4), true)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = Vector3(0.0, 2.0, 23.6)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.0, 4.0, 2.4)
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_goal_entered)


func _on_goal_entered(body: Node3D) -> void:
	if body != _player or _won:
		return
	_won = true
	for g in _guards:
		g.active = false
	_hud.cancel_aim()
	call_deferred("_play_ending")


func _on_caught() -> void:
	if _won or _caught_frame == Engine.get_physics_frames():
		return
	_caught_frame = Engine.get_physics_frames()
	_caught_count += 1
	_hud.show_message("Тебя поймали! Пробуем ещё раз.", 2.5)
	if _caught_count == 1:
		call_deferred("_play_caught_scene")
	_hud.cancel_aim()
	_picking = false
	_ammo_normal = AMMO_NORMAL
	_ammo_noise = AMMO_NOISE
	_ammo_stun = AMMO_STUN
	_hud.set_ammo(_ammo_normal, _ammo_noise, _ammo_stun)
	_pitch = -0.35
	if _stage == STAGE_YARD:
		_player.respawn(SPAWN)
		_yaw = PI
		_rig.global_position = SPAWN + Vector3(0.0, 1.5, 0.0)
		for g in _guards:
			g.reset()
		return

	# В кабинете или коридоре.
	_stage = STAGE_OFFICE
	if _has_pouch:
		_player.respawn(CHASE_SPAWN)
		_yaw = -PI * 0.5
		_rig.global_position = CHASE_SPAWN + Vector3(0.0, 1.5, 0.0)
		_reset_chandelier()
		for g in _office_guards:
			g.reset()
			g.wake()
		_hud.set_objective("Беги по коридору к двери! Погоню останови стрелой в люстру")
	else:
		_player.respawn(OFFICE_SPAWN)
		_yaw = PI
		_rig.global_position = OFFICE_SPAWN + Vector3(0.0, 1.5, 0.0)
		for g in _office_guards:
			g.reset()


# ---------- Окружение: ночное небо, луна, туман ----------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.03, 0.05, 0.14)
	sky_mat.sky_horizon_color = Color(0.12, 0.15, 0.30)
	sky_mat.ground_bottom_color = Color(0.02, 0.03, 0.06)
	sky_mat.ground_horizon_color = Color(0.12, 0.15, 0.30)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.40, 0.60)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.13, 0.25)
	env.fog_density = 0.012

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.65, 0.72, 1.0)
	moon.light_energy = 0.9
	moon.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 35.0
	add_child(moon)


# ---------- Мир: двор замка ----------

func _build_world() -> void:
	var stone := Color(0.46, 0.45, 0.50)
	var dark_stone := Color(0.30, 0.30, 0.35)
	var wood := Color(0.40, 0.27, 0.15)
	var roof := Color(0.32, 0.12, 0.10)

	# Земля и мощёный двор (двор только для вида).
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0), Color(0.12, 0.22, 0.12))
	_add_deco(_box_mesh(Vector3(48.0, 0.02, 48.0)), Vector3(0.0, 0.01, 0.0), Color(0.33, 0.32, 0.34))

	# Стены (южная — с воротами).
	_add_box(Vector3(0.0, 3.0, -26.0), Vector3(52.0, 6.0, 1.5), stone)
	_add_box(Vector3(-15.0, 3.0, 26.0), Vector3(22.0, 6.0, 1.5), stone)
	_add_box(Vector3(15.0, 3.0, 26.0), Vector3(22.0, 6.0, 1.5), stone)
	_add_box(Vector3(0.0, 5.5, 26.0), Vector3(8.0, 1.0, 1.5), stone)
	_add_box(Vector3(0.0, 2.5, 26.0), Vector3(8.0, 5.0, 0.8), Color(0.18, 0.13, 0.09))
	_add_box(Vector3(-26.0, 3.0, 0.0), Vector3(1.5, 6.0, 52.0), stone)
	_add_box(Vector3(26.0, 3.0, 0.0), Vector3(1.5, 6.0, 52.0), stone)

	# Угловые башни с крышами.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_cylinder(Vector3(sx * 26.0, 4.5, sz * 26.0), 3.0, 9.0, dark_stone)
			_add_deco(_cyl_mesh(0.0, 3.6, 3.5, 8), Vector3(sx * 26.0, 10.75, sz * 26.0), roof)

	# Донжон шерифа у северной стены.
	_add_box(Vector3(0.0, 5.0, -19.0), Vector3(18.0, 10.0, 8.0), Color(0.40, 0.38, 0.40))
	_add_deco(_box_mesh(Vector3(19.0, 0.8, 9.0)), Vector3(0.0, 10.4, -19.0), dark_stone)
	_add_box(Vector3(0.0, 2.0, -14.9), Vector3(3.2, 4.0, 0.2), Color(0.20, 0.13, 0.08))
	for wx in [-6.0, -2.5, 2.5, 6.0]:
		_add_deco(_box_mesh(Vector3(1.2, 1.6, 0.1)), Vector3(wx, 6.5, -14.94), Color(1.0, 0.80, 0.40), true)

	# Колодец, ящики, бочки.
	_add_cylinder(Vector3(-8.0, 0.5, 4.0), 1.3, 1.0, dark_stone)
	_add_box(Vector3(9.0, 0.6, 7.0), Vector3(1.2, 1.2, 1.2), wood)
	_add_box(Vector3(10.4, 0.6, 7.4), Vector3(1.2, 1.2, 1.2), wood)
	_add_box(Vector3(9.5, 1.8, 7.1), Vector3(1.2, 1.2, 1.2), wood)
	_add_box(Vector3(14.0, 0.6, 2.0), Vector3(1.2, 1.2, 1.2), wood)
	_add_cylinder(Vector3(-6.0, 0.55, 15.0), 0.5, 1.1, wood)
	_add_cylinder(Vector3(-4.8, 0.55, 16.0), 0.5, 1.1, wood)
	_add_cylinder(Vector3(12.0, 0.55, 15.0), 0.5, 1.1, wood)

	# Ступени для тренировки прыжка.
	_add_box(Vector3(-14.0, 0.2, -6.0), Vector3(3.0, 0.4, 3.0), stone)
	_add_box(Vector3(-17.0, 0.4, -6.0), Vector3(3.0, 0.8, 3.0), stone)
	_add_box(Vector3(-20.0, 0.6, -6.0), Vector3(3.0, 1.2, 3.0), stone)

	# Факелы со светом.
	_add_torch(-10.0, 8.0)
	_add_torch(10.0, 8.0)
	_add_torch(-10.0, -8.0)
	_add_torch(10.0, -8.0)

	# Лес за стенами.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(30):
		var a := float(i) / 30.0 * TAU + rng.randf_range(-0.08, 0.08)
		var r := rng.randf_range(40.0, 46.0)
		_add_tree(cos(a) * r, sin(a) * r, rng.randf_range(0.9, 1.4))


func _add_torch(x: float, z: float) -> void:
	_torches.append(Vector3(x, 0.0, z))
	_add_cylinder(Vector3(x, 1.2, z), 0.12, 2.4, Color(0.25, 0.17, 0.10))
	var flame := SphereMesh.new()
	flame.radius = 0.2
	flame.height = 0.4
	_add_deco(flame, Vector3(x, 2.6, z), Color(1.0, 0.60, 0.20), true)
	_add_light_pool(x, z)


# Вместо дорогих источников света: тёплое пятно на земле под факелом (почти бесплатно для телефона).
func _add_light_pool(x: float, z: float) -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 0.62, 0.28, 0.55), Color(1.0, 0.62, 0.28, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(x, 0.06, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _add_tree(x: float, z: float, s: float) -> void:
	var trunk_h := 3.0 * s
	_add_cylinder(Vector3(x, trunk_h * 0.5, z), 0.4 * s, trunk_h, Color(0.30, 0.20, 0.12))
	var crown_h := 6.0 * s
	_add_deco(_cyl_mesh(0.0, 2.4 * s, crown_h, 7), Vector3(x, trunk_h + crown_h * 0.5 - 0.5, z), Color(0.10, 0.28, 0.14))


# ---------- Помощники для построения ----------

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
	return m


func _box_mesh(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


func _cyl_mesh(top_r: float, bottom_r: float, h: float, segments: int = 10) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = h
	cm.radial_segments = segments
	cm.rings = 1
	return cm


func _add_deco(mesh: Mesh, pos: Vector3, color: Color, emissive: bool = false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(color, emissive)
	mi.position = pos
	add_child(mi)


func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.material_override = _material(color)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _add_cylinder(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl_mesh(radius, radius, height)
	mi.material_override = _material(color)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
