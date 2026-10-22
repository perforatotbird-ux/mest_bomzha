extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var level: Node2D = load("res://scenes/levels/sewer_01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Player = level.player
	var camera: Camera2D = player.get_node("Camera2D")
	var views: Array = [Vector2(1350, 460), Vector2(11170, 490), Vector2(21270, 450), Vector2(32680, 480), Vector2(44100, 440), Vector2(51250, 470), Vector2(61350, 460), Vector2(77500, 490)]
	for i in views.size():
		player.global_position = views[i]
		player.velocity = Vector2.ZERO
		player._invulnerable = 1000
		player.set_physics_process(true)
		player.reset_physics_interpolation()
		camera.reset_smoothing()
		for tick in 50:
			await physics_frame
		player.set_physics_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/data/campaign_sector_%02d.png" % (i + 1))
	level.queue_free()
	await process_frame
	quit(0)
