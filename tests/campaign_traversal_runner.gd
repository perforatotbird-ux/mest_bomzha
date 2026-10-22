extends SceneTree
## Automated geometry traversal at full movement speed. Damage is disabled only
## for this geometry test; trap damage is verified by campaign_smoke_runner.
var failures: int = 0
func _initialize() -> void:
	call_deferred("run_route")
func run_route() -> void:
	var level: Node2D = load("res://scenes/levels/sewer_01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for i in 15:
		await physics_frame
	var player: Player = level.player
	player._invulnerable = 10000.0
	Input.action_press("move_right")
	var last_x: float = player.position.x
	var stuck_ticks: int = 0
	var jumps: int = 0
	for tick in 24000:
		if level.completed:
			break
		for item in get_nodes_in_group("level_interactions"):
			if item.kind == "valve" and not item.used and player.position.distance_to(item.position) < 85.0:
				item.activate()
		var origin: Vector2 = player.global_position
		var world: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
		var ahead := PhysicsRayQueryParameters2D.create(origin + Vector2(42, 30), origin + Vector2(42, 100), 1)
		var head := PhysicsRayQueryParameters2D.create(origin + Vector2(0, -20), origin + Vector2(42, -20), 1)
		if player.is_on_floor() and (world.intersect_ray(ahead).is_empty() or not world.intersect_ray(head).is_empty()):
			Input.action_press("jump")
			jumps += 1
		elif not player.is_on_floor() and player.velocity.y >= 0:
			Input.action_release("jump")
		await physics_frame
		if player.position.x < last_x - 100:
			failures += 1
			push_error("Traversal fell/respawned at %.1f" % last_x)
			break
		if absf(player.position.x - last_x) < 0.5:
			stuck_ticks += 1
		else:
			stuck_ticks = 0
		if stuck_ticks > 180:
			failures += 1
			push_error("Traversal stuck at %.1f y %.1f" % [player.position.x, player.position.y])
			break
		last_x = player.position.x
		if tick % 3000 == 0:
			print("Route progress: %.0f px / %.1f sec" % [last_x, level.elapsed])
	Input.action_release("move_right")
	Input.action_release("jump")
	if not level.completed:
		failures += 1
		push_error("End-to-end traversal did not reach exit")
	print("Traversal: x=%.1f time=%.1fs jumps=%d returns=%d failures=%d" % [last_x, level.elapsed, jumps, level.deaths, failures])
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)
