extends Node2D
## Authored eight-sector route, assembled from explicit encounter beats, not random generation.
const LENGTH: float = 80400.0
const SECTOR_LENGTH: float = 10000.0
const SECTORS := ["ВХОДНОЙ КОЛЛЕКТОР", "КРЫСИНЫЕ НОРЫ", "ПАРОВЫЕ МАГИСТРАЛИ", "РЖАВЫЕ МОСТЫ", "НАСОСНАЯ СТАНЦИЯ", "КАБЕЛЬНЫЕ ГАЛЕРЕИ", "КАРАНТИННЫЙ ПОСТ", "ВЫПУСКНОЙ ШЛЮЗ"]
const BEATS := [
	["rest", "patrol", "gaps", "steam", "secret", "patrol", "bridge", "steam", "pack", "rest"],
	["rest", "rats", "gaps", "steam", "secret", "rats", "stairs", "crusher", "pack", "valve"],
	["rest", "steam", "stairs", "patrol", "secret", "steam", "bridge", "crusher", "drone", "rest"],
	["rest", "bridge", "drone", "gaps", "secret", "crusher", "bridge", "pack", "arc", "valve"],
	["rest", "patrol", "stairs", "crusher", "secret", "drone", "gaps", "steam", "pack", "rest"],
	["rest", "arc", "bridge", "drone", "secret", "arc", "stairs", "pack", "crusher", "valve"],
	["rest", "pack", "gaps", "crusher", "secret", "patrol", "stairs", "arc", "drone", "rest"],
	["rest", "steam", "bridge", "pack", "secret", "arc", "gaps", "crusher", "pack", "valve"]
]
const PLATFORM = preload("res://scenes/environment/sewer_platform.tscn")
const BRIDGE = preload("res://scenes/environment/hanging_platform.tscn")
const ACID = preload("res://scenes/environment/acid_pool.tscn")
const LAMP = preload("res://scenes/environment/lamp_prop.tscn")
const ENEMY = preload("res://scripts/level/sewer_enemy.gd")
const PIGEON = preload("res://scripts/level/pigeon.gd")
const TRAP = preload("res://scripts/level/sewer_trap.gd")
const INTERACTION = preload("res://scripts/level/level_interaction.gd")
const GRATE = preload("res://scripts/level/breakable_grate.gd")
const HEALTH_BAR = preload("res://scripts/ui/health_bar.gd")
var player: Player
var elapsed: float = 0.0
var secrets: int = 0
var valves: int = 0
var kills: int = 0
var completed: bool = false
var deaths: int = 0
var current_sector: int = -1
var notice_time: float = 0.0
var status: Label
var message: Label
var controls: Label
var health_bar: Control
var gates: Array[StaticBody2D] = []
var route: Array[Dictionary] = []

func _ready() -> void:
	player = $Player
	player.add_to_group("player")
	player.respawned.connect(func() -> void: deaths += 1)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = -80
	camera.limit_right = int(LENGTH + 300)
	camera.limit_bottom = 850
	camera.reset_smoothing()
	_make_hud()
	_build_route()
	notice("Выход в конце коллектора • Вентили: V • Тайники лечат")

