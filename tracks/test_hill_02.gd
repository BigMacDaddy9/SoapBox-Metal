extends Node3D

# =========================================================
# TEST HILL 02
# =========================================================
# Procedurally builds a more advanced downhill test track with:
# - angled turns (debatable turns at best)
# - a jump ramp
# - a landing section
# - a final straight
# - side walls and end caps
# - a finish trigger
#
# Also responsible for:
# - spawning the player
# - attaching the damage HUD
# - displaying a win message on completion
# =========================================================

# =========================================================
# EXPORT VARIABLES
# =========================================================
# Optional player scene override. Falls back to SBSettings.
# =========================================================
@export var player_scene: PackedScene

# =========================================================
# NODE REFERENCES
# =========================================================
# Spawn point for the player.
# =========================================================
@onready var spawn := $Spawn as Marker3D

# =========================================================
# RUNTIME STATE
# =========================================================
var _player: Node3D
var _finish: Area3D
var _hud: Node = null
var _win_layer: CanvasLayer
var _win_label: Label

# =========================================================
# READY
# =========================================================
# Initializes the track and spawns the player.
# =========================================================
func _ready() -> void:
	if player_scene == null:
		var scene_path := "res://vehicles/platform_4w.tscn"
		if has_node("/root/SBSettings"):
			scene_path = SBSettings.get_current_platform_scene_path()
		player_scene = load(scene_path)

	_build_track()
	_spawn_player()

# =========================================================
# SEGMENT POSITION HELPERS
# =========================================================
# Utility functions for calculating segment connections.
# =========================================================
func _segment_end_pos(center_pos: Vector3, basis: Basis, length: float) -> Vector3:
	return center_pos + (basis * Vector3(0, 0, length * 0.5))

func _segment_start_pos(center_pos: Vector3, basis: Basis, length: float) -> Vector3:
	return center_pos - (basis * Vector3(0, 0, length * 0.5))

# =========================================================
# TRACK BUILDING
# =========================================================
# Builds the entire downhill track dynamically:
# - segments
# - turns
# - jump / landing section
# - walls
# - start/end caps
# - finish trigger
# =========================================================
func _build_track() -> void:
	var track_root := Node3D.new()
	track_root.name = "TrackRoot"
	add_child(track_root)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.20)

	var seg_size := Vector3(18, 1, 36)
	var seg_len := seg_size.z
	var wall_size := Vector3(1.5, 3.0, seg_size.z)

	# =========================================================
	# START PAD
	# =========================================================
	_make_static_box(track_root, "StartPad", Vector3(10, 1, 10), Vector3(0, 7.5, 10), Basis.IDENTITY, mat)

	# =========================================================
	# TRACK SEGMENT 1
	# =========================================================
	var b1 := Basis(Vector3(1, 0, 0), deg_to_rad(10.0))
	var p1 := Vector3(0, 6, 15)
	_make_static_box(track_root, "TrackSeg1", seg_size, p1, b1, mat)

	# =========================================================
	# TRACK SEGMENT 2
	# =========================================================
	# Slight right turn
	var b2 := Basis(Vector3.UP, deg_to_rad(12.0)) * Basis(Vector3(1, 0, 0), deg_to_rad(12.0))
	var p2 := _segment_end_pos(p1, b1, seg_len) + (b2 * Vector3(0, 0, seg_len * 0.5))
	_make_static_box(track_root, "TrackSeg2", seg_size, p2, b2, mat)

	# =========================================================
	# TRACK SEGMENT 3
	# =========================================================
	# More turn
	var b3 := Basis(Vector3.UP, deg_to_rad(22.0)) * Basis(Vector3(1, 0, 0), deg_to_rad(10.0))
	var p3 := _segment_end_pos(p2, b2, seg_len) + (b3 * Vector3(0, 0, seg_len * 0.5))
	_make_static_box(track_root, "TrackSeg3", seg_size, p3, b3, mat)

	# =========================================================
	# JUMP RAMP
	# =========================================================
	var jump_len := 24.0
	var jump_size := Vector3(18, 1, jump_len)
	var b4 := Basis(Vector3.UP, deg_to_rad(22.0)) * Basis(Vector3(1, 0, 0), deg_to_rad(18.0))
	var p4 := _segment_end_pos(p3, b3, seg_len) + (b4 * Vector3(0, 0, jump_len * 0.5))
	_make_static_box(track_root, "JumpRamp", jump_size, p4, b4, mat)

	# =========================================================
	# LANDING SEGMENT
	# =========================================================
	# Landing section after the jump gap
	var gap_len := 12.0
	var landing_len := 34.0
	var landing_size := Vector3(18, 1, landing_len)
	var b5 := Basis(Vector3.UP, deg_to_rad(22.0)) * Basis(Vector3(1, 0, 0), deg_to_rad(8.0))
	var jump_end := _segment_end_pos(p4, b4, jump_len)
	var p5 := jump_end + (b4 * Vector3(0, 0, gap_len)) + (b5 * Vector3(0, 0, landing_len * 0.5))
	_make_static_box(track_root, "LandingSeg", landing_size, p5, b5, mat)

	# =========================================================
	# FINAL STRAIGHT
	# =========================================================
	var b6 := Basis(Vector3.UP, deg_to_rad(22.0)) * Basis.IDENTITY
	var final_len := 44.0
	var final_size := Vector3(18, 1, final_len)
	var p6 := _segment_end_pos(p5, b5, landing_len) + (b6 * Vector3(0, 0, final_len * 0.5))
	_make_static_box(track_root, "FinalSeg", final_size, p6, b6, mat)

	# =========================================================
	# WALLS
	# =========================================================
	var walls := Node3D.new()
	walls.name = "Walls"
	track_root.add_child(walls)

	_add_walls_for_segment(walls, p1, b1, seg_size, wall_size, mat, "Seg1")
	_add_walls_for_segment(walls, p2, b2, seg_size, wall_size, mat, "Seg2")
	_add_walls_for_segment(walls, p3, b3, seg_size, wall_size, mat, "Seg3")
	_add_walls_for_segment(walls, p4, b4, jump_size, Vector3(1.5, 3.0, jump_len), mat, "JumpRamp")
	_add_walls_for_segment(walls, p5, b5, landing_size, Vector3(1.5, 3.0, landing_len), mat, "LandingSeg")
	_add_walls_for_segment(walls, p6, b6, final_size, Vector3(1.5, 3.0, final_len), mat, "FinalSeg")

	var start_cap_pos := _segment_start_pos(p1, b1, seg_len)
	_add_end_cap(walls, "StartGate", start_cap_pos, b1, seg_size, 2.0, 4.0, mat)

	var end_cap_pos := _segment_end_pos(p6, b6, final_len)
	_add_end_cap(walls, "EndGate", end_cap_pos, b6, final_size, 2.0, 4.0, mat)

	# =========================================================
	# FINISH TRIGGER
	# =========================================================
	_finish = Area3D.new()
	_finish.name = "Finish"
	track_root.add_child(_finish)
	_finish.monitoring = true
	_finish.monitorable = true
	_finish.collision_layer = 1
	_finish.collision_mask = 1

	var finish_center := _segment_end_pos(p6, b6, final_len) + Vector3(0, 2.0, -2.0)
	_finish.global_position = finish_center
	_finish.global_basis = b6

	var finish_col := CollisionShape3D.new()
	finish_col.name = "Col_Finish"
	finish_col.disabled = false

	var finish_shape := BoxShape3D.new()
	finish_shape.size = Vector3(final_size.x, 4, 6)
	finish_col.shape = finish_shape
	_finish.add_child(finish_col)

	_finish.body_entered.connect(_on_finish_body_entered)

