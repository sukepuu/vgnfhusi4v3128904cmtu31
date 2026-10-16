extends Node2D
## 一刀両断：画面の左端から右端へ、横一列を白い斬撃が駆け抜ける（重装兵の特別強化）
## 線の長さはマップの横幅の120%。線の先頭が左端を出てから、線の最後尾が右端に着くまでが SWEEP_TIME 秒。
## 線のうち、マップの中にある部分だけが見えて、当たり判定もある。通り道の敵には1回だけダメージ。

const LENGTH_RATIO := 1.2
const SWEEP_TIME := 1.0
const THICKNESS := 24.0

var game: Node2D
var damage := 0.0
var src: Dictionary = {}
## 当たった敵を押す力（右向き）
var push := 120.0

var _t := 0.0
var _left := 0.0
var _right := 0.0
var _len := 0.0
var _speed := 0.0
var _hit := {}
## テスト用：当たった回数
var hits := 0


func _ready() -> void:
	var r: Rect2 = game.MAP_RECT
	_left = r.position.x
	_right = r.end.x
	_len = r.size.x * LENGTH_RATIO
	# 先頭は左端から、最後尾が右端に着くまで動く
	_speed = (r.size.x + _len) / SWEEP_TIME


## 今の線の先頭（右端側）の x
func head_x() -> float:
	return _left + _speed * minf(_t, SWEEP_TIME)


func _process(delta: float) -> void:
	var prev_head := head_x()
	_t += delta
	var head := head_x()
	var tail := head - _len
	# このフレームに線が通った範囲（前の先頭から今の先頭まで＋今の線の全体）
	var x0 := maxf(_left, minf(tail, prev_head - _len))
	var x1 := minf(_right, head)
	if x1 >= x0:
		_hit_range(x0, x1)
	if _t >= SWEEP_TIME:
		queue_free()
		return
	queue_redraw()


func _hit_range(x0: float, x1: float) -> void:
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var id: int = e.get_instance_id()
		if _hit.has(id):
			continue
		var p: Vector2 = e.global_position
		var er: float = e.radius
		if absf(p.y - global_position.y) > THICKNESS / 2.0 + er:
			continue
		if p.x + er < x0 or p.x - er > x1:
			continue
		_hit[id] = true
		hits += 1
		e.take_damage(damage, Vector2(push, 0.0), src)
		game.spawn_burst(p, Color(1, 1, 1), 14.0)


func _draw() -> void:
	var head := head_x()
	var tail := head - _len
	var a := maxf(_left, tail)
	var b := minf(_right, head)
	if b <= a:
		return
	# 線は global_position.y の高さ、x は世界座標（このノードは x=0 に置く）
	var y := 0.0
	# 最後尾ほど薄くなるように、細かく分けて描く
	var steps := 24
	for i in steps:
		var sx0 := lerpf(tail, head, float(i) / steps)
		var sx1 := lerpf(tail, head, float(i + 1) / steps)
		var c0 := maxf(a, sx0)
		var c1 := minf(b, sx1)
		if c1 <= c0:
			continue
		var k := (float(i) + 0.5) / steps  # 0 = 最後尾, 1 = 先頭
		var alpha := k * k
		draw_line(Vector2(c0, y), Vector2(c1, y), Color(0.75, 0.9, 1.0, 0.18 * alpha), THICKNESS * 2.6)
		draw_line(Vector2(c0, y), Vector2(c1, y), Color(0.9, 0.97, 1.0, 0.35 * alpha), THICKNESS * 1.5)
		draw_line(Vector2(c0, y), Vector2(c1, y), Color(1, 1, 1, 0.95 * alpha), THICKNESS * 0.55)
	# 先頭の光
	if head <= _right:
		draw_circle(Vector2(head, y), THICKNESS * 1.1, Color(0.85, 0.95, 1.0, 0.35))
		draw_circle(Vector2(head, y), THICKNESS * 0.5, Color(1, 1, 1, 0.95))
