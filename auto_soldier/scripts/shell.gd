extends Node2D
## 大砲の砲弾・投石器の岩。放物線を描いて飛び、着弾地点の周りにまとめてダメージ。

const MissileScript := preload("res://scripts/missile.gd")

var game: Node2D
var start := Vector2.ZERO
var target := Vector2.ZERO
var damage := 40.0
var blast_radius := 90.0
var flight_time := 0.7
## true なら投石器の岩（大きく、高く飛ぶ）
var boulder := false

## 撃った設備の戦績カード
var src: Dictionary = {}
## 特別強化：当たった敵の気絶時間・着弾地点の炎・砕けて周りに落ちる岩の数
var stun := 0.0
var fire_dps := 0.0
var fire_time := 0.0
var split_count := 0
## 巨岩直撃：着弾地点の真ん中の敵1体への追加ダメージ
var direct_bonus := 0.0
## 機雷散布：着弾地点の周りにばらまく機雷の数と威力
var mines := 0
var mine_damage := 0.0
## 転がり岩：着弾後に城と反対側へ転がっていく岩の威力（0なら無し）
var roll_damage := 0.0
## 隕石落とし（投石器の必殺）：大きく燃える岩として描く
var meteor := false
## ビリヤード砲弾（大砲のおもしろ強化）：着弾したあと、同じ向きにあと何回跳ねるか
var bounces := 0
## 牛投げ（投石器のおもしろ強化）：岩のかわりに牛が飛んでいき、着地したら走り出す
var cow := false

var _t := 0.0
var _height := 0.0


func _process(delta: float) -> void:
	_t += delta
	var k := minf(_t / flight_time, 1.0)
	position = start.lerp(target, k)
	_height = sin(k * PI) * (240.0 if boulder else 140.0)
	if k >= 1.0:
		_explode()
		return
	queue_redraw()


func _explode() -> void:
	for e in game.enemies_near(target, blast_radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - target
		if to.length() < blast_radius + e.radius:
			if stun > 0.0:
				e.stun(stun)
			e.take_damage(damage, to.normalized() * 300.0, src)
	if direct_bonus > 0.0:
		var near: Node2D = game.nearest_enemy(target, blast_radius)
		if near != null:
			near.take_damage(direct_bonus, Vector2.ZERO, src)
	var col := Color(0.75, 0.65, 0.5) if boulder else Color(1.0, 0.6, 0.2)
	game.spawn_burst(target, col, blast_radius / 2.2)
	if meteor:
		game.spawn_burst(target, Color(1.0, 0.4, 0.1), blast_radius)
		game.ultimates._flash(Color(1.0, 0.6, 0.3))
	if bounces > 0:
		# ビリヤード：同じ向きにポーンと跳ねて、もう一度小さく爆発
		var dir := (target - start).normalized()
		var s: Node2D = game.castle._fire_shell(target, game.clamp_to_map(target + dir * 150.0, 20.0), damage * 0.5, blast_radius * 0.75, false, src)
		s.flight_time = 0.45
		s.bounces = bounces - 1
	if cow:
		# 着地した牛が、城と反対の方へ暴走する
		var away: Vector2 = (target - game.castle.global_position).normalized()
		var m: Node2D = game.spawn_missile("ball", target, away.rotated(randf_range(-0.4, 0.4)) * 330.0, damage * 0.5, 22.0, 3.5, src)
		m.look = "cow"
	if fire_time > 0.0:
		game.spawn_hazard(target, blast_radius * 0.8, fire_dps, fire_time, Color(1.0, 0.45, 0.1), src)
	for i in mines:
		# 置きすぎないように上限つき
		if game.get_tree().get_nodes_in_group("placed_mine").size() >= 36:
			break
		var mp := target + Vector2.from_angle(TAU * i / mines + randf() * 0.8) * randf_range(50.0, 110.0)
		game.spawn_placed("mine", mp, mine_damage, 26.0, 20.0, src)
	if roll_damage > 0.0:
		var away: Vector2 = (target - game.castle.global_position).normalized()
		var m: Node2D = game.spawn_missile("ball", target, away.rotated(randf_range(-0.3, 0.3)) * 420.0, roll_damage, 30.0, 3.0, src)
		m.look = "rock"
	for i in split_count:
		var p := target + Vector2.from_angle(TAU * i / split_count + randf() * 0.5) * randf_range(blast_radius * 0.8, blast_radius * 1.2)
		game.spawn_blast(p, 0.3 + 0.08 * i, 70.0, damage * 0.4, src, Color(0.75, 0.65, 0.5), "rock")
	queue_free()


func _draw() -> void:
	if cow:
		# 空飛ぶ牛（くるくる回る）
		draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2(0, -_height), _t * 8.0, Vector2.ONE)
		MissileScript.draw_cow(self, false, _t * 10.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if meteor:
		var k := _t / flight_time
		draw_arc(target - position, blast_radius, 0.0, TAU, 48, Color(1.0, 0.3, 0.1, 0.4 + 0.4 * k), 4.0)
		draw_circle(target - position, blast_radius * k, Color(1.0, 0.3, 0.1, 0.15))
		# 炎の尾
		var back := (start - target).normalized()
		for i in 6:
			draw_circle(back * (20.0 + i * 16.0), 30.0 - i * 4.0, Color(1.0, 0.5 - i * 0.06, 0.1, 0.5 - i * 0.07))
		draw_circle(Vector2.ZERO, 32.0, Color(0.35, 0.2, 0.15))
		draw_circle(Vector2(-8, -8), 12.0, Color(0.6, 0.35, 0.2))
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 32, Color(1.0, 0.6, 0.2), 4.0)
		return
	if boulder:
		# 着弾予定地を表示
		draw_arc(target - position, blast_radius, 0.0, TAU, 40, Color(1.0, 0.8, 0.5, 0.35), 2.0)
		draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
		draw_circle(Vector2(0, -_height), 14.0, Color(0.45, 0.42, 0.4))
		draw_circle(Vector2(-4, -_height - 4), 5.0, Color(0.6, 0.58, 0.55))
		return
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.3))
	draw_circle(Vector2(0, -_height), 8.0, Color(0.15, 0.15, 0.18))
	draw_circle(Vector2(-2, -_height - 2), 3.0, Color(0.5, 0.5, 0.55))
