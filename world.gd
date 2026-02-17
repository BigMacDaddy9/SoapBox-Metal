extends Node3D

@export var enable_ai_car: bool = true

@onready var _enemy := $EnemySoapbox

func _ready() -> void:
	if not enable_ai_car and _enemy:
		_enemy.queue_free()
