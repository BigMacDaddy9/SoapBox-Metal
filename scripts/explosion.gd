extends Node3D
@onready var debris = $Debris
@onready var fire = $Fire


func explode():
	$Timer.timeout.connect(_on_timer_timeout)
	$Timer.start() # Start the timer
	
func _on_timer_timeout():
	queue_free()
