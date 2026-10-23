extends SceneTree
## Guards the three animation defects fixed in the player rig:
## crouch must animate, the airborne set must not shrink the character,
## and attacks must not run faster than the source pack's 8 fps.

const LEVEL := preload("res://scenes/levels/sewer_test.tscn")
const CAPTURE_DIR := "res://.workbuddy-ai/tmp/"

var passed := 0
var failed := 0
var scene: Node2D
var player: Player

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s" % label)

func tick(count: int) -> void:
	for _i in count:
		await physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

## Widest row of the head silhouette, scaled to world units. Pose-independent,
## so it measures how big the character is drawn rather than how he is posed.
func head_width(kind: StringName) -> float:
	var frames: SpriteFrames = player.anim.sprite_frames
	var image := frames.get_frame_texture(kind, 0).get_image()
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	var widest := 0
	for y in range(used.position.y, used.position.y + mini(45, used.size.y)):
		var first := -1
		var last := -1
		for x in range(used.position.x, used.position.x + used.size.x):
			if image.get_pixel(x, y).a > 0.06:
				if first < 0:
					first = x
				last = x
		widest = maxi(widest, last - first + 1)
	return widest * scale_for(kind)

func scale_for(kind: StringName) -> float:
	player._set_sprite_transform(kind)
	return player.anim.scale.x

func shot(name: String) -> void:
	if OS.get_environment("CAPTURE").is_empty():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	root.get_texture().get_image().save_png(CAPTURE_DIR + name + ".png")

func run() -> void:
	scene = LEVEL.instantiate()
	root.add_child(scene)
	current_scene = scene
	player = scene.get_node("Player")
	await tick(20)

	var frames: SpriteFrames = player.anim.sprite_frames

	# 1. Crouch has a real animation: four poses, played once, then held.
	check(frames.get_frame_count(&"crouch") == 4, "crouch uses all four poses")
	check(not frames.get_animation_loop(&"crouch"), "crouch plays once instead of looping")

	# 2. The character keeps one size in the air. Jump and landing are measured on
	# the head silhouette; fall is checked by scale alone because its raised arms
	# sit above the head and would skew a silhouette measurement.
	var idle_head := head_width(&"idle")
	for kind in [&"jump", &"landing"]:
		var ratio: float = head_width(kind) / idle_head
		check(ratio > 0.92 and ratio < 1.08, "%s keeps the idle character size (%.2f)" % [kind, ratio])
	for kind in [&"jump", &"fall", &"landing"]:
		check(is_equal_approx(scale_for(kind), scale_for(&"idle") * Player.AIRBORNE_SCALE_BOOST),
			"%s uses the airborne scale" % kind)

	# 3. Attacks are not faster than the pack's 8 fps.
	for kind in [&"throw", &"burp", &"rear_shot"]:
		var duration := frames.get_frame_count(kind) / frames.get_animation_speed(kind)
		check(duration >= 0.5, "%s lasts %.2fs, not a flash" % [kind, duration])

	# 4. Holding crouch descends once and holds the settled pose.
	key(KEY_S, true)
	await tick(6)
	check(player.crouching, "S crouches")
	check(player.anim.animation == &"crouch", "crouching plays the crouch animation")
	await shot("crouch_mid")
	await tick(30)
	var settled := player.anim.frame
	check(settled == frames.get_frame_count(&"crouch") - 1, "crouch settles on the last pose")
	await tick(30)
	check(player.anim.frame == settled, "settled crouch does not restart the descent")
	await shot("crouch_hold")

	# 5. Crouch-walking and stopping must not replay the stand-to-squat descent.
	key(KEY_D, true)
	await tick(10)
	check(player.anim.animation == &"crouch_walk", "crouch-walk while crouched")
	key(KEY_D, false)
	await tick(6)
	check(player.anim.frame == settled, "stopping keeps the settled crouch pose")
	key(KEY_S, false)
	await tick(6)
	check(not player.crouching, "releasing S stands up")
	check(player.anim.animation != &"crouch", "standing leaves the crouch pose")

	# 6. A real jump keeps the character at the boosted airborne size.
	key(KEY_SPACE, true)
	await tick(8)
	check(not player.is_on_floor(), "jump leaves the floor")
	check(is_equal_approx(player.anim.scale.x, Player.SPRITE_SCALE * Player.AIRBORNE_SCALE_BOOST),
		"jumping does not shrink the sprite")
	await shot("jump_air")
	key(KEY_SPACE, false)
	await tick(30)
	await shot("fall_air")

	await shot("idle")
	print("Results: %d passed, %d failed" % [passed, failed])
	scene.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)
