extends Node2D
## 城ロボ（城の特別強化「城ロボ起動」）。30秒ごとに城から出撃して、15秒間暴れまわる。
## 出撃中は、城についている兵装（矢倉・大砲・バリスタ・投石器）が城からはずれてロボットに付き、ロボットの位置から撃つ。
## （castle.wpos() がロボットの位置を返す。ロボットが消えると兵装は城に戻る）
## ロボットはいつもゆっくり歩き、全方位にぐるぐる射撃を続け、2秒ごとに近くの敵をパンチする。敵からは狙われない。

const BulletScript := preload("res://scripts/bullet.gd")

const LIFE := 15.0
const SPEED := 32.0
const PUNCH_RANGE := 150.0

var game: Node2D
var _life := LIFE
var _t := 0.0
var _spin := 0.0
var _shot_cd := 0.0
var _punch_cd := 1.0
## パンチの演出（どちらの腕で、どこへ、あと何秒）
var _punch_arm := 1
var _punch_to := Vector2.ZERO
var _punch_left := 0.0


func _ready() -> void:
	game.spawn_burst(global_position, Color(0.8, 0.8, 0.75), 80.0)


func _record() -> Dictionary:
	var castle: Node2D = game.castle
	if not castle.has_meta("robot_record"):
		castle.set_meta("robot_record", game.new_record("castle", "城ロボ"))
	return castle.get_meta("robot_record")


func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	if _life <= 0.0:
		game.spawn_burst(global_position, Color(0.8, 0.8, 0.75), 80.0)
		queue_free()
		return
	# いつもゆっくり歩く（一番近い敵の方へ。敵がいなければ城の前をうろうろ）
	var t: Node2D = game.nearest_enemy(global_position, INF)
	var goal: Vector2 = t.global_position if t != null else game.castle.global_position + Vector2(sin(_t) * 200.0, -260.0)
	var to := goal - global_position
	# いつも歩いている（近づいたら、敵のまわりを回るように横へ歩く）
	var walk: Vector2 = to.normalized() if to.length() > 70.0 else to.normalized().orthogonal()
	position += walk * SPEED * delta
	position = game.clamp_to_map(position, 60.0)
	# 全方位ぐるぐる射撃
	_shot_cd -= delta
	if _shot_cd <= 0.0:
		_shot_cd = 0.12
		_spin += 0.35
		var dmg: float = 3.0 * game._hp_mult()
		for k in 4:
			var dir := Vector2.from_angle(_spin + TAU * k / 4.0)
			var b := BulletScript.new()
			b.game = game
			b.velocity = dir * 420.0
			b.damage = dmg
			b.radius = 6.0
			b.color = Color(1.0, 0.85, 0.45)
			b.life = 1.3
			b.position = global_position + dir * 60.0
			b.src = _record()
			game.world.add_child(b)
	# 2秒ごとに近くの敵をパンチ
	_punch_cd -= delta
	_punch_left -= delta
	if _punch_cd <= 0.0:
		var near: Node2D = game.nearest_enemy(global_position, PUNCH_RANGE)
		if near != null:
			_punch_cd = 2.0
			_punch_arm = 1 if near.global_position.x >= global_position.x else -1
			_punch_to = near.global_position - global_position
			_punch_left = 0.25
			game.explode(near.global_position, 80.0, 40.0 * game._hp_mult(), _record(), Color(1.0, 0.75, 0.4), 0.0, 600.0)
	queue_redraw()


func _draw() -> void:
	var castle: Node2D = game.castle
	var half: Vector2 = castle.HALF
	var wall := Color(0.62, 0.6, 0.56)
	var dark := Color(0.35, 0.33, 0.3)
	var step := sin(_t * 6.0) * 8.0
	# 影
	draw_rect(Rect2(Vector2(-half.x, half.y + 30.0), Vector2(half.x * 2.0, 14.0)), Color(0, 0, 0, 0.3))
	# 足（ガシャガシャ歩く）
	draw_rect(Rect2(Vector2(-half.x * 0.55 - 14.0, half.y - 4.0 + step), Vector2(28, 40)), dark)
	draw_rect(Rect2(Vector2(half.x * 0.55 - 14.0, half.y - 4.0 - step), Vector2(28, 40)), dark)
	# 腕（パンチ中はその腕を敵の方へ伸ばす）
	for side in [-1, 1]:
		var shoulder := Vector2(side * (half.x + 6.0), -half.y * 0.2)
		var fist := shoulder + Vector2(side * 30.0, 30.0 + sin(_t * 6.0 + side) * 6.0)
		if _punch_left > 0.0 and side == _punch_arm:
			fist = shoulder + (_punch_to - shoulder).limit_length(PUNCH_RANGE)
		draw_line(shoulder, fist, dark, 12.0)
		draw_circle(fist, 15.0, Color(0.5, 0.48, 0.45))
		draw_circle(fist, 15.0, dark, false, 3.0)
	# 体（城そのもの）
	draw_rect(Rect2(-half, half * 2.0), wall)
	draw_rect(Rect2(-half, half * 2.0), dark, false, 3.0)
	var bw := 16.0
	var x := -half.x
	while x < half.x - 1.0:
		draw_rect(Rect2(Vector2(x, -half.y - 10.0), Vector2(bw * 0.6, 10.0)), wall)
		x += bw
	# 目（光る）
	var glow := 0.7 + 0.3 * sin(_t * 8.0)
	draw_circle(Vector2(-24, -6), 9.0, Color(1.0, 0.85, 0.3, glow))
	draw_circle(Vector2(24, -6), 9.0, Color(1.0, 0.85, 0.3, glow))
	draw_rect(Rect2(Vector2(-18, half.y - 30.0), Vector2(36, 30)), Color(0.3, 0.2, 0.12))
	# 城からはずれた兵装を、ロボットの体に付けて描く
	castle.draw_weapons(self, Vector2.ZERO)
	# 残り時間
	draw_rect(Rect2(Vector2(-half.x, -half.y - 22.0), Vector2(half.x * 2.0, 5.0)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(Vector2(-half.x, -half.y - 22.0), Vector2(half.x * 2.0 * _life / LIFE, 5.0)), Color(1.0, 0.8, 0.3))
