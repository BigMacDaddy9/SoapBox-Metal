extends CanvasLayer 

# =========================================================
# IN-GAME MENU
# =========================================================
# Pause/dropdown menu used during gameplay.
#
# Handles:
# - toggling the pause menu (Escape / ui_cancel)
# - resetting the current scene
# - returning to the main menu
# - quitting the game
# - managing mouse state (captured vs visible)
#
# This menu is only active during gameplay scenes and is hidden
# automatically in menu scenes.
# =========================================================

# =========================================================
# SCENE PATHS
# =========================================================
# Used for scene comparisons and transitions.
# =========================================================
const MAIN_MENU_SCENE_PATH := "res://main_menu.tscn"
const BUILD_MENU_SCENE_PATH := "res://build_menu.tscn"
const TRACK_SELECT_SCENE_PATH := "res://track_select.tscn"

# =========================================================
# NODE REFERENCES
# =========================================================
# UI elements for the dropdown panel and background dimmer.
# =========================================================
@onready var drop_panel: PanelContainer = $Root/TopRight/DropPanel
@onready var reset_button: Button = $Root/TopRight/DropPanel/Margin/VBox/ResetButton
@onready var quit_to_menu_button: Button = $Root/TopRight/DropPanel/Margin/VBox/QuitToMenuButton
@onready var quit_game_button: Button = $Root/TopRight/DropPanel/Margin/VBox/QuitGameButton
@onready var dimmer: ColorRect = $Root/Dimmer

# =========================================================
# READY
# =========================================================
# Connects button signals and initializes menu state.
# =========================================================
func _ready() -> void:
	reset_button.pressed.connect(_on_reset_pressed)
	quit_to_menu_button.pressed.connect(_on_quit_to_menu_pressed)
	quit_game_button.pressed.connect(_on_quit_game_pressed)

	# NOTE: in your build, scene_changed calls with 0 args
	get_tree().scene_changed.connect(_on_scene_changed)

	drop_panel.visible = false
	_refresh_scene_state()

# =========================================================
# PROCESS
# =========================================================
# Listens for the pause input (Escape / ui_cancel).
# Only works during gameplay scenes.
# =========================================================
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if not _is_gameplay_now():
			return
		_toggle_menu()

# =========================================================
# MENU TOGGLING
# =========================================================
# Opens/closes the dropdown menu and applies pause + mouse state.
# =========================================================
func _toggle_menu() -> void:
	var will_open := not drop_panel.visible
	drop_panel.visible = will_open
	dimmer.visible = will_open

	get_tree().paused = will_open

	if will_open:
		_apply_mouse_for_menu()
	else:
		_apply_mouse_for_gameplay()

# =========================================================
# BUTTON HANDLERS
# =========================================================
# Respond to menu button presses.
# =========================================================
func _on_reset_pressed() -> void:
	_close_menu()
	get_tree().reload_current_scene()

func _on_quit_to_menu_pressed() -> void:
	drop_panel.visible = false
	get_tree().paused = false
	_apply_mouse_for_menu()

	if has_node("/root/MenuMusic"):
		MenuMusic.transition_to_scene(MAIN_MENU_SCENE_PATH, "Returning to main menu...")
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_quit_game_pressed() -> void:
	_close_menu()
	get_tree().quit()

# =========================================================
# SCENE CHANGE HANDLING
# =========================================================
# Ensures the menu resets when switching scenes.
# =========================================================
func _on_scene_changed() -> void:
	_close_menu()
	_refresh_scene_state()

# =========================================================
# SCENE STATE MANAGEMENT
# =========================================================
# Determines whether we are currently in gameplay or menu scenes,
# and adjusts visibility + mouse behaviour accordingly.
# =========================================================
func _refresh_scene_state() -> void:
	var path := _get_current_scene_path()

	var in_gameplay := (
		path != MAIN_MENU_SCENE_PATH
		and path != TRACK_SELECT_SCENE_PATH
		and path != BUILD_MENU_SCENE_PATH
	)

	visible = in_gameplay

	# Mouse mode per scene
	if in_gameplay:
		_apply_mouse_for_gameplay()
	else:
		_apply_mouse_for_menu()

# =========================================================
# GAMEPLAY CHECK
# =========================================================
# Returns true if the current scene is considered gameplay.
# =========================================================
func _is_gameplay_now() -> bool:
	var path := _get_current_scene_path()
	if path == "":
		return true

	return (
		path != MAIN_MENU_SCENE_PATH
		and path != TRACK_SELECT_SCENE_PATH
		and path != BUILD_MENU_SCENE_PATH
	)

# =========================================================
# SCENE PATH HELPER
# =========================================================
# Safely retrieves the current scene file path.
# =========================================================
func _get_current_scene_path() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""

	if scene.has_method("get_scene_file_path"):
		return scene.get_scene_file_path()

	return ""

# =========================================================
# MENU CLOSE
# =========================================================
# Closes the dropdown and restores correct scene state.
# =========================================================
func _close_menu() -> void:
	drop_panel.visible = false
	dimmer.visible = false
	get_tree().paused = false

	# Apply correct mouse mode for whatever scene we are now in
	_refresh_scene_state()

# =========================================================
# MOUSE MODE HELPERS
# =========================================================
# Switch between gameplay (captured) and menu (visible) mouse modes.
# =========================================================
func _apply_mouse_for_gameplay() -> void:
	# If you don't want capture at all, change this to VISIBLE.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply_mouse_for_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE