extends Node2D
## 6つ目の特別強化「必殺技」。15秒ごとに、部隊・設備の種類ごとに強くて派手な技を出す。
## どの技を持っているかは、下の true / false で管理する（upgrades.gd の apply() で true になる）。

const SlashScript := preload("res://scripts/slash_effect.gd")
const BulletScript := preload("res://scripts/bullet.gd")
const LightningScript := preload("res://scripts/lightning.gd")
const MineFxScript := preload("res://scripts/mine_fx.gd")

## 必殺技の間隔（秒）
const INTERVAL := 15.0
## 鉄壁の陣のドームの大きさと、続く時間
const DOME_RADIUS := 300.0
const DOME_TIME := 5.0
## 剣の大嵐の威力（剣の何倍か。20倍の2倍）
const STORM_MULT := 40.0
## 鳥の大群の鳥の威力（ペットの攻撃力の10.8倍）
const FLOCK_MULT := 10.8

var game: Node2D

## 遊撃：剣の大嵐（周りを巻き込む巨大な回転斬り）
var storm := false
## 迎撃：鉄壁の陣（城をドームで包み、敵の弾を消す）
var dome := false
## 迎撃：拒馬の陣（鉄壁の陣のドームの中の敵に、拒馬の柵と同じ効果）
var dome_spikes := false
var _dome_spike_cd := 0.0
## 重装：大地砕き（敵の群れへ飛び込んで地面を叩き割る）
var leap := false
## 築城：城壁の大号令（全部の壁が耐久10回復して、全部の壁が爆発する）
var wall_burst := false
## 工兵：絨毯爆撃（敵の群れに一直線に爆弾が降る）
var carpet := false
## 狙撃：天穿つ一矢（巨大な矢が一直線に全部を貫く）
var sky_arrow := false
## 矢倉：千本矢（フィールド中の敵に矢の雨）
var thousand := false
## 大砲：一斉砲撃（12発の砲弾を一気に撃ち込む）
var barrage := false
## 投石器：隕石落とし（巨大な燃える岩）
var meteor := false
## バリスタ：雷神の大槍（一直線に雷の槍を放つ）
var thunder_spear := false
## 結界：氷河期（広い範囲の敵をまとめて凍らせる）
var ice_age := false
## ペット：鳥の大群（ペット1匹につき鳥を6羽呼び、敵を追いかけてつつく）
var flock := false
## 近衛：百騎突撃（騎士の幻が横一列になってフィールドを駆け抜ける）
var cavalry := false
## 修理：大修繕（城のHP5%回復・味方を全回復。壁は直さない）
var overhaul := false
## 採掘場：暴走トロッコ（右端から左端へトロッコが突進。はねた敵1体につき経験値+1）
var trolley := false

## 技ごとの残り時間（同時に出ないように少しずつずらしておく）
var _cds := {}
var dome_left := 0.0
## 画面の演出（氷河期・千本矢など）
var _flash_left := 0.0
var _flash_color := Color.WHITE
var _ice_ring := 0.0


func _ready() -> void:
	var names := ["storm", "dome", "leap", "wall_burst", "carpet", "sky_arrow", "thousand", "barrage", "meteor", "thunder_spear", "ice_age", "flock", "cavalry", "overhaul", "trolley"]
	for i in names.size():
		_cds[names[i]] = 4.0 + i * 1.3


## 敵の弾がドームの中にあるか（bullet.gd から呼ばれる）
func dome_blocks(p: Vector2) -> bool:
	return dome_left > 0.0 and p.distance_to(game.castle.global_position) < DOME_RADIUS


func _ready_to_fire(key: String, delta: float) -> bool:
	_cds[key] -= delta
	if _cds[key] > 0.0:
		return false
	_cds[key] = INTERVAL
	return true


