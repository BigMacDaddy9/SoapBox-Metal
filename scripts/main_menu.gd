extends Control

@export var downhill_scene: PackedScene

@onready var arena_button: Button = $CenterContainer/VBoxContainer/ArenaButton
@onready var ai_checkbox: CheckBox = $CenterContainer/VBoxContainer/AICheckBox
@onready var downhill_button: Button = $CenterContainer/VBoxContainer/DownhillButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel

func _ready() -> void:
	# Sync checkbox with global settings
	ai_checkbox.button_pressed = SBSettings.ai_enabled

	# Disable downhill for now
	downhill_button.disabled = true

	# Connect signals automatically
	arena_button.pressed.connect(_on_arena_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	downhill_button.pressed.connect(_on_downhill_pressed)

func _on_arena_pressed() -> void:
	SBSettings.ai_enabled = ai_checkbox.button_pressed
	get_tree().change_scene_to_file("res://world.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_downhill_pressed() -> void:
	status_label.text = "Soapbox Downhill Race: Coming Soon 🤘"
