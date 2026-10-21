extends RigidBody2D

@export var lifetime: float = 6.0

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0 or global_position.y > 900.0:
		queue_free()
