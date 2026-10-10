extends Node2D
## 主人公の兵士。移動も攻撃もすべて自動。
## 射撃 = 点の攻撃（遠くの単体）、剣 = 面の攻撃（近くの扇形範囲）

signal died

const BulletScript := preload("res://scripts/bullet.gd")
const SlashScript := preload("res://scripts/slash_effect.gd")

var game: Node2D
var radius := 16.0
var dead := false

# --- 基本ステータス
var max_hp := 100.0
var hp := 100.0
var move_speed := 170.0
var regen := 0.0

# --- 射撃
var shot_count := 1
var fire_interval := 0.55
var bullet_damage := 10.0
var bullet_speed := 680.0
var bullet_pierce := 0
var fire_range := 540.0

# --- 剣
var sword_damage := 16.0
var sword_radius := 90.0
var sword_arc := deg_to_rad(150.0)
var sword_interval := 0.75

# --- 突進突き（強化で解放）
var dash_level := 0
var dash_interval := 4.0
var dash_damage := 40.0
const DASH_SPEED := 1000.0
const DASH_DURATION := 0.28

var velocity := Vector2.ZERO
var aim_dir := Vector2.RIGHT

var _fire_cd := 0.0
var _sword_cd := 0.0
var _dash_cd := 1.5
var _dash_time := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_hit := {}
var _hurt_flash := 0.0
var _invuln := 0.0
var _wander_target := Vector2.ZERO
var _wander_cd := 0.0
var _strafe_sign := 1.0
var _strafe_cd := 2.0


func _process(delta: float) -> void:
	if dead:
		return
	_fire_cd -= delta
	_sword_cd -= delta
	_dash_cd -= delta
	_hurt_flash -= delta
	_invuln -= delta
	if regen > 0.0:
		hp = minf(max_hp, hp + regen * delta)

	if _dash_time > 0.0:
		_update_dash(delta)
	else:
		var dir := _compute_move_dir(delta)
		velocity = velocity.lerp(dir * move_speed, clampf(8.0 * delta, 0.0, 1.0))
		position += velocity * delta
	position = game.clamp_to_map(position, radius)

	var target: Node2D = _nearest_enemy(fire_range)
	if target != null:
		aim_dir = (target.global_position - global_position).normalized()
		if _fire_cd <= 0.0:
			_shoot()
			_fire_cd = fire_interval
	if _sword_cd <= 0.0 and _try_slash():
		_sword_cd = sword_interval
	if dash_level > 0 and _dash_cd <= 0.0 and _dash_time <= 0.0:
		_try_dash()
	queue_redraw()


# ---------------------------------------------------------------- 自動移動AI

func _compute_move_dir(delta: float) -> Vector2:
	var dir := Vector2.ZERO
	var nearest: Node2D = null
	var nearest_d := INF
	const DANGER := 210.0

	# 近い敵から離れる（囲まれないように）
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		var d := to.length()
		if d < nearest_d:
			nearest_d = d
			nearest = e
		if d < DANGER and d > 0.01:
			var w := pow((DANGER - d) / DANGER, 2.0) * (2.0 if e.kind == "brute" else 1.0)
			dir -= to / d * w * 2.0

	# 飛んでくる弾をよける
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		var rel: Vector2 = global_position - b.global_position
		if rel.length() > 170.0:
			continue
		var vn: Vector2 = b.velocity.normalized()
		var ahead := rel.dot(vn)
		if ahead <= 0.0:
			continue
		var perp := rel - vn * ahead
		if perp.length() < 45.0:
			var side := perp.normalized() if perp.length() > 1.0 else vn.orthogonal()
			dir += side * 1.8

	# 囲まれ気味なら、敵が一番薄い方向を探して脱出する
	if _count_near(DANGER) >= 3:
		dir += _find_escape_dir() * 2.5

	if nearest != null and nearest_d < 700.0:
		var to_n := (nearest.global_position - global_position).normalized()
		if nearest_d > 330.0:
			# 遠い敵には射程まで近づく
			dir += to_n * 0.8
		else:
			# 程よい距離では横に回り込む
			_strafe_cd -= delta
			if _strafe_cd <= 0.0:
				_strafe_cd = randf_range(1.5, 3.5)
				_strafe_sign = -_strafe_sign
			dir += to_n.orthogonal() * 0.35 * _strafe_sign
	else:
		# 敵がいないときはうろうろ探索
		_wander_cd -= delta
		if _wander_cd <= 0.0 or global_position.distance_to(_wander_target) < 40.0:
			_wander_cd = 3.0
			_wander_target = game.clamp_to_map(global_position + Vector2.from_angle(randf() * TAU) * 400.0, 200.0)
		dir += (_wander_target - global_position).normalized() * 0.6

	# 壁から離れる
	var rect: Rect2 = game.MAP_RECT
	const WALL := 260.0
	var p := global_position
	if p.x - rect.position.x < WALL:
		dir.x += (WALL - (p.x - rect.position.x)) / WALL * 2.5
	if rect.end.x - p.x < WALL:
		dir.x -= (WALL - (rect.end.x - p.x)) / WALL * 2.5
	if p.y - rect.position.y < WALL:
		dir.y += (WALL - (p.y - rect.position.y)) / WALL * 2.5
	if rect.end.y - p.y < WALL:
		dir.y -= (WALL - (rect.end.y - p.y)) / WALL * 2.5

	if dir.length() < 0.05:
		return Vector2.ZERO
	return dir.normalized()


