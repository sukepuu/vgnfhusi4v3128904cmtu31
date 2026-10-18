extends Node2D
## 弓兵部隊。画面の下半分で自由に動き回りながら戦う。
## 体力設定なし（敵から狙われない）。攻撃間隔0.8秒、威力30。
## ステータスは簡易的に固定（強化は後で追加予定）。

const BulletScript := preload("res://scripts/bullet.gd")

var game: Node2D
var index := 0
var hp := 80.0
var dead := false
var radius := 12.0
var record: Dictionary
var aim := Vector2.UP

var _cd := 0.4
var _wander_t := 0.0
var _target_pos := Vector2.ZERO

## 下半分の範囲（城より上、マップの下側）
func _lower_half_rect() -> Rect2:
	var r: Rect2 = game.MAP_RECT
	return Rect2(r.position.x, r.position.y + r.size.y * 0.5, r.size.x, r.size.y * 0.5)


func _ready() -> void:
	record = game.new_record("archer", "弓兵部隊%d" % (index + 1))
	_cd = 0.3 * index
	_pick_new_dest()


func take_damage(amount: float, _from_pos: Vector2 = Vector2.INF) -> void:
	if game.archer_counter:
		var target := _nearest_enemy(game.archer_stats.fire_range)
		if target != null:
			_shoot(target, game.archer_stats)
	if dead:
		return
	record["taken"] += minf(amount, hp)
	hp -= amount
	if hp <= 0.0:
		dead = true
		queue_free()
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		queue_free()


func _process(delta: float) -> void:
	var st = game.archer_stats
	_cd -= delta
	if game.archer_rain and fmod(game.elapsed, 8.0) < delta:
		_arrow_rain()
	if game.archer_ult and fmod(game.elapsed, 15.0) < delta:
		_fire_orb()
	if game.archer_tornado and fmod(game.elapsed, 10.0) < delta:
		_fire_tornado_arrow()
	if game.archer_giant_tornado and fmod(game.elapsed, 40.0) < delta:
		_giant_tornado()
	_wander_t -= delta
	# 下半分をふらふら移動
	if _wander_t <= 0.0 or position.distance_to(_target_pos) < 20.0:
		_pick_new_dest()
	var to := _target_pos - position
	if to.length() > 4.0:
		position += to.normalized() * minf(140.0 * delta, to.length())
	# 近くの敵を狙って撃つ
	var target := _nearest_enemy(st.fire_range)
	if target != null:
		aim = (target.global_position - global_position).normalized()
		if _cd <= 0.0:
			_cd = st.interval
			_shoot(target, st)
	queue_redraw()


func _pick_new_dest() -> void:
	var r := _lower_half_rect()
	_target_pos = Vector2(randf_range(r.position.x + 40, r.end.x - 40), randf_range(r.position.y + 40, r.end.y - 40))
	_wander_t = randf_range(2.5, 5.0)


func _nearest_enemy(range_limit: float) -> Node2D:
	var best: Node2D = null
	var best_d := range_limit
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _fire_tornado_arrow() -> void:
	var target := _nearest_enemy(game.archer_stats.fire_range)
	if target == null:
		return
	var b := BulletScript.new()
	b.game = game
	b.position = global_position
	b.velocity = (target.global_position - global_position).normalized() * 600.0
	b.damage = 20.0
	b.radius = 8.0
	b.color = Color(0.6, 0.9, 1.0)
	b.life = 1.5
	b.src = game.sp_src(record, "sp_archer_tornado")
	b.tornado_on_hit = true
	game.effects.add_child(b)


func _giant_tornado() -> void:
	var center := Vector2(960, 540)
	game.explode(center, 180.0, 80.0, game.sp_src(record, "sp_archer_giant_tornado"), Color(0.5, 0.8, 1.0), 0.0, 400.0)
	for e in game.enemies_near(center, 200.0):
		if is_instance_valid(e) and not e.dead:
			var dir: Vector2 = (e.global_position - center).normalized()
			e.shot_knockback(dir * 600.0)


func _fire_orb() -> void:
	var b := BulletScript.new()
	b.game = game
	b.position = global_position
	b.velocity = aim * 180.0
	b.damage = 20.0
	b.radius = 12.0
	b.color = Color(1.0, 0.8, 0.4)
	b.life = 6.0
	b.src = game.sp_src(record, "sp_archer_ult")
	b.ult_orb = true
	game.effects.add_child(b)


func _arrow_rain() -> void:
	var y := global_position.y
	for i in 8:
		var x := randf_range(100.0, 1700.0)
		var b := BulletScript.new()
		b.game = game
		b.position = Vector2(x, y - 200.0)
		b.velocity = Vector2(0, 400.0)
		b.damage = 8.0
		b.radius = 3.0
		b.color = Color(0.7, 0.8, 1.0, 0.6)
		b.life = 0.8
		b.src = game.sp_src(record, "sp_archer_rain")
		game.effects.add_child(b)


func _shoot(target: Node2D, st) -> void:
	for k in st.shots:
		var dir := aim.rotated((k - (st.shots - 1) / 2.0) * 0.15)
		var b := BulletScript.new()
		b.game = game
		b.position = global_position
		b.velocity = dir * st.arrow_speed
		b.damage = st.damage
		if game.archer_execute and target.hp <= target.max_hp * 0.5:
			b.damage *= 1.3
		if game.archer_heavy_arrow:
			b.radius *= 3.0
			b.scale *= 3.0
			b.velocity *= 0.5
			var dist := target.global_position.distance_to(game.castle.global_position)
			var bonus := clampf(1.0 - dist / 800.0, 0.0, 0.6)
			b.damage *= 1.0 + bonus
		if game.archer_link:
			b.link_mark = true
		b.pierce = st.pierce
		b.radius = 5.0 * st.arrow_scale
		b.scale = Vector2.ONE * st.arrow_scale
		b.src = record
		if game.archer_shadow:
			b.slow_on_hit = 3.0
		game.effects.add_child(b)


func _draw() -> void:
	# 簡易的な見た目（紫っぽい弓兵）
	draw_circle(Vector2.ZERO, 10.0, Color(0.6, 0.4, 0.9))
	draw_line(Vector2.ZERO, aim * 16.0, Color(0.9, 0.8, 1.0), 2.0)
