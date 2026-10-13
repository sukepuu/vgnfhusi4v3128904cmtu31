extends Node2D
## 近衛部隊（最大3人）。フィールドの一番下（城に一番近い高さ）にいる敵を最優先で狙う。
## 敵の近くまで行ったら、一直線に高速で突進して、通り道の敵をまとめて貫く。
## 突進中は無敵。倒されても10秒後に城から復活する。ステータスは game.knight_stats を全員で共有。

const RESPAWN_TIME := 10.0
const DASH_SPEED := 1100.0
## この距離まで近づいたら突進する
const DASH_START := 190.0

var game: Node2D
var index := 0
var radius := 15.0
var hp := 110.0
var dead := false
var respawn_left := 0.0
var target: Node2D = null
var record: Dictionary
var facing := Vector2.UP

var _cd := 0.5
var _retarget_cd := 0.0
var _dash_left := 0.0
var _dash_dir := Vector2.UP
var _dash_hit := {}
var _chain_left := 0
## 疾風怒濤：残りの連鎖回数と、今の突進で敵を倒したか
var _kill_chain_left := 0
var _dash_killed := false
var _star_cd := 0.0
var _hurt_flash := 0.0
var _invuln := 0.0
var _trail: Array = []
## 連行突撃で連れていっている敵
var _carried: Array = []


func _ready() -> void:
	record = game.new_record("knight", "近衛兵%d" % (index + 1))
	hp = game.knight_stats.max_hp


func is_dashing() -> bool:
	return _dash_left > 0.0


func _process(delta: float) -> void:
	if dead:
		respawn_left -= delta
		if respawn_left <= 0.0:
			dead = false
			hp = game.knight_stats.max_hp
			position = game.castle.gate_position()
			_invuln = 1.5
		queue_redraw()
		return
	var st = game.knight_stats
	_cd -= delta
	_retarget_cd -= delta
	_hurt_flash -= delta
	_invuln -= delta
	hp = minf(st.max_hp, hp + 2.0 * delta)
	# 突進の残像
	_trail.push_front(position)
	if _trail.size() > 8:
		_trail.pop_back()

	if is_dashing():
		_update_dash(delta, st)
		queue_redraw()
		return

	if _retarget_cd <= 0.0 or not _target_valid():
		target = _lowest_enemy()
		_retarget_cd = 0.3
	if _target_valid():
		var to: Vector2 = target.global_position - global_position
		var d := to.length()
		facing = to / maxf(d, 0.001)
		if d < DASH_START and _cd <= 0.0:
			_start_dash(facing, st)
			_chain_left = st.chain
			_kill_chain_left = 5
		elif d > DASH_START * 0.8:
			position += facing * st.move_speed * delta
	else:
		# 敵がいなければ城の前で待機
		var home: Vector2 = game.castle.gate_position() + Vector2((index - 1) * 50.0, -60.0)
		var to_home := home - position
		if to_home.length() > 6.0:
			position += to_home.normalized() * minf(st.move_speed * delta, to_home.length())
	position = game.clamp_to_map(position, radius)
	queue_redraw()


func _target_valid() -> bool:
	return target != null and is_instance_valid(target) and not target.dead


## フィールドの一番下にいる敵（y が一番大きい敵）
func _lowest_enemy() -> Node2D:
	var best: Node2D = null
	var best_y := -INF
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		if e.global_position.y > best_y:
			best_y = e.global_position.y
			best = e
	return best


## dist = 突進する距離（省略すると通常の突進距離）
func _start_dash(dir: Vector2, st, dist: float = -1.0) -> void:
	_dash_dir = dir
	_dash_left = maxf(st.dash_distance, dist) / DASH_SPEED
	_dash_hit.clear()
	_dash_killed = false
	_cd = st.interval


