extends Node2D
## 大砲の砲弾・投石器の岩。放物線を描いて飛び、着弾地点の周りにまとめてダメージ。

var game: Node2D
var start := Vector2.ZERO
var target := Vector2.ZERO
var damage := 40.0
var blast_radius := 90.0
var flight_time := 0.7
## true なら投石器の岩（大きく、高く飛ぶ）
var boulder := false

var _t := 0.0
var _height := 0.0


func _process(delta: float) -> void:
	_t += delta
	var k := minf(_t / flight_time, 1.0)
	position = start.lerp(target, k)
	_height = sin(k * PI) * (240.0 if boulder else 140.0)
	if k >= 1.0:
		_explode()
		return
	queue_redraw()


func _explode() -> void:
	for e in game.enemies_near(target, blast_radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - target
		if to.length() < blast_radius + e.radius:
			e.take_damage(damage, to.normalized() * 300.0)
	var col := Color(0.75, 0.65, 0.5) if boulder else Color(1.0, 0.6, 0.2)
	game.spawn_burst(target, col, blast_radius / 2.2)
	queue_free()


func _draw() -> void:
	if boulder:
		# 着弾予定地を表示
		draw_arc(target - position, blast_radius, 0.0, TAU, 40, Color(1.0, 0.8, 0.5, 0.35), 2.0)
		draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
		draw_circle(Vector2(0, -_height), 14.0, Color(0.45, 0.42, 0.4))
		draw_circle(Vector2(-4, -_height - 4), 5.0, Color(0.6, 0.58, 0.55))
		return
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.3))
	draw_circle(Vector2(0, -_height), 8.0, Color(0.15, 0.15, 0.18))
	draw_circle(Vector2(-2, -_height - 2), 3.0, Color(0.5, 0.5, 0.55))
