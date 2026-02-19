extends VehicleBody3D

@export var push_force: float = 100.0
@export var base_steer_angle: float = PI / 4.0

# --- Impact → damage tuning ---
@export var wheel_damage_impulse_threshold: float = 8.0     # ignore tiny bumps
@export var wheel_detach_impulse_threshold: float = 16.0    # used to scale damage gain
@export var damage_gain_per_threshold: float = 0.25         # damage added per "threshold-sized" hit
@export var wheel_detach_at_damage: float = 1.15
@export var wheel_damage_cooldown: float = 0.18             # prevents multi-hit spam per frame
@export var contacts_to_report: int = 16
@export var handling_damage_cap: float = 0.6  # up to this affects handling; beyond this mostly threatens detachment

# --- Pop-off feel (wheels) ---
@export var wheel_pop_linear_kick: float = 7.0
@export var wheel_pop_up_kick: float = 2.5
@export var wheel_pop_spin: float = 18.0

# --- Progressive handling degradation ---
@export var min_engine_multiplier_at_full_damage: float = 0.35
@export var min_steer_multiplier_at_full_front_damage: float = 0.45

# Optional: how much “suspension collapse” we apply as damage rises
@export var min_suspension_stiffness_multiplier: float = 0.25
@export var min_suspension_travel_multiplier: float = 0.40

# --- Bumpers (protect wheels) ---
@export var bumper_damage_impulse_threshold: float = 6.0
@export var bumper_detach_impulse_threshold: float = 14.0
@export var bumper_damage_gain_per_threshold: float = 0.22
@export var bumper_detach_at_damage: float = 1.0

# While bumper is still attached on that end, reduce wheel damage from hits on that end
@export var wheel_damage_multiplier_with_bumper: float = 0.35

# --- Pop-off feel (bumpers) ---
@export var bumper_pop_linear_kick: float = 8.0
@export var bumper_pop_up_kick: float = 2.0
@export var bumper_pop_spin: float = 12.0

# --- Boost ---
@export var boost_force: float = 100.0
@export var boost_multiplier: float = 1.5
@export var boost_duration: float = 0.4
@export var boost_cooldown: float = 1.5
@export var allow_player_input: bool = true

# --- Camera Rotation ---
@export var camera_sensitivity: float = 0.005
@export var camera_return_speed: float = 7.0
@export var camera_pitch_min: float = deg_to_rad(-20.0)
@export var camera_pitch_max: float = deg_to_rad(45.0)

signal damage_changed(damage_ratio: float)

var _last_damage_ratio: float = -1.0

var _boost_timer: float = 0.0
var _boost_cooldown_timer: float = 0.0

var _wheels := [] as Array[VehicleWheel3D]
var _detached := {} as Dictionary      # NodePath -> bool
var _damage := {} as Dictionary        # NodePath -> float (0..1)

var _front_bumper: Node3D
var _back_bumper: Node3D

var _bumper_detached := {"front": false, "back": false} as Dictionary
var _bumper_damage := {"front": 0.0, "back": 0.0} as Dictionary

# cache “healthy” baseline wheel settings so we can scale them down progressively
var _base_stiffness := {} as Dictionary # NodePath -> float
var _base_travel := {} as Dictionary   # NodePath -> float

var _cooldown_left := 0.0

var _camera_pivot: Node3D = null
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0
var _cam_default_yaw: float = 0.0
var _cam_default_pitch: float = 0.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = contacts_to_report

	_wheels = [
		$RightFrontWheel,
		$LeftFrontWheel,
		$RightBackWheel,
		$LeftBackWheel
	]

	for w in _wheels:
		var p := w.get_path()
		_detached[p] = false
		_damage[p] = 0.0
		_base_stiffness[p] = w.suspension_stiffness
		_base_travel[p] = w.suspension_travel

	_front_bumper = get_node_or_null("FrontBumper") as Node3D
	_back_bumper = get_node_or_null("BackBumper") as Node3D


	_camera_pivot = find_child("CameraPivot", true, false) as Node3D

	# Only set up camera vars if this instance actually has a camera pivot
	if _camera_pivot != null:
		_cam_default_yaw = _camera_pivot.rotation.y
		_cam_default_pitch = _camera_pivot.rotation.x

		_cam_yaw = _cam_default_yaw
		_cam_pitch = _cam_default_pitch



