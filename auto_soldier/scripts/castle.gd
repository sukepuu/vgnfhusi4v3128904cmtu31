extends Node2D
## 守るべき城。HPが0になったらゲームオーバー。
## 強化で迎撃システム（矢倉・大砲・投石器・バリスタ・氷結の結界）が増えていく。

const BulletScript := preload("res://scripts/bullet.gd")
const ShellScript := preload("res://scripts/shell.gd")

## 城本体の半分のサイズ（当たり判定もこの四角形）
const HALF := Vector2(95, 45)

var game: Node2D
var max_hp := 600.0
var hp := 600.0
var regen := 0.0

# --- 矢倉（自動で矢を撃つ）
var tower_count := 0
var tower_interval := 0.9
var tower_damage := 24.0
var tower_range := 520.0
var _tower_cds: Array = [0.0, 0.3, 0.6, 0.15]
var _tower_aims: Array = [Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP]

# --- 大砲（範囲攻撃）。強化を取るたびに1門ずつ増える（最大3門）
const MAX_GUNS := 3
var cannon_level := 0
var cannon_interval := 4.0
var cannon_damage := 40.0
var cannon_radius := 90.0
var cannon_range := 650.0
var _cannon_cds: Array = [1.0, 2.3, 3.6]
var _cannon_aims: Array = [Vector2.UP, Vector2.UP, Vector2.UP]

# --- 投石器（大砲より範囲が広いが、発射間隔が長い）。最大3台
var catapult_level := 0
var catapult_interval := 9.0
var catapult_damage := 48.0
var catapult_radius := 150.0
var _catapult_cds: Array = [2.0, 5.0, 8.0]
var _catapult_swings: Array = [0.0, 0.0, 0.0]
# --- バリスタ（矢倉より発射間隔が長いが、高威力・射程無限・貫通無限）。最大3基
var ballista_level := 0
var ballista_interval := 4.0
var ballista_damage := 96.0
var _ballista_cds: Array = [1.0, 2.3, 3.6]
var _ballista_aims: Array = [Vector2.UP, Vector2.UP, Vector2.UP]
var _ballista_recoil: Array = [0.0, 0.0, 0.0]

## 直前に撃ち込んだ場所（同じ場所に重ねて撃たないように）
var _recent_shots: Array = []

# --- 氷結の結界（近くの敵を遅くする）
var frost_radius := 0.0
var frost_slow := 0.0

# --- 特別強化
var tower_shots := 1
var tower_pierce := 0
var scatter_level := 0
var fire_level := 0
var split_level := 0
var ballista_shots := 1
var bolt_blast_level := 0
var freeze_level := 0
var icicle_level := 0
var tower_crit := false
var rock_rain := false
var big_bolt := false
var blizzard := false
var _blizzard_tick := 0.0
var _freeze_cd := 5.0
var _icicle_cd := 2.0

var _flash := 0.0
## 戦績カード（城の本体と、設備1基ずつ）
var record: Dictionary
var _equip_records := {}
var _t := 0.0


func _ready() -> void:
	record = game.new_record("castle", "城（本体）")


## 設備1基ごとの戦績カード（最初に使うときに作る）
func _equip_record(key: String, label: String, i: int) -> Dictionary:
	var k := "%s%d" % [key, i]
	if not _equip_records.has(k):
		_equip_records[k] = game.new_record("castle", "%s%d" % [label, i + 1])
	return _equip_records[k]


func _process(delta: float) -> void:
	_t += delta
	_flash -= delta
	if regen > 0.0:
		hp = minf(max_hp, hp + regen * delta)
	_update_towers(delta)
	_update_cannon(delta)
	_update_catapult(delta)
	_update_ballista(delta)
	_update_frost_specials(delta)
	queue_redraw()


# ---------------------------------------------------------------- 当たり判定まわり

func body_rect() -> Rect2:
	return Rect2(global_position - HALF, HALF * 2.0)


