extends CharacterBody2D
## Flying vermin: cruises a lane above the route, lines up over the player and bombs.
## No gravity and no world collision: it lives in the air between the ledges.
signal defeated

const POOP := preload("res://scripts/level/pigeon_poop.gd")
const TEXTURE := preload("res://Assets/Enemies/pigeon.tres")

@export var patrol_left: float = 0.0
@export var patrol_right: float = 300.0
@export var cruise_speed: float = 78.0
@export var chase_speed: float = 125.0
@export var sight_range: float = 430.0
@export var drop_cooldown: float = 2.4
@export var display_height: float = 44.0

var target: Node2D
var health: int = 2
var maximum: int = 2
var state: String = "cruise"
var timer: float = 0.0
var direction: float = -1.0

var _home_y: float
var _clock: float = 0.0
var _cooldown: float = 0.0
var _flash: float = 0.0
var _sprite: Sprite2D
var _splash: Vector2 = Vector2.ZERO
var _aiming: bool = false

func _ready() -> void:
	# Own group: the ground-enemy scripts and tests assume a patrol FSM and a `kind`.
	add_to_group("pigeons")
	collision_layer = 8
	collision_mask = 0
	_home_y = position.y
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.scale = Vector2.ONE * display_height / TEXTURE.get_height()
	add_child(_sprite)
	z_index = 5

func _physics_process(delta: float) -> void:
	_clock += delta
	timer = maxf(0.0, timer - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_flash = maxf(0.0, _flash - delta)
	var offset := Vector2.ZERO
	if is_instance_valid(target):
		offset = target.global_position - global_position
	match state:
		"cruise":
			# Only birds with a target below them bother to line up a drop.
			if absf(offset.x) < sight_range and offset.y > 40.0 and _cooldown <= 0.0:
				state = "aim"
				timer = 0.5
				_aiming = true
				_splash = _ground_below()
			elif global_position.x <= patrol_left + 6.0:
				direction = 1.0
			elif global_position.x >= patrol_right - 6.0:
				direction = -1.0
		"aim":
			if timer <= 0.0:
				state = "drop"
				timer = 0.35
				_aiming = false
				_drop()
		"drop":
			if timer <= 0.0:
				state = "cruise"
				_cooldown = drop_cooldown
	var wanted := direction * cruise_speed
	if state != "cruise":
		# Slide over the target instead of orbiting past it.
		wanted = clampf(offset.x * 3.0, -chase_speed, chase_speed)
	velocity.x = move_toward(velocity.x, wanted, 420.0 * delta)
	velocity.y = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, patrol_left, patrol_right)
	position.y = _home_y + sin(_clock * 2.1) * 9.0
	if absf(velocity.x) > 2.0:
		direction = signf(velocity.x)
	_sprite.flip_h = direction < 0.0
	_sprite.modulate = Color(2.0, 0.75, 0.55) if _flash > 0.0 else Color.WHITE
	queue_redraw()

func _ground_below() -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 900), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else global_position + Vector2(0, 240)

func _drop() -> void:
	var host := get_parent()
	if host == null:
		return
	var poop := POOP.new()
	poop.position = global_position + Vector2(0, 18)
	host.add_child(poop)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	_flash = 0.18
	if health <= 0:
		defeated.emit()
		queue_free()

func _draw() -> void:
	if health < maximum:
		draw_rect(Rect2(-20, -48, 40, 4), Color(0.08, 0.07, 0.06))
		draw_rect(Rect2(-20, -48, 40.0 * health / maximum, 4), Color(0.9, 0.35, 0.2))
	if _aiming:
		# Telegraphed landing spot so a drop is dodgeable, not a coin flip.
		var at := to_local(_splash)
		var closing := 1.0 - timer / 0.5
		draw_arc(at, 20.0 - 10.0 * closing, 0.0, TAU, 22, Color(1, 0.85, 0.4, 0.55), 2.0)
		draw_circle(at, 4.0, Color(1, 0.9, 0.5, 0.75))
