extends RigidBody3D

@export var speed: float = 100.0
@export var explosion_radius: float = 200.0
@export var explosion_power: float = 1000.0
@export var coolexplosion: PackedScene

@onready var explosion_area: Area3D = $MissileArea

var _has_exploded: bool = false
var _is_armed: bool = false


func _ready() -> void:
	# BMD MISSILE SYSTEM CHANGE:
	# The original flow moved the missile manually and then polled get_colliding_bodies()
	# every frame. That can make the blast LOOK early because the collision body list can update
	# slightly ahead of what the visible mesh seems to be doing.
	#
	# Fix: let physics drive the contact timing and arm the missile a fraction later so it does
	# not immediately react to the launcher/shooter overlap right after spawning.
	contact_monitor = true
	max_contacts_reported = max(max_contacts_reported, 5)
	continuous_cd = true
	sleeping = false
	linear_velocity = global_transform.basis.z.normalized() * speed
	call_deferred("_arm_missile")


func _physics_process(_delta: float) -> void:
	if _has_exploded:
		linear_velocity = Vector3.ZERO
		return

	# BMD MISSILE SYSTEM CHANGE:
	# Keep the missile driving forward in physics time instead of manually stepping movement in
	# _process(). This makes the hit timing line up better with actual collision resolution.
	linear_velocity = global_transform.basis.z.normalized() * speed


func _arm_missile() -> void:
	# BMD MISSILE SYSTEM CHANGE:
	# Tiny arming delay so the missile does not trigger on its own spawning overlap.
	await get_tree().create_timer(0.08).timeout
	_is_armed = true


func _on_missile_body_shape_entered(_body_rid: RID, body: Node, _body_shape_index: int, _local_shape_index: int) -> void:
	# BMD MISSILE SYSTEM CHANGE:
	# Explode from the actual body-shape contact signal instead of polling colliding bodies.
	# This makes the explosion happen when the missile actually collides with something.
	if _has_exploded or not _is_armed:
		return
	if body == null or body == self:
		return

	explode()


func explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true

	var bodies: Array[Node3D] = explosion_area.get_overlapping_bodies()
	for body in bodies:
		if body is StaticBody3D:
			continue
		if not body.has_method("apply_central_impulse"):
			continue

		var direction: Vector3 = (body.global_position - global_position).normalized()
		var distance: float = global_position.distance_to(body.global_position)
		var distance_factor: float = 1.0 - (distance / explosion_radius)
		distance_factor = clamp(distance_factor, 0.0, 1.0)

		var final_force: Vector3 = direction * explosion_power * distance_factor
		body.apply_central_impulse(final_force)

		var break_force_scale: float = explosion_power * distance_factor * 0.03
		if body is VehicleBody3D:
			VehicleBuilder.break_parts_near_point(body as Node3D, global_position, break_force_scale, 3.0, direction)
		elif body is RigidBody3D and body.has_meta("joint"):
			var joint_variant: Variant = body.get_meta("joint")
			var joint := joint_variant as Generic6DOFJoint3D
			if joint != null and is_instance_valid(joint):
				var break_force: float = float(body.get_meta("break_force"))
				if break_force_scale >= break_force:
					VehicleBuilder.break_attached_part(body as RigidBody3D, joint, direction, break_force_scale - break_force)

	# BMD MISSILE SYSTEM CHANGE:
	# Add the explosion instance to the scene tree before calling explode() so its timer and
	# particles are valid when the effect starts.
	if coolexplosion != null:
		var tmp_explosion: Node3D = coolexplosion.instantiate() as Node3D
		var scene_root: Node = get_tree().current_scene
		if scene_root == null:
			scene_root = get_parent()
		if scene_root != null:
			scene_root.add_child(tmp_explosion)
			tmp_explosion.global_position = global_position
			if tmp_explosion.has_method("explode"):
				tmp_explosion.explode()

	queue_free()
