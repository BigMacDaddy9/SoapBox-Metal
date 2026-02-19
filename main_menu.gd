extends Control

const ARENA_SCENE := "res://world.tscn"
const TRACK_SELECT_SCENE := "res://track_select.tscn"

@onready var arena_button: Button = find_child("ArenaButton", true, false) as Button
@onready var downhill_button: Button = find_child("DownhillButton", true, false) as Button
@onready var exit_button: Button = find_child("ExitButton", true, false) as Button
@onready var ai_checkbox: CheckBox = find_child("AICheckBox", true, false) as CheckBox


func _ready() -> void:
	print("MainMenu children:", get_children())
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Hard fail early with useful messages
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

	arena_button.pressed.connect(_on_arena_pressed)
	downhill_button.pressed.connect(_on_downhill_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_arena_pressed() -> void:
	if has_node("/root/SBSettings"):
		SBSettings.ai_enabled = ai_checkbox.button_pressed
	get_tree().change_scene_to_file(ARENA_SCENE)

func _on_downhill_pressed() -> void:
	if has_node("/root/SBSettings"):
		SBSettings.ai_enabled = ai_checkbox.button_pressed
	get_tree().change_scene_to_file(TRACK_SELECT_SCENE)

func _on_exit_pressed() -> void:
	get_tree().quit()