# =========================================================
# STATIC BOX HELPER
# =========================================================
# Creates a collision + optional mesh box.
# =========================================================
func _make_static_box(parent: Node, name: String, size: Vector3, pos: Vector3, basis: Basis, material: Material, make_mesh: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	parent.add_child(body)

	body.collision_layer = 1
	body.collision_mask = 1
	body.global_position = pos
	body.global_basis = basis

	var col := CollisionShape3D.new()
	col.name = "Col_" + name
	col.disabled = false

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
# WALL HELPERS
# =========================================================
func _add_walls_for_segment(parent: Node, seg_center: Vector3, seg_basis: Basis, seg_size: Vector3, wall_size: Vector3, material: Material, name_prefix: String) -> void:
	var half_w := seg_size.x * 0.5
	var wall_half_w := wall_size.x * 0.5

	var x_left := -(half_w + wall_half_w)
	var x_right := +(half_w + wall_half_w)

	var left_world := seg_center + (seg_basis * Vector3(x_left, 0, 0))
	var right_world := seg_center + (seg_basis * Vector3(x_right, 0, 0))

	_make_static_box(parent, name_prefix + "_WallLeft", wall_size, left_world, seg_basis, material)
	_make_static_box(parent, name_prefix + "_WallRight", wall_size, right_world, seg_basis, material)

func _add_end_cap(parent: Node, name: String, cap_center: Vector3, seg_basis: Basis, seg_size: Vector3, cap_thickness: float, cap_height: float, material: Material) -> void:
	var cap_size := Vector3(seg_size.x + 3.0, cap_height, cap_thickness)
	_make_static_box(parent, name, cap_size, cap_center, seg_basis, material)

# =========================================================
# PLAYER SPAWNING
# =========================================================
# Spawns the player and attaches the damage HUD.
# =========================================================
func _spawn_player() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()

	_player = player_scene.instantiate()
	add_child(_player)
	_player.global_position = spawn.global_position
	_player.global_rotation = spawn.global_rotation
	_player.add_to_group("player")

	# =========================================================
	# DAMAGE HUD
	# =========================================================
	if _hud and is_instance_valid(_hud):
		_hud.queue_free()

	_hud = preload("res://damage_hud.tscn").instantiate()
	add_child(_hud)

	# =========================================================
	# CAMERA SETUP
	# =========================================================
	var cam := _player.find_child("Camera", true, false) as Camera3D
	if cam:
		cam.current = true
		cam.make_current()
	else:
		push_error("No Camera3D found anywhere under the player instance.")

# =========================================================
# WIN UI
# =========================================================
# Displays a win message when the player reaches the finish.
# =========================================================
func _show_win_message() -> void:
	if _win_layer == null:
		_win_layer = CanvasLayer.new()
		_win_layer.name = "WinUI"
		add_child(_win_layer)

		_win_label = Label.new()
		_win_label.name = "WinLabel"
		_win_label.text = "You are win"
		_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_win_label.anchor_left = 0.0
		_win_label.anchor_top = 0.0
		_win_label.anchor_right = 1.0
		_win_label.anchor_bottom = 1.0
		_win_label.add_theme_font_size_override("font_size", 64)

		_win_layer.add_child(_win_label)
	else:
		_win_label.text = "You are win"

# =========================================================
# FINISH TRIGGER
# =========================================================
# Called when a body enters the finish area.
# =========================================================
func _on_finish_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_show_win_message()
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)