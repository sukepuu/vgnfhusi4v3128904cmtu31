extends Node2D
## 守るべき城。HPが0になったらゲームオーバー。
## 強化で迎撃システム（矢倉・大砲・投石器・バリスタ・氷結の結界）が増えていく。

const BulletScript := preload("res://scripts/bullet.gd")
const ShellScript := preload("res://scripts/shell.gd")
const RobotScript := preload("res://scripts/castle_robot.gd")

## 城本体の半分のサイズ（当たり判定もこの四角形）
const HALF := Vector2(95, 45)

var game: Node2D
var max_hp := 600.0
var hp := 600.0
## 城のHPの自然回復（毎秒1）。もっと回復させるには修理部隊が必要
var regen := 1.0
## これまでに回復したHPの合計（修理玉が「10秒で回復した量」を数えるのに使う）
var healed_total := 0.0
## 受けるダメージの倍率（修理部隊の「鉄壁補強」で下がる）
var damage_taken_mult := 1.0
## 背水の修繕：修理兵1人につき、城のHPが毎秒 OVERWORK_DRAIN ずつ減る（HP1より下にはならない）
var overwork := false
const OVERWORK_DRAIN := 20.0

# --- 矢倉（自動で矢を撃つ）
var tower_count := 0
var tower_interval := 0.9
var tower_damage := 48.0
var tower_range := 520.0
var _tower_cds: Array = [0.0, 0.3, 0.6, 0.15]
var _tower_aims: Array = [Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP]

# --- 大砲（範囲攻撃）。強化を取るたびに1門ずつ増える（最大3門）
const MAX_GUNS := 3
var cannon_level := 0
var cannon_interval := 4.0
var cannon_damage := 52.0
var cannon_radius := 90.0
var cannon_range := 650.0
var _cannon_cds: Array = [1.0, 2.3, 3.6]
var _cannon_aims: Array = [Vector2.UP, Vector2.UP, Vector2.UP]

# --- 投石器（大砲より範囲が広いが、発射間隔が長い）。最大3台
var catapult_level := 0
var catapult_interval := 9.0
var catapult_damage := 48.0
var catapult_radius := 150.0
var _catapult_cds: Array = [2.0, 5.0, 8.0]
var _catapult_swings: Array = [0.0, 0.0, 0.0]
# --- バリスタ（矢倉より発射間隔が長いが、高威力・射程無限・貫通無限）。最大3基
var ballista_level := 0
var ballista_interval := 4.0
var ballista_damage := 96.0
var _ballista_cds: Array = [1.0, 2.3, 3.6]
var _ballista_aims: Array = [Vector2.UP, Vector2.UP, Vector2.UP]
var _ballista_recoil: Array = [0.0, 0.0, 0.0]

## 直前に撃ち込んだ場所（同じ場所に重ねて撃たないように）
var _recent_shots: Array = []

# --- 氷結の結界（近くの敵を遅くする）
var frost_radius := 0.0
var frost_slow := 0.0

# --- 特別強化
var tower_shots := 1
var tower_pierce := 0
var scatter_level := 0
var fire_level := 0
var split_level := 0
var ballista_shots := 1
var bolt_blast_level := 0
var freeze_level := 0
var icicle_level := 0
var tower_crit := false
var rock_rain := false
var big_bolt := false
var blizzard := false
var arrow_rain := false
var ap_shell := false
var direct_hit := false
var blast_bolt := false
var ice_lance := false
## 5つ目の特別強化（新しい物を飛ばす・置く）
var homing_arrow := false
var cannon_mines := false
var rolling_rock := false
var lightning := false
var snowman := false
## おもしろ強化：ビリヤード砲弾・牛投げ・虹の矢
var billiard := false
var cow_throw := false
var rainbow_bolt := false
var _catapult_shots := 0
## 8つ目の特別強化
## 矢倉：爆裂矢（当たった敵が爆発して矢の3倍ダメージ）
var tower_blast := false
## 大砲：二連砲（1回に2発撃つ）
var double_cannon := false
## 投石器：居座り岩（着弾地点に岩が5秒残り、持続ダメージ＋足が30%遅くなる）
var stay_rock := false
## バリスタ：巨大弩砲（8秒ごとに3倍の大きさ・3倍の威力・1/3の速さの矢）
var mega_bolt := false
var _mega_cd := 4.0
## 結界：凍てつく大地（結界の中にずっとダメージ）
var frost_ground := false
## 9つ目の特別強化
## 矢倉・執念の矢（倒せなかった敵を狙い続け、続けるほど強くなる）
var tower_lock := false
var _tower_locks: Array = [null, null, null, null]
var _tower_stacks: Array = [0, 0, 0, 0]
## 大砲・置き土産（着弾地点に爆弾を置く）
var cannon_bomb := false
## 投石器・鉄塊投げ（4発に1回、HPが一番多い敵へ鉄塊）
var iron_chunk := false
## バリスタ・破竹の大矢（当たるたびに矢の威力 +10%）
var bolt_momentum := false
## 結界・氷像の囮（結界の中で倒された敵が氷像になる）
var ice_statue := false

