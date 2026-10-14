extends Node2D
## 敵。城を目指して進んでくる。
## 近接型（grunt / runner / brute）は城に触れると消滅して城にダメージ、近くの兵士には体当たり。
## 遠距離型（archer）は近くの兵士か城を狙って弾を撃つ。
## 刺客（hunter）は城を無視して兵士（遊撃部隊・迎撃部隊）だけを狙う。壁もすり抜ける。
## 壁に触れると壁の耐久を5削って消滅する（敵の弾は1削る）。
## 分裂体（splitter）は倒すと小さな分裂体（splitling）3体に分かれる。
## 治癒師（healer）は後方にとどまり、周りの敵を定期的に回復する。
## 自爆兵（bomber）は兵士・壁・城にぶつかると爆発する（壁は3発分削る）。
## 隠密兵（stealth）は右下・左下から現れて城を狙う。半透明で見えにくい。
## 迫撃砲（mortar）はマップの端から動かず、壁を飛び越える砲弾で城を撃ってくる。
## 弾幕兵（ringer）は5秒ごとに全方位へ赤い弾を撃ちながら城へ進む。
## 誘導砲兵（seeker）はマップの端から動かず、迎撃と設置物以外の味方（遊撃・近衛・重装）へ誘導弾を撃つ。
## ボスは Lv10 ごとに2種類が交互に出現。
##   破城の魔王（boss）：壁に触れると壁の耐久を7削り、城に着いても消えずに攻撃し続ける。
##   砲台要塞（boss2）：その場から動かず、いろんな弾幕と城狙いの砲撃をしてくる。

const BulletScript := preload("res://scripts/bullet.gd")
const EnemyShellScript := preload("res://scripts/enemy_shell.gd")

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
var is_boss := false
## 何体目のボスか（1始まり。強さに使う）
var boss_rank := 1
## 分裂の魔獣：何回分裂したあとの体か（0〜4。4まで分裂すると16体）
var split_gen := 0
const MAX_SPLIT := 4
## ボスの名前（HPバーに表示）
var boss_title := ""
## 砲台要塞の攻撃パターン
var _pattern := 0
var _pattern_left := 0.0
var _pattern_tick := 0.0
var _pattern_count := 0
var _spiral_angle := 0.0
## 迫撃砲・砲台要塞の砲身の反動
var _recoil := 0.0
var _hp_mult := 1.0
## 黒衣の大司教の力で、もう1回復活したか（1回だけ復活する）
var _revived := false
## 黒衣の大司教：ふわふわ漂う動きと、号令（全員の全方位射撃）のタイマー
var _bishop_t := 0.0
var _bishop_cd := 3.0
var _skill_cd := 3.0
var _summon_cd := 8.0
var _heal_fx := 0.0
var _wall_cd := 0.0
var dead := false

var knock := Vector2.ZERO
## ノックバックのクールタイム（どんな攻撃でも、押されるのは1秒に1回だけ）
const KB_COOLDOWN := 1.0
var _kb_cd := 0.0
var _facing := Vector2.RIGHT
var _shoot_cd := 1.5
var _contact_cd := 0.0
var _flash := 0.0
var _strafe_sign := 1.0
var speed_mult := 1.0
## 落とし穴で動けない残り時間
var stun_left := 0.0
## 弱点看破（狙撃部隊）：この時間のあいだ受けるダメージ +20%
var mark_left := 0.0
## 仁王立ちで挑発されている残り時間（このあいだは重装兵を狙う）
var provoked_left := 0.0
## 混乱（虹の矢・ペットの踊り）：この時間のあいだ、ふらふらと変な方向へ歩く
var confuse_left := 0.0
## 居座り岩・トゲの柵の上：この時間のあいだ足が slow_ratio ぶん遅くなる
var slow_left := 0.0
var slow_ratio := 0.0
var _confuse_dir := Vector2.ZERO
var _confuse_turn := 0.0


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
		"splitter":
			max_hp = 45.0; speed = 60.0; damage = 8.0; castle_damage = 8.0; radius = 18.0; xp_value = 2
			color = Color(0.75, 0.85, 0.25)
		"splitling":
			max_hp = 10.0; speed = 95.0; damage = 4.0; castle_damage = 4.0; radius = 9.0; xp_value = 1
			color = Color(0.85, 0.95, 0.35)
		"healer":
			max_hp = 150.0; speed = 50.0; damage = 4.0; castle_damage = 6.0; radius = 14.0; xp_value = 3
			color = Color(1.0, 0.6, 0.8)
		"bomber":
			max_hp = 25.0; speed = 120.0; damage = 30.0; castle_damage = 30.0; radius = 13.0; xp_value = 2
			color = Color(0.35, 0.1, 0.1)
		"stealth":
			max_hp = 15.0; speed = 160.0; damage = 8.0; castle_damage = 10.0; radius = 12.0; xp_value = 2
			color = Color(0.3, 0.35, 0.45)
		"boss":
			max_hp = 770.0 * (1.0 + 0.3 * (boss_rank - 1)); speed = 20.0; damage = 30.0
			castle_damage = 40.0; radius = 46.0; xp_value = 60
			color = Color(0.4, 0.12, 0.5)
			is_boss = true
			boss_title = "破城の魔王"
		"mortar":
			max_hp = 40.0; speed = 0.0; damage = 6.0; castle_damage = 6.0; radius = 16.0; xp_value = 3
			color = Color(0.45, 0.42, 0.3)
		"ringer":
			max_hp = 45.0; speed = 45.0; damage = 7.0; castle_damage = 8.0; radius = 17.0; xp_value = 3
			color = Color(0.85, 0.15, 0.2)
			_skill_cd = randf_range(1.0, 5.0)
		"seeker":
			max_hp = 50.0; speed = 0.0; damage = 10.0; castle_damage = 0.0; radius = 16.0; xp_value = 4
			color = Color(0.3, 0.4, 0.35)
		"boss2":
			max_hp = 412.5 * (1.0 + 0.3 * (boss_rank - 1)); speed = 0.0; damage = 20.0
			castle_damage = 0.0; radius = 50.0; xp_value = 60
			color = Color(0.3, 0.32, 0.4)
			is_boss = true
			boss_title = "砲台要塞"
			# 出てきてすぐ、全方位ぐるぐる射撃から始める
			_pattern = 3
			_pattern_left = 0.0
		"boss4":
			# 黒衣の大司教：画面の上のほうに浮かんで漂う。自分では戦わず、ほかの敵を強くする
			max_hp = 1500.0; speed = 0.0; damage = 10.0; castle_damage = 0.0; radius = 40.0; xp_value = 80
			color = Color(0.16, 0.12, 0.2)
			is_boss = true
			boss_title = "黒衣の大司教"
		"boss3":
			# 分裂するたびにHPは半分、体は小さく、足は速くなる
			# 最初の体のHPは 123.75。分かれた体ぜんぶの合計（最初の体の5倍 = 618.75）が、砲台要塞（412.5）の1.5倍になる
			var shrink := pow(0.5, split_gen)
			max_hp = 123.75 * (1.0 + 0.3 * (boss_rank - 1)) * shrink; speed = 22.0 * pow(1.18, split_gen); damage = 20.0 * pow(0.75, split_gen)
			castle_damage = 36.0 * pow(0.6, split_gen); radius = 44.0 * pow(0.78, split_gen)
			xp_value = [40, 20, 10, 6, 4][split_gen]
			color = Color(0.35, 0.75, 0.4).lerp(Color(0.6, 0.95, 0.5), split_gen / 4.0)
			is_boss = true
			boss_title = "分裂の魔獣"
			_skill_cd = randf_range(1.0, 3.0)
	_hp_mult = hp_mult
	max_hp *= hp_mult
	hp = max_hp
	if not is_boss:
		speed *= randf_range(0.9, 1.1)
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_shoot_cd = randf_range(2.0, 4.0) if k == "mortar" or k == "seeker" else randf_range(1.0, 2.5)
	add_to_group("enemies")


