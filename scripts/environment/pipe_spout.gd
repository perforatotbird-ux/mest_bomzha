extends Node2D

@export var fall_height: float = 260.0
@export var fall_width: float = 20.0
var _time: float = 0.0

@onready var fall: ColorRect = $AcidFall
@onready var splash: ColorRect = $Splash

func _ready() -> void:
	_apply()

func _process(delta: float) -> void:
	_time += delta
	fall.modulate.a = 0.84 + sin(_time * 8.0) * 0.08
	splash.modulate.a = 0.75 + sin(_time * 6.0 + 1.1) * 0.12

func _apply() -> void:
	fall.size = Vector2(fall_width, fall_height)
	fall.position = Vector2(70, 134)
	splash.size = Vector2(fall_width * 2.8, 18)
	splash.position = Vector2(70 - splash.size.x * 0.3, 134 + fall_height - 8)