func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)

	_boost_timer = maxf(0.0, _boost_timer - delta)
	_boost_cooldown_timer = maxf(0.0, _boost_cooldown_timer - delta)

	var input_dir: Vector2 = _get_drive_input()

	# Start boost (for player only)
	if allow_player_input and Input.is_action_just_pressed("boost") and _boost_cooldown_timer <= 0.0:
		_boost_timer = boost_duration
		_boost_cooldown_timer = boost_cooldown


	var engine_mult := _engine_multiplier_from_damage()
	var steer_mult := _steer_multiplier_from_front_damage()

	var final_engine_force: float = input_dir.y * push_force * engine_mult

	# Apply dramatic boost
	if _boost_timer > 0.0:
		final_engine_force += boost_force * boost_multiplier * engine_mult

	engine_force = final_engine_force
	steering = input_dir.x * base_steer_angle * steer_mult

	# Camera: only if this instance has a pivot (player car will, AI might not)
	if _camera_pivot != null and not Input.is_action_pressed("camera_rotate"):
		var t: float = 1.0 - exp(-camera_return_speed * delta)
		_cam_yaw = lerp(_cam_yaw, _cam_default_yaw, t)
		_cam_pitch = lerp(_cam_pitch, _cam_default_pitch, t)
		_camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)

	# --- Damage HUD update ---
	var r: float = get_damage_ratio()
	if absf(r - _last_damage_ratio) > 0.01:
		_last_damage_ratio = r
		emit_signal("damage_changed", r)

func request_boost() -> void:
	# Allows AI (or other scripts) to trigger boost without player input
	if _boost_cooldown_timer <= 0.0:
		_boost_timer = boost_duration
		_boost_cooldown_timer = boost_cooldown


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _cooldown_left > 0.0:
		return

	var contact_count := state.get_contact_count()
	if contact_count == 0:
		return

	# Find strongest impact this physics step
	var best_impulse := 0.0
	var best_pos_global := Vector3.ZERO
	var best_normal_global := Vector3.UP

	for i in range(contact_count):
		var impulse_vec := state.get_contact_impulse(i)
		var impulse_mag := impulse_vec.length()

		if impulse_mag > best_impulse:
			best_impulse = impulse_mag

			var local_pos := state.get_contact_local_position(i)
			best_pos_global = global_transform * local_pos

			var local_n := state.get_contact_local_normal(i)
			best_normal_global = global_transform.basis * local_n

	# Ignore tiny bumps
	if best_impulse < wheel_damage_impulse_threshold:
		return

	# Determine whether hit is front or back in LOCAL space
	var hit_local := global_transform.affine_inverse() * best_pos_global
	var hit_is_front := hit_local.z <= 0.0

	# If bumper exists on that end and not detached, damage bumper first and soften wheel damage
	var wheel_damage_mult: float = 1.0

	if hit_is_front and _front_bumper != null and not bool(_bumper_detached["front"]):
		if best_impulse >= bumper_damage_impulse_threshold:
			_apply_bumper_damage("front", best_impulse, best_pos_global, best_normal_global)
		wheel_damage_mult = wheel_damage_multiplier_with_bumper
	elif (not hit_is_front) and _back_bumper != null and not bool(_bumper_detached["back"]):
		if best_impulse >= bumper_damage_impulse_threshold:
			_apply_bumper_damage("back", best_impulse, best_pos_global, best_normal_global)
		wheel_damage_mult = wheel_damage_multiplier_with_bumper


	# Choose wheel ONLY on the side/quadrant of the hit
	var wheel := _pick_wheel_by_hit_quadrant(best_pos_global)
	if wheel == null:
		return

	# Convert impulse → damage gain
	var gain_scale := clampf(best_impulse / wheel_detach_impulse_threshold, 0.0, 3.0)
	var dmg_gain := damage_gain_per_threshold * gain_scale * wheel_damage_mult

	_apply_wheel_damage(wheel, dmg_gain, best_pos_global, best_normal_global, best_impulse)
	_cooldown_left = wheel_damage_cooldown

func _pick_wheel_by_hit_quadrant(hit_pos_global: Vector3) -> VehicleWheel3D:
	# Convert hit position to local space of the VehicleBody
	var hit_local: Vector3 = global_transform.affine_inverse() * hit_pos_global

	# Left/right from local X (this is stable)
	var hit_is_right: bool = hit_local.x >= 0.0

	# --- Determine what "front" means in *this* scene ---
	# Compute average local Z of front wheels and back wheels from their node names.
	var front_z_sum: float = 0.0
	var front_n: int = 0
	var back_z_sum: float = 0.0
	var back_n: int = 0

	for w in _wheels:
		var wl: Vector3 = global_transform.affine_inverse() * w.global_position
		if w.name.contains("Front"):
			front_z_sum += wl.z
			front_n += 1
		elif w.name.contains("Back"):
			back_z_sum += wl.z
			back_n += 1

	# Fallback if naming ever changes
	if front_n == 0 or back_n == 0:
		# Old behavior fallback
		var hit_is_front_fallback: bool = hit_local.z <= 0.0
		return _pick_wheel_by_quadrant_flags(hit_pos_global, hit_is_right, hit_is_front_fallback)

	var front_z_avg: float = front_z_sum / float(front_n)
	var back_z_avg: float = back_z_sum / float(back_n)

	# If front wheels have higher Z than back wheels, then "front" is +Z, otherwise "front" is -Z.
	var front_is_positive_z: bool = front_z_avg > back_z_avg

	# Decide if hit is on the "front half" by comparing hit z to midpoint between front/back averages.
	var mid_z: float = (front_z_avg + back_z_avg) * 0.5
	var hit_is_front: bool = (hit_local.z >= mid_z) if front_is_positive_z else (hit_local.z <= mid_z)

	return _pick_wheel_by_quadrant_flags(hit_pos_global, hit_is_right, hit_is_front)