func _process(delta: float) -> void:
	if dead:
		return
	_flash -= delta
	_contact_cd -= delta
	mark_left -= delta
	provoked_left -= delta
	_kb_cd -= delta
	confuse_left -= delta
	slow_left -= delta
	if stun_left > 0.0:
		# 落とし穴にはまって動けない（攻撃もできない）
		stun_left -= delta
		position += knock * delta
		knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
		position = game.clamp_to_map(position, radius)
		queue_redraw()
		return
	if kind == "mortar" or kind == "boss2" or kind == "seeker":
		_update_stationary(delta)
		return
	if kind == "boss4":
		_update_bishop(delta)
		return
	var castle: Node2D = game.castle
	var move := Vector2.ZERO
	if kind == "boss3":
		_split_boss_skills(delta)
	elif is_boss:
		_boss_skills(delta)
	elif kind == "healer":
		_heal_skill(delta)
	elif kind == "ringer":
		_ring_skill(delta)
	# 基本は城へ。近くに兵士がいればそちらを狙う
	var aggro := 300.0 if ranged else 110.0
	if hunter:
		aggro = INF
	elif kind == "bomber":
		aggro = 300.0
	elif kind == "healer" or kind == "ringer" or is_boss:
		aggro = 0.0
	# 弓兵は城だけを狙う（兵士・挑発・氷像には引きつけられない）
	var castle_only := kind == "archer"
	if castle_only:
		aggro = 0.0
	var soldier: Node2D = game.nearest_ally(global_position, aggro)
	# 挑発：近くに迎撃兵がいればそちらを狙う
	if game.guard_stats.taunt and not castle_only:
		var g := _nearest_guard(230.0)
		if g != null:
			soldier = g
	# 仁王立ち：挑発されているあいだは重装兵を狙う（ボスは挑発されない）
	if provoked_left > 0.0 and not is_boss and not castle_only:
		var h: Node2D = game.heavy
		if h != null and not h.dead:
			soldier = h
	# 氷像の囮：近くに氷像があれば、何よりも先にそちらを狙う
	if game.castle.ice_statue and not is_boss and not castle_only:
		var st: Node2D = _nearest_statue(320.0)
		if st != null:
			soldier = st
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
		# 射程は無限（どこからでも撃つ。城へ近づく動きはそのまま）
		if _shoot_cd <= 0.0 and confuse_left <= 0.0:
			# 城への弾は少し弱い。遠くからでも届くように、弾は届くまで消えない
			_shoot(dir, damage if soldier != null else damage * 0.5, 260.0, 7.0, Color(0.85, 0.45, 1.0), d / 260.0 + 1.0)
			_shoot_cd = randf_range(2.2, 3.0)
	elif hunter and soldier == null and d < 20.0:
		move = Vector2.ZERO
	elif kind == "healer" and soldier == null and global_position.distance_to(castle.global_position) < 400.0:
		# 治癒師は後方（城から離れた所）にとどまる
		move = Vector2.ZERO
	else:
		move = dir
	# 兵士への体当たり
	var touching: Node2D = game.nearest_ally(global_position, radius + 16.0)
	if touching != null and kind == "bomber":
		_bomber_explode()
		return
	if touching != null and _contact_cd <= 0.0:
		touching.take_damage(damage, global_position)
		_contact_cd = 0.6
	if is_boss:
		# ボスは壁を壊して進み、城に着いたら殴り続ける
		# ボスは壁に触れると壁の耐久を7減らし、大きく弾かれる
		_wall_cd -= delta
		var wi: int = game.walls.hit_test(global_position, radius)
		if wi >= 0 and _wall_cd <= 0.0:
			game.walls.spike_hit(wi, global_position)
			game.walls.damage_wall(wi, 7.0)
			# ボス自身はダメージを受けず、ランダムな方向へ大きく弾かれる（だいたい100くらい・気絶はしない）
			# 下側（城の方）へは弾かれない
			# （knock は毎秒1400ずつ弱まるので、進む距離 = 速さ² ÷ 2800）
			knock = Vector2.from_angle(randf_range(PI + 0.15, TAU - 0.15)) * sqrt(2800.0 * 100.0)
			_wall_cd = 1.0
		if castle.distance_to_point(global_position) < radius:
			move = Vector2.ZERO
			if _contact_cd <= 0.0:
				castle.take_damage(castle_damage)
				_contact_cd = 2.0
	elif not hunter and not _check_wall():
		return
	# 城に触れたら消滅して城にダメージ（経験値は入らない）
	if not hunter and not is_boss and castle.distance_to_point(global_position) < radius:
		if kind == "bomber":
			_bomber_explode()
			return
		castle.take_damage(castle_damage)
		dead = true
		remove_from_group("enemies")
		game.spawn_burst(global_position, color, radius)
		queue_free()
		return

	if confuse_left > 0.0:
		# 混乱中：ときどき向きを変えながら、ふらふら歩く（攻撃はしない）
		_confuse_turn -= delta
		if _confuse_turn <= 0.0:
			_confuse_turn = 0.4
			_confuse_dir = Vector2.from_angle(randf() * TAU)
		move = _confuse_dir
	speed_mult = castle.slow_factor_at(global_position)
	# ボスはHPが減るほど速くなる（HP満タンで0.5倍 → 残り20%で1倍。それ以上は速くならない）
	if is_boss:
		var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		speed_mult *= 0.5 + 0.5 * clampf((1.0 - ratio) / 0.8, 0.0, 1.0)
	if slow_left > 0.0:
		speed_mult *= 1.0 - slow_ratio
	position += (move * speed * speed_mult + knock) * delta
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	_separate()
	position = game.clamp_to_map(position, radius)
	queue_redraw()