# --- 城（本体）の特別強化
## 生命の泉：城の自然回復が毎秒3になる（regen を変える）
## 城の怒り：城のHPが50%より少ないとき、味方全員の与ダメージ +20%
var rage := false
## 不屈の城：HPが0になったとき、ボス以外の敵を全部消してHP20%で立ち直る（1回だけ）
var last_stand := false
var _last_stand_used := false
## 城レーザー：20秒ごとにマップ全体を薙ぎ払う（威力はレベル×10）
var laser := false
var _laser_cd := 6.0
var _laser_left := 0.0
var _laser_angle := 0.0
var _laser_hit := {}
const LASER_TIME := 2.0
## 城レーザーは正面（真上）から始まって、ぐるっと1周して正面で終わる
const LASER_START := PI * 1.5
## 城のくしゃみ：15秒ごとに、壁の内側くらいの敵を吹き飛ばす
var sneeze := false
var _sneeze_cd := 8.0
## 城の蓄え：城が受けたダメージ10ごとに経験値+1
var store := false
var _store_dmg := 0.0
## 城ロボ起動：30秒ごとにロボットが15秒間出撃する（そのあいだ兵装はロボットに付く）
var robot_enabled := false
## 城ロボ フライトモード・ファイナルモード（城ロボの戦い方が変わる）
var robot_flight := false
var robot_final := false
var _robot_cd := 10.0
var robot: Node2D = null
var _ground_tick := 0.0
var _homing_cd := 2.0
var _lightning_cd := 2.0
var _snowman_cd := 2.0
var _rain_cd := 4.0
var _ap_cd := 3.0
var _lance_cd := 2.0
var _blizzard_tick := 0.0
var _freeze_cd := 5.0
var _icicle_cd := 2.0

var _flash := 0.0
## 戦績カード（城の本体と、設備1基ずつ）
var record: Dictionary
var _equip_records := {}
var _t := 0.0


func _ready() -> void:
	record = game.new_record("castle", "城（本体）")


## 城ロボ起動中に与ダメージが上がる兵装と、その倍率
const ROBOT_BOOST_EQUIPS := ["tower", "cannon", "catapult", "ballista"]
const ROBOT_BOOST := 1.15


## 設備1基ごとの戦績カード（最初に使うときに作る）
func _equip_record(key: String, label: String, i: int) -> Dictionary:
	var k := "%s%d" % [key, i]
	if not _equip_records.has(k):
		_equip_records[k] = game.new_record("castle", "%s%d" % [label, i + 1])
		# 城にくっついている兵装（城ロボ起動中は城ロボに付いて、与ダメージ +15%）
		if key in ROBOT_BOOST_EQUIPS:
			_equip_records[k]["robot_boost"] = true
	return _equip_records[k]


func _process(delta: float) -> void:
	_t += delta
	_flash -= delta
	# 自然回復（毎秒 regen ずつ）。修理玉がためる「回復した量」にも入る
	if regen > 0.0 and hp > 0.0 and hp < max_hp:
		# 生命の泉で増えたぶん（基本の毎秒1を超えたぶん）は生命の泉の回復として記録
		heal(minf(regen, 1.0) * delta, record)
		if regen > 1.0:
			heal((regen - 1.0) * delta, record, "sp_castle_fountain")
	# 背水の修繕：城のHPが少しずつ減る（これで城が落ちることはない）
	if overwork and hp > 1.0 and not game.repairers.is_empty():
		hp = maxf(1.0, hp - OVERWORK_DRAIN * game.repairers.size() * delta)
	_update_towers(delta)
	_update_cannon(delta)
	_update_catapult(delta)
	_update_ballista(delta)
	_update_frost_specials(delta)
	_update_new_specials(delta)
	_update_castle_specials(delta)
	queue_redraw()


# ---------------------------------------------------------------- 当たり判定まわり

func body_rect() -> Rect2:
	return Rect2(global_position - HALF, HALF * 2.0)


func closest_point(p: Vector2) -> Vector2:
	var r := body_rect()
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


func distance_to_point(p: Vector2) -> float:
	return p.distance_to(closest_point(p))


func gate_position() -> Vector2:
	return global_position + Vector2(0, -HALF.y - 24.0)


## 氷結の結界の中なら速度倍率（1未満）を返す
func slow_factor_at(p: Vector2) -> float:
	if frost_radius > 0.0 and p.distance_to(global_position) < frost_radius:
		return 1.0 - frost_slow
	return 1.0


## 城のHPを回復する（回復した量は healed_total に足していく）。
## rec = 回復させた味方の戦績カード（回復量を記録する）、sp_id = 回復させた特別強化
func heal(amount: float, rec: Dictionary = {}, sp_id: String = "") -> void:
	var before := hp
	hp = minf(max_hp, hp + amount)
	healed_total += hp - before
	game.add_heal(rec, hp - before, sp_id)


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	amount *= damage_taken_mult
	record["taken"] += minf(amount, hp)
	hp -= amount
	_flash = 0.15
	game.spawn_damage_text(global_position + Vector2(randf_range(-60, 60), -HALF.y), amount, Color(1.0, 0.5, 0.2))
	# 城の蓄え：受けたダメージ10ごとに経験値+1
	if store:
		_store_dmg += amount
		while _store_dmg >= 10.0:
			_store_dmg -= 10.0
			game.add_xp(1)
	if hp <= 0.0:
		hp = 0.0
		# 不屈の城：1回だけ立ち直る
		if last_stand and not _last_stand_used:
			_do_last_stand()
			return
		game.on_castle_destroyed()