func _count_near(dist: float) -> int:
	var n := 0
	for e in game.enemies_near(global_position, dist):
		if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < dist:
			n += 1
	return n


## 16方向を調べて、敵が少なく壁から遠い方向を返す
func _find_escape_dir() -> Vector2:
	const LOOK := 320.0
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
		var probe := global_position + cand * 250.0
		if not rect.grow(-60.0).has_point(probe):
			cost += 3.0
		if cost < best_cost:
			best_cost = cost
			best_dir = cand
	return best_dir


func _nearest_enemy(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = global_position.distance_to(e.global_position) - e.radius
		if d < best_d:
			best_d = d
			best = e
	return best


# ---------------------------------------------------------------- 射撃（点）

func _shoot() -> void:
	const SPREAD := 0.13
	var base := aim_dir.angle() - SPREAD * (shot_count - 1) / 2.0
	for i in shot_count:
		var b := BulletScript.new()
		b.game = game
		b.velocity = Vector2.from_angle(base + SPREAD * i) * bullet_speed
		b.damage = bullet_damage
		b.pierce = bullet_pierce
		b.radius = 5.0
		b.color = Color(1.0, 0.92, 0.4)
		b.life = fire_range / bullet_speed + 0.2
		b.position = global_position + aim_dir * (radius + 8.0)
		game.world.add_child(b)


# ---------------------------------------------------------------- 剣（面）

func _try_slash() -> bool:
	var target: Node2D = _nearest_enemy(sword_radius)
	if target == null:
		return false
	var facing := (target.global_position - global_position).normalized()
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > sword_radius + e.radius:
			continue
		if sword_arc < TAU and absf(facing.angle_to(to)) > sword_arc / 2.0 + 0.2:
			continue
		e.take_damage(sword_damage, to.normalized() * 380.0)
	# 斬撃で敵の弾もかき消す
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		var to_b: Vector2 = b.global_position - global_position
		if to_b.length() <= sword_radius and (sword_arc >= TAU or absf(facing.angle_to(to_b)) <= sword_arc / 2.0):
			b.queue_free()
	var fx := SlashScript.new()
	fx.radius = sword_radius
	fx.arc = sword_arc
	fx.rotation = facing.angle()
	fx.position = global_position
	game.effects.add_child(fx)
	return true


# ---------------------------------------------------------------- 突進突き

func _try_dash() -> void:
	var target: Node2D = _nearest_enemy(420.0)
	if target == null:
		return
	_dash_dir = (target.global_position - global_position).normalized()
	_dash_time = DASH_DURATION
	_dash_hit.clear()
	_dash_cd = dash_interval
	_invuln = DASH_DURATION + 0.15


func _update_dash(delta: float) -> void:
	_dash_time -= delta
	position += _dash_dir * DASH_SPEED * delta
	velocity = _dash_dir * move_speed
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead or _dash_hit.has(e):
			continue
		if global_position.distance_to(e.global_position) < radius + e.radius + 18.0:
			_dash_hit[e] = true
			e.take_damage(dash_damage, _dash_dir * 500.0)


# ---------------------------------------------------------------- 被ダメージ

func take_damage(amount: float) -> void:
	if dead or _invuln > 0.0:
		return
	hp -= amount
	_hurt_flash = 0.15
	_invuln = 0.3
	game.spawn_damage_text(global_position, amount, Color(1.0, 0.35, 0.35))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		queue_redraw()
		died.emit()


# ---------------------------------------------------------------- 描画

func _draw() -> void:
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

	var body := Color(0.3, 0.55, 1.0)
	if dead:
		body = Color(0.3, 0.3, 0.35)
	elif _hurt_flash > 0.0:
		body = Color(1, 1, 1)
	draw_circle(Vector2.ZERO, radius, body)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.1, 0.2, 0.45), 2.5)
	# 銃
	draw_line(aim_dir * 4.0, aim_dir * (radius + 12.0), Color(0.15, 0.15, 0.18), 6.0)
	# 腰の剣
	var side := aim_dir.orthogonal()
	draw_line(side * 10.0 - aim_dir * 6.0, side * 10.0 + aim_dir * 16.0, Color(0.85, 0.88, 0.95), 3.0)
	# ヘルメット
	draw_circle(-aim_dir * 3.0, radius * 0.55, Color(0.25, 0.42, 0.25))
