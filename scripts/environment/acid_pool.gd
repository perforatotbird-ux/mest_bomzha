extends Area2D

@export var pool_size: Vector2 = Vector2(1280, 180)
@export var wave_amplitude: float = 7.0
@export var bubble_speed: float = 1.2

var _time: float = 0.0
var _bubbles := [
	{"x": 0.10, "r": 12.0, "phase": 0.1},
	{"x": 0.24, "r": 7.0, "phase": 1.2},
	{"x": 0.41, "r": 14.0, "phase": 2.0},
	{"x": 0.58, "r": 9.0, "phase": 0.7},
	{"x": 0.77, "r": 11.0, "phase": 2.7},
	{"x": 0.88, "r": 6.0, "phase": 3.4},
]

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var rect := RectangleShape2D.new()
	rect.size = pool_size
	$CollisionShape2D.shape = rect
	$Glow.size = Vector2(pool_size.x, pool_size.y * 0.85)
	$Glow.position = Vector2(-pool_size.x * 0.5, -pool_size.y * 0.5)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var left := -pool_size.x * 0.5
	var top := -pool_size.y * 0.5
	var points := PackedVector2Array()
	var segments := 28
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var x := left + t * pool_size.x
		var y := top + 20.0 + sin(t * TAU * 2.5 + _time * 2.7) * wave_amplitude
		points.append(Vector2(x, y))
	points.append(Vector2(left + pool_size.x, top + pool_size.y))
	points.append(Vector2(left, top + pool_size.y))
	draw_colored_polygon(points, Color(0.09, 0.19, 0.105, 0.96))
	for i in range(segments):
		var p0 := points[i]
		var p1 := points[i + 1]
		draw_line(p0, p1, Color(0.48, 0.64, 0.22, 0.85), 2.0)
	draw_rect(Rect2(left, top + 24, pool_size.x, pool_size.y - 24), Color(0.035, 0.085, 0.067, 0.52), true)
	for bubble: Dictionary in _bubbles:
		var bx: float = left + pool_size.x * bubble.x
		var bob: float = fmod(_time * 50.0 * bubble_speed + bubble.phase * 30.0, pool_size.y - 36.0)
		var by: float = top + pool_size.y - 20.0 - bob
		var alpha: float = clamp(1.0 - bob / (pool_size.y - 36.0), 0.18, 0.9)
		draw_arc(Vector2(bx, by), bubble.r, 0, TAU, 20, Color(0.46, 0.58, 0.22, alpha * 0.5), 2.0)
		draw_circle(Vector2(bx + bubble.r * 0.5, by - bubble.r * 0.5), 2.0, Color(0.69, 0.73, 0.40, alpha * 0.6))

func _on_body_entered(body: Node) -> void:
	if body.has_method("respawn"):
		body.call_deferred("respawn")
	elif body.has_method("take_damage"):
		body.call_deferred("take_damage", 999)
