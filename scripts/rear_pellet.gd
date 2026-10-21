extends CharacterBody2D
## Swept projectile: one hit, no bounce and no self-damage.
@export var damage: int = 2
@export var lifetime: float = 2.0
var _spent: bool = false

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var hit := move_and_collide(velocity * delta)
	if hit and not _spent:
		_spent = true
		var target := hit.get_collider()
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
