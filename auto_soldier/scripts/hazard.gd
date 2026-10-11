extends Node2D
## 一定時間残るダメージ地帯（焼夷弾の炎・毒沼など）。0.5秒ごとに範囲内の敵へダメージ。

var game: Node2D
var radius := 70.0
## 1秒あたりのダメージ
var dps := 20.0
var duration := 4.0
var color := Color(1.0, 0.45, 0.1)
var src: Dictionary = {}

var _t := 0.0
var _tick := 0.0


func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for e in game.enemies_near(global_position, radius + 30.0):
			if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < radius + e.radius:
				e.take_damage(dps * 0.5, Vector2.ZERO, src)
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := clampf((duration - _t) / 0.8, 0.0, 1.0)
	var flicker := 0.85 + sin(_t * 9.0) * 0.15
	draw_circle(Vector2.ZERO, radius, Color(color, 0.22 * fade * flicker))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.6 * fade), 2.0)
	for i in 5:
		var a := _t * 1.5 + TAU * i / 5.0
		draw_circle(Vector2.from_angle(a) * radius * 0.55, radius * 0.18, Color(color.lightened(0.3), 0.3 * fade))
