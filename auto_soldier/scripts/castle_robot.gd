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
## パンチ（ゆっくりモーション）：振りかぶる → 突き出す（ここで当たる）→ 止める → 戻す
const PUNCH_TIME := 1.3
const PUNCH_WINDUP := 0.45
const PUNCH_HIT := 0.7
const PUNCH_HOLD := 0.9
var _punch_arm := 1
var _punch_to := Vector2.ZERO
var _punch_t := -1.0
var _punch_target: Node2D = null
var _punch_done := false


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
	# 2秒ごとに近くの敵をパンチ（ゆっくりモーションで、突き出しきったところで当たる）
	_punch_cd -= delta
	if _punch_t >= 0.0:
		_punch_t += delta
		if _punch_target != null and is_instance_valid(_punch_target) and not _punch_target.dead:
			_punch_to = _punch_target.global_position - global_position
		if not _punch_done and _punch_t >= PUNCH_HIT:
			_punch_done = true
			var hit_pos: Vector2 = global_position + _fist_reach()
			game.explode(hit_pos, 80.0, 40.0 * game._hp_mult(), _record(), Color(1.0, 0.75, 0.4), 0.0, 600.0)
		if _punch_t >= PUNCH_TIME:
			_punch_t = -1.0
	elif _punch_cd <= 0.0:
		var near: Node2D = game.nearest_enemy(global_position, PUNCH_RANGE)
		if near != null:
			_punch_cd = 2.0
			_punch_target = near
			_punch_arm = 1 if near.global_position.x >= global_position.x else -1
			_punch_to = near.global_position - global_position
			_punch_t = 0.0
			_punch_done = false
	queue_redraw()


## パンチの伸び具合（-1 = 振りかぶり、0 = ふつう、1 = 突き出しきり）
func _punch_ext() -> float:
	if _punch_t < 0.0:
		return 0.0
	if _punch_t < PUNCH_WINDUP:
		return -_punch_t / PUNCH_WINDUP
	if _punch_t < PUNCH_HIT:
		return lerpf(-1.0, 1.0, (_punch_t - PUNCH_WINDUP) / (PUNCH_HIT - PUNCH_WINDUP))
	if _punch_t < PUNCH_HOLD:
		return 1.0
	return lerpf(1.0, 0.0, (_punch_t - PUNCH_HOLD) / (PUNCH_TIME - PUNCH_HOLD))


func _shoulder(side: int) -> Vector2:
	return Vector2(side * (game.castle.HALF.x - 4.0), -game.castle.HALF.y * 0.35)


## 拳が届く位置（ロボットの中心から）
func _fist_reach() -> Vector2:
	var sh := _shoulder(_punch_arm)
	return sh + (_punch_to - sh).limit_length(PUNCH_RANGE)


func _draw_arm(side: int, dark: Color) -> void:
	var stone := Color(0.55, 0.53, 0.5)
	var sh := _shoulder(side)
	var swing := sin(_t * 6.0 + side) * 4.0
	# ふだんの形：肩 → 横へ（ひじ）→ 下へ（拳）のL字
	var elbow := sh + Vector2(side * 46.0, 0.0)
	var fist := elbow + Vector2(0.0, 48.0 + swing)
	if side == _punch_arm and _punch_t >= 0.0:
		var ext := _punch_ext()
		if ext < 0.0:
			# 振りかぶり：拳を肩の後ろ上へ引く
			var back := sh + Vector2(side * 18.0, -26.0)
			fist = fist.lerp(back, -ext)
			elbow = elbow.lerp(sh + Vector2(side * 44.0, -6.0), -ext)
		else:
			# 突き出し：ひじは敵の方へ半分、拳は敵の位置まで（L字を保つように少し曲げる）
			var reach := _fist_reach()
			var mid := sh.lerp(reach, 0.5) + (reach - sh).orthogonal().normalized() * side * -18.0
			elbow = elbow.lerp(mid, ext)
			fist = fist.lerp(reach, ext)
	draw_line(sh, elbow, dark, 32.0)
	draw_line(elbow, fist, dark, 32.0)
	draw_line(sh, elbow, stone, 24.0)
	draw_line(elbow, fist, stone, 24.0)
	draw_circle(sh, 16.0, dark)
	draw_circle(elbow, 16.0, dark)
	draw_circle(elbow, 12.0, stone)
	draw_circle(fist, 25.0, dark)
	draw_circle(fist, 20.0, Color(0.62, 0.6, 0.56))
	draw_circle(fist + Vector2(-6, -6), 6.0, Color(0.75, 0.73, 0.7))


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
	# 腕（太いL字型。肩から横へ出て、ひじで下へ曲がり、先に丸い拳）
	for side in [-1, 1]:
		_draw_arm(side, dark)
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
