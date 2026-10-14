extends Node2D
## 遊撃部隊の兵士。移動も攻撃もすべて自動。
## 常に自分から一番近い敵を倒しに行く。
## 射撃 = 点の攻撃（遠くの単体）、剣 = 面の攻撃（近くの扇形範囲）
## ステータスは game.stats を全員で共有している。

const BulletScript := preload("res://scripts/bullet.gd")
const SlashScript := preload("res://scripts/slash_effect.gd")

const RESPAWN_TIME := 10.0
const DASH_SPEED := 1000.0
const DASH_DURATION := 0.28
const HELMET_COLORS := [
	Color(0.25, 0.42, 0.25), Color(0.6, 0.25, 0.25), Color(0.55, 0.45, 0.15),
	Color(0.35, 0.3, 0.6), Color(0.2, 0.5, 0.55)]

var game: Node2D
var index := 0
var radius := 16.0
var hp := 80.0
var dead := false
var respawn_left := 0.0

var velocity := Vector2.ZERO
var aim_dir := Vector2.UP
var target: Node2D = null
var record: Dictionary

var _fire_cd := 0.0
var _sword_cd := 0.0
var _dash_cd := 1.5
var _dash_time := 0.0
var _dash_dir := Vector2.UP
var _dash_hit := {}
var _hurt_flash := 0.0
var _invuln := 0.0
var _retarget_cd := 0.0
var _volley_cd := 3.0
var _last_kills := 0
## 触爆：同じ敵を何度も爆発させないための待ち時間
var _touch_cd := {}
var _boomerang_cd := 2.0
var _strafe_sign := 1.0
var _strafe_cd := 2.0


func _ready() -> void:
	record = game.new_record("soldier", "遊撃兵%d" % (index + 1))
	hp = game.stats.max_hp
	_strafe_sign = 1.0 if index % 2 == 0 else -1.0


func _process(delta: float) -> void:
	if dead:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_respawn()
		queue_redraw()
		return
	var st = game.stats
	_fire_cd -= delta
	_volley_cd -= delta
	_boomerang_cd -= delta
	if st.touch_blast:
		_touch_blast(st, delta)
	# 勝利の花火：敵を倒したら30%で花火を打ち上げる（弾けた所に小ダメージ）
	if st.fireworks and record["kills"] > _last_kills and randf() < 0.3:
		var f: Node2D = game.spawn_fun_fx("firework", global_position)
		f.end = global_position + Vector2(randf_range(-60, 60), randf_range(-160, -110))
		f.rise_time = 0.6
		f.damage = st.sword_damage * 0.4
		f.radius = 70.0
		f.src = game.sp_src(record, "sp_fun_fireworks")
	_last_kills = record["kills"]
	_sword_cd -= delta
	_dash_cd -= delta
	_hurt_flash -= delta
	_invuln -= delta
	_retarget_cd -= delta
	# 兵士は少しずつ自然回復
	hp = minf(st.max_hp, hp + 1.5 * delta)
	if _retarget_cd <= 0.0 or not _target_valid():
		target = _choose_target()
		_retarget_cd = 0.2

	if _dash_time > 0.0:
		_update_dash(delta)
	else:
		var dir := _compute_move_dir(delta)
		velocity = velocity.lerp(dir * st.move_speed, clampf(8.0 * delta, 0.0, 1.0))
		position += velocity * delta
	position = game.clamp_to_map(position, radius)
	_push_out_of_castle()

	# 狙っている敵が射程内ならそれを、いなければ一番近い敵を撃つ
	var shoot_at: Node2D = null
	if _target_valid() and global_position.distance_to(target.global_position) < st.fire_range:
		shoot_at = target
	else:
		shoot_at = game.nearest_enemy(global_position, st.fire_range)
	if shoot_at != null:
		aim_dir = (shoot_at.global_position - global_position).normalized()
		if _fire_cd <= 0.0:
			_shoot()
			_fire_cd = st.fire_interval
	if st.volley_level > 0 and _volley_cd <= 0.0 and game.nearest_enemy(global_position, 500.0) != null:
		_volley()
		_volley_cd = 6.0
	# ブーメラン：狙っている敵の方へ投げる（行きと帰りで貫く）
	if st.boomerang and _boomerang_cd <= 0.0 and shoot_at != null:
		_boomerang_cd = 3.5
		var m: Node2D = game.spawn_missile("boomerang", global_position, aim_dir * 750.0, st.sword_damage * 1.3, 32.0, 4.0, game.sp_src(record, "sp_boomerang"))
		m.thrower = self
	if _sword_cd <= 0.0 and _try_slash():
		_sword_cd = st.sword_interval
	if st.dash_level > 0 and _dash_cd <= 0.0 and _dash_time <= 0.0:
		_try_dash()
	queue_redraw()