func _nearest_statue(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for s in get_tree().get_nodes_in_group("placed_ice_statue"):
		if s.dead:
			continue
		var d: float = global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _nearest_guard(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for g in game.guards:
		if g.dead:
			continue
		var d: float = global_position.distance_to(g.global_position)
		if d < best_d:
			best_d = d
			best = g
	return best


## 壁に触れたら、壁の耐久を削って、この敵はHP半分・大きく弾き飛ばされて1秒気絶（false を返す）
func _check_wall() -> bool:
	var wi: int = game.walls.hit_test(global_position, radius)
	if wi < 0:
		return true
	# 剣山の壁：トゲが飛び出す（壁が壊れる前に）
	game.walls.spike_hit(wi, global_position)
	# 体当たりした敵は壁の耐久を5削る（自爆兵はその3倍）
	if wi >= game.walls.walls.size():
		return false
	game.walls.absorb(wi, global_position, 15.0 if kind == "bomber" else 5.0)
	if kind == "bomber":
		# 自爆兵はその場で爆発して消える
		game.spawn_burst(global_position, Color(1.0, 0.4, 0.1), 40.0)
		dead = true
		remove_from_group("enemies")
		game.spawn_burst(global_position, color, radius)
		queue_free()
		return false
	game.spawn_burst(global_position, color, radius)
	# HPが半分になる（倒れはしない）。ダメージは築城部隊の手柄
	var src: Dictionary = game.builders[0].record if not game.builders.is_empty() else {}
	take_damage(hp * 0.5, Vector2.ZERO, src)
	if dead:
		return false
	# 1秒気絶して、上側のランダムな方向へ大きく弾き飛ばされる（だいたい170くらい）
	# （knock は毎秒1400ずつ弱まるので、進む距離 = 速さ² ÷ 2800）
	stun(1.0)
	knock = Vector2.from_angle(randf_range(PI + 0.35, TAU - 0.35)) * sqrt(2800.0 * 170.0)
	return false


## ボスの技：全方位への弾と、手下の呼び出し
func _boss_skills(delta: float) -> void:
	_skill_cd -= delta
	_summon_cd -= delta
	if _skill_cd <= 0.0:
		_skill_cd = 5.0
		var n := 16
		for i in n:
			_shoot(Vector2.from_angle(TAU * i / n + randf() * 0.2), 12.0 * (1.0 + 0.3 * (boss_rank - 1)))
	if _summon_cd <= 0.0:
		_summon_cd = 12.0
		for i in 5:
			game.spawn_enemy_at("grunt", global_position + Vector2.from_angle(TAU * i / 5.0) * (radius + 30.0))


## 誘導砲兵の狙い：迎撃と設置物以外で一番近い味方
func _seeker_target() -> Node2D:
	var list: Array = game.soldiers + game.knights
	if game.heavy != null:
		list.append(game.heavy)
	var best: Node2D = null
	var best_d := INF
	for a in list:
		if not is_instance_valid(a) or a.dead:
			continue
		var d: float = global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


## 動かない敵（迫撃砲・砲台要塞）：その場で城の方を向いて撃ち続ける
func _update_stationary(delta: float) -> void:
	var castle: Node2D = game.castle
	_facing = (castle.global_position - global_position).normalized()
	_recoil -= delta
	if kind == "mortar":
		_shoot_cd -= delta
		if _shoot_cd <= 0.0:
			_shoot_cd = randf_range(6.0, 8.0)
			_lob_at_castle(damage, 45.0, 8.0)
	elif kind == "seeker":
		# 一番近いキャラクター（遊撃・近衛・重装）へ誘導弾（いなければ撃たない）
		# 迎撃と、見張り櫓・かかしなどの設置物は狙わない
		var t: Node2D = _seeker_target()
		if t != null:
			_facing = (t.global_position - global_position).normalized()
			_shoot_cd -= delta
			if _shoot_cd <= 0.0:
				_shoot_cd = randf_range(2.0, 2.75)
				var b: Node2D = _shoot(_facing, damage, 190.0, 8.0, Color(1.0, 0.45, 0.2), 7.0)
				b.seek = t
				_recoil = 0.3
	else:
		_fortress_skills(delta)
	# 触れた兵士にはダメージ
	var touching: Node2D = game.nearest_ally(global_position, radius + 16.0)
	if touching != null and _contact_cd <= 0.0:
		touching.take_damage(damage, global_position)
		_contact_cd = 0.6
	# 動かない敵（砲台要塞・迫撃砲・誘導砲兵）はノックバック無効
	knock = Vector2.ZERO
	position = game.clamp_to_map(position, radius)
	queue_redraw()


## 城のどこかへ山なりの砲弾を撃つ（壁を飛び越える）
func _lob_at_castle(dmg: float, area: float, size: float) -> void:
	var castle: Node2D = game.castle
	var s := EnemyShellScript.new()
	s.game = game
	var muzzle := global_position + _facing * (radius + 6.0)
	s.start = muzzle
	s.position = muzzle
	var half: Vector2 = castle.HALF
	s.target = castle.global_position + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y) * 0.6)
	s.damage = dmg
	s.blast_radius = area
	s.size = size
	s.flight_time = clampf(muzzle.distance_to(s.target) / 320.0, 1.5, 3.2)
	game.effects.add_child(s)
	_recoil = 0.3


