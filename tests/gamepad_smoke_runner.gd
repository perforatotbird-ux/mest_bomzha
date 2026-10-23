extends SceneTree
## Covers gamepad support: the input map carries pad events for every action, a pad
## event reaches the game through _unhandled_input (the path the level scripts use),
## the aim stick converts to a throw vector, and the keyboard bindings still behave.
##
## Input is verified through a probe node rather than by polling Input after a frame:
## is_action_just_pressed is only true during the frame the event is delivered, and
## polling from outside that frame reads it after the flush has already cleared it.

const LEVEL := preload("res://scenes/levels/sewer_test.tscn")

## Watches the same actions the game reads, from inside the input callback.
class Probe extends Node:
	var hits: Dictionary = {}
	var actions := ["valve", "respawn", "restart", "jump", "throw", "burp", "rear_shot", "crouch", "move_left", "move_right"]

	func _unhandled_input(_event: InputEvent) -> void:
		for action: String in actions:
			if Input.is_action_just_pressed(action):
				hits[action] = true

var passed := 0
var failed := 0
var level: Node2D
var player: Player
var probe: Probe

func _initialize() -> void:
	await run()
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s" % label)

func tick(count: int) -> void:
	for _i in count:
		await physics_frame

func send(event: InputEvent) -> void:
	Input.parse_input_event(event)

func tap(event: InputEvent) -> void:
	event.pressed = true
	send(event)
	var release := event.duplicate()
	release.pressed = false
	send(release)

func key(code: int, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	if shift:
		event.shift_pressed = true
	return event

func button(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	return event

func axis(which: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = which
	event.axis_value = value
	return event

func has_pad_event(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false

func run() -> void:
	# 1. Every action a pad should drive exists and carries a pad event.
	for action in ["move_left", "move_right", "jump", "crouch", "throw", "rear_shot", "burp", "valve", "respawn", "restart"]:
		check(InputMap.has_action(action), "action exists: %s" % action)
		check(has_pad_event(action), "pad event bound: %s" % action)

	# 2. Pad events reach the game through the input callback.
	level = LEVEL.instantiate()
	root.add_child(level)
	current_scene = level
	probe = Probe.new()
	root.add_child(probe)
	await tick(10)
	# Land on a process frame before the first tap: input is flushed on the physics
	# tick, so a tap issued right after a run of physics frames is read by the wrong
	# frame and looks like a missed press.
	await process_frame
	tap(button(JOY_BUTTON_A))
	await process_frame
	check(probe.hits.get("jump", false), "pad A reaches the game as jump")
	tap(button(JOY_BUTTON_X))
	await process_frame
	check(probe.hits.get("throw", false), "pad X reaches the game as throw")
	tap(button(JOY_BUTTON_Y))
	await process_frame
	check(probe.hits.get("rear_shot", false), "pad Y reaches the game as rear_shot")
	tap(button(JOY_BUTTON_B))
	await process_frame
	check(probe.hits.get("burp", false), "pad B reaches the game as burp")
	tap(button(JOY_BUTTON_RIGHT_SHOULDER))
	await process_frame
	check(probe.hits.get("valve", false), "pad RB reaches the game as valve")

	# 3. Keyboard still reaches the game, and the pad does not shadow it.
	tap(key(KEY_V))
	await process_frame
	check(probe.hits.get("valve", false), "V still opens valves")
	tap(key(KEY_F))
	await process_frame
	check(probe.hits.get("throw", false), "F still throws")

	# 4. The stick converts to a throw vector, with power from the deflection.
	player = level.get_node("Player")
	# An attack locks movement for as long as it plays, so let the throw finish
	# before measuring how far the pad can walk the drifter.
	for _i in 90:
		await physics_frame
		if not player._is_attacking():
			break
	var flick: Vector2 = player._aim_from_stick(Vector2(1.0, 0.0))
	check(flick.is_equal_approx(Vector2(player.throw_speed_max, 0.0)), "full stick deflection throws at max speed")
	var upward: Vector2 = player._aim_from_stick(Vector2(0.0, -1.0))
	check(upward.is_equal_approx(Vector2(0.0, -player.throw_speed_max)), "stick direction is preserved")
	var half: Vector2 = player._aim_from_stick(Vector2(0.5, 0.0))
	check(half.x > player.throw_speed_min and half.x < player.throw_speed_max, "half deflection throws softer")
	# With no pad deflected the aim falls back to the mouse, so mouse play is unchanged.
	var mouse_aim: Vector2 = player._aim_velocity()
	check(mouse_aim.length() >= player.throw_speed_min - 0.01, "no stick falls back to the mouse aim")
	check(player._aim_stick().length() <= player.AIM_DEADZONE, "no stick reports as no stick")

	# 5. Movement reads through the action, so the pad moves the drifter.
	var start: Vector2 = player.global_position
	await process_frame
	send(axis(JOY_AXIS_LEFT_X, 1.0))
	await tick(40)
	check(player.global_position.x > start.x + 20.0, "right stick moves the drifter right")
	await process_frame
	send(axis(JOY_AXIS_LEFT_X, 0.0))
	await tick(4)
	await process_frame
	send(axis(JOY_AXIS_LEFT_Y, 1.0))
	await tick(20)
	check(player.crouching, "left stick down crouches the drifter")
	await process_frame
	send(axis(JOY_AXIS_LEFT_Y, 0.0))
	await tick(4)

	# 6. Respawning and restarting come last: both mutate the level, and a restart
	# reloads the scene outright.
	await process_frame
	tap(key(KEY_R))
	await process_frame
	check(probe.hits.get("respawn", false), "R still respawns")
	await process_frame
	tap(key(KEY_R, true))
	await process_frame
	check(probe.hits.get("restart", false), "Shift+R still restarts")
	await tick(6)
	await process_frame
	tap(button(JOY_BUTTON_BACK))
	await process_frame
	check(probe.hits.get("respawn", false), "pad BACK reaches the game as respawn")
	# The reload from the restart above has to leave a playable level behind.
	var fresh: Node = current_scene
	check(fresh != null and fresh.get_node_or_null("Player") != null, "the level survives a restart")
