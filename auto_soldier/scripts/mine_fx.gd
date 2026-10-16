extends Node2D
## 採掘場の特別強化で出てくる物。
## mole   ：もぐら。地面の下を進んで敵の足元から飛び出して攻撃 → また潜る、を3回くり返して消える
## trolley：必殺・暴走トロッコ。マップの右端から左端へ横一直線に突進して、通った敵を全部はねる。
##          ダメージを与えた敵1体につき経験値+1（倍率なし）

const MOLE_SPEED := 320.0
const MOLE_RADIUS := 60.0
const MOLE_DAMAGE := 150.0
const MOLE_ATTACKS := 3
const TROLLEY_SPEED := 900.0
const TROLLEY_RADIUS := 34.0
const TROLLEY_DAMAGE := 600.0

var game: Node2D
var kind := "mole"
## もぐらを出した採掘場（記録・爆弾に使う）
var mine: Node2D
var damage := 0.0
var src: Dictionary = {}

var _t := 0.0
## もぐら：underground（潜って移動中）/ up（地上に出ている）
var _state := "underground"
var _target: Node2D = null
var _attacks_left := MOLE_ATTACKS
var _up_left := 0.0
var _trail: Array = []
var _trail_cd := 0.0
var _idle_left := 4.0
## トロッコ：もう当たった敵と、はねた数
var _hit := {}
var hits := 0
var attacks_done := 0


func _ready() -> void:
	if kind == "mole":
		damage = MOLE_DAMAGE * (1.0 + game.elapsed / 120.0)
		src = game.sp_src(mine.record, "sp_mine_mole")
	elif kind == "trolley":
		damage = TROLLEY_DAMAGE * (1.0 + game.elapsed / 120.0)
		var rec: Dictionary = game.mine_sites[0].record
		src = game.sp_src(rec, "sp_ult_trolley")
		z_index = 5


func _process(delta: float) -> void:
	_t += delta
	if kind == "mole":
		_update_mole(delta)
	else:
		_update_trolley(delta)
	queue_redraw()


# ---------------------------------------------------------------- もぐら

func _update_mole(delta: float) -> void:
	for p in _trail:
		p["t"] -= delta
	_trail = _trail.filter(func(p: Dictionary) -> bool: return p["t"] > 0.0)
	if _state == "up":
		_up_left -= delta
		if _up_left <= 0.0:
			if _attacks_left <= 0:
				queue_free()
				return
			_state = "underground"
			_target = null
		return
	if _target == null or not is_instance_valid(_target) or _target.dead:
		_target = game.nearest_enemy(global_position, INF)
		if _target == null:
			# 敵がいなければしばらく待って、いなければ消える
			_idle_left -= delta
			if _idle_left <= 0.0:
				queue_free()
			return
	_idle_left = 4.0
	var to: Vector2 = _target.global_position - global_position
	var step := MOLE_SPEED * delta
	if to.length() <= step + 4.0:
		position = _target.global_position
		_pop_up()
		return
	position += to.normalized() * step
	# 通った跡に土の盛り上がりを残す
	_trail_cd -= delta
	if _trail_cd <= 0.0:
		_trail_cd = 0.05
		_trail.append({"p": global_position, "t": 0.8})


## 敵の足元から飛び出して攻撃
func _pop_up() -> void:
	_attacks_left -= 1
	attacks_done += 1
	_state = "up"
	_up_left = 0.45
	game.explode(global_position, MOLE_RADIUS, damage, src, Color(0.6, 0.45, 0.3), 0.0, 260.0)
	game.spawn_burst(global_position, Color(0.55, 0.42, 0.28), 30.0)
	# もぐら爆弾：攻撃した場所に発破用の爆弾を置く
	if game.mole_bomb and is_instance_valid(mine):
		mine.place_bomb(global_position)


# ---------------------------------------------------------------- トロッコ

