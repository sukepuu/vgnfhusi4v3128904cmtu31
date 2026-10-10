extends Node2D
## 敵。近接型（grunt / runner / brute）と遠距離型（archer）

const BulletScript := preload("res://scripts/bullet.gd")

var game: Node2D
var kind := "grunt"
var max_hp := 20.0
var hp := 20.0
var speed := 95.0
var damage := 8.0
var radius := 14.0
var xp_value := 1
var color := Color(0.9, 0.3, 0.3)
var ranged := false
var dead := false

var knock := Vector2.ZERO
var _facing := Vector2.RIGHT
var _shoot_cd := 1.5
var _contact_cd := 0.0
var _flash := 0.0
var _strafe_sign := 1.0


func setup(k: String, hp_mult: float) -> void:
	kind = k
	match k:
		"grunt":
			max_hp = 20.0; speed = 95.0; damage = 6.0; radius = 14.0; xp_value = 1
			color = Color(0.9, 0.3, 0.3)
		"runner":
			max_hp = 12.0; speed = 165.0; damage = 6.0; radius = 11.0; xp_value = 1
			color = Color(1.0, 0.6, 0.2)
		"archer":
			max_hp = 18.0; speed = 85.0; damage = 10.0; radius = 14.0; xp_value = 2
			color = Color(0.7, 0.4, 0.95)
			ranged = true
		"brute":
			max_hp = 130.0; speed = 55.0; damage = 20.0; radius = 26.0; xp_value = 6
			color = Color(0.55, 0.15, 0.2)
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
	var soldier: Node2D = game.soldier
	var move := Vector2.ZERO
	if not soldier.dead:
		var to: Vector2 = soldier.global_position - global_position
		var d := to.length()
		var dir := to / maxf(d, 0.001)
		_facing = dir
		if ranged:
			if d > 330.0:
				move = dir
			elif d < 220.0:
				move = -dir
			else:
				move = dir.orthogonal() * _strafe_sign * 0.6
			_shoot_cd -= delta
			if _shoot_cd <= 0.0 and d < 500.0:
				_shoot(dir)
				_shoot_cd = randf_range(2.0, 2.8)
		else:
			move = dir
		# 接触ダメージ
		if d < radius + soldier.radius and _contact_cd <= 0.0:
			soldier.take_damage(damage)
			_contact_cd = 0.6

	position += (move * speed + knock) * delta
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	_separate()
	position = game.clamp_to_map(position, radius)
	queue_redraw()


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


func _shoot(dir: Vector2) -> void:
	var b := BulletScript.new()
	b.game = game
	b.from_enemy = true
	b.velocity = dir * 260.0
	b.damage = damage
	b.radius = 7.0
	b.color = Color(0.85, 0.45, 1.0)
	b.life = 3.0
	b.position = global_position + dir * (radius + 4.0)
	game.world.add_child(b)


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
		_:
			draw_circle(Vector2.ZERO, radius, c)
	# 目
	var side2 := _facing.orthogonal()
	for s in [-1.0, 1.0]:
		draw_circle(_facing * radius * 0.45 + side2 * radius * 0.3 * s, radius * 0.15, Color(0.1, 0.05, 0.05))
	# HPバー
	if hp < max_hp:
		var w := radius * 2.0
		var top := Vector2(-radius, -radius - 9.0)
		draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * hp / max_hp, 4)), Color(0.9, 0.2, 0.2))
