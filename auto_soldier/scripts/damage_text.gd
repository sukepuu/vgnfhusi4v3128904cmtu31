extends Node2D
## 浮かび上がるダメージ数字

var text := ""
var color := Color(1, 1, 1)

var _t := 0.0
const DURATION := 0.6


func _process(delta: float) -> void:
	_t += delta
	position.y -= 40.0 * delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / DURATION
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-20, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 40, 16, 4, Color(0, 0, 0, a))
	draw_string(font, Vector2(-20, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(color, a))