## 触爆：体に触れた敵が爆発する（同じ敵は1秒に1回まで）
func _touch_blast(st, delta: float) -> void:
	for e in _touch_cd.keys():
		_touch_cd[e] -= delta
		if _touch_cd[e] <= 0.0 or not is_instance_valid(e):
			_touch_cd.erase(e)
	for e in game.enemies_near(global_position, radius + 40.0):
		if not is_instance_valid(e) or e.dead or _touch_cd.has(e):
			continue
		if global_position.distance_to(e.global_position) < radius + e.radius + 4.0:
			_touch_cd[e] = 1.0
			game.explode(e.global_position, 75.0, st.bullet_damage * 3.0, game.sp_src(record, "sp_touch_blast"), Color(1.0, 0.5, 0.2), 0.0, 260.0)


# ---------------------------------------------------------------- 狙う敵を決める

func _target_valid() -> bool:
	return target != null and is_instance_valid(target) and not target.dead


## 常に自分から一番近い敵を狙う
func _choose_target() -> Node2D:
	# 魔王狩り：ボスがいれば一番近いボスを狙う
	if game.stats.boss_hunt:
		var b: Node2D = game.nearest_boss(global_position)
		if b != null:
			return b
	return game.nearest_enemy(global_position, INF)


# ---------------------------------------------------------------- 自動移動AI

func _compute_move_dir(delta: float) -> Vector2:
	var dir := Vector2.ZERO
	const DANGER := 150.0

	# 近すぎる敵からは少し離れる（囲まれないように）
	for e in game.enemies_near(global_position, DANGER):
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		var d := to.length()
		if d < DANGER and d > 0.01:
			var w := pow((DANGER - d) / DANGER, 2.0) * (2.0 if e.kind == "brute" else 1.0)
			dir -= to / d * w * 2.0

	# 飛んでくる弾をよける
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		var rel: Vector2 = global_position - b.global_position
		if rel.length() > 160.0:
			continue
		var vn: Vector2 = b.velocity.normalized()
		var ahead := rel.dot(vn)
		if ahead <= 0.0:
			continue
		var perp := rel - vn * ahead
		if perp.length() < 40.0:
			var side := perp.normalized() if perp.length() > 1.0 else vn.orthogonal()
			dir += side * 1.6

	# 囲まれ気味なら、敵が一番薄い方向を探して脱出する
	if _count_near(DANGER) >= 4:
		dir += _find_escape_dir() * 2.5

	if _target_valid():
		var to_t := target.global_position - global_position
		var d := to_t.length()
		var to_n := to_t / maxf(d, 0.001)
		if d > 220.0:
			# 遠い敵には近づく
			dir += to_n
		else:
			# 程よい距離では横に回り込む
			_strafe_cd -= delta
			if _strafe_cd <= 0.0:
				_strafe_cd = randf_range(1.5, 3.5)
				_strafe_sign = -_strafe_sign
			dir += to_n.orthogonal() * 0.35 * _strafe_sign + to_n * 0.25
	else:
		# 敵がいないときは城の前で待機
		var home: Vector2 = game.castle.gate_position() + Vector2((index - 2) * 90.0, -110.0)
		var to_home := home - global_position
		if to_home.length() > 20.0:
			dir += to_home.normalized() * minf(to_home.length() / 80.0, 1.0)

	# 兵士同士が固まらないように
	for s in game.soldiers:
		if s == self or s.dead:
			continue
		var rel: Vector2 = global_position - s.global_position
		var d := rel.length()
		if d < 70.0 and d > 0.01:
			dir += rel / d * (70.0 - d) / 70.0 * 1.2

	# 壁から離れる
	var rect: Rect2 = game.MAP_RECT
	const WALL := 120.0
	var p := global_position
	if p.x - rect.position.x < WALL:
		dir.x += (WALL - (p.x - rect.position.x)) / WALL * 2.0
	if rect.end.x - p.x < WALL:
		dir.x -= (WALL - (rect.end.x - p.x)) / WALL * 2.0
	if p.y - rect.position.y < WALL:
		dir.y += (WALL - (p.y - rect.position.y)) / WALL * 2.0

	if dir.length() < 0.05:
		return Vector2.ZERO
	return dir.normalized()


func _push_out_of_castle() -> void:
	var r: Rect2 = game.castle.body_rect().grow(radius)
	if r.has_point(position):
		position.y = r.position.y


func _count_near(dist: float) -> int:
	var n := 0
	for e in game.enemies_near(global_position, dist):
		if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < dist:
			n += 1
	return n


