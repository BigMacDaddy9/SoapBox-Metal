extends RefCounted
class_name VehicleBuilder

# =========================================================
# VEHICLE BUILDER
# =========================================================
# This script handles:
# - showing the correct base visuals
# - attaching build parts to mount points
# - creating springy multi-joint attachments in gameplay
# - creating simple static attachments in the preview
# - breaking attached parts off during impacts / explosions
#
# DESIGN GOAL:
# We want parts to feel like solid objects mounted to the vehicle
# with springy connection points.
#
# That means:
# - the PART should feel rigid
# - the JOINTS should provide the visible wobble / flex
# - breakage should feel like mounts failing, not like parts hovering
# =========================================================


# =========================================================
# BASE VISUALS
# =========================================================
# Switches between the light and heavy base meshes.
# =========================================================
static func apply_base_visuals(vehicle: Node, base_name: String) -> void:
	var thin_visual: Node3D = vehicle.get_node_or_null("ThinBaseVisual") as Node3D
	var heavy_visual: Node3D = vehicle.get_node_or_null("HeavyBaseVisual") as Node3D

	if thin_visual:
		thin_visual.visible = (base_name == "light" or base_name == "thin")

	if heavy_visual:
		heavy_visual.visible = (base_name == "heavy")


# =========================================================
# PART CLEANUP
# =========================================================
# Removes any previously attached parts and joints before rebuilding.
# This gets called whenever the build changes.
# =========================================================
static func clear_attached_parts(vehicle: Node) -> void:
	var mount_root: Node = vehicle.get_node_or_null("MountPoints")
	if mount_root == null:
		return

	# Clear preview/static parts sitting under mount nodes
	for mount: Node in mount_root.get_children():
		for child: Node in mount.get_children():
			if child.is_in_group("build_part"):
				child.queue_free()

	# Clear gameplay rigid bodies + joints attached directly to vehicle
	for child: Node in vehicle.get_children():
		if child.is_in_group("build_part_body") or child.is_in_group("build_part_joint"):
			child.queue_free()


# =========================================================
# PART ATTACH ENTRY POINT
# =========================================================
# Decides whether to use:
# - static preview parts
# - or full gameplay spring-mounted parts
# =========================================================
static func attach_parts(vehicle: Node, selected_parts: Dictionary) -> void:
	var mount_root: Node = vehicle.get_node_or_null("MountPoints")
	if mount_root == null:
		return

	clear_attached_parts(vehicle)

	var use_jointed_parts: bool = _should_use_jointed_parts(vehicle)

	for mount_name_variant: Variant in selected_parts.keys():
		var mount_name: String = str(mount_name_variant)
		var part_id: String = str(selected_parts[mount_name_variant])

		# Skip empty slots
		if part_id == "":
			continue

		# Skip invalid part IDs
		if not SBSettings.part_presets.has(part_id):
			continue

		var mount: Node3D = mount_root.get_node_or_null(mount_name) as Node3D
		if mount == null:
			continue

		var part_data: Dictionary = SBSettings.part_presets[part_id]
		var scene_path: String = str(part_data.get("scene_path", ""))
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			continue

		var part_scene: PackedScene = load(scene_path) as PackedScene
		if part_scene == null:
			continue

		if use_jointed_parts:
			_attach_jointed_part(vehicle, mount, mount_name, part_id, part_scene)
		else:
			_attach_static_part(mount, part_scene)


# =========================================================
# APPLY COMPLETE BUILD
# =========================================================
# Convenience function used by places that want to rebuild the whole
# cart in one call.
# =========================================================
static func apply_complete_build(vehicle: Node, base_name: String, selected_parts: Dictionary) -> void:
	apply_base_visuals(vehicle, base_name)
	attach_parts(vehicle, selected_parts)


