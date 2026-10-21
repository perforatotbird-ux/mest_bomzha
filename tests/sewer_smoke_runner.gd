extends SceneTree
const LEVEL = preload("res://scenes/levels/sewer_test.tscn")
var passed: int = 0
var failed: int = 0
var level: Node2D
var player: Player

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func traverse(jump_x: float, target_name: String) -> void:
	Input.action_press("move_right")
	var jumped: bool = false
	var airborne: bool = false
	var landed: bool = false
	var target: StaticBody2D = level.get_node("Level/" + target_name)
	var target_top: float = target.position.y - target.collision_size.y * 0.5
	for i in range(240):
		if not jumped and player.is_on_floor() and player.position.x >= jump_x:
			Input.action_press("jump")
			jumped = true
		if jumped and not player.is_on_floor():
			airborne = true
		if airborne and player.is_on_floor():
			landed = absf(player.position.y + 36.0 - target_top) < 3.0 and absf(player.position.x - target.position.x) < target.collision_size.x * 0.5 + 14.0
			break
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("jump")
	await frames(2)
	check(landed, "jump to " + target_name + " at " + str(player.position))

func run_tests() -> void:
	level = LEVEL.instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	await frames(30)
	check(player.is_on_floor(), "safe spawn")
	check(level.get_node("SewerParallaxBG").get_child_count() == 3, "three parallax layers")
	var far: ParallaxLayer = level.get_node("SewerParallaxBG/Far")
	var mid: ParallaxLayer = level.get_node("SewerParallaxBG/Mid")
	var near: ParallaxLayer = level.get_node("SewerParallaxBG/Near")
	check(far.motion_scale.x < mid.motion_scale.x and mid.motion_scale.x < near.motion_scale.x, "parallax depth ordering")
	check(not level.has_node("Backdrop"), "no opaque overlay hiding parallax")
	var texture: Texture2D = level.get_node("SewerParallaxBG/Far/FarSprite").texture
	check(texture.get_size() == Vector2(2048, 1024), "embedded background decodes losslessly")
	var a: StaticBody2D = level.get_node("Level/StartPlatform")
	var b: StaticBody2D = level.get_node("Level/MidPlatform")
	check(a.get_node("CollisionShape2D").shape != b.get_node("CollisionShape2D").shape, "independent collision shapes")
	for placeholder in level.get_node("Level/Placeholders").get_children():
		check(not placeholder is PhysicsBody2D and not placeholder.has_method("take_damage"), "visual-only placeholder: " + placeholder.name)
	await traverse(395.0, "MidPlatform")
	await traverse(714.0, "HangingBridge")
	await traverse(1110.0, "CenterPlatform")
	await traverse(1440.0, "TopRightPlatform")
	await traverse(1850.0, "DoorPlatform")
	Input.action_press("move_right")
	for i in range(150):
		if level.completed:
			break
		await physics_frame
	Input.action_release("move_right")
	check(level.completed, "exit reached without teleportation")
	player.position = Vector2(1220, 750)
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	await frames(12)
	check(player.position.x < 200 and player.position.y < 470, "acid respawns player")
	check(player.health == player.max_health, "respawn restores health")
	level.queue_free()
	await process_frame
	await process_frame
	print("Sewer results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
