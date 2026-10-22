extends StaticBody2D
var health: int = 2
func _ready() -> void:
	add_to_group("secret_grates")
	# Solid to the hero as well as the hero's projectiles.
	collision_layer = 9
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 95)
	shape.shape = rect
	shape.position.y = -47.5
	add_child(shape)
	z_index = 9
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
func _draw() -> void:
	draw_rect(Rect2(-10, -95, 20, 95), Color(0.17, 0.21, 0.18))
	for i in 5:
		draw_line(Vector2(-9, -90 + i * 20), Vector2(9, -82 + i * 20), Color(0.65, 0.46, 0.27), 3)
	draw_line(Vector2(-6, -78), Vector2(5, -48), Color(1, 0.78, 0.38), 2)
	draw_line(Vector2(5, -48), Vector2(-4, -15), Color(1, 0.78, 0.38), 2)
