extends Node2D
## ペット。担当の兵士のまわりを回りながら戦う。
## 遊撃ペット（archer = false）：担当の遊撃兵のまわりを回り、近くの敵を自動で撃つ。「遊撃ペット」を取るたびに、全遊撃兵に1匹ずつ付く。
## 弓兵ペット（archer = true）：担当の弓兵のまわりを回り、弓兵の近くまで来た敵へ飛んでいって、遊撃兵の剣と同じ扇形の斬撃で斬る。
##   「弓兵ペット」を取るたびに、全弓兵に1匹ずつ付く。強化・特別強化は game の archer_pet_* を使う（遊撃ペットとは別）。
## 鼓舞ペット（drum = true）：担当の鼓舞兵のまわりを回り、口にくわえた笛を吹いて自分のまわりの敵にまとめてダメージを与え、
##   範囲内の味方の攻撃速度を上げる。強化・特別強化は game の drum_pet_* を使う。

const BulletScript := preload("res://scripts/bullet.gd")
const SlashScript := preload("res://scripts/slash_effect.gd")

var game: Node2D
## 担当の遊撃兵と、その兵士のペットの中での番号
var owner_soldier: Node2D
var index := 0
## 弓兵ペットか（main.gd の _fill_archer_pets で true にする）
var archer := false
## 鼓舞ペットか（main.gd の _fill_drum_pets で true にする）
var drum := false
## ペットの攻撃力（技ごとのダメージはこの値に倍率をかける）
var attack_power := 5.0
## 通常攻撃（ペット弾）の威力の倍率。特別強化のダメージにはかからない
## 通常弾の威力（以前は基本の4倍だったが、基本値に吸収）
## 爆裂ペット弾の爆発（ペット弾の威力 × これ）。弓兵ペットの爆裂ペット斬撃は BURST_RATIO、遊撃ペットの爆裂遊撃ペット弾は PET_BURST_RATIO（1.8倍）
const BURST_RATIO := 0.35
const PET_BURST_RATIO := 0.63
## 弓兵ペットの爆裂ペット斬撃の爆発（斬撃の威力 × これ）
const ARCHER_BURST_RATIO := 0.175
var record: Dictionary
var interval := 0.5
var attack_range := 420.0

var _cd := 0.5
var _t := 0.0
var _aim := Vector2.RIGHT

## 突撃ペット：6秒ごとに、HPが一番高い敵へ突進する（行きだけダメージ、戻りはダメージなし）。
## 全ペットが同じタイミングでいっせいに突進する（ゲームの経過時間 CHARGE_EVERY 秒ごとの区切りで飛び出す。charge_cycle()）
const CHARGE_EVERY := 6.0
const CHARGE_SPEED := 900.0
const CHARGE_RETURN_SPEED := 700.0
const CHARGE_MAX_TIME := 1.2
## 突撃ペットの突進の威力（遊撃ペットの攻撃力の28.8倍）
const CHARGE_MULT := 28.8
## 突撃弓兵ペットの突進の威力（弓兵ペットの攻撃力の約21.3倍）
const ARCHER_CHARGE_MULT := 21.33
## 体当たりペットの威力（遊撃は攻撃力の10.8倍、弓兵は24倍）
const BODY_MULT := 10.8
const ARCHER_BODY_MULT := 24.0
## 爆裂突撃ペット：突進が当たった敵の位置で小爆発
const CHARGE_BURST_RADIUS := 50.0
## 遊撃ペット：突進のダメージ × これ。弓兵ペット：突進とは別に、弓兵ペットの攻撃力 × ARCHER_CHARGE_BURST_MULT
const PET_CHARGE_BURST_RATIO := 0.35
const ARCHER_CHARGE_BURST_MULT := 14.93
## 0 = ふだん / 1 = 突進中 / 2 = 戻り中
var _charge_state := 0
## 最後に突進した区切りの番号（charge_cycle()。これより新しい区切りになったら突進する）
var _charge_tick := 0
var _charge_t := 0.0
var _charge_target: Node2D = null
## 1回の突進で当てた敵（同じ敵には1回だけ）
var _charge_hits := {}
## 突進の残像（ワールド座標）
var _trail: Array = []


