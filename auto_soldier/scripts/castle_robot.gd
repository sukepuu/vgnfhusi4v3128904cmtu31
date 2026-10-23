extends Node2D
## 城ロボ（城の特別強化「城ロボ起動」）。30秒ごとに城から出撃して、15秒間暴れまわる。
## 出撃中は、城についている兵装（矢倉・大砲・バリスタ・投石器）が城からはずれてロボットに付き、ロボットの位置から撃つ。
## （castle.wpos() がロボットの位置を返す。ロボットが消えると兵装は城に戻る）
## ロボットはいつもゆっくり歩き、全方位にぐるぐる射撃を続け、2秒ごとに近くの敵をパンチする。敵からは狙われない。
## mode（特別強化で変わる）：
##   "walk"   … ふつう（上の動き）
##   "flight" … フライトモード。翼で飛び、両手を上げて遠くの敵へ高速タックル → 両手から誘導ミサイル30発 をくり返す
##   "final"  … ファイナルモード。画面の真ん中から動かず、10本のビームをランダムな敵へ撃ち続けながら、両手から誘導ミサイルを撃ち続ける
##   "true"   … 真・ファイナルモード（金色）。ファイナルモードの攻撃 ＋ 出撃10秒後に両目から虹色レーザー
##   "charge" … 真・ファイナルモードに戻る前に、足を止めて震えながら光をためる
## 真・ファイナルモードを取ると城ロボは城に戻らなくなり、
##   真・ファイナル（15秒）→ 通常の城ロボ "walk"（10秒）→ "charge"（5秒）→ 真・ファイナル … をくり返す

const BulletScript := preload("res://scripts/bullet.gd")

const LIFE := 25.0
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


## 城ロボの攻撃力を基準に、各攻撃の倍率・城Lv・兵装数補正をかける。全16基でLv×5
func _robot_damage_scale() -> float:
	var castle: Node2D = game.castle
	var equip_count: int = mini(castle.tower_count, 4)
	equip_count += mini(castle.ballista_level, castle.MAX_BALLISTAS)
	equip_count += mini(castle.cannon_level, castle.MAX_GUNS)
	equip_count += mini(castle.catapult_level, castle.MAX_GUNS)
	equip_count += mini(castle.rapid_level, 2)
	return float(game.level) * (1.0 + equip_count * 0.25)


## 城ロボの攻撃力。通常弾は100%。
const ATTACK_POWER := 1.5


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
		if _cycle:
			_next_phase()
		else:
			game.spawn_burst(global_position, Color(0.8, 0.8, 0.75), 80.0)
			queue_free()
			return
	if mode == "true":
		_update_final(delta)
		_update_rainbow(delta)
		queue_redraw()
		return
	if mode == "charge":
		_update_charge()
		queue_redraw()
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
		var dmg: float = ATTACK_POWER * _robot_damage_scale()
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
			b.src = _walk_src()
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
			game.explode(hit_pos, 80.0, ATTACK_POWER * 13.33 * _robot_damage_scale(), _walk_src(), Color(1.0, 0.75, 0.4), 0.0, 600.0)
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


# ---------------- 真・ファイナルモードのくり返し ----------------
const TRUE_TIME := 25.0
const CYCLE_WALK_TIME := 20.0
const CHARGE_TIME := 5.0
var _cycle := false
## 今の段階の長さ（残り時間のバー用）
var _phase_len := LIFE


func is_final_like() -> bool:
	return mode == "final" or mode == "true"


## 真・ファイナルモードのくり返しを始める（真・ファイナルモードから）
func start_true_cycle() -> void:
	_cycle = true
	_enter_true()


func _enter_true() -> void:
	mode = "true"
	_life = TRUE_TIME
	_phase_len = TRUE_TIME
	_beam_targets.clear()
	_rainbow_target = null
	position = game.MAP_RECT.get_center()
	game.spawn_burst(global_position, Color(1.0, 0.9, 0.55), 160.0)


func _next_phase() -> void:
	match mode:
		"true":
			# 通常の城ロボが真ん中に出撃
			mode = "walk"
			_life = CYCLE_WALK_TIME
			_phase_len = CYCLE_WALK_TIME
			_punch_t = -1.0
			position = game.MAP_RECT.get_center()
			game.spawn_burst(global_position, Color(0.8, 0.8, 0.75), 80.0)
			game.castle.on_robot_sortie()
		"walk":
			# 足を止めて、震えながら光をためる
			mode = "charge"
			_life = CHARGE_TIME
			_phase_len = CHARGE_TIME
			_rays.clear()
		_:
			_enter_true()


