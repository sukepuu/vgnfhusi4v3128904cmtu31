extends Node2D
## 迎撃部隊の兵士（盾＋槍）。城の近くに陣取って、近づく敵を迎え撃つ。
## 盾を向けている前方の狭い範囲からの攻撃はダメージが20%になる（大盾1レベルごとに-5%、最大で0%）。
## 槍はリーチが長いが、横の範囲はかなり狭い（直線上の敵をまとめて貫く）。
## ステータスは game.guard_stats を全員で共有している。

const BulletScript := preload("res://scripts/bullet.gd")
const GoldenShieldScript := preload("res://scripts/golden_shield.gd")
## 黄金の盾を飛ばす間隔（秒）
const GOLDEN_SHIELD_EVERY := 15.0

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
var _spike_cd := 2.0
var _giant_cd := 4.0
var _golden_cd := 3.0
## 城へ飛んでくる敵の弾を受け止めに行っているとき、その弾
var block_bullet: Node2D = null


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
	_spear_cd -= delta * game.atk_speed_mult(record)
	_bash_cd -= delta
	_whirl_cd -= delta
	_spike_cd -= delta
	_giant_cd -= delta
	_golden_cd -= delta
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
		# 待機中：城へ飛んでくる敵の弾があれば、その通り道に立って盾で受け止める
		block_bullet = _incoming_bullet(castle_pos)
		if block_bullet != null:
			desired = _block_point(block_bullet, castle_pos)
		else:
			# 弾を受け止める必要もなければ、採掘場が空いていれば掘りに行く
			desired = game.mine_spot(self, desired)
	if _target_valid():
		block_bullet = null
	var to := desired - global_position
	if to.length() > 6.0:
		position += to.normalized() * minf(st.move_speed * game.mine_speed_mult(self) * delta, to.length())
	# 仲間の迎撃部隊と重ならないように
	for g in game.guards:
		if g == self or g.dead:
			continue
		var rel: Vector2 = global_position - g.global_position
		if rel.length() < 36.0 and rel.length() > 0.01:
			position += rel.normalized() * (36.0 - rel.length()) * 0.5
	position = game.clamp_to_map(position, radius)

	# 盾を向ける方向：一番近い敵 → 狙っている敵 → 城の外側
	var look: Node2D = game.nearest_enemy(global_position, st.spear_reach + 80.0, true)
	if look == null and _target_valid():
		look = target
	var want: Vector2 = (look.global_position - global_position).normalized() if look != null else (global_position - castle_pos).normalized()
	if block_bullet != null and is_instance_valid(block_bullet):
		# 弾の方へ盾を向ける
		want = (block_bullet.global_position - global_position).normalized()
	facing = Vector2.from_angle(rotate_toward(facing.angle(), want.angle(), 7.0 * delta))

	# 大旋風槍
	if st.whirl and _whirl_cd <= 0.0 and game.nearest_enemy(global_position, st.spear_reach, true) != null:
		_whirl_cd = 6.0
		game.explode(global_position, st.spear_reach * 1.2, st.spear_damage * 3.0, game.sp_src(record, "sp_whirl_spear"), Color(0.7, 1.0, 0.7), 0.0, 320.0)
		game.spawn_burst(global_position, Color(1, 1, 1), st.spear_reach / 1.8)
	# 拒馬の柵：敵が近いとき、盾の前に柵を置く
	# 黄金の盾：15秒ごとに、今向いている方向へ黄金の盾を飛ばす
	if st.reflect and _golden_cd <= 0.0:
		_golden_cd = GOLDEN_SHIELD_EVERY
		_throw_golden_shield()
	# 神槍投擲：一番近い敵の方へ、ゆっくり進む巨大な槍を投げる
	if st.giant_spear and _giant_cd <= 0.0:
		var t: Node2D = game.nearest_enemy(global_position, 900.0, true)
		if t != null:
			_giant_cd = 8.0
			var dir: Vector2 = (t.global_position - global_position).normalized()
			var b := BulletScript.new()
			b.game = game
			b.velocity = dir * 230.0
			b.damage = st.spear_damage * 5.0
			b.pierce = 1000000
			b.radius = 26.0
			b.spear = true
			b.life = 5.0
			b.position = global_position + dir * 20.0
			b.src = game.sp_src(record, "sp_giant_spear")
			game.world.add_child(b)
	if st.spikes and _spike_cd <= 0.0 and game.nearest_enemy(global_position, 260.0, true) != null:
		_spike_cd = 8.0
		game.spawn_placed("spikes", global_position + facing * 70.0, st.spear_damage * 0.8, 33.0, 8.0, game.sp_src(record, "sp_spikes"))
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
		# 紫ひし形（archer）には反応しない（撃ってくる弾には盾を向ける）
		if not is_instance_valid(e) or e.dead or e.kind == "archer":
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