## 砲台要塞の技：いろんな弾幕を順番に。合間に城への砲撃
## 砲台要塞の攻撃パターン（くり返し）：
## 0 全方位ぐるぐる射撃×3 → 1 城狙いの連射 → 2 近くのキャラクターへ誘導弾10発 → 3 城狙いのビーム → 0 …
func _fortress_skills(delta: float) -> void:
	var rm := 1.0 + 0.3 * (boss_rank - 1)
	# 城を狙う攻撃は、出るたびに少しずつ強くなる
	var crm := 1.0 + 0.15 * (boss_rank - 1)
	var dmg := 10.0 * rm
	var to_castle: Vector2 = (game.castle.global_position - global_position).normalized()
	_pattern_left -= delta
	_pattern_tick -= delta
	if _pattern_left <= 0.0:
		# 次の攻撃パターンへ（少し休んでから）
		_pattern = (_pattern + 1) % 4
		_pattern_left = 99.0
		_pattern_tick = 0.8
		_pattern_count = 0
		return
	if _pattern_tick > 0.0:
		return
	match _pattern:
		0:
			# 全方位ぐるぐる射撃：10本の腕（濃い弾幕）がぐるっと1周するのを3回（回るペースは前と同じ）
			_pattern_tick = 0.07
			_spiral_angle += TAU / 24.0
			for arm in 10:
				_shoot(Vector2.from_angle(_spiral_angle + TAU * arm / 10.0), dmg, 220.0, 7.0, Color(0.95, 0.5, 1.0), 4.5)
			if _pattern_count >= 24 * 3 - 1:
				_pattern_left = 0.0
		1:
			# 城狙いの連射（城に当たるとそのままのダメージ。壁があれば壁が防ぐ）
			_pattern_tick = 0.12
			var b: Node2D = _shoot(to_castle.rotated(randf_range(-0.05, 0.05)), 5.0 * crm, 380.0, 8.0, Color(1.0, 0.3, 0.2), 4.0)
			b.castle_ratio = 1.0
			if _pattern_count >= 15:
				_pattern_left = 0.0
		2:
			# 一番近いキャラクターへ誘導弾を10発（いなければ城へまっすぐ）
			_pattern_tick = 0.18
			var t: Node2D = game.nearest_ally(global_position, INF)
			var aim: Vector2 = (t.global_position - global_position).normalized() if t != null else to_castle
			var m: Node2D = _shoot(aim.rotated(randf_range(-0.6, 0.6)), dmg * 1.2, 230.0, 8.0, Color(1.0, 0.45, 0.2), 6.0)
			if t != null:
				m.seek = t
			if _pattern_count >= 9:
				_pattern_left = 0.0
		3:
			# 城狙いのビーム：1秒前に予告線を出してから、城までの線上にあるものを全部まとめて撃ち抜く
			if _pattern_count == 0:
				var warn: Node2D = game.spawn_fun_fx("beam_warn", global_position)
				warn.end = game.castle.global_position
				_pattern_tick = 1.0
			else:
				_fire_beam(dmg, crm)
				_pattern_left = 0.0
	_pattern_count += 1
	_recoil = 0.15


## 砲台要塞のビーム：城までの一直線上の味方・壁・城にまとめてダメージ
func _fire_beam(dmg: float, crm: float) -> void:
	var from := global_position
	var to: Vector2 = game.castle.global_position
	var fx: Node2D = game.spawn_fun_fx("beam", from)
	fx.end = to
	const WIDTH := 30.0
	# 線上の味方（兵士・設置物など）
	for a in game.allies():
		if a.dead:
			continue
		var p: Vector2 = Geometry2D.get_closest_point_to_segment(a.global_position, from, to)
		if p.distance_to(a.global_position) < WIDTH + a.radius:
			a.take_damage(dmg * 3.0, from)
	# 線が通る場所の壁（耐久を5削る）
	var walls: Node2D = game.walls
	var cross: Vector2 = to + (from - to).normalized() * walls.RADIUS
	var wi: int = walls.hit_test(cross, WIDTH)
	if wi >= 0:
		walls.damage_wall(wi, 5.0)
	# 城
	game.castle.take_damage(30.0 * crm)
	game.spawn_burst(to + (from - to).normalized() * 60.0, Color(1.0, 0.4, 0.3), 40.0)


