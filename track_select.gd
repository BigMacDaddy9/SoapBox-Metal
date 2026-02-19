extends Control

const MAIN_MENU := "res://main_menu.tscn"
const TRACK_01 := "res://tracks/test_hill_01.tscn"

@onready var track1: Button = $Center/Panel/Margin/VBox/Track1
@onready var back: Button = $Center/Panel/Margin/VBox/Back

func _ready() -> void:
	get_tree().paused = false
	call_deferred("_apply_menu_mouse")

	track1.pressed.connect(func():
		get_tree().change_scene_to_file(TRACK_01)
	)

	back.pressed.connect(func():
		get_tree().change_scene_to_file(MAIN_MENU)
	)

func _apply_menu_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
