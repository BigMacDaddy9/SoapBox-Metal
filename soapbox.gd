extends VehicleBody3D

# =========================================================
# SOAPBOX VEHICLE
# =========================================================
# Main driving script for the player's soapbox.
#
# This handles:
# - movement
# - boost
# - missile firing
# - wheel damage / detachment
# - camera control
#
# This pass increases the base pace of the vehicle so the heavier,
# more fully built carts still feel lively during testing.
# =========================================================

@onready var thin_base_visual: MeshInstance3D = get_node_or_null("ThinBaseVisual")
@onready var heavy_base_visual: MeshInstance3D = get_node_or_null("HeavyBaseVisual")

# =========================================================
# BASE DRIVING VALUES
# =========================================================
# Increased from the older values so the vehicle feels faster and
# less bogged down when loaded with parts. 
# honestly, I've mixed up some vars here. push_force seems to do nothing,
# base_push_force is the base speed of the vehicle
# =========================================================
@export var push_force: float = 10.0
@export var base_steer_angle: float = PI / 4.0

@export var base_mass: float = 100.0
@export var base_push_force: float = 150.0
@export var base_wheel_detach_at_damage: float = 1.15
@export var base_steer_angle_default: float = PI / 4.0

# =========================================================
# DAMAGE / WHEEL DETACH TUNING
# =========================================================
@export var wheel_damage_impulse_threshold: float = 8.0
@export var wheel_detach_impulse_threshold: float = 16.0
@export var damage_gain_per_threshold: float = 0.25
@export var wheel_detach_at_damage: float = 1.15
@export var wheel_damage_cooldown: float = 0.18
@export var contacts_to_report: int = 16
@export var handling_damage_cap: float = 0.6

@export var wheel_pop_linear_kick: float = 7.0
@export var wheel_pop_up_kick: float = 2.5
@export var wheel_pop_spin: float = 18.0

@export var min_engine_multiplier_at_full_damage: float = 0.35
@export var min_steer_multiplier_at_full_front_damage: float = 0.45

@export var min_suspension_stiffness_multiplier: float = 0.25
@export var min_suspension_travel_multiplier: float = 0.40

# =========================================================
# BOOST / WEAPONS
# =========================================================
# Boost has been made more dramatic so it feels worth pressing.
# =========================================================
@export var boost_force: float = 170.0
@export var boost_multiplier: float = 1.5
@export var boost_duration: float = 0.65
@export var boost_cooldown: float = 1.5
@export var missile_cooldown: float = 4.0
@export var allow_player_input: bool = true
@export var missile: PackedScene = preload("res://missile.tscn")

# =========================================================
# CAMERA TUNING
# =========================================================
@export var camera_sensitivity: float = 0.005
@export var camera_return_speed: float = 7.0
@export var camera_pitch_min: float = deg_to_rad(-20.0)
@export var camera_pitch_max: float = deg_to_rad(45.0)

signal damage_changed(damage_ratio: float)

# =========================================================
# RUNTIME STATE
# =========================================================
var _last_damage_ratio: float = -1.0
var _boost_timer: float = 0.0
var _boost_cooldown_timer: float = 0.0
var _missile_cooldown_timer: float = 0.0
var _wheels := [] as Array[VehicleWheel3D]
var _detached := {} as Dictionary
var _damage := {} as Dictionary
var _base_stiffness := {} as Dictionary
var _base_travel := {} as Dictionary
var _cooldown_left := 0.0
var _camera_pivot: Node3D = null
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0
var _cam_default_yaw: float = 0.0
var _cam_default_pitch: float = 0.0


# =========================================================
# READY
# =========================================================
func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = contacts_to_report

	_wheels.clear()
	for child in get_children():
		if child is VehicleWheel3D:
			_wheels.append(child)

	for w in _wheels:
		var p := w.get_path()
		_detached[p] = false
		_damage[p] = 0.0
		_base_stiffness[p] = w.suspension_stiffness
		_base_travel[p] = w.suspension_travel

	_camera_pivot = find_child("CameraPivot", true, false) as Node3D

	if _camera_pivot != null:
		_cam_default_yaw = _camera_pivot.rotation.y
		_cam_default_pitch = _camera_pivot.rotation.x
		_cam_yaw = _cam_default_yaw
		_cam_pitch = _cam_default_pitch

	_apply_base_preset()

	if has_node("/root/SBSettings"):
		VehicleBuilder.attach_parts(self, SBSettings.get_sanitized_selected_parts())