# ---------------- 光をためる（真・ファイナルモードの前） ----------------
## 体からマップの端まで伸びる白い光（1秒ごとに1本ずつ増える）
var _rays: Array = []


func _update_charge() -> void:
	var passed := CHARGE_TIME - _life
	while _rays.size() < mini(int(passed) + 1, int(CHARGE_TIME)):
		_rays.append(randf() * TAU)


## p から dir の向きに、マップの端までの長さ
func _to_map_edge(p: Vector2, dir: Vector2) -> float:
	var r: Rect2 = game.MAP_RECT
	var best := INF
	if dir.x > 0.001:
		best = minf(best, (r.end.x - p.x) / dir.x)
	elif dir.x < -0.001:
		best = minf(best, (r.position.x - p.x) / dir.x)
	if dir.y > 0.001:
		best = minf(best, (r.end.y - p.y) / dir.y)
	elif dir.y < -0.001:
		best = minf(best, (r.position.y - p.y) / dir.y)
	return maxf(best, 0.0)


func _draw_rays() -> void:
	for i in _rays.size():
		var dir := Vector2.from_angle(_rays[i])
		var len := _to_map_edge(global_position, dir)
		var w := 14.0 + sin(_t * 30.0 + i) * 4.0
		draw_line(Vector2.ZERO, dir * len, Color(1, 1, 1, 0.25), w * 2.2)
		draw_line(Vector2.ZERO, dir * len, Color(1, 1, 1, 0.9), w * 0.6)
	var g := 1.0 - _life / CHARGE_TIME
	draw_circle(Vector2.ZERO, 40.0 + 60.0 * g, Color(1, 1, 1, 0.15 + 0.25 * g))


# ---------------- 真・ファイナルモードの虹色レーザー ----------------
## 真・ファイナルモードが始まってから、虹色レーザーを撃ち始める時間（10秒後と20秒後の2回）
const RAINBOW_STARTS := [10.0, 20.0]
const RAINBOW_TIME := 4.0
const RAINBOW_WIDTH := 30.0
const RAINBOW_TICK := 0.1
## 1本（片目）・0.1秒ごとのダメージ（城ロボの攻撃力 × これ）
const RAINBOW_DAMAGE := 3.33
var _rainbow_target: Node2D = null
var _rainbow_cd := 0.0


## ふつうの城ロボ（歩き）の射撃・パンチの記録先。
## 真・ファイナルモードのくり返しの途中で通常の城ロボに戻っている間は「真・ファイナルモード・クールタイムロボ」として記録する
func _walk_src() -> Dictionary:
	if _cycle:
		return game.sp_src(_record(), "robot_true_cool")
	return _record()


func _true_src() -> Dictionary:
	return game.sp_src(_record(), "sp_castle_robot_true")


func _rainbow_on() -> bool:
	if mode != "true":
		return false
	var passed := TRUE_TIME - _life
	for s in RAINBOW_STARTS:
		if passed >= s and passed < s + RAINBOW_TIME:
			return true
	return false


func _eye(side: int) -> Vector2:
	return Vector2(side * 24.0, -6.0)


## 体力が一番多い敵（倒すまで同じ敵を狙う）
func _pick_rainbow_target() -> Node2D:
	var best: Node2D = null
	var best_hp := -1.0
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		if e.hp > best_hp:
			best_hp = e.hp
			best = e
	return best


## 虹色レーザーの先（目から的を通って、マップの端まで）
func _rainbow_end(side: int) -> Vector2:
	var from: Vector2 = global_position + _eye(side)
	var dir: Vector2 = (_rainbow_target.global_position - from).normalized()
	return from + dir * _to_map_edge(from, dir)


