extends Node2D
## 工兵部隊。ランダムな地点へ移動して、6秒かけて罠を仕掛ける。
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
var record: Dictionary
var progress := 0.0

var _t := 0.0
var _facing := Vector2.UP


func _ready() -> void:
	record = game.new_record("engineer", "工兵%d" % (index + 1))


func _process(delta: float) -> void:
	_t += delta
	match state:
		"waiting":
			# 罠が上限で置けないあいだは、採掘場が空いていれば掘りに行く
			_move_to(game.mine_spot(self, game.castle.gate_position() + Vector2(-60.0 - index * 30.0, 10.0)), delta)
			var cap := MAX_TRAPS + (10 if game.engineer_stats.double_plant else 0)
			if game.get_tree().get_nodes_in_group("traps").size() < cap:
				target_pos = _random_spot()
				state = "moving"
		"moving":
			if _move_to(target_pos, delta):
				state = "planting"
				progress = 0.0
		"planting":
			progress += delta * game.atk_speed_mult(record) / game.engineer_stats.plant_time
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
	_spawn_trap(next_kind, position)
	# かかし：罠の後ろにかかしを立てて、敵の気を引く（工兵1人につき2体まで）
	if game.engineer_stats.scarecrow:
		var mine_n := 0
		for p in game.get_tree().get_nodes_in_group("placed_scarecrow"):
			if is_same(p.src, record):
				mine_n += 1
		if mine_n < 2:
			game.spawn_placed("scarecrow", position + _facing.orthogonal() * 40.0, 0.0, 14.0, 40.0, record)
	# 自動砲台：罠の隣に砲台も置く（同時に置けるのは工兵1人につき3台まで）
	if game.engineer_stats.sentry:
		var mine := 0
		for p in game.get_tree().get_nodes_in_group("placed_sentry"):
			if is_same(p.src, game.sp_src(record, "sp_sentry")):
				mine += 1
		if mine < 3:
			game.spawn_placed("sentry", position - _facing.orthogonal() * 40.0, 2.8 * (1.0 + game.elapsed / 150.0) * game.engineer_stats.attack_power / 180.0, 0.0, 30.0, game.sp_src(record, "sp_sentry"))
	# 二重設置：もう1種類の罠も隣に仕掛ける
	if game.engineer_stats.double_plant:
		_spawn_trap("pit" if next_kind == "bomb" else "bomb", game.clamp_to_map(position + _facing.orthogonal() * 45.0, 20.0))


func _spawn_trap(kind: String, pos: Vector2) -> void:
	var t := TrapScript.new()
	t.game = game
	t.kind = kind
	t.src = record
	record["traps"] += 1
	t.position = pos
	game.ground.add_child(t)


## 目的地へ移動。着いたら true
func _move_to(p: Vector2, delta: float) -> bool:
	var to := p - position
	var d := to.length()
	if d < 4.0:
		return true
	_facing = to / d
	position += _facing * minf(game.engineer_stats.move_speed * game.mine_speed_mult(self) * delta, d)
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
