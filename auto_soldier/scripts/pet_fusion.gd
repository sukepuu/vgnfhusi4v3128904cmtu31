extends Node2D
## ペット大合体（ペットの特別強化）。
## 20秒ごとに全ペットが1か所に集まって合体し、10秒間だけ巨大ペットになる。
## 巨大ペットは「立ち止まって特大弾を連射 → まっすぐ高速突進」をくり返す。合体したペットが多いほど強く大きい。
## ペットの強化（間隔・威力・射程・弾数）とペットの特別強化の効果も、合体中にそのまま乗る。
## 合体中、元のペットは隠れて休んでいる。
## 突撃ペットを持っていたら、合体中も6秒ごとの区切り（ふつうのペットと同じタイミング）で、
## 合体前のペットを1匹ずつ（LAUNCH_GAP 秒おきに、合体した数だけ）体の中心から突進させる（pet_charger.gd）。
## archer = true なら弓兵ペット大合体：弓兵ペットが合体し、特大弾のかわりに特大の斬撃を連発する（弓兵ペットの強化・特別強化が乗る）。
## drum = true なら鼓舞ペット大合体：鼓舞ペットが合体し、特大の笛（範囲攻撃＋攻撃速度アップ）を連発する。
## triple = true なら合体合体合体ペット：遊撃・弓兵・鼓舞の3種類のペットが全部合体し、3種類の攻撃を同時に行う。
##   5秒後に現れて20秒合体、分かれてから20秒後にまた合体する。これがいるあいだ、ほかの3つの合体ペットは合体しない。

const BulletScript := preload("res://scripts/bullet.gd")
const SlashScript := preload("res://scripts/slash_effect.gd")
const PetScript := preload("res://scripts/pet.gd")
const ChargerScript := preload("res://scripts/pet_charger.gd")
## 合体中の突撃：1匹ずつ飛び出す間隔
const LAUNCH_GAP := 0.5
const FROST_EVERY := 10.0
const ARCHER_FLOCK_EVERY := 15.0
const DRUM_DANCE_EVERY := 5.0
const DRUM_PARADE_EVERY := 15.0
const DRUM_FUSION_DAMAGE_MULT := 1.0 / 7.0

const CYCLE := 20.0
const DURATION := 10.0
## 合体合体合体ペット：合体している時間・分かれている時間
const TRIPLE_DURATION := 20.0
const TRIPLE_REST := 20.0

var game: Node2D
var record: Dictionary
## 弓兵ペット大合体か
var archer := false
## 鼓舞ペット大合体か
var drum := false
## 合体合体合体ペットか
var triple := false

var _cd := 5.0
var _left := 0.0
## 合体したペットの数
var _n := 0
var _radius := 20.0
var _shot_cd := 0.0
var _ram_cd := {}
var _t := 0.0
## 合体中の突撃：最後に飛び出させた区切りの番号・まだ飛び出していない数・次に飛び出すまでの時間・次に飛び出すペットの番号
var _charge_tick := 0
var _launch_left := 0
var _launch_cd := 0.0
var _launch_i := 0
## 種類（"pet" / "archer" / "drum"）ごとの、合体したペットの数・攻撃の待ち時間
var _n_of := {}
var _shot_cds := {}
## 合体中に発動する、ペット種類別の特別攻撃の区切り管理
var _special_ticks := {}
## 笛を吹いた直後の見た目
var _beat_fx := 0.0
var _beat_r := 0.0


func _ready() -> void:
	if triple:
		record = game.new_record("triple_pet", "合体合体合体ペット")
	elif archer:
		record = game.new_record("archer_pet", "合体弓兵ペット")
	elif drum:
		record = game.new_record("drum_pet", "合体鼓舞ペット")
	else:
		record = game.new_record("pet", "合体ペット")
	visible = false


func merged() -> bool:
	return _left > 0.0


## 合体するペットの種類
func _kinds() -> Array:
	if triple:
		return ["pet", "archer", "drum"]
	return ["archer"] if archer else (["drum"] if drum else ["pet"])


func _pets_of(kind: String) -> Array:
	match kind:
		"archer":
			return game.archer_pets
		"drum":
			return game.drum_pets
	return game.pets


## 合体するペット（全部の種類）
func _pets() -> Array:
	var list: Array = []
	for k in _kinds():
		list += _pets_of(k)
	return list


func _giant_of(kind: String) -> bool:
	match kind:
		"archer":
			return game.archer_pet_giant
		"drum":
			return game.drum_pet_giant
	return game.pet_giant


