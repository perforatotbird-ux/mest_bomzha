extends SceneTree
## Adds gamepad bindings to the project's input map. Idempotent: re-running only
## adds what is missing, so it is safe to call after every input change.
##
## The bindings are written through ProjectSettings, not InputMap: InputMap is
## read out of ProjectSettings at boot, and runtime edits to it never reach
## project.godot, so the pad would work in the editor session and nowhere else.
##
## Layout (Xbox-style, Godot's positional JoyButton order):
##   left stick / d-pad  move, left stick down or LB crouch
##   A jump   B burp   X throw   Y gas back
##   RB interact (valve)   BACK respawn   START restart level
##   right stick aims the throw; its deflection also sets the power.
##
## Usage: godot --headless --path . --script tools/add_gamepad_support.gd

const BINDINGS := {
	"move_left": [
		{"type": "axis", "axis": JOY_AXIS_LEFT_X, "value": -1.0},
		{"type": "button", "button": JOY_BUTTON_DPAD_LEFT},
	],
	"move_right": [
		{"type": "axis", "axis": JOY_AXIS_LEFT_X, "value": 1.0},
		{"type": "button", "button": JOY_BUTTON_DPAD_RIGHT},
	],
	"jump": [
		{"type": "button", "button": JOY_BUTTON_A},
		{"type": "button", "button": JOY_BUTTON_DPAD_UP},
	],
	"crouch": [
		{"type": "axis", "axis": JOY_AXIS_LEFT_Y, "value": 1.0},
		{"type": "button", "button": JOY_BUTTON_DPAD_DOWN},
		{"type": "button", "button": JOY_BUTTON_LEFT_SHOULDER},
	],
	"throw": [
		{"type": "button", "button": JOY_BUTTON_X},
	],
	"rear_shot": [
		{"type": "button", "button": JOY_BUTTON_Y},
	],
	"burp": [
		{"type": "button", "button": JOY_BUTTON_B},
	],
	# Actions the level scripts read directly; the keyboard half mirrors the keys
	# they already used (V, R, Shift+R).
	"valve": [
		{"type": "key", "keycode": KEY_V},
		{"type": "button", "button": JOY_BUTTON_RIGHT_SHOULDER},
	],
	"respawn": [
		{"type": "key", "keycode": KEY_R},
		{"type": "button", "button": JOY_BUTTON_BACK},
	],
	"restart": [
		{"type": "key", "keycode": KEY_R, "shift": true},
		{"type": "button", "button": JOY_BUTTON_START},
	],
}

func _initialize() -> void:
	var added := 0
	for action: String in BINDINGS:
		var path := "input/" + action
		if not ProjectSettings.has_setting(path + "/events"):
			ProjectSettings.set_setting(path + "/deadzone", 0.5)
			ProjectSettings.set_setting(path + "/events", [])
		var events: Array = ProjectSettings.get_setting(path + "/events")
		for spec: Dictionary in BINDINGS[action]:
			var event := _build(spec)
			if event == null or _has(events, event):
				continue
			events.append(event)
			added += 1
		ProjectSettings.set_setting(path + "/events", events)
	ProjectSettings.save()
	print("gamepad bindings added: %d" % added)
	quit()

func _build(spec: Dictionary) -> InputEvent:
	match String(spec.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(spec["keycode"])
			key.keycode = int(spec["keycode"])
			if bool(spec.get("shift", false)):
				key.shift_pressed = true
			return key
		"button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(spec["button"])
			return button
		"axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(spec["axis"])
			motion.axis_value = float(spec["value"])
			return motion
	return null

func _has(events: Array, event: InputEvent) -> bool:
	for existing in events:
		if existing is InputEvent and existing.is_match(event):
			return true
	return false