# ---------------------------------------------------------------- 迎撃システム

func _tower_local_pos(i: int) -> Vector2:
	match i:
		0: return Vector2(-HALF.x - 6.0, -HALF.y - 10.0)
		1: return Vector2(HALF.x + 6.0, -HALF.y - 10.0)
		2: return Vector2(-HALF.x * 0.45, -HALF.y - 22.0)
		_: return Vector2(HALF.x * 0.45, -HALF.y - 22.0)


func _update_towers(delta: float) -> void:
	for i in tower_count:
		_tower_cds[i] -= delta
		if _tower_cds[i] > 0.0:
			continue
		var from := wpos() + _tower_local_pos(i)
		var target: Node2D = game.nearest_enemy(from, tower_range)
		# 執念の矢：前に狙った敵がまだ生きていて射程内なら、また同じ敵を狙う
		var power := 1.0
		if tower_lock:
			var prev = _tower_locks[i]
			if prev != null and is_instance_valid(prev) and not prev.dead and from.distance_to(prev.global_position) < tower_range:
				target = prev
				_tower_stacks[i] = mini(_tower_stacks[i] + 1, 10)
			else:
				_tower_stacks[i] = 0
			_tower_locks[i] = target
			# 1回ごとに +20%、最大3倍
			power = 1.0 + 0.2 * _tower_stacks[i]
		if target == null:
			continue
		var aim := (target.global_position - from).normalized()
		_tower_aims[i] = aim
		# 連射なら少しずつ角度をずらして複数本
		for k in tower_shots:
			var dir := aim.rotated((k - (tower_shots - 1) / 2.0) * 0.12)
			var b := BulletScript.new()
			b.game = game
			b.velocity = dir * 760.0
			b.damage = tower_damage * power
			# 戦績の分け記録：連射で増えた矢 → 執念の矢 → 会心の一矢 の順に上書き
			var arrow_sp := "sp_tower_multi" if k > 0 else ""
			if power > 1.0:
				arrow_sp = "sp_tower_lock"
			# 会心の一矢：25%でダメージ3倍
			if tower_crit and randf() < 0.25:
				b.damage = tower_damage * power * 3.0
				b.radius = 6.0
				arrow_sp = "sp_tower_crit"
			b.pierce = tower_pierce
			b.radius = 4.0
			b.color = Color(0.95, 0.8, 0.55)
			if tower_lock and power > 1.0:
				# 執念がたまるほど赤く太い矢に
				b.color = Color(1.0, 0.8, 0.55).lerp(Color(1.0, 0.25, 0.2), (power - 1.0) / 2.0)
				b.radius = 4.0 + (power - 1.0) * 1.5
				if tower_shots == 1:
					# 狙った敵だけに当たる（手前の敵に吸われない）
					b.only_target = target
			b.src = _equip_record("tower", "矢倉", i)
			if tower_blast:
				b.explode_radius = 70.0
				b.explode_ratio = 3.0
				b.explode_src = game.sp_src(b.src, "sp_tower_blast")
			if arrow_sp != "":
				b.src = game.sp_src(b.src, arrow_sp)
			b.life = tower_range / 760.0 + 0.2
			b.position = from
			game.world.add_child(b)
		_tower_cds[i] = tower_interval


func _update_cannon(delta: float) -> void:
	for i in mini(cannon_level, MAX_GUNS):
		_cannon_cds[i] -= delta
		if _cannon_cds[i] > 0.0:
			continue
		var best := _densest_enemy(cannon_range, cannon_radius)
		if best == null:
			continue
		var from := wpos() + _cannon_local_pos(i)
		_cannon_aims[i] = (best.global_position - from).normalized()
		var rec := _equip_record("cannon", "大砲", i)
		var shells: Array = [_fire_shell(from, best.global_position, cannon_damage, cannon_radius, false, rec)]
		# 置き土産：着弾地点に爆弾を置く
		if cannon_bomb:
			shells[0].leave_bomb = cannon_damage * 1.5
		# ビリヤード砲弾：着弾後に2回跳ねる
		if billiard:
			shells[0].bounces = 2
		# 機雷散布：本命の砲弾が着弾地点に機雷をばらまく
		if cannon_mines:
			shells[0].mines = 3
			shells[0].mine_damage = cannon_damage * 1.2
		# 二連砲：もう1発、別の密集地へ撃つ（見つからなければ同じ所の近く）
		if double_cannon:
			var second := _densest_enemy(cannon_range, cannon_radius)
			var to2: Vector2 = second.global_position if second != null else best.global_position + Vector2.from_angle(randf() * TAU) * 80.0
			shells.append(_fire_shell(from + Vector2(8, 0), to2, cannon_damage, cannon_radius, false, game.sp_src(rec, "sp_double_cannon")))
		# 散弾砲：着弾地点の周りにも落ちる
		for k in scatter_level * 2:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(60.0, 110.0)
			shells.append(_fire_shell(from, best.global_position + off, cannon_damage * 0.7, cannon_radius * 0.8, false, game.sp_src(rec, "sp_scatter")))
		# 焼夷弾：着弾地点が燃える
		if fire_level > 0:
			for s in shells:
				s.fire_time = 4.0 + 2.0 * (fire_level - 1)
				s.fire_dps = cannon_damage * 0.3 * fire_level
		_cannon_cds[i] = cannon_interval


