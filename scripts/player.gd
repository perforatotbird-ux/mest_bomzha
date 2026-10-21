extends CharacterBody2D
class_name Player

signal health_changed(current: int, maximum: int)
signal attack_emitted(kind: StringName)

@export_group("Movement")
@export var move_speed: float = 260.0
@export var acceleration: float = 2400.0
@export var air_acceleration: float = 1500.0
@export var air_friction: float = 650.0
@export var crouch_speed_mult: float = 0.4
@export_group("Jump")
@export var jump_height: float = 120.0
@export var jump_time_to_peak: float = 0.35
@export var jump_time_to_descent: float = 0.28
@export var coyote_time: float = 0.1
@export var jump_buffer: float = 0.15
@export_group("Attacks")
@export var throw_velocity := Vector2(520.0, -420.0)
@export var throw_cooldown: float = 0.4
@export var gas_cooldown: float = 0.65
@export var gas_speed: float = 460.0
@export var preview_seconds: float = 1.2
@export var preview_step: float = 0.04
@export_group("Health")
@export var max_health: int = 5
@export var invulnerability_time: float = 1.0

const THROWN_ITEM: PackedScene = preload("res://scenes/projectiles/thrown_item.tscn")
const GAS_BALL: PackedScene = preload("res://scenes/projectiles/rear_pellet.tscn")
const GAS_CLOUD = preload("res://scripts/gas_cloud.gd")
const RELEASE_FRAMES := {&"throw": 3, &"burp": 2, &"rear_shot": 2}

@onready var collision_stand: CollisionShape2D = $CollisionStand
@onready var collision_crouch: CollisionShape2D = $CollisionCrouch
@onready var stand_clearance: ShapeCast2D = $StandClearance
@onready var anim: AnimatedSprite2D = $Visual/BodyWrap/Anim
@onready var throw_origin: Marker2D = $Visual/ThrowOrigin
@onready var rear_origin: Marker2D = $Visual/RearOrigin
@onready var mouth_origin: Marker2D = $Visual/MouthOrigin
@onready var trajectory: Line2D = $Trajectory

var facing: int = 1
var crouching: bool = false
var health: int
var jump_velocity: float
var jump_gravity: float
var fall_gravity: float
var _spawn: Vector2
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _throw_cd: float = 0.0
var _gas_cd: float = 0.0
var _invulnerable: float = 0.0
var _action: StringName = &""
var _attack_facing: int = 1
var _emitted: bool = false
var _aiming: bool = false
var _dead: bool = false
var _respawn_timer: float = 0.0

func _ready() -> void:
	_spawn = global_position
	health = max_health
	jump_velocity = -2.0 * jump_height / jump_time_to_peak
	jump_gravity = 2.0 * jump_height / pow(jump_time_to_peak, 2.0)
	fall_gravity = 2.0 * jump_height / pow(jump_time_to_descent, 2.0)
	anim.animation_finished.connect(_on_animation_finished)
	anim.frame_changed.connect(_on_frame_changed)
	anim.play(&"idle")
	_update_origins()