func _pick_wheel_by_quadrant_flags(hit_pos_global: Vector3, hit_is_right: bool, hit_is_front: bool) -> VehicleWheel3D:
	var candidates := [] as Array[VehicleWheel3D]

	for w in _wheels:
		var p := w.get_path()
		if _detached.get(p, false):
			continue

		var wl: Vector3 = global_transform.affine_inverse() * w.global_position
		var w_is_right: bool = wl.x >= 0.0

		# Use the wheel names to decide front/back bucket reliably
		var w_is_front: bool
		if w.name.contains("Front"):
			w_is_front = true
		elif w.name.contains("Back"):
			w_is_front = false
		else:
			# fallback to z sign if naming isn't as expected
			w_is_front = wl.z <= 0.0

		if w_is_right == hit_is_right and w_is_front == hit_is_front:
			candidates.append(w)

	if candidates.is_empty():
		return null

	# Choose nearest candidate
	var best: VehicleWheel3D = null
	var best_d := INF
	for w in candidates:
		var d := w.global_position.distance_squared_to(hit_pos_global)
		if d < best_d:
			best_d = d
			best = w

	return best


func _apply_bumper_damage(which: String, impulse_mag: float, hit_pos_global: Vector3, hit_normal_global: Vector3) -> void:
	var old: float = float(_bumper_damage.get(which, 0.0))
	var gain_scale := clampf(impulse_mag / bumper_detach_impulse_threshold, 0.0, 3.0)
	var dmg_gain := bumper_damage_gain_per_threshold * gain_scale
	var now: float = clampf(old + dmg_gain, 0.0, bumper_detach_at_damage)
	_bumper_damage[which] = now

	if now >= bumper_detach_at_damage:
		_detach_bumper(which, hit_pos_global, hit_normal_global, impulse_mag)

func _detach_bumper(which: String, hit_pos_global: Vector3, hit_normal_global: Vector3, impulse_mag: float) -> void:
	_bumper_detached[which] = true

	var bumper: Node3D = _front_bumper if which == "front" else _back_bumper
	if bumper == null:
		return

	# Hide bumper visuals + disable bumper collision
	bumper.visible = false

	var col := bumper.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.disabled = true

	# Spawn a loose bumper chunk (box)
	var loose := _make_loose_bumper()
	get_tree().current_scene.add_child(loose)
	loose.global_transform = bumper.global_transform

	var away := (bumper.global_position - hit_pos_global).normalized()
	if away == Vector3.ZERO:
		away = hit_normal_global.normalized()

	var kick := away * bumper_pop_linear_kick + Vector3.UP * bumper_pop_up_kick
	var scale := clampf(impulse_mag / bumper_detach_impulse_threshold, 1.0, 2.5)

	loose.linear_velocity = linear_velocity + kick * scale
	loose.angular_velocity = Vector3(
		randf_range(-bumper_pop_spin, bumper_pop_spin),
		randf_range(-bumper_pop_spin, bumper_pop_spin),
		randf_range(-bumper_pop_spin, bumper_pop_spin)
	) * scale

func _make_loose_bumper() -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.name = "LooseBumper"
	rb.mass = 10.0
	rb.continuous_cd = true

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 0.5, 0.8) # matches your tscn bumpers
	shape.shape = box
	rb.add_child(shape)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.6, 0.5, 0.8) # matches your tscn bumpers
	mi.mesh = mesh
	rb.add_child(mi)

	return rb