# =========================================================
# MAIN PHYSICS LOOP
# =========================================================
func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_boost_timer = maxf(0.0, _boost_timer - delta)
	_boost_cooldown_timer = maxf(0.0, _boost_cooldown_timer - delta)
	_missile_cooldown_timer = maxf(0.0, _missile_cooldown_timer - delta)

	var input_dir: Vector2 = _get_drive_input()

	if allow_player_input and Input.is_action_just_pressed("boost") and _boost_cooldown_timer <= 0.0:
		_boost_timer = boost_duration
		_boost_cooldown_timer = boost_cooldown

	# =====================================================
	# BMD MISSILE SYSTEM
	# =====================================================
	if allow_player_input and Input.is_action_just_pressed("missile") and _missile_cooldown_timer <= 0.0 and missile != null:
		_missile_cooldown_timer = missile_cooldown
		var missile_spawn := get_node_or_null("MissileSpawn") as Node3D
		var tmp_missile := missile.instantiate() as Node3D

		if tmp_missile != null:
			if missile_spawn != null:
				tmp_missile.global_transform = missile_spawn.global_transform
			else:
				tmp_missile.global_transform = global_transform

			get_tree().current_scene.add_child(tmp_missile)

	var engine_mult := _engine_multiplier_from_damage()
	var steer_mult := _steer_multiplier_from_front_damage()

	var final_engine_force: float = input_dir.y * push_force * engine_mult

	# Boost now adds a much more noticeable shove.
	if _boost_timer > 0.0:
		final_engine_force += boost_force * boost_multiplier * engine_mult

	engine_force = final_engine_force
	steering = input_dir.x * base_steer_angle * steer_mult

	if _camera_pivot != null and not Input.is_action_pressed("camera_rotate"):
		var t: float = 1.0 - exp(-camera_return_speed * delta)
		_cam_yaw = lerpf(_cam_yaw, _cam_default_yaw, t)
		_cam_pitch = lerpf(_cam_pitch, _cam_default_pitch, t)
		_camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)

	var r: float = get_damage_ratio()
	if absf(r - _last_damage_ratio) > 0.01:
		_last_damage_ratio = r
		emit_signal("damage_changed", r)


# =========================================================
# EXTERNAL BOOST REQUEST
# =========================================================
func request_boost() -> void:
	if _boost_cooldown_timer <= 0.0:
		_boost_timer = boost_duration
		_boost_cooldown_timer = boost_cooldown


# =========================================================
# COLLISION / DAMAGE INTEGRATION
# =========================================================
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _cooldown_left > 0.0:
		return

	var contact_count: int = state.get_contact_count()
	if contact_count == 0:
		return

	var best_impulse: float = 0.0
	var best_pos_global: Vector3 = Vector3.ZERO
	var best_normal_global: Vector3 = Vector3.UP

	for i: int in range(contact_count):
		var impulse_vec: Vector3 = state.get_contact_impulse(i)
		var impulse_mag: float = impulse_vec.length()

		if impulse_mag > best_impulse:
			best_impulse = impulse_mag
			var local_pos: Vector3 = state.get_contact_local_position(i)
			best_pos_global = global_transform * local_pos
			var local_n: Vector3 = state.get_contact_local_normal(i)
			best_normal_global = global_transform.basis * local_n

	if best_impulse < wheel_damage_impulse_threshold:
		return

	var wheel := _pick_wheel_by_hit_quadrant(best_pos_global)
	if wheel == null:
		return

	var gain_scale: float = clampf(best_impulse / wheel_detach_impulse_threshold, 0.0, 3.0)
	var dmg_gain: float = damage_gain_per_threshold * gain_scale

	_apply_wheel_damage(wheel, dmg_gain, best_pos_global, best_normal_global, best_impulse)
	_cooldown_left = wheel_damage_cooldown


