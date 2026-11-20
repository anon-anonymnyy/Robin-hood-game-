extends CharacterBody3D
# Персонаж из простых форм с именем над головой. Может идти за Робином (set_follow).

var follow_target: Node3D = null
var follow_speed: float = 4.3
var follow_dist: float = 2.6


func setup(shirt: Color, hat_col: Color, label: String, hat_style: int = 0, blocking: bool = true) -> void:
	collision_layer = 1 if blocking else 0
	collision_mask = 1
	set_physics_process(false)

	var legs := BoxMesh.new()
	legs.size = Vector3(0.42, 0.4, 0.22)
	_part(legs, Color(0.30, 0.22, 0.14), Vector3(0.0, 0.2, 0.0))
	var torso := CapsuleMesh.new()
	torso.radius = 0.30
	torso.height = 1.0
	_part(torso, shirt, Vector3(0.0, 0.82, 0.0))
	var skin := Color(0.90, 0.72, 0.58)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	_part(head, skin, Vector3(0.0, 1.47, 0.0))
	if hat_style == 0:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.24
		cone.height = 0.32
		cone.radial_segments = 8
		cone.rings = 1
		_part(cone, hat_col, Vector3(0.0, 1.74, 0.0))
	elif hat_style == 1:
		var cap := CylinderMesh.new()
		cap.top_radius = 0.22
		cap.bottom_radius = 0.22
		cap.height = 0.14
		cap.radial_segments = 8
		cap.rings = 1
		_part(cap, hat_col, Vector3(0.0, 1.66, 0.0))
	else:
		var hair := BoxMesh.new()
		hair.size = Vector3(0.42, 0.6, 0.16)
		_part(hair, hat_col, Vector3(0.0, 1.42, 0.2))
		var top := SphereMesh.new()
		top.radius = 0.22
		top.height = 0.3
		_part(top, hat_col, Vector3(0.0, 1.6, 0.0))

	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	cs.shape = shape
	cs.position = Vector3(0.0, 0.9, 0.0)
	add_child(cs)

	var tag := Label3D.new()
	tag.text = label
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 96
	tag.pixel_size = 0.005
	tag.outline_size = 24
	tag.position = Vector3(0.0, 2.35, 0.0)
	add_child(tag)


# Идти за целью (Робином); null — остановиться на месте.
func set_follow(t: Node3D) -> void:
	follow_target = t
	set_physics_process(t != null)


func _physics_process(delta: float) -> void:
	if follow_target == null:
		return
	var to: Vector3 = follow_target.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > 16.0:
		# Отстала слишком сильно: догоняет мгновенно, чтобы не потеряться.
		var back := Basis(Vector3.UP, follow_target.rotation.y) * Vector3(1.5, 0.0, 2.0)
		global_position = follow_target.global_position + back
		velocity = Vector3.ZERO
		return
	if d > follow_dist:
		var dir := to / d
		velocity.x = dir.x * follow_speed
		velocity.z = dir.z * follow_speed
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(8.0 * delta, 0.0, 1.0))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		var face := to.normalized() if d > 0.1 else Vector3(0.0, 0.0, -1.0)
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), clampf(5.0 * delta, 0.0, 1.0))
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 16.0 * delta
	move_and_slide()


func _part(mesh: Mesh, color: Color, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
