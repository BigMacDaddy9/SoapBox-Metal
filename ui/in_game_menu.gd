extends CanvasLayer

const MAIN_MENU_SCENE_PATH := "res://main_menu.tscn"
const TRACK_SELECT_SCENE_PATH := "res://track_select.tscn"

@onready var drop_panel: PanelContainer = $Root/TopRight/DropPanel
@onready var reset_button: Button = $Root/TopRight/DropPanel/Margin/VBox/ResetButton
@onready var quit_to_menu_button: Button = $Root/TopRight/DropPanel/Margin/VBox/QuitToMenuButton
@onready var quit_game_button: Button = $Root/TopRight/DropPanel/Margin/VBox/QuitGameButton
@onready var dimmer: ColorRect = $Root/Dimmer

func _ready() -> void:
	reset_button.pressed.connect(_on_reset_pressed)
	quit_to_menu_button.pressed.connect(_on_quit_to_menu_pressed)
	quit_game_button.pressed.connect(_on_quit_game_pressed)

	# NOTE: in your build, scene_changed calls with 0 args
	get_tree().scene_changed.connect(_on_scene_changed)

	drop_panel.visible = false
	_refresh_scene_state()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if not _is_gameplay_now():
			return
		_toggle_menu()

func _toggle_menu() -> void:
	var will_open := not drop_panel.visible
	drop_panel.visible = will_open
	dimmer.visible = will_open

	get_tree().paused = will_open

	if will_open:
		_apply_mouse_for_menu()
	else:
		_apply_mouse_for_gameplay()

func _on_reset_pressed() -> void:
	_close_menu()
	get_tree().reload_current_scene()

func _on_quit_to_menu_pressed() -> void:
	drop_panel.visible = false
	get_tree().paused = false
	_apply_mouse_for_menu()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_quit_game_pressed() -> void:
	_close_menu()
	get_tree().quit()

func _on_scene_changed() -> void:
	_close_menu()
	_refresh_scene_state()

func _refresh_scene_state() -> void:
	var path := _get_current_scene_path()
	var in_gameplay := (path != MAIN_MENU_SCENE_PATH and path != TRACK_SELECT_SCENE_PATH)


	visible = in_gameplay

	# Mouse mode per scene
	if in_gameplay:
		_apply_mouse_for_gameplay()
	else:
		_apply_mouse_for_menu()

func _is_gameplay_now() -> bool:
	var path := _get_current_scene_path()
	if path == "":
		return true
	return (path != MAIN_MENU_SCENE_PATH and path != TRACK_SELECT_SCENE_PATH)

func _get_current_scene_path() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	if scene.has_method("get_scene_file_path"):
		return scene.get_scene_file_path()
	return ""

func _close_menu() -> void:
	drop_panel.visible = false
	dimmer.visible = false
	get_tree().paused = false

	# Apply correct mouse mode for whatever scene we are now in
	_refresh_scene_state()

func _apply_mouse_for_gameplay() -> void:
	# If you don't want capture at all, change this to VISIBLE.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply_mouse_for_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
