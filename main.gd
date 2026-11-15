extends Node3D
# Робин Гуд: Не тот кошелёк. Тестовая сборка 0.1.
# Двор Ноттингемского замка ночью: ходьба, прыжок, присед, камера от третьего лица.

const PlayerScript = preload("res://player.gd")
const HudScript = preload("res://hud.gd")

const LOOK_SENSITIVITY := 0.006
const PITCH_MIN := -1.2
const PITCH_MAX := 0.25

var _player = null
var _hud = null
var _rig: Node3D
var _pitch_node: Node3D
var _yaw: float = 0.0
var _pitch: float = -0.35


func _ready() -> void:
	_build_environment()
	_build_world()
	_spawn_player()
	_build_camera()
	_build_hud()


func _process(delta: float) -> void:
	if _player == null:
		return
	_player.cam_yaw = _yaw
	var target: Vector3 = _player.global_position + Vector3(0.0, 1.5, 0.0)
	_rig.global_position = _rig.global_position.lerp(target, clampf(14.0 * delta, 0.0, 1.0))
	_rig.rotation.y = _yaw
	_pitch_node.rotation.x = _pitch


func _on_look_moved(rel: Vector2) -> void:
	_yaw -= rel.x * LOOK_SENSITIVITY
	_pitch = clampf(_pitch - rel.y * LOOK_SENSITIVITY, PITCH_MIN, PITCH_MAX)


# ---------- Игрок, камера, интерфейс ----------

func _spawn_player() -> void:
	_player = PlayerScript.new()
	_player.position = Vector3(0.0, 0.3, 14.0)
	add_child(_player)


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

	var cam := Camera3D.new()
	cam.near = 0.1
	cam.far = 150.0
	cam.fov = 70.0
	arm.add_child(cam)
	cam.current = true


func _build_hud() -> void:
	_hud = HudScript.new()
	add_child(_hud)
	_hud.connect("look_moved", _on_look_moved)
	_hud.connect("jump_pressed", Callable(_player, "queue_jump"))
	_hud.connect("crouch_changed", Callable(_player, "set_crouch"))
	_player.hud = _hud


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
