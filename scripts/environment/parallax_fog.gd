extends Sprite2D

@export var speed: float = 18.0
@export var travel: float = 90.0
var _origin: Vector2
var _time: float = 0.0

func _ready() -> void:
	_origin = position

func _process(delta: float) -> void:
	_time += delta
	position = _origin + Vector2(sin(_time * speed * 0.01) * travel, cos(_time * speed * 0.006) * 16.0)
