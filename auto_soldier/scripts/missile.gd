extends Node2D
## 特別強化で飛んでいく、いろいろな物。
## boomerang：遊撃兵のブーメラン。飛んでいって戻ってくる（行きと帰りでそれぞれ敵を貫く）
## ball     ：重装兵の鉄球・投石器の転がり岩。転がりながらだんだん遅くなり、ひいた敵を吹き飛ばす
## homing   ：矢倉の追尾火矢。敵を追いかけて、当たると小爆発
## rider    ：近衛の必殺「百騎突撃」の騎士の幻。まっすぐ駆け抜けて、通った敵を全部はねる
## cow      ：牛投げの牛。着地してから life 秒のあいだ、近くの敵へ何度も突進する

var game: Node2D
var kind := "boomerang"
var velocity := Vector2.ZERO
var damage := 20.0
var radius := 14.0
var life := 3.0
var color := Color(1, 1, 1)
## 撃った味方の戦績カード
var src: Dictionary = {}
## ブーメランが戻っていく相手（いなくなったら投げた場所へ）
var thrower: Node2D = null
## 追尾する敵
var target: Node2D = null
## 鳥の体の色（ふつうは白い鳩。鳥の大群は青い鳥）
var bird_color := Color(0.95, 0.95, 0.98)
## 見た目（ball："iron" 鉄球 / "rock" 岩 / "cow" 牛、homing："arrow" 火矢 / "bird" 鳩）
var look := "iron"

var _t := 0.0
var _hit := {}
var _returning := false
var _home := Vector2.ZERO
var _spin := 0.0
## 鳩：当たった敵にくっついている間の、その敵・残りのつつく回数・次につつくまでの時間
var _stuck_on: Node2D = null
var _pecks_left := 0
var _peck_cd := 0.0
## 牛：今の突進の残り時間と、次の突進までの休み
var _charge_left := 0.0
var _rest_left := 0.3


func _ready() -> void:
	_home = global_position


func _process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if _stuck_on != null:
		_update_stuck(delta)
		return
	match kind:
		"boomerang":
			_spin += delta * 18.0
			if not _returning:
				# だんだん減速して、止まったら戻り始める
				velocity = velocity.move_toward(Vector2.ZERO, 1100.0 * delta)
				if velocity.length() < 40.0:
					_returning = true
					_hit.clear()
			else:
				var back := _home
				if thrower != null and is_instance_valid(thrower) and not thrower.dead:
					back = thrower.global_position
				var to := back - global_position
				if to.length() < 24.0:
					queue_free()
					return
				velocity = to.normalized() * 700.0
		"cow":
			_update_cow(delta)
		"ball":
			if look == "cow":
				# 牛は転がらずに走る
				_spin += delta * 14.0
			else:
				_spin += velocity.length() * delta / radius
			velocity = velocity.move_toward(Vector2.ZERO, 220.0 * delta)
			if velocity.length() < 30.0:
				game.spawn_burst(global_position, Color(0.6, 0.55, 0.5), radius * 0.6)
				queue_free()
				return
		"homing":
			if target == null or not is_instance_valid(target) or target.dead:
				target = game.nearest_enemy(global_position, 600.0)
			if target != null:
				var want := (target.global_position - global_position).normalized() * velocity.length()
				velocity = velocity.lerp(want, clampf(6.0 * delta, 0.0, 1.0)).normalized() * velocity.length()
	position += velocity * delta
	_check_hits()
	queue_redraw()


func _check_hits() -> void:
	for e in game.enemies_near(global_position, radius + 50.0):
		if not is_instance_valid(e) or e.dead or _hit.has(e):
			continue
		if global_position.distance_to(e.global_position) >= radius + e.radius:
			continue
		_hit[e] = true
		match kind:
			"homing":
				e.take_damage(damage, Vector2.ZERO, src)
				# 追尾火矢・鳩も射撃のノックバック（1.5秒に1回・下側へは押さない）
				e.shot_knockback(velocity.normalized() * 100.0)
				game.explode(global_position, 55.0, damage * 0.5, src, Color(1.0, 0.5, 0.15), 0.0, 120.0)
				if look == "bird" and is_instance_valid(e) and not e.dead:
					# 鳩：敵が生き残っていたらくっついて、1秒ごとに2回つつく
					_stuck_on = e
					_pecks_left = 2
					_peck_cd = 1.0
					life = maxf(life, 2.5)
					return
				queue_free()
				return
			"ball", "cow", "rider":
				e.take_damage(damage, velocity.normalized() * 450.0, src)
			_:
				e.take_damage(damage, velocity.normalized() * 150.0, src)


