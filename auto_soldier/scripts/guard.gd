extends Node2D
## 迎撃部隊の兵士（盾＋槍）。城の近くに陣取って、近づく敵を迎え撃つ。
## 盾を向けている前方の狭い範囲からの攻撃は完全に無効。
## 槍はリーチが長いが、横の範囲はかなり狭い（直線上の敵をまとめて貫く）。
## ステータスは game.guard_stats を全員で共有している。

const RESPAWN_TIME := 12.0
## 城の中心からどこまで離れて戦うか
const LEASH := 185.0
const MIN_DIST := 115.0
## 城の中心からどの距離の敵に反応するか
const ALERT := 380.0

var game: Node2D
var index := 0
var radius := 16.0
var hp := 120.0
var dead := false
var respawn_left := 0.0
var facing := Vector2.UP
var target: Node2D = null
var record: Dictionary

var _spear_cd := 0.0
var _thrust := 0.0
var _hurt_flash := 0.0
var _block_flash := 0.0
var _invuln := 0.0
var _retarget_cd := 0.0
var _bash_cd := 0.0
var _whirl_cd := 3.0


func _ready() -> void:
	record = game.new_record("guard", "迎撃兵%d" % (index + 1))
	hp = game.guard_stats.max_hp


func _process(delta: float) -> void:
	if dead:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_respawn()
		queue_redraw()
		return
	var st = game.guard_stats
	var castle_pos: Vector2 = game.castle.global_position
	_spear_cd -= delta
	_bash_cd -= delta
	_whirl_cd -= delta
	_thrust -= delta
	_hurt_flash -= delta
	_block_flash -= delta
	_invuln -= delta
	_retarget_cd -= delta
	hp = minf(st.max_hp, hp + 2.0 * delta)

	if _retarget_cd <= 0.0 or not _target_valid():
		target = _choose_target(castle_pos)
		_retarget_cd = 0.3

	# 立ち位置：城と敵の間。敵がいなければ持ち場
	var desired: Vector2
	if _target_valid():
		var dir: Vector2 = (target.global_position - castle_pos).normalized()
		var td: float = target.global_position.distance_to(castle_pos)
		desired = castle_pos + dir * clampf(td - st.spear_reach * 0.8, MIN_DIST, LEASH)
	else:
		desired = _post_position(castle_pos)
	var to := desired - global_position
	if to.length() > 6.0:
		position += to.normalized() * minf(st.move_speed * delta, to.length())
	# 仲間の迎撃部隊と重ならないように
	for g in game.guards:
		if g == self or g.dead:
			continue
		var rel: Vector2 = global_position - g.global_position
		if rel.length() < 36.0 and rel.length() > 0.01:
			position += rel.normalized() * (36.0 - rel.length()) * 0.5
	position = game.clamp_to_map(position, radius)

	# 盾を向ける方向：一番近い敵 → 狙っている敵 → 城の外側
	var look: Node2D = game.nearest_enemy(global_position, st.spear_reach + 80.0)
	if look == null and _target_valid():
		look = target
	var want: Vector2 = (look.global_position - global_position).normalized() if look != null else (global_position - castle_pos).normalized()
	facing = Vector2.from_angle(rotate_toward(facing.angle(), want.angle(), 7.0 * delta))

	# 大旋風槍
	if st.whirl and _whirl_cd <= 0.0 and game.nearest_enemy(global_position, st.spear_reach) != null:
		_whirl_cd = 6.0
		game.explode(global_position, st.spear_reach * 1.2, st.spear_damage * 3.0, record, Color(0.7, 1.0, 0.7), 0.0, 320.0)
		game.spawn_burst(global_position, Color(1, 1, 1), st.spear_reach / 1.8)
	if _spear_cd <= 0.0 and _try_thrust():
		_spear_cd = st.spear_interval
	queue_redraw()


func _target_valid() -> bool:
	return target != null and is_instance_valid(target) and not target.dead


