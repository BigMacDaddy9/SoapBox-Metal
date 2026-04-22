extends Node

# =========================================================
# GAME SETTINGS
# =========================================================
# Shared global build state used by:
# - the build menu
# - the build preview
# - gameplay vehicle spawning
#
# This script stores the currently selected platform, base,
# part loadout, and part tuning data.
# =========================================================

# =========================================================
# GLOBAL BUILD STATE
# =========================================================
var ai_enabled: bool = true
var selected_base: String = "light"
var selected_platform: String = "four_wheeler"
var selected_parts: Dictionary = {
	"FrontBumperMount": "",
	"RearBumperMount": "",
	"LeftRailMount": "",
	"RightRailMount": "",
	"SeatMount": "",
	"NoseMount": ""
}

# =========================================================
# BASE PRESETS
# =========================================================
# Defines the currently available chassis/base options and
# how they affect mass, durability, and steering.
# =========================================================
var base_presets := {
	"light": {
		"display_name": "Light Base",
		"mass": 85.0,
		"push_force_mult": 1.15,
		"durability_mult": 0.85,
		"steer_mult": 1.05
	},
	"heavy": {
		"display_name": "Heavy Base",
		"mass": 130.0,
		"push_force_mult": 0.90,
		"durability_mult": 1.25,
		"steer_mult": 0.90
	},
	"thin": {
		"display_name": "Light Base",
		"mass": 85.0,
		"push_force_mult": 1.15,
		"durability_mult": 0.85,
		"steer_mult": 1.05
	}
}

# =========================================================
# PLATFORM PRESETS
# =========================================================
# Platform definitions map a platform ID to its display name
# and the scene used when spawning it.
# =========================================================
var platform_presets := {
	"four_wheeler": {
		"display_name": "4 Wheeler",
		"scene_path": "res://vehicles/platform_4w.tscn"
	},
	"three_wheeler": {
		"display_name": "3 Wheeler",
		"scene_path": "res://vehicles/platform_3w.tscn"
	},
	"two_wheeler": {
		"display_name": "2 Wheeler",
		"scene_path": "res://vehicles/platform_2w.tscn"
	}
}

# =========================================================
# BUILD MENU ORDER / LABELS
# =========================================================
# Controls the order and display naming of mount points in the UI.
# =========================================================
var build_mount_order: Array[String] = [
	"FrontBumperMount",
	"RearBumperMount",
	"LeftRailMount",
	"RightRailMount",
	"SeatMount",
	"NoseMount"
]

var build_mount_display_names := {
	"FrontBumperMount": "Front Bumper",
	"RearBumperMount": "Rear Bumper",
	"LeftRailMount": "Left Rail",
	"RightRailMount": "Right Rail",
	"SeatMount": "Seat",
	"NoseMount": "Nose"
}

# =========================================================
# PART PRESETS
# =========================================================
# Maps logical part IDs to their display names and scene files.
# =========================================================
var part_presets := {
	"basic_front_bumper": {
		"display_name": "Basic Front Bumper",
		"scene_path": "res://parts/basic_front_bumper.tscn"
	},
	"basic_rear_bumper": {
		"display_name": "Basic Rear Bumper",
		"scene_path": "res://parts/basic_rear_bumper.tscn"
	},
	"left_side_panel": {
		"display_name": "Left Side Panel",
		"scene_path": "res://parts/left_side_panel.tscn"
	},
	"right_side_panel": {
		"display_name": "Right Side Panel",
		"scene_path": "res://parts/right_side_panel.tscn"
	},
	"crate_seat": {
		"display_name": "Crate Seat",
		"scene_path": "res://parts/crate_seat.tscn"
	},
	"nose_cone": {
		"display_name": "Nose Cone",
		"scene_path": "res://parts/nose_cone.tscn"
	},
	"legacy_hat": {
		"display_name": "Legacy Hat",
		"scene_path": "res://parts/legacy_hat.tscn"
	},
	"modern_hat": {
		"display_name": "Modern Hat",
		"scene_path": "res://parts/modern_hat.tscn"
	}
}

