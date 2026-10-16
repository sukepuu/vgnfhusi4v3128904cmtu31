extends Node2D
## 採掘場の岩のかけら。投げた時の敵の位置へ山なりに飛んでいく（飛んでいるのが見える）。
## 落ちた所に敵がいれば当たる。外れたら、その場に岩が LIE_TIME 秒残り、最初に触れた敵に当たって消える。

const FLIGHT_TIME := 0.55
const ARC_HEIGHT := 70.0
## 落ちたときに当たる範囲
const HIT_RADIUS := 26.0
## 外れたとき、地面に残っている時間
const LIE_TIME := 10.0
const SIZE := 7.0

var game: Node2D
var start := Vector2.ZERO
var target := Vector2.ZERO
var damage := 200.0
var src: Dictionary = {}

var _t := 0.0
var _landed := false
var _lie_left := LIE_TIME
var _spin := 0.0


func _ready() -> void:
	position = start
	z_index = 5
	_spin = randf() * TAU


func _process(delta: float) -> void:
	if not _landed:
		_t += delta
		_spin += delta * 9.0
		var k := clampf(_t / FLIGHT_TIME, 0.0, 1.0)
		position = start.lerp(target, k)
		if k >= 1.0:
			_landed = true
			z_index = 0
			if _hit_near(HIT_RADIUS):
				queue_free()
				return
		queue_redraw()
		return
	# 地面に残っている間：触れた敵に当たって消える
	_lie_left -= delta
	if _lie_left <= 0.0:
		queue_free()
		return
	if _hit_near(SIZE + 4.0, true):
		queue_free()
		return
	if _lie_left < 1.0:
		queue_redraw()


## 近くの敵1体に当てる（touch = 敵の体の大きさも足して触れたか見る）
func _hit_near(r: float, touch: bool = false) -> bool:
	var best: Node2D = null
	var best_d := INF
	for e in game.enemies_near(global_position, r + 60.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = global_position.distance_to(e.global_position)
		var lim: float = r + (e.radius if touch else e.radius * 0.5)
		if d < lim and d < best_d:
			best_d = d
			best = e
	if best == null:
		return false
	best.take_damage(damage, (best.global_position - global_position).normalized() * 120.0, src)
	game.spawn_burst(global_position, Color(0.7, 0.66, 0.6), 16.0)
	return true


func _draw() -> void:
	var h := 0.0
	var alpha := 1.0
	if not _landed:
		var k := clampf(_t / FLIGHT_TIME, 0.0, 1.0)
		h = sin(k * PI) * ARC_HEIGHT
		# 地面の影
		draw_circle(Vector2.ZERO, SIZE * (1.0 - 0.35 * k * (1.0 - k) * 4.0), Color(0, 0, 0, 0.28))
	else:
		alpha = clampf(_lie_left, 0.0, 1.0)
		draw_circle(Vector2(1.5, 2.5), SIZE, Color(0, 0, 0, 0.25 * alpha))
	draw_set_transform(Vector2(0, -h), _spin, Vector2.ONE)
	var pts := PackedVector2Array()
	for i in 7:
		var a := TAU * i / 7.0
		pts.append(Vector2.from_angle(a) * SIZE * (0.75 + 0.25 * sin(a * 3.0 + 1.3)))
	draw_colored_polygon(pts, Color(0.62, 0.58, 0.52, alpha))
	var edge := pts.duplicate()
	edge.append(pts[0])
	draw_polyline(edge, Color(0.35, 0.32, 0.28, alpha), 1.5)
	draw_circle(Vector2(-SIZE * 0.3, -SIZE * 0.3), SIZE * 0.25, Color(0.85, 0.82, 0.76, 0.8 * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
