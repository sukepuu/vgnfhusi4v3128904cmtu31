extends Node2D
## 弓兵の特別強化で出るもの。kind で中身が変わる。
##   "orb"     … 必殺・連珠の玉。ゆっくりまっすぐ進み、0.5秒ごとに全方位へ16発の矢（貫通1）を放つ。玉そのものは敵に当たらない
##   "tornado" … 竜巻（竜巻矢が当たった所にできる）。duration 秒のあいだ、まわりの敵を中心へ吸い寄せる
##   "giant"   … 巨大竜巻。出たときに範囲の敵へダメージを与えて外へ押し出し、しばらく渦を巻いて消える
##   "sticky"  … 大砲・粘着砲のねばねば。duration 秒のあいだ、中にいる敵の移動速度を STICKY_SLOW 遅くする

const BulletScript := preload("res://scripts/bullet.gd")

var game: Node2D
var kind := "orb"
var src: Dictionary = {}
var damage := 0.0
var velocity := Vector2.ZERO
var radius := 120.0
var duration := 1.0

var _t := 0.0
var _orb_cd := ORB_EVERY

## 連珠の玉
const ORB_LIFE := 6.0
const ORB_ARROWS := 16
const ORB_EVERY := 0.5
## 竜巻の吸い寄せる強さ（1秒あたりに動かす距離）
const PULL_SPEED := 160.0
## 巨大竜巻の押し出しの強さ
const GIANT_KNOCK := 650.0
## 粘着砲：遅くする割合
const STICKY_SLOW := 0.3


func _ready() -> void:
	if kind == "orb":
		duration = ORB_LIFE
	elif kind == "giant":
		_giant_blast()


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	match kind:
		"orb":
			position += velocity * delta
			_orb_cd -= delta
			if _orb_cd <= 0.0:
				_orb_cd = ORB_EVERY
				_orb_volley()
		"tornado":
			_pull(delta)
		"sticky":
			_stick()
	queue_redraw()


## 玉から全方位へ16発の矢
func _orb_volley() -> void:
	for i in ORB_ARROWS:
		var dir := Vector2.from_angle(TAU * i / ORB_ARROWS + _t)
		var b := BulletScript.new()
		b.game = game
		b.position = global_position
		b.velocity = dir * 520.0
		b.damage = damage
		b.pierce = 1
		b.radius = 4.0
		b.bolt = true
		b.scale = Vector2(0.45, 0.45)
		b.color = Color(1.0, 0.85, 0.45)
		b.life = 0.9
		b.src = src
		game.world.add_child(b)


## 竜巻：まわりの敵（ボス以外）を中心へ少しずつ吸い寄せる
func _pull(delta: float) -> void:
	for e in game.enemies_near(global_position, radius):
		if not is_instance_valid(e) or e.dead or e.is_boss:
			continue
		var to: Vector2 = global_position - e.global_position
		if to.length() > 6.0:
			e.position += to.normalized() * minf(PULL_SPEED * delta, to.length())


## 粘着砲：中にいる敵を遅くする（出たら少しだけ残る）
func _stick() -> void:
	for e in game.enemies_near(global_position, radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		if global_position.distance_to(e.global_position) < radius + e.radius:
			e.slow(0.1, STICKY_SLOW)


## 巨大竜巻：出た瞬間に範囲の敵へダメージを与えて、外へ押し出す
func _giant_blast() -> void:
	for e in game.enemies_near(global_position, radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > radius + e.radius:
			continue
		var dir: Vector2 = to.normalized() if to.length() > 1.0 else Vector2.from_angle(randf() * TAU)
		e.take_damage(damage, dir * GIANT_KNOCK, src)
	game.spawn_burst(global_position, Color(0.7, 0.9, 1.0), radius)


func _draw() -> void:
	match kind:
		"orb":
			var pulse := 1.0 + sin(_t * 10.0) * 0.12
			draw_circle(Vector2.ZERO, 22.0 * pulse, Color(1.0, 0.8, 0.35, 0.25))
			draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.85, 0.45))
			draw_circle(Vector2(-4, -4), 5.0, Color(1, 1, 0.9, 0.9))
			for i in ORB_ARROWS:
				var a := _t * 2.0 + TAU * i / ORB_ARROWS
				draw_circle(Vector2.from_angle(a) * 19.0, 2.0, Color(1.0, 0.95, 0.7))
		"sticky":
			var fade := clampf((duration - _t) / 0.4, 0.0, 1.0)
			draw_circle(Vector2.ZERO, radius, Color(0.75, 0.55, 0.95, 0.28 * fade))
			for k in 6:
				var a := TAU * k / 6.0 + 0.4
				draw_circle(Vector2.from_angle(a) * radius * 0.55, radius * 0.18, Color(0.85, 0.65, 1.0, 0.35 * fade))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.6, 0.4, 0.85, 0.6 * fade), 2.0)
		"tornado", "giant":
			# 渦：中心へ向かって回る何本もの弧（消える前は薄くなる）
			var fade := clampf((duration - _t) / 0.4, 0.0, 1.0)
			draw_circle(Vector2.ZERO, radius, Color(0.6, 0.85, 1.0, 0.12 * fade))
			for i in 4:
				var r: float = radius * (1.0 - i * 0.22)
				var start := -_t * (8.0 + i * 3.0) + i * 1.3
				draw_arc(Vector2.ZERO, r, start, start + 4.0, 24, Color(0.8, 0.95, 1.0, 0.65 * fade), 3.0 + i)
