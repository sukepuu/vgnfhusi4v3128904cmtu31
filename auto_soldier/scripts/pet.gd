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

	_cd -= delta
	if _cd <= 0.0:
		var target := _nearest_enemy()
		if target != null:
			_aim = (target.global_position - global_position).normalized()
			var b := BulletScript.new()
			b.game = game
			b.velocity = _aim * 520.0
			b.damage = damage
			b.radius = 4.0
			b.color = Color(0.5, 1.0, 0.7)
			b.life = attack_range / 520.0 + 0.2
			b.position = global_position
			b.src = record
			game.world.add_child(b)
			_cd = interval
	queue_redraw()


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
	draw_circle(c, 9.0, Color(0.45, 0.95, 0.65))
	var wing := sin(_t * 18.0) * 4.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-15, -4 - wing), c + Vector2(-8, 5)]), Color(0.3, 0.75, 0.5))
	draw_colored_polygon(PackedVector2Array([c + Vector2(6, 0), c + Vector2(15, -4 - wing), c + Vector2(8, 5)]), Color(0.3, 0.75, 0.5))
	draw_circle(c + _aim * 4.0 + Vector2(-2, -2), 1.8, Color(0.1, 0.1, 0.1))
	draw_circle(c + _aim * 4.0 + Vector2(2, -2), 1.8, Color(0.1, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([c + _aim * 12.0, c + _aim * 7.0 + _aim.orthogonal() * 3.0, c + _aim * 7.0 - _aim.orthogonal() * 3.0]), Color(1.0, 0.8, 0.3))
