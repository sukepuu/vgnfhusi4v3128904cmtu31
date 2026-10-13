extends Node2D
## おもしろ特別強化（あまり強くないけど、変で派手なやつ）のうち、一定時間ごとに出るもの。
## そのほか（花火・はね返し盾・ビックリ箱・かかし・ビリヤード砲弾・牛投げ・虹の矢・流れ星）は
## それぞれのスクリプトの中で処理している。

const FunFx := preload("res://scripts/fun_fx.gd")
const BulletScript := preload("res://scripts/bullet.gd")

var game: Node2D

## 重装：雄叫び（10秒ごとに叫んで、周りの敵に斬撃3倍のダメージを与えて吹き飛ばす）
var roar := false
## 矢倉：伝書鳩部隊（6秒ごとに敵を追いかける鳩を放つ。当たった敵にくっついて2回つつく）
var doves := false
## 結界：雪合戦（城から敵へ雪玉を投げ続ける）
var snowball := false
## ペット：ペットの踊り（虹色に光ってくるくる回り、5秒ごとに全方位へ玉を撃つ）
var pet_dance := false
## 修理：くす玉割り（12秒ごとにくす玉が割れて、城と味方が少し回復）
var kusudama := false

var _roar_cd := 5.0
var _dove_cd := 3.0
var _snow_cd := 1.0
var _dance_cd := 6.0
var _kusu_cd := 8.0
## 工兵：巨大からくり兵（20秒ごとに設置、10秒で消える）
var automaton := false
var _auto_cd := 5.0


func _process(delta: float) -> void:
	var castle: Node2D = game.castle
	if roar and game.heavy != null and not game.heavy.dead:
		_roar_cd -= delta
		if _roar_cd <= 0.0 and game.nearest_enemy(game.heavy.global_position, 220.0) != null:
			_roar_cd = 10.0
			_do_roar()
	if doves and castle.tower_count > 0:
		_dove_cd -= delta
		if _dove_cd <= 0.0 and not game.enemies_cache.is_empty():
			_dove_cd = 6.0
			for i in castle.tower_count:
				var from: Vector2 = castle.global_position + castle._tower_local_pos(i)
				var m: Node2D = game.spawn_missile("homing", from, Vector2.from_angle(randf_range(-PI * 0.8, -PI * 0.2)) * 260.0,
					castle.tower_damage * 0.8, 10.0, 6.0, castle._equip_record("tower", "矢倉", i))
				m.look = "bird"
	if snowball and castle.frost_radius > 0.0:
		_snow_cd -= delta
		if _snow_cd <= 0.0:
			_snow_cd = 0.7
			_throw_snowball()
	if pet_dance and not game.pets.is_empty():
		_dance_cd -= delta
		if _dance_cd <= 0.0:
			_dance_cd = 5.0
			_do_dance()
	if automaton and not game.engineers.is_empty():
		_auto_cd -= delta
		if _auto_cd <= 0.0:
			_auto_cd = 20.0
			_place_automaton()
	if kusudama and not game.repairers.is_empty():
		_kusu_cd -= delta
		if _kusu_cd <= 0.0:
			_kusu_cd = 12.0
			_do_kusudama()


func _fx(kind: String, pos: Vector2) -> Node2D:
	var f := FunFx.new()
	f.game = game
	f.kind = kind
	f.position = pos
	return f


func _do_roar() -> void:
	var h: Node2D = game.heavy
	var f := _fx("roar", h.global_position)
	f.radius = 220.0
	game.effects.add_child(f)
	# 斬撃（通常攻撃）の3倍のダメージを与えて、思いっきり吹き飛ばす
	game.explode(h.global_position, 220.0, h.dmg() * 3.0, h.record, Color(1.0, 0.6, 0.3), 0.0, 700.0)


func _throw_snowball() -> void:
	var castle: Node2D = game.castle
	var pool: Array = game.enemies_cache.filter(func(e: Node2D) -> bool:
		return is_instance_valid(e) and not e.dead and castle.global_position.distance_to(e.global_position) < castle.frost_radius * 1.6)
	if pool.is_empty():
		return
	var e: Node2D = pool.pick_random()
	var from: Vector2 = castle.global_position + Vector2(randf_range(-60, 60), -castle.HALF.y)
	var b := BulletScript.new()
	b.game = game
	b.velocity = (e.global_position - from).normalized() * 480.0
	b.damage = 12.0 * (1.0 + game.elapsed / 120.0)
	b.radius = 7.0
	b.color = Color(0.97, 0.98, 1.0)
	b.stun_on_hit = 0.15
	b.life = 1.6
	b.position = from
	b.src = castle._equip_record("frost", "氷結の結界", 0)
	game.world.add_child(b)


func _do_dance() -> void:
	# 全部のペットが、全方位へ虹色の玉を12発ずつ撃つ
	for p in game.pets:
		for i in 12:
			var dir := Vector2.from_angle(TAU * i / 12.0 + p._t)
			var b := BulletScript.new()
			b.game = game
			b.velocity = dir * 420.0
			b.damage = game.pet_damage
			b.radius = 5.0
			b.color = Color.from_hsv(float(i) / 12.0, 0.75, 1.0)
			b.life = 0.9
			b.position = p.global_position + dir * 10.0
			b.src = p.record
			game.world.add_child(b)


## 敵が一番集まっている所の少し手前（城側）に置く。敵がいなければ城の前
func _place_automaton() -> void:
	var castle: Node2D = game.castle
	var best: Node2D = castle._densest_enemy(2000.0, 150.0)
	var pos: Vector2 = castle.global_position + Vector2(0, -320)
	if best != null:
		pos = best.global_position + (castle.global_position - best.global_position).normalized() * 100.0
	var dmg: float = game.engineer_stats.bomb_damage
	game.spawn_placed("automaton", pos, dmg, 46.0, 10.0, game.engineers[0].record)
	game.spawn_burst(pos, Color(1.0, 0.8, 0.4), 50.0)


func _do_kusudama() -> void:
	var castle: Node2D = game.castle
	game.effects.add_child(_fx("kusudama", castle.global_position + Vector2(0, -castle.HALF.y - 60.0)))
	castle.hp = minf(castle.max_hp, castle.hp + 20.0)
	# 味方も少し回復
	for s in game.soldiers:
		if not s.dead:
			s.hp = minf(game.stats.max_hp, s.hp + 20.0)
	for g in game.guards:
		if not g.dead:
			g.hp = minf(game.guard_stats.max_hp, g.hp + 20.0)
	for k in game.knights:
		if not k.dead:
			k.hp = minf(game.knight_stats.max_hp, k.hp + 20.0)
	if game.heavy != null and not game.heavy.dead:
		game.heavy.hp = minf(game.heavy.max_hp, game.heavy.hp + 20.0)