## 弾幕兵：5秒ごとに全方位へ赤い弾を10発
func _ring_skill(delta: float) -> void:
	_skill_cd -= delta
	if _skill_cd > 0.0:
		return
	_skill_cd = 5.0
	_spiral_angle += 0.3
	for i in 10:
		_shoot(Vector2.from_angle(TAU * i / 10.0 + _spiral_angle), damage, 220.0, 6.0, Color(1.0, 0.15, 0.15), 3.0)
	_recoil = 0.3


## 分裂の魔獣の技：全方位へ弾を撃ちながら城へ進む（小さい体ほど弾は少なく弱い）
func _split_boss_skills(delta: float) -> void:
	_skill_cd -= delta
	if _skill_cd > 0.0:
		return
	_skill_cd = 3.5
	var n: int = [20, 14, 10, 8, 6][split_gen]
	var dmg := 11.0 * (1.0 + 0.3 * (boss_rank - 1)) * pow(0.75, split_gen)
	_spiral_angle += 0.5
	for i in n:
		_shoot(Vector2.from_angle(TAU * i / n + _spiral_angle), dmg, 230.0, 7.0 - split_gen, Color(0.55, 1.0, 0.5), 3.5)


## 分裂の魔獣：倒されたら少し小さい体2体に分かれる
func _split() -> void:
	for i in 2:
		var side := Vector2.from_angle(PI * i + randf_range(-0.4, 0.4)) * radius * 0.7
		var child: Node2D = get_script().new()
		child.game = game
		child.boss_rank = boss_rank
		child.split_gen = split_gen + 1
		child.setup("boss3", _hp_mult)
		child.position = game.clamp_to_map(global_position + side, 20.0)
		child.knock = side.normalized() * 260.0
		child.knock.y = minf(child.knock.y, 0.0)
		game.world.add_child(child)
	game.spawn_burst(global_position, Color(0.6, 1.0, 0.5), radius)


## 治癒師：3秒ごとに周りの敵を回復
func _heal_skill(delta: float) -> void:
	_heal_fx -= delta
	_skill_cd -= delta
	if _skill_cd > 0.0:
		return
	_skill_cd = 3.0
	var healed := false
	for e in game.enemies_near(global_position, 150.0):
		if e == self or not is_instance_valid(e) or e.dead or e.hp >= e.max_hp:
			continue
		if global_position.distance_to(e.global_position) < 150.0:
			# ボスは回復しにくい（2%だけ）
			e.hp = minf(e.max_hp, e.hp + e.max_hp * (0.02 if e.is_boss else 0.25))
			healed = true
	if healed:
		_heal_fx = 0.5


## 自爆兵の爆発：周りの味方と城にダメージ
func _bomber_explode() -> void:
	for a in game.allies():
		if not a.dead and global_position.distance_to(a.global_position) < 80.0 + a.radius:
			a.take_damage(damage, global_position)
	if game.castle.distance_to_point(global_position) < 80.0:
		game.castle.take_damage(castle_damage)
	game.spawn_burst(global_position, Color(1.0, 0.4, 0.1), 40.0)
	game.spawn_burst(global_position, Color(1.0, 0.85, 0.3), 25.0)
	dead = true
	remove_from_group("enemies")
	queue_free()


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
	# ボスは下側（城の方）には押されない
	if is_boss and push.y > 0.0:
		push.y = 0.0
	position += push * 0.5


func _shoot(dir: Vector2, dmg: float, spd: float = 260.0, r: float = 7.0, col: Color = Color(0.85, 0.45, 1.0), life: float = 3.0) -> Node2D:
	var b := BulletScript.new()
	b.game = game
	b.from_enemy = true
	b.velocity = dir * spd
	b.damage = dmg
	b.radius = r
	b.color = col
	b.life = life
	b.position = global_position + dir * (radius + 4.0)
	# ボスの弾は、味方・壁に2回当たるまで突き抜ける
	b.boss_pierce = is_boss
	# 砲台要塞の弾幕は兵士向け。城に当たったときは2割のダメージ
	if kind == "boss2":
		b.castle_ratio = 0.2
	game.world.add_child(b)
	return b


## 射撃によるノックバック。射撃は下側（城の方）へは押さない
func shot_knockback(kb: Vector2) -> void:
	kb.y = minf(kb.y, 0.0)
	apply_knock(kb)


## 攻撃で押す。どんな攻撃でも、同じ敵が押されるのは1秒に1回だけ。城に近づく向きには押さない
func apply_knock(kb: Vector2) -> void:
	if dead or kb.length_squared() < 1.0 or _kb_cd > 0.0 or _kb_mult() <= 0.0:
		return
	_kb_cd = KB_COOLDOWN
	knock += no_castle_push(kb * _kb_mult())
	# ボスは下側（城の方）には押されない
	if is_boss and knock.y > 0.0:
		knock.y = 0.0


## 押す力から「城に近づく向き」の分を取りのぞく（攻撃で城側へは押されない）
func no_castle_push(v: Vector2) -> Vector2:
	var to_castle: Vector2 = (game.castle.global_position - global_position).normalized()
	var toward := v.dot(to_castle)
	if toward > 0.0:
		v -= to_castle * toward
	return v


## 攻撃で押される強さの倍率。大型は吹き飛びにくい
## 破城の魔王・分裂の魔獣は重いので押されにくい（ふつうの敵の4割）。砲台要塞・迫撃砲・誘導砲兵は押されない
func _kb_mult() -> float:
	if kind == "boss2" or kind == "mortar" or kind == "seeker" or kind == "boss4":
		return 0.0
	if is_boss:
		return 0.4
	return 0.3 if kind == "brute" else 1.0


func confuse(seconds: float) -> void:
	# ボスはほとんど混乱しない
	confuse_left = maxf(confuse_left, seconds * (0.2 if is_boss else 1.0))


