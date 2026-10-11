extends Node2D
## 工兵部隊。ランダムな地点へ移動して、5秒かけて罠を仕掛ける。
## 爆弾 → 落とし穴 → 爆弾 … と交互に仕掛け続ける。ステータスは game.engineer_stats で共有。
## 敵からは狙われない（作業員なので戦闘には参加しない）。

const TrapScript := preload("res://scripts/trap.gd")

## フィールドに置ける罠の上限（全工兵の合計）
const MAX_TRAPS := 20

var game: Node2D
var index := 0
## waiting（城の前で待機）/ moving（移動中）/ planting（設置中）
var state := "waiting"
var next_kind := "bomb"
var target_pos := Vector2.ZERO
var progress := 0.0

var _t := 0.0
var _facing := Vector2.UP


func _process(delta: float) -> void:
	_t += delta
	match state:
		"waiting":
			_move_to(game.castle.gate_position() + Vector2(-60.0 - index * 30.0, 10.0), delta)
			if game.get_tree().get_nodes_in_group("traps").size() < MAX_TRAPS:
				target_pos = _random_spot()
				state = "moving"
		"moving":
			if _move_to(target_pos, delta):
				state = "planting"
				progress = 0.0
		"planting":
			progress += delta / game.engineer_stats.plant_time
			if progress >= 1.0:
				_place_trap()
				next_kind = "pit" if next_kind == "bomb" else "bomb"
				state = "waiting"
	queue_redraw()


## 壁の外側のランダムな地点
func _random_spot() -> Vector2:
	var rect: Rect2 = game.MAP_RECT.grow(-60.0)
	var castle_pos: Vector2 = game.castle.global_position
	var p := Vector2.ZERO
	for i in 20:
		p = Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, castle_pos.y - 40.0))
		if p.distance_to(castle_pos) > game.walls.RADIUS + 50.0:
			break
	return p


func _place_trap() -> void:
	var t := TrapScript.new()
	t.game = game
	t.kind = next_kind
	t.position = position
	game.ground.add_child(t)


## 目的地へ移動。着いたら true
func _move_to(p: Vector2, delta: float) -> bool:
	var to := p - position
	var d := to.length()
	if d < 4.0:
		return true
	_facing = to / d
	position += _facing * minf(game.engineer_stats.move_speed * delta, d)
	return false


func _draw() -> void:
	draw_circle(Vector2(0, 6), 11.0, Color(0, 0, 0, 0.3))
	# 背中の荷物
	draw_rect(Rect2(-_facing * 10.0 - Vector2(7, 7), Vector2(14, 14)), Color(0.45, 0.35, 0.2))
	draw_circle(Vector2.ZERO, 11.0, Color(0.55, 0.6, 0.35))
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color(0.25, 0.3, 0.15), 2.0)
	# ヘルメット
	draw_circle(-_facing * 2.0, 6.5, Color(0.35, 0.4, 0.25))
	# スコップ
	var side := _facing.orthogonal() * 8.0
	var dig := sin(_t * 10.0) * 6.0 if state == "planting" else 0.0
	draw_line(side, side + _facing * (14.0 + dig), Color(0.5, 0.35, 0.2), 3.0)
	draw_circle(side + _facing * (16.0 + dig), 4.0, Color(0.6, 0.6, 0.65))
	# 設置中の進み具合と、何を仕掛けているか
	if state == "planting":
		draw_rect(Rect2(Vector2(-14, -22), Vector2(28, 4)), Color(0, 0, 0, 0.6))
		var col := Color(1.0, 0.45, 0.3) if next_kind == "bomb" else Color(0.75, 0.55, 0.3)
		draw_rect(Rect2(Vector2(-14, -22), Vector2(28 * progress, 4)), col)
