extends Node2D
## 城ロボ（城の特別強化「城ロボ起動」）。30秒ごとに城から出撃して、15秒間暴れまわる。
## 出撃中は、城についている兵装（矢倉・大砲・バリスタ・投石器）が城からはずれてロボットに付き、ロボットの位置から撃つ。
## （castle.wpos() がロボットの位置を返す。ロボットが消えると兵装は城に戻る）
## ロボットはいつもゆっくり歩き、全方位にぐるぐる射撃を続け、2秒ごとに近くの敵をパンチする。敵からは狙われない。
## mode（特別強化で変わる）：
##   "walk"   … ふつう（上の動き）
##   "flight" … フライトモード。翼で飛び、両手を上げて遠くの敵へ高速タックル → 両手から誘導ミサイル30発 をくり返す
##   "final"  … ファイナルモード。画面の真ん中から動かず、8本のビームを別々の敵へ撃ち続けながら、両手から誘導ミサイルを撃ち続ける

const BulletScript := preload("res://scripts/bullet.gd")

const LIFE := 15.0
const SPEED := 32.0
const PUNCH_RANGE := 150.0

var game: Node2D
var mode := "walk"
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
	if mode == "flight":
		_update_flight(delta)
		queue_redraw()
		return
	if mode == "final":
		_update_final(delta)
		queue_redraw()
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


# ---------------- フライトモード ----------------
const TACKLE_SPEED := 950.0
const MISSILE_COUNT := 30
const MISSILE_INTERVAL := 0.05
## "tackle"（突撃中）/ "missile"（止まってミサイル発射）
var _fly_state := "missile"
var _fly_dir := Vector2.UP
var _fly_left := 0.3
var _missiles_left := 0
var _missile_cd := 0.0
var _missile_arm := 1
var _tackle_hit := {}


func _flight_src() -> Dictionary:
	return game.sp_src(_record(), "sp_castle_robot_flight")


func _update_flight(delta: float) -> void:
	_fly_left -= delta
	if _fly_state == "tackle":
		position += _fly_dir * TACKLE_SPEED * delta
		position = game.clamp_to_map(position, 60.0)
		# 通り道の敵に体当たり（1回のタックルで同じ敵には1回）
		var r: float = game.castle.HALF.x + 10.0
		for e in game.enemies_near(global_position, r + 40.0):
			if not is_instance_valid(e) or e.dead or _tackle_hit.has(e):
				continue
			if global_position.distance_to(e.global_position) < r + e.radius:
				_tackle_hit[e] = true
				e.take_damage(25.0 * game._hp_mult(), _fly_dir * 500.0, _flight_src())
		if _fly_left <= 0.0:
			_fly_state = "missile"
			_missiles_left = MISSILE_COUNT
			_missile_cd = 0.1
			game.spawn_burst(global_position, Color(0.8, 0.85, 1.0), 50.0)
		return
	# 止まって、両手から交互に誘導ミサイル
	_missile_cd -= delta
	if _missiles_left > 0 and _missile_cd <= 0.0:
		_missile_cd = MISSILE_INTERVAL
		_missiles_left -= 1
		_fire_missile(_flight_src(), 6.0 * game._hp_mult())
	if _missiles_left <= 0 and _missile_cd <= -0.2:
		_start_tackle()


## 遠くの敵（一番遠い敵）へ向かって高速タックル
func _start_tackle() -> void:
	var far: Node2D = null
	var far_d := -1.0
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d > far_d:
			far_d = d
			far = e
	_fly_state = "tackle"
	_tackle_hit.clear()
	if far == null:
		_fly_dir = Vector2.from_angle(randf() * TAU)
		_fly_left = 0.4
		return
	var to: Vector2 = far.global_position - global_position
	_fly_dir = to.normalized()
	# 敵を少し突き抜けるところまで
	_fly_left = clampf((to.length() + 80.0) / TACKLE_SPEED, 0.15, 1.5)


## 手の先から誘導ミサイルを1発（左右の手で交互）
func _fire_missile(src: Dictionary, dmg: float) -> void:
	_missile_arm = -_missile_arm
	var p: Vector2 = global_position + _arm_pose(_missile_arm)[1]
	# 手の向き（斜め上）へ飛び出してから、敵を追いかける
	var dir := Vector2.from_angle(-PI / 2.0 + _missile_arm * 0.6 + randf_range(-0.35, 0.35))
	var m: Node2D = game.spawn_missile("homing", p, dir * 520.0, dmg, 9.0, 3.0, src)
	m.look = "rocket"
	m.target = _random_target()


