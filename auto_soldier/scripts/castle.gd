extends Node2D
## 守るべき城。HPが0になったらゲームオーバー。
## 強化で迎撃システム（矢倉・大砲・投石器・氷結の結界）が増えていく。

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
var tower_damage := 12.0
var tower_range := 520.0
var _tower_cds: Array = [0.0, 0.3, 0.6, 0.15]
var _tower_aims: Array = [Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP]

# --- 大砲（範囲攻撃）
var cannon_level := 0
var cannon_interval := 4.0
var cannon_damage := 40.0
var cannon_radius := 90.0
var cannon_range := 650.0
var _cannon_cd := 1.0
var _cannon_aim := Vector2.UP

# --- 投石器（大砲より範囲が広いが、発射間隔が長い）
var catapult_level := 0
var catapult_interval := 9.0
var catapult_damage := 60.0
var catapult_radius := 150.0
var _catapult_cd := 2.0
var _catapult_swing := 0.0

# --- 氷結の結界（近くの敵を遅くする）
var frost_radius := 0.0
var frost_slow := 0.0

var _flash := 0.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	_flash -= delta
	if regen > 0.0:
		hp = minf(max_hp, hp + regen * delta)
	_update_towers(delta)
	_update_cannon(delta)
	_update_catapult(delta)
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
		var dir := (target.global_position - from).normalized()
		_tower_aims[i] = dir
		var b := BulletScript.new()
		b.game = game
		b.velocity = dir * 760.0
		b.damage = tower_damage
		b.radius = 4.0
		b.color = Color(0.95, 0.8, 0.55)
		b.life = tower_range / 760.0 + 0.2
		b.position = from
		game.world.add_child(b)
		_tower_cds[i] = tower_interval


func _update_cannon(delta: float) -> void:
	if cannon_level <= 0:
		return
	_cannon_cd -= delta
	if _cannon_cd > 0.0:
		return
	var best := _densest_enemy(cannon_range, cannon_radius)
	if best == null:
		return
	var from := global_position + Vector2(0, -HALF.y - 30.0)
	_cannon_aim = (best.global_position - from).normalized()
	var s := ShellScript.new()
	s.game = game
	s.start = from
	s.target = best.global_position
	s.damage = cannon_damage
	s.blast_radius = cannon_radius
	s.position = from
	game.effects.add_child(s)
	_cannon_cd = cannon_interval


func _update_catapult(delta: float) -> void:
	_catapult_swing -= delta
	if catapult_level <= 0:
		return
	_catapult_cd -= delta
	if _catapult_cd > 0.0:
		return
	var best := _densest_enemy(2000.0, catapult_radius)
	if best == null:
		return
	var from := global_position + _catapult_local_pos() + Vector2(0, -20)
	var s := ShellScript.new()
	s.game = game
	s.start = from
	s.target = best.global_position
	s.damage = catapult_damage
	s.blast_radius = catapult_radius
	s.boulder = true
	s.flight_time = 1.3
	s.position = from
	game.effects.add_child(s)
	_catapult_cd = catapult_interval
	_catapult_swing = 0.4


## 敵が一番密集している場所にいる敵（射程内）
func _densest_enemy(max_range: float, area: float) -> Node2D:
	var best: Node2D = null
	var best_score := 0
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		if global_position.distance_to(e.global_position) > max_range:
			continue
		var n: int = game.enemies_near(e.global_position, area).size()
		if n > best_score:
			best_score = n
			best = e
	return best


func _catapult_local_pos() -> Vector2:
	return Vector2(-HALF.x * 0.55, -HALF.y * 0.2)


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
	if cannon_level > 0:
		var cp := Vector2(0, -HALF.y - 30.0)
		draw_circle(cp, 14.0, Color(0.25, 0.25, 0.28))
		draw_line(cp, cp + _cannon_aim * 26.0, Color(0.15, 0.15, 0.18), 10.0)

	# 投石器
	if catapult_level > 0:
		var p := _catapult_local_pos()
		var wood := Color(0.5, 0.35, 0.2)
		draw_rect(Rect2(p + Vector2(-16, 4), Vector2(32, 8)), wood)
		draw_line(p + Vector2(-10, 6), p + Vector2(0, -8), wood, 3.0)
		draw_line(p + Vector2(10, 6), p + Vector2(0, -8), wood, 3.0)
		var arm_ang := -2.2 if _catapult_swing > 0.0 else -0.5
		var arm_end := p + Vector2(0, -8) + Vector2.from_angle(arm_ang) * 26.0
		draw_line(p + Vector2(0, -8), arm_end, Color(0.4, 0.28, 0.15), 4.0)
		if _catapult_swing <= 0.0:
			draw_circle(arm_end, 6.0, Color(0.45, 0.42, 0.4))

	# HPバー（城の下）
	var w := HALF.x * 2.0
	var top := Vector2(-HALF.x, HALF.y + 8.0)
	draw_rect(Rect2(top, Vector2(w, 8)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(w * hp / max_hp, 8)), Color(1.0, 0.6, 0.2))