func _build_route() -> void:
	for sector in 8:
		var base: float = [540.0, 570.0, 530.0, 560.0, 520.0, 550.0, 540.0, 570.0][sector]
		var start: float = sector * SECTOR_LENGTH
		for beat in 10:
			var x: float = start + beat * 1000.0
			var type: String = BEATS[sector][beat]
			var surfaces: Array = [[0, 1000, base]]
			if type == "gaps":
				surfaces = [[0, 370, base], [440, 240, base - 60], [750, 250, base]]
			elif type == "stairs":
				surfaces = [[0, 330, base], [390, 240, base - 65], [700, 300, base]]
			elif type == "bridge":
				surfaces = [[0, 300, base], [365, 250, base - 25], [680, 320, base]]
			for surface: Array in surfaces:
				_surface(x + surface[0], surface[1], surface[2], type == "bridge")
			var pool: Node2D = ACID.instantiate()
			pool.position = Vector2(x + 500, 875)
			pool.pool_size = Vector2(1004, 200)
			add_child(pool)
			var lamp: Node2D = LAMP.instantiate()
			lamp.position = Vector2(x + 180, base - 290)
			lamp.scale = Vector2.ONE * 0.48
			add_child(lamp)
			# Open-sky beats get a bird overhead: it lines up and bombs the ledges.
			# Kept below the HUD band so it never hides behind the status panel.
			if type in ["gaps", "bridge"] and beat % 4 == 2:
				_pigeon(x + 520, base - 195, x + 120, x + 880)
			match type:
				"patrol":
					_enemy("guard", x + 620, base, x + 420, x + 850)
				"rats":
					_enemy("rat", x + 460, base, x + 290, x + 650)
					_enemy("rat", x + 800, base, x + 660, x + 940)
				"pack":
					_enemy("rat", x + 230, base, x + 100, x + 320)
					_enemy("guard", x + 490, base, x + 360, x + 610)
					_enemy("dog", x + 810, base, x + 660, x + 960)
				"drone":
					_enemy("drone", x + 680, base - 125, x + 430, x + 920)
				"steam", "crusher", "arc":
					_trap(type, x + 440, base, sector * 0.47)
					if sector > 1:
						_trap(type, x + 780, base, 1.7 + sector * 0.41)
				"secret":
					_secret_route(sector, x, base)
				"valve":
					var idx: int = sector / 2
					_interaction("valve", x + 700, base - 20, idx)
					_make_gate(x + 930, base)
			if type == "rest":
				_interaction("medkit", x + 430, base - 20)
			if beat == 0:
				_interaction("checkpoint", x + 160, base - 20, sector)
				_sign(Vector2(x + 320, base - 170), "%02d / %s   →" % [sector + 1, SECTORS[sector]])
			if type in ["steam", "crusher", "arc"]:
				var text: String = {"steam": "ПАР • дождись паузы или перепрыгни", "crusher": "ПРЕСС • жди паузы", "arc": "РАЗРЯД • S: пригнись или дождись паузы"}[type]
				_sign(Vector2(x + 140, base - 205), text)
	_surface(80000, 700, 570, false)
	_interaction("checkpoint", 80090, 550, 8)
	var door: Node2D = preload("res://scenes/environment/door_prop.tscn").instantiate()
	door.position = Vector2(80350, 455)
	door.scale = Vector2.ONE * 0.55
	add_child(door)
	_interaction("exit", 80350, 550)
	_wall(-60, 300, Vector2(60, 1400))
	_wall(80700, 300, Vector2(60, 1400))

func _surface(left: float, width: float, top: float, hanging: bool, optional: bool = false) -> void:
	# Keep painting at its intended scale rather than stretching one sprite 1000 px.
	var count: int = ceili(width / 360.0)
	for i in count:
		var w: float = width / count
		var platform: Node2D = BRIDGE.instantiate() if hanging else PLATFORM.instantiate()
		platform.position = Vector2(left + (i + 0.5) * w, top)
		platform.collision_size = Vector2(w + 0.5, 32)
		if hanging:
			platform.chain_height = 210.0
		add_child(platform)
		if optional:
			platform.get_node("CollisionShape2D").one_way_collision = true
	route.append({"left": left, "right": left + width, "top": top - 16.0, "optional": optional})

func _enemy(kind: String, x: float, y: float, left: float, right: float) -> void:
	var enemy := ENEMY.new()
	enemy.kind = kind
	enemy.position = Vector2(x, y - 17)
	enemy.patrol_left = left
	enemy.patrol_right = right
	enemy.target = player
	enemy.defeated.connect(func() -> void: kills += 1)
	add_child(enemy)

func _pigeon(x: float, y: float, left: float, right: float) -> void:
	var bird := PIGEON.new()
	bird.position = Vector2(x, y)
	bird.patrol_left = left
	bird.patrol_right = right
	bird.target = player
	bird.defeated.connect(func() -> void: kills += 1)
	add_child(bird)

func _trap(kind: String, x: float, y: float, phase: float) -> void:
	var trap := TRAP.new()
	trap.position = Vector2(x, y - 16)
	trap.kind = kind
	trap.target = player
	trap.phase_offset = phase
	add_child(trap)

func _interaction(kind: String, x: float, y: float, index: int = 0) -> Node2D:
	var item := INTERACTION.new()
	item.kind = kind
	item.position = Vector2(x, y)
	item.index = index
	item.level = self
	add_child(item)
	return item