func _update_dash(delta: float, st) -> void:
	position += _dash_dir * DASH_SPEED * delta
	position = game.clamp_to_map(position, radius)
	_dash_left -= delta
	# 連行突撃：つかまえた敵を槍の先に引っかけて運ぶ
	var k := 0
	for c in _carried:
		if is_instance_valid(c) and not c.dead:
			c.position = global_position + _dash_dir * (radius + c.radius + 4.0) + _dash_dir.orthogonal() * (k % 3 - 1) * 14.0
			c.knock = Vector2.ZERO
			k += 1
	# 隠密兵を1発で倒せる威力（敵が強くなるのに合わせて上がる）
	var dmg: float = st.damage * game._hp_mult()
	for e in game.enemies_near(global_position, radius + 50.0):
		if not is_instance_valid(e) or e.dead or _dash_hit.has(e):
			continue
		if global_position.distance_to(e.global_position) < radius + e.radius + 6.0:
			_dash_hit[e] = true
			var hit_dmg := dmg
			# とどめの一撃：弱った敵（ボス以外）は一撃で倒す
			if st.execute and not e.is_boss and e.hp <= e.max_hp * 0.2:
				hit_dmg = maxf(dmg, e.hp + 1.0)
			if st.stun_hit:
				e.stun(1.0)
			e.take_damage(hit_dmg, _dash_dir * 350.0, record)
			if e.dead:
				_dash_killed = true
			if st.carry and not e.is_boss and not e.dead and e.speed > 0.0:
				_carried.append(e)
			if st.heal_on_hit:
				hp = minf(st.max_hp, hp + 8.0)
	# 流れ星突撃：通った跡に星が残って弾ける
	if st.star_trail:
		_star_cd -= delta
		if _star_cd <= 0.0:
			_star_cd = 0.05
			game.spawn_blast(global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.35, 34.0, dmg * 0.15, record, Color(1.0, 0.95, 0.4), "star")
	if _dash_left <= 0.0:
		_dash_left = 0.0
		# 運んでいた敵を、勢いよく放り出す（城の方へは飛ばさない）
		for c in _carried:
			if is_instance_valid(c) and not c.dead:
				c.knock = c.no_castle_push(_dash_dir * 400.0)
		_carried.clear()
		# 突撃の衝撃：止まった所で爆発
		if st.quake:
			game.explode(global_position, 90.0, dmg * 0.6, record, Color(1.0, 0.85, 0.4), 0.0, 300.0)
		# 疾風怒濤：敵を倒していたら、すぐ次の敵へ突進し直す（最大5連鎖）
		if st.kill_chain and _dash_killed and _kill_chain_left > 0:
			var nk := _nearest_unhit(450.0)
			if nk != null:
				_kill_chain_left -= 1
				var to_k: Vector2 = nk.global_position - global_position
				facing = to_k.normalized()
				_start_dash(facing, st, to_k.length() + 40.0)
				return
		# 連続突撃：すぐ次の敵へ
		if _chain_left > 0:
			var next := _nearest_unhit(320.0)
			if next != null:
				_chain_left -= 1
				facing = (next.global_position - global_position).normalized()
				_start_dash(facing, st)


func _nearest_unhit(max_d: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_d
	for e in game.enemies_near(global_position, max_d):
		if not is_instance_valid(e) or e.dead or _dash_hit.has(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func take_damage(amount: float, _from_pos: Vector2 = Vector2.INF) -> void:
	if dead or _invuln > 0.0 or is_dashing():
		return
	record["taken"] += minf(amount, hp)
	hp -= amount
	_hurt_flash = 0.15
	_invuln = 0.25
	game.spawn_damage_text(global_position, amount, Color(1.0, 0.35, 0.35))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		target = null
		respawn_left = RESPAWN_TIME


func _draw() -> void:
	if dead:
		# 復活待ち：城の前に半透明の兜
		var p: Vector2 = game.castle.gate_position() - position
		draw_circle(p, 10.0, Color(0.9, 0.8, 0.4, 0.3))
		return
	# 突進中の残像
	if is_dashing():
		for i in _trail.size():
			var a := 0.35 * (1.0 - float(i) / _trail.size())
			draw_circle(_trail[i] - position, radius * 0.9, Color(1.0, 0.85, 0.4, a))
	draw_circle(Vector2(0, 7), radius, Color(0, 0, 0, 0.3))
	var body := Color(1, 1, 1) if _hurt_flash > 0.0 else Color(0.85, 0.7, 0.3)
	draw_circle(Vector2.ZERO, radius, body)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.45, 0.3, 0.1), 2.0)
	# 赤い羽根飾りの兜
	draw_circle(-facing * 3.0, 8.0, Color(0.75, 0.75, 0.8))
	draw_line(-facing * 3.0, -facing * 3.0 - facing * 9.0 + facing.orthogonal() * 3.0, Color(0.9, 0.2, 0.2), 4.0)
	# 長い騎槍
	var side := facing.orthogonal() * 9.0
	var tip_len := 30.0 if is_dashing() else 22.0
	draw_line(side - facing * 6.0, side + facing * tip_len, Color(0.6, 0.45, 0.25), 3.0)
	draw_colored_polygon(PackedVector2Array([
		side + facing * (tip_len + 10.0), side + facing * tip_len + facing.orthogonal() * 4.0,
		side + facing * tip_len - facing.orthogonal() * 4.0]), Color(0.9, 0.9, 0.95))
	# HPバー
	var st = game.knight_stats
	if hp < st.max_hp:
		var top := Vector2(-16, -radius - 10)
		draw_rect(Rect2(top, Vector2(32, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(32 * hp / st.max_hp, 4)), Color(0.4, 0.9, 0.4))