func _process(delta: float) -> void:
	dome_left -= delta
	if dome_spikes and dome_left > 0.0 and not game.guards.is_empty():
		_dome_spike_cd -= delta
		if _dome_spike_cd <= 0.0:
			_dome_spike_cd = 0.5
			_dome_spike_hit()
	_flash_left -= delta
	_ice_ring -= delta
	if storm and _ready_to_fire("storm", delta):
		_do_storm()
	if dome and not game.guards.is_empty() and _ready_to_fire("dome", delta):
		_do_dome()
	if leap and game.all_heavies().any(func(h: Node2D) -> bool: return not h.dead) and _ready_to_fire("leap", delta):
		_do_leap()
	if wall_burst and not game.walls.walls.is_empty() and _ready_to_fire("wall_burst", delta):
		_do_wall_burst()
	if carpet and not game.engineers.is_empty() and _ready_to_fire("carpet", delta):
		_do_carpet()
	if sky_arrow and not game.snipers.is_empty() and _ready_to_fire("sky_arrow", delta):
		_do_sky_arrow()
	var castle: Node2D = game.castle
	if thousand and castle.tower_count > 0 and _ready_to_fire("thousand", delta):
		_do_thousand()
	if barrage and castle.cannon_level > 0 and _ready_to_fire("barrage", delta):
		_do_barrage()
	if meteor and castle.catapult_level > 0 and _ready_to_fire("meteor", delta):
		_do_meteor()
	if thunder_spear and castle.ballista_level > 0 and _ready_to_fire("thunder_spear", delta):
		_do_thunder_spear()
	if ice_age and castle.frost_radius > 0.0 and _ready_to_fire("ice_age", delta):
		_do_ice_age()
	if flock and not game.pets.is_empty() and _ready_to_fire("flock", delta):
		_do_flock()
	if cavalry and not game.knights.is_empty() and not game.enemies_cache.is_empty() and _ready_to_fire("cavalry", delta):
		_do_cavalry()
	if overhaul and not game.repairers.is_empty() and _ready_to_fire("overhaul", delta):
		_do_overhaul()
	if trolley and not game.mine_sites.is_empty() and not game.enemies_cache.is_empty() and _ready_to_fire("trolley", delta):
		_do_trolley()
	queue_redraw()


## 時間とともに強くなる威力（設備の威力を使わない技用）
func _time_mult() -> float:
	return 1.0 + game.elapsed / 120.0


func _alive_enemies() -> Array:
	return game.enemies_cache.filter(func(e: Node2D) -> bool: return is_instance_valid(e) and not e.dead)


# ---------------------------------------------------------------- 各部隊の必殺技

func _do_storm() -> void:
	var st = game.stats
	for s in game.soldiers:
		if s.dead:
			continue
		game.explode(s.global_position, 210.0, st.sword_attack_power() * STORM_MULT, game.sp_src(s.record, "sp_ult_storm"), Color(0.7, 0.9, 1.0), 0.0, 450.0)
		for r in [210.0, 150.0]:
			var fx := SlashScript.new()
			fx.radius = r
			fx.arc = TAU
			fx.duration = 0.35
			fx.position = s.global_position
			game.effects.add_child(fx)


## 拒馬の陣：ドームの中の敵に、拒馬の柵と同じダメージ（0.5秒ごとに槍の0.4倍）と足止め（20%遅く）
func _dome_spike_hit() -> void:
	var dmg: float = game.guard_stats.attack_power * 0.4
	var src: Dictionary = game.sp_src(game.guards[0].record, "sp_dome_spikes")
	for e in game.enemies_near(game.castle.global_position, DOME_RADIUS):
		if not is_instance_valid(e) or e.dead:
			continue
		if e.global_position.distance_to(game.castle.global_position) < DOME_RADIUS:
			e.take_damage(dmg, Vector2.ZERO, src)
			e.slow(0.6, 0.2)


func _do_dome() -> void:
	dome_left = DOME_TIME
	# 迎撃兵も全回復
	for g in game.guards:
		if not g.dead:
			game.heal_unit(g, game.guard_stats.max_hp, INF, g.record, "sp_ult_dome")
	game.spawn_burst(game.castle.global_position, Color(0.5, 1.0, 0.6), DOME_RADIUS / 2.0)


func _do_leap() -> void:
	var triggered := false
	for h in game.all_heavies():
		if h.dead:
			continue
		var best: Node2D = null
		var best_n := 0
		for e in _alive_enemies():
			if h.global_position.distance_to(e.global_position) > 450.0:
				continue
			var n: int = game.enemies_near(e.global_position, 150.0).size()
			if n > best_n:
				best_n = n
				best = e
		if best == null:
			continue
		triggered = true
		game.spawn_burst(h.global_position, Color(0.8, 0.7, 0.5), 30.0)
		h.position = best.global_position
		game.explode(h.global_position, 190.0, h.dmg() * 4.0, game.sp_src(h.record, "sp_ult_leap"), Color(0.75, 0.55, 0.3), 1.0, 500.0)
		game.spawn_burst(h.global_position, Color(1.0, 0.8, 0.4), 140.0)
	if not triggered:
		_cds["leap"] = 1.0
		return
	_flash(Color(1.0, 0.8, 0.5))


