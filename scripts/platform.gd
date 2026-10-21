extends StaticBody2D

@export var shape_size: Vector2 = Vector2(160, 24)
@export var color: Color = Color(0.36, 0.47, 0.7, 1)

@onready var shape: CollisionShape2D = $Shape
@onready var visual: ColorRect = $Visual

func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = shape_size
	shape.shape = rect
	visual.size = shape_size
	visual.position = -shape_size * 0.5
	visual.color = color