# =========================================================
# PART JOINT PROFILES
# =========================================================
# Physics tuning for each modular part.
#
# These values drive:
# - mass
# - spring limits
# - angular stiffness / damping
# - break thresholds
# - multi-joint mounting offsets
# =========================================================
var part_joint_profiles := {
	"basic_front_bumper": {
		"mass": 2.6,
		"linear_limit": 0.01,
		"angular_limit_deg": 8.0,
		"angular_stiffness": 8.5,
		"angular_damping": 1.6,
		"linear_damp": 2.2,
		"body_angular_damp": 1.4,
		"break_force": 22.0,
		"joint_offsets": [
			Vector3(-1.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0)
		]
	},
	"basic_rear_bumper": {
		"mass": 2.6,
		"linear_limit": 0.01,
		"angular_limit_deg": 8.0,
		"angular_stiffness": 8.5,
		"angular_damping": 1.6,
		"linear_damp": 2.2,
		"body_angular_damp": 1.4,
		"break_force": 22.0,
		"joint_offsets": [
			Vector3(-1.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0)
		]
	},
	"left_side_panel": {
		"mass": 1.8,
		"linear_limit": 0.01,
		"angular_limit_deg": 7.0,
		"angular_stiffness": 9.0,
		"angular_damping": 1.8,
		"linear_damp": 2.3,
		"body_angular_damp": 1.5,
		"break_force": 18.0,
		"joint_offsets": [
			Vector3(0.0, 0.0, 1.2),
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.0, 0.0, -1.2)
		]
	},
	"right_side_panel": {
		"mass": 1.8,
		"linear_limit": 0.01,
		"angular_limit_deg": 7.0,
		"angular_stiffness": 9.0,
		"angular_damping": 1.8,
		"linear_damp": 2.3,
		"body_angular_damp": 1.5,
		"break_force": 18.0,
		"joint_offsets": [
			Vector3(0.0, 0.0, 1.2),
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.0, 0.0, -1.2)
		]
	},
	"crate_seat": {
		"mass": 2.2,
		"linear_limit": 0.008,
		"angular_limit_deg": 6.0,
		"angular_stiffness": 10.0,
		"angular_damping": 2.0,
		"linear_damp": 2.5,
		"body_angular_damp": 1.7,
		"break_force": 30.0,
		"joint_offsets": [
			Vector3(-0.4, 0.0, 0.35),
			Vector3(0.4, 0.0, 0.35),
			Vector3(-0.4, 0.0, -0.35),
			Vector3(0.4, 0.0, -0.35)
		]
	},
	"nose_cone": {
		"mass": 1.3,
		"linear_limit": 0.01,
		"angular_limit_deg": 7.0,
		"angular_stiffness": 8.5,
		"angular_damping": 1.5,
		"linear_damp": 2.0,
		"body_angular_damp": 1.2,
		"break_force": 16.0,
		"joint_offsets": [
			Vector3.ZERO
		]
	},
	"legacy_hat": {
		"mass": 0.9,
		"linear_limit": 0.015,
		"angular_limit_deg": 10.0,
		"angular_stiffness": 6.0,
		"angular_damping": 1.0,
		"linear_damp": 1.3,
		"body_angular_damp": 0.9,
		"break_force": 8.0,
		"joint_offsets": [
			Vector3.ZERO
		]
	},
	"modern_hat": {
		"mass": 0.25,
		"linear_limit": 0.02,
		"angular_limit_deg": 12.0,
		"angular_stiffness": 5.0,
		"angular_damping": 0.9,
		"linear_damp": 1.0,
		"body_angular_damp": 0.7,
		"break_force": 5.0,
		"joint_offsets": [
			Vector3.ZERO
		]
	},
	"default": {
		"mass": 1.5,
		"linear_limit": 0.01,
		"angular_limit_deg": 8.0,
		"angular_stiffness": 8.0,
		"angular_damping": 1.5,
		"linear_damp": 2.0,
		"body_angular_damp": 1.2,
		"break_force": 18.0,
		"joint_offsets": [
			Vector3.ZERO
		]
	}
}

# =========================================================
# READY
# =========================================================
# Normalize legacy values when the settings singleton wakes up.
# =========================================================
func _ready() -> void:
	if selected_base == "none" or selected_base == "thin":
		selected_base = "light"

	selected_parts = get_sanitized_selected_parts()

# =========================================================
# PRESET ACCESSORS
# =========================================================
func get_current_base() -> Dictionary:
	if base_presets.has(selected_base):
		return base_presets[selected_base]
	return base_presets["light"]

func get_current_platform() -> Dictionary:
	if platform_presets.has(selected_platform):
		return platform_presets[selected_platform]
	return platform_presets["four_wheeler"]

func get_platform_scene_path(platform_name: String) -> String:
	if platform_presets.has(platform_name):
		var scene_path := str(platform_presets[platform_name].get("scene_path", ""))
		if scene_path != "" and ResourceLoader.exists(scene_path):
			return scene_path

	return "res://vehicles/platform_4w.tscn"

func get_current_platform_scene_path() -> String:
	return get_platform_scene_path(selected_platform)

# =========================================================
# DISPLAY HELPERS
# =========================================================
func get_mount_display_name(mount_name: String) -> String:
	if build_mount_display_names.has(mount_name):
		return str(build_mount_display_names[mount_name])
	return mount_name

func get_part_display_name(part_id: String) -> String:
	if part_id == "":
		return "Empty"

	if part_presets.has(part_id):
		return str(part_presets[part_id]["display_name"])

	return part_id

# =========================================================
# PART PROFILE ACCESS
# =========================================================
func get_part_joint_profile(part_id: String) -> Dictionary:
	if part_joint_profiles.has(part_id):
		return part_joint_profiles[part_id]
	return part_joint_profiles["default"]

# =========================================================
# BUILD STATE SANITIZING
# =========================================================
# Clean the selected part dictionary so only valid mount keys and
# valid part IDs survive between sessions and scene changes.
# =========================================================
func get_sanitized_selected_parts() -> Dictionary:
	var sanitized: Dictionary = {}

	for mount_name in build_mount_order:
		sanitized[mount_name] = ""

	for mount_name in selected_parts.keys():
		var mount_key := str(mount_name)
		if not sanitized.has(mount_key):
			continue

		var part_id := str(selected_parts[mount_key])
		if part_id == "":
			sanitized[mount_key] = ""
			continue

		if not part_presets.has(part_id):
			continue

		sanitized[mount_key] = part_id

	return sanitized