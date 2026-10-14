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
## 修理：修理玉（20秒ごとに城の前へ玉を置く。10秒で回復した城のHPの20倍のダメージを、HPが一番多い敵へ撃つ）
var repair_orb := false

var _roar_cd := 5.0
var _dove_cd := 3.0
var _snow_cd := 1.0
var _dance_cd := 6.0
var _orb_cd := 3.0
## 工兵：巨大からくり兵（20秒ごとに設置、10秒で消える）
var automaton := false
## からくり兵団：からくり兵を一度に2体置く
var automaton_squad := false
## からくり兵の戦績カード（工兵とは別に記録する）
var _automaton_record: Dictionary = {}
var _auto_cd := 5.0
## ペット：凍える羽根（10秒ごとに、全ペットが敵を追いかける凍結弾を撃つ。当たった敵は0.5秒凍る）
var _frost_cd := 3.0


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
	if game.pet_frost and not game.pets.is_empty():
		_frost_cd -= delta
		if _frost_cd <= 0.0:
			_frost_cd = 10.0
			_frost_volley()
	if automaton and not game.engineers.is_empty():
		_auto_cd -= delta
		if _auto_cd <= 0.0:
			_auto_cd = 20.0
			_place_automaton()
	if repair_orb and not game.repairers.is_empty():
		_orb_cd -= delta
		if _orb_cd <= 0.0:
			_orb_cd = 20.0
			game.spawn_placed("repair_orb", castle.global_position + Vector2(0, -castle.HALF.y - 70.0), 0.0, 16.0, 10.0, game.repairers[0].record)


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
	# 合体中は、巨大ペットが全方位へ24発（合体した数ぶんの威力）
	var f: Node2D = game.pet_fusion
	if f != null and f.merged():
		for i in 24:
			var dir := Vector2.from_angle(TAU * i / 24.0 + f._t)
			var fb := BulletScript.new()
			fb.game = game
			fb.velocity = dir * 420.0
			fb.damage = game.pet_damage * f._n / 2.0
			fb.radius = 8.0
			fb.color = Color.from_hsv(float(i) / 24.0, 0.75, 1.0)
			fb.life = 1.2
			fb.position = f.global_position + dir * f._radius
			fb.src = f.record
			game.world.add_child(fb)
	# 全部のペットが、全方位へ虹色の玉を12発ずつ撃つ
	for p in game.pets:
		# 合体中で隠れているペットは撃たない
		if not p.visible:
			continue
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


## 凍える羽根：全ペットが、近くの敵を追いかける凍結弾を1発ずつ撃つ（狙う敵はなるべくばらけさせる）
func _frost_volley() -> void:
	var f: Node2D = game.pet_fusion
	var used := {}
	for p in game.pets:
		# 合体中は巨大ペットの体から撃つ
		var from: Vector2 = p.global_position
		if not p.visible and f != null and f.merged():
			from = f.global_position
		var t: Node2D = null
		var best: float = game.pet_range * 1.5
		for e in game.enemies_near(from, best):
			if not is_instance_valid(e) or e.dead or used.has(e):
				continue
			var d: float = from.distance_to(e.global_position)
			if d < best:
				best = d
				t = e
		if t == null:
			t = game.nearest_enemy(from, game.pet_range * 1.5)
		if t == null:
			continue
		used[t] = true
		var b := BulletScript.new()
		b.game = game
		b.velocity = (t.global_position - from).normalized() * 380.0
		b.damage = game.pet_damage * 2.0 * (1.4 if game.pet_giant else 1.0)
		b.radius = 8.0
		b.color = Color(0.7, 0.95, 1.0)
		b.aim_target = t
		b.stun_on_hit = 0.5
		b.life = 3.0
		b.position = from
		b.src = p.record
		game.world.add_child(b)


## 敵が一番集まっている所の少し手前（城側）に置く。敵がいなければ城の前
func _place_automaton() -> void:
	var castle: Node2D = game.castle
	var best: Node2D = castle._densest_enemy(2000.0, 150.0)
	var pos: Vector2 = castle.global_position + Vector2(0, -320)
	if best != null:
		pos = best.global_position + (castle.global_position - best.global_position).normalized() * 160.0
	# からくり兵の火力（斬り・射撃・最後の爆発すべて）は爆弾の威力の0.6倍
	var dmg: float = game.engineer_stats.bomb_damage * 0.6
	var life := 10.0
	if _automaton_record.is_empty():
		_automaton_record = game.new_record("engineer", "からくり兵")
	var rec: Dictionary = _automaton_record
	game.spawn_placed("automaton", pos, dmg, 92.0, life, rec)
	if automaton_squad:
		# 2体目は横に並べて置く
		var side: Vector2 = (pos - castle.global_position).normalized().orthogonal() * 200.0
		game.spawn_placed("automaton", game.clamp_to_map(pos + side, 92.0), dmg, 92.0, life, rec)
	game.spawn_burst(pos, Color(1.0, 0.8, 0.4), 50.0)
