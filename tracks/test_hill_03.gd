extends Node3D

# =========================================================
# NURBURGER RING
# =========================================================
# A longer lap-style testing circuit.
#
# This track is designed for:
# - repeated lap testing
# - longer sustained race sessions
# - obstacle / jump stress tests
# - no falling off the sides
#
# Important:
# The lap counter for this track is routed through the shared HUD.
# =========================================================

@export var player_scene: PackedScene
@export var target_laps: int = 999

@onready var spawn: Marker3D = $Spawn

var _player: Node3D
var _hud: Node = null
var _finish: Area3D
var _lap_count: int = 0
var _lap_gate_open: bool = true

# =========================================================
# TRACK SHAPE TUNING
# =========================================================
const TRACK_WIDTH: float = 20.0
const TRACK_THICKNESS: float = 1.0
const WALL_HEIGHT: float = 4.0
const WALL_THICKNESS: float = 1.5

# =========================================================
# SPAWN / PIT LANE TUNING
# =========================================================
# This is now treated more like a pit lane than a perpendicular ramp.
# The player starts slightly above the track and merges in at an angle.
# =========================================================
const PIT_WIDTH: float = 16.0
const PIT_START: Vector3 = Vector3(-28.0, 12.0, 132.0)
const PIT_MID_A: Vector3 = Vector3(-22.0, 11.6, 118.0)
const PIT_MID_B: Vector3 = Vector3(-12.0, 10.6, 108.0)
const PIT_JOIN: Vector3 = Vector3(-4.0, 9.7, 100.0)

# =========================================================
# FINISH LINE TUNING
# =========================================================
# Moved further forward on the main straight so it does not interfere
# with the spawn / pit merge.
# =========================================================
const FINISH_POS: Vector3 = Vector3(24.0, 8.95, 96.0)


# =========================================================
# READY
# =========================================================
func _ready() -> void:
	if player_scene == null:
		var scene_path: String = "res://vehicles/platform_4w.tscn"
		if has_node("/root/SBSettings"):
			scene_path = SBSettings.get_current_platform_scene_path()
		player_scene = load(scene_path)

	_build_track()
	_spawn_player()
	_update_lap_hud()