# =========================================================
# HIT QUADRANT -> TARGET WHEEL
# =========================================================
func _pick_wheel_by_hit_quadrant(hit_pos_global: Vector3) -> VehicleWheel3D:
	if _wheels.is_empty():
		return null

	var hit_local: Vector3 = global_transform.affine_inverse() * hit_pos_global
	var hit_is_right: bool = hit_local.x >= 0.0

	var front_z: float = -INF
	var rear_z: float = INF

	for w in _wheels:
		var wl: Vector3 = global_transform.affine_inverse() * w.global_position
		front_z = maxf(front_z, wl.z)
		rear_z = minf(rear_z, wl.z)

	var mid_z: float = (front_z + rear_z) * 0.5
	var hit_is_front: bool = hit_local.z >= mid_z

	return _pick_wheel_by_quadrant_flags(hit_pos_global, hit_is_right, hit_is_front)


func _pick_wheel_by_quadrant_flags(hit_pos_global: Vector3, hit_is_right: bool, hit_is_front: bool) -> VehicleWheel3D:
	var candidates := [] as Array[VehicleWheel3D]
	var front_z: float = -INF
	var rear_z: float = INF

	for w in _wheels:
		var wl: Vector3 = global_transform.affine_inverse() * w.global_position
		front_z = maxf(front_z, wl.z)
		rear_z = minf(rear_z, wl.z)

	var mid_z: float = (front_z + rear_z) * 0.5

	for w in _wheels:
		var p := w.get_path()
		if _detached.get(p, false):
			continue

		var wl: Vector3 = global_transform.affine_inverse() * w.global_position
		var w_is_right: bool = wl.x >= 0.0
		var w_is_front: bool = wl.z >= mid_z

		if w_is_right == hit_is_right and w_is_front == hit_is_front:
			candidates.append(w)

	if candidates.is_empty():
		return null

	var best: VehicleWheel3D = null
	var best_d: float = INF

	for w in candidates:
		var d: float = w.global_position.distance_squared_to(hit_pos_global)
		if d < best_d:
			best_d = d
			best = w

	return best


# =========================================================
# APPLY DAMAGE TO WHEEL
# =========================================================
func _apply_wheel_damage(w: VehicleWheel3D, dmg_gain: float, hit_pos_global: Vector3, hit_normal_global: Vector3, impulse_mag: float) -> void:
	var p := w.get_path()
	var old: float = float(_damage.get(p, 0.0))
	var now: float = clampf(old + dmg_gain, 0.0, wheel_detach_at_damage)
	_damage[p] = now

	var t: float = now / wheel_detach_at_damage
	var stiff_mult: float = lerpf(1.0, 0.85, t)
	var travel_mult: float = lerpf(1.0, 0.9, t)

	w.suspension_stiffness = _base_stiffness[p] * stiff_mult
	w.suspension_travel = _base_travel[p] * travel_mult

	if now >= wheel_detach_at_damage:
		_detach_wheel(w, hit_pos_global, hit_normal_global, impulse_mag)


# =========================================================
# DETACH WHEEL
# =========================================================
func _detach_wheel(w: VehicleWheel3D, hit_pos_global: Vector3, hit_normal_global: Vector3, impulse_mag: float) -> void:
	var p := w.get_path()
	_detached[p] = true

	var mesh := w.get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = false

	w.use_as_steering = false
	w.use_as_traction = false
	w.engine_force = 0.0
	w.wheel_rest_length = 0.0
	w.suspension_travel = 0.0
	w.suspension_stiffness = 0.01
	w.wheel_radius = 0.05

	var loose: RigidBody3D = _make_loose_wheel()
	get_tree().current_scene.add_child(loose)
	loose.global_transform = w.global_transform

	var away: Vector3 = (w.global_position - hit_pos_global).normalized()
	if away == Vector3.ZERO:
		away = hit_normal_global.normalized()

	var kick: Vector3 = away * wheel_pop_linear_kick + Vector3.UP * wheel_pop_up_kick
	var scale: float = clampf(impulse_mag / wheel_detach_impulse_threshold, 1.0, 2.5)

	loose.linear_velocity = linear_velocity + kick * scale
	loose.angular_velocity = Vector3(
		randf_range(-wheel_pop_spin, wheel_pop_spin),
		randf_range(-wheel_pop_spin, wheel_pop_spin),
		randf_range(-wheel_pop_spin, wheel_pop_spin)
	) * scale


