extends Node2D
## 重装部隊（最大1体）。足は遅いが、耐久力と攻撃力が高い。
## 壁の中央（城の真上）の外側に陣取り、迎撃部隊のように近づく敵を迎え撃ちに行く。
## 攻撃は遊撃部隊と同じ扇形の斬撃のみ。

const SlashScript := preload("res://scripts/slash_effect.gd")

const RESPAWN_TIME := 15.0
## 持ち場からどこまで離れて戦うか
const LEASH := 170.0
## 持ち場からどの距離の敵に反応するか
const ALERT := 300.0

var game: Node2D
var radius := 22.0
var dead := false
var respawn_left := 0.0
var facing := Vector2.UP
var target: Node2D = null

# --- ステータス
var max_hp := 450.0
var hp := 450.0
var regen := 4.0
var move_speed := 60.0
var slash_damage := 45.0
var slash_radius := 105.0
var slash_arc := deg_to_rad(150.0)
var slash_interval := 1.1

var _slash_cd := 0.0
var _hurt_flash := 0.0
var _invuln := 0.0
var _retarget_cd := 0.0


## 持ち場：壁の中央の、少し外側
func post_position() -> Vector2:
	return game.walls.point_at(PI * 1.5, game.walls.RADIUS + 55.0)


func _process(delta: float) -> void:
	if dead:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_respawn()
		queue_redraw()
		return
	_slash_cd -= delta
	_hurt_flash -= delta
	_invuln -= delta
	_retarget_cd -= delta
	hp = minf(max_hp, hp + regen * delta)

	var post := post_position()
	if _retarget_cd <= 0.0 or not _target_valid():
		target = _choose_target(post)
		_retarget_cd = 0.3

	# 敵に向かって行く。ただし持ち場から離れすぎない
	var desired := post
	if _target_valid():
		var to_t := target.global_position - post
		desired = post + to_t.limit_length(LEASH)
	var to := desired - global_position
	if to.length() > 6.0:
		position += to.normalized() * minf(move_speed * delta, to.length())
	position = game.clamp_to_map(position, radius)

	var look: Node2D = game.nearest_enemy(global_position, slash_radius + 60.0)
	if look == null and _target_valid():
		look = target
	if look != null:
		var want := (look.global_position - global_position).normalized()
		facing = Vector2.from_angle(rotate_toward(facing.angle(), want.angle(), 6.0 * delta))

	if _slash_cd <= 0.0 and _try_slash():
		_slash_cd = slash_interval
	queue_redraw()


func _target_valid() -> bool:
	return target != null and is_instance_valid(target) and not target.dead


## 持ち場に一番近い敵
func _choose_target(post: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := ALERT
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = e.global_position.distance_to(post)
		if d < best_d:
			best_d = d
			best = e
	return best


## 遊撃部隊と同じ扇形の斬撃
func _try_slash() -> bool:
	var near: Node2D = game.nearest_enemy(global_position, slash_radius)
	if near == null:
		return false
	var dir := (near.global_position - global_position).normalized()
	facing = dir
	for e in game.enemies_near(global_position, slash_radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - global_position
		if rel.length() > slash_radius + e.radius:
			continue
		if absf(dir.angle_to(rel)) > slash_arc / 2.0 + 0.2:
			continue
		e.take_damage(slash_damage, rel.normalized() * 420.0)
	# 斬撃で敵の弾もかき消す
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		var to_b: Vector2 = b.global_position - global_position
		if to_b.length() <= slash_radius and absf(dir.angle_to(to_b)) <= slash_arc / 2.0:
			b.queue_free()
	var fx := SlashScript.new()
	fx.radius = slash_radius
	fx.arc = slash_arc
	fx.rotation = dir.angle()
	fx.position = global_position
	game.effects.add_child(fx)
	return true


func take_damage(amount: float, _from_pos: Vector2 = Vector2.INF) -> void:
	if dead or _invuln > 0.0:
		return
	hp -= amount
	_hurt_flash = 0.15
	_invuln = 0.2
	game.spawn_damage_text(global_position, amount, Color(1.0, 0.35, 0.35))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		target = null
		respawn_left = RESPAWN_TIME


func _respawn() -> void:
	dead = false
	hp = max_hp
	position = game.castle.gate_position()
	_invuln = 2.0
	game.spawn_burst(global_position, Color(0.8, 0.7, 1.0), 26.0)


func _draw() -> void:
	if dead:
		draw_circle(Vector2.ZERO, radius * 0.8, Color(0.35, 0.3, 0.4, 0.5))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-20, 6), str(ceili(respawn_left)), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(1, 1, 1, 0.8))
		return
	draw_circle(Vector2(0, 9), radius, Color(0, 0, 0, 0.35))
	var body := Color(0.45, 0.42, 0.55)
	if _hurt_flash > 0.0:
		body = Color(1, 1, 1)
	draw_circle(Vector2.ZERO, radius, body)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.15, 0.12, 0.2), 3.5)
	# 肩当て
	var side := facing.orthogonal()
	draw_circle(side * radius * 0.75, 8.0, Color(0.6, 0.58, 0.7))
	draw_circle(-side * radius * 0.75, 8.0, Color(0.6, 0.58, 0.7))
	# 兜
	draw_circle(-facing * 3.0, radius * 0.55, Color(0.3, 0.28, 0.38))
	draw_line(facing * radius * 0.1 - side * 6.0, facing * radius * 0.1 + side * 6.0, Color(0.1, 0.1, 0.12), 3.0)
	# 大剣
	var hilt := side * radius * 0.9
	draw_line(hilt - facing * 6.0, hilt + facing * 40.0, Color(0.85, 0.88, 0.95), 6.0)
	draw_line(hilt - side * 7.0, hilt + side * 7.0, Color(0.55, 0.45, 0.2), 4.0)
	# HPバー
	if hp < max_hp:
		var w := radius * 2.4
		var top := Vector2(-w / 2.0, -radius - 12.0)
		draw_rect(Rect2(top, Vector2(w, 5)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * hp / max_hp, 5)), Color(0.3, 0.9, 0.4))
