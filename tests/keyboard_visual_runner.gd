extends SceneTree
var scene: Node2D
var player: Player
var failures: int = 0
func _initialize() -> void:
	call_deferred("run_tests")
func tick(count: int) -> void:
	for i in count:
		await physics_frame
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
func shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/data/" + name + ".png")
func run_tests() -> void:
	scene = load("res://scenes/levels/sewer_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	player = scene.get_node("Player")
	await tick(30)
	var start: Vector2 = player.position
	var screen: Vector2 = player.get_global_transform_with_canvas().origin
	check(player.anim.is_visible_in_tree(), "player sprite visible")
	check(screen.x > 120 and screen.x < 1160 and screen.y > 100 and screen.y < 620, "player framed away from screen edges")
	await shot("sewer_playable_start")
	key(KEY_D, true)
	await tick(22)
	key(KEY_D, false)
	await tick(2)
	check(player.position.x > start.x + 65.0, "physical D key moves player")
	await shot("sewer_playable_run")
	var floor_y: float = player.position.y
	key(KEY_SPACE, true)
	await tick(12)
	check(player.position.y < floor_y - 60.0, "physical Space key jumps")
	await shot("sewer_playable_jump")
	key(KEY_SPACE, false)
	await tick(45)
	key(KEY_A, true)
	var x: float = player.position.x
	await tick(12)
	key(KEY_A, false)
	check(player.position.x < x - 20.0, "physical A key moves left")
	await tick(4)
	key(KEY_E, true)
	await tick(1)
	key(KEY_E, false)
	await tick(18)
	await shot("sewer_playable_attack")
	check(player.anim.sprite_frames.has_animation("burp"), "burp animation preserved")
	print("Keyboard/visibility failures: ", failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
