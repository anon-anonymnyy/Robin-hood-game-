extends "res://main.gd"
# Миссия 2: деревня Локсли. Уилл, амбар сборщика налогов, печать на расписке, выбор «Слава» / «Тень».
# Лук, камера, диалоги и стража берутся из main.gd, здесь только уровень и сюжет.

const StampScript = preload("res://stamp_game.gd")

const M2_SPAWN := Vector3(0.0, 0.3, -30.0)
const GATE_CHECK := Vector3(10.0, 0.3, -3.0)
const WILL_POS := Vector3(-19.5, 0.0, 1.5)
const DESK_POS := Vector3(29.0, 0.0, -5.6)
const COIN_POS := Vector3(29.6, 0.0, -2.0)
const BOARD_POS := Vector3(0.0, 0.0, 2.6)
const WINDOW_POS := Vector3(-20.0, 0.0, -3.2)
const EXIT_Z := 37.0

var _m2: int = 0
var _base_glory: int = 0
var _base_shadow: int = 0
var _stamp = null
var _marian: Node3D = null
var _cur_id: String = ""
var _desk_done: bool = false
var _coins_done: bool = false
var _coins_kept: bool = false
var _awaiting_mode: bool = false
var _ret_mode: String = ""
var _returned: bool = false
var _chase_on: bool = false
var _checkpoint: Vector3 = M2_SPAWN
var _checkpoint_yaw: float = PI
var _exit_area: Area3D = null
var _exit_vis: MeshInstance3D = null


func _ready() -> void:
	var d: Dictionary = SaveScript.load_data()
	_base_glory = int(d.get("m1_glory", 0))
	_base_shadow = int(d.get("m1_shadow", 0))
	_glory = _base_glory
	_shadow = _base_shadow
	_build_environment()
	_build_village()
	_spawn_player()
	_build_camera()
	_build_hud()
	_build_dialogue()
	_build_stamp()
	_spawn_village_guards()
	_build_npcs()
	_build_exit_zone()
	_hud.set_ammo(_ammo_normal, _ammo_noise, _ammo_stun)
	_hud.set_objective("Выслушай Мэриан")
	_start_card("Миссия 2", "Деревня должников", "Локсли. На следующую ночь.", _play_m2_intro)


func _spawn_player() -> void:
	_player = PlayerScript.new()
	_player.torch_positions = _torches
	add_child(_player)
	_player.respawn(M2_SPAWN)


func _build_stamp() -> void:
	_stamp = StampScript.new()
	add_child(_stamp)
	_stamp.finished.connect(_on_stamp_done)


# ---------- Сюжет ----------

func _play_m2_intro() -> void:
	var lines: Array = [
		{"who": "Мэриан", "text": "Вот и Локсли. Всю ночь шли, а ты так ни разу и не спросил, зачем мы сюда пришли."},
		{"who": "Робин", "text": "Я думал, ты ведёшь меня на завтрак."},
		{"who": "Мэриан", "text": "Ты хоть понимаешь, что держишь в руках? Любая бумага с этим оттиском становится законной. Ты сейчас сильнее самого шерифа."},
		{"who": "Робин", "text": "Серьёзно? А почему тогда я пахну сеном и прячусь в бочке?"},
		{"who": "Мэриан", "text": "Потому что ты ей не пользуешься. Здесь сборщик Счёткин отбирает мельницу за долг. Найди мельника Уилла у мельницы на западе. Я пойду с тобой."},
	]
	_dlg.start(lines, _after_m2_intro)


func _after_m2_intro() -> void:
	_hud.reset_touches()
	_hud.set_objective("Найди мельника Уилла у мельницы на западе деревни")
	_hud.show_hint("Подойди к человеку или предмету: слева от кнопки приседа появится золотая кнопка действия. Кнопка «Меню» вверху справа.", 14.0)
	if _marian != null:
		_marian.set_follow(_player)