## 牛：近くの敵を見つけては突進する（突進のたびに同じ敵にもまた当たる）
func _update_cow(delta: float) -> void:
	_spin += delta * 14.0
	if _charge_left > 0.0:
		_charge_left -= delta
		if _charge_left <= 0.0:
			_rest_left = 0.35
			velocity = velocity.normalized() * 30.0
		return
	_rest_left -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
	if _rest_left > 0.0:
		return
	var t: Node2D = game.nearest_enemy(global_position, 380.0)
	if t == null:
		# 近くに敵がいなければ、のんびりうろうろ
		_rest_left = 0.5
		velocity = Vector2.from_angle(randf() * TAU) * 60.0
		return
	# 敵の向こう側まで突き抜けるつもりで突進
	_hit.clear()
	velocity = (t.global_position - global_position).normalized() * 480.0
	_charge_left = clampf(global_position.distance_to(t.global_position) / 480.0 + 0.25, 0.3, 1.0)


## 鳩が敵にくっついている間：敵と一緒に動き、1秒ごとにつつく
func _update_stuck(delta: float) -> void:
	if not is_instance_valid(_stuck_on) or _stuck_on.dead:
		# 先に倒されたら飛んでいく
		queue_free()
		return
	position = _stuck_on.global_position + Vector2(0, -_stuck_on.radius - 4.0)
	_peck_cd -= delta
	if _peck_cd <= 0.0:
		_peck_cd = 1.0
		_pecks_left -= 1
		_stuck_on.take_damage(damage, Vector2.ZERO, src)
		if _pecks_left <= 0:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	match kind:
		"boomerang":
			if look == "wrench":
				# くるくる回るスパナ（修理兵の工具投げ）
				var d := Vector2.from_angle(_spin)
				draw_line(-d * 9.0, d * 9.0, Color(0.7, 0.72, 0.78), 4.0)
				draw_arc(d * 11.0, 4.5, 0.0, TAU * 0.75, 8, Color(0.7, 0.72, 0.78), 3.0)
				draw_arc(-d * 11.0, 4.5, 0.0, TAU * 0.75, 8, Color(0.7, 0.72, 0.78), 3.0)
				return
			# くの字型
			var a := Vector2.from_angle(_spin)
			var b := a.rotated(1.9)
			draw_line(Vector2.ZERO, a * radius, Color(0.55, 0.35, 0.15), 6.0)
			draw_line(Vector2.ZERO, b * radius, Color(0.55, 0.35, 0.15), 6.0)
			draw_circle(Vector2.ZERO, 3.5, Color(0.9, 0.8, 0.5))
		"rider":
			# 半透明の金色の騎馬（馬の体・脚・騎士・槍）
			var f := 1.0 if velocity.x >= 0.0 else -1.0
			var gold := Color(1.0, 0.85, 0.4, 0.75)
			for i in 3:
				draw_circle(Vector2(-f * (14.0 + i * 12.0), 0), 10.0 - i * 2.5, Color(1.0, 0.85, 0.4, 0.25 - i * 0.07))
			for i in 4:
				var x := (-10.0 + i * 6.5) * f
				draw_line(Vector2(x, 6), Vector2(x + sin(_t * 30.0 + i * 1.6) * 5.0, 17), gold, 3.0)
			draw_circle(Vector2(-5 * f, 0), 10.0, gold)
			draw_circle(Vector2(7 * f, 0), 10.0, gold)
			draw_circle(Vector2(18 * f, -6), 6.0, gold)
			draw_circle(Vector2(0, -14), 7.0, Color(0.95, 0.95, 1.0, 0.8))
			draw_line(Vector2(-4 * f, -12), Vector2(34 * f, -12), Color(1, 1, 1, 0.9), 3.0)
		"cow":
			# 消える前は点滅
			modulate.a = 0.4 if life < 1.0 and int(life * 8.0) % 2 == 0 else 1.0
			draw_circle(Vector2(0, radius * 0.4), radius, Color(0, 0, 0, 0.3))
			draw_cow(self, velocity.x < 0.0, _spin if velocity.length() > 40.0 else 0.0)
		"ball":
			draw_circle(Vector2(0, radius * 0.4), radius, Color(0, 0, 0, 0.3))
			if look == "cow":
				draw_cow(self, velocity.x < 0.0, _spin)
			elif look == "rock":
				draw_circle(Vector2.ZERO, radius, Color(0.5, 0.46, 0.42))
				draw_circle(Vector2.from_angle(_spin) * radius * 0.45, radius * 0.3, Color(0.62, 0.58, 0.54))
				draw_circle(Vector2.from_angle(_spin + 2.5) * radius * 0.5, radius * 0.2, Color(0.4, 0.37, 0.34))
			else:
				# トゲ付き鉄球
				for i in 8:
					var d := Vector2.from_angle(_spin + TAU * i / 8.0)
					draw_line(d * radius * 0.8, d * (radius + 7.0), Color(0.55, 0.55, 0.6), 4.0)
				draw_circle(Vector2.ZERO, radius, Color(0.28, 0.28, 0.32))
				draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.3, Color(0.55, 0.55, 0.6))
		"homing":
			var dir := velocity.normalized()
			if look == "bird":
				if _stuck_on != null:
					# くっついてつつく鳩（頭がコツコツ動く）
					dir = Vector2.DOWN
				# パタパタ飛ぶ鳥（ふつうは白い鳩）
				var flap := sin(_t * 22.0) * 7.0
				var side := dir.orthogonal()
				var wing := bird_color.darkened(0.06)
				draw_colored_polygon(PackedVector2Array([side * 2.0, side * (12.0 + flap) - dir * 4.0, -dir * 6.0]), wing)
				draw_colored_polygon(PackedVector2Array([-side * 2.0, -side * (12.0 + flap) - dir * 4.0, -dir * 6.0]), wing)
				draw_circle(Vector2.ZERO, 6.0, bird_color)
				draw_circle(dir * 6.0, 4.0, bird_color)
				var peck := (absf(sin(_t * 12.0)) * 4.0) if _stuck_on != null else 0.0
				draw_colored_polygon(PackedVector2Array([dir * (13.0 + peck), dir * (8.0 + peck) + side * 2.0, dir * (8.0 + peck) - side * 2.0]), Color(1.0, 0.7, 0.2))
				return
			for i in 4:
				draw_circle(-dir * (6.0 + i * 6.0), 5.0 - i, Color(1.0, 0.5 - i * 0.08, 0.1, 0.6 - i * 0.12))
			draw_line(-dir * 10.0, dir * 8.0, Color(0.95, 0.85, 0.6), 3.0)
			draw_circle(dir * 8.0, 4.0, Color(1.0, 0.85, 0.3))