func _update_rainbow(delta: float) -> void:
	if not _rainbow_on():
		_rainbow_target = null
		return
	if _rainbow_target == null or not is_instance_valid(_rainbow_target) or _rainbow_target.dead:
		_rainbow_target = _pick_rainbow_target()
	if _rainbow_target == null:
		return
	_rainbow_cd -= delta
	if _rainbow_cd > 0.0:
		return
	_rainbow_cd = RAINBOW_TICK
	var dmg: float = ATTACK_POWER * RAINBOW_DAMAGE * _robot_damage_scale()
	for side in [-1, 1]:
		var from: Vector2 = global_position + _eye(side)
		var seg: Vector2 = _rainbow_end(side) - from
		var seg_len2: float = maxf(seg.length_squared(), 1.0)
		for e in game.enemies_cache:
			if not is_instance_valid(e) or e.dead:
				continue
			var k: float = clampf((e.global_position - from).dot(seg) / seg_len2, 0.0, 1.0)
			if e.global_position.distance_to(from + seg * k) <= RAINBOW_WIDTH + e.radius:
				e.take_damage(dmg, Vector2.ZERO, _true_src())


func _draw_rainbow() -> void:
	if not _rainbow_on() or _rainbow_target == null or not is_instance_valid(_rainbow_target):
		return
	for side in [-1, 1]:
		var from := _eye(side)
		var to: Vector2 = _rainbow_end(side) - global_position
		# 太い虹：外側から内側へ色を変えて重ねる
		var bands := 7
		for b in bands:
			var col := Color.from_hsv(fmod(float(b) / bands + _t * 0.8, 1.0), 0.7, 1.0, 0.55)
			draw_line(from, to, col, RAINBOW_WIDTH * 2.0 * (1.0 - float(b) / bands) + 4.0)
		draw_line(from, to, Color(1, 1, 1, 0.95), 6.0)
		draw_circle(from, 16.0 + sin(_t * 30.0) * 3.0, Color(1, 1, 1, 0.9))


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
			e.take_damage(ATTACK_POWER * 4.17 * _robot_damage_scale(), _fly_dir * 500.0, _flight_src())
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
		_fire_missile(_flight_src(), ATTACK_POWER * _robot_damage_scale())
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
	var m: Node2D = game.spawn_missile("homing", p, dir * 520.0, dmg, 18.0, 3.0, src)
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


## ファイナルモードのビーム・ミサイルの記録先。真・ファイナルモード中は、真・ファイナルモードとして記録する
func _final_src() -> Dictionary:
	if mode == "true":
		return _true_src()
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
		var dmg: float = ATTACK_POWER * 0.444 * _robot_damage_scale()
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
		_fire_missile(_final_src(), ATTACK_POWER * 1.33 * _robot_damage_scale())


## ビームが出る場所（胸の真ん中）
func _beam_origin() -> Vector2:
	return Vector2(0, -6)


## フライト・ファイナルモードの腕の形：[ひじ, 拳]（ロボットの中心から）
func _arm_pose(side: int) -> Array:
	var sh := _shoulder(side)
	if is_final_like():
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
	var stone := _gold(Color(0.55, 0.53, 0.5))
	var sh := _shoulder(side)
	var swing := sin(_t * 6.0 + side) * 4.0
	# ふだんの形：肩 → 横へ（ひじ）→ 下へ（拳）のL字
	var elbow := sh + Vector2(side * 46.0, 0.0)
	var fist := elbow + Vector2(0.0, 48.0 + swing)
	if mode != "walk" and mode != "charge":
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
	draw_circle(fist, 20.0, _gold(Color(0.62, 0.6, 0.56)))
	draw_circle(fist + Vector2(-6, -6), 6.0, _gold(Color(0.75, 0.73, 0.7)))


## 真・ファイナルモードは体が金色になる
func _gold(c: Color) -> Color:
	if mode != "true":
		return c
	return Color(1.0, 0.8, 0.22).darkened(maxf(0.0, 0.45 - c.v * 0.6))