func _talk_will() -> void:
	var lines: Array = [
		{"who": "Уилл", "text": "Если до заката не заплачу, мельница уйдёт сборщику. Моя мельница! Она ещё дедова."},
		{"who": "Робин", "text": "Где Счёткин держит долговые расписки?"},
		{"who": "Уилл", "text": "В амбаре на востоке. У ворот стража, а сзади есть лаз через огороды. Только тихо: Счёткин считает деньги даже во сне."},
		{"who": "Робин", "text": "Считать — это не страшно. Скоро вернусь с бумагой."},
	]
	_dlg.start(lines, _after_will)


func _after_will() -> void:
	_hud.reset_touches()
	if _marian != null:
		_marian.set_follow(null)
	_m2 = 1
	_checkpoint = GATE_CHECK
	_checkpoint_yaw = -PI * 0.5
	_hud.set_objective("Проберись в амбар на востоке (ворота или огороды сзади) и найди расписку на столе")


func _talk_desk() -> void:
	var lines: Array = [
		{"who": "Робин", "text": "Так... Уилл, Уилл... Вот она! «Мельница за долг: двенадцать золотых»."},
		{"who": "Мэриан", "text": "Я ведь говорила: ставь печать прямо на расписку. Только руку не дрожи."},
		{"who": "Робин", "text": "Я никогда не дрожу. Это у меня такая... вибрация."},
	]
	_dlg.start(lines, _open_stamp)


func _open_stamp() -> void:
	_hud.reset_touches()
	_stamp.start()


func _on_stamp_done() -> void:
	_desk_done = true
	_m2 = 3
	_awaiting_mode = true
	var lines: Array = [
		{"who": "Робин", "text": "Оттиск идеальный. Долг мельника признан недействительным."},
		{"who": "Мэриан", "text": "Теперь расписку нужно вернуть владельцу. Как поступишь?", "choices": [
			{"text": "Громко! Повешу на площади, пусть вся деревня знает.", "effect": "glory", "reply": [
				{"who": "Мэриан", "text": "Деревня будет рада. А стража тоже услышит. Будет жарко."},
			]},
			{"text": "Тихо. Подброшу мельнику в окно.", "effect": "shadow", "reply": [
				{"who": "Мэриан", "text": "Умно. Никто и не узнает, откуда помощь."},
			]},
		]},
	]
	_dlg.start(lines, _after_mode_choice)


func _after_mode_choice() -> void:
	_hud.reset_touches()
	if _ret_mode == "glory":
		_hud.set_objective("Повесь расписку на доске объявлений на площади в центре деревни")
	else:
		_hud.set_objective("Подбрось расписку в окно мельницы на западе")


func _talk_coins() -> void:
	_coins_done = true
	var lines: Array = [
		{"who": "Робин", "text": "Целый сундук налоговых монет. Красивые. Тяжёлые.", "choices": [
			{"text": "Оставить себе. Мне нужны стрелы!", "effect": "coins_take", "reply": [
				{"who": "Мэриан", "text": "Робин... Это деньги этих людей."},
				{"who": "Робин", "text": "Я верну. Когда-нибудь. С процентами."},
			]},
			{"text": "Вернуть деревне. Пусть Уилл раздаст.", "effect": "coins_leave", "reply": [
				{"who": "Мэриан", "text": "Вот теперь ты мне нравишься."},
			]},
		]},
	]
	_dlg.start(lines, _after_dialogue)


func _do_board() -> void:
	_returned = true
	_m2 = 4
	var lines: Array = [
		{"who": "Робин", "text": "Слушайте все! Долг мельника отменён печатью шерифа! Налог отменяется!"},
		{"who": "Крестьянин", "text": "Налог отменён?! Ура Робину!"},
		{"who": "Счёткин", "text": "Двенадцать... тринадцать... Эй! Ты мне мешаешь считать! Я теперь собьюсь!"},
		{"who": "Мэриан", "text": "Стража всё слышала. Беги в лес на юге!"},
	]
	_dlg.start(lines, _begin_glory_chase)


func _begin_glory_chase() -> void:
	_hud.reset_touches()
	_chase_on = true
	_checkpoint = Vector3(0.0, 0.3, 5.5)
	_checkpoint_yaw = PI
	_start_chase_m2()
	if _exit_vis != null:
		_exit_vis.visible = true
	if _exit_area != null:
		_exit_area.monitoring = true
	_hud.set_objective("Беги в лес на юге! Стража в погоне")
	_hud.show_message("Стража разъярена! Беги к зелёной полосе на юге!", 3.0)