func _do_wall_burst() -> void:
	var walls: Node2D = game.walls
	var dmg := 75.0 * _time_mult()
	for w in walls.walls:
		var before: float = w["hp"]
		w["hp"] = minf(w["max"], w["hp"] + 10.0)
		if not w["src"].is_empty():
			w["src"]["wall_fixed"] += int(w["hp"] - before)
		var p: Vector2 = walls.point_at((w["a0"] + w["a1"]) / 2.0)
		game.explode(p + (p - game.castle.global_position).normalized() * 30.0, 110.0, dmg, game.sp_src(w["src"], "sp_ult_wall_burst"), Color(1.0, 0.85, 0.4), 0.0, 400.0)


func _do_carpet() -> void:
	var center: Node2D = game.castle._densest_enemy(2000.0, 150.0)
	if center == null:
		_cds["carpet"] = 1.0
		return
	var dir := Vector2.from_angle(randf() * TAU)
	var dmg: float = game.engineer_stats.bomb_damage * 0.6
	var rec: Dictionary = game.sp_src(game.engineers[0].record, "sp_ult_carpet")
	for i in 13:
		var p: Vector2 = center.global_position + dir * (i - 6) * 45.0
		game.spawn_blast(p, 0.5 + 0.06 * i, 85.0, dmg, rec, Color(1.0, 0.55, 0.2), "bomb")


func _do_sky_arrow() -> void:
	var st = game.sniper_stats
	for sn in game.snipers:
		var dir: Vector2 = game.castle._best_pierce_dir(sn.global_position)
		if dir == Vector2.ZERO:
			continue
		var b := BulletScript.new()
		b.game = game
		b.velocity = dir * 1500.0
		# 攻撃力の864倍
		b.damage = st.attack_power * 864.0
		b.pierce = 1000000
		b.radius = 22.0
		b.bolt = true
		b.scale = Vector2(2.6, 2.6)
		b.life = 1.8
		b.src = game.sp_src(sn.record, "sp_ult_sky_arrow")
		b.position = sn.global_position
		game.world.add_child(b)
	_flash(Color(1.0, 0.95, 0.6))


func _do_thousand() -> void:
	var castle: Node2D = game.castle
	var pool := _alive_enemies()
	pool.shuffle()
	var n := 30
	for i in n:
		var p: Vector2
		if i < pool.size():
			p = pool[i].global_position
		else:
			# 敵が少なければ、城の前の広い範囲にばらまく
			p = castle.global_position + Vector2(randf_range(-600, 600), randf_range(-700, -150))
		game.spawn_blast(p, 0.5 + randf() * 1.3, 60.0, castle.tower_attack_power * 6.0, game.sp_src(castle._equip_record("tower", "矢倉", i % castle.tower_count), "sp_ult_thousand"), Color(1.0, 0.6, 0.25), "arrow")


func _do_barrage() -> void:
	var castle: Node2D = game.castle
	var pool := _alive_enemies()
	if pool.is_empty():
		_cds["barrage"] = 1.0
		return
	pool.shuffle()
	var guns: int = mini(castle.cannon_level, castle.MAX_GUNS)
	for i in 12:
		var e: Node2D = pool[i % pool.size()]
		var gi := i % guns
		var from: Vector2 = castle.wpos() + castle._cannon_local_pos(gi)
		var to := e.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		var s: Node2D = castle._fire_shell(from, to, castle.cannon_attack_power * 24.0, castle.cannon_radius, false, game.sp_src(castle._equip_record("cannon", "大砲", gi), "sp_ult_barrage"))
		s.flight_time = 0.6 + i * 0.07


