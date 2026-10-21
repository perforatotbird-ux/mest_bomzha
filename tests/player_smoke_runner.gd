extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const THROWN_SCENE := preload("res://scenes/projectiles/thrown_item.tscn")
const GAS_SCENE := preload("res://scenes/projectiles/rear_pellet.tscn")
const DummyEnemy = preload("res://tests/dummy_enemy.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	await run_tests()
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func assert_true(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s" % label)

func run_tests() -> void:
	await process_frame
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var player: Player = main.get_node("Player")
	assert_true(player.anim.sprite_frames.has_animation("burp"), "burp animation registered")
	assert_true(player.anim.sprite_frames.has_animation("rear_shot"), "rear_shot animation registered")
	assert_true(player.anim.sprite_frames.has_animation("throw"), "throw animation registered")
	assert_true(is_equal_approx(player.anim.sprite_frames.get_animation_speed("idle"), 3.0), "idle slowed down")

	var before_children := current_scene.get_child_count()
	player._emit_attack(&"throw", 1)
	await process_frame
	assert_true(current_scene.get_child_count() == before_children + 1, "throw spawns projectile")
	var spawned_bottle := current_scene.get_child(current_scene.get_child_count() - 1)
	assert_true(spawned_bottle is RigidBody2D, "thrown bottle type")

	player._emit_attack(&"burp", 1)
	await process_frame
	var found_ball := false
	var found_cloud := false
	for child in current_scene.get_children():
		if child.name == "GasBall":
			found_ball = true
		elif child.get_script() != null and str(child.get_script().resource_path).ends_with("gas_cloud.gd"):
			found_cloud = true
	assert_true(found_ball, "burp spawns gas ball")
	assert_true(found_cloud, "burp spawns gas cloud")

	var enemy := DummyEnemy.new()
	current_scene.add_child(enemy)
	enemy.global_position = Vector2(220, 358)
	await process_frame
	var pellet := GAS_SCENE.instantiate()
	current_scene.add_child(pellet)
	pellet.global_position = enemy.global_position + Vector2(-50, 0)
	pellet.velocity = Vector2(400, 0)
	for _i in 10:
		await physics_frame
	assert_true(enemy.damage_taken >= 2, "gas projectile damages enemy")

	var enemy2 := DummyEnemy.new()
	current_scene.add_child(enemy2)
	await process_frame
	var bottle := THROWN_SCENE.instantiate()
	current_scene.add_child(bottle)
	bottle._on_body_entered(enemy2)
	await process_frame
	assert_true(enemy2.damage_taken >= 3, "bottle damages enemy on hit")

	main.queue_free()
	await process_frame
