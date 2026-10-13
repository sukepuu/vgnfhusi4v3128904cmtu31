extends Node2D
## ペット大合体（ペットの特別強化）。
## 20秒ごとに全ペットが1か所に集まって合体し、10秒間だけ巨大ペットになる。
## 巨大ペットは近くの敵へ体当たりしながら、特大弾を連射する。合体したペットが多いほど強く大きい。
## 合体中、元のペットは隠れて休んでいる。

const BulletScript := preload("res://scripts/bullet.gd")

const CYCLE := 20.0
const DURATION := 10.0

var game: Node2D
var record: Dictionary

var _cd := 5.0
var _left := 0.0
## 合体したペットの数
var _n := 0
var _radius := 20.0
var _shot_cd := 0.0
var _ram_cd := {}
var _t := 0.0


func _ready() -> void:
	record = game.new_record("pet", "合体ペット")
	visible = false


func merged() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	_t += delta
	if not merged():
		_cd -= delta
		if _cd <= 0.0 and not game.pets.is_empty():
			_merge()
		return
	_left -= delta
	# 合体中に増えたペットも隠しておく
	for p in game.pets:
		if p.visible:
			_hide_pet(p)
	_update_body(delta)
	if _left <= 0.0:
		_split()
	queue_redraw()


func _hide_pet(p: Node2D) -> void:
	p.visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED


func _merge() -> void:
	_n = game.pets.size()
	var center := Vector2.ZERO
	for p in game.pets:
		center += p.global_position
		_hide_pet(p)
	position = center / _n
	_radius = minf(18.0 + 6.0 * _n, 80.0)
	_left = DURATION
	_cd = CYCLE - DURATION
	_ram_cd.clear()
	visible = true
	game.spawn_burst(position, Color(0.5, 1.0, 0.7), _radius * 1.5)


func _split() -> void:
	_left = 0.0
	visible = false
	for p in game.pets:
		p.visible = true
		p.process_mode = Node.PROCESS_MODE_INHERIT
		p.position = position + Vector2.from_angle(randf() * TAU) * 20.0
	game.spawn_burst(position, Color(0.5, 1.0, 0.7), _radius)


## 合体したペット1匹ぶんあたりの強さの倍率（多いほど1匹あたりも少し強い）
func _power() -> float:
	return _n * (1.0 + 0.1 * _n)


func _update_body(delta: float) -> void:
	# 一番近い敵へ突っ込む
	var t: Node2D = game.nearest_enemy(global_position, INF)
	if t != null:
		var to: Vector2 = t.global_position - global_position
		if to.length() > 4.0:
			position += to.normalized() * minf(230.0 * delta, to.length())
	position = game.clamp_to_map(position, _radius)
	# 体当たり：触れた敵にダメージ（同じ敵へは0.5秒に1回）
	for e in _ram_cd.keys():
		_ram_cd[e] -= delta
		if _ram_cd[e] <= 0.0 or not is_instance_valid(e):
			_ram_cd.erase(e)
	for e in game.enemies_near(global_position, _radius + 40.0):
		if not is_instance_valid(e) or e.dead or _ram_cd.has(e):
			continue
		if global_position.distance_to(e.global_position) < _radius + e.radius:
			_ram_cd[e] = 0.5
			e.take_damage(game.pet_damage * 2.0 * _power(), (e.global_position - global_position).normalized() * 300.0, record)
	# 特大弾の連射
	_shot_cd -= delta
	if _shot_cd <= 0.0:
		var aim: Node2D = game.nearest_enemy(global_position, 650.0)
		if aim != null:
			_shot_cd = 0.15
			var dir: Vector2 = (aim.global_position - global_position).normalized().rotated(randf_range(-0.08, 0.08))
			var b := BulletScript.new()
			b.game = game
			b.velocity = dir * 560.0
			b.damage = game.pet_damage * _power()
			b.radius = 9.0 + minf(_n, 8.0)
			b.pierce = 2
			b.color = Color.from_hsv(fmod(_t * 0.7, 1.0), 0.5, 1.0)
			b.life = 1.3
			b.position = global_position + dir * _radius
			b.src = record
			game.world.add_child(b)


func _draw() -> void:
	if not merged():
		return
	var r := _radius
	var flap := sin(_t * 14.0) * r * 0.25
	draw_circle(Vector2(0, r * 0.4), r, Color(0, 0, 0, 0.25))
	# 大きな羽
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.6, 0), Vector2(-r * 1.7, -r * 0.6 - flap), Vector2(-r * 1.2, r * 0.3)]), Color(0.75, 1.0, 0.85))
	draw_colored_polygon(PackedVector2Array([Vector2(r * 0.6, 0), Vector2(r * 1.7, -r * 0.6 - flap), Vector2(r * 1.2, r * 0.3)]), Color(0.75, 1.0, 0.85))
	# 体（キラキラ光る輪つき）
	draw_circle(Vector2.ZERO, r, Color(0.45, 0.95, 0.65))
	draw_arc(Vector2.ZERO, r + 6.0 + sin(_t * 6.0) * 3.0, 0.0, TAU, 48, Color.from_hsv(fmod(_t * 0.5, 1.0), 0.6, 1.0, 0.7), 4.0)
	draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.25, Color(0.8, 1.0, 0.9))
	# 目とくちばし
	draw_circle(Vector2(-r * 0.3, -r * 0.1), r * 0.12, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(r * 0.3, -r * 0.1), r * 0.12, Color(0.1, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.15, r * 0.15), Vector2(r * 0.15, r * 0.15), Vector2(0, r * 0.45)]), Color(1.0, 0.7, 0.2))
	# 残り時間
	draw_arc(Vector2.ZERO, r + 14.0, -PI / 2.0, -PI / 2.0 + TAU * _left / DURATION, 40, Color(1, 1, 1, 0.6), 3.0)
