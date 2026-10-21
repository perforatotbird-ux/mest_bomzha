extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene: Node2D = load("res://scenes/levels/sewer_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png("/data/sewer_after.png")
	var player: Player = scene.get_node("Player")
	print("PLAYER ", player.position, " screen ", player.get_global_transform_with_canvas().origin, " sprite ", player.anim.get_global_transform_with_canvas(), " visible ", player.anim.is_visible_in_tree(), " texture ",player.anim.sprite_frames.get_frame_texture(player.anim.animation,player.anim.frame).get_size())
	quit()