## しばらく足を遅くする（ratio = 遅くする割合。重なったら強いほう）
func slow(seconds: float, ratio: float) -> void:
	if slow_left <= 0.0:
		slow_ratio = ratio
	else:
		slow_ratio = maxf(slow_ratio, ratio)
	slow_left = maxf(slow_left, seconds)


func stun(seconds: float) -> void:
	# ボスはほとんど気絶しない
	stun_left = maxf(stun_left, seconds * (0.15 if is_boss else 1.0))
	knock = Vector2.ZERO


## src = 攻撃した味方の戦績カード（記録しないときは空）
func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, src: Dictionary = {}) -> void:
	if dead:
		return
	if mark_left > 0.0:
		amount *= 1.2
	# 城の怒り：城のHPが50%より少ないとき、味方の与ダメージ +20%
	if game.castle.rage_active():
		amount *= 1.2
	# 魔王狩り：遊撃兵からボスへのダメージ +10%
	if is_boss and game.stats.boss_hunt and src.get("cat", "") == "soldier":
		amount *= 1.1
	# 城ロボ起動中：城にくっついている兵装（矢倉・大砲・投石器・バリスタ）の与ダメージ +15%
	if src.get("robot_boost", false) and game.castle.robot_active():
		amount *= game.castle.ROBOT_BOOST
	# 黒衣の大司教がいるあいだは、倒されたザコ敵が1回だけその場でHP50%で復活する
	var revive: bool = hp - amount <= 0.0 and not is_boss and not _revived and game.bishop_alive()
	if not src.is_empty():
		var dealt := minf(amount, hp)
		var killed: bool = hp - amount <= 0.0 and not revive
		var rec: Dictionary = src
		# 特別強化のダメージ（game.sp_src で作ったカード）は、元の兵士の戦績にも入れて、特別強化ごとにも記録する
		if src.has("sp_id"):
			rec = game.records[src["rec_idx"]]
			var by: Dictionary = rec.get_or_add("sp_dealt", {})
			by[src["sp_id"]] = float(by.get(src["sp_id"], 0.0)) + dealt
		rec["dealt"] += dealt
		if killed:
			rec["kills"] += 1
	hp -= amount
	_flash = 0.1
	apply_knock(knockback)
	game.spawn_damage_text(global_position, amount, Color(1, 1, 1))
	if revive:
		_revived = true
		hp = max_hp * 0.5
		game.spawn_burst(global_position, Color(0.6, 0.3, 0.9), radius * 1.6)
		queue_redraw()
		return
	if hp <= 0.0:
		_die()


## ダメージなしで、その場で倒す（近衛兵の突進が隠密兵に当たったとき）。
## 黒衣の大司教がいれば、ふつうに倒したときと同じく1回だけ復活する
func instant_kill(src: Dictionary = {}) -> void:
	if dead:
		return
	if not is_boss and not _revived and game.bishop_alive():
		_revived = true
		hp = max_hp * 0.5
		game.spawn_burst(global_position, Color(0.6, 0.3, 0.9), radius * 1.6)
		queue_redraw()
		return
	if not src.is_empty():
		var rec: Dictionary = game.records[src["rec_idx"]] if src.has("sp_id") else src
		rec["kills"] += 1
	hp = 0.0
	_die()


func _die() -> void:
	if true:
		dead = true
		remove_from_group("enemies")
		# 分裂の魔獣は、倒されたことを知らせる前に分かれる（残りの体がいるかの判定のため）
		if kind == "boss3" and split_gen < MAX_SPLIT:
			_split()
		game.on_enemy_killed(self)
		# 分裂体は小さな分裂体3体に分かれる
		if kind == "splitter":
			for i in 3:
				game.spawn_enemy_at("splitling", global_position + Vector2.from_angle(TAU * i / 3.0 + randf()) * 16.0, _hp_mult)
		queue_free()


## 黒衣の大司教：画面の上のほうをゆっくり左右に漂い、10秒ごとに「号令」でほかの敵全員に全方位射撃をさせる
func _update_bishop(delta: float) -> void:
	_bishop_t += delta
	var rect: Rect2 = game.MAP_RECT
	var goal := Vector2(rect.get_center().x + sin(_bishop_t * 0.35) * rect.size.x * 0.35, rect.position.y + 130.0 + sin(_bishop_t * 0.9) * 25.0)
	position = position.move_toward(goal, 60.0 * delta)
	_bishop_cd -= delta
	if _bishop_cd <= 0.0:
		_bishop_cd = BISHOP_VOLLEY_INTERVAL
		_bishop_volley()
	queue_redraw()


const BISHOP_VOLLEY_INTERVAL := 10.0
const BISHOP_VOLLEY_SHOTS := 6


## 号令：大司教以外のすべての敵が、全方位へ貫通無限の弾を撃つ（壁は素通り。城に当たったら消える）
func _bishop_volley() -> void:
	game.spawn_burst(global_position, Color(0.65, 0.3, 0.95), 160.0)
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead or e.kind == "boss4":
			continue
		var base := randf() * TAU
		for i in BISHOP_VOLLEY_SHOTS:
			var dir := Vector2.from_angle(base + TAU * i / BISHOP_VOLLEY_SHOTS)
			var b: Node2D = e._shoot(dir, maxf(2.0, e.damage * 0.5), 210.0, 6.0, Color(0.7, 0.35, 1.0), 2.5)
			b.boss_pierce = true
			b._boss_hits_left = 1000000
			b.ignore_walls = true
			b.castle_ratio = 0.2