# =========================================================
# LOOSE WHEEL DEBRIS BODY
# =========================================================
func _make_loose_wheel() -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.name = "LooseWheel"
	rb.mass = 6.0
	rb.continuous_cd = true

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.7
	cyl.height = 0.1
	shape.shape = cyl
	rb.add_child(shape)

	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.7
	mesh.height = 0.1
	mi.mesh = mesh
	mi.rotation.x = -PI / 2.0
	rb.add_child(mi)

	return rb


# =========================================================
# DAMAGE-BASED HANDLING MODIFIERS
# =========================================================
func _engine_multiplier_from_damage() -> float:
	var sum: float = 0.0
	var count: float = 0.0

	for w in _wheels:
		var p := w.get_path()
		if _detached.get(p, false):
			continue

		sum += minf(float(_damage.get(p, 0.0)), handling_damage_cap)
		count += 1.0

	if count <= 0.0:
		return min_engine_multiplier_at_full_damage

	var avg: float = sum / count
	return lerpf(1.0, min_engine_multiplier_at_full_damage, avg)


func _steer_multiplier_from_front_damage() -> float:
	var front_sum: float = 0.0
	var front_count: float = 0.0

	for w in _wheels:
		var name: String = w.name
		if not name.contains("Front"):
			continue

		var p := w.get_path()
		if _detached.get(p, false):
			continue

		front_sum += minf(float(_damage.get(p, 0.0)), handling_damage_cap)
		front_count += 1.0

	if front_count <= 0.0:
		return min_steer_multiplier_at_full_front_damage

	var avg_front: float = front_sum / front_count
	return lerpf(1.0, min_steer_multiplier_at_full_front_damage, avg_front)


# =========================================================
# INPUT
# =========================================================
func _get_drive_input() -> Vector2:
	return Input.get_vector("move_right", "move_left", "move_back", "move_forward")


func _unhandled_input(event: InputEvent) -> void:
	if _camera_pivot == null:
		return

	if event is InputEventMouseMotion and Input.is_action_pressed("camera_rotate"):
		_cam_yaw -= event.relative.x * camera_sensitivity
		_cam_pitch += event.relative.y * camera_sensitivity
		_cam_pitch = clampf(_cam_pitch, camera_pitch_min, camera_pitch_max)
		_camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


# =========================================================
# HUD QUERY HELPERS
# =========================================================
func get_damage_ratio() -> float:
	var total: float = 0.0
	var count: float = 0.0

	for w in _wheels:
		var p := w.get_path()
		count += 1.0

		if bool(_detached.get(p, false)):
			total += 1.0
		else:
			var d: float = float(_damage.get(p, 0.0))
			var ratio: float = 0.0
			if wheel_detach_at_damage > 0.0:
				ratio = clampf(d / wheel_detach_at_damage, 0.0, 1.0)
			total += ratio

	if count <= 0.0:
		return 0.0

	return clampf(total / count, 0.0, 1.0)


func get_wheel_damage_ratio_by_name(wheel_name: String) -> float:
	for w in _wheels:
		if w.name == wheel_name:
			var p := w.get_path()
			if bool(_detached.get(p, false)):
				return 1.0

			var d: float = float(_damage.get(p, 0.0))
			if wheel_detach_at_damage <= 0.0:
				return 0.0

			return clampf(d / wheel_detach_at_damage, 0.0, 1.0)

	return 0.0


func is_wheel_detached_by_name(wheel_name: String) -> bool:
	for w in _wheels:
		if w.name == wheel_name:
			var p := w.get_path()
			return bool(_detached.get(p, false))
	return false


# =========================================================
# APPLY BASE PRESET
# =========================================================
func _apply_base_preset() -> void:
	if thin_base_visual:
		thin_base_visual.visible = false
	if heavy_base_visual:
		heavy_base_visual.visible = false

	mass = base_mass
	push_force = base_push_force
	wheel_detach_at_damage = base_wheel_detach_at_damage
	base_steer_angle = base_steer_angle_default

	if not has_node("/root/SBSettings"):
		return

	var preset: Dictionary = SBSettings.get_current_base()
	var selected: String = SBSettings.selected_base

	mass = float(preset["mass"])
	push_force = base_push_force * float(preset["push_force_mult"])
	wheel_detach_at_damage = base_wheel_detach_at_damage * float(preset["durability_mult"])
	base_steer_angle = base_steer_angle_default * float(preset["steer_mult"])

	VehicleBuilder.apply_base_visuals(self, selected)
