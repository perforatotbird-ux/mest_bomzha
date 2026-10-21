extends Node2D

@export var preview_texture: Texture2D
@export var caption: String = "ENEMY"

@onready var label: Label = $Label

func _ready() -> void:
	label.text = caption
	if preview_texture:
		$Sprite2D.texture = preview_texture
