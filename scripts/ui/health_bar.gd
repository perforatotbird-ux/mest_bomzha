extends Control
## Segmented health plate for the sewer HUD: a hand-drawn heart, then one cell per
## hit point. Yellow, deepening as the drifter takes damage.
## Per request: the plate sits in the top-left corner and reads yellow, not green.

const HEART_W := 20.0
const HEART_GAP := 8.0
const CELL_GAP := 3.0

const FULL := Color(0.96, 0.8, 0.16)
const HURT := Color(0.88, 0.62, 0.1)
const CRITICAL := Color(0.76, 0.42, 0.08)
const EMPTY := Color(0.08, 0.09, 0.08, 0.92)
const FRAME := Color(0.42, 0.33, 0.19, 0.95)
const PLATE := Color(0.02, 0.045, 0.04, 0.55)

var maximum: int = 5
var value: int = 5
var _flash: float = 0.0
var _pulse: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(210, 26)

func set_health(current: int, total: int) -> void:
	if current < value:
		_flash = 0.35
	value = current
	maximum = maxi(1, total)
	queue_redraw()

func _process(delta: float) -> void:
	_pulse += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()
	elif float(value) / float(maximum) <= 0.4:
		queue_redraw()

func _draw() -> void:
	var ratio := float(value) / float(maximum)
	var tint: Color = FULL if ratio > 0.6 else (HURT if ratio > 0.4 else CRITICAL)
	var plate := Rect2(Vector2(-4, -4), Vector2(size.x + 8, size.y + 8))
	draw_rect(plate, PLATE, true)
	draw_rect(plate, FRAME, false, 1.0)

	# Heart: two lobes and a point, pulsing faster as the bar empties.
	var beat := 1.0
	if ratio <= 0.4:
		beat = 1.0 + sin(_pulse * 9.0) * 0.08
	_draw_heart(Vector2(HEART_W * 0.5, size.y * 0.5), 9.0 * beat, CRITICAL if ratio <= 0.4 else Color(0.78, 0.26, 0.2))

	var left := HEART_W + HEART_GAP
	var cell_w := (size.x - left - CELL_GAP * (maximum - 1)) / maximum
	for i in maximum:
		var cell := Rect2(left + i * (cell_w + CELL_GAP), 0.0, cell_w, size.y)
		if i < value:
			draw_rect(cell, tint, true)
			# Top bevel keeps the cells from reading as flat blocks.
			draw_rect(Rect2(cell.position, Vector2(cell.size.x, cell.size.y * 0.32)), tint.lightened(0.28), true)
		else:
			draw_rect(cell, EMPTY, true)
		draw_rect(cell, Color(0, 0, 0, 0.45), false, 1.0)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.3, 0.2, _flash * 0.55), true)

func _draw_heart(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center + Vector2(-radius * 0.46, -radius * 0.28), radius * 0.56, color)
	draw_circle(center + Vector2(radius * 0.46, -radius * 0.28), radius * 0.56, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-radius * 0.99, -radius * 0.05),
		center + Vector2(radius * 0.99, -radius * 0.05),
		center + Vector2(0.0, radius * 0.92),
	]), color)
