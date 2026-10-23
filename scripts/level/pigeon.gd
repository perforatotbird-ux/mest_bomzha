extends CharacterBody2D
class_name Pigeon
## Flying vermin: hunts the drifter instead of waiting to be flown over. It holds a
## slot above and to one side, telegraphs where the bomb will land, then swoops in
## flat and fast from alternating flanks. It keeps coming back until it is shot.
signal defeated

const POOP := preload("res://scripts/level/pigeon_poop.gd")
const FRAMES: SpriteFrames = preload("res://Assets/Enemies/pigeon_frames.tres")
## Feet to head of the bird in the source frames.
const BODY_PX := 146.0
## Body centre relative to the middle of the 256 px frame.
const BODY_OFFSET := Vector2(0.0, -35.0)
## Matches the gravity inside pigeon_poop.gd.
const BOMB_GRAVITY := 1200.0

enum State { PATROL, HUNT, WINDUP, SWOOP, RECOVER }

@export var patrol_left: float = 0.0
@export var patrol_right: float = 300.0
@export var cruise_speed: float = 96.0
@export var hunt_speed: float = 215.0
@export var sight_range: float = 560.0
@export var give_up_range: float = 1500.0
@export var drop_cooldown: float = 0.85
@export var display_height: float = 40.0

var target: Node2D
var health: int = 2
var maximum: int = 2
var state: State = State.PATROL
var timer: float = 0.0
var direction: float = -1.0

var _home_y: float
var _clock: float = 0.0
var _cooldown: float = 0.0
var _flash: float = 0.0
var _sprite: AnimatedSprite2D
var _splash: Vector2 = Vector2.ZERO
var _aiming: bool = false
var _flank: int = -1

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
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = FRAMES
	_sprite.animation = &"flap"
	_sprite.offset = BODY_OFFSET
	_sprite.scale = Vector2.ONE * (display_height / BODY_PX)
	add_child(_sprite)
	_sprite.play(&"flap")
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
		State.PATROL:
			if offset.length() < sight_range and offset.y > 30.0:
				state = State.HUNT
			elif global_position.x <= patrol_left + 6.0:
				direction = 1.0
			elif global_position.x >= patrol_right - 6.0:
				direction = -1.0
		State.HUNT:
			# Hold above and to one side; the side flips after every pass so the
			# drifter cannot just walk out of the line of fire.
			var want := target.global_position + Vector2(_flank * 115.0, -155.0) if is_instance_valid(target) else global_position
			var steer: Vector2 = want - global_position
			var approach: float = minf(hunt_speed, steer.length() * 4.0)
			velocity = steer.normalized() * approach if steer.length() > 1.0 else Vector2.ZERO
			if steer.length() < 50.0 and _cooldown <= 0.0:
				state = State.WINDUP
				timer = 0.32
				_aiming = true
			elif offset.length() > give_up_range:
				state = State.PATROL
		State.WINDUP:
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
			if is_instance_valid(target):
				# The marker tracks the drifter as he runs, so it never lies.
				_splash = _predict_landing()
			if timer <= 0.0:
				state = State.SWOOP
				timer = 0.28
				_aiming = false
				_drop()
		State.SWOOP:
			# Dive at the drifter, not at the ground: the bomb comes out flat and fast.
			if is_instance_valid(target):
				velocity = (target.global_position - global_position).normalized() * 330.0
			if timer <= 0.0:
				state = State.RECOVER
				timer = 0.35
				_cooldown = drop_cooldown
				_flank = -_flank
		State.RECOVER:
			velocity.y = move_toward(velocity.y, -190.0, 700.0 * delta)
			velocity.x = move_toward(velocity.x, direction * cruise_speed, 320.0 * delta)
			if timer <= 0.0:
				state = State.HUNT
	var wanted := direction * cruise_speed
	if state == State.PATROL:
		velocity.x = move_toward(velocity.x, wanted, 420.0 * delta)
		velocity.y = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, patrol_left, patrol_right)
	position.y = clampf(position.y, _home_y - 300.0, _home_y + 300.0)
	if absf(velocity.x) > 2.0:
		direction = signf(velocity.x)
	# The body rides the flap: it lifts while the wings push down.
	var flap := (float(_sprite.frame) + _sprite.frame_progress) / 4.0 * TAU
	position.y += -cos(flap) * 2.0
	_sprite.flip_h = direction < 0.0
	_sprite.rotation = clampf(velocity.x / 520.0, -0.16, 0.16)
	_sprite.modulate = Color(2.0, 0.75, 0.55) if _flash > 0.0 else Color.WHITE
	queue_redraw()

func _ground_below() -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 900), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else global_position + Vector2(0, 240)

## Where the bomb will actually touch down, leading the drifter's own motion so a
## running player is aimed at rather than the ground he has already left. The spot
## is clamped to what the bomb can reach sideways, so the marker never promises
## more than the drop delivers.
func _predict_landing() -> Vector2:
	var ground := _ground_below()
	var fall: float = sqrt(maxf(0.0, (ground.y - global_position.y) * 2.0 / BOMB_GRAVITY))
	var spot := Vector2(global_position.x, ground.y)
	if is_instance_valid(target):
		var motion := Vector2.ZERO
		if target is CharacterBody2D:
			motion = (target as CharacterBody2D).velocity
		spot.x = target.global_position.x + motion.x * fall * 0.85
	var reach: float = fall * 520.0
	spot.x = global_position.x + clampf(spot.x - global_position.x, -reach, reach)
	return spot

func _drop() -> void:
	var host := get_parent()
	if host == null:
		return
	var ground := _ground_below()
	var fall: float = sqrt(maxf(0.0, (ground.y - global_position.y) * 2.0 / BOMB_GRAVITY))
	var landing := _predict_landing()
	# Pick the sideways speed that puts the bomb on the marked spot.
	var push: float = clampf((landing.x - global_position.x) / maxf(fall, 0.05), -520.0, 520.0)
	var poop := POOP.new()
	poop.position = global_position + Vector2(0, 14)
	poop.velocity = Vector2(push, 0.0)
	host.add_child(poop)
	_splash = landing

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
		# Telegraphed landing spot: it closes in as the drop lands, so the drifter
		# can read both where and when.
		var at := to_local(_splash)
		var closing := 1.0 - timer / 0.32
		draw_arc(at, 20.0 - 11.0 * closing, 0.0, TAU, 22, Color(1, 0.85, 0.4, 0.55), 2.0)
		draw_circle(at, 4.0, Color(1, 0.9, 0.5, 0.75))
