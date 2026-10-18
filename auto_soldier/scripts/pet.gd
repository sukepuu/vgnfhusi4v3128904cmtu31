extends Node2D
## ペット。担当の遊撃兵のまわりを回りながら、近くの敵を自動で撃つ。
## 「ペットの仲間」を取るたびに、全遊撃兵に1匹ずつ付く。

const BulletScript := preload("res://scripts/bullet.gd")

var game: Node2D
## 担当の遊撃兵と、その兵士のペットの中での番号
var owner_soldier: Node2D
var index := 0
var damage := 3.0
## 通常攻撃（ペット弾）の威力の倍率。特別強化のダメージにはかからない
## 通常弾の威力（以前は基本の4倍だったが、基本値に吸収）
## 爆裂ペット弾の爆発（ペット弾の威力 × これ。前は0.7）
const BURST_RATIO := 0.35
var record: Dictionary
var interval := 0.8
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
## 突撃ペットの突進の威力（ペットの攻撃力の何倍か。16倍の2倍）
const CHARGE_MULT := 32.0
## 体当たりペットの威力（ペットの攻撃力の何倍か。6倍の2倍）
const BODY_MULT := 12.0
## 爆裂突撃ペット：突進が当たった敵の位置で小爆発（突進の70%）
const CHARGE_BURST_RADIUS := 50.0
const CHARGE_BURST_RATIO := 0.7
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
	var is_archer: bool = game.archers.has(owner_soldier)
	var unit_name := "弓兵" if is_archer else "遊撃兵"
	record = game.new_record("pet", "%s%dのペット%d" % [unit_name, owner_soldier.index + 1, index + 1])
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
	var n: int = maxi(game.pets_per_soldier, 1)
	var ang: float = game.elapsed * 1.6 + TAU * index / n
	var target_pos: Vector2 = center + Vector2.from_angle(ang) * 60.0
	# 突撃ペット（合体中で隠れているあいだは突進しない）
	var is_archer_pet: bool = game.archers.has(owner_soldier)
	if (game.pet_charge and not is_archer_pet or game.archer_pet_charge and is_archer_pet) and visible:
		_update_charge(delta, target_pos)
	else:
		_charge_state = 0
		_trail.clear()
		_charge_tick = charge_cycle(game)
	if _charge_state == 0:
		position = position.lerp(target_pos, 1.0 - exp(-10.0 * delta))

	# ペットの強化は全ペット共通（game のペット用の値を使う）
	interval = game.archer_pet_interval if is_archer_pet else game.pet_interval
	attack_range = game.archer_pet_range if is_archer_pet else game.pet_range
	scale = Vector2(1.7, 1.7) if (game.pet_giant and not is_archer_pet) or (game.archer_pet_giant and is_archer_pet) else Vector2.ONE
	# 癒しのさえずり：担当の遊撃兵のHPを少しずつ回復
	if game.pet_heal and not owner_soldier.dead and not is_archer_pet:
		game.heal_unit(owner_soldier, game.stats.max_hp, 2.0 * delta, record, "sp_pet_heal")
	if game.archer_pet_dance and is_archer_pet and fmod(game.elapsed, 5.0) < delta:
		for i in 12:
			var dir := Vector2.from_angle(TAU * i / 12.0)
			var b := BulletScript.new()
			b.game = game
			b.velocity = dir * 400.0
			b.damage = damage * 20.0
			b.radius = 6.0
			b.color = Color(1, 0.5, 1)
			b.life = 1.2
			b.position = global_position
			b.src = game.sp_src(record, "sp_archer_pet_dance")
			game.world.add_child(b)
	if game.archer_pet_flock and is_archer_pet and fmod(game.elapsed, 15.0) < delta:
		for i in 6:
			var target := _nearest_enemy()
			if target == null:
				break
			var dir := (target.global_position - global_position).normalized().rotated(randf_range(-0.3, 0.3))
			var b := BulletScript.new()
			b.game = game
			b.velocity = dir * 600.0
			b.damage = damage * 12.0
			b.radius = 5.0
			b.color = Color(0.9, 0.9, 1)
			b.life = 1.5
			b.position = global_position
			b.src = game.sp_src(record, "sp_archer_pet_flock")
			game.world.add_child(b)
	# 体当たりペット：触れた敵にペットの BODY_MULT（12）倍ダメージ（同じ敵は0.5秒に1回）
	if game.pet_body or (game.archer_pet_body and is_archer_pet):
		_body_slam(delta)
	_cd -= delta
	# 突進中・戻り中は撃たない
	if _cd <= 0.0 and _charge_state == 0:
		var target := _nearest_enemy()
		if target != null:
			_aim = (target.global_position - global_position).normalized()
			if is_archer_pet:
				var slash_count: int = game.archer_pet_shots
				for i in slash_count:
					_do_slash()
			else:
				var shots: int = game.pet_shots
				for k in shots:
					_shoot_one(target, k, shots)
			_cd = interval
	queue_redraw()