func _update_catapult(delta: float) -> void:
	for i in mini(catapult_level, MAX_GUNS):
		_catapult_swings[i] -= delta
		_catapult_cds[i] -= delta
		if _catapult_cds[i] > 0.0:
			continue
		var best := _densest_enemy(2000.0, catapult_radius)
		if best == null:
			continue
		var from := wpos() + _catapult_local_pos(i) + Vector2(0, -20)
		var s := _fire_shell(from, best.global_position, catapult_damage, catapult_radius, true, _equip_record("catapult", "投石器", i))
		if split_level > 0:
			s.split_count = 2 + 2 * split_level
		if direct_hit:
			s.direct_bonus = catapult_damage * 4.0
		if stay_rock:
			s.stay_rock = true
		# 牛投げ：3回に1回、岩のかわりに牛を投げる
		_catapult_shots += 1
		# 鉄塊投げ：4発に1回、HPが一番多い敵へ鉄塊も投げる
		if iron_chunk and _catapult_shots % 4 == 0:
			var big := _toughest_enemy_in(wpos(), INF)
			if big != null:
				# 威力：落ちた所の範囲に投石器×4、追いかけた敵への直撃に投石器×64
				var iron := _fire_shell(from + Vector2(10, 0), big.global_position, catapult_damage * 4.0, 50.0, true, game.sp_src(s.src, "sp_iron_chunk"))
				iron.iron = true
				iron.chase = big
				iron.direct_bonus = catapult_damage * 64.0
		if cow_throw and _catapult_shots % 3 == 0:
			s.cow = true
		if rolling_rock:
			s.roll_damage = catapult_damage * 1.2
		# 岩雨：ランダムな敵2体の頭上にも岩が落ちる
		if rock_rain:
			var pool: Array = game.enemies_cache.filter(func(e: Node2D) -> bool: return is_instance_valid(e) and not e.dead)
			pool.shuffle()
			for e in pool.slice(0, 2):
				game.spawn_blast(e.global_position, 1.0, 75.0, catapult_damage * 0.6, game.sp_src(s.src, "sp_rock_rain"), Color(0.75, 0.65, 0.5), "rock")
		_catapult_cds[i] = catapult_interval
		_catapult_swings[i] = 0.4


func _update_ballista(delta: float) -> void:
	for i in mini(ballista_level, MAX_GUNS):
		_ballista_recoil[i] -= delta
		_ballista_cds[i] -= delta
		if _ballista_cds[i] > 0.0:
			continue
		var from := wpos() + _ballista_local_pos(i)
		# HPが一番多い敵を最優先で狙う（射程は無限）
		var big := _toughest_enemy_in(wpos(), INF)
		if big == null:
			continue
		var aim := (big.global_position - from).normalized()
		_ballista_aims[i] = aim
		# 連装なら少しずつ横にずらして複数発。どれも狙った敵の真ん中へ向かう
		for k in ballista_shots:
			var offset := aim.orthogonal() * (k - (ballista_shots - 1) / 2.0) * 12.0
			var dir := (big.global_position - (from + offset)).normalized()
			var b := BulletScript.new()
			b.game = game
			b.velocity = dir * 1000.0
			b.damage = ballista_damage
			b.pierce = 1000000
			b.radius = 7.0
			if big_bolt:
				b.radius = 16.0
				b.scale = Vector2(1.8, 1.8)
			b.bolt = true
			# 破竹の大矢：当たるたびに威力 +10%
			if bolt_momentum:
				b.grow_on_hit = 0.1
			# 虹の矢：虹色の尾を引き、当たった敵を混乱させる
			if rainbow_bolt:
				b.rainbow = true
				b.confuse_on_hit = 1.5
			b.src = _equip_record("ballista", "バリスタ", i)
			# 連装で増えた矢は、連装のダメージとして記録
			if k > 0:
				b.src = game.sp_src(b.src, "sp_ballista_multi")
			b.life = 2.5
			b.position = from + offset
			if blast_bolt:
				b.first_blast_radius = 140.0
				b.first_blast_damage = ballista_damage * 1.5
				b.first_blast_src = game.sp_src(b.src, "sp_blast_bolt")
			if bolt_blast_level > 0:
				b.explode_radius = 40.0 + 15.0 * bolt_blast_level
				b.explode_ratio = 0.15 + 0.15 * bolt_blast_level
				b.explode_src = game.sp_src(b.src, "sp_ballista_blast")
			game.world.add_child(b)
		_ballista_cds[i] = ballista_interval
		_ballista_recoil[i] = 0.25