func _ready() -> void:
	if archer:
		record = game.new_record("archer_pet", "弓兵%dのペット%d" % [owner_soldier.index + 1, index + 1])
	elif drum:
		record = game.new_record("drum_pet", "鼓舞兵%dのペット%d" % [owner_soldier.index + 1, index + 1])
	else:
		record = game.new_record("pet", "遊撃兵%dのペット%d" % [owner_soldier.index + 1, index + 1])
	for key in [FROST_EVERY, DANCE_EVERY, FLOCK_EVERY, DRUM_DANCE_EVERY, DRUM_PARADE_EVERY]:
		_ticks[key] = floori(game.elapsed / key)
	# あとから来たペットも、次の区切りでほかのペットといっしょに突進する
	_charge_tick = charge_cycle(game)


## 突撃ペットの区切りの番号（経過時間 CHARGE_EVERY 秒ごとに1つ増える。全ペット・合体ペットで共通）
static func charge_cycle(g: Node2D) -> int:
	return floori(g.elapsed / CHARGE_EVERY)


func _process(delta: float) -> void:
	_t += delta
	# 担当の兵士のまわりを回る。兵士が倒れているあいだは城の前で待つ
	var center: Vector2 = game.castle.gate_position() if owner_soldier.dead else owner_soldier.position
	# 同じ兵士のペット同士は等間隔に並んで回る
	# （回る角度はゲーム全体の時間で決める。ペットごとの時間だと、あとから来たペットとずれてしまう）
	var n: int = maxi(game.pets_per_archer if archer else (game.pets_per_drummer if drum else game.pets_per_soldier), 1)
	var ang: float = game.elapsed * 1.6 + TAU * index / n
	var target_pos: Vector2 = center + Vector2.from_angle(ang) * 60.0
	# 突撃ペット（合体中で隠れているあいだは突進しない）
	if _charge_on() and visible:
		_update_charge(delta, target_pos)
	else:
		_charge_state = 0
		_trail.clear()
		_charge_tick = charge_cycle(game)

	# ペットの強化は種類ごとに全ペット共通（game のペット用の値を使う）
	interval = game.archer_pet_interval if archer else (game.drum_pet_interval if drum else game.pet_interval)
	attack_range = game.archer_pet_range if archer else (game.drum_pet_radius if drum else game.pet_range)
	scale = Vector2(1.7, 1.7) if _giant() else Vector2.ONE
	if drum:
		_update_drum_pet(delta, target_pos)
		queue_redraw()
		return
	if archer:
		_update_archer_pet(delta, target_pos)
		queue_redraw()
		return
	if _charge_state == 0:
		position = position.lerp(target_pos, 1.0 - exp(-10.0 * delta))
	# 癒しのさえずり：担当の遊撃兵のHPを少しずつ回復
	if game.pet_heal and not owner_soldier.dead:
		game.heal_unit(owner_soldier, game.stats.max_hp, 2.0 * delta, record, "sp_pet_heal")
	# 体当たりペット：触れた敵にペットの BODY_MULT 倍ダメージ（同じ敵は0.5秒に1回）
	if game.pet_body:
		_body_slam(delta)
	_cd -= delta * game.atk_speed_mult(record)
	# 突進中・戻り中は撃たない
	if _cd <= 0.0 and _charge_state == 0:
		var target := _nearest_enemy()
		if target != null:
			_aim = (target.global_position - global_position).normalized()
			var shots: int = game.pet_shots
			for k in shots:
				_shoot_one(target, k, shots)
			_cd = interval
	queue_redraw()


func _charge_on() -> bool:
	return game.archer_pet_charge if archer else (game.drum_pet_charge if drum else game.pet_charge)


func _giant() -> bool:
	return game.archer_pet_giant if archer else (game.drum_pet_giant if drum else game.pet_giant)


## このペットの攻撃力（突撃・体当たりの元になる値）
func _base_damage() -> float:
	return game.archer_pet_attack_power if archer else (game.drum_pet_attack_power if drum else game.pet_attack_power)


# ---------------------------------------------------------------- 鼓舞ペット

