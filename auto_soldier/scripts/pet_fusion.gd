extends Node2D
## ペット大合体（ペットの特別強化）。
## 20秒ごとに全ペットが1か所に集まって合体し、10秒間だけ巨大ペットになる。
## 巨大ペットは「立ち止まって特大弾を連射 → まっすぐ高速突進」をくり返す。合体したペットが多いほど強く大きい。
## ペットの強化（間隔・威力・射程・弾数）とペットの特別強化の効果も、合体中にそのまま乗る。
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
	_radius = minf(18.0 + 6.0 * _n, 80.0) * (1.3 if game.pet_giant else 1.0)
	_left = DURATION
	_cd = CYCLE - DURATION
	_ram_cd.clear()
	_mode = "shoot"
	_mode_left = SHOOT_TIME
	_shot_cd = 0.0
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


## 合体ペットの火力の調整（ペットの弾の威力を0.7倍にしたうえで、合体ペット全体を前の1/7にするための値）
const FUSION_SCALE := 1.0 / 4.9


## 合体したペット1匹ぶんあたりの強さの倍率（多いほど1匹あたりも少し強い）
func _power() -> float:
	return _n * (1.0 + 0.1 * _n) * FUSION_SCALE


## 行動：立ち止まって射撃（SHOOT_TIME秒）→ 一番近い敵へまっすぐ高速突進 → 立ち止まって射撃 … をくり返す
const SHOOT_TIME := 1.2
const DASH_SPEED := 900.0
var _mode := "shoot"
var _mode_left := SHOOT_TIME
var _dash_dir := Vector2.ZERO


func _update_body(delta: float) -> void:
	# 癒しのさえずり：合体中も、各遊撃兵をペットの数ぶん回復
	if game.pet_heal:
		for s in game.soldiers:
			if not s.dead:
				s.hp = minf(game.stats.max_hp, s.hp + 2.0 * game.pets_per_soldier * delta)
	_mode_left -= delta
	if _mode == "shoot":
		_shoot_update(delta)
		if _mode_left <= 0.0:
			var t: Node2D = game.nearest_enemy(global_position, INF)
			if t != null:
				# 敵を突き抜けて少し先まで、まっすぐ突っ込む
				var to: Vector2 = t.global_position - global_position
				_dash_dir = to.normalized()
				_mode = "dash"
				_mode_left = (to.length() + _radius + 80.0) / DASH_SPEED
				_ram_cd.clear()
			else:
				_mode_left = 0.3
	else:
		position += _dash_dir * DASH_SPEED * delta
		position = game.clamp_to_map(position, _radius)
		_ram()
		if _mode_left <= 0.0:
			_mode = "shoot"
			_mode_left = SHOOT_TIME
			_shot_cd = 0.0


## 突進中に触れた敵へ体当たり（1回の突進で同じ敵には1回）。体当たりペットを持っていると2倍
func _ram() -> void:
	var dmg: float = game.pet_damage * 2.0 * _power() * (2.0 if game.pet_body else 1.0)
	for e in game.enemies_near(global_position, _radius + 40.0):
		if not is_instance_valid(e) or e.dead or _ram_cd.has(e):
			continue
		if global_position.distance_to(e.global_position) < _radius + e.radius:
			_ram_cd[e] = true
			e.take_damage(dmg, _dash_dir * 300.0, record)


## 立ち止まって特大弾を連射。ペットの強化（間隔・威力・射程・弾数・特別強化）がそのまま乗る
func _shoot_update(delta: float) -> void:
	_shot_cd -= delta
	if _shot_cd > 0.0:
		return
	var rng: float = game.pet_range * 1.5
	var aim: Node2D = game.nearest_enemy(global_position, rng)
	if aim == null:
		return
	# 早撃ちペットで間隔が縮む（ふつうのペットの間隔0.8に対して0.15）
	_shot_cd = 0.15 * game.pet_interval / 0.8
	var base: Vector2 = (aim.global_position - global_position).normalized()
	for k in game.pet_shots:
		var dir: Vector2 = base.rotated((k - (game.pet_shots - 1) / 2.0) * 0.12 + randf_range(-0.05, 0.05))
		var b := BulletScript.new()
		b.game = game
		b.velocity = dir * 560.0
		b.damage = game.pet_damage * _power()
		b.radius = 9.0 + minf(_n, 8.0)
		b.pierce = 2
		b.color = Color.from_hsv(fmod(_t * 0.7, 1.0), 0.5, 1.0)
		b.life = rng / 560.0 + 0.2
		b.position = global_position + dir * _radius
		b.src = record
		b.homing = game.pet_homing
		if game.pet_giant:
			b.damage *= 1.4
			b.radius *= 1.4
			b.pierce += 2
		if game.pet_burst:
			b.explode_radius = 45.0 + 3.0 * _n
			b.explode_ratio = 0.6
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
	# ペットの踊りを持っていたら、虹色に光る
	var body_col := Color.from_hsv(fmod(_t * 0.8, 1.0), 0.55, 1.0) if game.fun.pet_dance else Color(0.45, 0.95, 0.65)
	draw_circle(Vector2.ZERO, r, body_col)
	draw_arc(Vector2.ZERO, r + 6.0 + sin(_t * 6.0) * 3.0, 0.0, TAU, 48, Color.from_hsv(fmod(_t * 0.5, 1.0), 0.6, 1.0, 0.7), 4.0)
	draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.25, Color(0.8, 1.0, 0.9))
	# 目とくちばし
	draw_circle(Vector2(-r * 0.3, -r * 0.1), r * 0.12, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(r * 0.3, -r * 0.1), r * 0.12, Color(0.1, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.15, r * 0.15), Vector2(r * 0.15, r * 0.15), Vector2(0, r * 0.45)]), Color(1.0, 0.7, 0.2))
	# 残り時間
	draw_arc(Vector2.ZERO, r + 14.0, -PI / 2.0, -PI / 2.0 + TAU * _left / DURATION, 40, Color(1, 1, 1, 0.6), 3.0)