func closest_point(p: Vector2) -> Vector2:
	var r := body_rect()
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


func distance_to_point(p: Vector2) -> float:
	return p.distance_to(closest_point(p))


func gate_position() -> Vector2:
	return global_position + Vector2(0, -HALF.y - 24.0)


## 氷結の結界の中なら速度倍率（1未満）を返す
func slow_factor_at(p: Vector2) -> float:
	if frost_radius > 0.0 and p.distance_to(global_position) < frost_radius:
		return 1.0 - frost_slow
	return 1.0


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	record["taken"] += minf(amount, hp)
	hp -= amount
	_flash = 0.15
	game.spawn_damage_text(global_position + Vector2(randf_range(-60, 60), -HALF.y), amount, Color(1.0, 0.5, 0.2))
	if hp <= 0.0:
		hp = 0.0
		game.on_castle_destroyed()


# ---------------------------------------------------------------- 迎撃システム

func _tower_local_pos(i: int) -> Vector2:
	match i:
		0: return Vector2(-HALF.x - 6.0, -HALF.y - 10.0)
		1: return Vector2(HALF.x + 6.0, -HALF.y - 10.0)
		2: return Vector2(-HALF.x * 0.45, -HALF.y - 22.0)
		_: return Vector2(HALF.x * 0.45, -HALF.y - 22.0)


func _update_towers(delta: float) -> void:
	for i in tower_count:
		_tower_cds[i] -= delta
		if _tower_cds[i] > 0.0:
			continue
		var from := global_position + _tower_local_pos(i)
		var target: Node2D = game.nearest_enemy(from, tower_range)
		if target == null:
			continue
		var aim := (target.global_position - from).normalized()
		_tower_aims[i] = aim
		# 連射なら少しずつ角度をずらして複数本
		for k in tower_shots:
			var dir := aim.rotated((k - (tower_shots - 1) / 2.0) * 0.12)
			var b := BulletScript.new()
			b.game = game
			b.velocity = dir * 760.0
			b.damage = tower_damage
			# 会心の一矢：25%でダメージ3倍
			if tower_crit and randf() < 0.25:
				b.damage = tower_damage * 3.0
				b.radius = 6.0
			b.pierce = tower_pierce
			b.radius = 4.0
			b.color = Color(0.95, 0.8, 0.55)
			b.src = _equip_record("tower", "矢倉", i)
			b.life = tower_range / 760.0 + 0.2
			b.position = from
			game.world.add_child(b)
		_tower_cds[i] = tower_interval


func _update_cannon(delta: float) -> void:
	for i in mini(cannon_level, MAX_GUNS):
		_cannon_cds[i] -= delta
		if _cannon_cds[i] > 0.0:
			continue
		var best := _densest_enemy(cannon_range, cannon_radius)
		if best == null:
			continue
		var from := global_position + _cannon_local_pos(i)
		_cannon_aims[i] = (best.global_position - from).normalized()
		var rec := _equip_record("cannon", "大砲", i)
		var shells: Array = [_fire_shell(from, best.global_position, cannon_damage, cannon_radius, false, rec)]
		# 散弾砲：着弾地点の周りにも落ちる
		for k in scatter_level * 2:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(60.0, 110.0)
			shells.append(_fire_shell(from, best.global_position + off, cannon_damage * 0.7, cannon_radius * 0.8, false, rec))
		# 焼夷弾：着弾地点が燃える
		if fire_level > 0:
			for s in shells:
				s.fire_time = 4.0 + 2.0 * (fire_level - 1)
				s.fire_dps = cannon_damage * 0.3 * fire_level
		_cannon_cds[i] = cannon_interval


