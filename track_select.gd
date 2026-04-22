extends Control

# =========================================================
# TRACK SELECT
# =========================================================
# Simple menu for choosing which race/testing track to load.
#
# This screen:
# - shows available tracks
# - transitions back to the main menu
# - asks the music manager to handle scene/audio changes
# =========================================================

# =========================================================
# SCENE PATHS
# =========================================================
const MAIN_MENU := "res://main_menu.tscn"
const TRACK_01 := "res://tracks/test_hill_01.tscn"
const TRACK_02 := "res://tracks/test_hill_02.tscn"
const TRACK_03 := "res://tracks/test_hill_03.tscn"

# =========================================================
# BUTTON LOOKUP
# =========================================================
# Finds a named button anywhere below this control.
# =========================================================
func _find_button(name: String) -> Button:
	return find_child(name, true, false) as Button

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	get_tree().paused = false
	call_deferred("_apply_menu_mouse")

	var track1 := _find_button("Track1")
	var track2 := _find_button("Track2")
	var track3 := _find_button("Track3")
	var back := _find_button("Back")

	if track1:
		track1.pressed.connect(func():
			if has_node("/root/MenuMusic"):
				MenuMusic.transition_to_scene(TRACK_01, "Loading track 01...")
			else:
				get_tree().change_scene_to_file(TRACK_01)
		)

	if track2:
		track2.pressed.connect(func():
			if has_node("/root/MenuMusic"):
				MenuMusic.transition_to_scene(TRACK_02, "Loading track 02...")
			else:
				get_tree().change_scene_to_file(TRACK_02)
		)

	if track3:
		track3.pressed.connect(func():
			if has_node("/root/MenuMusic"):
				MenuMusic.transition_to_scene(TRACK_03, "Loading Nurburger Ring...")
			else:
				get_tree().change_scene_to_file(TRACK_03)
		)

	if back:
		back.pressed.connect(func():
			get_tree().change_scene_to_file(MAIN_MENU)
		)

# =========================================================
# MOUSE MODE
# =========================================================
# Make sure the cursor is visible when entering menu screens.
# =========================================================
func _apply_menu_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
