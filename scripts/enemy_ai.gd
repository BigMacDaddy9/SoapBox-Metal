extends "res://scripts/soapbox.gd"

@export var target_path: NodePath

# Steering feel
@export var aggression: float = 3.0
@export var steer_smoothing: float = 10.0

# Always push forward
@export var throttle: float = 1.0

# Lead the target a little (helps hit moving player)
@export var lead_time: float = 0.15
@export var lead_time_max: float = 0.45

# Optional: make it “dumber” (less lining-up) by adding a little constant bias
@export var ram_bias: float = 0.08  # 0..0.2 feels good

# Unstuck (THIS is what looked like backoff)
# Lower threshold so it doesn't reverse just because it's slow while turning / rubbing on you.
@export var stuck_speed_threshold: float = 0.18
@export var stuck_time_to_trigger: float = 1.2
@export var unstuck_time: float = 0.55
@export var unstuck_throttle: float = 1.0
@export var unstuck_turn: float = 1.0

# Boost when close to player
@export var truck_boost_distance: float = 10.0   # how close before it boosts
@export var truck_boost_dot: float = 0.15        # how "roughly facing" the target (lower = boosts even when sloppy)
@export var ai_boost_force_mult: float = 1.6
@export var ai_boost_duration_mult: float = 1.15

var _target: RigidBody3D = null
var _steer_smoothed: float = 0.0
var _delta_cache: float = 0.016

var _unstuck_timer: float = 0.0
var _stuck_timer: float = 0.0
var _unstuck_turn_dir: float = 1.0

var enemy_missile_cooldown_timer : float = 8.0
var enemy_missile_cooldown : float = 8.0

func _ready() -> void:
	super._ready()
	_target = _resolve_target()

func _resolve_target() -> RigidBody3D:
	if target_path != NodePath():
		var n := get_node_or_null(target_path)
		if n is RigidBody3D:
			return n
		return null

	var g := get_tree().get_first_node_in_group("player")
	if g is RigidBody3D:
		return g
	return null

func _physics_process(delta: float) -> void:
	_delta_cache = delta
	if _target == null:
		_target = _resolve_target()

	_unstuck_timer = maxf(0.0, _unstuck_timer - delta)
	enemy_missile_cooldown_timer = maxf(0.0, enemy_missile_cooldown_timer - delta)

	# Only consider "stuck" when we are trying to move forward.
	var spd := linear_velocity.length()
	if _unstuck_timer <= 0.0 and spd < stuck_speed_threshold:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0

	if _stuck_timer >= stuck_time_to_trigger and _unstuck_timer <= 0.0:
		_unstuck_timer = unstuck_time
		_stuck_timer = 0.0
		_unstuck_turn_dir = (1.0 if randf() > 0.5 else -1.0)
		
	# Missiles
	if enemy_missile_cooldown_timer <= 0.0:
		is_in_front_vector_check(_target)

	super._physics_process(delta)
	
func is_in_front_vector_check(target_object: Node3D):
	var direction_to_target = (target_object.global_transform.origin - global_transform.origin).normalized()
	var forward_vector = -global_transform.basis.z.normalized()
	# The dot product is positive if the angle between the vectors is less than 90 degrees
	var dot_product = forward_vector.dot(direction_to_target)
	if dot_product < 0:
		enemy_missile_cooldown_timer = enemy_missile_cooldown
		var tmp_missile = missile.instantiate()
		tmp_missile.position = $Marker3D.global_position
		tmp_missile.rotation = $Marker3D.global_rotation
		add_sibling(tmp_missile)

func _get_drive_input() -> Vector2:
	if _target == null:
		return Vector2.ZERO

	# Aim point (small lead)
	var aim_pos: Vector3 = _target.global_position
	var v: Vector3 = _target.linear_velocity
	v.y = 0.0

	var lt: float = clampf(lead_time, 0.0, lead_time_max)
	aim_pos += v * lt

	var to_aim: Vector3 = aim_pos - global_position
	to_aim.y = 0.0
	var dist := to_aim.length()
	if dist < 0.01:
		return Vector2.ZERO

	var dir: Vector3 = to_aim / dist

	# Basis vectors
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right: Vector3 = global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var right_dot: float = right.dot(dir)
	var forward_dot: float = forward.dot(dir)
	# Hit like a truck mode: boost when close and generally aimed at the target
	if dist <= truck_boost_distance and forward_dot >= truck_boost_dot:
		if _boost_cooldown_timer <= 0.0:
			# temporarily beef up boost for AI, then trigger
			var old_force := boost_force
			var old_dur := boost_duration

			boost_force = old_force * ai_boost_force_mult
			boost_duration = old_dur * ai_boost_duration_mult
			request_boost()

			# restore so values don't drift
			boost_force = old_force
			boost_duration = old_dur



	var angle: float = atan2(right_dot, forward_dot)

	# Steering target (aggressive)
	var steer_target: float = clampf(angle * aggression, -1.0, 1.0)

	# Slight bias so it doesn't endlessly "perfect align"
	steer_target = clampf(steer_target + (signf(steer_target) * ram_bias), -1.0, 1.0)

	# Smooth steering
	var t: float = 1.0 - exp(-steer_smoothing * _delta_cache)
	_steer_smoothed = lerp(_steer_smoothed, steer_target, t)

	# Unstuck: ONLY time we reverse
	if _unstuck_timer > 0.0:
		return Vector2(_unstuck_turn_dir * unstuck_turn, -unstuck_throttle)

	# Otherwise: ALWAYS forward.
	return Vector2(_steer_smoothed, throttle)