func _draw() -> void:
	# 隠密兵は半透明
	modulate.a = 0.45 if kind == "stealth" else 1.0
	if kind == "boss4":
		_draw_bishop()
		return
	draw_circle(Vector2(0, radius * 0.45), radius, Color(0, 0, 0, 0.3))
	# 大司教の力で復活した敵は、紫のもやをまとう
	if _revived:
		draw_circle(Vector2.ZERO, radius + 5.0, Color(0.6, 0.3, 0.9, 0.35))
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
		"splitter", "splitling":
			# ぷるぷるした塊（中に小さな粒）
			var wob := sin(Time.get_ticks_msec() / 150.0 + radius) * 1.5
			draw_circle(Vector2.ZERO, radius + wob, c)
			if kind == "splitter":
				for i in 3:
					draw_circle(Vector2.from_angle(TAU * i / 3.0) * radius * 0.45, radius * 0.22, Color(0.55, 0.65, 0.15))
		"healer":
			draw_circle(Vector2.ZERO, radius, c)
			# 十字マーク
			draw_rect(Rect2(Vector2(-3, -radius * 0.7), Vector2(6, radius * 1.4)), Color(1, 1, 1))
			draw_rect(Rect2(Vector2(-radius * 0.7, -3), Vector2(radius * 1.4, 6)), Color(1, 1, 1))
			if _heal_fx > 0.0:
				draw_arc(Vector2.ZERO, 150.0 * (1.0 - _heal_fx), 0.0, TAU, 40, Color(0.5, 1.0, 0.6, _heal_fx * 1.6), 3.0)
		"bomber":
			draw_circle(Vector2.ZERO, radius, c)
			# 導火線と火花
			var top := -_facing * radius
			draw_line(top, top - _facing * 8.0 + _facing.orthogonal() * 4.0, Color(0.7, 0.6, 0.4), 2.0)
			if int(Time.get_ticks_msec() / 100) % 2 == 0:
				draw_circle(top - _facing * 9.0 + _facing.orthogonal() * 4.0, 3.5, Color(1.0, 0.8, 0.2))
		"boss":
			# 大きな体とトゲ、王冠
			for i in 10:
				var a := TAU * i / 10.0 + Time.get_ticks_msec() / 2000.0
				draw_colored_polygon(PackedVector2Array([
					Vector2.from_angle(a - 0.15) * radius * 0.9, Vector2.from_angle(a) * radius * 1.3,
					Vector2.from_angle(a + 0.15) * radius * 0.9]), Color(0.25, 0.08, 0.3))
			draw_circle(Vector2.ZERO, radius, c)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.15, 0.05, 0.2), 4.0)
			var crown_y := -radius - 4.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(-22, crown_y), Vector2(-22, crown_y - 14), Vector2(-11, crown_y - 6), Vector2(0, crown_y - 18),
				Vector2(11, crown_y - 6), Vector2(22, crown_y - 14), Vector2(22, crown_y)]), Color(1.0, 0.82, 0.25))
		"ringer":
			# 赤いトゲトゲの玉。撃つ前は光る
			var spin := Time.get_ticks_msec() / 400.0
			for i in 8:
				var d := Vector2.from_angle(spin + TAU * i / 8.0)
				draw_colored_polygon(PackedVector2Array([d.rotated(0.25) * radius * 0.8, d * radius * 1.35, d.rotated(-0.25) * radius * 0.8]), Color(0.55, 0.05, 0.1))
			draw_circle(Vector2.ZERO, radius, c)
			var glow := clampf(1.0 - _skill_cd, 0.0, 1.0)
			draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 0.6 + 0.4 * glow, 0.5 * glow))
		"seeker":
			# 発射台と、狙った味方の方を向いたミサイルの筒（2本）
			draw_rect(Rect2(Vector2(-radius, -radius * 0.2), Vector2(radius * 2.0, radius)), Color(0.25, 0.28, 0.25))
			draw_circle(Vector2.ZERO, radius * 0.75, c)
			var side := _facing.orthogonal() * 5.0
			var back := -_facing * (4.0 if _recoil > 0.0 else 0.0)
			for sgn in [-1.0, 1.0]:
				draw_line(back + side * sgn, back + side * sgn + _facing * (radius + 10.0), Color(0.2, 0.22, 0.2), 7.0)
				draw_circle(back + side * sgn + _facing * (radius + 10.0), 3.0, Color(1.0, 0.4, 0.2))
		"boss3":
			# ぷるぷる揺れるスライム。分裂前の大きい体には王冠
			var wob := sin(Time.get_ticks_msec() / 180.0 + radius) * radius * 0.06
			draw_circle(Vector2(0, wob), radius + wob, c)
			draw_circle(Vector2(-radius * 0.3, -radius * 0.3 + wob), radius * 0.25, Color(1, 1, 1, 0.35))
			# 分かれる線（あと何回分裂できるか）
			for i in MAX_SPLIT - split_gen:
				var a := -PI / 2.0 + (i - (MAX_SPLIT - split_gen - 1) / 2.0) * 0.5
				draw_line(Vector2.from_angle(a) * radius * 0.4, Vector2.from_angle(a) * radius * 0.9, Color(0.15, 0.4, 0.15, 0.6), 2.0)
			if split_gen == 0:
				var crown_y := -radius - 2.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(-18, crown_y), Vector2(-18, crown_y - 12), Vector2(-9, crown_y - 5), Vector2(0, crown_y - 15),
					Vector2(9, crown_y - 5), Vector2(18, crown_y - 12), Vector2(18, crown_y)]), Color(1.0, 0.82, 0.25))
		"mortar":
			# 土台と、城の方へ斜め上に向いた太い砲身
			draw_rect(Rect2(Vector2(-radius, -radius * 0.3), Vector2(radius * 2.0, radius * 1.1)), Color(0.35, 0.25, 0.15))
			draw_circle(Vector2.ZERO, radius * 0.8, c)
			var tube := (_facing + Vector2(0, -1.2)).normalized()
			var back := tube * (-4.0 if _recoil > 0.0 else 0.0)
			draw_line(back, back + tube * (radius + 12.0), Color(0.2, 0.2, 0.22), 11.0)
			draw_circle(back + tube * (radius + 12.0), 6.0, Color(0.1, 0.1, 0.1))
		"boss2":
			# 石の要塞：城壁のギザギザと、回る砲台
			var r := radius
			draw_rect(Rect2(Vector2(-r, -r * 0.8), Vector2(r * 2.0, r * 1.6)), c.darkened(0.2))
			for i in 5:
				draw_rect(Rect2(Vector2(-r + i * r * 0.45, -r * 0.8 - 10.0), Vector2(r * 0.25, 10.0)), c.darkened(0.2))
			draw_rect(Rect2(Vector2(-r, -r * 0.8), Vector2(r * 2.0, r * 1.6)), Color(0.1, 0.1, 0.15), false, 3.0)
			draw_circle(Vector2.ZERO, r * 0.62, c)
			var spin := Time.get_ticks_msec() / 700.0
			for i in 4:
				var d := Vector2.from_angle(spin + TAU * i / 4.0)
				draw_line(d * r * 0.4, d * (r * 0.95 - (5.0 if _recoil > 0.0 else 0.0)), Color(0.15, 0.15, 0.18), 9.0)
			draw_line(_facing * (r * 0.4), _facing * (r + 18.0 - (6.0 if _recoil > 0.0 else 0.0)), Color(0.1, 0.1, 0.12), 14.0)
			draw_circle(Vector2.ZERO, r * 0.3, Color(0.9, 0.25, 0.3))
			var crown_y := -r * 0.8 - 12.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(-22, crown_y), Vector2(-22, crown_y - 14), Vector2(-11, crown_y - 6), Vector2(0, crown_y - 18),
				Vector2(11, crown_y - 6), Vector2(22, crown_y - 14), Vector2(22, crown_y)]), Color(1.0, 0.82, 0.25))
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
	if confuse_left > 0.0:
		# 混乱：頭の上でぐるぐる回る「？」
		var qa := Time.get_ticks_msec() / 200.0
		draw_string(ThemeDB.fallback_font, Vector2(cos(qa) * 6.0 - 4.0, -radius - 8.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.5, 1.0))
	if mark_left > 0.0:
		# 弱点看破：赤い照準マーク
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.2, 0.8), 2.0)
		for i in 4:
			var d := Vector2.from_angle(TAU * i / 4.0)
			draw_line(d * (radius + 3.0), d * (radius + 11.0), Color(1.0, 0.25, 0.2, 0.8), 2.0)
	if speed_mult < 1.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 20, Color(0.6, 0.9, 1.0, 0.8), 2.0)
	# HPバー
	if hp < max_hp:
		var w := radius * 2.0
		var top := Vector2(-radius, -radius - 9.0)
		draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * hp / max_hp, 4)), Color(0.9, 0.2, 0.2))


