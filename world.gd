extends Node3D

@export var enable_ai_car: bool = true

@onready var _enemy := $EnemySoapbox

func _ready() -> void:
	# If menu settings exist, prefer them.
	var settings := get_node_or_null("/root/SBSettings")
	if settings:
		enable_ai_car = settings.ai_enabled

	if not enable_ai_car and _enemy:
		_enemy.queue_free()

