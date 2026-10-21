extends StaticBody2D
class_name DummyEnemy

var damage_taken: int = 0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)

func take_damage(amount: int) -> void:
	damage_taken += amount
