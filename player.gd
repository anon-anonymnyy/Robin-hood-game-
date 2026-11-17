extends CharacterBody3D
# Робин: ходьба, прыжок, присед. Модель собрана из простых форм (заглушка до настоящих 3D-моделей).

const WALK_SPEED := 4.6
const CROUCH_SPEED := 2.0
const JUMP_VELOCITY := 5.2
const GRAVITY := 16.0
const TURN_SPEED := 12.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const RADIUS := 0.35
const LIT_RADIUS := 5.0
const AIM_SPEED := 2.2

var hud = null
var cam_yaw: float = 0.0
var crouching: bool = false
var torch_positions: Array = []
var aiming: bool = false

var _visual: Node3D
var _col: CollisionShape3D
var _capsule: CapsuleShape3D
var _jump_queued: bool = false
var _bow: Node3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1

	_capsule = CapsuleShape3D.new()
	_capsule.radius = RADIUS
	_capsule.height = STAND_HEIGHT
	_col = CollisionShape3D.new()
	_col.shape = _capsule
	_col.position = Vector3(0.0, STAND_HEIGHT * 0.5, 0.0)
	add_child(_col)

	_visual = Node3D.new()
	add_child(_visual)
	_build_model()


func _build_model() -> void:
	var green := Color(0.15, 0.45, 0.20)
	var dark_green := Color(0.10, 0.32, 0.14)
	var skin := Color(0.90, 0.72, 0.58)
	var brown := Color(0.32, 0.20, 0.10)

	var leg := BoxMesh.new()
	leg.size = Vector3(0.18, 0.38, 0.20)
	_part(leg, brown, Vector3(-0.12, 0.19, 0.0))
	_part(leg, brown, Vector3(0.12, 0.19, 0.0))

	var torso := CapsuleMesh.new()
	torso.radius = 0.30
	torso.height = 1.0
	_part(torso, green, Vector3(0.0, 0.82, 0.0))

	var head := SphereMesh.new()
	head.radius = 0.20
	head.height = 0.40
	_part(head, skin, Vector3(0.0, 1.47, 0.0))

	# Нос показывает, куда смотрит Робин (вперёд = минус Z).
	var nose := BoxMesh.new()
	nose.size = Vector3(0.08, 0.08, 0.12)
	_part(nose, Color(0.80, 0.60, 0.46), Vector3(0.0, 1.45, -0.2))

	var brim := CylinderMesh.new()
	brim.top_radius = 0.32
	brim.bottom_radius = 0.32
	brim.height = 0.04
	_part(brim, dark_green, Vector3(0.0, 1.62, 0.0))

	var hat := CylinderMesh.new()
	hat.top_radius = 0.0
	hat.bottom_radius = 0.24
	hat.height = 0.32
	_part(hat, green, Vector3(0.0, 1.78, 0.0))

	var feather := BoxMesh.new()
	feather.size = Vector3(0.04, 0.26, 0.04)
	_part(feather, Color(0.75, 0.20, 0.15), Vector3(0.16, 1.88, 0.0), Vector3(0.0, 0.0, -25.0))

	var quiver := BoxMesh.new()
	quiver.size = Vector3(0.16, 0.5, 0.14)
	_part(quiver, brown, Vector3(0.0, 0.95, 0.3))

	var fletching := BoxMesh.new()
	fletching.size = Vector3(0.12, 0.12, 0.04)
	_part(fletching, Color(0.90, 0.88, 0.80), Vector3(0.0, 1.25, 0.3))

	_build_bow()


# Лук в левой руке: виден только в режиме прицеливания.
func _build_bow() -> void:
	_bow = Node3D.new()
	_bow.position = Vector3(-0.38, 1.0, -0.3)
	_bow.visible = false
	_visual.add_child(_bow)
	var wood := Color(0.42, 0.28, 0.14)
	var limb := BoxMesh.new()
	limb.size = Vector3(0.05, 0.5, 0.05)
	_bow_part(limb, wood, Vector3(0.0, 0.22, 0.0), Vector3(-14.0, 0.0, 0.0))
	_bow_part(limb, wood, Vector3(0.0, -0.22, 0.0), Vector3(14.0, 0.0, 0.0))
	var cord := BoxMesh.new()
	cord.size = Vector3(0.012, 0.86, 0.012)
	_bow_part(cord, Color(0.9, 0.9, 0.85), Vector3(0.0, 0.0, 0.1), Vector3.ZERO)


func _bow_part(mesh: Mesh, color: Color, pos: Vector3, rot_deg: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	_bow.add_child(mi)


func _part(mesh: Mesh, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	_visual.add_child(mi)


func is_lit() -> bool:
	for t in torch_positions:
		var tp: Vector3 = t
		if Vector2(tp.x - global_position.x, tp.z - global_position.z).length() < LIT_RADIUS:
			return true
	return false


# Насколько заметен Робин: на свету и стоя — больше всего, в тени и присев — меньше всего.
func visibility() -> float:
	var v := 1.3 if is_lit() else 0.8
	if crouching:
		v *= 0.55
	return v


# Шум шагов для интерфейса: 0 — тихо, 1 — шаги слышно рядом, 2 — бег слышно издалека.
func noise_level() -> int:
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp < 0.3 or crouching:
		return 0
	if sp < 3.4:
		return 1
	return 2


# Радиус (в метрах), в котором стражник слышит Робина.
func noise_radius() -> float:
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp < 0.3:
		return 0.0
	if crouching:
		return 0.0
	if sp < 3.4:
		return 5.0
	return 11.0


func respawn(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_visual.rotation.y = PI


func queue_jump() -> void:
	_jump_queued = true


func set_crouch(on: bool) -> void:
	crouching = on
	var h := CROUCH_HEIGHT if on else STAND_HEIGHT
	_capsule.height = h
	_col.position.y = h * 0.5


func _process(delta: float) -> void:
	_bow.visible = aiming
	var target_scale := 0.62 if crouching else 1.0
	_visual.scale.y = lerpf(_visual.scale.y, target_scale, clampf(12.0 * delta, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	var mv := Vector2.ZERO
	if hud != null:
		mv = hud.move_vector

	# Направление считаем относительно того, куда повёрнута камера.
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(mv.x, 0.0, mv.y)
	var speed := CROUCH_SPEED if crouching else WALK_SPEED
	if aiming:
		speed = minf(speed, AIM_SPEED)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if is_on_floor():
		if _jump_queued and not crouching:
			velocity.y = JUMP_VELOCITY
		else:
			velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	_jump_queued = false

	move_and_slide()

	if aiming:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, cam_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))
	elif dir.length() > 0.1:
		var target := atan2(-dir.x, -dir.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target, clampf(TURN_SPEED * delta, 0.0, 1.0))

	# Страховка: если вдруг провалились под землю, возвращаемся на старт.
	if global_position.y < -10.0:
		global_position = Vector3(0.0, 0.5, 14.0)
		velocity = Vector3.ZERO
