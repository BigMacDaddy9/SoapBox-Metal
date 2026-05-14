extends Node3D

@onready var spill: GPUParticles3D = $Spill
@onready var cleanup_timer: Timer = $Timer

var _has_spilled: bool = false


func _ready() -> void:
	# BMD MISSILE SYSTEM CHANGE:
	# Connect the timer once after the explosion node is inside the tree.
	spill.process_material.gravity = Vector3(10.0, 0, 0)
	if cleanup_timer != null and not cleanup_timer.timeout.is_connected(_on_timer_timeout):
		cleanup_timer.timeout.connect(_on_timer_timeout)


func explode() -> void:
	if _has_spilled:
		return
	_has_spilled = true

	if spill != null:
		spill.restart()
		spill.emitting = true
	# Start the cleanup timer only once the node is definitely in the scene tree.
	if is_inside_tree():
		cleanup_timer.start()
	else:
		call_deferred("_start_cleanup_timer_deferred")


func _start_cleanup_timer_deferred() -> void:
	if cleanup_timer != null and is_inside_tree():
		cleanup_timer.start()


func _on_timer_timeout() -> void:
	queue_free()