# =========================================================
# BREAK PARTS NEAR AN IMPACT
# =========================================================
# Used by:
# - car impacts
# - missile explosions
#
# We look for attached part bodies near the impact point and compare
# the effective impact force against that part's break threshold.
# =========================================================
static func break_parts_near_point(
	vehicle: Node3D,
	world_point: Vector3,
	impact_force: float,
	break_radius: float = 1.6,
	break_direction: Vector3 = Vector3.UP
) -> int:
	if vehicle == null:
		return 0

	var broken_count: int = 0

	for child: Node in vehicle.get_children():
		if not (child is RigidBody3D):
			continue

		var part_body := child as RigidBody3D

		# Only consider actual attached build parts
		if not part_body.is_in_group("build_part_body"):
			continue

		# If a part has no live joints left, it's already detached
		if not _part_has_active_joints(part_body):
			continue

		var distance: float = part_body.global_position.distance_to(world_point)
		if distance > break_radius:
			continue

		var break_force: float = float(part_body.get_meta("break_force"))
		var distance_factor: float = clampf(1.0 - (distance / break_radius), 0.0, 1.0)
		var effective_force: float = impact_force * distance_factor

		if effective_force < break_force:
			continue

		var impulse_scale: float = maxf(effective_force - break_force, 0.0)

		if break_attached_part(part_body, null, break_direction, impulse_scale):
			broken_count += 1

	return broken_count


# =========================================================
# BREAK A SINGLE ATTACHED PART
# =========================================================
# Removes all active joints from a part and lets it become free debris.
#
# IMPORTANT:
# A part may now have MULTIPLE joints.
# We break the whole part free by destroying all of them at once.
# =========================================================
static func break_attached_part(
	part_body: RigidBody3D,
	joint_hint: Generic6DOFJoint3D = null,
	break_direction: Vector3 = Vector3.UP,
	extra_force: float = 0.0
) -> bool:
	if part_body == null or not is_instance_valid(part_body):
		return false

	var valid_joints: Array[Generic6DOFJoint3D] = _get_valid_joints_for_part(part_body)

	# Fallback for older/single-joint cases
	if valid_joints.is_empty():
		if joint_hint == null or not is_instance_valid(joint_hint):
			return false
		valid_joints.append(joint_hint)

	# Store current world transform so the part doesn't jump when reparented
	var old_global: Transform3D = part_body.global_transform

	# Detached debris should live in the main scene, not under the car
	var scene_root: Node = part_body.get_tree().current_scene
	if scene_root == null:
		scene_root = part_body.get_parent()

	# Remove all mounting joints
	for joint in valid_joints:
		if joint != null and is_instance_valid(joint):
			joint.queue_free()

	part_body.set_meta("joint", null)
	part_body.set_meta("joints", [])

	# Reparent to the scene root so the part stays behind in the world
	if scene_root != null and part_body.get_parent() != scene_root:
		part_body.reparent(scene_root)
		part_body.global_transform = old_global

	# Apply a little breakup impulse so parts don't just drop dead
	var direction := break_direction.normalized()
	if direction == Vector3.ZERO:
		direction = Vector3.UP

	var impulse_strength: float = maxf(extra_force, 4.0) * maxf(part_body.mass, 0.1)
	var impulse: Vector3 = direction * impulse_strength
	impulse += Vector3(
		randf_range(-2.5, 2.5),
		randf_range(1.0, 3.0),
		randf_range(-2.5, 2.5)
	)

	part_body.apply_central_impulse(impulse)
	part_body.apply_torque_impulse(
		Vector3(
			randf_range(-3.0, 3.0),
			randf_range(-3.0, 3.0),
			randf_range(-3.0, 3.0)
		) * maxf(part_body.mass, 0.1)
	)

	return true


# =========================================================
# PREVIEW OR GAMEPLAY?
# =========================================================
# If we are rendering inside a SubViewport, that usually means this is
# the build preview. In that case, we use simple static parts.
#
# If not, we assume this is live gameplay and use the full physics setup.
# =========================================================
static func _should_use_jointed_parts(vehicle: Node) -> bool:
	var viewport: Viewport = vehicle.get_viewport()
	return not (viewport is SubViewport)


