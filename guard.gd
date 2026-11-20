extends CharacterBody3D
# Стражник: ходит по маршруту, видит конусом, копит подозрение, при полном подозрении гонится за Робином.

signal caught

enum State { PATROL, LOOK, ALERT }

const VIEW_DISTANCE := 12.0      # дальность зрения при средней заметности Робина
const VIEW_HALF_ANGLE := 40.0    # половина угла обзора, градусы
const CONE_SHOW_RADIUS := 10.0   # размер конуса на земле (только для показа)
const PATROL_SPEED := 1.8
const CHASE_SPEED := 5.0
const GRAVITY := 16.0
const STEP_HEIGHT := 0.45
const ALERT_RADIUS := 16.0
const WAIT_TIME := 1.4
const SUSPICION_DECAY := 0.35
const GIVE_UP_TIME := 4.0
const CATCH_DISTANCE := 1.2
const NEAR_SENSE := 1.6          # вплотную стражник замечает Робина и без взгляда

var player = null
var dead: bool = false           # убит стрелой
var asleep: bool = false         # спит: просыпается от шума рядом
var chase_speed: float = 5.0     # скорость погони
var relentless: bool = false     # в тревоге всегда знает, где Робин (для сценарной погони)
var waypoints: Array = []
var active: bool = true
var suspicion: float = 0.0
var state: int = State.PATROL

var _yaw: float = 0.0
var _body: Node3D
var _cone_mat: StandardMaterial3D
var _icon: Label3D
var _cone: MeshInstance3D
var _wp_index: int = 0
var _wait: float = 0.0
var _lost_timer: float = 0.0
var _last_seen: Vector3 = Vector3.ZERO
var _start_pos: Vector3 = Vector3.ZERO
var _caught_sent: bool = false
var _steer_sign: float = 1.0
var _steer_dir: Vector3 = Vector3.ZERO
var _steer_t: float = 0.0
var _investigate_t: float = 0.0
var _stun_t: float = 0.0
var _start_asleep: bool = false
var _corpse_alarmed: bool = false
var _corpse_pos: Vector3 = Vector3.ZERO
var _fall_tw: Tween = null


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	_start_pos = position
	_start_asleep = asleep
	add_to_group("guards")
	floor_snap_length = 0.5

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = capsule
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

	_body = Node3D.new()
	add_child(_body)
	_build_model()
	_build_cone()

	_icon = Label3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.font_size = 128
	_icon.pixel_size = 0.006
	_icon.outline_size = 32
	_icon.position = Vector3(0.0, 2.7, 0.0)
	_icon.text = ""
	add_child(_icon)

	_wp_index = 1 % maxi(waypoints.size(), 1)
	_face_first_leg()
	_body.rotation.y = _yaw


func reset() -> void:
	if _fall_tw != null and _fall_tw.is_valid():
		_fall_tw.kill()
	dead = false
	_corpse_alarmed = false
	collision_layer = 4
	_body.rotation.x = 0.0
	position = _start_pos
	velocity = Vector3.ZERO
	suspicion = 0.0
	state = State.PATROL
	_lost_timer = 0.0
	_wait = 0.0
	_caught_sent = false
	_steer_t = 0.0
	_investigate_t = 0.0
	_stun_t = 0.0
	asleep = _start_asleep
	_wp_index = 1 % maxi(waypoints.size(), 1)
	_face_first_leg()