func _do_meteor() -> void:
	var castle: Node2D = game.castle
	var center: Node2D = castle._densest_enemy(2000.0, 250.0)
	if center == null:
		_cds["meteor"] = 1.0
		return
	var from: Vector2 = center.global_position + Vector2(-500, -600)
	var s: Node2D = castle._fire_shell(from, center.global_position, castle.catapult_attack_power * 9.0, 260.0, true, game.sp_src(castle._equip_record("catapult", "投石器", 0), "sp_ult_meteor"))
	s.meteor = true
	s.stay_rock = castle.meteor_rock
	s.flight_time = 1.8
	s.fire_time = 5.0
	s.fire_sp = ""
	s.fire_dps = castle.catapult_attack_power * 1.2


func _do_thunder_spear() -> void:
	var castle: Node2D = game.castle
	var from: Vector2 = castle.global_position + Vector2(0, -castle.HALF.y)
	var dir: Vector2 = castle._best_pierce_dir(from)
	if dir == Vector2.ZERO:
		_cds["thunder_spear"] = 1.0
		return
	var rec: Dictionary = game.sp_src(castle._equip_record("ballista", "バリスタ", 0), "sp_ult_thunder")
	var hits: Array = []
	for e in _alive_enemies():
		var rel: Vector2 = e.global_position - from
		if rel.dot(dir) > 0.0 and absf(rel.dot(dir.orthogonal())) < 50.0 + e.radius:
			hits.append(e)
	# 破竹の雷槍（条件付き）：城に近い敵から順に当たり、当たるたびに威力 +10%（破竹の大矢と同じ）
	if castle.thunder_momentum:
		hits.sort_custom(func(a, b): return (a.global_position - from).dot(dir) < (b.global_position - from).dot(dir))
	var dmg: float = castle.ballista_attack_power * 4.8
	var dmg_max: float = dmg * 2.0
	for e in hits:
		e.stun(1.0)
		e.take_damage(dmg, dir * 300.0, rec)
		if castle.thunder_momentum:
			# 最大で最初の威力の2倍（+100%）まで
			dmg = minf(dmg * 1.1, dmg_max)
	for k in 3:
		var fx := LightningScript.new()
		fx.points = PackedVector2Array([from, from + dir * 1800.0])
		fx.width = 3.0 - k
		game.effects.add_child(fx)
	_flash(Color(0.7, 0.85, 1.0))


func _do_flock() -> void:
	# ペット1匹につき6羽の、ペットと同じ色の鳥。当たった敵が生き残っていたら、くっついて2回つつく（伝書鳩と同じ）
	for p in game.pets:
		# 合体中は巨大ペットの体から飛び立つ
		var from: Vector2 = p.global_position
		if not p.visible and game.soldier_pet_fusion() != null:
			from = game.soldier_pet_fusion().global_position
		for i in 6:
			var m: Node2D = game.spawn_missile("homing", from,
				Vector2.from_angle(TAU * i / 6.0) * 300.0, game.pet_attack_power * FLOCK_MULT, 10.0, 6.0, game.sp_src(p.record, "sp_ult_flock"))
			m.look = "bird"
			# ペットと同じ色の鳥（ペットの踊り中は虹色）
			m.bird_color = Color.from_hsv(randf(), 0.55, 1.0) if game.fun.pet_dance else Color(0.45, 0.95, 0.65)
			m.bird_wing = Color(0.3, 0.75, 0.5)
	_flash(Color(0.8, 1.0, 0.9))


func _do_cavalry() -> void:
	# 一番下にいる敵の高さを中心に、8騎が横一列で駆け抜ける
	var low_y := -INF
	for e in _alive_enemies():
		low_y = maxf(low_y, e.global_position.y)
	if low_y == -INF:
		_cds["cavalry"] = 1.0
		return
	var rect: Rect2 = game.MAP_RECT
	var from_left := randf() < 0.5
	var sgn := 1.0 if from_left else -1.0
	var dmg: float = game.knight_damage() * 225.0
	for i in 8:
		var y := clampf(low_y + (i - 3.5) * 34.0, rect.position.y + 20.0, rect.end.y - 20.0)
		var x := (rect.position.x + 10.0 if from_left else rect.end.x - 10.0) - (i % 2) * 40.0 * sgn
		var rider: Node2D = game.spawn_missile("rider", Vector2(x, y), Vector2(950.0 * sgn, 0.0), dmg, 20.0, 1.8, game.sp_src(game.knights[0].record, "sp_ult_cavalry"))
		# 流星百騎：騎士の幻も、近衛の突進と同じ流れ星を残す（流れ星突撃として記録）
		if game.knight_stats.cavalry_star:
			rider.star_damage = game.knight_damage() * 3.6
			rider.star_src = game.sp_src(game.knights[0].record, "sp_fun_star")
	_flash(Color(1.0, 0.9, 0.5))