func _secret_route(sector: int, x: float, base: float) -> void:
	# Optional elevated alcove: two <=70 px climbs. Ground route stays open.
	_surface(x + 210, 110, base - 70, false, true)
	_surface(x + 380, 140, base - 140, false, true)
	_surface(x + 580, 280, base - 200, false, true)
	_interaction("secret", x + 780, base - 218, sector)
	if sector % 2 == 1:
		var grate := GRATE.new()
		grate.position = Vector2(x + 650, base - 216)
		add_child(grate)
		_sign(Vector2(x + 260, base - 275), "ТРЕСНУВШАЯ РЕШЁТКА • разбей атакой")
	else:
		_sign(Vector2(x + 80, base - 150), "↑ Следы ведут наверх")

func _make_gate(x: float, base: float) -> void:
	var gate: StaticBody2D = _wall(x, base - 133, Vector2(120, 1200))
	var panel := Sprite2D.new()
	panel.texture = preload("res://Assets/Environment/Sewer/door_heavy.tres")
	panel.scale = Vector2.ONE * 0.65
	gate.add_child(panel)
	gates.append(gate)
	var hint: Label = _sign(Vector2(x - 120, base - 285), "[V] ОТКРОЙ ВЕНТИЛЬ")
	hint.reparent(gate)

func _wall(x: float, y: float, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = Vector2(x, y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	return wall

func _sign(at: Vector2, text: String) -> Label:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.92, 0.8, 0.52))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label

func open_valve(index: int) -> void:
	if index < gates.size() and is_instance_valid(gates[index]):
		gates[index].queue_free()
	valves += 1
	notice("Вентиль %d/4 • шлюз открыт" % valves)

func heal(amount: int) -> void:
	player.health = mini(player.max_health, player.health + amount)
	player.health_changed.emit(player.health, player.max_health)

func notice(text: String) -> void:
	message.text = text
	notice_time = 5.0

func finish() -> void:
	if completed:
		return
	completed = true
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.anim.play("idle")
	notice_time = 100000
	message.text = "УРОВЕНЬ ПРОЙДЕН • %02d:%02d • Тайники %d/8 • Враги %d • Возвраты %d\nShift+R — пройти заново" % [int(elapsed) / 60, int(elapsed) % 60, secrets, kills, deaths]

func _make_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var panel := ColorRect.new()
	panel.position = Vector2(12, 12)
	panel.size = Vector2(1120, 78)
	panel.color = Color(0.015, 0.035, 0.03, 0.9)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	status = Label.new()
	status.position = Vector2(26, 18)
	status.add_theme_font_size_override("font_size", 18)
	status.modulate = Color(0.82, 0.93, 0.57)
	hud.add_child(status)
	controls = Label.new()
	controls.position = Vector2(26, 48)
	controls.add_theme_font_size_override("font_size", 14)
	controls.text = "A/D — бег   Space — прыжок   S — присесть   F — прицел мышью, отпустить — бросок   E/G — атаки   V — вентиль   R — контрольная точка"
	hud.add_child(controls)
	health_bar = HEALTH_BAR.new()
	health_bar.position = Vector2(896, 22)
	health_bar.size = Vector2(210, 26)
	health_bar.set_health(player.health, player.max_health)
	player.health_changed.connect(health_bar.set_health)
	hud.add_child(health_bar)
	message = Label.new()
	message.position = Vector2(26, 100)
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_shadow_color", Color.BLACK)
	message.add_theme_constant_override("shadow_offset_x", 2)
	message.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(message)

func _process(delta: float) -> void:
	if not completed:
		elapsed += delta
	notice_time -= delta
	message.visible = notice_time > 0.0
	var sector: int = clampi(int(player.position.x / SECTOR_LENGTH), 0, 7)
	if sector != current_sector:
		current_sector = sector
		var tint: Color = [Color(1,1,1), Color(0.83,0.92,0.83), Color(1,0.87,0.73), Color(0.85,0.95,1), Color(0.81,0.94,0.88), Color(0.8,0.87,1), Color(1,0.85,0.77), Color(0.85,1,0.88)][sector]
		$SewerParallaxBG/Far/FarSprite.modulate = tint
	status.text = "%02d / %s   •   %d%%   •   %02d:%02d   •   Вентили %d/4   •   Тайники %d/8" % [sector + 1, SECTORS[sector], clampi(int(player.position.x / LENGTH * 100), 0, 100), int(elapsed) / 60, int(elapsed) % 60, valves, secrets]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_V and not completed:
		for item in get_tree().get_nodes_in_group("level_interactions"):
			if item.kind == "valve" and not item.used and player.global_position.distance_to(item.global_position) < 95:
				item.activate()
				break
	elif event.physical_keycode == KEY_R:
		if event.shift_pressed:
			get_tree().reload_current_scene()
		elif not completed:
			player.respawn()
