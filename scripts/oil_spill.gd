extends RigidBody3D
var _oil_spawn_timer : float = 0.0
var rotation_speed = 360
@export var oilspillanim: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("oil")
	if oilspillanim != null:
		var tmp_oilspillanim: Node3D = oilspillanim.instantiate() as Node3D
		var scene_root: Node = get_tree().current_scene
		if scene_root == null:
			scene_root = get_parent()
		if scene_root != null:
			scene_root.add_child(tmp_oilspillanim)
			tmp_oilspillanim.global_position = global_position
			if tmp_oilspillanim.has_method("explode"):
				tmp_oilspillanim.explode()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_oil_spawn_timer = _oil_spawn_timer + delta
	
	if _oil_spawn_timer == 5.0:
		queue_free()

func _on_oil_spill_body_entered(body: Node) -> void:
	if "oil_spill_hit" in body:
		body.oil_spill_hit = true
		queue_free()
