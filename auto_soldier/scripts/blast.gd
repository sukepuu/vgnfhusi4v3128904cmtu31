extends Node2D
## 少し遅れて起きる爆発（子爆弾・分裂岩・氷柱など）。落ちてくるまで着弾地点に印を出す。

var game: Node2D
var delay := 0.4
var radius := 60.0
var damage := 30.0
var stun := 0.0
var color := Color(1.0, 0.6, 0.2)
var src: Dictionary = {}
## "bomb"（小さな爆弾）/ "rock"（岩）/ "ice"（氷柱）
var look := "bomb"

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= delay:
		game.explode(global_position, radius, damage, src, color, stun)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / delay
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.25 + 0.3 * k), 1.5)
	var h := (1.0 - k) * 90.0
	match look:
		"ice":
			var tip := Vector2(0, -h)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 10), tip + Vector2(-6, -16), tip + Vector2(6, -16)]), Color(0.75, 0.95, 1.0))
		"rock":
			draw_circle(Vector2(0, -h), 8.0, Color(0.5, 0.47, 0.44))
		_:
			draw_circle(Vector2(0, -h * 0.4), 6.0, Color(0.2, 0.2, 0.22))
