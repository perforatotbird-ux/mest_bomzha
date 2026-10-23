extends SceneTree
var failures: int = 0
var passed: int = 0
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, text: String) -> void:
	if ok:
		passed += 1
	else:
		failures += 1
		push_error("FAIL " + text)
func run_tests() -> void:
	var level: Node2D = load("res://scenes/levels/sewer_01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for i in 20:
		await physics_frame
	var player: Player = level.player
	var enemies: Array[Node] = get_nodes_in_group("level_enemies")
	for enemy in enemies:
		enemy.set_physics_process(false)
	for bird in get_nodes_in_group("pigeons"):
		bird.set_physics_process(false)
	for trap in get_nodes_in_group("level_traps"):
		trap.set_physics_process(false)
	player.set_physics_process(false)
	# Real player gas projectile hits a real enemy body on enemy collision layer 8.
	var guard: Node2D = enemies[0]
	player.global_position = guard.global_position + Vector2(-100, -35)
	player.facing = 1
	var hp: int = guard.health
	player._emit_attack(&"burp", 1)
	for i in 30:
		await physics_frame
	check(guard.health == hp - 2, "player gas damages placed enemy")
	# Real thrown bottle first-contact damage.
	var bottle: RigidBody2D = player.THROWN_ITEM.instantiate()
	bottle.position = guard.global_position + Vector2(-70, -40)
	bottle.gravity_scale = 0
	bottle.linear_velocity = Vector2(300, 0)
	level.add_child(bottle)
	hp = guard.health
	for i in 25:
		await physics_frame
	check(guard.health == hp - 3, "bottle damages placed enemy")
	check(not is_instance_valid(bottle), "bottle breaks on enemy contact")
	# Actual guard windup/strike damages stationary hero.
	player.global_position = guard.global_position + Vector2(-35, -35)
	player._invulnerable = 0
	player.health = 5
	guard.state = "patrol"
	guard.set_physics_process(true)
	for i in 65:
		await physics_frame
	check(player.health < 5, "guard warning then melee strike")
	guard.set_physics_process(false)
	# Drone winds up, fires and hits the hero with swept enemy projectile.
	var drone: Node2D
	for enemy in enemies:
		if enemy.kind == "drone":
			drone = enemy
			break
	player.global_position = drone.global_position + Vector2(-180, 90)
	player.health = 5
	player._invulnerable = 0
	drone.set_physics_process(true)
	for i in 160:
		await physics_frame
	check(player.health < 5, "drone telegraphs and shoots damaging projectile")
	drone.set_physics_process(false)
	# All eight optional alcoves reached by actual movement/jumps, no teleport to cache.
	for grate in get_nodes_in_group("secret_grates"):
		grate.take_damage(2)
	await process_frame
	check(get_nodes_in_group("secret_grates").is_empty(), "secret grates are breakable")
	player.set_physics_process(true)
	for sector in 8:
		var base: float = [540.0, 570.0, 530.0, 560.0, 520.0, 550.0, 540.0, 570.0][sector]
		var x: float = sector * 10000 + 4000
		player.position = Vector2(x + 100, base - 52)
		player.velocity = Vector2.ZERO
		player._action = &""
		player._dead = false
		player._invulnerable = 10000
		var before: int = level.secrets
		Input.action_release("jump")
		Input.action_press("move_right")
		for tick in 400:
			if level.secrets > before:
				break
			var origin: Vector2 = player.global_position
			var world: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
			var ahead := PhysicsRayQueryParameters2D.create(origin + Vector2(42, 30), origin + Vector2(42, 100), 1)
			var head := PhysicsRayQueryParameters2D.create(origin + Vector2(0, -20), origin + Vector2(42, -20), 1)
			if player.is_on_floor() and (world.intersect_ray(ahead).is_empty() or not world.intersect_ray(head).is_empty()):
				Input.action_press("jump")
			elif not player.is_on_floor() and player.velocity.y >= 0:
				Input.action_release("jump")
			await physics_frame
		check(level.secrets == before + 1, "physically reachable secret %d (x %.0f y %.0f)" % [sector + 1, player.position.x, player.position.y])
		Input.action_release("move_right")
		Input.action_release("jump")
	print("Campaign gameplay: %d passed, %d failed" % [passed, failures])
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)