## 16方向を調べて、敵が少なく壁から遠い方向を返す
func _find_escape_dir() -> Vector2:
	const LOOK := 300.0
	var nearby: Array = game.enemies_near(global_position, LOOK)
	var best_dir := Vector2.ZERO
	var best_cost := INF
	var rect: Rect2 = game.MAP_RECT
	for i in 16:
		var cand := Vector2.from_angle(TAU * i / 16.0)
		var cost := 0.0
		for e in nearby:
			if not is_instance_valid(e) or e.dead:
				continue
			var to: Vector2 = e.global_position - global_position
			var d := to.length()
			if d > LOOK or d < 0.01:
				continue
			cost += maxf(0.0, cand.dot(to / d)) * (LOOK - d) / LOOK
		var probe := global_position + cand * 200.0
		if not rect.grow(-40.0).has_point(probe):
			cost += 3.0
		if cost < best_cost:
			best_cost = cost
			best_dir = cand
	return best_dir


# ---------------------------------------------------------------- 射撃（点）

func _shoot() -> void:
	var st = game.stats
	const SPREAD := 0.13
	var base: float = aim_dir.angle() - SPREAD * (st.shot_count - 1) / 2.0
	for i in st.shot_count:
		var b := BulletScript.new()
		b.game = game
		b.velocity = Vector2.from_angle(base + SPREAD * i) * st.bullet_speed
		b.damage = st.bullet_damage
		b.pierce = st.bullet_pierce
		b.radius = 5.0
		b.color = Color(1.0, 0.92, 0.4)
		b.life = st.fire_range / st.bullet_speed + 0.2
		b.position = global_position + aim_dir * (radius + 8.0)
		b.src = record
		if st.burst_level > 0:
			b.explode_radius = 30.0 + 15.0 * st.burst_level
			b.explode_ratio = 0.25 + 0.15 * st.burst_level
			b.explode_src = game.sp_src(record, "sp_burst")
		game.world.add_child(b)
	# 影分身：横の分身からも同じ弾を撃つ（威力50%）
	if st.shadow:
		var from := global_position + _shadow_offset()
		for k in st.shot_count:
			var sb := BulletScript.new()
			sb.game = game
			sb.velocity = Vector2.from_angle(base + SPREAD * k) * st.bullet_speed
			sb.damage = st.bullet_damage * 0.5
			sb.pierce = st.bullet_pierce
			sb.radius = 5.0
			sb.color = Color(0.7, 0.75, 1.0)
			sb.life = st.fire_range / st.bullet_speed + 0.2
			sb.position = from + aim_dir * 10.0
			sb.src = game.sp_src(record, "sp_shadow")
			game.world.add_child(sb)


func _shadow_offset() -> Vector2:
	return aim_dir.orthogonal() * 34.0


## 一斉射撃：全方位へ弾をばらまく
func _volley() -> void:
	var st = game.stats
	var count: int = 6 + 6 * st.volley_level
	for i in count:
		var dir := Vector2.from_angle(TAU * i / count)
		var b := BulletScript.new()
		b.game = game
		b.velocity = dir * st.bullet_speed
		b.damage = st.bullet_damage
		b.pierce = st.bullet_pierce
		b.radius = 5.0
		b.color = Color(1.0, 0.75, 0.3)
		b.life = st.fire_range / st.bullet_speed + 0.2
		b.position = global_position + dir * (radius + 6.0)
		b.src = game.sp_src(record, "sp_volley")
		game.world.add_child(b)


# ---------------------------------------------------------------- 剣（面）