## 暴走トロッコ：敵が一番多く並んでいる高さ（上下40以内の敵の数が一番多い所）を、右端から左端へ駆け抜ける
func _do_trolley() -> void:
	var alive := _alive_enemies()
	if alive.is_empty():
		_cds["trolley"] = 1.0
		return
	var best_y := 0.0
	var best_n := -1
	for e in alive:
		var y: float = e.global_position.y
		var n := 0
		for o in alive:
			if absf(o.global_position.y - y) < 40.0:
				n += 1
		if n > best_n:
			best_n = n
			best_y = y
	var rect: Rect2 = game.MAP_RECT
	var t := MineFxScript.new()
	t.game = game
	t.kind = "trolley"
	t.position = Vector2(rect.end.x + 40.0, clampf(best_y, rect.position.y + 20.0, rect.end.y - 20.0))
	game.effects.add_child(t)
	_flash(Color(1.0, 0.85, 0.5))


func _do_overhaul() -> void:
	var castle: Node2D = game.castle
	var rec: Dictionary = game.repairers[0].record if not game.repairers.is_empty() else {}
	castle.heal(castle.max_hp * 0.05, rec, "sp_ult_overhaul")
	for s in game.soldiers:
		if not s.dead:
			game.heal_unit(s, game.stats.max_hp, INF, rec, "sp_ult_overhaul")
	for g in game.guards:
		if not g.dead:
			game.heal_unit(g, game.guard_stats.max_hp, INF, rec, "sp_ult_overhaul")
	for k in game.knights:
		if not k.dead:
			game.heal_unit(k, game.knight_stats.max_hp, INF, rec, "sp_ult_overhaul")
	for h in game.all_heavies():
		if not h.dead:
			game.heal_unit(h, h.max_hp, INF, rec, "sp_ult_overhaul")
	game.spawn_burst(castle.global_position, Color(0.5, 1.0, 0.6), 160.0)
	_flash(Color(0.6, 1.0, 0.7))


func _do_ice_age() -> void:
	var castle: Node2D = game.castle
	var r: float = castle.frost_radius * 2.2
	var dmg := 4.0 * _time_mult()
	var rec: Dictionary = game.sp_src(castle._equip_record("frost", "氷結の結界", 0), "sp_ult_ice_age")
	for e in _alive_enemies():
		if castle.global_position.distance_to(e.global_position) < r:
			e.stun(1.0)
			e.take_damage(dmg, Vector2.ZERO, rec)
	_ice_ring = 0.8
	_flash(Color(0.7, 0.95, 1.0))


func _flash(col: Color) -> void:
	_flash_left = 0.3
	_flash_color = col


func _draw() -> void:
	var c: Vector2 = game.castle.global_position
	if dome_left > 0.0:
		# 鉄壁の陣：城を包む緑のドーム（消える前は点滅）
		var a := 1.0 if dome_left > 1.0 or int(dome_left * 8.0) % 2 == 0 else 0.4
		draw_circle(c, DOME_RADIUS, Color(0.4, 1.0, 0.5, 0.1 * a))
		draw_arc(c, DOME_RADIUS, 0.0, TAU, 64, Color(0.6, 1.0, 0.7, 0.8 * a), 4.0)
		for i in 6:
			var ang: float = TAU * i / 6.0 + game.elapsed * 0.3
			draw_line(c, c + Vector2.from_angle(ang) * DOME_RADIUS, Color(0.6, 1.0, 0.7, 0.15 * a), 2.0)
	if _ice_ring > 0.0:
		# 氷河期：広がる氷の輪
		var k := 1.0 - _ice_ring / 0.8
		var r: float = game.castle.frost_radius * 2.2 * k
		draw_circle(c, r, Color(0.7, 0.95, 1.0, 0.25 * (1.0 - k)))
		draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, 0.9 * (1.0 - k)), 6.0)
	if _flash_left > 0.0:
		# 画面全体が一瞬光る
		draw_rect(game.MAP_RECT.grow(400.0), Color(_flash_color, 0.25 * _flash_left / 0.3))