# =========================================================
# ATTACH STATIC PREVIEW PART
# =========================================================
# Used in the build preview where we do not want live physics.
# =========================================================
static func _attach_static_part(mount: Node3D, part_scene: PackedScene) -> void:
	var instance: Node3D = part_scene.instantiate() as Node3D
	if instance == null:
		return

	# If a scene already uses a rigid body root, freeze it in the preview
	if instance is RigidBody3D:
		var rigid := instance as RigidBody3D
		rigid.freeze = true
		rigid.sleeping = true

	mount.add_child(instance)
	instance.transform = Transform3D.IDENTITY
	instance.add_to_group("build_part")


# =========================================================
# ATTACH GAMEPLAY PART
# =========================================================
# Creates:
# - one rigid body for the part
# - multiple joints between vehicle and part
#
# GAME FEEL IDEA:
# The part is a solid chunk.
# The springy movement comes from multiple tight spring-mounted joints.
# =========================================================
static func _attach_jointed_part(
	vehicle: Node,
	mount: Node3D,
	mount_name: String,
	part_id: String,
	part_scene: PackedScene
) -> void:
	var vehicle_body: PhysicsBody3D = vehicle as PhysicsBody3D
	if vehicle_body == null:
		_attach_static_part(mount, part_scene)
		return

	var raw_instance: Node = part_scene.instantiate()
	if raw_instance == null or not (raw_instance is Node3D):
		return

	var raw_part_node := raw_instance as Node3D
	var profile: Dictionary = SBSettings.get_part_joint_profile(part_id)

	# AABB = Axis-Aligned Bounding Box (simple box that fully contains a mesh, used to generate collision)
	var local_aabb: AABB = _collect_local_mesh_aabb(raw_part_node)
	var local_center: Vector3 = local_aabb.position + (local_aabb.size * 0.5)
	var shape: Shape3D = _build_collision_shape_from_aabb(local_aabb)

	var part_body: RigidBody3D
	var visual_root: Node3D

	# ---------------------------------------------------------
	# If the part scene already has a RigidBody root, reuse it.
	# Otherwise wrap the visual scene inside a new rigid body.
	# ---------------------------------------------------------
	if raw_part_node is RigidBody3D:
		part_body = raw_part_node as RigidBody3D
		_prepare_existing_part_body(part_body)
		visual_root = part_body
	else:
		part_body = RigidBody3D.new()
		part_body.name = "%s_PartBody" % mount_name

		visual_root = raw_part_node
		part_body.add_child(visual_root)

		# Centre the visual inside the body using mesh bounds
		visual_root.position = -local_center
		visual_root.rotation = Vector3.ZERO
		visual_root.scale = Vector3.ONE

		var collider: CollisionShape3D = CollisionShape3D.new()
		collider.shape = shape
		collider.position = local_center
		part_body.add_child(collider)

	# ---------------------------------------------------------
	# Part body tuning
	# ---------------------------------------------------------
	# We keep the part itself fairly controlled.
	# The wobble should come from the mounts, not from the body going wild.
	# ---------------------------------------------------------
	part_body.mass = float(profile.get("mass", 1.5))
	part_body.linear_damp = float(profile.get("linear_damp", 1.8))
	part_body.angular_damp = float(profile.get("body_angular_damp", 1.2))
	part_body.continuous_cd = true
	part_body.can_sleep = false
	part_body.contact_monitor = true
	part_body.max_contacts_reported = 4
	part_body.freeze = false
	part_body.sleeping = false
	part_body.global_transform = mount.global_transform

	part_body.add_to_group("build_part_body")
	part_body.add_to_group("build_part")

	part_body.set_meta("part_id", part_id)
	part_body.set_meta("mount_name", mount_name)
	part_body.set_meta("break_force", float(profile.get("break_force", 18.0)))

	vehicle.add_child(part_body)
	visual_root.add_to_group("build_part")

	# ---------------------------------------------------------
	# Multi-joint mount creation
	# ---------------------------------------------------------
	# Each offset represents one physical connection point.
	# Example:
	# - rails = front / centre / rear
	# - bumpers = left / right
	# - seat = 4 corners
	# - nose = 1
	# ---------------------------------------------------------
	var joints: Array[Generic6DOFJoint3D] = []
	var joint_offsets: Array = profile.get("joint_offsets", [Vector3.ZERO])

	# ---------------------------------------------------------
	# Spring settings
	# ---------------------------------------------------------
	# We are deliberately going for:
	# - small movement range
	# - strong spring pullback
	# - some visible stress wobble
	#
	# If parts still feel floaty:
	# - raise damping first
	# - then reduce linear/Angular limits
	# ---------------------------------------------------------
	var linear_limit: float = float(profile.get("linear_limit", 0.01))
	var angular_limit: float = deg_to_rad(float(profile.get("angular_limit_deg", 8.0)))
	var angular_stiffness: float = float(profile.get("angular_stiffness", 8.0))
	var angular_damping: float = float(profile.get("angular_damping", 1.4))

	for i in range(joint_offsets.size()):
		var offset_variant: Variant = joint_offsets[i]
		var offset: Vector3 = Vector3.ZERO
		if offset_variant is Vector3:
			offset = offset_variant

		var joint := Generic6DOFJoint3D.new()
		joint.name = "%s_PartJoint_%d" % [mount_name, i]

		# Position the joint in world space using the mount transform + local offset
		var joint_transform: Transform3D = mount.global_transform
		joint_transform.origin += mount.global_transform.basis * offset
		joint.global_transform = joint_transform

		joint.add_to_group("build_part_joint")
		vehicle.add_child(joint)

		var path_to_vehicle: NodePath = joint.get_path_to(vehicle_body)
		var path_to_part_body: NodePath = joint.get_path_to(part_body)
		joint.node_a = path_to_vehicle
		joint.node_b = path_to_part_body

		# -----------------------------------------------------
		# Linear limits
		# -----------------------------------------------------
		# Very small positional freedom.
		# This gives a spring-mounted feel without parts drifting.
		# -----------------------------------------------------
		joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -linear_limit)
		joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, linear_limit)
		joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -linear_limit)
		joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, linear_limit)
		joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -linear_limit)
		joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, linear_limit)

		# -----------------------------------------------------
		# Angular limits
		# -----------------------------------------------------
		# We keep rotation constrained so parts feel mounted,
		# but still allow a little drama under stress.
		# -----------------------------------------------------
		joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -angular_limit)
		joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, angular_limit)
		joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -angular_limit)
		joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, angular_limit)
		joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -angular_limit)
		joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, angular_limit)

		# -----------------------------------------------------
		# Angular springs
		# -----------------------------------------------------
		# This is the main "mounted but flexy" feel.
		# Higher stiffness = more bolted on
		# Higher damping = settles faster, less floaty
		# -----------------------------------------------------
		joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING, true)
		joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING, true)
		joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING, true)

		joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, angular_stiffness)
		joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, angular_stiffness)
		joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, angular_stiffness)

		joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING, angular_damping)
		joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING, angular_damping)
		joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING, angular_damping)

		# -----------------------------------------------------
		# Linear springs
		# -----------------------------------------------------
		# This is what helps the part feel like it's being held
		# by springy mounts instead of a magic invisible field.
		#
		# Note:
		# If this feels too twitchy, lower stiffness or raise damping.
		# -----------------------------------------------------
		joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_SPRING, true)
		joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_SPRING, true)
		joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_SPRING, true)

		var linear_stiffness: float = angular_stiffness * 1.35
		var linear_damping: float = angular_damping * 1.4

		joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_SPRING_STIFFNESS, linear_stiffness)
		joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_SPRING_STIFFNESS, linear_stiffness)
		joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_SPRING_STIFFNESS, linear_stiffness)

		joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_SPRING_DAMPING, linear_damping)
		joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_SPRING_DAMPING, linear_damping)
		joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_SPRING_DAMPING, linear_damping)

		joints.append(joint)

	# Store both the old single-joint key and the new array for compatibility
	if not joints.is_empty():
		part_body.set_meta("joint", joints[0])
	part_body.set_meta("joints", joints)


