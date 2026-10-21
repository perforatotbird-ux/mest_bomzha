extends StaticBody2D

@export var collision_size: Vector2 = Vector2(220, 28)
@export var chain_height: float = 160.0

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var chain_left: Sprite2D = $ChainLeft
@onready var chain_right: Sprite2D = $ChainRight

func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = collision_size
	shape.shape = rect
	if sprite.texture:
		var tex_size: Vector2 = sprite.texture.get_size()
		sprite.scale = Vector2(collision_size.x / tex_size.x, 0.40)
		sprite.position.y = -collision_size.y * 0.5 + (tex_size.y * 0.5 - 150.0) * sprite.scale.y
	if chain_left.texture:
		var csize: Vector2 = chain_left.texture.get_size()
		var y_scale: float = maxf(0.5, chain_height / csize.y)
		chain_left.scale = Vector2(1.0, y_scale)
		chain_right.scale = Vector2(1.0, y_scale)
	chain_left.position = Vector2(-collision_size.x * 0.34 - 12.0, -chain_height - collision_size.y * 0.5)
	chain_right.position = Vector2(collision_size.x * 0.34 - 12.0, -chain_height - collision_size.y * 0.5)
