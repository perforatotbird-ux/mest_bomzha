extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
func run_tests() -> void:
	var frames: SpriteFrames = load("res://Assets/player_frames.tres")
	check(frames.get_frame_count("run") == 16, "run has 16 distinct phases")
	check(is_equal_approx(frames.get_animation_speed("run"), 24.0), "24 fps run cycle")
	check(frames.get_animation_loop("run"), "seamless looping enabled")
	var unique: Dictionary = {}
	for i in frames.get_frame_count("run"):
		var texture: Texture2D = frames.get_frame_texture("run", i)
		check(texture.get_size() == Vector2(384, 512), "same canvas and pivot, frame %d" % i)
		var image: Image = texture.get_image()
		unique[hash(image.get_data())] = true
	check(unique.size() == 16, "no duplicate run poses")
	var level: Node2D = load("res://scenes/levels/sewer_test.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Player = level.get_node("Player")
	for i in 30:
		await physics_frame
	Input.action_press("move_right")
	for i in 15:
		await physics_frame
	check(player.anim.animation == &"run", "movement plays the new run cycle")
	check(player.anim.speed_scale > 0.95, "cadence follows full movement speed")
	Input.action_release("move_right")
	for i in 3:
		await physics_frame
	check(is_zero_approx(player.velocity.x), "no added foot-driven ground sliding")
	level.queue_free()
	await process_frame
	await process_frame
	print("Run animation failures: ", failures)
	quit(1 if failures else 0)