func _do_slash() -> void:
	var radius := 85.0
	var dmg := damage
	var is_archer_pet: bool = game.archers.has(owner_soldier)
	if game.archer_pet_giant and is_archer_pet:
		radius *= 1.3
		dmg *= 1.4
	for e in game.enemies_near(global_position, radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() < radius + e.radius:
			e.take_damage(dmg, to.normalized() * 380.0, record)
			if game.archer_pet_burst and is_archer_pet:
				game.explode(e.global_position, 45.0, dmg * 0.35, game.sp_src(record, "sp_archer_pet_burst"), Color(1.0, 0.7, 0.4), 0.0, 120.0)
			if game.archer_pet_frost and is_archer_pet and randf() < 0.3:
				e.stun(0.5)
	# 簡易的な斬撃エフェクト
	game.spawn_burst(global_position, Color(0.8, 0.9, 1.0), radius * 0.4)


## 1発撃つ。何発も撃つときは少しずつ横にずらして、どれも狙った敵へ向かわせる
func _shoot_one(target: Node2D, k: int, shots: int) -> void:
	var offset: Vector2 = _aim.orthogonal() * (k - (shots - 1) / 2.0) * 8.0
	var dir: Vector2 = (target.global_position - (global_position + offset)).normalized()
	var b := BulletScript.new()
	b.game = game
	b.velocity = dir * 520.0
	b.damage = damage
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
		b.explode_ratio = BURST_RATIO
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
	var is_archer_pet: bool = game.archers.has(owner_soldier)
	for e in game.enemies_near(global_position, r + 60.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var id: int = e.get_instance_id()
		if _charge_hits.has(id):
			continue
		if global_position.distance_to(e.global_position) < r + e.radius + 3.0:
			_charge_hits[id] = true
			var dmg: float = game.pet_damage * CHARGE_MULT
			var hit_pos: Vector2 = e.global_position
			e.take_damage(dmg, _aim * 260.0, game.sp_src(record, "sp_pet_charge"))
			if game.pet_charge_burst or (game.archer_pet_charge_burst and is_archer_pet):
				game.explode(hit_pos, CHARGE_BURST_RADIUS, dmg * CHARGE_BURST_RATIO, game.sp_src(record, "sp_pet_charge_burst"), Color(1.0, 0.7, 0.3))


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
			e.take_damage(game.pet_damage * BODY_MULT, (e.global_position - global_position).normalized() * 200.0, game.sp_src(record, "sp_pet_body"))


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
	var bob := sin(_t * 6.0) * 2.0
	draw_circle(Vector2(0, 10), 7.0, Color(0, 0, 0, 0.25))
	var c := Vector2(0, bob)
	if game.fun.pet_dance:
		# ペットの踊り：虹色に光りながら、その場でくるくる回る
		var hue := fmod(_t * 0.8 + index * 0.3, 1.0)
		draw_circle(c, 15.0, Color.from_hsv(hue, 0.7, 1.0, 0.35))
		for i in 6:
			var a := _t * 4.0 + TAU * i / 6.0
			draw_circle(c + Vector2.from_angle(a) * 14.0, 2.5, Color.from_hsv(fmod(hue + i / 6.0, 1.0), 0.8, 1.0))
		draw_set_transform(c, _t * 9.0, Vector2.ONE)
		c = Vector2.ZERO
	draw_circle(c, 9.0, Color.from_hsv(fmod(_t * 0.8 + index * 0.3, 1.0), 0.55, 1.0) if game.fun.pet_dance else Color(0.45, 0.95, 0.65))
	var wing := sin(_t * 18.0) * 4.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-15, -4 - wing), c + Vector2(-8, 5)]), Color(0.3, 0.75, 0.5))
	draw_colored_polygon(PackedVector2Array([c + Vector2(6, 0), c + Vector2(15, -4 - wing), c + Vector2(8, 5)]), Color(0.3, 0.75, 0.5))
	draw_circle(c + _aim * 4.0 + Vector2(-2, -2), 1.8, Color(0.1, 0.1, 0.1))
	draw_circle(c + _aim * 4.0 + Vector2(2, -2), 1.8, Color(0.1, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([c + _aim * 12.0, c + _aim * 7.0 + _aim.orthogonal() * 3.0, c + _aim * 7.0 - _aim.orthogonal() * 3.0]), Color(1.0, 0.8, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