## 一直線上に一番多くの敵が並ぶ向き（敵がいなければ ZERO）
func _best_pierce_dir(from: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_n := 0
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var dir: Vector2 = (e.global_position - from).normalized()
		var n := 0
		for o in game.enemies_cache:
			if not is_instance_valid(o) or o.dead:
				continue
			var rel: Vector2 = o.global_position - from
			if rel.dot(dir) > 0.0 and absf(rel.dot(dir.orthogonal())) < o.radius + 7.0:
				n += 1
		if n > best_n:
			best_n = n
			best = dir
	return best


func _fire_shell(from: Vector2, to: Vector2, dmg: float, area: float, boulder: bool, src: Dictionary) -> Node2D:
	var s := ShellScript.new()
	s.src = src
	s.game = game
	s.start = from
	s.target = to
	s.damage = dmg
	s.blast_radius = area
	s.boulder = boulder
	if boulder:
		s.flight_time = 1.3
	s.position = from
	game.effects.add_child(s)
	_recent_shots.append({"pos": to, "area": area, "until": _t + s.flight_time + 0.3})
	return s


## 4つ目の特別強化（火矢の雨・徹甲榴弾・氷槍）
func _update_new_specials(delta: float) -> void:
	if arrow_rain and tower_count > 0:
		_rain_cd -= delta
		if _rain_cd <= 0.0:
			_rain_cd = 7.0
			for i in tower_count:
				var t := _densest_enemy(tower_range * 1.3, 120.0)
				if t == null:
					break
				var p: Vector2 = t.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
				game.spawn_blast(p, 0.8, 120.0, tower_damage * 4.0, game.sp_src(_equip_record("tower", "矢倉", i), "sp_arrow_rain"), Color(1.0, 0.55, 0.2), "arrow")
				_recent_shots.append({"pos": p, "area": 120.0, "until": _t + 1.2})
	if ap_shell and cannon_level > 0:
		_ap_cd -= delta
		if _ap_cd <= 0.0:
			_ap_cd = 6.0
			for i in mini(cannon_level, MAX_GUNS):
				var big := _toughest_enemy_in(wpos(), cannon_range * 1.5)
				if big == null:
					break
				var from := wpos() + _cannon_local_pos(i)
				var dir := (big.global_position - from).normalized()
				_cannon_aims[i] = dir
				var b := BulletScript.new()
				b.game = game
				b.velocity = dir * 1100.0
				b.damage = cannon_damage * 8.0
				b.radius = 10.0
				b.color = Color(1.0, 0.45, 0.2)
				b.life = 2.0
				b.only_target = big
				b.first_blast_radius = 50.0
				b.first_blast_damage = cannon_damage
				b.position = from
				b.src = game.sp_src(_equip_record("cannon", "大砲", i), "sp_ap_shell")
				game.world.add_child(b)
	_update_fifth_specials(delta)
	_update_eighth_specials(delta)
	if ice_lance and frost_radius > 0.0:
		_lance_cd -= delta
		if _lance_cd <= 0.0:
			_lance_cd = 3.0
			var big := _toughest_enemy_in(global_position, frost_radius)
			if big != null:
				var dmg: float = 300.0 * (1.0 + game.elapsed / 120.0)
				game.spawn_blast(big.global_position, 0.4, 30.0, dmg, game.sp_src(_equip_record("frost", "氷結の結界", 0), "sp_ice_lance"), Color(0.6, 0.9, 1.0), "ice")


## 8つ目の特別強化（巨大弩砲・凍てつく大地）
func _update_eighth_specials(delta: float) -> void:
	if mega_bolt and ballista_level > 0:
		_mega_cd -= delta
		if _mega_cd <= 0.0:
			var big := _toughest_enemy_in(wpos(), INF)
			if big != null:
				_mega_cd = 8.0
				for i in mini(ballista_level, MAX_GUNS):
					var from := wpos() + _ballista_local_pos(i)
					var dir := (big.global_position - from).normalized()
					_ballista_aims[i] = dir
					var b := BulletScript.new()
					b.game = game
					b.velocity = dir * 1000.0 / 3.0
					b.damage = ballista_damage * 3.0
					b.pierce = 1000000
					b.radius = 21.0
					b.scale = Vector2(3.0, 3.0)
					b.bolt = true
					b.life = 7.0
					b.position = from
					b.src = game.sp_src(_equip_record("ballista", "バリスタ", i), "sp_mega_bolt")
					game.world.add_child(b)
	if frost_ground and frost_radius > 0.0:
		_ground_tick -= delta
		if _ground_tick <= 0.0:
			_ground_tick = 0.5
			var dps: float = 25.0 * (1.0 + game.elapsed / 120.0)
			var rec: Dictionary = game.sp_src(_equip_record("frost", "氷結の結界", 0), "sp_frost_ground")
			for e in game.enemies_cache:
				if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < frost_radius:
					e.take_damage(dps * 0.5, Vector2.ZERO, rec)


## 5つ目の特別強化（追尾火矢・雷撃・雪だるま）
func _update_fifth_specials(delta: float) -> void:
	if homing_arrow and tower_count > 0:
		_homing_cd -= delta
		if _homing_cd <= 0.0 and game.nearest_enemy(wpos(), tower_range * 1.5) != null:
			_homing_cd = 3.0
			for i in tower_count:
				var from := wpos() + _tower_local_pos(i)
				for k in 2:
					var m: Node2D = game.spawn_missile("homing", from, Vector2.from_angle(-PI / 2.0 + (k - 0.5) * 1.6) * 420.0,
						tower_damage * 1.5, 8.0, 4.0, game.sp_src(_equip_record("tower", "矢倉", i), "sp_homing"))
					m.target = game.nearest_enemy(from, tower_range * 1.5)
	if lightning and ballista_level > 0:
		_lightning_cd -= delta
		if _lightning_cd <= 0.0:
			_lightning_cd = 5.0
			for i in mini(ballista_level, MAX_GUNS):
				var from := wpos() + _ballista_local_pos(i)
				# なるべく別々の敵から連鎖を始める
				var pool: Array = game.enemies_cache.filter(func(e: Node2D) -> bool:
					return is_instance_valid(e) and not e.dead and from.distance_to(e.global_position) < 700.0)
				if pool.is_empty():
					break
				var first: Node2D = pool.pick_random()
				game.chain_lightning(from, first, 7, ballista_damage * 0.8, 200.0, game.sp_src(_equip_record("ballista", "バリスタ", i), "sp_lightning"))
	if snowman and frost_radius > 0.0:
		_snowman_cd -= delta
		if _snowman_cd <= 0.0:
			_snowman_cd = 5.0
			if game.get_tree().get_nodes_in_group("placed_snowman").size() < 6:
				var p := global_position + Vector2.from_angle(randf_range(PI + 0.2, TAU - 0.2)) * frost_radius * randf_range(0.75, 1.0)
				var dmg: float = 150.0 * (1.0 + game.elapsed / 120.0)
				game.spawn_placed("snowman", p, dmg, 40.0, 40.0, game.sp_src(_equip_record("frost", "氷結の結界", 0), "sp_snowman"))


## 範囲内で一番HPの多い敵
func _toughest_enemy_in(center: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_hp := 0.0
	for e in game.enemies_cache:
		if is_instance_valid(e) and not e.dead and center.distance_to(e.global_position) < max_dist and e.hp > best_hp:
			best_hp = e.hp
			best = e
	return best


## 氷結の結界の特別強化（絶対零度・氷柱）
func _update_frost_specials(delta: float) -> void:
	if frost_radius <= 0.0:
		return
	if freeze_level > 0:
		_freeze_cd -= delta
		if _freeze_cd <= 0.0:
			_freeze_cd = 12.0
			var t := 1.0
			for e in game.enemies_cache:
				if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < frost_radius:
					e.stun(t)
			game.spawn_burst(global_position, Color(0.7, 0.95, 1.0), frost_radius / 2.2)
	# 吹雪：結界の中の敵にずっとダメージ
	if blizzard:
		_blizzard_tick -= delta
		if _blizzard_tick <= 0.0:
			_blizzard_tick = 0.5
			var dps: float = 20.0 * (1.0 + game.elapsed / 120.0)
			var rec: Dictionary = game.sp_src(_equip_record("frost", "氷結の結界", 0), "sp_blizzard")
			for e in game.enemies_cache:
				if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < frost_radius:
					e.take_damage(dps * 0.5, Vector2.ZERO, rec)
	if icicle_level > 0:
		_icicle_cd -= delta
		if _icicle_cd <= 0.0:
			_icicle_cd = 2.5 if icicle_level == 1 else 1.5
			var inside: Array = []
			for e in game.enemies_cache:
				if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < frost_radius:
					inside.append(e)
			inside.shuffle()
			var dmg: float = 60.0 * icicle_level * (1.0 + game.elapsed / 180.0)
			for e in inside.slice(0, icicle_level):
				game.spawn_blast(e.global_position, 0.5, 45.0, dmg, game.sp_src(_equip_record("frost", "氷結の結界", 0), "sp_icicle"), Color(0.7, 0.95, 1.0), "ice", 0.5)


## 敵が一番密集している場所にいる敵（射程内）
func _densest_enemy(max_range: float, area: float) -> Node2D:
	_recent_shots = _recent_shots.filter(func(r: Dictionary) -> bool: return r["until"] > _t)
	var best: Node2D = null
	var best_score := 0
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		if wpos().distance_to(e.global_position) > max_range:
			continue
		# まだ着弾していない砲弾の範囲内は狙わない
		var covered := false
		for r in _recent_shots:
			if e.global_position.distance_to(r["pos"]) < r["area"] * 0.8:
				covered = true
				break
		if covered:
			continue
		var n: int = game.enemies_near(e.global_position, area).size()
		if n > best_score:
			best_score = n
			best = e
	return best


func _cannon_local_pos(i: int) -> Vector2:
	match i:
		0: return Vector2(0, -HALF.y - 30.0)
		1: return Vector2(-72, -HALF.y - 26.0)
		_: return Vector2(72, -HALF.y - 26.0)


func _ballista_local_pos(i: int) -> Vector2:
	match i:
		0: return Vector2(-HALF.x * 0.78, HALF.y * 0.45)
		1: return Vector2(HALF.x * 0.78, HALF.y * 0.45)
		_: return Vector2(HALF.x * 0.4, HALF.y * 0.55)


func _catapult_local_pos(i: int) -> Vector2:
	match i:
		0: return Vector2(-HALF.x * 0.55, -HALF.y * 0.2)
		1: return Vector2(HALF.x * 0.55, -HALF.y * 0.2)
		_: return Vector2(0, -HALF.y * 0.55)


# ---------------------------------------------------------------- 描画

func _draw() -> void:
	if frost_radius > 0.0:
		var pulse := 0.06 + sin(_t * 2.0) * 0.02
		draw_circle(Vector2.ZERO, frost_radius, Color(0.5, 0.8, 1.0, pulse))
		draw_arc(Vector2.ZERO, frost_radius, 0.0, TAU, 64, Color(0.6, 0.9, 1.0, 0.35), 2.0)
		if frost_ground:
			# 凍てつく大地：地面に霜の結晶がきらきら
			for i in 24:
				var a := TAU * i / 24.0 + i * 0.7
				var p := Vector2.from_angle(a) * frost_radius * (0.25 + 0.7 * fmod(i * 0.37, 1.0))
				var tw := 0.35 + 0.35 * sin(_t * 3.0 + i)
				draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), Color(0.85, 0.97, 1.0, tw), 1.5)
				draw_line(p + Vector2(0, -5), p + Vector2(0, 5), Color(0.85, 0.97, 1.0, tw), 1.5)

	var wall := Color(0.62, 0.6, 0.56) if _flash <= 0.0 else Color(1, 0.7, 0.6)
	var dark := Color(0.35, 0.33, 0.3)
	# 影
	draw_rect(Rect2(-HALF + Vector2(0, 10), HALF * 2.0), Color(0, 0, 0, 0.3))
	# 本体
	draw_rect(Rect2(-HALF, HALF * 2.0), wall)
	draw_rect(Rect2(-HALF, HALF * 2.0), dark, false, 3.0)
	# 胸壁（ギザギザ）
	var bw := 16.0
	var x := -HALF.x
	while x < HALF.x - 1.0:
		draw_rect(Rect2(Vector2(x, -HALF.y - 10.0), Vector2(bw * 0.6, 10.0)), wall)
		x += bw
	# 門
	draw_rect(Rect2(Vector2(-18, HALF.y - 40.0), Vector2(36, 40)), Color(0.3, 0.2, 0.12))
	draw_circle(Vector2(0, HALF.y - 40.0), 18.0, Color(0.3, 0.2, 0.12))
	# 旗
	draw_line(Vector2(0, -HALF.y - 10.0), Vector2(0, -HALF.y - 50.0), dark, 3.0)
	var wave := sin(_t * 4.0) * 3.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -HALF.y - 50.0), Vector2(26, -HALF.y - 44.0 + wave), Vector2(0, -HALF.y - 36.0)]), Color(0.3, 0.55, 1.0))

	# 兵装（城ロボが出撃中は、ロボットの方に描く）
	if not robot_active():
		draw_weapons(self, Vector2.ZERO)
	# 城の怒り・城レーザー
	_draw_castle_specials()

	# HPバー（城の下）
	var w := HALF.x * 2.0
	var top := Vector2(-HALF.x, HALF.y + 8.0)
	draw_rect(Rect2(top, Vector2(w, 8)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(w * hp / max_hp, 8)), Color(1.0, 0.6, 0.2))


