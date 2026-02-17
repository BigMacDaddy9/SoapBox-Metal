extends VehicleBody3D


#
#@export var speed: float = 14.0
#@export var fall_acceleration: float = 75.0
@export var push_force: float = 100.0
#@export var bounce_impulse = 16
#
#var target_velocity := Vector3.ZERO
#
#
func _physics_process(delta: float) -> void:
	# Get input direction
	var input_dir = Input.get_vector(
		"move_right", "move_left", 
		"move_back", "move_forward"
	)
	
	
	
	## Set horizontal velocity
	#target_velocity.x = input_dir.x * speed
	#target_velocity.z = input_dir.z * speed
	engine_force = input_dir.y * push_force
	steering = input_dir.x * PI/4.0#lerpf(steering, , delta)
	
	#$BackAxel.apply_torque($BackAxel.global_basis.x*target_velocity.z*100.0)
	
	
	## Apply gravity
	#if not is_on_floor():
		#target_velocity.y -= fall_acceleration * delta
	#else:
		#target_velocity.y = 0.0
	#
	## Move
	#velocity = target_velocity
	#move_and_slide()
	#
	## Push rigid bodies we collide with
	#for i in get_slide_collision_count():
		#var collision := get_slide_collision(i)
		#var collider := collision.get_collider()
		#if collision.get_collider().is_in_group("obstacles"):
			## we check that we are hitting it from above.
			#if Vector3.DOWN.dot(collision.get_normal()) < 0.1:
				#target_velocity.y = bounce_impulse
				## Prevent further duplicate calls.
				#break
		#if collider is RigidBody3D:
			#var push_dir := -collision.get_normal()
			#collider.apply_central_impulse(push_dir * push_force)
