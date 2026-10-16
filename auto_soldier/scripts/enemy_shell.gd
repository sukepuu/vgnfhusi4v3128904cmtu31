extends Node2D
## 敵の砲弾（迫撃砲・砲台要塞のボス）。高い山なりで壁を飛び越え、着弾地点の城と兵士にダメージ。
## 落ちてくるまで着弾地点に赤い印が出る。

var game: Node2D
var start := Vector2.ZERO
var target := Vector2.ZERO
var damage := 10.0
## 撃った敵の名前（被害状況の記録用）
var from_name := ""
var blast_radius := 50.0
var flight_time := 2.5
## 砲弾の大きさ（見た目だけ）
var size := 8.0

var _t := 0.0
var _height := 0.0


func _process(delta: float) -> void:
	_t += delta
	var k := minf(_t / flight_time, 1.0)
	position = start.lerp(target, k)
	_height = sin(k * PI) * 320.0
	if k >= 1.0:
		_land()
		return
	queue_redraw()


func _land() -> void:
	# 鉄壁の陣のドームに当たったら、ダメージなしで消える
	if game.ultimates.dome_blocks(target):
		game.spawn_burst(target, Color(0.6, 1.0, 0.7), blast_radius / 2.0)
		queue_free()
		return
	game.dmg_from = from_name
	if game.castle.distance_to_point(target) < blast_radius:
		game.castle.take_damage(damage)
	for a in game.allies():
		if not a.dead and target.distance_to(a.global_position) < blast_radius + a.radius:
			# 上から降ってくるので盾では防げない
			a.take_damage(damage)
	game.dmg_from = ""
	game.spawn_burst(target, Color(1.0, 0.35, 0.2), blast_radius / 2.0)
	queue_free()


func _draw() -> void:
	var k := _t / flight_time
	# 着弾予定地（だんだん濃くなる）
	draw_arc(target - position, blast_radius, 0.0, TAU, 32, Color(1.0, 0.2, 0.2, 0.2 + 0.5 * k), 2.0)
	draw_circle(target - position, blast_radius * k, Color(1.0, 0.2, 0.2, 0.12))
	draw_circle(Vector2.ZERO, size * 0.8, Color(0, 0, 0, 0.3))
	draw_circle(Vector2(0, -_height), size, Color(0.3, 0.1, 0.12))
	draw_circle(Vector2(-2, -_height - 2), size * 0.4, Color(1.0, 0.5, 0.3))