func _giant() -> bool:
	return _kinds().any(func(k: String) -> bool: return _giant_of(k))


func _drum_fusion_damage_mult() -> float:
	return DRUM_FUSION_DAMAGE_MULT if drum else 1.0


func _dance() -> bool:
	for k in _kinds():
		if (k == "archer" and game.archer_pet_dance) or (k == "drum" and game.drum_pet_dance) or (k == "pet" and game.fun.pet_dance):
			return true
	return false


## 合体合体合体ペットがいるあいだ、ほかの合体ペットは合体しない
func _blocked() -> bool:
	return not triple and game.triple_fusion_on


func _process(delta: float) -> void:
	_t += delta
	_beat_fx -= delta
	if _blocked():
		if merged():
			_split()
		return
	if not merged():
		_cd -= delta
		if _cd <= 0.0 and not _pets().is_empty():
			_merge()
		return
	_left -= delta
	# 合体中に増えたペットも隠しておく
	for p in _pets():
		if p.visible:
			_hide_pet(p)
	_update_body(delta)
	_update_launch(delta)
	_update_special_attacks()
	if _left <= 0.0:
		_split()
	queue_redraw()


func _hide_pet(p: Node2D) -> void:
	p.visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED


func _merge() -> void:
	_n = _pets().size()
	for k in _kinds():
		_n_of[k] = _pets_of(k).size()
		_shot_cds[k] = 0.0
	for spec in [["pet_frost", FROST_EVERY], ["archer_frost", FROST_EVERY], ["archer_flock", ARCHER_FLOCK_EVERY], ["drum_dance", DRUM_DANCE_EVERY], ["drum_parade", DRUM_PARADE_EVERY]]:
		_special_ticks[spec[0]] = floori(game.elapsed / spec[1])
	var center := Vector2.ZERO
	for p in _pets():
		center += p.global_position
		_hide_pet(p)
	position = center / _n
	_radius = minf(18.0 + 6.0 * _n, 80.0 if not triple else 110.0) * (1.3 if _giant() else 1.0)
	_left = TRIPLE_DURATION if triple else DURATION
	_cd = TRIPLE_REST if triple else CYCLE - DURATION
	_ram_cd.clear()
	_charge_tick = PetScript.charge_cycle(game)
	_launch_left = 0
	_mode = "shoot"
	_mode_left = SHOOT_TIME
	visible = true
	game.spawn_burst(position, Color(0.5, 1.0, 0.7), _radius * 1.5)


func _split() -> void:
	_left = 0.0
	visible = false
	_launch_left = 0
	for p in _pets():
		p.visible = true
		p.process_mode = Node.PROCESS_MODE_INHERIT
		p.position = position + Vector2.from_angle(randf() * TAU) * 20.0
		# 合体中に過ぎた区切りのぶんは突進しない（次の区切りでほかのペットといっしょに突進する）
		p._charge_tick = PetScript.charge_cycle(game)
	game.spawn_burst(position, Color(0.5, 1.0, 0.7), _radius)


## 合体ペットの火力の調整（合体したペット1匹あたりの強さ）。
## 強さは合体した数にそのまま比例するだけ（たくさん合体しても1匹あたりの強さは増えない）。
## 弾の火力（1秒あたり）が、何匹合体しても合体前のペット全員の合計とほぼ同じ（×1.0）になる
const FUSION_SCALE := 0.1874
## 合体ペットのダメージ補正（合体中の攻撃すべてに1.875倍。前の1.25倍の1.5倍）
const FUSION_BONUS := 1.875
## 合体中の爆裂ペット弾の爆発の倍率（ふつうのペットの爆発の割合 × これ。80%）
const FUSION_BURST_MULT := 0.8
## 合体弓兵ペットの特大斬撃の威力の倍率（攻撃力変更前と同じダメージ）
const ARCHER_SLASH_MULT := 2.0 / 27.0


## 合体ペットの強さの倍率（弾1発 = ペットの攻撃力 × これ）。合体合体合体ペットは種類ごとに、その種類の数で決まる
func _power(kind: String = "") -> float:
	var n: int = _n if kind == "" or not triple else int(_n_of.get(kind, 0))
	return n * FUSION_SCALE * FUSION_BONUS


## 鼓舞ペット大合体：特大の笛の間隔（ふつうの鼓舞ペットの間隔に対して 0.15/0.8）・範囲・突進のダメージの倍率
const DRUM_BEAT_RATIO := 0.15 / 0.8
const DRUM_RANGE_MULT := 1.5
const DRUM_RAM_MULT := 0.3