func _face_first_leg() -> void:
	if waypoints.size() >= 2:
		var a: Vector3 = waypoints[0]
		var b: Vector3 = waypoints[1]
		var d := b - a
		_yaw = atan2(-d.x, -d.z)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if player == null or not active:
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		_update_visuals()
		return

	if _stun_t > 0.0:
		_stun_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		_update_visuals()
		if _stun_t <= 0.0:
			# Пришёл в себя: сразу смотрит в сторону стрелка.
			state = State.PATROL
			suspicion = 0.0 if asleep else 0.6
			_lost_timer = 0.0
			_last_seen = player.global_position
		return

	if asleep:
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		_update_visuals()
		var sx: float = player.global_position.x - global_position.x
		var sz: float = player.global_position.z - global_position.z
		if sqrt(sx * sx + sz * sz) < player.noise_radius() * 0.5:
			wake()
		return

	# Заметил тело убитого товарища: решает, что тут Робин, и поднимает тревогу.
	if state != State.ALERT and not _corpse_alarmed and _sees_corpse():
		_corpse_alarmed = true
		suspicion = 1.0
		_last_seen = _corpse_pos

	var rate := _detect()
	var heard := _hear()
	if rate > 0.0:
		suspicion = minf(suspicion + rate * delta, 1.0)
		_last_seen = player.global_position
		_lost_timer = 0.0
	elif heard > 0.0 and state != State.ALERT:
		# Только слышит: идёт проверять шум, но тревогу поднимает лишь увидев Робина.
		_last_seen = player.global_position
		suspicion = maxf(suspicion, minf(suspicion + heard * delta, 0.9))
		_lost_timer = 0.0
		_investigate_t = maxf(_investigate_t, 2.5)
	else:
		_lost_timer += delta
		if state != State.ALERT and _lost_timer > 0.6 and _investigate_t <= 0.0:
			suspicion = maxf(suspicion - SUSPICION_DECAY * delta, 0.0)

	_investigate_t = maxf(_investigate_t - delta, 0.0)

	if state == State.ALERT:
		if relentless:
			_lost_timer = 0.0
			_last_seen = player.global_position
		if _lost_timer > GIVE_UP_TIME:
			state = State.PATROL
			suspicion = 0.2
	elif suspicion >= 1.0:
		state = State.ALERT
		_lost_timer = 0.0
		_alert_neighbors()
	elif state == State.PATROL and suspicion > 0.25:
		state = State.LOOK
	elif state == State.LOOK and suspicion <= 0.05:
		state = State.PATROL

	var move_dir := Vector3.ZERO
	if state == State.PATROL:
		move_dir = _patrol_step(delta)
	elif state == State.LOOK:
		var look: Vector3 = _last_seen - global_position
		look.y = 0.0
		if look.length() > 0.1:
			_turn_to(look, 5.0, delta)
		# Услышал крик товарища: идёт проверять место, где Робина заметили.
		if _investigate_t > 0.0 and look.length() > 1.5:
			move_dir = _steer(look.normalized(), delta)
	else:
		var chase: Vector3 = _last_seen - global_position
		chase.y = 0.0
		if chase.length() > 0.5:
			move_dir = _steer(chase.normalized(), delta)
			_turn_to(chase, 8.0, delta)

	if state == State.ALERT and not _caught_sent:
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() < CATCH_DISTANCE:
			_caught_sent = true
			caught.emit()
			return

	var speed := chase_speed if state == State.ALERT else (2.4 if _investigate_t > 0.0 else PATROL_SPEED)
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	_try_step_up(delta)
	_apply_gravity(delta)
	move_and_slide()
	_update_visuals()


# Другие стражники рядом слышат крик и идут проверять место, где Робина заметили.
func hear(pos: Vector3) -> void:
	if asleep or dead:
		return
	_last_seen = pos
	suspicion = maxf(suspicion, 0.8)
	_investigate_t = 4.0


# Стрела убила стражника: он падает и больше не двигается.
func kill() -> void:
	if dead:
		return
	dead = true
	asleep = false
	state = State.PATROL
	suspicion = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	_cone.visible = false
	_icon.text = "x_x"
	_icon.modulate = Color(0.8, 0.8, 0.8)
	_fall_tw = create_tween()
	_fall_tw.tween_property(_body, "rotation:x", -PI * 0.5, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


# Видит ли стражник тело убитого (в конусе обзора, без стен между ними).
func _sees_corpse() -> bool:
	var eye := global_position + Vector3(0.0, 1.5, 0.0)
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	for n in get_tree().get_nodes_in_group("guards"):
		var o = n
		if o == self or not o.dead:
			continue
		var tp: Vector3 = o.global_position + Vector3(0.0, 0.3, 0.0)
		var flat := Vector3(tp.x - eye.x, 0.0, tp.z - eye.z)
		var d := flat.length()
		if d > 9.0 or d < 0.1:
			continue
		if d > NEAR_SENSE and fwd.dot(flat / d) < cos(deg_to_rad(VIEW_HALF_ANGLE)):
			continue
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, tp, 1))
		if hit.is_empty():
			_corpse_pos = o.global_position
			return true
	return false


# Сценарная тревога: стражник сразу знает, где Робин, и бросается в погоню.
func force_alert() -> void:
	if dead:
		return
	asleep = false
	_stun_t = 0.0
	state = State.ALERT
	suspicion = 1.0
	_lost_timer = 0.0
	if player != null:
		_last_seen = player.global_position


# Просыпается и сразу бросается в погоню.
func wake() -> void:
	if not asleep or dead:
		return
	asleep = false
	state = State.ALERT
	suspicion = 1.0
	_lost_timer = 0.0
	_last_seen = player.global_position
	_alert_neighbors()