func _update_catapult(delta: float) -> void:
	for i in mini(catapult_level, MAX_GUNS):
		_catapult_swings[i] -= delta
		_catapult_cds[i] -= delta
		if _catapult_cds[i] > 0.0:
			continue
		var best := _densest_enemy(2000.0, catapult_radius)
		if best == null:
			continue
		var from := global_position + _catapult_local_pos(i) + Vector2(0, -20)
		var s := _fire_shell(from, best.global_position, catapult_damage, catapult_radius, true, _equip_record("catapult", "投石器", i))
		if split_level > 0:
			s.split_count = 2 + 2 * split_level
		# 岩雨：ランダムな敵2体の頭上にも岩が落ちる
		if rock_rain:
			var pool: Array = game.enemies_cache.filter(func(e: Node2D) -> bool: return is_instance_valid(e) and not e.dead)
			pool.shuffle()
			for e in pool.slice(0, 2):
				game.spawn_blast(e.global_position, 1.0, 75.0, catapult_damage * 0.6, s.src, Color(0.75, 0.65, 0.5), "rock")
		_catapult_cds[i] = catapult_interval
		_catapult_swings[i] = 0.4


func _update_ballista(delta: float) -> void:
	for i in mini(ballista_level, MAX_GUNS):
		_ballista_recoil[i] -= delta
		_ballista_cds[i] -= delta
		if _ballista_cds[i] > 0.0:
			continue
		var from := global_position + _ballista_local_pos(i)
		var aim := _best_pierce_dir(from)
		if aim == Vector2.ZERO:
			continue
		_ballista_aims[i] = aim
		# 連装なら少しずつ角度をずらして複数発
		for k in ballista_shots:
			var dir := aim.rotated((k - (ballista_shots - 1) / 2.0) * 0.07)
			var b := BulletScript.new()
			b.game = game
			b.velocity = dir * 1000.0
			b.damage = ballista_damage
			b.pierce = 1000000
			b.radius = 7.0
			if big_bolt:
				b.radius = 16.0
				b.scale = Vector2(1.8, 1.8)
			b.bolt = true
			b.src = _equip_record("ballista", "バリスタ", i)
			b.life = 2.5
			b.position = from
			if bolt_blast_level > 0:
				b.explode_radius = 40.0 + 15.0 * bolt_blast_level
				b.explode_ratio = 0.15 + 0.15 * bolt_blast_level
			game.world.add_child(b)
		_ballista_cds[i] = ballista_interval
		_ballista_recoil[i] = 0.25


