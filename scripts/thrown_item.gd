extends RigidBody2D
@export var damage: int = 3
@export var lifetime: float = 5.0
var _spent: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	_spent = true
	if body.has_method("take_damage"):
		body.take_damage(damage)
	# A bottle breaks on its first world/enemy contact, rather than bouncing forever.
	queue_free()