## 兵装（矢倉・大砲・バリスタ・投石器）を ci に描く。offset = 城の中心の位置（ci の座標で）
func draw_weapons(ci: CanvasItem, offset: Vector2) -> void:
	# 矢倉
	for i in tower_count:
		var p := _tower_local_pos(i) + offset
		ci.draw_rect(Rect2(p - Vector2(13, 13), Vector2(26, 26)), Color(0.55, 0.4, 0.25))
		ci.draw_rect(Rect2(p - Vector2(13, 13), Vector2(26, 26)), Color(0.3, 0.2, 0.1), false, 2.0)
		var aim: Vector2 = _tower_aims[i]
		ci.draw_line(p, p + aim * 18.0, Color(0.25, 0.15, 0.08), 4.0)

	# 大砲
	for i in mini(cannon_level, MAX_GUNS):
		var cp := _cannon_local_pos(i) + offset
		var aim: Vector2 = _cannon_aims[i]
		ci.draw_circle(cp, 14.0, Color(0.25, 0.25, 0.28))
		ci.draw_line(cp, cp + aim * 26.0, Color(0.15, 0.15, 0.18), 10.0)

	# バリスタ
	for i in mini(ballista_level, MAX_GUNS):
		var p := _ballista_local_pos(i) + offset
		var aim: Vector2 = _ballista_aims[i]
		var side := aim.orthogonal()
		var back: float = 4.0 if _ballista_recoil[i] > 0.0 else 0.0
		var c := p - aim * back
		ci.draw_circle(p, 9.0, Color(0.4, 0.3, 0.2))
		# 弓の部分
		ci.draw_line(c + side * 14.0 - aim * 4.0, c + aim * 6.0, Color(0.55, 0.4, 0.2), 4.0)
		ci.draw_line(c - side * 14.0 - aim * 4.0, c + aim * 6.0, Color(0.55, 0.4, 0.2), 4.0)
		ci.draw_line(c + side * 14.0 - aim * 4.0, c - aim * 8.0, Color(0.9, 0.9, 0.85), 1.5)
		ci.draw_line(c - side * 14.0 - aim * 4.0, c - aim * 8.0, Color(0.9, 0.9, 0.85), 1.5)
		# 台座のレール
		ci.draw_line(c - aim * 12.0, c + aim * 16.0, Color(0.3, 0.2, 0.1), 5.0)

	# 投石器
	for i in mini(catapult_level, MAX_GUNS):
		var p := _catapult_local_pos(i) + offset
		var wood := Color(0.5, 0.35, 0.2)
		ci.draw_rect(Rect2(p + Vector2(-16, 4), Vector2(32, 8)), wood)
		ci.draw_line(p + Vector2(-10, 6), p + Vector2(0, -8), wood, 3.0)
		ci.draw_line(p + Vector2(10, 6), p + Vector2(0, -8), wood, 3.0)
		var swinging: bool = _catapult_swings[i] > 0.0
		var arm_ang := -2.2 if swinging else -0.5
		var arm_end := p + Vector2(0, -8) + Vector2.from_angle(arm_ang) * 26.0
		ci.draw_line(p + Vector2(0, -8), arm_end, Color(0.4, 0.28, 0.15), 4.0)
		if not swinging:
			ci.draw_circle(arm_end, 6.0, Color(0.45, 0.42, 0.4))


