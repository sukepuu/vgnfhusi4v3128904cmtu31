extends Node2D
## 剣の斬撃エフェクト（扇形 / 回転斬りなら円）

var radius := 90.0
var arc := PI
var duration := 0.18

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var alpha := 1.0 - k
	var outer := radius * (0.85 + 0.15 * k)
	var inner := outer * 0.45
	if arc >= TAU:
		# 回転斬り：太いリングで描く
		draw_arc(Vector2.ZERO, (outer + inner) / 2.0, 0.0, TAU, 48, Color(0.85, 0.95, 1.0, 0.45 * alpha), outer - inner)
		draw_arc(Vector2.ZERO, outer, 0.0, TAU, 48, Color(1, 1, 1, 0.9 * alpha), 3.0)
		return
	var half := arc / 2.0
	var steps := 24
	var pts := PackedVector2Array()
	for i in steps + 1:
		pts.append(Vector2.from_angle(-half + 2.0 * half * i / steps) * outer)
	for i in range(steps, -1, -1):
		pts.append(Vector2.from_angle(-half + 2.0 * half * i / steps) * inner)
	draw_colored_polygon(pts, Color(0.85, 0.95, 1.0, 0.45 * alpha))
	draw_arc(Vector2.ZERO, outer, -half, half, steps, Color(1, 1, 1, 0.9 * alpha), 3.0)