func _draw() -> void:
	var castle: Node2D = game.castle
	var half: Vector2 = castle.HALF
	var wall := _gold(Color(0.62, 0.6, 0.56))
	var dark := _gold(Color(0.35, 0.33, 0.3))
	var step := sin(_t * 6.0) * 8.0
	var flying := mode != "walk" and mode != "charge"
	if mode == "charge":
		# 光をためている間は足を止めて、ぶるぶる震える
		step = 0.0
		_draw_rays()
		var shake := 2.0 + 4.0 * (1.0 - _life / CHARGE_TIME)
		draw_set_transform(Vector2(randf_range(-shake, shake), randf_range(-shake, shake)))
	if flying:
		step = 0.0
	# 影（飛んでいるときは下に離れて小さめ）
	if flying:
		draw_rect(Rect2(Vector2(-half.x * 0.7, half.y + 70.0), Vector2(half.x * 1.4, 12.0)), Color(0, 0, 0, 0.22))
	else:
		draw_rect(Rect2(Vector2(-half.x, half.y + 30.0), Vector2(half.x * 2.0, 14.0)), Color(0, 0, 0, 0.3))
	# ファイナルモード：ビーム（体の後ろから描く）
	if is_final_like():
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
	# 現在の城と同じ左右の張り出し
	var ext_w := half.x * 0.3
	var ext_h := half.y * 0.7
	draw_rect(Rect2(Vector2(-half.x - ext_w, -ext_h), Vector2(ext_w, ext_h * 2.0)), wall)
	draw_rect(Rect2(Vector2(-half.x - ext_w, -ext_h), Vector2(ext_w, ext_h * 2.0)), dark, false, 2.0)
	draw_rect(Rect2(Vector2(half.x, -ext_h), Vector2(ext_w, ext_h * 2.0)), wall)
	draw_rect(Rect2(Vector2(half.x, -ext_h), Vector2(ext_w, ext_h * 2.0)), dark, false, 2.0)
	if mode == "true":
		# 金色の輝き（ふちが光り、ななめの光の筋が流れる）
		var shine := 0.5 + 0.3 * sin(_t * 4.0)
		draw_rect(Rect2(-half - Vector2(4, 4), half * 2.0 + Vector2(8, 8)), Color(1.0, 0.85, 0.3, shine), false, 4.0)
		var sx := fposmod(_t * 160.0, half.x * 4.0) - half.x * 2.0
		if absf(sx) < half.x - 26.0:
			draw_line(Vector2(sx - 20.0, half.y), Vector2(sx + 20.0, -half.y), Color(1.0, 0.97, 0.75, 0.55), 10.0)
	var bw := 16.0
	var x := -half.x
	while x < half.x - 1.0:
		draw_rect(Rect2(Vector2(x, -half.y - 10.0), Vector2(bw * 0.6, 10.0)), wall)
		x += bw
	# 現在の城と同じ旗
	draw_line(Vector2(0, -half.y - 10.0), Vector2(0, -half.y - 50.0), dark, 3.0)
	var flag_wave := sin(_t * 4.0) * 3.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -half.y - 50.0), Vector2(26, -half.y - 44.0 + flag_wave), Vector2(0, -half.y - 36.0)]), Color(0.3, 0.55, 1.0))
	# 目（光る）
	var glow := 0.7 + 0.3 * sin(_t * 8.0)
	draw_circle(Vector2(-24, -6), 9.0, Color(1.0, 0.85, 0.3, glow))
	draw_circle(Vector2(24, -6), 9.0, Color(1.0, 0.85, 0.3, glow))
	draw_rect(Rect2(Vector2(-18, half.y - 30.0), Vector2(36, 30)), Color(0.3, 0.2, 0.12))
	# 城からはずれた兵装を、ロボットの体に付けて描く
	castle.draw_weapons(self, Vector2.ZERO)
	# ファイナルモード：胸のビーム発射口が光る
	if is_final_like():
		var g := 0.6 + 0.4 * sin(_t * 20.0)
		draw_circle(_beam_origin(), 14.0, Color(1.0, 0.4, 0.3, 0.5 * g))
		draw_circle(_beam_origin(), 8.0, Color(1.0, 0.95, 0.85))
	# 残り時間
	draw_rect(Rect2(Vector2(-half.x, -half.y - 22.0), Vector2(half.x * 2.0, 5.0)), Color(0, 0, 0, 0.6))
	var bar := Color(1.0, 0.95, 0.6) if mode == "true" else (Color(1, 1, 1) if mode == "charge" else Color(1.0, 0.8, 0.3))
	draw_rect(Rect2(Vector2(-half.x, -half.y - 22.0), Vector2(half.x * 2.0 * clampf(_life / _phase_len, 0.0, 1.0), 5.0)), bar)
	draw_set_transform(Vector2.ZERO)
	# 真・ファイナルモード：両目から虹色レーザー（体の前に描く）
	if mode == "true":
		_draw_rainbow()


## ロボットウイング：肩の後ろから左右に大きく広がる金属の翼（ファイナルモードは大きく光る）
func _draw_wings(half: Vector2) -> void:
	var is_final := is_final_like()
	var size := 1.35 if is_final else 1.0
	var flap := sin(_t * (14.0 if _fly_state == "tackle" else 6.0)) * 10.0
	var metal := _gold(Color(0.5, 0.55, 0.62))
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