func _try_slash() -> bool:
	var st = game.stats
	var near: Node2D = game.nearest_enemy(global_position, st.sword_radius)
	if near == null:
		return false
	var facing := (near.global_position - global_position).normalized()
	for e in game.enemies_near(global_position, st.sword_radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > st.sword_radius + e.radius:
			continue
		if st.sword_arc < TAU and absf(facing.angle_to(to)) > st.sword_arc / 2.0 + 0.2:
			continue
		e.take_damage(st.sword_damage, to.normalized() * 380.0, record)
	# 斬撃で敵の弾もかき消す
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		var to_b: Vector2 = b.global_position - global_position
		if to_b.length() <= st.sword_radius and (st.sword_arc >= TAU or absf(facing.angle_to(to_b)) <= st.sword_arc / 2.0):
			b.queue_free()
	if st.sword_wave:
		# 剣気：敵を貫く三日月形の衝撃波
		var w := BulletScript.new()
		w.game = game
		# 大きな三日月がゆっくり進む（届く距離は前と同じ）
		w.velocity = facing * 260.0
		w.damage = st.sword_damage
		w.pierce = 1000000
		w.radius = 32.0
		w.wave = true
		w.color = Color(0.75, 0.9, 1.0)
		w.life = 1.5
		w.position = global_position + facing * 20.0
		w.src = game.sp_src(record, "sp_sword_wave")
		game.world.add_child(w)
	var fx := SlashScript.new()
	fx.radius = st.sword_radius
	fx.arc = st.sword_arc
	fx.rotation = facing.angle()
	fx.position = global_position
	game.effects.add_child(fx)
	return true


# ---------------------------------------------------------------- 突進突き

func _try_dash() -> void:
	var t: Node2D = target if _target_valid() and global_position.distance_to(target.global_position) < 400.0 else game.nearest_enemy(global_position, 400.0)
	if t == null:
		return
	_dash_dir = (t.global_position - global_position).normalized()
	_dash_time = DASH_DURATION
	_dash_hit.clear()
	_dash_cd = game.stats.dash_interval
	_invuln = DASH_DURATION + 0.15


func _update_dash(delta: float) -> void:
	_dash_time -= delta
	position += _dash_dir * DASH_SPEED * delta
	velocity = _dash_dir * game.stats.move_speed
	for e in game.enemies_near(global_position, radius + 50.0):
		if not is_instance_valid(e) or e.dead or _dash_hit.has(e):
			continue
		if global_position.distance_to(e.global_position) < radius + e.radius + 18.0:
			_dash_hit[e] = true
			e.take_damage(game.stats.dash_damage, _dash_dir * 500.0, record)


# ---------------------------------------------------------------- 被ダメージ・復活

func take_damage(amount: float, _from_pos: Vector2 = Vector2.INF) -> void:
	if dead or _invuln > 0.0:
		return
	record["taken"] += minf(amount, hp)
	hp -= amount
	_hurt_flash = 0.15
	_invuln = 0.3
	game.spawn_damage_text(global_position, amount, Color(1.0, 0.35, 0.35))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		target = null
		_dash_time = 0.0
		respawn_left = RESPAWN_TIME


func _respawn() -> void:
	dead = false
	hp = game.stats.max_hp
	position = game.castle.gate_position() + Vector2(randf_range(-40, 40), 0)
	velocity = Vector2.ZERO
	_invuln = 1.5
	game.spawn_burst(global_position, Color(0.5, 0.8, 1.0), 20.0)


# ---------------------------------------------------------------- 描画

func _draw() -> void:
	if dead:
		# 倒れた場所に復活までのカウント
		draw_circle(Vector2.ZERO, radius * 0.8, Color(0.3, 0.3, 0.35, 0.5))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-20, 6), str(ceili(respawn_left)), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(1, 1, 1, 0.8))
		return

	draw_circle(Vector2(0, 7), radius, Color(0, 0, 0, 0.3))
	if _dash_time > 0.0:
		# 突進の残像と槍
		for i in 4:
			draw_circle(-_dash_dir * (14.0 * (i + 1)), radius * (0.9 - i * 0.15), Color(0.5, 0.8, 1.0, 0.35 - i * 0.07))
		draw_line(_dash_dir * radius, _dash_dir * (radius + 42.0), Color(1.0, 0.95, 0.6), 5.0)
		draw_colored_polygon(PackedVector2Array([
			_dash_dir * (radius + 54.0),
			_dash_dir * (radius + 40.0) + _dash_dir.orthogonal() * 7.0,
			_dash_dir * (radius + 40.0) - _dash_dir.orthogonal() * 7.0]), Color(1.0, 0.95, 0.6))

	# 影分身
	if game.stats.shadow:
		var so := _shadow_offset()
		draw_circle(so, radius * 0.9, Color(0.5, 0.55, 0.9, 0.35))
		draw_line(so + aim_dir * 4.0, so + aim_dir * (radius + 10.0), Color(0.2, 0.2, 0.3, 0.4), 5.0)
	var body := Color(0.3, 0.55, 1.0)
	if _hurt_flash > 0.0:
		body = Color(1, 1, 1)
	elif _invuln > 0.3 and int(_invuln * 10.0) % 2 == 0:
		body = Color(0.6, 0.8, 1.0)
	draw_circle(Vector2.ZERO, radius, body)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.1, 0.2, 0.45), 2.5)
	# 銃
	draw_line(aim_dir * 4.0, aim_dir * (radius + 12.0), Color(0.15, 0.15, 0.18), 6.0)
	# 腰の剣
	var side := aim_dir.orthogonal()
	draw_line(side * 10.0 - aim_dir * 6.0, side * 10.0 + aim_dir * 16.0, Color(0.85, 0.88, 0.95), 3.0)
	# ヘルメット（兵士ごとに色違い）
	draw_circle(-aim_dir * 3.0, radius * 0.55, HELMET_COLORS[index % HELMET_COLORS.size()])
	# HPバー
	var max_hp: float = game.stats.max_hp
	if hp < max_hp:
		var w := radius * 2.2
		var top := Vector2(-w / 2.0, -radius - 10.0)
		draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * hp / max_hp, 4)), Color(0.3, 0.9, 0.4))
