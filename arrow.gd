extends Node3D
# Стрела: летит по дуге, на каждом шаге проверяет луч до новой позиции, втыкается в препятствие.
# Тип 0 — обычная, тип 1 — шумовая (на удар слетаются стражники).

signal hit_something(collider, pos: Vector3, kind: int)

const SPEED := 46.0
const GRAVITY := 5.0
const MAX_LIFE := 6.0
const STUCK_LIFE := 8.0

var arrow_type: int = 0

var _vel: Vector3 = Vector3.ZERO
var _stuck: bool = false
var _life: float = 0.0


func setup(start: Vector3, velocity: Vector3, t: int) -> void:
	position = start
	_vel = velocity
	arrow_type = t


func _ready() -> void:
	_build_model()
	_orient()


func _physics_process(delta: float) -> void:
	_life += delta
	if _stuck:
		if _life > STUCK_LIFE:
			queue_free()
		return
	if _life > MAX_LIFE:
		queue_free()
		return

	_vel.y -= GRAVITY * delta
	var from := global_position
	var to := from + _vel * delta
	# Слои: 1 — мир, 4 — стражники (игрок на слое 2 и стрелу не останавливает).
	var query := PhysicsRayQueryParameters3D.create(from, to, 5)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_orient()
		return

	var p: Vector3 = hit["position"]
	var col = hit["collider"]
	global_position = p
	_stuck = true
	_life = 0.0
	hit_something.emit(col, p, arrow_type)
	# В стражнике стрела не торчит: он двигается, и она бы висела в воздухе.
	if col != null and col.is_in_group("guards"):
		queue_free()


func _orient() -> void:
	if _vel.length() < 0.1:
		return
	var d := _vel.normalized()
	if absf(d.dot(Vector3.UP)) > 0.98:
		return
	look_at(global_position + d, Vector3.UP)


func _build_model() -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.018
	shaft.bottom_radius = 0.018
	shaft.height = 0.9
	shaft.radial_segments = 6
	shaft.rings = 1
	_add_part(shaft, Color(0.55, 0.40, 0.22), Vector3(0.0, 0.0, 0.0))

	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.05
	tip.height = 0.16
	tip.radial_segments = 6
	tip.rings = 1
	var tip_col := Color(0.75, 0.78, 0.82) if arrow_type == 0 else Color(0.35, 0.65, 1.0)
	_add_part(tip, tip_col, Vector3(0.0, 0.0, -0.52))

	var fin := BoxMesh.new()
	fin.size = Vector3(0.12, 0.01, 0.16)
	var fin_col := Color(0.9, 0.88, 0.8) if arrow_type == 0 else Color(0.5, 0.8, 1.0)
	_add_part(fin, fin_col, Vector3(0.0, 0.0, 0.38))


func _add_part(mesh: Mesh, color: Color, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if arrow_type == 1:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	mi.position = pos
	# Меши вытянуты вдоль Y, а стрела летит вдоль -Z.
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
