extends RigidBody3D


#
@export var speed: float = 14.0
@export var fall_acceleration: float = 75.0
@export var push_force: float = 3.0
@export var bounce_impulse = 16
#
var target_velocity := Vector3.ZERO
#
#
func _physics_process(delta: float) -> void:
	# Get input direction
	var input_dir := Vector3.ZERO
	
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
	
	## Set horizontal velocity
	#target_velocity.x = input_dir.x * speed
	target_velocity.z = input_dir.z * speed
	
	$BackAxel.apply_torque($BackAxel.global_basis.x*target_velocity.z*100.0)
	
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