func _start_chase_m2() -> void:
	for g in _guards:
		g.relentless = true
		g.chase_speed = 3.6
		g.force_alert()


func _do_window() -> void:
	_returned = true
	_m2 = 4
	var lines: Array = [
		{"who": "Уилл", "text": "Что это? Моя расписка?.. Аннулирована?! Кто-то добрый подбросил!"},
		{"who": "Мэриан", "text": "Тебя никто не видел. Идеально."},
		{"who": "Робин", "text": "Я мастер теней. Ну, или сено в бочке сделало своё дело."},
	]
	_dlg.start(lines, _finish_shadow)


func _finish_shadow() -> void:
	_finish_m2()


func _on_goal_entered(body: Node3D) -> void:
	if body != _player or _won or not _chase_on:
		return
	_won = true
	for g in _guards:
		g.active = false
	_hud.cancel_aim()
	_hud.set_interact("")
	call_deferred("_play_glory_ending")


func _play_glory_ending() -> void:
	var lines: Array = [
		{"who": "Мэриан", "text": "Ты сделал это. Вся деревня знает твоё имя. И шериф тоже."},
		{"who": "Робин", "text": "Знаменитый Робин Гуд! Звучит неплохо. Страшновато, но неплохо."},
	]
	_dlg.start(lines, _finish_m2)


func _finish_m2() -> void:
	_hud.reset_touches()
	_hud.set_interact("")
	_won = true
	for g in _guards:
		g.active = false
	_kill_bonuses()
	var d: Dictionary = SaveScript.load_data()
	d["mission1_done"] = true
	d["mission2_done"] = true
	d["m2_glory"] = _glory - _base_glory
	d["m2_shadow"] = _shadow - _base_shadow
	d["glory"] = _glory
	d["shadow"] = _shadow
	d["coins_kept"] = _coins_kept
	SaveScript.write(d)
	var title := "Загадочный Робин: и шум, и тишина"
	if _glory > _shadow:
		title = "Громкий Робин: о нём говорят в каждой деревне"
	elif _shadow > _glory:
		title = "Робин-Тень: никто не знает, кто помогает"
	var coins := "монеты оставил себе" if _coins_kept else "монеты вернул деревне"
	_hud.set_objective("Миссия 2 завершена")
	_card.show_card("Миссия 2 пройдена", "Слава %d · Тень %d" % [_glory, _shadow], "%s\n%s · %s\nМиссия 3 «Банда» скоро появится." % [title, coins, _kills_text()], [
		{"text": "В главное меню", "cb": _go_menu},
	])


func _on_choice_made(effect: String) -> void:
	super(effect)
	if _awaiting_mode and (effect == "glory" or effect == "shadow"):
		_ret_mode = effect
		_awaiting_mode = false
	elif effect == "coins_take":
		_coins_kept = true
	elif effect == "coins_leave":
		_coins_kept = false


func _play_caught_scene() -> void:
	var lines: Array = [
		{"who": "Счёткин", "text": "Двенадцать... тринадцать... Эй! Ты мне мешаешь считать! Теперь я собьюсь!"},
		{"who": "Робин", "text": "Начнём с единицы, Счёткин. Я подожду."},
	]
	_dlg.start(lines, _after_dialogue)


func _on_caught() -> void:
	if _won or _caught_frame == Engine.get_physics_frames():
		return
	_caught_frame = Engine.get_physics_frames()
	_caught_count += 1
	_hud.show_message("Тебя поймали! Пробуем ещё раз.", 2.5)
	if _caught_count == 1:
		call_deferred("_play_caught_scene")
	_hud.cancel_aim()
	_ammo_normal = AMMO_NORMAL
	_ammo_noise = AMMO_NOISE
	_ammo_stun = AMMO_STUN
	_hud.set_ammo(_ammo_normal, _ammo_noise, _ammo_stun)
	_pitch = -0.35
	_player.respawn(_checkpoint)
	_yaw = _checkpoint_yaw
	_rig.global_position = _checkpoint + Vector3(0.0, 1.5, 0.0)
	for g in _guards:
		g.reset()
	if _chase_on:
		_start_chase_m2()


