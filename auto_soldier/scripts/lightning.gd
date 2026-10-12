extends Node2D
## 雷の見た目だけ（ダメージは撃った側で計算済み）。ギザギザの線が少しのあいだ光って消える。

var points: PackedVector2Array = PackedVector2Array()
## 線の太さの倍率（雷神の大槍は太く）
var width := 1.0
var _t := 0.0
const LIFE := 0.35


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / LIFE
	for i in points.size() - 1:
		var p0 := points[i]
		var p1 := points[i + 1]
		# 途中を少しずつずらしてギザギザにする
		var zig := PackedVector2Array([p0])
		# 長い線ほど細かくギザギザにする
		var n := maxi(6, int(p0.distance_to(p1) / 60.0))
		var side := (p1 - p0).normalized().orthogonal()
		for k in range(1, n):
			zig.append(p0.lerp(p1, float(k) / n) + side * randf_range(-12.0, 12.0) * width)
		zig.append(p1)
		draw_polyline(zig, Color(0.6, 0.8, 1.0, 0.5 * a), 7.0 * width)
		draw_polyline(zig, Color(1.0, 1.0, 1.0, a), 2.5 * width)
		draw_circle(p1, 8.0 * a * width, Color(0.8, 0.9, 1.0, 0.7 * a))
