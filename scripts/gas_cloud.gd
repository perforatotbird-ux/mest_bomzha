extends Node2D
## Cosmetic gas; the independent swept ball owns damage.
const SOURCE: Texture2D = preload("res://Assets/Bomzh/frames/fart_02.png")
var direction: int = 1
var _age: float = 0.0
var _sprite: Sprite2D

func _ready() -> void:
	var cloud := AtlasTexture.new()
	cloud.atlas = SOURCE
	cloud.region = Rect2(119, 85, 79, 84)
	_sprite = Sprite2D.new()
	_sprite.texture = cloud
	_sprite.scale = Vector2(0.35, 0.35)
	_sprite.flip_h = direction > 0
	add_child(_sprite)

func _process(delta: float) -> void:
	_age += delta
	position += Vector2(direction * 35.0, -12.0) * delta
	_sprite.scale = Vector2.ONE * (0.35 + _age * 0.5)
	modulate.a = maxf(0.0, 1.0 - _age / 0.55)
	if _age >= 0.55:
		queue_free()