# ---------------------------------------------------------------- 城（本体）の特別強化

## 兵装の位置の基準（城ロボが出撃中はロボットの位置）
func wpos() -> Vector2:
	return robot.global_position if robot_active() else global_position


func robot_active() -> bool:
	return robot != null and is_instance_valid(robot)


func _update_castle_specials(delta: float) -> void:
	# 城レーザー：20秒ごとに、城から全方位をぐるっと薙ぎ払う
	if laser:
		if _laser_left > 0.0:
			var prev := _laser_angle
			_laser_left -= delta
			_laser_angle = LASER_START + TAU * (1.0 - maxf(_laser_left, 0.0) / LASER_TIME)
			_laser_sweep(prev, _laser_angle)
		else:
			_laser_cd -= delta
			if _laser_cd <= 0.0 and not game.enemies_cache.is_empty():
				_laser_cd = 20.0
				_laser_left = LASER_TIME
				_laser_angle = LASER_START
				_laser_hit.clear()
	# 城のくしゃみ：15秒ごとに、壁の内側くらいの敵を外へ吹き飛ばす
	if sneeze:
		_sneeze_cd -= delta
		if _sneeze_cd <= 0.0 and game.nearest_enemy(global_position, game.walls.RADIUS) != null:
			_sneeze_cd = 15.0
			var f: Node2D = game.spawn_fun_fx("sneeze", global_position + Vector2(0, -HALF.y))
			f.radius = game.walls.RADIUS
			for e in game.enemies_near(global_position, game.walls.RADIUS + 30.0):
				if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < game.walls.RADIUS:
					e.apply_knock((e.global_position - global_position).normalized() * 900.0)
	# 城ロボ起動：30秒ごとに15秒間出撃
	if robot_enabled and not robot_active():
		_robot_cd -= delta
		if _robot_cd <= 0.0:
			_robot_cd = 30.0
			robot = RobotScript.new()
			robot.game = game
			robot.mode = "final" if robot_final else ("flight" if robot_flight else "walk")
			# ファイナルモードは画面の真ん中に出撃する
			robot.position = game.MAP_RECT.get_center() if robot_final else global_position + Vector2(0, -HALF.y - 60.0)
			game.world.add_child(robot)