## 城に一番近い敵を狙う。ほかの迎撃部隊が狙っている敵は少し避ける
func _choose_target(castle_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = e.global_position.distance_to(castle_pos)
		if d > ALERT:
			continue
		var score := d + global_position.distance_to(e.global_position) * 0.3
		for g in game.guards:
			if g != self and not g.dead and g.target == e:
				score += 120.0
		if score < best_score:
			best_score = score
			best = e
	return best


## 敵がいないときの持ち場（城の上側に扇状に並ぶ）
func _post_position(castle_pos: Vector2) -> Vector2:
	var n: int = game.guards.size()
	var ang := PI + PI * (index + 1) / (n + 1)
	return castle_pos + Vector2.from_angle(ang) * 140.0


## 槍を突く向き（三叉槍なら3方向・5方向）
func _spear_dirs() -> Array:
	var dirs: Array = [facing]
	var lv: int = game.guard_stats.trident_level
	if lv >= 1:
		dirs.append(facing.rotated(0.45))
		dirs.append(facing.rotated(-0.45))
	if lv >= 2:
		dirs.append(facing.rotated(0.9))
		dirs.append(facing.rotated(-0.9))
	return dirs


## 槍で突く。前方の細長い範囲の敵すべてにダメージ
func _try_thrust() -> bool:
	var st = game.guard_stats
	var hits := {}
	for dir in _spear_dirs():
		var mid: Vector2 = global_position + dir * st.spear_reach / 2.0
		for e in game.enemies_near(mid, st.spear_reach / 2.0 + 30.0):
			if not is_instance_valid(e) or e.dead or hits.has(e):
				continue
			var rel: Vector2 = e.global_position - global_position
			var along: float = rel.dot(dir)
			var perp: float = absf(rel.dot(dir.orthogonal()))
			if along > 0.0 and along < st.spear_reach + e.radius and perp < st.spear_width + e.radius:
				hits[e] = dir
	if hits.is_empty():
		return false
	for e in hits:
		e.take_damage(st.spear_damage, hits[e] * 260.0, record)
	_thrust = 0.18
	return true


## from_pos = 攻撃が来た場所。盾の範囲内からなら完全に防ぐ
func take_damage(amount: float, from_pos: Vector2 = Vector2.INF) -> void:
	if dead or _invuln > 0.0:
		return
	if from_pos != Vector2.INF:
		var dir := (from_pos - global_position).normalized()
		if absf(facing.angle_to(dir)) <= game.guard_stats.shield_arc / 2.0:
			_block_flash = 0.15
			record["blocked"] += amount
			# 盾撃：防いだ瞬間に周りへ衝撃波
			var bash: int = game.guard_stats.bash_level
			if bash > 0 and _bash_cd <= 0.0:
				_bash_cd = 0.4
				game.explode(global_position, 60.0 + 20.0 * bash, game.guard_stats.spear_damage * (0.7 + 0.3 * bash), record, Color(0.7, 1.0, 0.6), 0.0, 320.0)
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


func _respawn() -> void:
	dead = false
	hp = game.guard_stats.max_hp
	position = game.castle.gate_position()
	_invuln = 1.5
	game.spawn_burst(global_position, Color(0.5, 1.0, 0.6), 20.0)


func _draw() -> void:
	if dead:
		draw_circle(Vector2.ZERO, radius * 0.8, Color(0.3, 0.35, 0.3, 0.5))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-20, 6), str(ceili(respawn_left)), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(1, 1, 1, 0.8))
		return
	var st = game.guard_stats
	var half: float = st.shield_arc / 2.0
	var fa := facing.angle()
	# 盾で守れる範囲（うっすら）
	draw_arc(Vector2.ZERO, radius + 30.0, fa - half, fa + half, 16, Color(0.6, 1.0, 0.7, 0.15), 24.0)

	draw_circle(Vector2(0, 7), radius, Color(0, 0, 0, 0.3))
	var body := Color(0.3, 0.7, 0.4)
	if _hurt_flash > 0.0:
		body = Color(1, 1, 1)
	draw_circle(Vector2.ZERO, radius, body)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.1, 0.3, 0.15), 2.5)
	draw_circle(-facing * 3.0, radius * 0.55, Color(0.55, 0.55, 0.6))

	# 槍（突いている間は伸びる）
	var side := facing.orthogonal() * 9.0
	var reach: float = st.spear_reach if _thrust > 0.0 else 34.0
	draw_line(side - facing * 8.0, side + facing * reach, Color(0.55, 0.4, 0.25), 3.0)
	var tip := side + facing * reach
	draw_colored_polygon(PackedVector2Array([
		tip + facing * 12.0, tip + facing.orthogonal() * 4.0, tip - facing.orthogonal() * 4.0]), Color(0.85, 0.88, 0.95))
	if _thrust > 0.0:
		draw_line(side + facing * 20.0, tip, Color(1, 1, 1, 0.5), st.spear_width)
		# 三叉槍：ほかの向きの突き
		for d in _spear_dirs().slice(1):
			draw_line(d * 20.0, d * st.spear_reach, Color(0.85, 0.88, 0.95, 0.7), 3.0)
			draw_line(d * 20.0, d * st.spear_reach, Color(1, 1, 1, 0.3), st.spear_width)

	# 盾
	var shield_col := Color(1.0, 1.0, 0.7) if _block_flash > 0.0 else Color(0.75, 0.6, 0.3)
	draw_arc(Vector2.ZERO, radius + 6.0, fa - half, fa + half, 12, shield_col, 7.0)
	draw_arc(Vector2.ZERO, radius + 6.0, fa - half, fa + half, 12, Color(0.35, 0.25, 0.1), 1.5)

	# HPバー
	if hp < st.max_hp:
		var w := radius * 2.2
		var top := Vector2(-w / 2.0, -radius - 12.0)
		draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * hp / st.max_hp, 4)), Color(0.3, 0.9, 0.4))
