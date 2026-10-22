extends Area2D
## Reusable checkpoint, valve, cache, medkit or exit. V only operates valves.
var kind: String = "checkpoint"
var index: int = 0
var used: bool = false
var level: Node
var label: Label
var clock: float = 0.0
func _ready() -> void:
	add_to_group("level_interactions")
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90, 100)
	shape.shape = rect
	shape.position.y = -42
	add_child(shape)
	body_entered.connect(_entered)
	label = Label.new()
	label.position = Vector2(-90, -225 if kind == "exit" else -110)
	label.size.x = 180
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.text = {"checkpoint": "УБЕЖИЩЕ", "valve": "[V] ВЕНТИЛЬ", "secret": "ТАЙНИК", "medkit": "+ ЗДОРОВЬЕ", "exit": "ВЫХОД"}[kind]
	add_child(label)
	z_index = 7
func _process(delta: float) -> void:
	clock += delta
	if kind == "secret" and not used:
		queue_redraw()
func _entered(body: Node) -> void:
	if body.has_method("respawn") and kind != "valve":
		activate()
func activate() -> void:
	if used and kind != "exit":
		return
	if kind == "exit" and level.valves < 4:
		level.notice("Открой четыре вентиля. Найдено: %d/4" % level.valves)
		return
	if kind == "checkpoint":
		# Checkpoints cannot move backwards when revisiting older sectors.
		if level.player._spawn.x >= position.x:
			return
		level.player.set_checkpoint(position + Vector2(0, -40))
		level.notice("Контрольная точка • здоровье восстановлено")
	elif kind == "valve":
		level.open_valve(index)
		label.text = "ВЕНТИЛЬ ОТКРЫТ"
	elif kind == "secret":
		level.secrets += 1
		level.heal(2)
		level.notice("Тайник %d/8 • +2 здоровья" % level.secrets)
	elif kind == "medkit":
		if level.player.health == level.player.max_health:
			return
		level.heal(2)
	elif kind == "exit":
		level.finish()
	used = true
	if kind in ["medkit", "secret"]:
		visible = false
	queue_redraw()
func _draw() -> void:
	var c := Color(0.45, 0.85, 0.6) if used else Color(0.96, 0.7, 0.3)
	if kind == "valve":
		draw_rect(Rect2(-9, -65, 18, 65), Color(0.28, 0.25, 0.19))
		draw_arc(Vector2(0, -55), 22, 0, TAU, 32, c, 4)
		for i in 4:
			var p := Vector2.from_angle(i * PI * 0.5 + (0.8 if used else 0.0)) * 20
			draw_line(Vector2(0, -55), Vector2(0, -55) + p, c, 3)
	elif kind == "checkpoint":
		draw_rect(Rect2(-8, -65, 16, 65), Color(0.21, 0.22, 0.2))
		draw_rect(Rect2(-18, -60, 36, 42), Color(0.09, 0.14, 0.12))
		draw_circle(Vector2(0, -40), 8, c)
	elif kind == "medkit":
		draw_rect(Rect2(-19, -27, 38, 27), Color(0.68, 0.68, 0.5))
		draw_rect(Rect2(-3, -23, 6, 18), Color(0.7, 0.15, 0.1))
		draw_rect(Rect2(-9, -17, 18, 6), Color(0.7, 0.15, 0.1))
	elif kind == "secret":
		draw_rect(Rect2(-24, -32, 48, 32), Color(0.32, 0.23, 0.12))
		draw_rect(Rect2(-24, -32, 48, 10), Color(0.63, 0.46, 0.21))
		draw_circle(Vector2(0, -18), 4, c)
		draw_circle(Vector2(0, -49), 3 + sin(clock * 3), Color(0.94, 0.79, 0.43, 0.7))
