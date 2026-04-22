extends Control

# =========================================================
# MAIN MENU
# =========================================================
# Entry point for the game UI.
#
# Responsible for:
# - navigating to build menu
# - launching arena mode
# - launching downhill mode (track select)
# - toggling AI on/off before entering gameplay
# - displaying current platform and base selection
# - updating the build preview
# =========================================================

# =========================================================
# SCENE PATHS
# =========================================================
# Used for scene transitions from the main menu.
# =========================================================
const BUILD_MENU_SCENE := "res://build_menu.tscn"
const ARENA_SCENE := "res://tracks/sandbox_arena.tscn"
const TRACK_SELECT_SCENE := "res://track_select.tscn"

# =========================================================
# NODE REFERENCES
# =========================================================
# UI elements pulled dynamically using find_child to avoid strict paths.
# =========================================================
@onready var build_button: Button = find_child("BuildButton", true, false) as Button
@onready var platform_status_label: Label = find_child("PlatformStatusLabel", true, false) as Label
@onready var base_status_label: Label = find_child("BaseStatusLabel", true, false) as Label
@onready var arena_button: Button = find_child("ArenaButton", true, false) as Button
@onready var downhill_button: Button = find_child("DownhillButton", true, false) as Button
@onready var exit_button: Button = find_child("ExitButton", true, false) as Button
@onready var ai_checkbox: CheckBox = find_child("AICheckBox", true, false) as CheckBox
@onready var preview: Node = find_child("BuildPreview", true, false) as Node

# =========================================================
# READY
# =========================================================
# Initializes UI, validates required nodes, and connects signals.
# =========================================================
func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# DEBUG: Print children to help diagnose missing nodes
	print("MainMenu children:", get_children())

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# =========================================================
	# NODE VALIDATION
	# =========================================================
	# Hard fail early if required UI elements are missing.
	# =========================================================
	if build_button == null:
		push_error("MainMenu: Missing node at Center/Panel/Margin/VBox/BuildButton (check name/path).")
		return
	if arena_button == null:
		push_error("MainMenu: Missing node at Center/Panel/Margin/VBox/ArenaButton (check name/path).")
		return
	if downhill_button == null:
		push_error("MainMenu: Missing node at Center/Panel/Margin/VBox/DownhillButton (check name/path).")
		return
	if exit_button == null:
		push_error("MainMenu: Missing node at Center/Panel/Margin/VBox/ExitButton (check name/path).")
		return
	if ai_checkbox == null:
		push_error("MainMenu: Missing node at Center/Panel/Margin/VBox/AICheckBox (check name/path).")
		return

	# =========================================================
	# SIGNAL CONNECTIONS
	# =========================================================
	build_button.pressed.connect(_on_build_pressed)
	arena_button.pressed.connect(_on_arena_pressed)
	downhill_button.pressed.connect(_on_downhill_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# =========================================================
	# UI INITIALIZATION
	# =========================================================
	_refresh_base_status()
	_refresh_preview()

# =========================================================
# BUTTON HANDLERS
# =========================================================
# Respond to main menu button presses.
# =========================================================
func _on_build_pressed() -> void:
	get_tree().change_scene_to_file(BUILD_MENU_SCENE)

func _on_arena_pressed() -> void:
	# Save AI toggle before entering gameplay
	if has_node("/root/SBSettings"):
		SBSettings.ai_enabled = ai_checkbox.button_pressed

	# Use music transition system if available
	if has_node("/root/MenuMusic"):
		MenuMusic.transition_to_scene(ARENA_SCENE, "Loading arena...")
	else:
		get_tree().change_scene_to_file(ARENA_SCENE)

func _on_downhill_pressed() -> void:
	# Save AI toggle before entering gameplay
	if has_node("/root/SBSettings"):
		SBSettings.ai_enabled = ai_checkbox.button_pressed

	get_tree().change_scene_to_file(TRACK_SELECT_SCENE)

func _on_exit_pressed() -> void:
	get_tree().quit()

# =========================================================
# STATUS DISPLAY
# =========================================================
# Updates the displayed platform and base information.
# =========================================================
func _refresh_base_status() -> void:
	if base_status_label != null:
		var base_label_text := "Current Base: No Base"
		if has_node("/root/SBSettings"):
			var base_data := SBSettings.get_current_base()
			base_label_text = "Current Base: " + str(base_data["display_name"])
		base_status_label.text = base_label_text

	if platform_status_label != null:
		var platform_label_text := "Current Platform: 4 Wheeler"
		if has_node("/root/SBSettings"):
			var platform_data := SBSettings.get_current_platform()
			platform_label_text = "Current Platform: " + str(platform_data["display_name"])
		platform_status_label.text = platform_label_text

# =========================================================
# PREVIEW UPDATE
# =========================================================
# Updates the build preview to reflect the currently selected base.
# =========================================================
func _refresh_preview() -> void:
	if preview and preview.has_method("set_base"):
		preview.set_base(SBSettings.selected_base)