## 一直線上に一番多くの敵が並ぶ向き（敵がいなければ ZERO）
func _best_pierce_dir(from: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_n := 0
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var dir: Vector2 = (e.global_position - from).normalized()
		var n := 0
		for o in game.enemies_cache:
			if not is_instance_valid(o) or o.dead:
				continue
			var rel: Vector2 = o.global_position - from
			if rel.dot(dir) > 0.0 and absf(rel.dot(dir.orthogonal())) < o.radius + 7.0:
				n += 1
		if n > best_n:
			best_n = n
			best = dir
	return best


func _fire_shell(from: Vector2, to: Vector2, dmg: float, area: float, boulder: bool, src: Dictionary) -> Node2D:
	var s := ShellScript.new()
	s.src = src
	s.game = game
	s.start = from
	s.target = to
	s.damage = dmg
	s.blast_radius = area
	s.boulder = boulder
	if boulder:
		s.flight_time = 1.3
	s.position = from
	game.effects.add_child(s)
	_recent_shots.append({"pos": to, "area": area, "until": _t + s.flight_time + 0.3})
	return s


## 氷結の結界の特別強化（絶対零度・氷柱）
func _update_frost_specials(delta: float) -> void:
	if frost_radius <= 0.0:
		return
	if freeze_level > 0:
		_freeze_cd -= delta
		if _freeze_cd <= 0.0:
			_freeze_cd = 10.0 if freeze_level == 1 else 8.0
			var t := 2.0 if freeze_level == 1 else 3.5
			for e in game.enemies_cache:
				if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < frost_radius:
					e.stun(t)
			game.spawn_burst(global_position, Color(0.7, 0.95, 1.0), frost_radius / 2.2)
	# 吹雪：結界の中の敵にずっとダメージ
	if blizzard:
		_blizzard_tick -= delta
		if _blizzard_tick <= 0.0:
			_blizzard_tick = 0.5
			var dps: float = 20.0 * (1.0 + game.elapsed / 120.0)
			var rec := _equip_record("frost", "氷結の結界", 0)
			for e in game.enemies_cache:
				if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < frost_radius:
					e.take_damage(dps * 0.5, Vector2.ZERO, rec)
	if icicle_level > 0:
		_icicle_cd -= delta
		if _icicle_cd <= 0.0:
			_icicle_cd = 2.5 if icicle_level == 1 else 1.5
			var inside: Array = []
			for e in game.enemies_cache:
				if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < frost_radius:
					inside.append(e)
			inside.shuffle()
			var dmg: float = 60.0 * icicle_level * (1.0 + game.elapsed / 180.0)
			for e in inside.slice(0, icicle_level):
				game.spawn_blast(e.global_position, 0.5, 45.0, dmg, _equip_record("frost", "氷結の結界", 0), Color(0.7, 0.95, 1.0), "ice", 0.5)


## 敵が一番密集している場所にいる敵（射程内）
func _densest_enemy(max_range: float, area: float) -> Node2D:
	_recent_shots = _recent_shots.filter(func(r: Dictionary) -> bool: return r["until"] > _t)
	var best: Node2D = null
	var best_score := 0
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		if global_position.distance_to(e.global_position) > max_range:
			continue
		# まだ着弾していない砲弾の範囲内は狙わない
		var covered := false
		for r in _recent_shots:
			if e.global_position.distance_to(r["pos"]) < r["area"] * 0.8:
				covered = true
				break
		if covered:
			continue
		var n: int = game.enemies_near(e.global_position, area).size()
		if n > best_score:
			best_score = n
			best = e
	return best


func _cannon_local_pos(i: int) -> Vector2:
	match i:
		0: return Vector2(0, -HALF.y - 30.0)
		1: return Vector2(-72, -HALF.y - 26.0)
		_: return Vector2(72, -HALF.y - 26.0)


func _ballista_local_pos(i: int) -> Vector2:
	match i:
		0: return Vector2(-HALF.x * 0.78, HALF.y * 0.45)
		1: return Vector2(HALF.x * 0.78, HALF.y * 0.45)
		_: return Vector2(HALF.x * 0.4, HALF.y * 0.55)


func _catapult_local_pos(i: int) -> Vector2:
	match i:
		0: return Vector2(-HALF.x * 0.55, -HALF.y * 0.2)
		1: return Vector2(HALF.x * 0.55, -HALF.y * 0.2)
		_: return Vector2(0, -HALF.y * 0.55)


# ---------------------------------------------------------------- 描画

func _draw() -> void:
	if frost_radius > 0.0:
		var pulse := 0.06 + sin(_t * 2.0) * 0.02
		draw_circle(Vector2.ZERO, frost_radius, Color(0.5, 0.8, 1.0, pulse))
		draw_arc(Vector2.ZERO, frost_radius, 0.0, TAU, 64, Color(0.6, 0.9, 1.0, 0.35), 2.0)

	var wall := Color(0.62, 0.6, 0.56) if _flash <= 0.0 else Color(1, 0.7, 0.6)
	var dark := Color(0.35, 0.33, 0.3)
	# 影
	draw_rect(Rect2(-HALF + Vector2(0, 10), HALF * 2.0), Color(0, 0, 0, 0.3))
	# 本体
	draw_rect(Rect2(-HALF, HALF * 2.0), wall)
	draw_rect(Rect2(-HALF, HALF * 2.0), dark, false, 3.0)
	# 胸壁（ギザギザ）
	var bw := 16.0
	var x := -HALF.x
	while x < HALF.x - 1.0:
		draw_rect(Rect2(Vector2(x, -HALF.y - 10.0), Vector2(bw * 0.6, 10.0)), wall)
		x += bw
	# 門
	draw_rect(Rect2(Vector2(-18, HALF.y - 40.0), Vector2(36, 40)), Color(0.3, 0.2, 0.12))
	draw_circle(Vector2(0, HALF.y - 40.0), 18.0, Color(0.3, 0.2, 0.12))
	# 旗
	draw_line(Vector2(0, -HALF.y - 10.0), Vector2(0, -HALF.y - 50.0), dark, 3.0)
	var wave := sin(_t * 4.0) * 3.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -HALF.y - 50.0), Vector2(26, -HALF.y - 44.0 + wave), Vector2(0, -HALF.y - 36.0)]), Color(0.3, 0.55, 1.0))

	# 矢倉
	for i in tower_count:
		var p := _tower_local_pos(i)
		draw_rect(Rect2(p - Vector2(13, 13), Vector2(26, 26)), Color(0.55, 0.4, 0.25))
		draw_rect(Rect2(p - Vector2(13, 13), Vector2(26, 26)), Color(0.3, 0.2, 0.1), false, 2.0)
		var aim: Vector2 = _tower_aims[i]
		draw_line(p, p + aim * 18.0, Color(0.25, 0.15, 0.08), 4.0)

	# 大砲
	for i in mini(cannon_level, MAX_GUNS):
		var cp := _cannon_local_pos(i)
		var aim: Vector2 = _cannon_aims[i]
		draw_circle(cp, 14.0, Color(0.25, 0.25, 0.28))
		draw_line(cp, cp + aim * 26.0, Color(0.15, 0.15, 0.18), 10.0)

	# バリスタ
	for i in mini(ballista_level, MAX_GUNS):
		var p := _ballista_local_pos(i)
		var aim: Vector2 = _ballista_aims[i]
		var side := aim.orthogonal()
		var back: float = 4.0 if _ballista_recoil[i] > 0.0 else 0.0
		var c := p - aim * back
		draw_circle(p, 9.0, Color(0.4, 0.3, 0.2))
		# 弓の部分
		draw_line(c + side * 14.0 - aim * 4.0, c + aim * 6.0, Color(0.55, 0.4, 0.2), 4.0)
		draw_line(c - side * 14.0 - aim * 4.0, c + aim * 6.0, Color(0.55, 0.4, 0.2), 4.0)
		draw_line(c + side * 14.0 - aim * 4.0, c - aim * 8.0, Color(0.9, 0.9, 0.85), 1.5)
		draw_line(c - side * 14.0 - aim * 4.0, c - aim * 8.0, Color(0.9, 0.9, 0.85), 1.5)
		# 台座のレール
		draw_line(c - aim * 12.0, c + aim * 16.0, Color(0.3, 0.2, 0.1), 5.0)

	# 投石器
	for i in mini(catapult_level, MAX_GUNS):
		var p := _catapult_local_pos(i)
		var wood := Color(0.5, 0.35, 0.2)
		draw_rect(Rect2(p + Vector2(-16, 4), Vector2(32, 8)), wood)
		draw_line(p + Vector2(-10, 6), p + Vector2(0, -8), wood, 3.0)
		draw_line(p + Vector2(10, 6), p + Vector2(0, -8), wood, 3.0)
		var swinging: bool = _catapult_swings[i] > 0.0
		var arm_ang := -2.2 if swinging else -0.5
		var arm_end := p + Vector2(0, -8) + Vector2.from_angle(arm_ang) * 26.0
		draw_line(p + Vector2(0, -8), arm_end, Color(0.4, 0.28, 0.15), 4.0)
		if not swinging:
			draw_circle(arm_end, 6.0, Color(0.45, 0.42, 0.4))

	# HPバー（城の下）
	var w := HALF.x * 2.0
	var top := Vector2(-HALF.x, HALF.y + 8.0)
	draw_rect(Rect2(top, Vector2(w, 8)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(w * hp / max_hp, 8)), Color(1.0, 0.6, 0.2))
