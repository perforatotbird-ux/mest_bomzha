extends CharacterBody2D
## Pigeon dropping: falls, splats on the first surface or on the drifter's head.
const GRAVITY := 1200.0
const TERMINAL := 720.0

var _fall: float = 60.0
var _life: float = 4.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 3
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	z_index = 9

func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_fall = minf(_fall + GRAVITY * delta, TERMINAL)
	var hit := move_and_collide(Vector2(0.0, _fall) * delta)
	if hit:
		var body := hit.get_collider()
		if body.has_method("take_damage"):
			body.take_damage(1)
		queue_free()

func _draw() -> void:
	draw_line(Vector2(0, -14), Vector2(0, -4), Color(0.9, 0.92, 0.85, 0.22), 2.0)
	# Lumpy splat rather than a clean ball: three overlapping blobs and a wet edge.
	draw_circle(Vector2(0, -1), 4.6, Color(0.93, 0.94, 0.88))
	draw_circle(Vector2(2.6, 1.6), 3.4, Color(0.9, 0.91, 0.85))
	draw_circle(Vector2(-2.4, 2.0), 2.8, Color(0.86, 0.88, 0.81))
	draw_circle(Vector2(-1.4, -2.2), 1.8, Color(0.98, 0.98, 0.94, 0.85))