# Стрела попала в стражника: он оглушён на 5 секунд, ничего не видит и не слышит.
func stun() -> void:
	if dead:
		return
	_stun_t = 5.0
	state = State.PATROL
	suspicion = 0.0
	velocity = Vector3.ZERO


func _alert_neighbors() -> void:
	for n in get_tree().get_nodes_in_group("guards"):
		var other = n
		if other == self:
			continue
		var d: float = other.global_position.distance_to(global_position)
		if d < ALERT_RADIUS and other.state != State.ALERT and not other.dead:
			other.hear(_last_seen)


# Путь свободен или упирается в низкую ступеньку, на которую можно подняться.
func _blocked(motion: Vector3) -> bool:
	if not test_move(global_transform, motion):
		return false
	var up := Vector3(0.0, STEP_HEIGHT, 0.0)
	if not test_move(global_transform, up) and not test_move(global_transform.translated(up), motion.normalized() * 0.3):
		return false
	return true


# Обходит препятствия (бочки, ящики): если прямо идти нельзя, отклоняется в сторону.
func _steer(dir: Vector3, delta: float) -> Vector3:
	# Выбранный обход держим полсекунды, чтобы стражник не метался у бочек.
	if _steer_t > 0.0:
		_steer_t -= delta
		if not _blocked(_steer_dir * 0.8):
			return _steer_dir
		_steer_t = 0.0
	if not _blocked(dir * 0.8):
		return dir
	for k in [0.5, 1.0, 1.5, 2.2]:
		var ang: float = k * _steer_sign
		var d := dir.rotated(Vector3.UP, ang)
		if not _blocked(d * 0.8):
			_steer_dir = d
			_steer_t = 0.5
			return d
		d = dir.rotated(Vector3.UP, -ang)
		if not _blocked(d * 0.8):
			_steer_sign = -_steer_sign
			_steer_dir = d
			_steer_t = 0.5
			return d
	return Vector3.ZERO


# Поднимается на ступеньки высотой до STEP_HEIGHT.
func _try_step_up(delta: float) -> void:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.001 or not is_on_floor():
		return
	if test_move(global_transform, motion):
		var up := Vector3(0.0, STEP_HEIGHT, 0.0)
		if not test_move(global_transform, up) and not test_move(global_transform.translated(up), motion):
			var n := motion.normalized() * 0.15
			if not test_move(global_transform.translated(up), n):
				global_position += up + n
			else:
				global_position += up


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta


func _turn_to(dir: Vector3, turn_speed: float, delta: float) -> void:
	var target := atan2(-dir.x, -dir.z)
	_yaw = lerp_angle(_yaw, target, clampf(turn_speed * delta, 0.0, 1.0))


# Возвращает направление шага (нулевой вектор, пока стражник ждёт или разворачивается).
func _patrol_step(delta: float) -> Vector3:
	if waypoints.size() < 2:
		return Vector3.ZERO
	var wp: Vector3 = waypoints[_wp_index]
	var d: Vector3 = wp - global_position
	d.y = 0.0
	if d.length() < 0.5:
		_wait += delta
		if _wait >= WAIT_TIME:
			_wait = 0.0
			_wp_index = (_wp_index + 1) % waypoints.size()
		return Vector3.ZERO
	_wait = 0.0
	_turn_to(d, 4.0, delta)
	var target := atan2(-d.x, -d.z)
	if absf(angle_difference(_yaw, target)) > 0.6:
		return Vector3.ZERO
	return _steer(d.normalized(), delta)


# Слух: чем ближе и громче шаги Робина, тем быстрее растёт подозрение (от 0.4 до 1.6 в секунду).
func _hear() -> float:
	var r: float = player.noise_radius()
	if r <= 0.0:
		return 0.0
	var dx: float = player.global_position.x - global_position.x
	var dz: float = player.global_position.z - global_position.z
	var dist := sqrt(dx * dx + dz * dz)
	if dist > r:
		return 0.0
	return lerpf(0.4, 1.6, clampf(1.0 - dist / r, 0.0, 1.0))