## 黒衣の大司教の絵：足元で回る紫の魔法陣、黒いローブとフード、光る目、杖
func _draw_bishop() -> void:
	var r := radius
	var t := Time.get_ticks_msec() / 1000.0
	var bob := sin(t * 2.0) * 4.0
	# 魔法陣（二重の輪と、回る文字の点）
	draw_arc(Vector2(0, r * 0.9), r * 1.5, 0.0, TAU, 48, Color(0.65, 0.3, 0.95, 0.6), 3.0)
	draw_arc(Vector2(0, r * 0.9), r * 1.15, 0.0, TAU, 40, Color(0.65, 0.3, 0.95, 0.4), 2.0)
	for i in 8:
		var a := t * 0.8 + TAU * i / 8.0
		draw_circle(Vector2(0, r * 0.9) + Vector2.from_angle(a) * r * 1.32, 4.0, Color(0.85, 0.6, 1.0, 0.8))
	var c := Color(1, 1, 1) if _flash > 0.0 else color
	# ローブ（すそが広がった三角）
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.45, -r * 0.4 + bob), Vector2(r * 0.45, -r * 0.4 + bob),
		Vector2(r * 0.95, r * 1.0 + bob), Vector2(-r * 0.95, r * 1.0 + bob)]), c)
	draw_line(Vector2(0, -r * 0.3 + bob), Vector2(0, r * 0.95 + bob), Color(0.45, 0.2, 0.6), 4.0)
	# フード
	draw_circle(Vector2(0, -r * 0.55 + bob), r * 0.5, c)
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.5, -r * 0.55 + bob), Vector2(0, -r * 1.25 + bob), Vector2(r * 0.5, -r * 0.55 + bob)]), c)
	draw_circle(Vector2(0, -r * 0.5 + bob), r * 0.32, Color(0.04, 0.02, 0.06))
	# 光る目
	var glow := 0.7 + 0.3 * sin(t * 6.0)
	draw_circle(Vector2(-r * 0.13, -r * 0.52 + bob), 3.5, Color(0.85, 0.45, 1.0, glow))
	draw_circle(Vector2(r * 0.13, -r * 0.52 + bob), 3.5, Color(0.85, 0.45, 1.0, glow))
	# 杖（先に紫の玉）
	draw_line(Vector2(r * 0.8, -r * 0.9 + bob), Vector2(r * 0.8, r * 0.9 + bob), Color(0.45, 0.32, 0.2), 4.0)
	draw_circle(Vector2(r * 0.8, -r * 0.95 + bob), 9.0, Color(0.7, 0.35, 1.0, 0.5 + 0.4 * glow))
	draw_circle(Vector2(r * 0.8, -r * 0.95 + bob), 5.0, Color(0.95, 0.85, 1.0))
	# 号令の直前は、魔法陣が強く光る
	if _bishop_cd < 1.0:
		draw_circle(Vector2.ZERO, r * 1.8, Color(0.7, 0.35, 1.0, 0.25 * (1.0 - _bishop_cd)))
