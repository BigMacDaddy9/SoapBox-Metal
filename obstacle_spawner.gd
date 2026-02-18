extends Node3D

@export var obstacle_count: int = 35

# Arena bounds (match your wall distance; for 120 ground + walls at 60, use ~58)
@export var arena_half_size: float = 58.0
@export var wall_padding: float = 3.0

# Keep spawns away from cars
@export var avoid_radius_player: float = 10.0
@export var avoid_radius_enemy: float = 10.0
@export var player_path: NodePath = NodePath("../Soapbox")
@export var enemy_path: NodePath = NodePath("../EnemySoapbox")

# Deterministic layout (0 = random every run)
@export var seed: int = 0

# Sizes
@export var box_size_min: Vector3 = Vector3(0.7, 0.7, 0.7)
@export var box_size_max: Vector3 = Vector3(4.0, 3.0, 4.0)

@export var cyl_radius_min: float = 0.5
@export var cyl_radius_max: float = 2.5
@export var cyl_height_min: float = 0.7
@export var cyl_height_max: float = 4.0

# Physics feel
@export var base_mass: float = 6.0
@export var mass_per_volume: float = 0.35   # bigger obstacles weigh more
@export var linear_damp: float = 0.2
@export var angular_damp: float = 0.3
@export var friction: float = 1.1
@export var bounce: float = 0.05

var _rng := RandomNumberGenerator.new()

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

func _random_pos() -> Vector3:
	var limit := arena_half_size - wall_padding
	return Vector3(
		_rng.randf_range(-limit, limit),
		0.0,
		_rng.randf_range(-limit, limit)
	)

func _make_random_obstacle() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Obstacle"
	body.linear_damp = linear_damp
	body.angular_damp = angular_damp
	body.continuous_cd = true

	# Physics material (friction/bounce)
	var phys := PhysicsMaterial.new()
	phys.friction = friction
	phys.bounce = bounce
	body.physics_material_override = phys

	var collision := CollisionShape3D.new()
	var mesh_inst := MeshInstance3D.new()

	# Random color material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(_rng.randf(), 0.75, 0.95) # bright-ish random colors
	mesh_inst.material_override = mat

	# Choose shape type
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

	# Mass scaling so big chunks feel heavy
	body.mass = base_mass + volume_estimate * mass_per_volume

	body.add_child(collision)
	body.add_child(mesh_inst)
	return body
