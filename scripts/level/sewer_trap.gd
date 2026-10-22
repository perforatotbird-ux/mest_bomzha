extends Node2D
## Idle -> amber warning -> active -> cooldown; phases are offset per placement.
@export_enum("steam", "crusher", "arc") var kind: String = "steam"
var phase_offset: float = 0.0
var clock: float = 0.0
var target: Node2D
var active: bool = false
var warning: bool = false
const VENT = preload("res://Assets/Environment/Sewer/steam_vent.tres")
const HEAD = preload("res://Assets/Environment/Sewer/crusher_head.tres")
const POST = preload("res://Assets/Environment/Sewer/arc_post.tres")
var area: Area2D
func _ready() -> void:
	add_to_group("level_traps")
	area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(66, 100) if kind == "steam" else Vector2(80, 170)
	if kind == "arc":
		rect.size = Vector2(160, 15)
	shape.position.y = -65.0 if kind == "arc" else -rect.size.y * 0.5
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	z_index = 6
func _physics_process(delta: float) -> void:
	clock += delta
	var cycle: float = fmod(clock + phase_offset, 4.8)
	warning = cycle >= 1.8 and cycle < 2.6
	active = cycle >= 2.6 and cycle < 3.7
	if is_instance_valid(target) and absf(target.global_position.x - global_position.x) < 1100.0:
		if active:
			for body in area.get_overlapping_bodies():
				if body.has_method("take_damage"):
					body.take_damage(1)
		queue_redraw()
func _draw() -> void:
	var color := Color(1, 0.32, 0.17) if active else Color(1, 0.72, 0.2)
	if kind == "steam":
		draw_texture_rect(VENT, Rect2(-42, -17, 84, 22), false)
		if active or warning:
			for i in 7:
				var y: float = -fmod(clock * 110.0 + i * 17.0, 110.0 if active else 25.0)
				draw_circle(Vector2(sin(i * 2.2 + clock) * 18, y), 12.0 + i * 1.4, Color(0.65, 0.75, 0.62, 0.32 if active else 0.13))
	elif kind == "crusher":
		draw_rect(Rect2(-44, -220, 88, 24), Color(0.21, 0.23, 0.21))
		var y: float = -38.0 if active else -195.0
		draw_rect(Rect2(-10, -220, 20, y + 220), Color(0.42, 0.36, 0.26))
		draw_texture_rect(HEAD, Rect2(-43, y - 78, 86, 112), false)
		if active or warning:
			draw_line(Vector2(-40, -2), Vector2(40, -2), color, 4)
	else:
		for x in [-88, 88]:
			draw_texture_rect(POST, Rect2(x - 13, -100, 38, 100), false)
		if active or warning:
			var points := PackedVector2Array()
			for i in 17:
				points.append(Vector2(-80 + i * 10, -65 + sin(i * 3.0 + clock * 30) * (5 if active else 1)))
			draw_polyline(points, Color(0.55, 0.88, 1, 0.9 if active else 0.3), 3)
	if warning:
		draw_circle(Vector2(0, -130 if kind != "crusher" else -235), 5, color)
