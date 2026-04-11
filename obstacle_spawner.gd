extends Node3D

# =========================================================
# OBSTACLE SPAWNER
# =========================================================
# Procedurally spawns physics obstacles inside the arena.
#
# Handles:
# - random obstacle placement
# - avoidance around player and enemy spawn positions
# - deterministic or random layouts
# - random obstacle shape/size generation
# - basic obstacle physics setup
# =========================================================

# =========================================================
# EXPORT VARIABLES
# =========================================================
# Total number of obstacles to spawn.
# =========================================================
@export var obstacle_count: int = 35

# =========================================================
# ARENA BOUNDS
# =========================================================
# Controls the playable spawn area for obstacles.
# arena_half_size should roughly match the inner arena bounds.
# =========================================================
@export var arena_half_size: float = 58.0
@export var wall_padding: float = 3.0

# =========================================================
# SPAWN AVOIDANCE
# =========================================================
# Keeps obstacles from spawning too close to the player or enemy.
# =========================================================
@export var avoid_radius_player: float = 10.0
@export var avoid_radius_enemy: float = 10.0
@export var player_path: NodePath = NodePath("../Soapbox")
@export var enemy_path: NodePath = NodePath("../EnemySoapbox")

# =========================================================
# RANDOMIZATION
# =========================================================
# If seed is 0, layout changes each run.
# If seed is non-zero, layout becomes deterministic.
# =========================================================
@export var seed: int = 0

# =========================================================
# BOX SIZE RANGE
# =========================================================
# Min/max dimensions for randomly generated box obstacles.
# =========================================================
@export var box_size_min: Vector3 = Vector3(0.7, 0.7, 0.7)
@export var box_size_max: Vector3 = Vector3(4.0, 3.0, 4.0)

# =========================================================
# CYLINDER SIZE RANGE
# =========================================================
# Min/max dimensions for randomly generated cylinder obstacles.
# =========================================================
@export var cyl_radius_min: float = 0.5
@export var cyl_radius_max: float = 2.5
@export var cyl_height_min: float = 0.7
@export var cyl_height_max: float = 4.0

# =========================================================
# PHYSICS TUNING
# =========================================================
# Controls how heavy and slippery/bouncy the spawned obstacles feel.
# =========================================================
@export var base_mass: float = 6.0
@export var mass_per_volume: float = 0.35
@export var linear_damp: float = 0.2
@export var angular_damp: float = 0.3
@export var friction: float = 1.1
@export var bounce: float = 0.05

# =========================================================
# RUNTIME STATE
# =========================================================
# Dedicated RNG so the spawner can support deterministic layouts.
# =========================================================
var _rng := RandomNumberGenerator.new()

# =========================================================
# READY
# =========================================================
# Initializes the random generator, resolves player/enemy positions,
# and begins obstacle spawning.
# =========================================================
func _ready() -> void:
	if seed != 0:
		_rng.seed = seed
	else:
		_rng.randomize()

	var player := get_node_or_null(player_path) as Node3D
	var enemy := get_node_or_null(enemy_path) as Node3D

	var player_pos := (player.global_position if player else Vector3.ZERO)
	var enemy_pos := (enemy.global_position if enemy else Vector3.ZERO)

	_spawn_obstacles(player_pos, enemy_pos)

# =========================================================
# OBSTACLE SPAWNING
# =========================================================
# Repeatedly attempts to place obstacles until the desired count
# is reached or the maximum number of attempts is exceeded.
# =========================================================
func _spawn_obstacles(player_pos: Vector3, enemy_pos: Vector3) -> void:
	var attempts := 0
	var spawned := 0
	var max_attempts := obstacle_count * 25

	while spawned < obstacle_count and attempts < max_attempts:
		attempts += 1

		var pos := _random_pos()
		if pos.distance_to(player_pos) < avoid_radius_player:
			continue
		if pos.distance_to(enemy_pos) < avoid_radius_enemy:
			continue

		var obstacle := _make_random_obstacle()
		add_child(obstacle)
		obstacle.global_position = pos
		obstacle.rotation.y = _rng.randf_range(-PI, PI)

		spawned += 1

# =========================================================
# RANDOM POSITION HELPER
# =========================================================
# Returns a valid random position inside the arena bounds.
# =========================================================
func _random_pos() -> Vector3:
	var limit := arena_half_size - wall_padding
	return Vector3(
		_rng.randf_range(-limit, limit),
		0.0,
		_rng.randf_range(-limit, limit)
	)

# =========================================================
# OBSTACLE GENERATION
# =========================================================
# Creates a random rigidbody obstacle, choosing between:
# - box
# - cylinder
#
# Also applies:
# - random size
# - random color
# - collision shape
# - mass scaling based on estimated volume
# =========================================================
func _make_random_obstacle() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Obstacle"
	body.linear_damp = linear_damp
	body.angular_damp = angular_damp
	body.continuous_cd = true

	# =========================================================
	# PHYSICS MATERIAL
	# =========================================================
	# Controls friction and bounce.
	# =========================================================
	var phys := PhysicsMaterial.new()
	phys.friction = friction
	phys.bounce = bounce
	body.physics_material_override = phys

	var collision := CollisionShape3D.new()
	var mesh_inst := MeshInstance3D.new()

	# =========================================================
	# VISUAL MATERIAL
	# =========================================================
	# Random bright-ish color for easy visual variety.
	# =========================================================
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(_rng.randf(), 0.75, 0.95)
	mesh_inst.material_override = mat

	# =========================================================
	# SHAPE SELECTION
	# =========================================================
	# Boxes are more common than cylinders.
	# =========================================================
	var is_box := _rng.randf() < 0.65
	var volume_estimate := 1.0

	if is_box:
		var size := Vector3(
			_rng.randf_range(box_size_min.x, box_size_max.x),
			_rng.randf_range(box_size_min.y, box_size_max.y),
			_rng.randf_range(box_size_min.z, box_size_max.z)
		)

		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape

		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_inst.mesh = mesh

		# Place on ground (box is centered)
		body.position.y += size.y * 0.5

		volume_estimate = maxf(0.01, size.x * size.y * size.z)

	else:
		var r := _rng.randf_range(cyl_radius_min, cyl_radius_max)
		var h := _rng.randf_range(cyl_height_min, cyl_height_max)

		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = h
		collision.shape = shape

		var mesh := CylinderMesh.new()
		mesh.top_radius = r
		mesh.bottom_radius = r
		mesh.height = h
		mesh_inst.mesh = mesh

		# Place on ground
		body.position.y += h * 0.5

		volume_estimate = maxf(0.01, PI * r * r * h)

	# =========================================================
	# MASS SCALING
	# =========================================================
	# Larger obstacles become heavier based on estimated volume.
	# =========================================================
	body.mass = base_mass + volume_estimate * mass_per_volume

	body.add_child(collision)
	body.add_child(mesh_inst)
	return body