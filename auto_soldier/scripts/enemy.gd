extends Node2D
## 敵。城を目指して進んでくる。
## 近接型（grunt / runner / brute）は城に触れると消滅して城にダメージ、近くの兵士には体当たり。
## 遠距離型（archer）は近くの兵士か城を狙って弾を撃つ。
## 刺客（hunter）は城を無視して兵士（遊撃部隊・迎撃部隊）だけを狙う。壁もすり抜ける。
## 壁に触れると壁に1発分防がれて消滅する（ダメージの大きさに関係なし）。

const BulletScript := preload("res://scripts/bullet.gd")

var game: Node2D
var kind := "grunt"
var max_hp := 20.0
var hp := 20.0
var speed := 95.0
var damage := 8.0
## 城に触れたときに城へ与えるダメージ
var castle_damage := 8.0
var radius := 14.0
var xp_value := 1
var color := Color(0.9, 0.3, 0.3)
var ranged := false
var hunter := false
var dead := false

var knock := Vector2.ZERO
var _facing := Vector2.RIGHT
var _shoot_cd := 1.5
var _contact_cd := 0.0
var _flash := 0.0
var _strafe_sign := 1.0
var speed_mult := 1.0
## 落とし穴で動けない残り時間
var stun_left := 0.0


func setup(k: String, hp_mult: float) -> void:
	kind = k
	match k:
		"grunt":
			max_hp = 20.0; speed = 55.0; damage = 6.0; castle_damage = 6.0; radius = 14.0; xp_value = 1
			color = Color(0.9, 0.3, 0.3)
		"runner":
			max_hp = 12.0; speed = 105.0; damage = 6.0; castle_damage = 6.0; radius = 11.0; xp_value = 1
			color = Color(1.0, 0.6, 0.2)
		"archer":
			max_hp = 18.0; speed = 50.0; damage = 5.0; castle_damage = 6.0; radius = 14.0; xp_value = 2
			color = Color(0.7, 0.4, 0.95)
			ranged = true
		"brute":
			max_hp = 130.0; speed = 35.0; damage = 18.0; castle_damage = 25.0; radius = 26.0; xp_value = 6
			color = Color(0.55, 0.15, 0.2)
		"hunter":
			max_hp = 35.0; speed = 92.0; damage = 12.0; castle_damage = 0.0; radius = 13.0; xp_value = 3
			color = Color(0.2, 0.65, 0.6)
			hunter = true
	max_hp *= hp_mult
	hp = max_hp
	speed *= randf_range(0.9, 1.1)
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_shoot_cd = randf_range(1.0, 2.5)
	add_to_group("enemies")


func _process(delta: float) -> void:
	if dead:
		return
	_flash -= delta
	_contact_cd -= delta
	if stun_left > 0.0:
		# 落とし穴にはまって動けない（攻撃もできない）
		stun_left -= delta
		position += knock * delta
		knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
		queue_redraw()
		return
	var castle: Node2D = game.castle
	var move := Vector2.ZERO
	# 基本は城へ。近くに兵士がいればそちらを狙う
	var aggro := 300.0 if ranged else 110.0
	if hunter:
		aggro = INF
	var soldier: Node2D = game.nearest_ally(global_position, aggro)
	var target_pos: Vector2 = soldier.global_position if soldier != null else castle.closest_point(global_position)
	if hunter and soldier == null:
		# 狙える兵士がいなければ城の前で待ち伏せ
		target_pos = castle.gate_position() + Vector2(0, -280.0)
	var to: Vector2 = target_pos - global_position
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	_facing = dir
	if ranged:
		if d > 300.0:
			move = dir
		elif d < 200.0 and soldier != null:
			# 兵士からは距離をとる（城を狙っているときは下がらない）
			move = -dir
		else:
			move = dir.orthogonal() * _strafe_sign * 0.5
		_shoot_cd -= delta
		if _shoot_cd <= 0.0 and d < 420.0:
			# 城への弾は少し弱い
			_shoot(dir, damage if soldier != null else damage * 0.5)
			_shoot_cd = randf_range(2.2, 3.0)
	elif hunter and soldier == null and d < 20.0:
		move = Vector2.ZERO
	else:
		move = dir
	# 兵士への体当たり
	var touching: Node2D = game.nearest_ally(global_position, radius + 16.0)
	if touching != null and _contact_cd <= 0.0:
		touching.take_damage(damage, global_position)
		_contact_cd = 0.6
	if not hunter and not _check_wall():
		return
	# 城に触れたら消滅して城にダメージ（経験値は入らない）
	if not hunter and castle.distance_to_point(global_position) < radius:
		castle.take_damage(castle_damage)
		dead = true
		remove_from_group("enemies")
		game.spawn_burst(global_position, color, radius)
		queue_free()
		return

	speed_mult = castle.slow_factor_at(global_position)
	position += (move * speed * speed_mult + knock) * delta
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	_separate()
	position = game.clamp_to_map(position, radius)
	queue_redraw()


