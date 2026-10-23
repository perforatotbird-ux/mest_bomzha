extends RigidBody2D
## Whole bottle: tumbles through its sprite frames and shatters on first contact.
@export var damage: int = 3
@export var lifetime: float = 5.0

const GLASS_BURST := preload("res://scripts/glass_burst.gd")

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
	# A bottle breaks on its first world/enemy contact rather than bouncing forever.
	# Deferred: body_entered fires inside the physics step, where adding nodes is unsafe.
	_spawn_burst.call_deferred(global_position)
	queue_free()

func _spawn_burst(at: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var burst := GLASS_BURST.new()
	burst.position = at
	host.add_child(burst)
