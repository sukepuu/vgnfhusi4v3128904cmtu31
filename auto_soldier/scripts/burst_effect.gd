extends Node2D
## 敵を倒したときの破裂エフェクト

var color := Color(1, 1, 1)
var max_radius := 30.0

var _t := 0.0
const DURATION := 0.3


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	draw_circle(Vector2.ZERO, max_radius * k, Color(color, 0.35 * (1.0 - k)))
	draw_arc(Vector2.ZERO, max_radius * k, 0.0, TAU, 24, Color(1, 1, 1, 0.8 * (1.0 - k)), 2.0)
