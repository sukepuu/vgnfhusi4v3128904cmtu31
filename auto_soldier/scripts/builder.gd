extends Node2D
## 築城部隊。壁のすき間を見つけて歩いていき、壁を建てる。
## 敵からは狙われない（作業員なので戦闘には参加しない）。

var game: Node2D
var index := 0
## idle（城の前で待機）/ walking（現場へ移動）/ building（建設中）
var state := "idle"
## 建設予定の壁 Vector2(開始角, 終了角)
var plan := Vector2.ZERO
var progress := 0.0

const SPEED := 120.0
var _t := 0.0
var _facing := Vector2.UP


func _process(delta: float) -> void:
	_t += delta
	var walls: Node2D = game.walls
	match state:
		"idle":
			var home: Vector2 = game.castle.gate_position() + Vector2(60.0 + index * 30.0, 10.0)
			_move_to(home, delta)
			var spot = walls.find_build_spot(_reserved_by_others())
			if spot != null:
				plan = spot
				state = "walking"
		"walking":
			if _move_to(_site(), delta):
				state = "building"
				progress = 0.0
		"building":
			_facing = (walls.point_at((plan.x + plan.y) / 2.0) - global_position).normalized()
			progress += delta / walls.build_time
			if progress >= 1.0:
				walls.add_wall(plan)
				state = "idle"
	queue_redraw()


## 壁の内側に立って作業する
func _site() -> Vector2:
	return game.walls.point_at((plan.x + plan.y) / 2.0, game.walls.RADIUS - 24.0)


func _reserved_by_others() -> Array:
	var res: Array = []
	for b in game.builders:
		if b != self and b.state != "idle":
			res.append(b.plan)
	return res


## 目的地へ移動。着いたら true
func _move_to(p: Vector2, delta: float) -> bool:
	var to := p - position
	var d := to.length()
	if d < 4.0:
		return true
	_facing = to / d
	position += _facing * minf(SPEED * delta, d)
	return false


func _draw() -> void:
	draw_circle(Vector2(0, 6), 11.0, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, 11.0, Color(0.85, 0.6, 0.3))
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color(0.4, 0.25, 0.1), 2.0)
	# 黄色いヘルメット
	draw_circle(-_facing * 2.0, 6.5, Color(1.0, 0.85, 0.2))
	# ハンマー（建設中は振る）
	var swing := sin(_t * 14.0) * 0.9 if state == "building" else 0.0
	var arm := _facing.rotated(swing)
	var side := _facing.orthogonal() * 8.0
	draw_line(side, side + arm * 16.0, Color(0.45, 0.3, 0.15), 3.0)
	draw_line(side + arm * 16.0 - arm.orthogonal() * 5.0, side + arm * 16.0 + arm.orthogonal() * 5.0, Color(0.5, 0.5, 0.55), 5.0)
	# 建設の進み具合
	if state == "building":
		draw_rect(Rect2(Vector2(-14, -22), Vector2(28, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(Vector2(-14, -22), Vector2(28 * progress, 4)), Color(1.0, 0.85, 0.3))