## 行動：立ち止まって射撃（SHOOT_TIME秒）→ 一番近い敵へまっすぐ高速突進 → 立ち止まって射撃 … をくり返す
const SHOOT_TIME := 1.2
const DASH_SPEED := 900.0
var _mode := "shoot"
var _mode_left := SHOOT_TIME
var _dash_dir := Vector2.ZERO


func _update_body(delta: float) -> void:
	# 癒しの羽ばたき：合体中も、各弓兵をペットの数ぶん回復
	if _kinds().has("archer") and game.archer_pet_heal:
		for a in game.archers:
			if not a.dead:
				game.heal_unit(a, game.archer_stats.max_hp, 2.0 * game.pets_per_archer * delta, record, "sp_archer_pet_heal")
	# 癒しのさえずり：合体中も、各遊撃兵をペットの数ぶん回復
	if _kinds().has("pet") and game.pet_heal:
		for s in game.soldiers:
			if not s.dead:
				game.heal_unit(s, game.stats.max_hp, 2.0 * game.pets_per_soldier * delta, record, "sp_pet_heal")
	_mode_left -= delta
	if _mode == "shoot":
		# 合体合体合体ペットは3種類の攻撃を同時に
		for k in _kinds():
			match k:
				"archer":
					_slash_update(delta)
				"drum":
					_beat_update(delta)
				_:
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
			for k in _shot_cds:
				_shot_cds[k] = 0.0


## 合体中の突撃：区切りが来たら、合体した数だけ1匹ずつ（LAUNCH_GAP 秒おき）体の中心から突進させる。
## 前の区切りのぶんが残っていたら、新しい区切りの数に入れ替える
func _charge_of(kind: String) -> bool:
	match kind:
		"archer":
			return game.archer_pet_charge
		"drum":
			return game.drum_pet_charge
	return game.pet_charge


## 突撃を持っている種類のペット（合体前の）
func _chargers() -> Array:
	var list: Array = []
	for k in _kinds():
		if _charge_of(k):
			list += _pets_of(k)
	return list


func _update_launch(delta: float) -> void:
	var chargers := _chargers()
	if chargers.is_empty():
		_launch_left = 0
		_charge_tick = PetScript.charge_cycle(game)
		return
	var cyc: int = PetScript.charge_cycle(game)
	if cyc > _charge_tick:
		_charge_tick = cyc
		_launch_left = chargers.size()
		_launch_cd = 0.0
	if _launch_left <= 0:
		return
	_launch_cd -= delta
	if _launch_cd > 0.0:
		return
	var target: Node2D = PetScript.strongest_enemy_of(game)
	if target == null:
		# 敵がいなければ、出てくるまで待つ
		return
	_launch_left -= 1
	_launch_cd = LAUNCH_GAP
	var c := ChargerScript.new()
	c.game = game
	c.fusion = self
	# ダメージは合体前のペットの戦績に、突撃ペット・爆裂突撃ペットとして記録する（どの種類のペットかで威力も変わる）
	var p: Node2D = chargers[_launch_i % chargers.size()]
	c.record = p.record
	c.archer = p.archer
	c.drum = p.drum
	c.damage_mult = _drum_fusion_damage_mult() if c.drum else 1.0
	_launch_i += 1
	c.target = target
	c.position = global_position
	game.world.add_child(c)


## 突進中に触れた敵へ体当たり（1回の突進で同じ敵には1回）。体当たりペットを持っていると4倍
func _ram() -> void:
	# 種類ごとの体当たりの威力を足す（鼓舞ペットは笛の威力が高いので DRUM_RAM_MULT 倍）
	var dmg := 0.0
	for k in _kinds():
		match k:
			"archer":
				dmg += game.archer_pet_attack_power * (4.0 / 3.0) * _power(k) * (4.0 if game.archer_pet_body else 1.0)
			"drum":
				dmg += game.drum_pet_attack_power * DRUM_RAM_MULT * _power(k) * (4.0 if game.drum_pet_body else 1.0) * _drum_fusion_damage_mult()
			_:
				dmg += game.pet_attack_power * _power(k) * (4.0 if game.pet_body else 1.0)
	for e in game.enemies_near(global_position, _radius + 40.0):
		if not is_instance_valid(e) or e.dead or _ram_cd.has(e):
			continue
		if global_position.distance_to(e.global_position) < _radius + e.radius:
			_ram_cd[e] = true
			e.take_damage(dmg, _dash_dir * 300.0, record)


