extends Node2D
## 弓兵部隊。画面の下半分を自由に動き回りながら、近くの敵へ矢を放つ。
## 敵から狙われない（敵の狙う相手 game.allies() には入らない）が、流れ弾・爆発・ビームには当たる（game.hittables()）。
## 倒れたら RESPAWN_TIME 秒後に城の前から復帰する。ステータスは game.archer_stats を全員で共有している。

const BulletScript := preload("res://scripts/bullet.gd")
const ArcherFxScript := preload("res://scripts/archer_fx.gd")

const RESPAWN_TIME := 10.0
const MOVE_SPEED := 140.0
## 特別強化の威力（矢1本の威力 × これ）
const RAIN_MULT := 30.0
const ORB_MULT := 7.5
const TORNADO_ARROW_MULT := 200.0
const GIANT_TORNADO_MULT := 60.0
## 特別強化の間隔（秒）。全弓兵が同じタイミングで撃つように、ゲームの経過時間の区切りで数える
const RAIN_EVERY := 8.0
const ORB_EVERY := 15.0
const TORNADO_EVERY := 10.0
const GIANT_TORNADO_EVERY := 30.0
const GIANT_TORNADO_RADIUS := 230.0

var game: Node2D
var index := 0
var hp := 80.0
var dead := false
var radius := 12.0
var record: Dictionary
var aim := Vector2.UP
var respawn_left := 0.0

var _cd := 0.4
var _wander_t := 0.0
var _target_pos := Vector2.ZERO
var _invuln := 0.0
var _hurt_flash := 0.0
var _t := 0.0
## 特別強化ごとに、最後に撃った区切りの番号（区切りが進んだら撃つ）
var _ticks := {}


## 動き回る範囲（マップの下半分）
func _lower_half_rect() -> Rect2:
	var r: Rect2 = game.MAP_RECT
	return Rect2(r.position.x, r.position.y + r.size.y * 0.5, r.size.x, r.size.y * 0.5)


func _ready() -> void:
	record = game.new_record("archer", "弓兵%d" % (index + 1))
	hp = game.archer_stats.max_hp
	_cd = 0.3 * index
	_pick_new_dest()
	for key in [RAIN_EVERY, ORB_EVERY, TORNADO_EVERY, GIANT_TORNADO_EVERY]:
		_ticks[key] = floori(game.elapsed / key)


## 流れ弾などに当たったとき（from_pos は使わない）
func take_damage(amount: float, _from_pos: Vector2 = Vector2.INF) -> void:
	if dead or _invuln > 0.0:
		return
	# 追い討ち：HPが半分以下の敵からの攻撃は受けない
	if game.archer_execute:
		var who = game.dmg_attacker
		if who != null and is_instance_valid(who) and who.hp <= who.max_hp * 0.5:
			return
	# 170overtime・序盤の被ダメージ半減は、ほかの兵士と同じ
	amount += game.overtime_dmg_bonus()
	amount *= game.early_damage_mult()
	record["taken"] += minf(amount, hp)
	game.note_taken("archer", minf(amount, hp))
	hp -= amount
	_hurt_flash = 0.15
	_invuln = 0.3
	game.spawn_damage_text(global_position, amount, Color(1.0, 0.35, 0.35))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		respawn_left = RESPAWN_TIME
		return
	# 反撃の矢：攻撃を受けたら、すぐに通常攻撃を1回
	if game.archer_counter:
		var target := _nearest_enemy(game.archer_stats.fire_range)
		if target != null:
			aim = (target.global_position - global_position).normalized()
			_shoot(target)


func _respawn() -> void:
	dead = false
	hp = game.archer_stats.max_hp
	position = game.castle.gate_position() + Vector2(randf_range(-40, 40), -30)
	_invuln = 1.5
	_pick_new_dest()
	game.spawn_burst(global_position, Color(0.8, 0.6, 1.0), 20.0)


func _process(delta: float) -> void:
	_t += delta
	_invuln -= delta
	_hurt_flash -= delta
	if dead:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_respawn()
		queue_redraw()
		return
	var st = game.archer_stats
	_cd -= delta * game.atk_speed_mult(record)
	if game.archer_rain and _due(RAIN_EVERY):
		_arrow_rain()
	if game.archer_ult and _due(ORB_EVERY):
		_fire_orb()
	if game.archer_tornado and _due(TORNADO_EVERY):
		_fire_tornado_arrow()
	# 巨大竜巻はフィールドに1つだけ（生きている一番前の弓兵が出す）
	if game.archer_giant_tornado and _due(GIANT_TORNADO_EVERY) and _is_leader():
		_giant_tornado()
	_wander_t -= delta
	# 下半分をふらふら移動
	if _wander_t <= 0.0 or position.distance_to(_target_pos) < 20.0:
		_pick_new_dest()
	var to := _target_pos - position
	if to.length() > 4.0:
		position += to.normalized() * minf(MOVE_SPEED * delta, to.length())
	# 近くの敵を狙って撃つ
	var target := _nearest_enemy(st.fire_range)
	if target != null:
		aim = (target.global_position - global_position).normalized()
		if _cd <= 0.0:
			_cd = st.interval
			_shoot(target)
	queue_redraw()


## every 秒ごとの区切りが進んでいたら true（全弓兵が同じタイミングになる）
func _due(every: float) -> bool:
	var cyc := floori(game.elapsed / every)
	if cyc > int(_ticks.get(every, cyc)):
		_ticks[every] = cyc
		return true
	_ticks[every] = cyc
	return false