## 鼓舞ペットの突撃・体当たりの威力（笛の威力 × これ）
const DRUM_CHARGE_MULT := 10.0
## 合体中に鼓舞ペット大合体・合体合体合体ペットから飛び出す鼓舞ペットの突進の威力
const DRUM_LAUNCH_CHARGE_MULT := 1.0
const DRUM_BODY_MULT := 2.0
## 巨大鼓舞ペット：範囲・威力
const DRUM_GIANT_RADIUS := 1.3
const DRUM_GIANT_DAMAGE := 1.4
## 攻撃速度アップ（ふつう / 高揚の笛）
const DRUM_BUFF_TIME := 4.0
const DRUM_BOOST_BONUS := 0.2
const DRUM_BOOST_TIME := 8.0
## 凍える笛：遅くする秒数・割合
const DRUM_SLOW_TIME := 3.0
const DRUM_SLOW_RATIO := 0.4
## 癒しの笛：1回で味方が回復する量
const DRUM_HEAL := 10.0
## 連吹き：二吹き目までの時間・威力
const DRUM_DOUBLE_DELAY := 0.3
const DRUM_DOUBLE_RATIO := 1.0
## 鼓舞ペットの舞：間隔・音符の数・威力
const DRUM_DANCE_EVERY := 5.0
const DRUM_DANCE_NOTES := 12
const DRUM_DANCE_RATIO := 3.0
## 必殺・鼓笛隊：間隔・音符の数・威力
const DRUM_PARADE_EVERY := 15.0
const DRUM_PARADE_NOTES := 6
const DRUM_PARADE_RATIO := 0.3
var _drum_double_left := -1.0
var _beat_fx := 0.0
var _beat_r := 0.0


func _update_drum_pet(delta: float, home: Vector2) -> void:
	_beat_fx -= delta
	if _charge_state == 0:
		position = position.lerp(home, 1.0 - exp(-10.0 * delta))
	if game.drum_pet_body:
		_body_slam(delta)
	if game.drum_pet_dance and _due(DRUM_DANCE_EVERY):
		_note_ring()
	if game.drum_pet_parade and _due(DRUM_PARADE_EVERY):
		_note_parade()
	if _drum_double_left > 0.0:
		_drum_double_left -= delta
		if _drum_double_left <= 0.0:
			_drum_beat(DRUM_DOUBLE_RATIO, game.sp_src(record, "sp_drum_pet_double"))
	_cd -= delta * game.atk_speed_mult(record)
	# 突進中・戻り中は吹かない。範囲に敵がいるときだけ吹く
	if _cd <= 0.0 and _charge_state == 0 and _enemy_in_range(_drum_radius()):
		_cd = interval
		_drum_beat(1.0, record)
		if game.drum_pet_double:
			_drum_double_left = DRUM_DOUBLE_DELAY


func _drum_radius() -> float:
	return attack_range * (DRUM_GIANT_RADIUS if game.drum_pet_giant else 1.0)


func _drum_damage() -> float:
	return attack_power * (DRUM_GIANT_DAMAGE if game.drum_pet_giant else 1.0)


func _enemy_in_range(r: float) -> bool:
	for e in game.enemies_near(global_position, r + 30.0):
		if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) <= r + e.radius:
			return true
	return false


## 笛を1回吹く：自分を中心に範囲の敵へダメージ、範囲の味方に攻撃速度アップ（凍える笛・癒しの笛も）
func _drum_beat(ratio: float, src: Dictionary) -> void:
	var r := _drum_radius()
	drum_pet_area(game, global_position, r, _drum_damage() * ratio, src, record, owner_soldier)
	_beat_fx = 0.3
	_beat_r = r