# =========================================================
# TRACK BUILD
# =========================================================
func _build_track() -> void:
	var track_root := Node3D.new()
	track_root.name = "TrackRoot"
	add_child(track_root)

	# =====================================================
	# MATERIALS
	# =====================================================
	var track_mat := StandardMaterial3D.new()
	track_mat.albedo_color = Color(0.16, 0.16, 0.18)
	track_mat.roughness = 0.9

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.52, 0.15, 0.12)
	wall_mat.roughness = 0.85

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = Color(0.82, 0.78, 0.30)
	accent_mat.roughness = 0.75

	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.11, 0.28, 0.11)
	grass_mat.roughness = 1.0

	# =====================================================
	# BASE GROUND
	# =====================================================
	_make_static_box(
		track_root,
		"Ground",
		Vector3(320, 2, 320),
		Vector3(0, -2, 0),
		Basis.IDENTITY,
		grass_mat
	)

	# =====================================================
	# MAIN LOOP POINTS
	# =====================================================
	var seg_points: Array[Dictionary] = []

	_append_straight(seg_points, Vector3(-96, 9.5, 96), Vector3(96, 5.5, 96), 6)
	_append_arc(seg_points, Vector3(96, 4.0, 64), 32.0, deg_to_rad(90.0), deg_to_rad(0.0), 6)
	_append_straight(seg_points, Vector3(128, 3.5, 64), Vector3(128, -1.0, -64), 7)
	_append_arc(seg_points, Vector3(96, -2.0, -64), 32.0, deg_to_rad(0.0), deg_to_rad(-90.0), 6)
	_append_straight(seg_points, Vector3(96, -2.0, -96), Vector3(-96, -4.0, -96), 8)
	_append_arc(seg_points, Vector3(-96, -3.5, -64), 32.0, deg_to_rad(-90.0), deg_to_rad(-180.0), 6)
	_append_straight(seg_points, Vector3(-128, -2.5, -64), Vector3(-128, 4.5, 64), 7)
	_append_arc(seg_points, Vector3(-96, 6.5, 64), 32.0, deg_to_rad(180.0), deg_to_rad(90.0), 6)

	var walls := Node3D.new()
	walls.name = "Walls"
	track_root.add_child(walls)

	for i: int in range(seg_points.size() - 1):
		var a: Vector3 = seg_points[i]["pos"]
		var b: Vector3 = seg_points[i + 1]["pos"]
		_make_track_segment(track_root, walls, "LoopSeg_%02d" % i, a, b, track_mat, wall_mat)

	# =====================================================
	# PIT LANE / SPAWN ENTRY
	# =====================================================
	# This replaces the old perpendicular feeder with a shallow-angle
	# merge lane so the player can join the track more naturally.
	# Abandoned for a later time perhaps
	# =====================================================
	#_make_custom_track_segment(
	#	track_root,
	#	walls,
	#	"PitLane_A",
	#	PIT_START,
	#	PIT_MID_A,
	#	PIT_WIDTH,
	#	track_mat,
	#	wall_mat
	#)
	#
	#_make_custom_track_segment(
	#	track_root,
	#	walls,
	#	"PitLane_B",
	#	PIT_MID_A,
	#	PIT_MID_B,
	#	PIT_WIDTH,
	#	track_mat,
	#	wall_mat
	#)
	#
	#_make_custom_track_segment(
	#	track_root,
	#	walls,
	#	"PitLane_C",
	#	PIT_MID_B,
	#	PIT_JOIN,
	#	PIT_WIDTH,
	#	track_mat,
	#	wall_mat
	#)

	# Rear wall to stop the player reversing out of spawn.
	#_make_static_box(
	#	walls,
	#	"PitRearWall",
	#	Vector3(PIT_WIDTH + 2.0, WALL_HEIGHT, WALL_THICKNESS),
	#	PIT_START + Vector3(0.0, (WALL_HEIGHT * 0.5) - 0.1, 3.5),
	#	Basis.IDENTITY,
	#	wall_mat
	#)

	# =====================================================
	# FINISH / LAP COUNTER LINE
	# =====================================================
	_create_finish_line(track_root, accent_mat)

	# =====================================================
	# JUMPS
	# =====================================================
	_make_jump(track_root, walls, "JumpEast", Vector3(128, 1.5, -6), Basis(Vector3(1, 0, 0), deg_to_rad(-16.0)), 18.0, track_mat, wall_mat)
	_make_jump(track_root, walls, "JumpWest", Vector3(-128, 1.0, -6), Basis(Vector3(1, 0, 0), deg_to_rad(14.0)), 16.0, track_mat, wall_mat)

	# =====================================================
	# OBSTACLES
	# =====================================================
	_make_blocker(track_root, "NorthObstacleA", Vector3(32, 6.9, 96), Vector3(3, 3, 3), wall_mat)
	_make_blocker(track_root, "NorthObstacleB", Vector3(-18, 7.7, 96), Vector3(4, 4, 4), wall_mat)

	_make_blocker(track_root, "EastObstacleA", Vector3(128, 1.0, 40), Vector3(3, 5, 3), wall_mat)
	_make_blocker(track_root, "EastObstacleB", Vector3(128, -0.5, -26), Vector3(5, 2.5, 5), wall_mat)

	_make_blocker(track_root, "SouthObstacleA", Vector3(42, -2.2, -96), Vector3(4, 3, 4), wall_mat)
	_make_blocker(track_root, "SouthObstacleB", Vector3(-36, -3.0, -96), Vector3(3, 4, 3), wall_mat)

	_make_blocker(track_root, "WestObstacleA", Vector3(-128, 0.4, 38), Vector3(4, 3, 4), wall_mat)
	_make_blocker(track_root, "WestObstacleB", Vector3(-128, -0.8, -34), Vector3(3, 5, 3), wall_mat)


