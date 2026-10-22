extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var level: Node2D = load("res://scenes/levels/sewer_test.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Player = level.get_node("Player")
	for i in 40:
		await process_frame
	player.set_physics_process(false)
	player._set_sprite_transform(&"run")
	player.anim.play(&"run")
	player.anim.pause()
	for i in 16:
		player.anim.set_frame_and_progress(i, 0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/data/run_game_%02d.png" % i)
	level.queue_free()
	await process_frame
	quit()