# =========================================================
# EXISTING RIGIDBODY PART PREP
# =========================================================
# Some part scenes already use a RigidBody3D as the root.
# This makes sure they still behave nicely in our system.
# =========================================================
static func _prepare_existing_part_body(part_body: RigidBody3D) -> void:
	part_body.name = "%s_PartBody" % part_body.name
	var has_collision: bool = false

	for child: Node in part_body.get_children():
		if child is CollisionShape3D:
			has_collision = true
		if child is Node3D:
			(child as Node3D).add_to_group("build_part")

	if has_collision:
		return

	# Fallback collision if the scene did not provide one
	var fallback_shape := CollisionShape3D.new()
	fallback_shape.shape = _build_collision_shape_from_aabb(_collect_local_mesh_aabb(part_body))
	part_body.add_child(fallback_shape)


# =========================================================
# ACTIVE JOINT CHECK
# =========================================================
# Returns true if the part still has one or more valid live joints.
# =========================================================
static func _part_has_active_joints(part_body: RigidBody3D) -> bool:
	return not _get_valid_joints_for_part(part_body).is_empty()


# =========================================================
# GATHER LIVE JOINTS
# =========================================================
# Supports both:
# - new multi-joint parts
# - old single-joint fallback data
# =========================================================
static func _get_valid_joints_for_part(part_body: RigidBody3D) -> Array[Generic6DOFJoint3D]:
	var result: Array[Generic6DOFJoint3D] = []

	if part_body.has_meta("joints"):
		var joints_variant: Variant = part_body.get_meta("joints")
		if joints_variant is Array:
			for entry in joints_variant:
				if entry is Generic6DOFJoint3D and is_instance_valid(entry):
					result.append(entry)

	if result.is_empty() and part_body.has_meta("joint"):
		var joint_variant: Variant = part_body.get_meta("joint")
		if joint_variant is Generic6DOFJoint3D and is_instance_valid(joint_variant):
			result.append(joint_variant)

	return result