# ---------- Подсказки-кнопки ----------

func _interacts() -> Array:
	var out: Array = []
	if _m2 == 0:
		out.append({"id": "will", "text": "Поговорить", "pos": WILL_POS})
	if _m2 >= 1 and not _desk_done:
		out.append({"id": "desk", "text": "Расписки", "pos": DESK_POS})
	if _m2 >= 1 and not _coins_done:
		out.append({"id": "coins", "text": "Сундук", "pos": COIN_POS})
	if _ret_mode == "glory" and not _returned and _desk_done:
		out.append({"id": "board", "text": "Повесить", "pos": BOARD_POS})
	if _ret_mode == "shadow" and not _returned and _desk_done:
		out.append({"id": "window", "text": "Подбросить", "pos": WINDOW_POS})
	return out


func _update_stage(_delta: float) -> void:
	if _won:
		return
	var txt := ""
	_cur_id = ""
	if not _dlg.is_active() and not _stamp.is_active():
		var pp: Vector3 = _player.global_position
		for it in _interacts():
			var item: Dictionary = it
			var ip: Vector3 = item["pos"]
			if _flat_dist(pp, ip) < 2.4:
				_cur_id = item["id"]
				txt = item["text"]
				break
	_hud.set_interact(txt)


func _on_interact() -> void:
	if _won or _dlg.is_active() or _stamp.is_active():
		return
	if _cur_id == "will":
		_talk_will()
	elif _cur_id == "desk":
		_talk_desk()
	elif _cur_id == "coins":
		_talk_coins()
	elif _cur_id == "board":
		_do_board()
	elif _cur_id == "window":
		_do_window()


# ---------- Стража и персонажи ----------

func _spawn_village_guards() -> void:
	var routes: Array = [
		[Vector3(16.5, 0.0, -8.5), Vector3(16.5, 0.0, 1.5), Vector3(20.0, 0.0, 1.5), Vector3(20.0, 0.0, -8.5)],
		[Vector3(16.0, 0.0, -9.5), Vector3(30.0, 0.0, -9.5)],
		[Vector3(26.0, 0.0, -1.5), Vector3(26.0, 0.0, -6.5)],
		[Vector3(-6.0, 0.0, -5.0), Vector3(6.0, 0.0, -5.0), Vector3(6.0, 0.0, 8.0), Vector3(-6.0, 0.0, 8.0)],
	]
	for route in routes:
		var first: Vector3 = route[0]
		var g = GuardScript.new()
		g.waypoints = route
		g.player = _player
		g.position = first + Vector3(0.0, 0.3, 0.0)
		add_child(g)
		g.caught.connect(_on_caught)
		_guards.append(g)


func _build_npcs() -> void:
	var will = NpcScript.new()
	will.setup(Color(0.75, 0.7, 0.6), Color(0.92, 0.92, 0.88), "Уилл", 1)
	will.position = WILL_POS
	will.rotation_degrees.y = -90.0
	add_child(will)

	var marian = NpcScript.new()
	marian.setup(Color(0.65, 0.25, 0.45), Color(0.25, 0.15, 0.08), "Мэриан", 2, false)
	marian.position = Vector3(2.0, 0.0, -28.0)
	marian.rotation_degrees.y = 180.0
	add_child(marian)
	_marian = marian


func _build_exit_zone() -> void:
	_exit_vis = MeshInstance3D.new()
	_exit_vis.mesh = _box_mesh(Vector3(30.0, 0.04, 3.0))
	_exit_vis.material_override = _material(Color(0.3, 1.0, 0.4), true)
	_exit_vis.position = Vector3(0.0, 0.04, EXIT_Z)
	_exit_vis.visible = false
	add_child(_exit_vis)

	_exit_area = Area3D.new()
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = 2
	_exit_area.position = Vector3(0.0, 2.0, EXIT_Z)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 4.0, 3.0)
	cs.shape = shape
	_exit_area.add_child(cs)
	_exit_area.monitoring = false
	add_child(_exit_area)
	_exit_area.body_entered.connect(_on_goal_entered)


# ---------- Уровень: деревня Локсли ----------