func _is_leader() -> bool:
	for a in game.archers:
		if is_instance_valid(a) and not a.dead:
			return a == self
	return false


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


## 通常攻撃：多連矢のぶん少しずつ広げて撃つ。影縫い・近城の矢・連携射撃・追い討ちの効果は矢に付ける
func _shoot(target: Node2D) -> void:
	var st = game.archer_stats
	for k in st.shots:
		var dir := aim.rotated((k - (st.shots - 1) / 2.0) * 0.15)
		var b := _make_arrow(dir, st.damage, record)
		b.pierce = st.pierce
		b.radius = 5.0 * st.arrow_scale
		b.scale = Vector2(0.5, 0.5) * st.arrow_scale
		b.life = st.fire_range / st.arrow_speed + 0.3
		b.archer_hit = true
		b.link_mark = game.archer_link
		if game.archer_shadow:
			b.slow_on_hit = 3.0
		game.world.add_child(b)


func _make_arrow(dir: Vector2, dmg: float, src: Dictionary) -> Node2D:
	var b := BulletScript.new()
	b.game = game
	b.position = global_position
	b.velocity = dir * game.archer_stats.arrow_speed
	b.damage = dmg
	b.bolt = true
	b.scale = Vector2(0.5, 0.5)
	b.color = Color(0.85, 0.7, 1.0)
	b.src = src
	return b


## 竜巻矢：一番近い敵へ撃つ。当たった所に1秒の竜巻ができる
func _fire_tornado_arrow() -> void:
	var target := _nearest_enemy(game.archer_stats.fire_range * 1.5)
	if target == null:
		return
	var b := _make_arrow((target.global_position - global_position).normalized(), game.archer_stats.damage * TORNADO_ARROW_MULT, game.sp_src(record, "sp_archer_tornado"))
	b.radius = 8.0
	b.scale = Vector2(0.8, 0.8)
	b.color = Color(0.6, 0.9, 1.0)
	b.life = 1.5
	# 狙った敵を追いかける（途中で倒されたら、そのまままっすぐ飛ぶ）
	b.aim_target = target
	b.tornado_on_hit = true
	game.world.add_child(b)


## 巨大竜巻：フィールドの真ん中に出す
func _giant_tornado() -> void:
	var fx := ArcherFxScript.new()
	fx.game = game
	fx.kind = "giant"
	fx.radius = GIANT_TORNADO_RADIUS
	fx.duration = 1.5
	fx.damage = game.archer_stats.damage * GIANT_TORNADO_MULT
	fx.src = game.sp_src(record, "sp_archer_giant_tornado")
	fx.position = game.MAP_RECT.get_center()
	game.effects.add_child(fx)


## 必殺・連珠の玉：狙っている向き（敵がいなければ上）へ、ゆっくり進む玉を放つ
func _fire_orb() -> void:
	var target := _nearest_enemy(INF)
	var dir: Vector2 = (target.global_position - global_position).normalized() if target != null else Vector2.UP
	var fx := ArcherFxScript.new()
	fx.game = game
	fx.kind = "orb"
	fx.velocity = dir * 120.0
	fx.damage = game.archer_stats.damage * ORB_MULT
	fx.src = game.sp_src(record, "sp_archer_ult")
	fx.position = global_position
	game.effects.add_child(fx)


## 矢雨の予兆：弓兵のいる高さに、マップの端から端まで横一列に矢が降る
func _arrow_rain() -> void:
	var r: Rect2 = game.MAP_RECT
	var y := global_position.y
	var n := 14
	for i in n:
		var x: float = lerpf(r.position.x + 40.0, r.end.x - 40.0, (i + 0.5) / n) + randf_range(-20.0, 20.0)
		game.spawn_blast(Vector2(x, y + randf_range(-20.0, 20.0)), randf_range(0.3, 0.9), 45.0,
			game.archer_stats.damage * RAIN_MULT, game.sp_src(record, "sp_archer_rain"), Color(0.75, 0.8, 1.0), "arrow")


func _draw() -> void:
	if dead:
		return
	var body := Color(1, 1, 1) if _hurt_flash > 0.0 else Color(0.6, 0.4, 0.9)
	if _invuln > 0.0 and int(_invuln * 10.0) % 2 == 0:
		body.a = 0.5
	draw_circle(Vector2(0, 8), 9.0, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, 10.0, body)
	# 弓（狙っている向きに弧と弦）
	var bow_c := aim * 8.0
	draw_arc(bow_c - aim * 4.0, 11.0, aim.angle() - 1.2, aim.angle() + 1.2, 12, Color(0.55, 0.35, 0.15), 2.5)
	draw_line(bow_c - aim * 4.0 + Vector2.from_angle(aim.angle() - 1.2) * 11.0, bow_c - aim * 4.0 + Vector2.from_angle(aim.angle() + 1.2) * 11.0, Color(0.95, 0.95, 0.9), 1.0)
	draw_line(Vector2.ZERO, aim * 16.0, Color(0.9, 0.8, 1.0), 2.0)
	# HPバー（減っているときだけ）
	var max_hp: float = game.archer_stats.max_hp
	if hp < max_hp:
		draw_rect(Rect2(Vector2(-12, -18), Vector2(24, 3)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(Vector2(-12, -18), Vector2(24.0 * hp / max_hp, 3)), Color(0.6, 1.0, 0.5))
