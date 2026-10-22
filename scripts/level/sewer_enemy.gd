extends CharacterBody2D
## Small FSM: patrol -> warning -> strike/recover. Patrol bounds prevent cliff falls.
signal defeated
@export_enum("guard", "rat", "dog", "drone") var kind: String = "guard"
@export var patrol_left: float = 0.0
@export var patrol_right: float = 300.0
var target: Node2D
var health: int = 4
var maximum: int = 4
var state: String = "patrol"
var timer: float = 0.0
var direction: float = -1.0
var flash: float = 0.0
var clock: float = 0.0
var home_y: float
var sprite: Sprite2D
const BULLET = preload("res://scripts/level/enemy_bullet.gd")

func _ready() -> void:
	add_to_group("level_enemies")
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 8.0
	maximum = {"guard": 6, "rat": 2, "dog": 3, "drone": 4}[kind]
	health = maximum
	home_y = position.y
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 70) if kind == "guard" else Vector2(48, 28)
	shape.position.y = -rect.size.y * 0.5
	shape.shape = rect
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = load("res://Assets/Enemies/%s.tres" % kind)
	var height: float = {"guard": 90.0, "rat": 36.0, "dog": 55.0, "drone": 60.0}[kind]
	sprite.scale = Vector2.ONE * height / sprite.texture.get_height()
	sprite.position.y = -height * 0.5
	add_child(sprite)
	z_index = 5

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	if absf(target.global_position.x - global_position.x) > 1600.0:
		return
	clock += delta
	flash = maxf(0.0, flash - delta)
	timer = maxf(0.0, timer - delta)
	var offset: Vector2 = target.global_position - global_position
	var in_lane: bool = absf(offset.y + 36.0) < 95.0 if kind != "drone" else absf(offset.y) < 300.0
	var reach: float = 340.0 if kind == "drone" else (180.0 if kind == "dog" else 80.0)
	match state:
		"patrol":
			if in_lane and absf(offset.x) < reach and _can_see_target():
				direction = signf(offset.x) if absf(offset.x) > 1.0 else direction
				state = "warning"
				timer = 0.75 if kind == "drone" else 0.5
			elif global_position.x <= patrol_left + 8.0:
				direction = 1.0
			elif global_position.x >= patrol_right - 8.0:
				direction = -1.0
		"warning":
			if timer <= 0.0:
				state = "strike"
				timer = 0.3
				if kind == "drone":
					var bullet := BULLET.new()
					bullet.position = global_position + Vector2(0, -30)
					bullet.velocity = (target.global_position - bullet.position).normalized() * 230.0
					get_parent().add_child(bullet)
		"strike":
			if kind != "drone" and absf(offset.x) < 62.0 and in_lane:
				target.take_damage(1)
			if timer <= 0.0:
				state = "recover"
				timer = 0.9
		"recover":
			if timer <= 0.0:
				state = "patrol"
	var speed: float = {"guard": 45.0, "rat": 65.0, "dog": 85.0, "drone": 55.0}[kind]
	velocity.x = direction * speed if state == "patrol" else 0.0
	if state == "strike" and kind == "dog":
		velocity.x = direction * 240.0
	if kind == "drone":
		position.y = home_y + sin(clock * 2.0) * 12.0
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + 1600.0 * delta, 900.0)
	move_and_slide()
	global_position.x = clampf(global_position.x, patrol_left + 4.0, patrol_right - 4.0)
	sprite.flip_h = direction < 0
	sprite.modulate = Color(2, 0.7, 0.5) if flash > 0 else Color.WHITE
	sprite.rotation = sin(clock * 10.0) * 0.035 if state == "patrol" else 0.0
	queue_redraw()

func _can_see_target() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -40), target.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	flash = 0.18
	if health <= 0:
		defeated.emit()
		queue_free()

func _draw() -> void:
	if health < maximum:
		draw_rect(Rect2(-22, -104, 44, 4), Color(0.08, 0.07, 0.06))
		draw_rect(Rect2(-22, -104, 44.0 * health / maximum, 4), Color(0.9, 0.35, 0.2))
	if state == "warning":
		draw_circle(Vector2(0, -111 if kind == "guard" else -77), 5.0, Color(1, 0.7, 0.17))
		if kind == "drone" and is_instance_valid(target):
			draw_line(Vector2(0, -30), to_local(target.global_position), Color(1, 0.3, 0.2, 0.45), 1.5)