## 立ち止まって特大弾を連射。ペットの強化（間隔・威力・射程・弾数・特別強化）がそのまま乗る
func _shoot_update(delta: float) -> void:
	_shot_cds["pet"] = float(_shot_cds.get("pet", 0.0)) - delta * game.atk_speed_mult(record)
	if _shot_cds["pet"] > 0.0:
		return
	var rng: float = game.pet_range * 1.5
	var aim: Node2D = game.nearest_enemy(global_position, rng)
	if aim == null:
		return
	# 早撃ちペットで間隔が縮む（ふつうのペットの間隔0.8に対して0.15）
	_shot_cds["pet"] = 0.15 * game.pet_interval / 0.8
	var base: Vector2 = (aim.global_position - global_position).normalized()
	for k in game.pet_shots:
		var dir: Vector2 = base.rotated((k - (game.pet_shots - 1) / 2.0) * 0.12 + randf_range(-0.05, 0.05))
		var b := BulletScript.new()
		b.game = game
		b.velocity = dir * 560.0
		# 通常攻撃（以前のSHOT_MULTは基本値に吸収済み）
		b.damage = game.pet_attack_power * _power("pet") * 0.5
		b.radius = 9.0 + minf(_n, 8.0)
		b.pierce = 2
		b.color = Color.from_hsv(fmod(_t * 0.7, 1.0), 0.5, 1.0)
		b.life = rng / 560.0 + 0.2
		b.position = global_position + dir * _radius
		b.src = record
		if game.pet_giant:
			b.damage *= 1.4
			b.radius *= 1.4
			b.pierce += 2
		if game.pet_burst:
			b.explode_radius = 45.0 + 3.0 * _n
			b.explode_ratio = PetScript.BURST_RATIO * FUSION_BURST_MULT
			b.explode_src = game.sp_src(record, "sp_pet_burst")
		game.world.add_child(b)


