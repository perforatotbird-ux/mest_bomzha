extends CharacterBody2D
class_name Player

@export_group("Movement")
@export var move_speed: float = 320.0
@export var acceleration: float = 2200.0
@export var friction: float = 2400.0
@export var air_acceleration: float = 1400.0
@export var air_friction: float = 900.0
@export var crouch_speed_mult: float = 0.45

@export_group("Jump")
@export var jump_height: float = 120.0
@export var jump_time_to_peak: float = 0.35
@export var jump_time_to_descent: float = 0.28
@export var coyote_time: float = 0.1
@export var jump_buffer: float = 0.15
@export var apex_gravity_mult: float = 0.5

@export_group("Throw")
@export var throw_velocity: Vector2 = Vector2(520.0, -420.0)
@export var throw_cooldown: float = 0.3
@export var preview_seconds: float = 1.2
@export var preview_step: float = 0.04

@export_group("Rear Shot")
@export var rear_shot_speed: float = 620.0
@export var rear_shot_cooldown: float = 0.25
@export var rear_shot_recoil: float = 140.0

@export_group("Visuals")
@export var throw_hand_x: float = 18.0
@export var rear_hand_x: float = -16.0

const THROWN_ITEM: PackedScene = preload("res://scenes/projectiles/thrown_item.tscn")
const REAR_PELLET: PackedScene = preload("res://scenes/projectiles/rear_pellet.tscn")

@onready var collision_stand: CollisionShape2D = $CollisionStand
@onready var collision_crouch: CollisionShape2D = $CollisionCrouch
@onready var ceiling_check: RayCast2D = $CeilingCheck
@onready var body_wrap: Node2D = $Visual/BodyWrap
@onready var anim: AnimatedSprite2D = $Visual/BodyWrap/Anim
@onready var throw_origin: Marker2D = $Visual/ThrowOrigin
@onready var rear_origin: Marker2D = $Visual/RearOrigin
@onready var trajectory: Line2D = $Trajectory

var jump_velocity: float = 0.0
var jump_gravity: float = 0.0
var fall_gravity: float = 0.0
var projectile_gravity: float = 980.0

var facing: int = 1
var crouching: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _is_jumping: bool = false
var _was_airborne: bool = false
var _throw_cd: float = 0.0
var _rear_cd: float = 0.0
var _one_shot: String = ""
var _juice_tween: Tween

func _ready() -> void:
	jump_velocity = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
	jump_gravity = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
	fall_gravity = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0
	projectile_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	anim.animation_finished.connect(_on_anim_finished)
	if anim.sprite_frames.has_animation(&"idle"):
		anim.play(&"idle")

