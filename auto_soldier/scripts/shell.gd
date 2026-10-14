extends Node2D
## 大砲の砲弾・投石器の岩。放物線を描いて飛び、着弾地点の周りにまとめてダメージ。

const MissileScript := preload("res://scripts/missile.gd")
const TrapScript := preload("res://scripts/trap.gd")

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
## 居座り岩（投石器）：着弾地点に岩が5秒残る
var stay_rock := false
## 大砲・置き土産：着弾地点に置く爆弾の威力（0なら置かない）
var leave_bomb := 0.0
## 投石器・鉄塊投げ：鉄塊の見た目。chase の敵を追いかけて落ち、その敵に direct_bonus のダメージ
var iron := false
var chase: Node2D = null

var _t := 0.0
var _height := 0.0


func _process(delta: float) -> void:
	_t += delta
	if chase != null and is_instance_valid(chase) and not chase.dead:
		target = chase.global_position
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
	if direct_bonus > 0.0 and chase != null and is_instance_valid(chase) and not chase.dead:
		# 鉄塊：追いかけた敵に直撃
		chase.take_damage(direct_bonus, Vector2.ZERO, src if iron else game.sp_src(src, "sp_direct_hit"))
		game.spawn_burst(target, Color(0.75, 0.8, 0.9), 40.0)
	elif direct_bonus > 0.0:
		var near: Node2D = game.nearest_enemy(target, blast_radius)
		if near != null:
			near.take_damage(direct_bonus, Vector2.ZERO, src if iron else game.sp_src(src, "sp_direct_hit"))
	var col := Color(0.75, 0.65, 0.5) if boulder else Color(1.0, 0.6, 0.2)
	game.spawn_burst(target, col, blast_radius / 2.2)
	if meteor:
		game.spawn_burst(target, Color(1.0, 0.4, 0.1), blast_radius)
		game.ultimates._flash(Color(1.0, 0.6, 0.3))
	if bounces > 0:
		# ビリヤード：同じ向きにポーンと跳ねて、もう一度小さく爆発
		var dir := (target - start).normalized()
		var s: Node2D = game.castle._fire_shell(target, game.clamp_to_map(target + dir * 150.0, 20.0), damage * 0.5, blast_radius * 0.75, false, game.sp_src(src, "sp_fun_billiard"))
		s.flight_time = 0.45
		s.bounces = bounces - 1
	if cow:
		# 着地した牛が、6秒間近くの敵へ何度も突進する
		game.spawn_missile("cow", target, Vector2.ZERO, damage * 0.5, 22.0, 6.0, game.sp_src(src, "sp_fun_cow"))
	if fire_time > 0.0:
		game.spawn_hazard(target, blast_radius * 0.8, fire_dps, fire_time, Color(1.0, 0.45, 0.1), game.sp_src(src, "sp_incendiary"))
	for i in mines:
		# 置きすぎないように上限つき
		if game.get_tree().get_nodes_in_group("placed_mine").size() >= 36:
			break
		var mp := target + Vector2.from_angle(TAU * i / mines + randf() * 0.8) * randf_range(50.0, 110.0)
		game.spawn_placed("mine", mp, mine_damage, 26.0, 20.0, game.sp_src(src, "sp_mines"))
	if leave_bomb > 0.0 and game.get_tree().get_nodes_in_group("cannon_bombs").size() < 24:
		var b := TrapScript.new()
		b.game = game
		b.kind = "bomb"
		b.from_cannon = true
		b.fixed_damage = leave_bomb
		b.fixed_radius = blast_radius
		b.src = game.sp_src(src, "sp_cannon_bomb")
		b.position = target
		game.ground.add_child(b)
	if stay_rock:
		game.spawn_placed("boulder", target, damage * 0.3, blast_radius * 0.6, 5.0, game.sp_src(src, "sp_stay_rock"))
	if roll_damage > 0.0:
		var away: Vector2 = (target - game.castle.global_position).normalized()
		var m: Node2D = game.spawn_missile("ball", target, away.rotated(randf_range(-0.3, 0.3)) * 420.0, roll_damage, 30.0, 3.0, game.sp_src(src, "sp_rolling"))
		m.look = "rock"
	for i in split_count:
		var p := target + Vector2.from_angle(TAU * i / split_count + randf() * 0.5) * randf_range(blast_radius * 0.8, blast_radius * 1.2)
		game.spawn_blast(p, 0.3 + 0.08 * i, 70.0, damage * 0.4, game.sp_src(src, "sp_split_rock"), Color(0.75, 0.65, 0.5), "rock")
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
	if iron:
		# 鉄塊（重そうな黒い四角）
		draw_arc(target - position, blast_radius, 0.0, TAU, 32, Color(0.8, 0.85, 1.0, 0.45), 2.0)
		draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2(0, -_height), _t * 6.0, Vector2.ONE)
		draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), Color(0.25, 0.26, 0.3))
		draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), Color(0.55, 0.57, 0.62), false, 3.0)
		draw_rect(Rect2(Vector2(-10, -10), Vector2(8, 8)), Color(0.6, 0.62, 0.68))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