## 弓兵ペット大合体：立ち止まって、一番近い敵の方へ特大の斬撃を連発する。
## 弓兵ペットの強化（間隔・威力・射程・斬撃回数・巨大・爆裂）がそのまま乗る
func _slash_update(delta: float) -> void:
	_shot_cds["archer"] = float(_shot_cds.get("archer", 0.0)) - delta * game.atk_speed_mult(record)
	if _shot_cds["archer"] > 0.0:
		return
	var reach: float = game.archer_pet_range * 2.0 + _radius
	var aim: Node2D = game.nearest_enemy(global_position, reach + 60.0)
	if aim == null:
		return
	# 弓兵ペット早撃ちで間隔が縮む（ふつうの弓兵ペットの間隔0.75に対して0.15）
	_shot_cds["archer"] = 0.15 * game.archer_pet_interval / 0.75
	var dir: Vector2 = (aim.global_position - global_position).normalized()
	var arc: float = game.stats.sword_arc
	var radius: float = reach * (1.3 if game.archer_pet_giant else 1.0)
	# 連続斬撃のぶん、1回の斬撃が強くなる。合体弓兵ペットの斬撃は ARCHER_SLASH_MULT 倍
	var dmg: float = game.archer_pet_attack_power * _power("archer") * game.archer_pet_shots * (1.4 if game.archer_pet_giant else 1.0) * ARCHER_SLASH_MULT
	for e in game.enemies_near(global_position, radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > radius + e.radius:
			continue
		if to.length() > _radius + e.radius and absf(dir.angle_to(to)) > arc / 2.0:
			continue
		e.take_damage(dmg, to.normalized() * 380.0, record)
		if game.archer_pet_burst:
			game.explode(e.global_position, 45.0 + 3.0 * _n, dmg * PetScript.BURST_RATIO * 0.5 * FUSION_BURST_MULT, game.sp_src(record, "sp_archer_pet_burst"), Color(1.0, 0.7, 0.4), 0.0, 120.0)
	var fx := SlashScript.new()
	fx.radius = radius
	fx.arc = arc
	fx.rotation = dir.angle()
	fx.position = global_position
	game.effects.add_child(fx)


## 鼓舞ペット大合体：立ち止まって、自分を中心に特大の笛（範囲攻撃＋範囲の味方に攻撃速度アップ）を連発する。
## 鼓舞ペットの強化（間隔・威力・範囲・巨大・凍える笛・癒しの笛・高揚の笛）がそのまま乗る
func _beat_update(delta: float) -> void:
	_shot_cds["drum"] = float(_shot_cds.get("drum", 0.0)) - delta * game.atk_speed_mult(record)
	if _shot_cds["drum"] > 0.0:
		return
	var r: float = (game.drum_pet_radius * DRUM_RANGE_MULT + _radius) * (PetScript.DRUM_GIANT_RADIUS if game.drum_pet_giant else 1.0)
	if game.nearest_enemy(global_position, r) == null:
		return
	_shot_cds["drum"] = game.drum_pet_interval * DRUM_BEAT_RATIO
	var dmg: float = game.drum_pet_attack_power * _power("drum") * (PetScript.DRUM_GIANT_DAMAGE if game.drum_pet_giant else 1.0) * 10.0 * _drum_fusion_damage_mult()
	PetScript.drum_pet_area(game, global_position, r, dmg, record, record, self)
	_beat_fx = 0.3
	_beat_r = r


## 元のペットが停止している合体中も、時間制の特別攻撃を合体体から発動する
func _update_special_attacks() -> void:
	if _kinds().has("archer"):
		if game.archer_pet_frost and _special_due("archer_frost", FROST_EVERY):
			_fusion_archer_frost()
		if game.archer_pet_flock and _special_due("archer_flock", ARCHER_FLOCK_EVERY):
			_fusion_archer_flock()
	if _kinds().has("drum"):
		if game.drum_pet_dance and _special_due("drum_dance", DRUM_DANCE_EVERY):
			_fusion_drum_dance()
		if game.drum_pet_parade and _special_due("drum_parade", DRUM_PARADE_EVERY):
			_fusion_drum_parade()


func _special_due(key: String, every: float) -> bool:
	var cycle := floori(game.elapsed / every)
	var previous := int(_special_ticks.get(key, cycle))
	_special_ticks[key] = cycle
	return cycle > previous


func _fusion_archer_frost() -> void:
	for p in _pets_of("archer"):
		var target: Node2D = game.nearest_enemy(global_position, 700.0)
		if target == null:
			continue
		var b := BulletScript.new()
		b.game = game
		b.velocity = (target.global_position - global_position).normalized() * 336.0
		b.damage = game.archer_pet_attack_power * PetScript.FROST_MULT
		b.radius = 12.0
		b.wave = true
		b.pierce = 2
		b.color = Color(0.7, 0.95, 1.0)
		b.aim_target = target
		b.stun_on_hit = 0.5
		b.life = 2.5
		b.position = global_position
		b.src = game.sp_src(p.record, "sp_archer_pet_frost")
		game.world.add_child(b)


func _fusion_archer_flock() -> void:
	for p in _pets_of("archer"):
		for i in 6:
			var m: Node2D = game.spawn_missile("homing", global_position,
				Vector2.from_angle(TAU * i / 6.0) * 320.0, game.archer_pet_attack_power * PetScript.FLOCK_MULT * 0.5,
				10.0, 6.0, game.sp_src(p.record, "sp_archer_pet_flock"))
			m.look = "blade"


func _fusion_drum_dance() -> void:
	for p in _pets_of("drum"):
		for i in PetScript.DRUM_DANCE_NOTES:
			var dir := Vector2.from_angle(TAU * i / PetScript.DRUM_DANCE_NOTES + _t)
			var b := BulletScript.new()
			b.game = game
			b.position = global_position
			b.velocity = dir * 380.0
			b.damage = game.drum_pet_attack_power * _power("drum") * (PetScript.DRUM_GIANT_DAMAGE if game.drum_pet_giant else 1.0) * PetScript.DRUM_DANCE_RATIO * 10.0 * _drum_fusion_damage_mult()
			b.radius = 8.0
			b.pierce = 1
			b.color = Color.from_hsv(float(i) / PetScript.DRUM_DANCE_NOTES, 0.6, 1.0)
			b.life = 1.2
			b.src = game.sp_src(p.record, "sp_drum_pet_dance")
			game.world.add_child(b)


func _fusion_drum_parade() -> void:
	for p in _pets_of("drum"):
		for i in PetScript.DRUM_PARADE_NOTES:
			var m: Node2D = game.spawn_missile("homing", global_position,
				Vector2.from_angle(TAU * i / PetScript.DRUM_PARADE_NOTES) * 320.0,
				game.drum_pet_attack_power * _power("drum") * (PetScript.DRUM_GIANT_DAMAGE if game.drum_pet_giant else 1.0) * PetScript.DRUM_PARADE_RATIO * 10.0 * _drum_fusion_damage_mult(),
				10.0, 6.0, game.sp_src(p.record, "sp_ult_drum_parade"))
			m.look = "note"


func _draw() -> void:
	if not merged():
		return
	if _beat_fx > 0.0:
		var k := clampf(1.0 - _beat_fx / 0.3, 0.0, 1.0)
		draw_arc(Vector2.ZERO, _beat_r * (0.3 + 0.7 * k), 0.0, TAU, 56, Color(1.0, 0.75, 0.55, 0.7 * (1.0 - k) + 0.1), 5.0)
	var r := _radius
	var flap := sin(_t * 14.0) * r * 0.25
	draw_circle(Vector2(0, r * 0.4), r, Color(0, 0, 0, 0.25))
	# ペットの踊り：合体中も、虹色の光をまといながらその場でくるくる回る
	var wing_col := Color(0.85, 0.75, 1.0) if archer else (Color(1.0, 0.7, 0.6) if drum else Color(0.75, 1.0, 0.85))
	if triple:
		wing_col = Color(1.0, 0.9, 0.55)
	if _dance():
		var hue := fmod(_t * 0.8, 1.0)
		draw_circle(Vector2.ZERO, r * 1.6, Color.from_hsv(hue, 0.7, 1.0, 0.25))
		for i in 10:
			var a := _t * 3.0 + TAU * i / 10.0
			draw_circle(Vector2.from_angle(a) * r * 1.5, 3.0 + r * 0.06, Color.from_hsv(fmod(hue + i / 10.0, 1.0), 0.8, 1.0))
		draw_set_transform(Vector2.ZERO, _t * 6.0, Vector2.ONE)
	# 大きな羽
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.6, 0), Vector2(-r * 1.7, -r * 0.6 - flap), Vector2(-r * 1.2, r * 0.3)]), wing_col)
	draw_colored_polygon(PackedVector2Array([Vector2(r * 0.6, 0), Vector2(r * 1.7, -r * 0.6 - flap), Vector2(r * 1.2, r * 0.3)]), wing_col)
	if triple:
		# 3種類の色の羽を重ねる（緑・紫・赤）
		for i in 3:
			var col: Color = [Color(0.45, 0.95, 0.65), Color(0.8, 0.65, 1.0), Color(1.0, 0.6, 0.5)][i]
			var off := (i - 1) * r * 0.25
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.6, off * 0.3), Vector2(-r * (1.4 - i * 0.15), -r * 0.3 + off - flap), Vector2(-r * 1.0, r * 0.2 + off * 0.5)]), col)
			draw_colored_polygon(PackedVector2Array([Vector2(r * 0.6, off * 0.3), Vector2(r * (1.4 - i * 0.15), -r * 0.3 + off - flap), Vector2(r * 1.0, r * 0.2 + off * 0.5)]), col)
	# 体（キラキラ光る輪つき）
	# ペットの踊りを持っていたら、虹色に光る
	var body_col := Color.from_hsv(fmod(_t * 0.8, 1.0), 0.55, 1.0) if _dance() else (Color(0.8, 0.65, 1.0) if archer else (Color(1.0, 0.6, 0.5) if drum else Color(0.45, 0.95, 0.65)))
	if triple and not _dance():
		body_col = Color(1.0, 0.85, 0.4)
	draw_circle(Vector2.ZERO, r, body_col)
	draw_arc(Vector2.ZERO, r + 6.0 + sin(_t * 6.0) * 3.0, 0.0, TAU, 48, Color.from_hsv(fmod(_t * 0.5, 1.0), 0.6, 1.0, 0.7), 4.0)
	draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.25, Color(0.8, 1.0, 0.9))
	# 目とくちばし
	draw_circle(Vector2(-r * 0.3, -r * 0.1), r * 0.12, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(r * 0.3, -r * 0.1), r * 0.12, Color(0.1, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.15, r * 0.15), Vector2(r * 0.15, r * 0.15), Vector2(0, r * 0.45)]), Color(1.0, 0.7, 0.2))
	if drum or triple:
		# 口にくわえた大きな笛
		draw_line(Vector2(0, r * 0.35), Vector2(r * 0.15, r * 0.85), Color(0.82, 0.84, 0.88), r * 0.12)
		draw_circle(Vector2(r * 0.05, r * 0.5), r * 0.08, Color(0.6, 0.62, 0.68))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 残り時間
	var dur := TRIPLE_DURATION if triple else DURATION
	draw_arc(Vector2.ZERO, r + 14.0, -PI / 2.0, -PI / 2.0 + TAU * _left / dur, 40, Color(1, 1, 1, 0.6), 3.0)
