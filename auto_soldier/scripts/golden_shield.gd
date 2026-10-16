extends Node2D
## 黄金の盾（迎撃部隊のおもしろ強化）：迎撃兵が前へ飛ばす、盾の2倍の大きさの黄金の盾。
## ゆっくりまっすぐ進み、当たった敵の弾を消す。弾を消すたびに、黄金の盾から全方位へ弾を撃つ。

const BulletScript := preload("res://scripts/bullet.gd")

## 進む速さ・残る秒数
const SPEED := 70.0
const LIFE := 8.0
## 盾の大きさ（迎撃兵の盾の2倍）
const ARC_RADIUS := 44.0
const ARC_WIDTH := 14.0
## 敵の弾を消す範囲
const CATCH_RADIUS := 40.0
## 全方位に撃つ弾の数・速さ・飛ぶ秒数
const BURST_COUNT := 12
const BURST_SPEED := 420.0
const BURST_LIFE := 0.9
## 全方位の弾を撃ったあと、次に撃てるまでの秒数（弾が一度にたくさん来ても撃ちすぎないように）
const BURST_CD := 0.15

var game: Node2D
var dir := Vector2.UP
var half_arc := 0.5
var damage := 10.0
var src: Dictionary = {}

var _life := LIFE
var _burst_cd := 0.0
var _flash := 0.0


func _process(delta: float) -> void:
	position += dir * SPEED * delta
	_life -= delta
	_burst_cd -= delta
	_flash -= delta
	if _life <= 0.0:
		game.spawn_burst(global_position, Color(1.0, 0.85, 0.3), 16.0)
		queue_free()
		return
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		if global_position.distance_to(b.global_position) < CATCH_RADIUS + b.radius:
			b.queue_free()
			_flash = 0.12
			if _burst_cd <= 0.0:
				_burst_cd = BURST_CD
				_fire_burst()
	queue_redraw()


func _fire_burst() -> void:
	var off := randf() * TAU
	for i in BURST_COUNT:
		var d := Vector2.from_angle(off + TAU * i / float(BURST_COUNT))
		var b := BulletScript.new()
		b.game = game
		b.velocity = d * BURST_SPEED
		b.damage = damage
		b.radius = 5.0
		b.color = Color(1.0, 0.85, 0.3)
		b.life = BURST_LIFE
		b.position = global_position + d * 24.0
		b.src = src
		game.world.add_child(b)


func _draw() -> void:
	var fa := dir.angle()
	var col := Color(1.0, 1.0, 0.75) if _flash > 0.0 else Color(1.0, 0.8, 0.2)
	var a := clampf(_life / 0.5, 0.0, 1.0)
	col.a = a
	draw_arc(Vector2.ZERO, ARC_RADIUS, fa - half_arc, fa + half_arc, 16, Color(1.0, 0.9, 0.4, 0.25 * a), ARC_WIDTH + 8.0)
	draw_arc(Vector2.ZERO, ARC_RADIUS, fa - half_arc, fa + half_arc, 16, col, ARC_WIDTH)
	draw_arc(Vector2.ZERO, ARC_RADIUS, fa - half_arc, fa + half_arc, 16, Color(0.5, 0.35, 0.05, a), 3.0)
