extends Node3D

@onready var debris: GPUParticles3D = $Debris
@onready var fire: GPUParticles3D = $Fire
@onready var smoke: GPUParticles3D = $Smoke
@onready var cleanup_timer: Timer = $Timer

var _has_exploded: bool = false


func _ready() -> void:
	# BMD MISSILE SYSTEM CHANGE:
	# Connect the timer once after the explosion node is inside the tree.
	if cleanup_timer != null and not cleanup_timer.timeout.is_connected(_on_timer_timeout):
		cleanup_timer.timeout.connect(_on_timer_timeout)


func explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true

	if debris != null:
		debris.restart()
		debris.emitting = true
	if fire != null:
		fire.restart()
		fire.emitting = true
	if smoke != null:
		smoke.restart()
		smoke.emitting = true

	# BMD MISSILE SYSTEM CHANGE:
	# Start the cleanup timer only once the node is definitely in the scene tree.
	if is_inside_tree():
		cleanup_timer.start()
	else:
		call_deferred("_start_cleanup_timer_deferred")


func _start_cleanup_timer_deferred() -> void:
	# BMD MISSILE SYSTEM CHANGE:
	# Deferred fallback in case explode() is ever called too early again.
	if cleanup_timer != null and is_inside_tree():
		cleanup_timer.start()


func _on_timer_timeout() -> void:
	queue_free()
