extends RigidBody3D

@export var speed = 100
@export var explosion_radius := 200.0
@export var explosion_power := 1000.0
@onready var explosion_area = $MissileArea
@export var coolexplosion : PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	move_and_collide(transform.basis.z * delta * speed)
	var collision = get_colliding_bodies()
	if !collision.is_empty():
		explode()

func explode():
	var bodies = explosion_area.get_overlapping_bodies()
	for body in bodies:
		# Check if the body is a soapbox or obstacle
		if body is not StaticBody3D:
			var direction = (body.global_position - global_position).normalized()
			var distance = global_position.distance_to(body.global_position)
			var distance_factor = 1.0 - (distance / explosion_radius)
			distance_factor = clamp(distance_factor, 0.0, 1.0)
			
			var final_force = direction * explosion_power * distance_factor
			body.apply_central_impulse(final_force)
			
	var tmp_explosion = coolexplosion.instantiate()
	tmp_explosion.explode()
	
	queue_free()
	
	
