extends Node2D
## One-shot shatter effect: the bottle itself is freed on impact, this sells the break.
const FRAMES: SpriteFrames = preload("res://Assets/Projectiles/glass_frames.tres")

func _ready() -> void:
	z_index = 6
	rotation = randf_range(-0.5, 0.5)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.scale = Vector2.ONE * 0.14
	add_child(sprite)
	sprite.animation_finished.connect(queue_free)
	sprite.play(&"shatter")