func _apply_wheel_damage(w: VehicleWheel3D, dmg_gain: float, hit_pos_global: Vector3, hit_normal_global: Vector3, impulse_mag: float) -> void:
	var p := w.get_path()
	var old: float = float(_damage.get(p, 0.0))
	var now: float = clampf(old + dmg_gain, 0.0, wheel_detach_at_damage)
	_damage[p] = now

	# Progressive “sketchiness” before detaching:
	# Scale down suspension stiffness/travel (feel: more sloppy, more bottoming out)
	var t := now / wheel_detach_at_damage # 0..1
	var stiff_mult : float = lerp(1.0, 0.85, t)
	var travel_mult: float = lerp(1.0, 0.9, t)

	w.suspension_stiffness = _base_stiffness[p] * stiff_mult
	w.suspension_travel = _base_travel[p] * travel_mult

	# If fully damaged → detach
	if now >= wheel_detach_at_damage:
		_detach_wheel(w, hit_pos_global, hit_normal_global, impulse_mag)

func _detach_wheel(w: VehicleWheel3D, hit_pos_global: Vector3, hit_normal_global: Vector3, impulse_mag: float) -> void:
	var p := w.get_path()
	_detached[p] = true

	# Hide wheel mesh
	var mesh := w.get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = false

	# Stop it contributing to vehicle control
	w.use_as_steering = false
	w.use_as_traction = false
	w.engine_force = 0.0

	# Collapse it further so it’s effectively “gone”
	w.wheel_rest_length = 0.0
	w.suspension_travel = 0.0
	w.suspension_stiffness = 0.01
	w.wheel_radius = 0.05

	# Spawn loose wheel
	var loose := _make_loose_wheel()
	get_tree().current_scene.add_child(loose)
	loose.global_transform = w.global_transform

	var away := (w.global_position - hit_pos_global).normalized()
	if away == Vector3.ZERO:
		away = hit_normal_global.normalized()

	var kick := away * wheel_pop_linear_kick + Vector3.UP * wheel_pop_up_kick
	var scale := clampf(impulse_mag / wheel_detach_impulse_threshold, 1.0, 2.5)

	loose.linear_velocity = linear_velocity + kick * scale
	loose.angular_velocity = Vector3(
		randf_range(-wheel_pop_spin, wheel_pop_spin),
		randf_range(-wheel_pop_spin, wheel_pop_spin),
		randf_range(-wheel_pop_spin, wheel_pop_spin)
	) * scale

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

# --- Handling multipliers ---

func _engine_multiplier_from_damage() -> float:
	# Average damage across attached wheels reduces engine/traction.
	var sum := 0.0
	var count := 0.0
	for w in _wheels:
		var p := w.get_path()
		if _detached.get(p, false):
			continue
		sum += minf(float(_damage.get(p, 0.0)), handling_damage_cap)
		count += 1.0

	if count <= 0.0:
		return min_engine_multiplier_at_full_damage

	var avg := sum / count # 0..1
	return lerp(1.0, min_engine_multiplier_at_full_damage, avg)

func _steer_multiplier_from_front_damage() -> float:
	# Front wheel damage affects steering more (soapbox feels “loose”)
	var front_sum := 0.0
	var front_count := 0.0

	for w in _wheels:
		var name := w.name
		if not name.contains("Front"):
			continue

		var p := w.get_path()
		if _detached.get(p, false):
			continue

		front_sum += minf(float(_damage.get(p, 0.0)), handling_damage_cap)
		front_count += 1.0

	if front_count <= 0.0:
		return min_steer_multiplier_at_full_front_damage

	var avg_front := front_sum / front_count
	return lerp(1.0, min_steer_multiplier_at_full_front_damage, avg_front)

func _get_drive_input() -> Vector2:
	# Your original mapping/direction
	return Input.get_vector("move_right", "move_left", "move_back", "move_forward")

func _unhandled_input(event: InputEvent) -> void:
	if _camera_pivot == null:
		return

	if event is InputEventMouseMotion and Input.is_action_pressed("camera_rotate"):
		_cam_yaw -= event.relative.x * camera_sensitivity
		_cam_pitch += event.relative.y * camera_sensitivity
		_cam_pitch = clampf(_cam_pitch, camera_pitch_min, camera_pitch_max)

		_camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)

func get_damage_ratio() -> float:
	# 0.0 = pristine, 1.0 = wrecked
	var total := 0.0
	var count := 0.0

	for w in _wheels:
		var p := w.get_path()
		count += 1.0

		if bool(_detached.get(p, false)):
			total += 1.0
		else:
			# Normalise by detach threshold so "1.0 damage" == "about to detach"
			var d: float = float(_damage.get(p, 0.0))
			var ratio := 0.0
			if wheel_detach_at_damage > 0.0:
				ratio = clampf(d / wheel_detach_at_damage, 0.0, 1.0)
			total += ratio

	if count <= 0.0:
		return 0.0

	return clampf(total / count, 0.0, 1.0)

func get_wheel_damage_ratio_by_name(wheel_name: String) -> float:
	# Returns 0..1 for that wheel (1 = fully damaged / detached)
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