func _random_target() -> Node2D:
	var pool: Array = game.enemies_cache.filter(func(e: Node2D) -> bool: return is_instance_valid(e) and not e.dead)
	if pool.is_empty():
		return null
	return pool.pick_random()


# ---------------- ファイナルモード ----------------
const BEAM_COUNT := 10
## ビームの太さ（この幅に入った敵は、的までの途中でもダメージを受ける）
const BEAM_WIDTH := 12.0
const BEAM_TICK := 0.1
const FINAL_MISSILE_INTERVAL := 0.07
var _beam_targets: Array = []
var _beam_cd := 0.0


func _final_src() -> Dictionary:
	return game.sp_src(_record(), "sp_castle_robot_final")


func _update_final(delta: float) -> void:
	# ビームの的を決める（倒した・いなくなった的は、まだ狙っていないランダムな敵に取り替える）
	_beam_targets = _beam_targets.filter(func(e) -> bool: return is_instance_valid(e) and not e.dead)
	if _beam_targets.size() < BEAM_COUNT:
		var cand: Array = game.enemies_cache.filter(func(e: Node2D) -> bool:
			return is_instance_valid(e) and not e.dead and not _beam_targets.has(e))
		cand.shuffle()
		for e in cand.slice(0, BEAM_COUNT - _beam_targets.size()):
			_beam_targets.append(e)
	_beam_cd -= delta
	if _beam_cd <= 0.0:
		_beam_cd = BEAM_TICK
		var dmg: float = 2.0 * game._hp_mult()
		var from: Vector2 = global_position + _beam_origin()
		# ビーム1本ごとに、胸から的までの線の上にいる敵すべてにダメージ
		for t in _beam_targets.duplicate():
			if not is_instance_valid(t) or t.dead:
				continue
			var to: Vector2 = t.global_position
			var seg: Vector2 = to - from
			var seg_len2: float = maxf(seg.length_squared(), 1.0)
			for e in game.enemies_cache:
				if not is_instance_valid(e) or e.dead:
					continue
				var k: float = clampf((e.global_position - from).dot(seg) / seg_len2, 0.0, 1.0)
				if e.global_position.distance_to(from + seg * k) <= BEAM_WIDTH + e.radius:
					e.take_damage(dmg, Vector2.ZERO, _final_src())
	# 両手から誘導ミサイルを撃ち続ける
	_missile_cd -= delta
	if _missile_cd <= 0.0:
		_missile_cd = FINAL_MISSILE_INTERVAL
		_fire_missile(_final_src(), 6.0 * game._hp_mult())


## ビームが出る場所（胸の真ん中）
func _beam_origin() -> Vector2:
	return Vector2(0, -6)


