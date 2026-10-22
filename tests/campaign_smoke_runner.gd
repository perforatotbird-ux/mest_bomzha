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
	for i in 30:
		await physics_frame
	var player: Player = level.player
	check(level.LENGTH / player.move_speed >= 300.0, "route cannot be sprinted in under five minutes")
	check(level.SECTORS.size() == 8, "eight distinct sectors")
	var enemies: Array[Node] = get_nodes_in_group("level_enemies")
	var traps: Array[Node] = get_nodes_in_group("level_traps")
	var items: Array[Node] = get_nodes_in_group("level_interactions")
	check(enemies.size() >= 35, "populated encounters")
	check(traps.size() >= 30, "trap placements")
	var counts: Dictionary = {}
	for item in items:
		counts[item.kind] = int(counts.get(item.kind, 0)) + 1
	check(counts.get("secret", 0) == 8, "eight secrets")
	check(counts.get("valve", 0) == 4, "four required valves")
	check(counts.get("checkpoint", 0) == 9, "sector checkpoints plus exit refuge")
	check(level.gates.size() == 4, "four blocking gates")
	# Validate every required transition against the locked movement metrics.
	var previous: Dictionary = {}
	for surface: Dictionary in level.route:
		if surface.optional:
			continue
		if not previous.is_empty():
			check(surface.left - previous.right <= 110.0, "safe gap at %d" % surface.left)
			check(previous.top - surface.top <= 70.0, "reachable rise at %d" % surface.left)
		previous = surface
	# Functional enemy damage and death, not visual placeholders.
	var kinds: Dictionary = {}
	for enemy in enemies:
		kinds[enemy.kind] = true
	check(kinds.size() == 4, "four functional enemy types")
	var enemy: Node = enemies[0]
	var old_health: int = enemy.health
	enemy.take_damage(2)
	check(enemy.health == old_health - 2, "projectile-compatible damage interface")
	var kills: int = level.kills
	enemy.take_damage(999)
	await process_frame
	check(not is_instance_valid(enemy) and level.kills == kills + 1, "enemy death and kill counter")
	# Health, checkpoint and respawn roundtrip.
	player.set_checkpoint(Vector2(10160, 510))
	player.health = 1
	player.global_position = Vector2(11200, 200)
	player.respawn()
	check(player.global_position == Vector2(10160, 510), "respawn at latest checkpoint")
	check(player.health == player.max_health, "respawn restores health")
	# Valves remove their paired gate; exit must reject missing valves.
	var exit_item: Node
	for item in items:
		if item.kind == "exit":
			exit_item = item
	check(exit_item != null, "exit exists")
	exit_item.activate()
	check(not level.completed, "exit rejects missing valves")
	for item in items:
		if item.kind == "valve":
			item.activate()
	await process_frame
	check(level.valves == 4, "all four valves work")
	for gate in level.gates:
		check(not is_instance_valid(gate), "opened gate removed")
	for item in items:
		if item.kind == "secret":
			item.activate()
	check(level.secrets == 8, "secrets counted")
	for item in items:
		if item.kind == "secret":
			item.activate()
	check(level.secrets == 8, "no duplicate cache farming")
	# Trap phase/health path with a real overlap.
	var trap: Node2D = traps[0]
	player.global_position = trap.global_position + Vector2(0, -36)
	player._invulnerable = 0.0
	player.health = 5
	player.set_physics_process(false)
	trap.clock = 2.8 - trap.phase_offset
	for i in 6:
		await physics_frame
	check(trap.active and player.health == 4, "active trap damages player once during invulnerability")
	exit_item.activate()
	check(level.completed, "exit works after four valves")
	print("Campaign smoke: %d passed, %d failed. Enemies=%d traps=%d" % [passed, failures, enemies.size(), traps.size()])
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)
