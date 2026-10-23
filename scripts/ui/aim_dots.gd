extends Node2D
## Dotted throw arc: beads along the flight path and a fat bead where the bottle
## actually lands, so the player reads the landing point instead of a drawn line.

const BEAD := Color(1.0, 0.86, 0.34)
const IMPACT := Color(1.0, 0.7, 0.18)

## Draw every nth sample of the trajectory; 1 would be a solid line again.
@export var stride: int = 3

var points: PackedVector2Array = []

func _draw() -> void:
	if points.size() < 2:
		return
	var last := points.size() - 1
	for i in range(0, points.size(), maxi(1, stride)):
		var at := points[mini(i, last)]
		var along := float(mini(i, last)) / float(last)
		# Beads thin out and fade as the arc gets further from the hand.
		var radius := lerpf(2.1, 3.2, along)
		var alpha := BEAD.a * (1.0 - along * 0.5)
		draw_circle(at, radius, Color(BEAD.r, BEAD.g, BEAD.b, alpha))
	draw_circle(points[last], 5.5, Color(IMPACT.r, IMPACT.g, IMPACT.b, 0.92))
	draw_arc(points[last], 9.5, 0.0, TAU, 24, Color(IMPACT.r, IMPACT.g, IMPACT.b, 0.5), 2.0)