func _physics_process(delta: float) -> void:
	_throw_cd = maxf(0.0, _throw_cd - delta)
	_gas_cd = maxf(0.0, _gas_cd - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	anim.modulate.a = 0.5 if _invulnerable > 0.0 and fmod(_invulnerable, 0.16) < 0.08 else 1.0
	if _dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			respawn()
		return
	if global_position.y > 1000.0:
		respawn()
		return

	var grounded := is_on_floor()
	var input_x := Input.get_axis(&"move_left", &"move_right")
	# Landing is cosmetic and interruptible. Attacks lock the pose and direction.
	if _action == &"landing" and (not is_zero_approx(input_x) or Input.is_action_just_pressed(&"jump")):
		_action = &""
	if not _is_attacking() and _action != &"hit" and not is_zero_approx(input_x):
		facing = -1 if input_x < 0.0 else 1
	_update_origins()
	_update_crouch()

	_coyote = coyote_time if grounded else maxf(0.0, _coyote - delta)
	_jump_buffer = jump_buffer if Input.is_action_just_pressed(&"jump") else maxf(0.0, _jump_buffer - delta)
	if not grounded:
		velocity.y = minf(velocity.y + (jump_gravity if velocity.y < 0.0 else fall_gravity) * delta, 1000.0)
	if _jump_buffer > 0.0 and _coyote > 0.0 and not _is_attacking() and _action != &"hit" and _can_stand():
		_set_crouch(false)
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_action = &""
	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	var locked := _is_attacking() or _action == &"hit"
	var axis := 0.0 if locked else input_x
	var speed := move_speed * (crouch_speed_mult if crouching else 1.0)
	if grounded and is_zero_approx(axis):
		velocity.x = 0.0 # No unwanted ground/landing drift.
	elif is_zero_approx(axis):
		velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
	else:
		velocity.x = move_toward(velocity.x, axis * speed, (acceleration if grounded else air_acceleration) * delta)

	_handle_attacks()
	move_and_slide()
	if not grounded and is_on_floor():
		if is_zero_approx(input_x) or _is_attacking():
			velocity.x = 0.0
		if _action == &"" and is_zero_approx(input_x):
			_play_action(&"landing")
	# Consume a buffered jump on the next physics tick; landing cannot block it.
	_update_animation()
	_update_preview()

func _can_stand() -> bool:
	stand_clearance.force_shapecast_update()
	return not stand_clearance.is_colliding()

func _update_crouch() -> void:
	if _is_attacking():
		return
	if Input.is_action_pressed(&"crouch") and is_on_floor():
		_set_crouch(true)
	elif crouching and _can_stand():
		_set_crouch(false)

func _set_crouch(active: bool) -> void:
	crouching = active
	collision_stand.set_deferred("disabled", active)
	collision_crouch.set_deferred("disabled", not active)

func _is_attacking() -> bool:
	return RELEASE_FRAMES.has(_action)

func _handle_attacks() -> void:
	if _is_attacking() or _action == &"hit":
		_aiming = false
		return
	if Input.is_action_just_pressed(&"throw") and _throw_cd <= 0.0:
		_aiming = true
	if _aiming and Input.is_action_just_released(&"throw"):
		_aiming = false
		if _throw_cd <= 0.0:
			_play_action(&"throw")
			_throw_cd = throw_cooldown
	elif Input.is_action_just_pressed(&"burp") and _gas_cd <= 0.0:
		_aiming = false
		_play_action(&"burp")
		_gas_cd = gas_cooldown
	elif Input.is_action_just_pressed(&"rear_shot") and _gas_cd <= 0.0:
		_aiming = false
		_play_action(&"rear_shot")
		_gas_cd = gas_cooldown

func _play_action(kind: StringName) -> void:
	_action = kind
	_attack_facing = facing
	_emitted = false
	anim.speed_scale = 1.0
	_set_sprite_transform(kind)
	anim.play(kind)

func _on_frame_changed() -> void:
	if _is_attacking() and not _emitted and anim.frame >= int(RELEASE_FRAMES[_action]):
		_emitted = true
		# AnimatedSprite emits in the idle step; do not mutate physics during callbacks.
		_emit_attack.call_deferred(_action, _attack_facing)

func _emit_attack(kind: StringName, direction: int) -> void:
	if _dead:
		return
	_update_origins()
	if kind == &"throw":
		var bottle := THROWN_ITEM.instantiate() as RigidBody2D
		get_tree().current_scene.add_child(bottle)
		bottle.global_position = throw_origin.global_position
		bottle.linear_velocity = Vector2(direction * throw_velocity.x, throw_velocity.y)
		bottle.angular_velocity = direction * 8.0
	else:
		var rear := kind == &"rear_shot"
		var shot_direction := -direction if rear else direction
		var origin := rear_origin if rear else mouth_origin
		var ball := GAS_BALL.instantiate() as CharacterBody2D
		get_tree().current_scene.add_child(ball)
		ball.global_position = origin.global_position
		ball.velocity = Vector2(shot_direction * gas_speed, 0.0)
		ball.get_node("Sprite").flip_h = shot_direction < 0
		var cloud := GAS_CLOUD.new()
		get_tree().current_scene.add_child(cloud)
		cloud.global_position = origin.global_position
		cloud.direction = shot_direction
	attack_emitted.emit(kind)

func _update_origins() -> void:
	throw_origin.position = Vector2(27.0 * facing, -57.0 if not crouching else -35.0)
	mouth_origin.position = Vector2(22.0 * facing, -61.0 if not crouching else -38.0)
	rear_origin.position = Vector2(-22.0 * facing, -29.0)
	anim.flip_h = facing < 0

func _update_preview() -> void:
	trajectory.visible = _aiming and not _is_attacking()
	if not trajectory.visible:
		return
	var points := PackedVector2Array()
	var origin := throw_origin.global_position
	var initial := Vector2(facing * throw_velocity.x, throw_velocity.y)
	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	var previous := origin
	var t := 0.0
	while t <= preview_seconds:
		var point := origin + initial * t + Vector2(0.0, 0.5 * gravity * t * t)
		var query := PhysicsRayQueryParameters2D.create(previous, point, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		points.append(trajectory.to_local(hit.position if not hit.is_empty() else point))
		if not hit.is_empty():
			break
		previous = point
		t += preview_step
	trajectory.points = points

func _update_animation() -> void:
	if _action != &"":
		return
	var target := &"idle"
	if not is_on_floor():
		target = &"jump" if velocity.y < 0.0 else &"fall"
	elif crouching:
		target = &"crouch_walk" if absf(velocity.x) > 4.0 else &"crouch"
	elif absf(velocity.x) > 4.0:
		target = &"run"
	_set_sprite_transform(target)
	# Match foot cadence to real movement, not a walk/run threshold flicker.
	anim.speed_scale = clampf(absf(velocity.x) / move_speed, 0.55, 1.15) if target == &"run" else 1.0
	if anim.animation != target:
		anim.play(target)

func _set_sprite_transform(kind: StringName) -> void:
	# Legacy fart frames have a different canvas. Both sets share the feet baseline.
	if kind == &"rear_shot":
		anim.scale = Vector2(0.44, 0.44)
		anim.position = Vector2(-10.0 * facing, -42.24)
	else:
		anim.scale = Vector2(0.22, 0.22)
		anim.position = Vector2(0.0, -45.76)

func _on_animation_finished() -> void:
	if _dead:
		return
	_action = &""
	_update_animation()

func take_damage(amount: int) -> void:
	if _dead or _invulnerable > 0.0 or amount <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	_invulnerable = invulnerability_time
	_aiming = false
	trajectory.visible = false
	if health == 0:
		_dead = true
		_respawn_timer = 1.2
		velocity = Vector2.ZERO
		_play_action(&"death")
	else:
		_play_action(&"hit")

func respawn() -> void:
	_dead = false
	health = max_health
	_invulnerable = invulnerability_time
	global_position = _spawn
	velocity = Vector2.ZERO
	_coyote = 0.0
	_jump_buffer = 0.0
	_action = &""
	_aiming = false
	_set_crouch(false)
	reset_physics_interpolation()
	$Camera2D.reset_smoothing()
	health_changed.emit(health, max_health)
	_update_animation()