## フライト・ファイナルモードの腕の形：[ひじ, 拳]（ロボットの中心から）
func _arm_pose(side: int) -> Array:
	var sh := _shoulder(side)
	if mode == "final":
		# 両手を大きく斜め上に広げる
		var wob := sin(_t * 10.0 + side) * 3.0
		return [sh + Vector2(side * 44.0, -30.0), sh + Vector2(side * 70.0, -84.0 + wob)]
	if _fly_state == "tackle":
		# 両手をまっすぐ上に上げる
		return [sh + Vector2(side * 14.0, -46.0), sh + Vector2(side * 6.0, -100.0)]
	# ミサイル発射中：両手を斜め上に
	var kick := 6.0 if side == _missile_arm and _missile_cd > MISSILE_INTERVAL * 0.5 else 0.0
	return [sh + Vector2(side * 40.0, -34.0), sh + Vector2(side * (62.0 - kick), -78.0 + kick)]


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
	if mode != "walk":
		var pose := _arm_pose(side)
		elbow = pose[0]
		fist = pose[1]
	elif side == _punch_arm and _punch_t >= 0.0:
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
	var flying := mode != "walk"
	if flying:
		step = 0.0
	# 影（飛んでいるときは下に離れて小さめ）
	if flying:
		draw_rect(Rect2(Vector2(-half.x * 0.7, half.y + 70.0), Vector2(half.x * 1.4, 12.0)), Color(0, 0, 0, 0.22))
	else:
		draw_rect(Rect2(Vector2(-half.x, half.y + 30.0), Vector2(half.x * 2.0, 14.0)), Color(0, 0, 0, 0.3))
	# ファイナルモード：ビーム（体の後ろから描く）
	if mode == "final":
		_draw_beams()
	# ロボットウイング（フライト・ファイナルモード）
	if flying:
		_draw_wings(half)
	# 足（ガシャガシャ歩く。飛んでいるときはぶら下がって、足の裏からジェット噴射）
	draw_rect(Rect2(Vector2(-half.x * 0.55 - 14.0, half.y - 4.0 + step), Vector2(28, 40)), dark)
	draw_rect(Rect2(Vector2(half.x * 0.55 - 14.0, half.y - 4.0 - step), Vector2(28, 40)), dark)
	if flying:
		for sx in [-1.0, 1.0]:
			var fx: float = sx * half.x * 0.55
			var flick := 10.0 + sin(_t * 30.0 + sx) * 5.0
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 11, half.y + 36), Vector2(fx + 11, half.y + 36), Vector2(fx, half.y + 50 + flick)]), Color(1.0, 0.6, 0.2, 0.9))
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 6, half.y + 36), Vector2(fx + 6, half.y + 36), Vector2(fx, half.y + 44 + flick * 0.6)]), Color(1.0, 0.95, 0.6))
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
	# ファイナルモード：胸のビーム発射口が光る
	if mode == "final":
		var g := 0.6 + 0.4 * sin(_t * 20.0)
		draw_circle(_beam_origin(), 14.0, Color(1.0, 0.4, 0.3, 0.5 * g))
		draw_circle(_beam_origin(), 8.0, Color(1.0, 0.95, 0.85))
	# 残り時間
	draw_rect(Rect2(Vector2(-half.x, -half.y - 22.0), Vector2(half.x * 2.0, 5.0)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(Vector2(-half.x, -half.y - 22.0), Vector2(half.x * 2.0 * _life / LIFE, 5.0)), Color(1.0, 0.8, 0.3))


## ロボットウイング：肩の後ろから左右に大きく広がる金属の翼（ファイナルモードは大きく光る）
func _draw_wings(half: Vector2) -> void:
	var is_final := mode == "final"
	var size := 1.35 if is_final else 1.0
	var flap := sin(_t * (14.0 if _fly_state == "tackle" else 6.0)) * 10.0
	var metal := Color(0.5, 0.55, 0.62)
	var edge := Color(1.0, 0.75, 0.35) if is_final else Color(0.55, 0.85, 1.0)
	for side in [-1.0, 1.0]:
		var root := Vector2(side * half.x * 0.6, -half.y * 0.5)
		var tip := root + Vector2(side * 150.0, -70.0 - flap) * size
		var mid := root + Vector2(side * 120.0, 10.0 - flap * 0.5) * size
		var low := root + Vector2(side * 70.0, 50.0) * size
		draw_colored_polygon(PackedVector2Array([root, tip, mid, low]), metal)
		# 羽根のすじ
		draw_line(root, tip, edge, 4.0)
		draw_line(root, mid, Color(0.38, 0.4, 0.45), 3.0)
		draw_line(root, low, Color(0.38, 0.4, 0.45), 3.0)
		draw_line(tip, mid, edge, 3.0)
		draw_line(mid, low, edge, 3.0)
		if is_final:
			draw_circle(tip, 8.0 + sin(_t * 12.0) * 2.0, Color(1.0, 0.85, 0.4, 0.8))


## ファイナルモードのビーム（胸から、それぞれの的まで）
func _draw_beams() -> void:
	var o := _beam_origin()
	for i in _beam_targets.size():
		var e = _beam_targets[i]
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		var col := Color.from_hsv(fmod(float(i) / BEAM_COUNT + _t * 0.3, 1.0), 0.55, 1.0)
		var w := 10.0 + sin(_t * 25.0 + i) * 3.0
		draw_line(o, to, Color(col.r, col.g, col.b, 0.3), w * 2.0)
		draw_line(o, to, Color(col.r, col.g, col.b, 0.85), w * 0.7)
		draw_line(o, to, Color(1, 1, 1, 0.95), 2.0)
		draw_circle(to, 12.0 + sin(_t * 20.0 + i) * 3.0, Color(col.r, col.g, col.b, 0.6))
