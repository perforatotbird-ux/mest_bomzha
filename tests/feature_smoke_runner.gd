extends SceneTree
## Covers the four additions: cursor-aimed bottle, whole-bottle projectile,
## HUD health bar and the pigeon that bombs the drifter.

const LEVEL := preload("res://scenes/levels/sewer_test.tscn")
const BOTTLE := preload("res://scenes/projectiles/thrown_item.tscn")
const PIGEON := preload("res://scripts/level/pigeon.gd")
const HEALTH_BAR := preload("res://scripts/ui/health_bar.gd")

var passed := 0
var failed := 0
var level: Node2D
var player: Player

func _initialize() -> void:
	await run()
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s" % label)

func tick(count: int) -> void:
	for _i in count:
		await physics_frame

func run() -> void:
	level = LEVEL.instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	await tick(20)

	# 1. The projectile is a whole bottle that tumbles through its own frames.
	var bottle := BOTTLE.instantiate()
	var sprite := bottle.get_node("Sprite")
	check(sprite is AnimatedSprite2D, "bottle sprite is animated")
	var frames: SpriteFrames = sprite.sprite_frames
	check(frames.has_animation(&"spin"), "bottle spin animation present")
	check(frames.get_frame_count(&"spin") == 6, "bottle uses all six spin poses")
	check(frames.get_animation_loop(&"spin"), "bottle spin loops in flight")
	check(sprite.scale.x > 0.1 and sprite.scale.x < 0.2, "bottle sized for the drifter")
	bottle.free()

	# 2. Cursor aiming: speed follows distance and clamps at both ends.
	check(is_equal_approx(player._aim_speed(5.0), player.throw_speed_min), "close aim clamps to the minimum")
	check(player._aim_speed(400.0) > player._aim_speed(120.0), "further cursor throws harder")
	check(is_equal_approx(player._aim_speed(9000.0), player.throw_speed_max), "long aim clamps to the maximum")
	var mid := player._aim_speed(400.0)
	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	check(absf(mid - sqrt(400.0 * gravity)) < 1.0, "aim speed matches the ballistic arc")

	# 3. The throw follows the frozen aim, not the facing direction.
	player._throw_aim = Vector2(-180.0, -260.0)
	var before := level.get_child_count()
	player._emit_attack(&"throw", 1)
	await process_frame
	check(level.get_child_count() == before + 1, "throw spawns one bottle")
	var thrown: RigidBody2D = level.get_child(level.get_child_count() - 1)
	check(thrown.linear_velocity.is_equal_approx(Vector2(-180.0, -260.0)), "bottle flies along the aim vector")
	check(thrown.get_node("Sprite").flip_h, "leftward throw mirrors the bottle")
	thrown.free()

	# 4. Health bar tracks the player signal.
	var bar: Control = HEALTH_BAR.new()
	level.add_child(bar)
	bar.set_health(3, 5)
	check(bar.value == 3 and bar.maximum == 5, "bar stores health")
	player.health_changed.connect(bar.set_health)
	player.health = 5
	player.take_damage(2)
	await process_frame
	check(bar.value == 3, "bar follows damage")
	bar.free()

	# 5. A pigeon lines up over the drifter and drops something that hurts.
	player.health = player.max_health
	player._invulnerable = 0.0
	player.global_position = Vector2(560, 440)
	player.velocity = Vector2.ZERO
	await tick(4)
	var bird := PIGEON.new()
	bird.position = player.global_position + Vector2(0, -180)
	bird.patrol_left = 400.0
	bird.patrol_right = 760.0
	bird.target = player
	bird.drop_cooldown = 0.0
	level.add_child(bird)
	var dropped := false
	for _i in 180:
		await physics_frame
		if bird.state == "drop":
			dropped = true
			break
	check(dropped, "pigeon lines up and drops")
	var poop_found := false
	for child in level.get_children():
		var script_path := "" if child.get_script() == null else str(child.get_script().resource_path)
		if script_path.ends_with("pigeon_poop.gd"):
			poop_found = true
	check(poop_found, "drop spawns a falling projectile")
	await tick(60)
	check(player.health < player.max_health, "dropping hurts the drifter")
	check(bird.health == bird.maximum, "pigeon survives its own drop")

	# 6. A pigeon dies to the same damage interface as the ground enemies.
	var kills := [0]
	bird.defeated.connect(func() -> void: kills[0] += 1)
	bird.take_damage(2)
	await process_frame
	check(not is_instance_valid(bird), "pigeon dies to two hits")
	check(kills[0] == 1, "pigeon reports its death once")

	level.queue_free()
	await process_frame