## 牛の絵（牛投げ用。投石器の弾からも使う）
static func draw_cow(ci: CanvasItem, face_left: bool, t: float, sz: float = 1.0) -> void:
	var f := -1.0 if face_left else 1.0
	# 走る足
	for i in 4:
		var x := (-10.0 + i * 6.5) * sz
		var swing := sin(t + i * 1.6) * 4.0 * sz
		ci.draw_line(Vector2(x, 6.0 * sz), Vector2(x + swing, 16.0 * sz), Color(0.2, 0.2, 0.2), 3.0 * sz)
	# 体と黒いぶち
	ci.draw_circle(Vector2(-6.0 * sz, 0), 10.0 * sz, Color(0.97, 0.97, 0.95))
	ci.draw_circle(Vector2(6.0 * sz, 0), 10.0 * sz, Color(0.97, 0.97, 0.95))
	ci.draw_circle(Vector2(-7.0 * sz, -3.0 * sz), 4.0 * sz, Color(0.15, 0.15, 0.15))
	ci.draw_circle(Vector2(5.0 * sz, 3.0 * sz), 3.5 * sz, Color(0.15, 0.15, 0.15))
	# 頭・鼻・角
	var head := Vector2(17.0 * f * sz, -5.0 * sz)
	ci.draw_circle(head, 7.0 * sz, Color(0.97, 0.97, 0.95))
	ci.draw_circle(head + Vector2(4.0 * f * sz, 3.0 * sz), 4.0 * sz, Color(1.0, 0.7, 0.75))
	ci.draw_circle(head + Vector2(1.0 * f * sz, -2.0 * sz), 1.5 * sz, Color(0, 0, 0))
	ci.draw_line(head + Vector2(-2.0 * f * sz, -6.0 * sz), head + Vector2(-4.0 * f * sz, -11.0 * sz), Color(0.9, 0.85, 0.6), 2.0 * sz)
