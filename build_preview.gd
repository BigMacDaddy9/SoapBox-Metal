extends Node3D

# =========================================================
# BUILD PREVIEW
# =========================================================
# Live 3D preview used in the build menu.
#
# This script:
# - spawns the currently selected platform
# - applies the selected base and parts
# - optionally rotates the preview for presentation
# =========================================================

# =========================================================
# EXPORT VARIABLES
# =========================================================
@export var rotate_speed: float = 0.5

# =========================================================
# RUNTIME STATE
# =========================================================
var _current_vehicle: Node3D = null
var _rotate_preview: bool = true

var _platform_name: String = "four_wheeler"
var _base_name: String = "light"
var _selected_parts: Dictionary = {}

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	_selected_parts = SBSettings.get_sanitized_selected_parts().duplicate(true)
	_rebuild_preview()

# =========================================================
# PROCESS
# =========================================================
# Rotates the preview stand/vehicle when preview rotation is enabled.
# =========================================================
func _process(delta: float) -> void:
	if not _rotate_preview:
		return

	if _current_vehicle != null and is_instance_valid(_current_vehicle):
		_current_vehicle.rotate_y(rotate_speed * delta)

# =========================================================
# BUILD INPUT
# =========================================================
# Called by the build menu when the pending build changes.
# =========================================================
func set_build(platform_name: String, base_name: String, selected_parts: Dictionary) -> void:
	_platform_name = platform_name
	_base_name = base_name
	_selected_parts = selected_parts.duplicate(true)
	_rebuild_preview()

func set_rotate_preview(enabled: bool) -> void:
	_rotate_preview = enabled

# =========================================================
# PREVIEW REBUILD
# =========================================================
func _rebuild_preview() -> void:
	if _current_vehicle != null and is_instance_valid(_current_vehicle):
		_current_vehicle.queue_free()
		_current_vehicle = null

	var scene_path: String = SBSettings.get_platform_scene_path(_platform_name)
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		return

	var instance := packed.instantiate() as Node3D
	if instance == null:
		return

	add_child(instance)
	_current_vehicle = instance

	if _current_vehicle is VehicleBody3D:
		var body := _current_vehicle as VehicleBody3D
		body.freeze = true
		body.sleeping = true

	VehicleBuilder.apply_complete_build(_current_vehicle, _base_name, _selected_parts)
