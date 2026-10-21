extends StaticBody2D

@export var collision_size: Vector2 = Vector2(220, 34)
@export var pillar_height: float = 0.0
@export var pillar_width: float = 54.0
@export var pipe_radius: float = 14.0
@export var tint: Color = Color(1, 1, 1, 1)

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var pillar: ColorRect = $Decor/Pillar
@onready var pipe: ColorRect = $Decor/Pipe
@onready var grime: ColorRect = $Decor/Grime

func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = collision_size
	shape.shape = rect
	_update_visuals()

func _update_visuals() -> void:
	if sprite.texture:
		var tex_size := sprite.texture.get_size()
		sprite.scale = Vector2(collision_size.x / tex_size.x, maxf(0.36, collision_size.y / tex_size.y))
		sprite.position.y = -collision_size.y * 0.5 + tex_size.y * 0.5 * sprite.scale.y
	sprite.modulate = tint
	grime.visible = false
	grime.size = Vector2(collision_size.x * 0.82, 18)
	grime.position = Vector2(-grime.size.x * 0.5, -2)
	var has_pillar := pillar_height > 0.0
	pillar.visible = has_pillar
	pipe.visible = has_pillar
	if has_pillar:
		pillar.size = Vector2(pillar_width, pillar_height)
		pillar.position = Vector2(-pillar_width * 0.5, collision_size.y * 0.33)
		pipe.size = Vector2(pipe_radius * 2.0, pillar_height)
		pipe.position = Vector2(-pipe.size.x * 0.5, collision_size.y * 0.33)