# Скорость набора подозрения: 0 — не видит, иначе от 0.5 (далеко) до 2.2 (вплотную) в секунду.
func _detect() -> float:
	var eye := global_position + Vector3(0.0, 1.5, 0.0)
	var crouched: bool = player.crouching
	var target: Vector3 = player.global_position + Vector3(0.0, 0.7 if crouched else 1.2, 0.0)
	var flat := Vector3(target.x - eye.x, 0.0, target.z - eye.z)
	var dist := flat.length()
	if dist < 0.01:
		return 2.2
	var vis: float = player.visibility()
	var eff := VIEW_DISTANCE * vis
	if dist > eff and dist > NEAR_SENSE:
		return 0.0
	if dist > NEAR_SENSE:
		var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		if fwd.dot(flat / dist) < cos(deg_to_rad(VIEW_HALF_ANGLE)):
			return 0.0
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return 0.0
	return lerpf(0.5, 2.2, clampf(1.0 - dist / eff, 0.0, 1.0))


func _update_visuals() -> void:
	_body.rotation.y = _yaw
	var col := Color(1.0, 0.92, 0.35, 0.16)
	if state == State.ALERT:
		col = Color(1.0, 0.15, 0.1, 0.30)
	elif suspicion > 0.02:
		col = col.lerp(Color(1.0, 0.45, 0.1, 0.26), clampf(suspicion, 0.0, 1.0))
	_cone_mat.albedo_color = col
	_cone.visible = _stun_t <= 0.0 and not asleep

	# Конус сжимается, когда Робин в тени или присел: показывает реальную дальность зрения.
	if player != null:
		var vis: float = player.visibility()
		var k := VIEW_DISTANCE * vis / CONE_SHOW_RADIUS
		_cone.scale = _cone.scale.lerp(Vector3(k, 1.0, k), 0.2)

	var t := ""
	if asleep:
		t = "Zzz"
		_icon.modulate = Color(0.7, 0.85, 1.0)
	elif _stun_t > 0.0:
		t = "Ой!"
		_icon.modulate = Color(0.6, 0.85, 1.0)
	elif state == State.ALERT:
		t = "!"
		_icon.modulate = Color(1.0, 0.2, 0.15)
	elif state == State.LOOK:
		t = "?"
		_icon.modulate = Color(1.0, 0.9, 0.3)
	if _icon.text != t:
		_icon.text = t


# ---------- Внешний вид ----------

func _build_cone() -> void:
	var half := deg_to_rad(VIEW_HALF_ANGLE)
	var steps := 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(steps):
		var a0 := -half + 2.0 * half * float(i) / float(steps)
		var a1 := -half + 2.0 * half * float(i + 1) / float(steps)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0) * CONE_SHOW_RADIUS, 0.0, -cos(a0) * CONE_SHOW_RADIUS))
		st.add_vertex(Vector3(sin(a1) * CONE_SHOW_RADIUS, 0.0, -cos(a1) * CONE_SHOW_RADIUS))
	var mesh := st.commit()

	_cone_mat = StandardMaterial3D.new()
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.albedo_color = Color(1.0, 0.92, 0.35, 0.16)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _cone_mat
	mi.position = Vector3(0.0, 0.09, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)
	_cone = mi


func _build_model() -> void:
	var steel := Color(0.50, 0.52, 0.56)
	var tabard := Color(0.55, 0.14, 0.12)
	var skin := Color(0.88, 0.70, 0.56)
	var wood := Color(0.35, 0.24, 0.13)

	var leg := BoxMesh.new()
	leg.size = Vector3(0.2, 0.45, 0.22)
	_part(leg, steel, Vector3(-0.13, 0.22, 0.0))
	_part(leg, steel, Vector3(0.13, 0.22, 0.0))

	var torso := CapsuleMesh.new()
	torso.radius = 0.32
	torso.height = 1.05
	_part(torso, tabard, Vector3(0.0, 0.92, 0.0))

	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	_part(head, skin, Vector3(0.0, 1.55, 0.0))

	# Нос показывает, куда смотрит стражник (вперёд = минус Z).
	var nose := BoxMesh.new()
	nose.size = Vector3(0.08, 0.08, 0.12)
	_part(nose, Color(0.78, 0.58, 0.45), Vector3(0.0, 1.53, -0.2))

	var helmet := SphereMesh.new()
	helmet.radius = 0.23
	helmet.height = 0.3
	_part(helmet, steel, Vector3(0.0, 1.66, 0.0))

	var spear := CylinderMesh.new()
	spear.top_radius = 0.025
	spear.bottom_radius = 0.025
	spear.height = 2.3
	_part(spear, wood, Vector3(0.42, 1.15, 0.0))

	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.07
	tip.height = 0.25
	_part(tip, steel, Vector3(0.42, 2.42, 0.0))


func _part(mesh: Mesh, color: Color, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	_body.add_child(mi)
