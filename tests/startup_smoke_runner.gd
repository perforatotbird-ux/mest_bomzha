extends SceneTree
## Runs after import. Do not depend on the Player global class in this validator:
## its absence is one of the errors this runner must report, not hide.
var failures: int = 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("STARTUP: " + message)

func run_tests() -> void:
	var main_path: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	var packed: PackedScene = load(main_path) as PackedScene
	if packed == null:
		push_error("STARTUP: main scene could not be loaded after import")
		quit(1)
		return
	var level: Node = packed.instantiate()
	if level == null:
		push_error("STARTUP: main scene could not be instantiated")
		quit(1)
		return
	root.add_child(level)
	current_scene = level
	for i in 30:
		await physics_frame
	var player: Node2D = level.get_node_or_null("Player") as Node2D
	check(player != null, "player node is missing")
	if player != null:
		check(player.get_script() != null and player.has_method("respawn"), "player controller failed to load")
		var sprite: AnimatedSprite2D = player.get_node_or_null("Visual/BodyWrap/Anim") as AnimatedSprite2D
		check(sprite != null and sprite.is_visible_in_tree(), "player sprite is missing or hidden")
		if sprite != null and sprite.sprite_frames != null:
			var frames: SpriteFrames = sprite.sprite_frames
			for animation: StringName in frames.get_animation_names():
				for index in frames.get_frame_count(animation):
					var texture: Texture2D = frames.get_frame_texture(animation, index)
					check(texture != null and texture.get_width() > 0 and texture.get_height() > 0, "missing animation texture: %s/%d" % [animation, index])
		else:
			check(false, "player animation resource failed to load")
		var screen: Vector2 = player.get_global_transform_with_canvas().origin
		var viewport: Rect2 = root.get_visible_rect()
		check(viewport.has_point(screen), "player spawned outside the camera view")
		var initial_x: float = player.position.x
		Input.action_press("move_right")
		for i in 10:
			await physics_frame
		Input.action_release("move_right")
		check(player.position.x > initial_x + 10.0, "player does not respond to movement")
	level.queue_free()
	await process_frame
	await process_frame
	print("Startup validation: %d failures" % failures)
	quit(1 if failures else 0)
