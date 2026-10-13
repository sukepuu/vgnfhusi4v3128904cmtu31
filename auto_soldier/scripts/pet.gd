extends Node2D
## ペット。担当の遊撃兵のまわりを回りながら、近くの敵を自動で撃つ。
## 「ペットの仲間」を取るたびに、全遊撃兵に1匹ずつ付く。

const BulletScript := preload("res://scripts/bullet.gd")

var game: Node2D
## 担当の遊撃兵と、その兵士のペットの中での番号
var owner_soldier: Node2D
var index := 0
var damage := 7.0
var record: Dictionary
var interval := 0.8
var attack_range := 420.0

var _cd := 0.5
var _t := 0.0
var _aim := Vector2.RIGHT


func _ready() -> void:
	record = game.new_record("pet", "遊撃兵%dのペット%d" % [owner_soldier.index + 1, index + 1])


func _process(delta: float) -> void:
	_t += delta
	# 担当の兵士のまわりを回る。兵士が倒れているあいだは城の前で待つ
	var center: Vector2 = game.castle.gate_position() if owner_soldier.dead else owner_soldier.position
	# 同じ兵士のペット同士は等間隔に並んで回る
	var n: int = maxi(game.pets_per_soldier, 1)
	var ang := _t * 1.6 + TAU * index / n
	var target_pos: Vector2 = center + Vector2.from_angle(ang) * 60.0
	position = position.lerp(target_pos, 1.0 - exp(-10.0 * delta))

	# ペットの強化は全ペット共通（game のペット用の値を使う）
	interval = game.pet_interval
	attack_range = game.pet_range
	scale = Vector2(1.7, 1.7) if game.pet_giant else Vector2.ONE
	# 癒しのさえずり：担当の遊撃兵のHPを少しずつ回復
	if game.pet_heal and not owner_soldier.dead:
		owner_soldier.hp = minf(game.stats.max_hp, owner_soldier.hp + 2.0 * delta)
	# 体当たりペット：触れた敵にペットの3倍ダメージ（同じ敵は0.5秒に1回）
	if game.pet_body:
		_body_slam(delta)
	_cd -= delta
	if _cd <= 0.0:
		var target := _nearest_enemy()
		if target != null:
			_aim = (target.global_position - global_position).normalized()
			for k in game.pet_shots:
				_shoot_one(target, k)
			_cd = interval
	queue_redraw()


## 1発撃つ。何発も撃つときは少しずつ横にずらして、どれも狙った敵へ向かわせる
func _shoot_one(target: Node2D, k: int) -> void:
	var offset: Vector2 = _aim.orthogonal() * (k - (game.pet_shots - 1) / 2.0) * 8.0
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
	# 追尾ペット弾：敵を少し追いかける
	b.homing = game.pet_homing
	# 凍える羽根：当たった敵が0.4秒止まる
	if game.pet_frost:
		b.stun_on_hit = 0.4
		b.color = Color(0.7, 0.95, 1.0)
	# 巨大ペット：弾も大きく、2体貫通して威力アップ
	if game.pet_giant:
		b.damage *= 1.4
		b.radius = 7.0
		b.pierce = 2
	# 爆裂ペット弾：当たると小爆発
	if game.pet_burst:
		b.explode_radius = 45.0
		b.explode_ratio = 0.6
	game.world.add_child(b)


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
			e.take_damage(game.pet_damage * 3.0, (e.global_position - global_position).normalized() * 200.0, record)


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