## 壁に触れたら壁が1発分防ぎ、この敵は消滅する（false を返す）
func _check_wall() -> bool:
	var wi: int = game.walls.hit_test(global_position, radius)
	if wi < 0:
		return true
	game.walls.absorb(wi)
	dead = true
	remove_from_group("enemies")
	game.spawn_burst(global_position, color, radius)
	queue_free()
	return false


## 敵同士が重なりすぎないように押し出す
func _separate() -> void:
	var push := Vector2.ZERO
	for o in game.enemies_near(position, radius + 26.0):
		if o == self or not is_instance_valid(o) or o.dead:
			continue
		var diff: Vector2 = position - o.position
		var min_d: float = radius + o.radius
		var dl := diff.length_squared()
		if dl < min_d * min_d and dl > 0.0001:
			var l := sqrt(dl)
			push += diff / l * (min_d - l)
	position += push * 0.5


func _shoot(dir: Vector2, dmg: float) -> void:
	var b := BulletScript.new()
	b.game = game
	b.from_enemy = true
	b.velocity = dir * 260.0
	b.damage = dmg
	b.radius = 7.0
	b.color = Color(0.85, 0.45, 1.0)
	b.life = 3.0
	b.position = global_position + dir * (radius + 4.0)
	game.world.add_child(b)


func stun(seconds: float) -> void:
	stun_left = maxf(stun_left, seconds)
	knock = Vector2.ZERO


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.1
	# 大型は吹き飛びにくい
	knock += knockback * (0.3 if kind == "brute" else 1.0)
	game.spawn_damage_text(global_position, amount, Color(1, 1, 1))
	if hp <= 0.0:
		dead = true
		remove_from_group("enemies")
		game.on_enemy_killed(self)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2(0, radius * 0.45), radius, Color(0, 0, 0, 0.3))
	var c := Color(1, 1, 1) if _flash > 0.0 else color
	match kind:
		"archer":
			# ひし形
			var pts := PackedVector2Array([
				Vector2(0, -radius * 1.2), Vector2(radius, 0),
				Vector2(0, radius * 1.2), Vector2(-radius, 0)])
			draw_colored_polygon(pts, c)
			draw_line(_facing * 4.0, _facing * (radius + 8.0), Color(0.3, 0.15, 0.4), 3.0)
		"brute":
			draw_circle(Vector2.ZERO, radius, c)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.2, 0.05, 0.05), 3.0)
			# 角
			var side := _facing.orthogonal()
			for s in [-1.0, 1.0]:
				var base: Vector2 = _facing * radius * 0.6 + side * radius * 0.6 * s
				draw_line(base, base + _facing * 12.0 + side * 6.0 * s, Color(0.9, 0.85, 0.7), 4.0)
		"hunter":
			# とがった刺客
			var f := _facing
			var o := _facing.orthogonal()
			draw_colored_polygon(PackedVector2Array([
				f * radius * 1.5, o * radius, -f * radius * 0.8, -o * radius]), c)
			draw_line(o * radius * 0.9, o * radius * 0.9 + f * 14.0, Color(0.85, 0.9, 0.95), 2.0)
			draw_line(-o * radius * 0.9, -o * radius * 0.9 + f * 14.0, Color(0.85, 0.9, 0.95), 2.0)
		_:
			draw_circle(Vector2.ZERO, radius, c)
	# 目
	var side2 := _facing.orthogonal()
	for s in [-1.0, 1.0]:
		draw_circle(_facing * radius * 0.45 + side2 * radius * 0.3 * s, radius * 0.15, Color(0.1, 0.05, 0.05))
	# 氷結の結界で遅くなっている
	if stun_left > 0.0:
		# 落とし穴で動けない：頭の上でぐるぐる回る星
		for i in 3:
			var a := stun_left * 4.0 + TAU * i / 3.0
			draw_circle(Vector2(cos(a) * radius * 0.7, -radius - 6.0 + sin(a) * 3.0), 3.0, Color(1.0, 0.9, 0.3))
	if speed_mult < 1.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 20, Color(0.6, 0.9, 1.0, 0.8), 2.0)
	# HPバー
	if hp < max_hp:
		var w := radius * 2.0
		var top := Vector2(-radius, -radius - 9.0)
		draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * hp / max_hp, 4)), Color(0.9, 0.2, 0.2))