func _add_house(x: float, z: float, w: float, d: float, wall_col: Color) -> void:
	_add_box(Vector3(x, 1.75, z), Vector3(w, 3.5, d), wall_col)
	_add_deco(_box_mesh(Vector3(w + 0.8, 0.5, d + 0.8)), Vector3(x, 3.75, z), Color(0.36, 0.16, 0.10))
	_add_deco(_box_mesh(Vector3(w * 0.6, 0.5, d * 0.6)), Vector3(x, 4.25, z), Color(0.32, 0.14, 0.09))
	_add_deco(_box_mesh(Vector3(1.0, 1.6, 0.1)), Vector3(x, 0.8, z + d * 0.5 + 0.03), Color(0.22, 0.14, 0.08))
	_add_deco(_box_mesh(Vector3(0.9, 0.9, 0.1)), Vector3(x + w * 0.28, 2.0, z + d * 0.5 + 0.03), Color(1.0, 0.8, 0.4), true)


func _build_village() -> void:
	var wood := Color(0.40, 0.27, 0.15)
	var plaster := Color(0.62, 0.57, 0.48)
	var stone := Color(0.46, 0.45, 0.50)
	var hedge := Color(0.10, 0.25, 0.12)

	# Земля, дорога, площадь.
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(120.0, 1.0, 120.0), Color(0.13, 0.24, 0.12))
	_add_deco(_box_mesh(Vector3(6.0, 0.02, 80.0)), Vector3(0.0, 0.01, 0.0), Color(0.30, 0.24, 0.16))
	_add_deco(_box_mesh(Vector3(70.0, 0.02, 5.0)), Vector3(0.0, 0.012, 0.0), Color(0.30, 0.24, 0.16))
	_add_deco(_cyl_mesh(8.0, 8.0, 0.03, 20), Vector3(0.0, 0.02, 1.0), Color(0.36, 0.34, 0.34))

	# Живая изгородь по краю деревни.
	_add_box(Vector3(0.0, 1.5, -40.0), Vector3(80.0, 3.0, 1.0), hedge)
	_add_box(Vector3(0.0, 1.5, 40.0), Vector3(80.0, 3.0, 1.0), hedge)
	_add_box(Vector3(-40.0, 1.5, 0.0), Vector3(1.0, 3.0, 80.0), hedge)
	_add_box(Vector3(40.0, 1.5, 0.0), Vector3(1.0, 3.0, 80.0), hedge)

	# Дома.
	_add_house(-10.0, -16.0, 6.0, 5.0, plaster)
	_add_house(10.0, -20.0, 5.0, 5.0, plaster)
	_add_house(8.0, 16.0, 6.0, 6.0, plaster)
	_add_house(-14.0, 17.0, 6.0, 5.0, plaster)

	# Мельница на западе: окно, куда подбрасывают расписку, смотрит на восток.
	_add_box(Vector3(-26.0, 3.0, 0.0), Vector3(8.0, 6.0, 8.0), Color(0.55, 0.50, 0.44))
	_add_deco(_cyl_mesh(0.0, 6.0, 3.0, 8), Vector3(-26.0, 7.5, 0.0), Color(0.36, 0.16, 0.10))
	_add_deco(_box_mesh(Vector3(0.1, 2.4, 1.6)), Vector3(-21.95, 1.2, 0.0), Color(0.22, 0.14, 0.08))
	_add_deco(_box_mesh(Vector3(0.1, 1.2, 1.2)), Vector3(-21.95, 2.2, -3.0), Color(1.0, 0.8, 0.4), true)
	_add_cylinder(Vector3(-20.0, 0.9, -5.5), 0.5, 1.8, wood)

	# Колодец и доска объявлений на площади.
	_add_cylinder(Vector3(-3.5, 0.5, -2.5), 1.0, 1.0, stone)
	_add_box(Vector3(0.0, 1.0, 4.4), Vector3(2.4, 2.0, 0.2), wood)
	_add_deco(_box_mesh(Vector3(1.4, 1.0, 0.05)), Vector3(0.0, 1.2, 4.27), Color(0.9, 0.85, 0.7))

	# Двор сборщика налогов: забор с двумя входами (главные ворота и лаз сзади).
	_add_box(Vector3(14.0, 1.2, -8.0), Vector3(0.4, 2.4, 6.0), wood)
	_add_box(Vector3(14.0, 1.2, 1.0), Vector3(0.4, 2.4, 4.0), wood)
	_add_box(Vector3(18.5, 1.2, -11.0), Vector3(9.0, 2.4, 0.4), wood)
	_add_box(Vector3(28.5, 1.2, -11.0), Vector3(7.0, 2.4, 0.4), wood)
	_add_box(Vector3(32.0, 1.2, -4.0), Vector3(0.4, 2.4, 14.0), wood)
	_add_box(Vector3(23.0, 1.2, 3.0), Vector3(18.0, 2.4, 0.4), wood)

	# Амбар: вход с запада.
	_add_box(Vector3(27.5, 2.0, -8.0), Vector3(7.0, 4.0, 0.4), Color(0.45, 0.30, 0.18))
	_add_box(Vector3(27.5, 2.0, 0.0), Vector3(7.0, 4.0, 0.4), Color(0.45, 0.30, 0.18))
	_add_box(Vector3(31.0, 2.0, -4.0), Vector3(0.4, 4.0, 8.0), Color(0.45, 0.30, 0.18))
	_add_box(Vector3(24.0, 2.0, -6.5), Vector3(0.4, 4.0, 3.0), Color(0.45, 0.30, 0.18))
	_add_box(Vector3(24.0, 2.0, -1.5), Vector3(0.4, 4.0, 3.0), Color(0.45, 0.30, 0.18))
	_add_deco(_box_mesh(Vector3(8.4, 0.5, 9.0)), Vector3(27.5, 4.25, -4.0), Color(0.34, 0.15, 0.09))
	_add_deco(_box_mesh(Vector3(5.0, 0.5, 6.0)), Vector3(27.5, 4.75, -4.0), Color(0.30, 0.13, 0.08))
	# Внутри: стол с расписками, сундук с монетами, лампа.
	_add_box(Vector3(29.5, 0.45, -6.8), Vector3(2.4, 0.9, 1.0), Color(0.26, 0.17, 0.10))
	_add_deco(_box_mesh(Vector3(0.7, 0.05, 0.5)), Vector3(29.0, 0.93, -6.8), Color(0.95, 0.9, 0.75), true)
	_add_box(Vector3(30.0, 0.4, -1.3), Vector3(1.2, 0.8, 0.8), wood)
	_add_deco(_box_mesh(Vector3(1.2, 0.08, 0.8)), Vector3(30.0, 0.84, -1.3), Color(1.0, 0.8, 0.2), true)
	_add_deco(_cyl_mesh(0.0, 0.14, 0.28, 6), Vector3(27.5, 3.2, -4.0), Color(1.0, 0.65, 0.2), true)
	_torches.append(Vector3(27.5, 0.0, -4.0))
	_add_warm_light(Vector3(27.5, 3.0, -4.0), 7.0)

	# Факелы: у главных ворот и во дворе.
	_add_torch(12.5, -3.0)
	_add_torch(22.0, -6.0)
	_add_torch(-12.0, 4.0)
	_add_torch(12.0, 4.0)

	# Огороды позади амбара: грядки (низкие, лазом можно проползти).
	for i in range(5):
		_add_deco(_box_mesh(Vector3(10.0, 0.35, 0.8)), Vector3(24.0, 0.18, -14.0 - float(i) * 2.0), Color(0.20, 0.14, 0.08))
		_add_deco(_box_mesh(Vector3(9.0, 0.5, 0.5)), Vector3(24.0, 0.4, -14.0 - float(i) * 2.0), Color(0.15, 0.40, 0.15))
	for t in [-1.0, 1.0]:
		_add_box(Vector3(30.0 * t, 1.0, -24.0), Vector3(1.2, 2.0, 1.2), wood)

	# Лес за деревней.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(34):
		var a := float(i) / 34.0 * TAU + rng.randf_range(-0.08, 0.08)
		var r := rng.randf_range(46.0, 54.0)
		_add_tree(cos(a) * r, sin(a) * r, rng.randf_range(0.9, 1.4))