## 城レーザーが出る場所（城ロボ起動中は城ロボから）
func _laser_origin() -> Vector2:
	if robot_active():
		return robot.global_position + Vector2(0, -20)
	return global_position + Vector2(0, -HALF.y)


## 城レーザー：from 〜 to の角度のあいだにいる敵に1回ずつダメージ（威力はレベル×10）
func _laser_sweep(from: float, to: float) -> void:
	var dmg := float(game.level) * 10.0
	var origin := _laser_origin()
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead or _laser_hit.has(e):
			continue
		var a: float = (e.global_position - origin).angle()
		# from〜to（0〜TAU の範囲を超えてもよいように、差で判定）
		var d := fposmod(a - from, TAU)
		if d <= fposmod(to - from, TAU) + 0.02:
			_laser_hit[e] = true
			e.take_damage(dmg, Vector2.ZERO, game.sp_src(record, "sp_castle_laser"))


## 不屈の城：ボス以外の敵を全部消して（経験値なし）、HP20%で立ち直る
func _do_last_stand() -> void:
	_last_stand_used = true
	for e in game.enemies_cache:
		if is_instance_valid(e) and not e.dead and not e.is_boss:
			e.dead = true
			e.remove_from_group("enemies")
			game.spawn_burst(e.global_position, Color(1.0, 0.95, 0.7), e.radius)
			e.queue_free()
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		b.queue_free()
	hp = max_hp * 0.2
	game.add_heal(record, hp, "sp_castle_last_stand")
	_flash = 0.5
	game.spawn_burst(global_position, Color(1.0, 0.9, 0.5), 260.0)
	game.hud.show_banner("不屈の城！", Color(1.0, 0.85, 0.3))


## 城の怒りが発動しているか（城のHPが50%より少ない）
func rage_active() -> bool:
	return rage and hp < max_hp * 0.5


func _draw_castle_specials() -> void:
	if rage_active():
		# 城の怒り：城が赤く脈打つ
		var a := 0.15 + 0.12 * absf(sin(_t * 5.0))
		draw_rect(Rect2(-HALF - Vector2(6, 6), HALF * 2.0 + Vector2(12, 12)), Color(1.0, 0.25, 0.15, a), false, 6.0)
	if _laser_left > 0.0:
		# 城レーザー：城（城ロボ起動中は城ロボ）から長い光線
		var dir := Vector2.from_angle(_laser_angle)
		var o := _laser_origin() - global_position
		draw_line(o, o + dir * 2200.0, Color(1.0, 0.3, 0.3, 0.35), 34.0)
		draw_line(o, o + dir * 2200.0, Color(1.0, 0.8, 0.6, 0.8), 12.0)
		draw_line(o, o + dir * 2200.0, Color(1, 1, 1, 0.95), 4.0)
		draw_circle(o, 22.0, Color(1.0, 0.9, 0.7, 0.8))
