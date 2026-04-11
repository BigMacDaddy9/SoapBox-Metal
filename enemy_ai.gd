extends "res://soapbox.gd"

# =========================================================
# ENEMY AI
# =========================================================
# AI driver built on top of the base soapbox vehicle script.
#
# This keeps the shared vehicle physics and weapon setup, while
# replacing direct keyboard steering with target-driven behaviour.
# =========================================================

# =========================================================
# EXPORT VARIABLES
# =========================================================
@export var target_path: NodePath

@export var aggression: float = 3.0
@export var steer_smoothing: float = 10.0
@export var throttle: float = 1.0
@export var lead_time: float = 0.15
@export var lead_time_max: float = 0.45
@export var ram_bias: float = 0.08
@export var stuck_speed_threshold: float = 0.18
@export var stuck_time_to_trigger: float = 1.2
@export var unstuck_time: float = 0.55
@export var unstuck_throttle: float = 1.0
@export var unstuck_turn: float = 1.0
@export var truck_boost_distance: float = 10.0
@export var truck_boost_dot: float = 0.15
@export var ai_boost_force_mult: float = 1.6
@export var ai_boost_duration_mult: float = 1.15

# =========================================================
# RUNTIME STATE
# =========================================================
var _target: RigidBody3D = null
var _steer_smoothed: float = 0.0
var _delta_cache: float = 0.016
var _unstuck_timer: float = 0.0
var _stuck_timer: float = 0.0
var _unstuck_turn_dir: float = 1.0
var enemy_missile_cooldown_timer: float = 8.0
var enemy_missile_cooldown: float = 8.0

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	super._ready()
	_target = _resolve_target()

# =========================================================
# TARGET RESOLUTION
# =========================================================
# Resolve the target from either an explicit NodePath or the
# first node found in the player group.
# =========================================================
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

# =========================================================
# PROCESS / PHYSICS
# =========================================================
func _physics_process(delta: float) -> void:
	_delta_cache = delta

	if _target == null:
		_target = _resolve_target()

	_unstuck_timer = maxf(0.0, _unstuck_timer - delta)
	enemy_missile_cooldown_timer = maxf(0.0, enemy_missile_cooldown_timer - delta)

	var spd := linear_velocity.length()
	if _unstuck_timer <= 0.0 and spd < stuck_speed_threshold:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0

	if _stuck_timer >= stuck_time_to_trigger and _unstuck_timer <= 0.0:
		_unstuck_timer = unstuck_time
		_stuck_timer = 0.0
		_unstuck_turn_dir = (1.0 if randf() > 0.5 else -1.0)

	# BMD MISSILE SYSTEM
	if enemy_missile_cooldown_timer <= 0.0 and _target != null:
		_bmd_try_fire_missile(_target)

	super._physics_process(delta)

# =========================================================
# WEAPON LOGIC
# =========================================================
# Fire a missile when the AI has a valid target in front of it.
# =========================================================
func _bmd_try_fire_missile(target_object: Node3D) -> void:
	if missile == null or target_object == null:
		return

	var direction_to_target := (target_object.global_transform.origin - global_transform.origin).normalized()
	var forward_vector := -global_transform.basis.z.normalized()
	var dot_product := forward_vector.dot(direction_to_target)

	if dot_product > 0.0:
		enemy_missile_cooldown_timer = enemy_missile_cooldown
		var missile_spawn := get_node_or_null("MissileSpawn") as Node3D
		var tmp_missile := missile.instantiate() as Node3D

		if tmp_missile == null:
			return

		if missile_spawn != null:
			tmp_missile.global_transform = missile_spawn.global_transform
		else:
			tmp_missile.global_transform = global_transform

		get_tree().current_scene.add_child(tmp_missile)

# =========================================================
# DRIVE INPUT
# =========================================================
# Calculate the AI steering and throttle response based on the
# target's position, movement, and the AI's current state.
# =========================================================
func _get_drive_input() -> Vector2:
	if _target == null:
		return Vector2.ZERO

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

	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right: Vector3 = global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var right_dot: float = right.dot(dir)
	var forward_dot: float = forward.dot(dir)

	if dist <= truck_boost_distance and forward_dot >= truck_boost_dot:
		if _boost_cooldown_timer <= 0.0:
			var old_force := boost_force
			var old_dur := boost_duration
			boost_force = old_force * ai_boost_force_mult
			boost_duration = old_dur * ai_boost_duration_mult
			request_boost()
			boost_force = old_force
			boost_duration = old_dur

	var angle: float = atan2(right_dot, forward_dot)
	var steer_target: float = clampf(angle * aggression, -1.0, 1.0)
	steer_target = clampf(steer_target + (signf(steer_target) * ram_bias), -1.0, 1.0)

	var t: float = 1.0 - exp(-steer_smoothing * _delta_cache)
	_steer_smoothed = lerp(_steer_smoothed, steer_target, t)

	if _unstuck_timer > 0.0:
		return Vector2(_unstuck_turn_dir * unstuck_turn, -unstuck_throttle)

	return Vector2(_steer_smoothed, throttle)
