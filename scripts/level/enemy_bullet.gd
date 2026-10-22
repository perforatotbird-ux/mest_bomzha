extends CharacterBody2D
var lifetime: float = 3.0
func _ready() -> void:
	collision_layer = 0
	collision_mask = 3
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	z_index = 8
func _physics_process(delta: float) -> void:
	lifetime -= delta
	var hit := move_and_collide(velocity * delta)
	if hit:
		var body := hit.get_collider()
		if body.has_method("take_damage"):
			body.take_damage(1)
		queue_free()
	elif lifetime <= 0.0:
		queue_free()
func _draw() -> void:
	draw_circle(Vector2.ZERO, 7, Color(1, 0.4, 0.1, 0.3))
	draw_circle(Vector2.ZERO, 3, Color(1, 0.85, 0.4))