# =========================================================
# POINT HELPERS
# =========================================================
func _append_straight(points: Array[Dictionary], start_pos: Vector3, end_pos: Vector3, slices: int) -> void:
	for i: int in range(slices + 1):
		var t: float = float(i) / float(slices)
		var pos: Vector3 = start_pos.lerp(end_pos, t)

		if points.is_empty() or points[points.size() - 1]["pos"] != pos:
			points.append({"pos": pos})


func _append_arc(points: Array[Dictionary], center: Vector3, radius: float, start_angle: float, end_angle: float, slices: int) -> void:
	for i: int in range(slices + 1):
		var t: float = float(i) / float(slices)
		var angle: float = lerpf(start_angle, end_angle, t)
		var y: float = center.y + lerpf(1.5, -1.5, t)

		var pos: Vector3 = Vector3(
			center.x + cos(angle) * radius,
			y,
			center.z + sin(angle) * radius
		)

		if points.is_empty() or points[points.size() - 1]["pos"] != pos:
			points.append({"pos": pos})


# =========================================================
# STANDARD TRACK SEGMENT
# =========================================================
func _make_track_segment(
	track_root: Node,
	walls_root: Node,
	name: String,
	start_pos: Vector3,
	end_pos: Vector3,
	track_material: Material,
	wall_material: Material
) -> void:
	_make_custom_track_segment(
		track_root,
		walls_root,
		name,
		start_pos,
		end_pos,
		TRACK_WIDTH,
		track_material,
		wall_material
	)


# =========================================================
# CUSTOM TRACK SEGMENT
# =========================================================
# Same as the normal segment builder, but lets us set a custom width.
# Useful for pit lanes, merges, and special track pieces.
# =========================================================
func _make_custom_track_segment(
	track_root: Node,
	walls_root: Node,
	name: String,
	start_pos: Vector3,
	end_pos: Vector3,
	segment_width: float,
	track_material: Material,
	wall_material: Material
) -> void:
	var delta: Vector3 = end_pos - start_pos
	var length: float = delta.length()
	if length <= 0.1:
		return

	var center: Vector3 = start_pos.lerp(end_pos, 0.5)
	var basis: Basis = Basis.looking_at(delta.normalized(), Vector3.UP)

	_make_static_box(
		track_root,
		name,
		Vector3(segment_width, TRACK_THICKNESS, length),
		center,
		basis,
		track_material
	)

	var half_track: float = segment_width * 0.5
	var half_wall: float = WALL_THICKNESS * 0.5
	var wall_size: Vector3 = Vector3(WALL_THICKNESS, WALL_HEIGHT, length)

	var left_pos: Vector3 = center + (basis * Vector3(-(half_track + half_wall), (WALL_HEIGHT * 0.5) - 0.1, 0))
	var right_pos: Vector3 = center + (basis * Vector3((half_track + half_wall), (WALL_HEIGHT * 0.5) - 0.1, 0))

	_make_static_box(walls_root, "%s_WallLeft" % name, wall_size, left_pos, basis, wall_material)
	_make_static_box(walls_root, "%s_WallRight" % name, wall_size, right_pos, basis, wall_material)


# =========================================================
# JUMP CREATION
# =========================================================
func _make_jump(
	track_root: Node,
	walls_root: Node,
	name: String,
	center: Vector3,
	basis: Basis,
	length: float,
	track_material: Material,
	wall_material: Material
) -> void:
	var jump_size: Vector3 = Vector3(TRACK_WIDTH, TRACK_THICKNESS, length)
	_make_static_box(track_root, name, jump_size, center, basis, track_material)

	var wall_size: Vector3 = Vector3(WALL_THICKNESS, WALL_HEIGHT, length)
	var half_track: float = TRACK_WIDTH * 0.5
	var half_wall: float = WALL_THICKNESS * 0.5

	var left_pos: Vector3 = center + (basis * Vector3(-(half_track + half_wall), (WALL_HEIGHT * 0.5) - 0.1, 0))
	var right_pos: Vector3 = center + (basis * Vector3((half_track + half_wall), (WALL_HEIGHT * 0.5) - 0.1, 0))

	_make_static_box(walls_root, "%s_WallLeft" % name, wall_size, left_pos, basis, wall_material)
	_make_static_box(walls_root, "%s_WallRight" % name, wall_size, right_pos, basis, wall_material)