## 黄金の盾：今向いている方向へ、ゆっくり進む大きな黄金の盾を飛ばす
func _throw_golden_shield() -> void:
	var gs := GoldenShieldScript.new()
	gs.game = game
	gs.dir = facing
	gs.half_arc = game.guard_stats.shield_arc / 2.0
	gs.damage = game.guard_stats.spear_damage * 5.0
	gs.src = game.sp_src(record, "sp_fun_reflect")
	gs.position = global_position + facing * 20.0
	game.world.add_child(gs)


## 城に当たりそうな敵の弾のうち、城に一番近いもの（ほかの迎撃兵が受け止めに行っている弾は除く）
func _incoming_bullet(castle_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 520.0
	var half: Vector2 = game.castle.HALF
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		var taken := false
		for g in game.guards:
			if g != self and not g.dead and g.block_bullet == b:
				taken = true
		if taken:
			continue
		var vn: Vector2 = b.velocity.normalized()
		var rel: Vector2 = castle_pos - b.global_position
		# 城の方へ向かっていて、そのまま進めば城に当たる弾だけ
		if rel.dot(vn) <= 0.0 or absf(rel.dot(vn.orthogonal())) > half.x + 10.0:
			continue
		var d := rel.length()
		if d < best_d:
			best_d = d
			best = b
	return best


## 弾の通り道の、城の少し手前の地点（まだ弾が通り過ぎていない所）
func _block_point(b: Node2D, castle_pos: Vector2) -> Vector2:
	var vn: Vector2 = b.velocity.normalized()
	var along := (castle_pos - b.global_position).dot(vn)
	var p: Vector2 = b.global_position + vn * maxf(along - 120.0, 30.0)
	return p


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
	# 紫ひし形（archer）だけなら突かない（ほかの敵を突いたときに一緒に当たるのはそのまま）
	if hits.is_empty() or hits.keys().all(func(h) -> bool: return h.kind == "archer"):
		return false
	for e in hits:
		# 捨て身の構え：突いた敵が爆発
		if st.berserk:
			game.explode(e.global_position, 70.0, st.spear_damage * 3.0, game.sp_src(record, "sp_berserk_guard"), Color(1.0, 0.45, 0.3), 0.0, 260.0)
		# 三叉槍で増えた向きの槍も、ふつうの突きなので通常攻撃として数える
		e.take_damage(st.spear_damage, hits[e] * 260.0, record)
	_thrust = 0.18
	return true


## from_pos = 攻撃が来た場所。盾の範囲内からならダメージを減らす（大盾が最大なら完全に防ぐ）
func take_damage(amount: float, from_pos: Vector2 = Vector2.INF) -> void:
	if dead or _invuln > 0.0:
		return
	# 170overtime：Lv170からは敵のダメージ +（レベルの百の位）
	amount += game.overtime_dmg_bonus()
	# 5分までは、城と同じく受けるダメージが半分（設置物は半分にならない）
	amount *= game.early_damage_mult()
	var blocked := false
	if from_pos != Vector2.INF:
		var dir := (from_pos - global_position).normalized()
		if absf(facing.angle_to(dir)) <= game.guard_stats.shield_arc / 2.0:
			_block_flash = 0.15
			# 盾で受けるとダメージは20%（大盾で減っていき、最大で0%。捨て身の構えなら50%）
			var taken_ratio: float = 0.5 if game.guard_stats.berserk else game.guard_stats.shield_taken
			record["blocked"] += amount * (1.0 - taken_ratio)
			# 盾撃：防いだ瞬間に周りへ衝撃波
			var bash: int = game.guard_stats.bash_level
			if bash > 0 and _bash_cd <= 0.0:
				_bash_cd = 0.4
				game.explode(global_position, 60.0 + 20.0 * bash, game.guard_stats.spear_damage * (0.7 + 0.3 * bash), game.sp_src(record, "sp_bash"), Color(0.7, 1.0, 0.6), 0.0, 320.0)
			amount *= taken_ratio
			blocked = true
			# 完全に防いだら、ダメージの数字は出さない
			if amount <= 0.0:
				return
	record["taken"] += minf(amount, hp)
	game.note_taken("guard", minf(amount, hp))
	hp -= amount
	_hurt_flash = 0.15
	# 盾で受けたときは無敵時間なし（続けて来る弾も盾で受け止められるように）
	if not blocked:
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