# =========================================================
# COLLISION SHAPE FROM BOUNDS
# =========================================================
# Builds a simple box collision from the part's mesh bounds.
# Not perfect, but cheap and stable for modular chaotic gameplay.
# =========================================================
static func _build_collision_shape_from_aabb(aabb: AABB) -> Shape3D:
	var box: BoxShape3D = BoxShape3D.new()

	var size: Vector3 = aabb.size
	if size.length() <= 0.001:
		size = Vector3(0.3, 0.3, 0.3)

	box.size = Vector3(
		maxf(size.x, 0.08),
		maxf(size.y, 0.08),
		maxf(size.z, 0.08)
	)

	return box


# =========================================================
# COLLECT MESH BOUNDS
# =========================================================
# Walks through the part scene and merges all mesh bounds into one box.
# =========================================================
static func _collect_local_mesh_aabb(root: Node3D) -> AABB:
	var found: bool = false
	var result: AABB = AABB()

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()

		if current is MeshInstance3D:
			var mesh_instance: MeshInstance3D = current as MeshInstance3D
			if mesh_instance.mesh != null:
				var mesh_aabb: AABB = mesh_instance.mesh.get_aabb()
				var transformed_aabb: AABB = mesh_instance.transform * mesh_aabb

				if not found:
					result = transformed_aabb
					found = true
				else:
					result = result.merge(transformed_aabb)

		for child: Node in current.get_children():
			stack.append(child)

	if found:
		return result

	# Safe fallback if the part scene has no meshes for some reason
	return AABB(Vector3(-0.15, -0.15, -0.15), Vector3(0.3, 0.3, 0.3))