func _update_trolley(delta: float) -> void:
	position.x -= TROLLEY_SPEED * delta
	for e in game.enemies_near(global_position, TROLLEY_RADIUS + 40.0):
		if not is_instance_valid(e) or e.dead or _hit.has(e):
			continue
		if global_position.distance_to(e.global_position) < TROLLEY_RADIUS + e.radius:
			_hit[e] = true
			e.take_damage(damage, Vector2(-260.0, -60.0), src)
			hits += 1
			# はねた敵1体につき経験値+1
			game.add_raw_xp(1)
			# 部隊戦績：トロッコの経験値は採掘場1に入れる
			var rec: Dictionary = game.mine_sites[0].record
			rec["xp"] = int(rec.get("xp", 0)) + 1
			game.spawn_burst(e.global_position, Color(1.0, 0.8, 0.4), 18.0)
	if position.x < game.MAP_RECT.position.x - 60.0:
		queue_free()


# ---------------------------------------------------------------- 見た目

func _draw() -> void:
	if kind == "trolley":
		_draw_trolley()
		return
	for p in _trail:
		var lp: Vector2 = p["p"] - global_position
		draw_circle(lp, 7.0, Color(0.42, 0.32, 0.2, clampf(p["t"] / 0.8, 0.0, 1.0) * 0.8))
	# もぐらの大きさは元の2倍（攻撃の範囲は MOLE_RADIUS のまま）
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.0, 2.0))
	if _state == "underground":
		# 地面の盛り上がり
		draw_circle(Vector2.ZERO, 10.0, Color(0.48, 0.36, 0.22))
		draw_circle(Vector2(-3, -3), 4.0, Color(0.58, 0.45, 0.3))
		return
	# 地上に出ているもぐら（出てきてすぐに大きく、潜るときに小さく）
	var k := clampf(minf((0.45 - _up_left) * 8.0, _up_left * 6.0), 0.0, 1.0)
	draw_circle(Vector2(0, 6), 16.0, Color(0.4, 0.3, 0.18))
	var body := Vector2(0, 6 - 18.0 * k)
	draw_circle(body, 13.0, Color(0.3, 0.24, 0.22))
	draw_circle(body + Vector2(0, 6), 6.0, Color(1.0, 0.7, 0.7))
	draw_circle(body + Vector2(-5, -3), 2.0, Color(0, 0, 0))
	draw_circle(body + Vector2(5, -3), 2.0, Color(0, 0, 0))
	# 前足の爪
	draw_line(body + Vector2(-12, 4), body + Vector2(-17, 8), Color(0.95, 0.9, 0.85), 2.0)
	draw_line(body + Vector2(12, 4), body + Vector2(17, 8), Color(0.95, 0.9, 0.85), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_trolley() -> void:
	# 土ぼこり
	for i in 4:
		draw_circle(Vector2(30 + i * 14, 14 + sin(_t * 20.0 + i) * 3.0), 8.0 - i, Color(0.6, 0.5, 0.35, 0.4))
	# 車体と、山盛りの鉱石
	draw_circle(Vector2(-6, -16), 14.0, Color(0.5, 0.48, 0.45))
	draw_circle(Vector2(10, -14), 11.0, Color(0.45, 0.43, 0.4))
	draw_circle(Vector2(-2, -22), 4.0, Color(0.5, 0.95, 1.0))
	draw_circle(Vector2(12, -18), 3.5, Color(1.0, 0.85, 0.3))
	var cart := PackedVector2Array([Vector2(-30, -12), Vector2(30, -12), Vector2(24, 12), Vector2(-24, 12)])
	draw_colored_polygon(cart, Color(0.55, 0.32, 0.18))
	draw_polyline(cart + PackedVector2Array([cart[0]]), Color(0.3, 0.18, 0.1), 3.0)
	draw_line(Vector2(-27, -2), Vector2(27, -2), Color(0.7, 0.7, 0.72), 2.0)
	# 車輪（回る）
	for wx in [-15.0, 15.0]:
		var c := Vector2(wx, 14)
		draw_circle(c, 7.0, Color(0.25, 0.25, 0.28))
		var sp := Vector2.from_angle(-_t * 30.0) * 6.0
		draw_line(c - sp, c + sp, Color(0.7, 0.7, 0.72), 2.0)
