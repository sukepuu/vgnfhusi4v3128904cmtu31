extends Node2D
## 浮かび上がるダメージ数字

var text := ""
var color := Color(1, 1, 1)
var font_size := 16

var _t := 0.0
var duration := 0.6


func _process(delta: float) -> void:
	_t += delta
	position.y -= 40.0 * delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / duration
	var font := ThemeDB.fallback_font
	# 文字の幅に合わせて真ん中にそろえる
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var p := Vector2(-w / 2.0, 0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, a))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, a))