# =========================================================
# FINISH / LAP TRIGGER
# =========================================================
func _create_finish_line(track_root: Node, accent_material: Material) -> void:
	_finish = Area3D.new()
	_finish.name = "Finish"
	track_root.add_child(_finish)
	_finish.monitoring = true
	_finish.monitorable = true
	_finish.collision_layer = 1
	_finish.collision_mask = 1

	# Finish line is now further along the main straight so it stays
	# clear of the pit lane merge area.
	_finish.global_position = FINISH_POS
	_finish.global_basis = Basis(Vector3.UP, deg_to_rad(90.0))

	var finish_col := CollisionShape3D.new()
	finish_col.name = "Col_Finish"
	var finish_shape := BoxShape3D.new()
	finish_shape.size = Vector3(18, 5, 6)
	finish_col.shape = finish_shape
	_finish.add_child(finish_col)

	var stripe := MeshInstance3D.new()
	stripe.name = "FinishStripe"
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(18, 0.12, 4)
	stripe.mesh = stripe_mesh
	stripe.material_override = accent_material
	track_root.add_child(stripe)
	stripe.global_position = FINISH_POS + Vector3(0.0, 0.01, 0.0)
	stripe.global_basis = Basis(Vector3.UP, deg_to_rad(-90.0))

	# Pylons moved with the finish line so they stay at the stripe ends.
	_make_blocker(track_root, "FinishPylonLeft", FINISH_POS + Vector3(0.0, 2.6, -9.0), Vector3(1.2, 5.0, 1.2), accent_material)
	_make_blocker(track_root, "FinishPylonRight", FINISH_POS + Vector3(0.0, 2.6, 9.0), Vector3(1.2, 5.0, 1.2), accent_material)

	_finish.body_entered.connect(_on_finish_body_entered)


# =========================================================
# SIMPLE STATIC BOX
# =========================================================
func _make_static_box(
	parent: Node,
	name: String,
	size: Vector3,
	pos: Vector3,
	basis: Basis,
	material: Material,
	make_mesh: bool = true
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	parent.add_child(body)

	body.collision_layer = 1
	body.collision_mask = 1
	body.global_position = pos
	body.global_basis = basis

	var col := CollisionShape3D.new()
	col.name = "Col_" + name
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	if make_mesh:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_" + name
		var mesh := BoxMesh.new()
		mesh.size = size
		mi.mesh = mesh
		mi.material_override = material
		body.add_child(mi)

	return body


# =========================================================
# SIMPLE OBSTACLE
# =========================================================
func _make_blocker(parent: Node, name: String, pos: Vector3, size: Vector3, material: Material) -> void:
	_make_static_box(parent, name, size, pos, Basis.IDENTITY, material)


# =========================================================
# PLAYER + HUD
# =========================================================
func _spawn_player() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()

	_player = player_scene.instantiate()
	add_child(_player)
	_player.global_position = spawn.global_position
	_player.global_rotation = spawn.global_rotation
	_player.add_to_group("player")

	if _hud and is_instance_valid(_hud):
		_hud.queue_free()

	_hud = preload("res://damage_hud.tscn").instantiate()
	add_child(_hud)

	var cam := _player.find_child("Camera", true, false) as Camera3D
	if cam:
		cam.current = true
		cam.make_current()
	else:
		push_error("No Camera3D found anywhere under the player instance.")


# =========================================================
# LAP HUD UPDATE
# =========================================================
func _update_lap_hud() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return

	if _hud.has_method("set_lap_counter_enabled"):
		_hud.call("set_lap_counter_enabled", true)

	if _hud.has_method("set_lap_counter"):
		_hud.call("set_lap_counter", "Nurburger Ring", max(_lap_count, 1))


# =========================================================
# LAP TRIGGER
# =========================================================
func _on_finish_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if not _lap_gate_open:
		return

	_lap_gate_open = false
	_lap_count += 1
	_update_lap_hud()
	_reset_lap_gate_later()


func _reset_lap_gate_later() -> void:
	await get_tree().create_timer(1.5).timeout
	_lap_gate_open = true