func _physics_process(delta: float) -> void:
	_throw_cd = maxf(_throw_cd - delta, 0.0)
	_rear_cd = maxf(_rear_cd - delta, 0.0)

	var input_x := Input.get_axis(&"move_left", &"move_right")
	if input_x < -0.1:
		facing = -1
	elif input_x > 0.1:
		facing = 1

	var gravity_mult := 1.0
	if _is_jumping and absf(velocity.y) < 100.0:
		gravity_mult = apex_gravity_mult
	if velocity.y < 0.0:
		velocity.y += jump_gravity * gravity_mult * delta
	else:
		velocity.y += fall_gravity * gravity_mult * delta

	if is_on_floor():
		_coyote_timer = coyote_time
		_is_jumping = false
	else:
		_coyote_timer -= delta

	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = jump_buffer
	else:
		_jump_buffer_timer -= delta

	_update_crouch()

	if _jump_buffer_timer > 0.0 and (_coyote_timer > 0.0 or is_on_floor()):
		if crouching and not ceiling_check.is_colliding():
			_set_crouch(false)
		velocity.y = jump_velocity
		_is_jumping = true
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_squash(Vector2(0.9, 1.1), 0.15)

	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	var speed := move_speed * (crouch_speed_mult if crouching else 1.0)
	var accel := acceleration if is_on_floor() else air_acceleration
	var fric := friction if is_on_floor() else air_friction
	if not is_zero_approx(input_x):
		velocity.x = move_toward(velocity.x, input_x * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	_update_throw()
	_update_rear_shot()

	move_and_slide()

	if _was_airborne and is_on_floor():
		_squash(Vector2(1.08, 0.92), 0.18)
		_play_one_shot(&"landing")
	_was_airborne = not is_on_floor()

	_update_visuals()

func _update_crouch() -> void:
	var wants := Input.is_action_pressed(&"crouch")
	if wants and is_on_floor() and not crouching:
		_set_crouch(true)
	elif not wants and crouching and not ceiling_check.is_colliding():
		_set_crouch(false)

func _set_crouch(active: bool) -> void:
	crouching = active
	collision_stand.disabled = active
	collision_crouch.disabled = not active

func _update_throw() -> void:
	var can := _throw_cd <= 0.0
	var aiming := can and Input.is_action_pressed(&"throw")
	trajectory.visible = aiming
	if aiming:
		_draw_trajectory()
	if can and Input.is_action_just_released(&"throw"):
		var item: RigidBody2D = THROWN_ITEM.instantiate()
		get_tree().current_scene.add_child(item)
		item.global_position = throw_origin.global_position
		item.linear_velocity = Vector2(facing * throw_velocity.x, throw_velocity.y)
		_throw_cd = throw_cooldown
		trajectory.visible = false
		_play_one_shot(&"throw")

func _draw_trajectory() -> void:
	var vel := Vector2(facing * throw_velocity.x, throw_velocity.y)
	var pos := throw_origin.global_position
	var points: PackedVector2Array = []
	var t := 0.0
	while t < preview_seconds:
		vel.y += projectile_gravity * preview_step
		pos += vel * preview_step
		t += preview_step
		points.append(trajectory.to_local(pos))
	trajectory.points = points

func _update_rear_shot() -> void:
	if _rear_cd > 0.0 or not Input.is_action_just_pressed(&"rear_shot"):
		return
	_rear_cd = rear_shot_cooldown
	var pellet: RigidBody2D = REAR_PELLET.instantiate()
	get_tree().current_scene.add_child(pellet)
	pellet.global_position = rear_origin.global_position
	pellet.linear_velocity = Vector2(-facing * rear_shot_speed, 0.0)
	velocity.x += facing * rear_shot_recoil
	_squash(Vector2(0.94, 1.06), 0.1)
	_play_one_shot(&"rear_shot")

func _update_visuals() -> void:
	anim.flip_h = facing < 0
	throw_origin.position.x = throw_hand_x * float(facing)
	rear_origin.position.x = rear_hand_x * float(facing)
	_update_animation()

func _update_animation() -> void:
	if _one_shot != "":
		return
	var target := &"idle"
	if not is_on_floor():
		target = &"fall" if velocity.y > 0.0 else &"jump"
	elif crouching:
		target = &"crouch_walk" if absf(velocity.x) > 8.0 else &"crouch"
	elif absf(velocity.x) > move_speed * 0.7:
		target = &"run"
	elif absf(velocity.x) > 8.0:
		target = &"walk"
	if anim.animation != target and anim.sprite_frames.has_animation(target):
		anim.play(target)

func _play_one_shot(name: StringName) -> void:
	if not anim.sprite_frames.has_animation(name):
		return
	_one_shot = String(name)
	anim.play(name)

func _on_anim_finished() -> void:
	if _one_shot != "":
		_one_shot = ""
		_update_animation()

func _squash(target: Vector2, dur: float) -> void:
	if _juice_tween and _juice_tween.is_valid():
		_juice_tween.kill()
	body_wrap.scale = Vector2.ONE
	_juice_tween = create_tween()
	_juice_tween.tween_property(body_wrap, "scale", target, dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_juice_tween.tween_property(body_wrap, "scale", Vector2.ONE, dur * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
