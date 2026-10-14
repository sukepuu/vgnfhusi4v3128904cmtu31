extends Node2D
## おもしろ特別強化の見た目（ダメージは呼んだ側か、このスクリプトの花火が計算する）
## firework：start から打ち上がって end で弾ける花火（弾けた所の敵に小ダメージ）
## jack    ：ビックリ箱（バネでピエロが飛び出す）
## roar    ：雄叫びの広がる輪
## spikes  ：剣山の壁から飛び出すトゲ
## beam_warn / beam：砲台要塞のビームの予告線と、ビーム本体（start から end まで）

var game: Node2D
var kind := "firework"
var start := Vector2.ZERO
var end := Vector2.ZERO
## 花火が飛んでいく時間
var rise_time := 0.5
var damage := 0.0
var radius := 60.0
var src: Dictionary = {}

const COLORS := [Color(1.0, 0.3, 0.3), Color(1.0, 0.8, 0.2), Color(0.4, 1.0, 0.4), Color(0.4, 0.7, 1.0), Color(1.0, 0.45, 1.0), Color(1, 1, 1)]

var _t := 0.0
var _burst := false
var _sparks: Array = []


func _ready() -> void:
	if kind == "firework":
		position = start


func _life() -> float:
	match kind:
		"firework":
			return rise_time + 0.8
		"beam_warn":
			return 1.0
		"beam":
			return 0.45
		_:
			return 0.7


func _process(delta: float) -> void:
	_t += delta
	if kind == "firework" and not _burst:
		if _t < rise_time:
			position = start.lerp(end, _t / rise_time)
		else:
			_burst = true
			position = end
			if damage > 0.0:
				game.explode(end, radius, damage, src, COLORS.pick_random(), 0.0, 150.0)
			for i in 24:
				_sparks.append({"p": Vector2.ZERO, "v": Vector2.from_angle(TAU * i / 24.0) * randf_range(110, 170), "c": COLORS.pick_random()})
	for s in _sparks:
		var v: Vector2 = s["v"]
		v *= 0.94
		v.y += 120.0 * delta
		s["v"] = v
		s["p"] += v * delta
	if _t >= _life():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	match kind:
		"firework":
			if not _burst:
				# 打ち上がるロケットと火花の尾
				var back := (start - end).normalized()
				for i in 5:
					draw_circle(back * (6.0 + i * 5.0), 3.0 - i * 0.4, Color(1.0, 0.7, 0.2, 0.8 - i * 0.15))
				draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1))
			else:
				var a := clampf(1.0 - (_t - rise_time) / 0.8, 0.0, 1.0)
				for s in _sparks:
					draw_line(s["p"], s["p"] - s["v"] * 0.05, Color(s["c"], a), 3.0)
					draw_circle(s["p"], 2.5, Color(s["c"], a))
		"jack":
			# バネが伸びて、ピエロの顔が飛び出す
			var k := minf(_t / 0.2, 1.0)
			var a := clampf((0.7 - _t) / 0.3, 0.0, 1.0)
			draw_rect(Rect2(Vector2(-12, -6), Vector2(24, 18)), Color(0.85, 0.25, 0.3, a))
			var top := Vector2(0, -6 - 40.0 * k)
			var pts := PackedVector2Array()
			for i in 9:
				pts.append(Vector2(6.0 if i % 2 == 0 else -6.0, lerpf(-6.0, top.y, i / 8.0)))
			draw_polyline(pts, Color(0.8, 0.8, 0.85, a), 2.0)
			draw_circle(top, 11.0, Color(1.0, 0.95, 0.85, a))
			draw_circle(top + Vector2(0, 2), 3.5, Color(1.0, 0.2, 0.2, a))
			draw_circle(top + Vector2(-4, -3), 1.8, Color(0, 0, 0, a))
			draw_circle(top + Vector2(4, -3), 1.8, Color(0, 0, 0, a))
			draw_colored_polygon(PackedVector2Array([top + Vector2(-10, -7), top + Vector2(0, -24), top + Vector2(10, -7)]), Color(0.3, 0.6, 1.0, a))
		"beam_warn":
			# 予告線（点滅しながらだんだん太く）
			var k := _t / 1.0
			var a := 0.35 + 0.35 * absf(sin(_t * 18.0))
			draw_line(Vector2.ZERO, end - start, Color(1.0, 0.25, 0.2, a), 2.0 + 6.0 * k)
		"beam":
			# 太いビーム（だんだん細く消える）
			var k := 1.0 - _t / 0.45
			draw_line(Vector2.ZERO, end - start, Color(1.0, 0.35, 0.25, 0.5 * k), 60.0 * k)
			draw_line(Vector2.ZERO, end - start, Color(1.0, 0.85, 0.7, 0.9 * k), 22.0 * k)
			draw_line(Vector2.ZERO, end - start, Color(1, 1, 1, k), 8.0 * k)
		"spikes":
			# 全方位にトゲがシャキーンと伸びて、引っこむ
			var k := minf(_t / 0.12, 1.0) * clampf((0.7 - _t) / 0.3, 0.0, 1.0)
			for i in 14:
				var d := Vector2.from_angle(TAU * i / 14.0 + 0.2)
				var tip := d * (30.0 + 90.0 * k)
				var side := d.orthogonal() * 7.0
				draw_colored_polygon(PackedVector2Array([d * 12.0 + side, tip, d * 12.0 - side]), Color(0.78, 0.8, 0.85, k))
				draw_line(d * 12.0, tip, Color(1, 1, 1, 0.6 * k), 1.5)
		"roar":
			var k := _t / 0.7
			draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 48, Color(1.0, 0.6, 0.3, 1.0 - k), 8.0)
			draw_arc(Vector2.ZERO, radius * k * 0.7, 0.0, TAU, 48, Color(1, 1, 1, 0.7 * (1.0 - k)), 3.0)
