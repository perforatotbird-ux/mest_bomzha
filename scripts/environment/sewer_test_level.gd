extends Node2D

const HEALTH_BAR = preload("res://scripts/ui/health_bar.gd")

var completed: bool = false
@onready var player: Player = $Player
@onready var status: Label = $HUD/Status

func _ready() -> void:
	var bar: Control = HEALTH_BAR.new()
	bar.position = Vector2(624, 22)
	bar.size = Vector2(210, 26)
	bar.set_health(player.health, player.max_health)
	player.health_changed.connect(bar.set_health)
	$HUD.add_child(bar)

func _process(_delta: float) -> void:
	if not completed and player.global_position.x > 2220.0 and player.is_on_floor() and player.global_position.y < 450.0:
		completed = true
		status.text = "ТЕСТ ПРОЙДЕН • Выход найден!   R — заново"
		$Level/ExitDoor/Glow.color = Color(0.5, 1.0, 0.25, 0.28)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		completed = false
		status.text = "01 / КАНАЛИЗАЦИЯ     •     Найди выход справа"
		$Level/ExitDoor/Glow.color = Color(1, 0.74, 0.3, 0.12)
		player.respawn()
