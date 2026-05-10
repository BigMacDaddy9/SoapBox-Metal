extends RigidBody3D
var _oil_spawn_timer : float = 0.0
var rotation_speed = 360

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_oil_spawn_timer = _oil_spawn_timer + delta
	
	if _oil_spawn_timer == 5.0:
		queue_free()

func _on_oil_spill_body_entered(body: Node) -> void:
	if body == null or body == self:
		return
	else:
		if body is VehicleBody3D:
			if body.linear_velocity.z != 0: 
				body.rotate_z(deg_to_rad(rotation_speed))
			else:
				if body.linear_velocity.x != 0: 
					body.rotate_x(deg_to_rad(rotation_speed))
			queue_free()
		
func _on_oil_spill_body_shape_entered(body: Node) -> void:
	if body == null or body == self:
		return
	else:
		if body is VehicleBody3D:
			if body.linear_velocity.z != 0: 
				body.rotate_z(deg_to_rad(rotation_speed))
			else:
				if body.linear_velocity.x != 0: 
					body.rotate_x(deg_to_rad(rotation_speed))
		queue_free()
