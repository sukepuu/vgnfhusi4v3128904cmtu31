extends Node2D
## 特別強化で設置される、いろいろな物。
## spikes    ：迎撃兵の拒馬の柵。上にいる敵にダメージを与え続け、足を止める
## watchtower：築城兵の見張り櫓。ずっと残り、近くの敵へ矢を撃つ
## sentry    ：工兵の自動砲台。しばらくのあいだ近くの敵を連射する
## mine      ：大砲の機雷。敵が触れると爆発
## snowman   ：結界の雪だるま。敵が近づくと爆発して周りを凍らせる

const BulletScript := preload("res://scripts/bullet.gd")

var game: Node2D
var kind := "spikes"
var damage := 20.0
var radius := 50.0
## 残り時間（0以下ならずっと残る）
var life := 10.0
var src: Dictionary = {}

var _t := 0.0
var _cd := 0.0
var _aim := Vector2.UP
var _forever := false


func _ready() -> void:
	add_to_group("placed_" + kind)
	_forever = life <= 0.0
	_cd = randf() * 0.5


func _process(delta: float) -> void:
	_t += delta
	_cd -= delta
	if not _forever:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
	match kind:
		"spikes":
			if _cd <= 0.0:
				_cd = 0.5
				for e in _enemies_inside(radius):
					e.take_damage(damage * 0.5, Vector2.ZERO, src)
					e.stun(0.3)
		"watchtower":
			# 時間とともに威力が上がる
			if _cd <= 0.0 and _fire(400.0, damage * (1.0 + game.elapsed / 180.0), 680.0, Color(0.95, 0.85, 0.6)):
				_cd = 0.7
		"sentry":
			if _cd <= 0.0 and _fire(330.0, damage, 720.0, Color(1.0, 0.95, 0.5)):
				_cd = 0.25
		"mine", "snowman":
			if not _enemies_inside(radius).is_empty():
				if kind == "mine":
					game.explode(global_position, 75.0, damage, src, Color(1.0, 0.55, 0.2), 0.0, 260.0)
				else:
					game.explode(global_position, 130.0, damage, src, Color(0.75, 0.95, 1.0), 2.5, 200.0)
					game.spawn_burst(global_position, Color(1, 1, 1), 40.0)
				queue_free()
				return
	queue_redraw()


func _enemies_inside(r: float) -> Array:
	var list: Array = []
	for e in game.enemies_near(global_position, r + 30.0):
		if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < r + e.radius:
			list.append(e)
	return list


## 一番近い敵へ弾を撃つ。撃てたら true
func _fire(rng: float, dmg: float, spd: float, col: Color) -> bool:
	var from := global_position + Vector2(0, -22.0 if kind == "watchtower" else -8.0)
	var t: Node2D = game.nearest_enemy(from, rng)
	if t == null:
		return false
	_aim = (t.global_position - from).normalized()
	var b := BulletScript.new()
	b.game = game
	b.velocity = _aim * spd
	b.damage = dmg
	b.radius = 4.0
	b.color = col
	b.life = rng / spd + 0.2
	b.position = from
	b.src = src
	game.world.add_child(b)
	return true


func _draw() -> void:
	# 消える直前は点滅
	var fade := 1.0
	if not _forever and life < 2.0 and int(life * 8.0) % 2 == 0:
		fade = 0.4
	modulate.a = fade
	match kind:
		"spikes":
			draw_circle(Vector2.ZERO, radius, Color(0.45, 0.3, 0.15, 0.18))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.5, 0.35, 0.2, 0.5), 2.0)
			# 交差した木の杭
			for i in 5:
				var p := Vector2.from_angle(TAU * i / 5.0 + 0.3) * radius * 0.55
				draw_line(p + Vector2(-9, 8), p + Vector2(9, -10), Color(0.55, 0.38, 0.2), 4.0)
				draw_line(p + Vector2(9, 8), p + Vector2(-9, -10), Color(0.55, 0.38, 0.2), 4.0)
				draw_circle(p + Vector2(9, -10), 2.0, Color(0.85, 0.85, 0.8))
				draw_circle(p + Vector2(-9, -10), 2.0, Color(0.85, 0.85, 0.8))
		"watchtower":
			draw_circle(Vector2(0, 8), 14.0, Color(0, 0, 0, 0.3))
			# 4本の柱と、上の見張り台
			for x in [-10.0, 10.0]:
				draw_line(Vector2(x, 8), Vector2(x * 0.7, -18), Color(0.5, 0.33, 0.18), 4.0)
			draw_line(Vector2(-10, -2), Vector2(10, -10), Color(0.45, 0.3, 0.15), 2.0)
			draw_rect(Rect2(Vector2(-14, -28), Vector2(28, 10)), Color(0.62, 0.42, 0.22))
			draw_colored_polygon(PackedVector2Array([Vector2(-16, -28), Vector2(0, -40), Vector2(16, -28)]), Color(0.7, 0.25, 0.2))
			draw_line(Vector2(0, -23), Vector2(0, -23) + _aim * 14.0, Color(0.3, 0.2, 0.1), 2.0)
		"sentry":
			draw_circle(Vector2(0, 6), 11.0, Color(0, 0, 0, 0.3))
			# 三脚と回る砲身
			for a in [0.5, PI - 0.5, PI * 0.5]:
				draw_line(Vector2.ZERO, Vector2.from_angle(a) * 13.0, Color(0.3, 0.3, 0.32), 3.0)
			draw_circle(Vector2(0, -8), 8.0, Color(0.45, 0.5, 0.4))
			draw_line(Vector2(0, -8), Vector2(0, -8) + _aim * 16.0, Color(0.15, 0.15, 0.15), 4.0)
			if _cd > 0.18:
				draw_circle(Vector2(0, -8) + _aim * 18.0, 4.0, Color(1.0, 0.9, 0.4))
		"mine":
			var blink := int(_t * 3.0) % 2 == 0
			draw_circle(Vector2.ZERO, 9.0, Color(0.2, 0.2, 0.22))
			for i in 6:
				var d := Vector2.from_angle(TAU * i / 6.0)
				draw_line(d * 8.0, d * 12.0, Color(0.35, 0.35, 0.38), 2.0)
			draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.2, 0.2) if blink else Color(0.4, 0.1, 0.1))
		"snowman":
			draw_circle(Vector2(0, 10), 14.0, Color(0, 0, 0, 0.25))
			draw_circle(Vector2(0, 2), 13.0, Color(0.95, 0.97, 1.0))
			draw_circle(Vector2(0, -15), 9.0, Color(0.95, 0.97, 1.0))
			draw_circle(Vector2(-3, -17), 1.5, Color(0.1, 0.1, 0.1))
			draw_circle(Vector2(3, -17), 1.5, Color(0.1, 0.1, 0.1))
			draw_line(Vector2(0, -15), Vector2(6, -13), Color(1.0, 0.55, 0.1), 2.5)
			draw_rect(Rect2(Vector2(-7, -28), Vector2(14, 6)), Color(0.2, 0.35, 0.7))
			draw_line(Vector2(-12, -2), Vector2(-20, -10), Color(0.45, 0.3, 0.15), 2.0)
			draw_line(Vector2(12, -2), Vector2(20, -10), Color(0.45, 0.3, 0.15), 2.0)