## 鼓舞ペットの笛（合体ペットからも使う）：pos を中心に r の範囲の敵へ dmg、味方に攻撃速度アップ
static func drum_pet_area(g: Node2D, pos: Vector2, r: float, dmg: float, src: Dictionary, rec: Dictionary, from: Node2D) -> void:
	for e in g.enemies_near(pos, r + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		if pos.distance_to(e.global_position) > r + e.radius:
			continue
		if g.drum_pet_slow:
			e.slow(DRUM_SLOW_TIME, DRUM_SLOW_RATIO)
		e.take_damage(dmg, Vector2.ZERO, src)
	var bonus: float = DRUM_BOOST_BONUS if g.drum_pet_boost else g.ATK_BUFF_BONUS
	var time: float = DRUM_BOOST_TIME if g.drum_pet_boost else DRUM_BUFF_TIME
	g.drum_buff_area(pos, r, time, from, bonus, true)
	if g.drum_pet_heal:
		g.drum_heal_area(pos, r, DRUM_HEAL, rec, "sp_drum_pet_heal")


## 鼓舞ペットの舞：全方位へ音符を飛ばす
func _note_ring() -> void:
	for i in DRUM_DANCE_NOTES:
		var dir := Vector2.from_angle(TAU * i / DRUM_DANCE_NOTES + _t)
		var b := BulletScript.new()
		b.game = game
		b.position = global_position
		b.velocity = dir * 380.0
		b.damage = _drum_damage() * DRUM_DANCE_RATIO
		b.radius = 8.0
		b.pierce = 1
		b.color = Color.from_hsv(float(i) / DRUM_DANCE_NOTES, 0.6, 1.0)
		b.life = 1.2
		b.src = game.sp_src(record, "sp_drum_pet_dance")
		game.world.add_child(b)


## 必殺・鼓笛隊：敵を追いかけてくっつく音符
func _note_parade() -> void:
	for i in DRUM_PARADE_NOTES:
		var m: Node2D = game.spawn_missile("homing", global_position,
			Vector2.from_angle(TAU * i / DRUM_PARADE_NOTES) * 320.0, _drum_damage() * DRUM_PARADE_RATIO, 10.0, 6.0, game.sp_src(record, "sp_ult_drum_parade"))
		m.look = "note"


# ---------------------------------------------------------------- 弓兵ペット

## 弓兵ペットが斬りかかりに行く範囲（担当の弓兵からの距離）
const LEASH := 230.0
const FLY_SPEED := 520.0
## 連続斬撃：2回目以降の斬撃の間隔
const MULTI_GAP := 0.12
## 斬撃の威力倍率（巨大弓兵ペット）
const GIANT_MULT := 1.4
## 凍える爪・弓兵ペットの舞・刃の大群の間隔（全弓兵ペットが同じタイミング）
const FROST_EVERY := 10.0
const DANCE_EVERY := 5.0
const FLOCK_EVERY := 15.0
## 弓兵ペット特殊攻撃の倍率（弓兵ペットの攻撃力 × これ）
const FROST_MULT := 1.33
const DANCE_MULT := 6.67
const FLOCK_MULT := 4.0
## 連続斬撃の残り回数・次の斬撃までの時間
var _slashes_left := 0
var _slash_gap := 0.0
var _slash_target: Node2D = null
var _ticks := {}


func _update_archer_pet(delta: float, home: Vector2) -> void:
	# 癒しの羽ばたき：担当の弓兵のHPを毎秒2回復
	if game.archer_pet_heal and not owner_soldier.dead:
		game.heal_unit(owner_soldier, game.archer_stats.max_hp, 2.0 * delta, record, "sp_archer_pet_heal")
	if game.archer_pet_body:
		_body_slam(delta)
	if game.archer_pet_frost and _due(FROST_EVERY):
		_frost_slash()
	if game.archer_pet_dance and _due(DANCE_EVERY):
		_dance_slashes()
	if game.archer_pet_flock and _due(FLOCK_EVERY):
		_blade_flock()
	if _charge_state != 0:
		return
	# 担当の弓兵の近くにいる敵へ飛んでいって斬る。いなければ弓兵のまわりへ戻る
	var leash_center: Vector2 = home if owner_soldier.dead else owner_soldier.global_position
	var target := _slash_target if _slash_target_ok(leash_center) else _nearest_enemy_near(leash_center)
	_slash_target = target
	_cd -= delta * game.atk_speed_mult(record)
	_slash_gap -= delta
	if target == null:
		_slashes_left = 0
		position = position.lerp(home, 1.0 - exp(-10.0 * delta))
		return
	var to: Vector2 = target.global_position - global_position
	_aim = to.normalized()
	var reach: float = attack_range * 0.8 + target.radius
	if to.length() > reach * 0.7:
		global_position += to.limit_length(minf(FLY_SPEED * delta, to.length() - reach * 0.6))
	# 連続斬撃：1回目のあと、MULTI_GAP 秒おきに残りを斬る
	if _slashes_left > 0 and _slash_gap <= 0.0:
		_slashes_left -= 1
		_slash_gap = MULTI_GAP
		_do_slash()
	if _cd <= 0.0 and to.length() <= reach:
		_cd = interval
		_slashes_left = int(game.archer_pet_shots) - 1
		_slash_gap = MULTI_GAP
		_do_slash()


func _slash_target_ok(leash_center: Vector2) -> bool:
	return _slash_target != null and is_instance_valid(_slash_target) and not _slash_target.dead \
		and leash_center.distance_to(_slash_target.global_position) < LEASH + 40.0


func _nearest_enemy_near(leash_center: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := LEASH
	for e in game.enemies_near(leash_center, LEASH):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = leash_center.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## every 秒ごとの区切りが進んでいたら true（全弓兵ペットが同じタイミングになる）
func _due(every: float) -> bool:
	var cyc := floori(game.elapsed / every)
	var last: int = int(_ticks.get(every, cyc))
	_ticks[every] = cyc
	return cyc > last


## 遊撃兵の剣と同じ扇形の斬撃（扇の角度は遊撃兵の剣と同じ。半径は弓兵ペットの射程）
func _do_slash() -> void:
	var radius: float = attack_range
	var arc: float = game.stats.sword_arc
	var dmg := attack_power
	if game.archer_pet_giant:
		radius *= 1.3
		dmg *= GIANT_MULT
	for e in game.enemies_near(global_position, radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > radius + e.radius:
			continue
		if arc < TAU and to.length() > e.radius and absf(_aim.angle_to(to)) > arc / 2.0:
			continue
		e.take_damage(dmg, to.normalized() * 380.0, record)
		# 爆裂ペット斬撃：当たった敵の所で小爆発（斬撃の35%）
		if game.archer_pet_burst:
			game.explode(e.global_position, 45.0, dmg * ARCHER_BURST_RATIO, game.sp_src(record, "sp_archer_pet_burst"), Color(1.0, 0.7, 0.4), 0.0, 120.0)
	var fx := SlashScript.new()
	fx.radius = radius
	fx.arc = arc
	fx.rotation = _aim.angle()
	fx.position = global_position
	game.effects.add_child(fx)


## 凍える爪：敵を追いかける凍結斬撃（当たった敵は0.5秒凍る）
func _frost_slash() -> void:
	var t := _nearest_enemy_near(global_position)
	if t == null:
		t = game.nearest_enemy(global_position, 700.0)
	if t == null:
		return
	var b := _slash_bullet((t.global_position - global_position).normalized(), attack_power * FROST_MULT, Color(0.7, 0.95, 1.0), "sp_archer_pet_frost")
	b.aim_target = t
	b.stun_on_hit = 0.5
	b.velocity *= 0.8
	b.life = 2.5
	game.world.add_child(b)


## 弓兵ペットの舞：全方位へ虹色の斬撃を12発
func _dance_slashes() -> void:
	for i in 12:
		var dir := Vector2.from_angle(TAU * i / 12.0 + _t)
		var b := _slash_bullet(dir, attack_power * DANCE_MULT, Color.from_hsv(i / 12.0, 0.7, 1.0), "sp_archer_pet_dance")
		b.life = 1.0
		game.world.add_child(b)


## 必殺・刃の大群：敵を追いかけ、当たった敵にくっついて2回斬る刃を6本
func _blade_flock() -> void:
	for i in 6:
		var m: Node2D = game.spawn_missile("homing", global_position,
			Vector2.from_angle(TAU * i / 6.0) * 320.0, attack_power * FLOCK_MULT, 10.0, 6.0, game.sp_src(record, "sp_archer_pet_flock"))
		m.look = "blade"


## 飛んでいく斬撃（三日月形の弾）
func _slash_bullet(dir: Vector2, dmg: float, col: Color, sp_id: String) -> Node2D:
	var b := BulletScript.new()
	b.game = game
	b.velocity = dir * 420.0
	b.damage = dmg
	b.radius = 12.0
	b.wave = true
	b.pierce = 2
	b.color = col
	b.position = global_position
	b.src = game.sp_src(record, sp_id)
	return b


## 1発撃つ。何発も撃つときは少しずつ横にずらして、どれも狙った敵へ向かわせる
func _shoot_one(target: Node2D, k: int, shots: int) -> void:
	var offset: Vector2 = _aim.orthogonal() * (k - (shots - 1) / 2.0) * 8.0
	var dir: Vector2 = (target.global_position - (global_position + offset)).normalized()
	var b := BulletScript.new()
	b.game = game
	b.velocity = dir * 520.0
	b.damage = attack_power
	b.radius = 4.0
	b.color = Color(0.5, 1.0, 0.7)
	b.life = attack_range / 520.0 + 0.2
	b.position = global_position + offset
	b.src = record
	# 巨大ペット：弾も大きく、2体貫通して威力アップ
	if game.pet_giant:
		b.damage *= 1.4
		b.radius = 7.0
		b.pierce = 2
	# 爆裂ペット弾：当たると小爆発
	if game.pet_burst:
		b.explode_radius = 45.0
		b.explode_ratio = PET_BURST_RATIO
		b.explode_src = game.sp_src(record, "sp_pet_burst")
	game.world.add_child(b)


## 突撃ペット：ふだん → 突進 → 戻る をくり返す
func _update_charge(delta: float, home: Vector2) -> void:
	match _charge_state:
		0:
			_trail.clear()
			var cyc := charge_cycle(game)
			if cyc > _charge_tick:
				# 敵がいなければ、次の区切りまで待つ
				_charge_tick = cyc
				_charge_target = _strongest_enemy()
				if _charge_target != null:
					_charge_state = 1
					_charge_t = 0.0
					_charge_hits.clear()
		1:
			_charge_t += delta
			# 狙った敵が倒れたら、別の一番HPが高い敵へ。いなければ戻る
			if not is_instance_valid(_charge_target) or _charge_target.dead:
				_charge_target = _strongest_enemy()
			if _charge_target == null:
				_charge_state = 2
				return
			var to: Vector2 = _charge_target.global_position - global_position
			_aim = to.normalized()
			global_position += to.limit_length(CHARGE_SPEED * delta)
			_push_trail()
			_charge_hit()
			var reach: float = 9.0 * scale.x + _charge_target.radius
			if global_position.distance_to(_charge_target.global_position) <= reach or _charge_t >= CHARGE_MAX_TIME:
				_charge_state = 2
		2:
			# 戻るときはダメージなし
			var back: Vector2 = home - global_position
			global_position += back.limit_length(CHARGE_RETURN_SPEED * delta)
			_push_trail()
			if global_position.distance_to(home) < 8.0:
				_charge_state = 0
				_trail.clear()


func _push_trail() -> void:
	_trail.append(global_position)
	if _trail.size() > 10:
		_trail.pop_front()


## 突進中に触れた敵に1回ずつダメージ（爆裂突撃ペットなら、当たった所で小爆発）
func _charge_hit() -> void:
	var r := 9.0 * scale.x
	var charge_sp := "sp_archer_pet_charge" if archer else ("sp_drum_pet_charge" if drum else "sp_pet_charge")
	var burst_sp := "sp_archer_pet_charge_burst" if archer else "sp_pet_charge_burst"
	var burst_on: bool = game.archer_pet_charge_burst if archer else (false if drum else game.pet_charge_burst)
	for e in game.enemies_near(global_position, r + 60.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var id: int = e.get_instance_id()
		if _charge_hits.has(id):
			continue
		if global_position.distance_to(e.global_position) < r + e.radius + 3.0:
			_charge_hits[id] = true
			var charge_mult: float = DRUM_CHARGE_MULT if drum else (ARCHER_CHARGE_MULT if archer else CHARGE_MULT)
			var dmg: float = _base_damage() * charge_mult
			var hit_pos: Vector2 = e.global_position
			e.take_damage(dmg, _aim * 260.0, game.sp_src(record, charge_sp))
			if burst_on:
				var burst_dmg: float = _base_damage() * ARCHER_CHARGE_BURST_MULT if archer else dmg * PET_CHARGE_BURST_RATIO
				game.explode(hit_pos, CHARGE_BURST_RADIUS, burst_dmg, game.sp_src(record, burst_sp), Color(1.0, 0.7, 0.3))


## HPが一番高い敵（ボスも含む）
func _strongest_enemy() -> Node2D:
	return strongest_enemy_of(game)


## HPが一番高い敵（ボスも含む。合体中の突撃でも使う）
static func strongest_enemy_of(g: Node2D) -> Node2D:
	var best: Node2D = null
	var best_hp := -1.0
	for e in g.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		if e.hp > best_hp:
			best_hp = e.hp
			best = e
	return best


var _slam_cd := {}


func _body_slam(delta: float) -> void:
	for e in _slam_cd.keys():
		_slam_cd[e] -= delta
		if _slam_cd[e] <= 0.0 or not is_instance_valid(e):
			_slam_cd.erase(e)
	var r := 9.0 * scale.x
	for e in game.enemies_near(global_position, r + 40.0):
		if not is_instance_valid(e) or e.dead or _slam_cd.has(e):
			continue
		if global_position.distance_to(e.global_position) < r + e.radius + 3.0:
			_slam_cd[e] = 0.5
			var body_mult: float = ARCHER_BODY_MULT if archer else (DRUM_BODY_MULT if drum else BODY_MULT)
			var body_sp := "sp_archer_pet_body" if archer else ("sp_drum_pet_body" if drum else "sp_pet_body")
			e.take_damage(_base_damage() * body_mult, (e.global_position - global_position).normalized() * 200.0, game.sp_src(record, body_sp))


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := attack_range
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _draw() -> void:
	# ふわふわ浮いている小鳥風
	# 突撃ペット：突進中・戻り中は残像の線を引く
	if _trail.size() >= 2:
		var col := Color(1.0, 0.85, 0.4) if _charge_state == 1 else Color(0.6, 1.0, 0.8)
		for i in range(1, _trail.size()):
			var a: float = float(i) / _trail.size()
			draw_line(to_local(_trail[i - 1]), to_local(_trail[i]), Color(col, 0.6 * a), 3.0 + 7.0 * a)
	# 鼓舞ペット：笛を吹いた直後、範囲いっぱいまで広がる輪
	if drum and _beat_fx > 0.0:
		var k := clampf(1.0 - _beat_fx / 0.3, 0.0, 1.0)
		draw_arc(Vector2.ZERO, _beat_r * (0.3 + 0.7 * k), 0.0, TAU, 40, Color(1.0, 0.75, 0.55, 0.7 * (1.0 - k) + 0.1), 3.0)
	var bob := sin(_t * 6.0) * 2.0
	draw_circle(Vector2(0, 10), 7.0, Color(0, 0, 0, 0.25))
	var c := Vector2(0, bob)
	# 踊り（遊撃ペットは「ペットの踊り」、弓兵ペットは「弓兵ペットの舞」、鼓舞ペットは「鼓舞ペットの舞」）
	var dancing: bool = game.archer_pet_dance if archer else (game.drum_pet_dance if drum else game.fun.pet_dance)
	# 弓兵ペットは紫っぽい色、鼓舞ペットは赤っぽい色
	var body_col := Color(0.8, 0.65, 1.0) if archer else (Color(1.0, 0.6, 0.5) if drum else Color(0.45, 0.95, 0.65))
	var wing_col := Color(0.6, 0.45, 0.85) if archer else (Color(0.85, 0.38, 0.32) if drum else Color(0.3, 0.75, 0.5))
	if dancing:
		# ペットの踊り：虹色に光りながら、その場でくるくる回る
		var hue := fmod(_t * 0.8 + index * 0.3, 1.0)
		draw_circle(c, 15.0, Color.from_hsv(hue, 0.7, 1.0, 0.35))
		for i in 6:
			var a := _t * 4.0 + TAU * i / 6.0
			draw_circle(c + Vector2.from_angle(a) * 14.0, 2.5, Color.from_hsv(fmod(hue + i / 6.0, 1.0), 0.8, 1.0))
		draw_set_transform(c, _t * 9.0, Vector2.ONE)
		c = Vector2.ZERO
	draw_circle(c, 9.0, Color.from_hsv(fmod(_t * 0.8 + index * 0.3, 1.0), 0.55, 1.0) if dancing else body_col)
	var wing := sin(_t * 18.0) * 4.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-15, -4 - wing), c + Vector2(-8, 5)]), wing_col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(6, 0), c + Vector2(15, -4 - wing), c + Vector2(8, 5)]), wing_col)
	draw_circle(c + _aim * 4.0 + Vector2(-2, -2), 1.8, Color(0.1, 0.1, 0.1))
	draw_circle(c + _aim * 4.0 + Vector2(2, -2), 1.8, Color(0.1, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([c + _aim * 12.0, c + _aim * 7.0 + _aim.orthogonal() * 3.0, c + _aim * 7.0 - _aim.orthogonal() * 3.0]), Color(1.0, 0.8, 0.3))
	if drum:
		# 口にくわえた笛（銀色の細い管。吹いた直後は先が光る）
		var tip := c + _aim * 20.0 + _aim.orthogonal() * 2.0
		draw_line(c + _aim * 10.0, tip, Color(0.82, 0.84, 0.88), 3.0)
		draw_circle(c + _aim * 13.0, 2.2, Color(0.6, 0.62, 0.68))
		if _beat_fx > 0.1:
			draw_circle(tip, 3.0, Color(1.0, 0.95, 0.6, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

