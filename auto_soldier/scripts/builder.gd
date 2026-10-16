extends Node2D
## 築城部隊。壁のすき間を見つけて歩いていき、壁を建てる。
## 敵からは狙われない（作業員なので戦闘には参加しない）。
## 複数いるときは、ほかの作業員が建設中の場所を避けて別々の壁を建てる。

var game: Node2D
var index := 0
## idle（城の前で待機）/ walking（現場へ移動）/ building（建設中）
## 見張り櫓を建てるときは tower_job = true（plan の代わりに tower_spot へ行く）
var state := "idle"
## 建設予定の壁 Vector2(開始角, 終了角)
var plan := Vector2.ZERO
var progress := 0.0
var tower_job := false
var tower_spot := Vector2.ZERO
var record: Dictionary
## 見張り櫓：待機中に乗っている（乗りに行っている）櫓
var post: Node2D = null
## 櫓の上で立つ場所（櫓の位置から）
const POST_OFFSET := Vector2(0, -24)

const SPEED := 120.0
var _t := 0.0
var _facing := Vector2.UP


func _ready() -> void:
	record = game.new_record("builder", "築城兵%d" % (index + 1))


func _process(delta: float) -> void:
	_t += delta
	var walls: Node2D = game.walls
	match state:
		"idle":
			# 見張り櫓が足りなければ先に建てる
			if walls.watchtower and _towers_planned() < walls.MAX_WATCHTOWERS:
				tower_job = true
				# 見張り櫓は壁の内側（城と壁のあいだ）の、まだ空いている場所に建てる
				tower_spot = _free_tower_spot()
				state = "walking"
				queue_redraw()
				return
			var spot = walls.find_build_spot(_reserved_by_others())
			if spot != null:
				post = null
				tower_job = false
				plan = spot
				state = "walking"
				return
			# 待機中：空いている見張り櫓に乗って、櫓から射撃する（櫓がなければ城の前で待つ）
			if walls.watchtower:
				if post == null or not is_instance_valid(post):
					post = _free_post()
				if post != null:
					_move_to(post.global_position + POST_OFFSET, delta)
					return
			var home: Vector2 = game.castle.gate_position() + Vector2(60.0 + index * 30.0, 10.0)
			# 見張り櫓がなければ、採掘場が空いていれば掘りに行く
			_move_to(game.mine_spot(self, home), delta)
		"walking":
			if _move_to(tower_spot if tower_job else _site(), delta):
				state = "building"
				progress = 0.0
		"building":
			if tower_job:
				# 見張り櫓は6秒で完成
				progress += delta / 6.0
				if progress >= 1.0:
					game.spawn_placed("watchtower", tower_spot + Vector2(0, -26), 480.0, 0.0, 0.0, game.sp_src(record, "sp_watchtower"))
					tower_job = false
					state = "idle"
				queue_redraw()
				return
			_facing = (walls.point_at((plan.x + plan.y) / 2.0) - global_position).normalized()
			progress += delta / walls.build_time
			if progress >= 1.0:
				walls.add_wall(plan, record)
				record["walls"] += 1
				state = "idle"
	queue_redraw()


## 壁の内側に立って作業する
func _site() -> Vector2:
	return game.walls.point_at((plan.x + plan.y) / 2.0, game.walls.RADIUS - 24.0)


## 見張り櫓を建てる場所：壁の内側に等間隔で3か所。建っている櫓や、ほかの築城兵が向かっている場所は避ける
func _free_tower_spot() -> Vector2:
	var walls: Node2D = game.walls
	var taken: Array = []
	for t in game.get_tree().get_nodes_in_group("placed_watchtower"):
		taken.append(t.global_position + Vector2(0, 26))
	for b in game.builders:
		if b != self and b.state != "idle" and b.tower_job:
			taken.append(b.tower_spot)
	var n: int = walls.MAX_WATCHTOWERS
	var free: Array = []
	for i in n:
		var spot: Vector2 = walls.point_at(PI + PI * (i + 1) / float(n + 1), walls.RADIUS - 60.0)
		var ok := true
		for p in taken:
			if spot.distance_to(p) < 30.0:
				ok = false
		if ok:
			free.append(spot)
	if free.is_empty():
		return walls.point_at(randf_range(PI + 0.35, TAU - 0.35), walls.RADIUS - 60.0)
	return free.pick_random()


## まだだれも乗っていない見張り櫓（いちばん近いもの）
func _free_post() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for t in game.get_tree().get_nodes_in_group("placed_watchtower"):
		var used := false
		for b in game.builders:
			if b != self and b.post == t:
				used = true
		if used:
			continue
		var d: float = position.distance_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best


## この築城兵が櫓の上に乗っているか
func is_on_post(t: Node2D) -> bool:
	return state == "idle" and post == t and position.distance_to(t.global_position + POST_OFFSET) < 6.0


## 建っている櫓と、ほかの築城兵が建てに行っている櫓の数
func _towers_planned() -> int:
	var n: int = game.get_tree().get_nodes_in_group("placed_watchtower").size()
	for b in game.builders:
		if b != self and b.state != "idle" and b.tower_job:
			n += 1
	return n


func _reserved_by_others() -> Array:
	var res: Array = []
	for b in game.builders:
		if b != self and b.state != "idle" and not b.tower_job:
			res.append(b.plan)
	return res


## 目的地へ移動。着いたら true
func _move_to(p: Vector2, delta: float) -> bool:
	var to := p - position
	var d := to.length()
	if d < 4.0:
		return true
	_facing = to / d
	position += _facing * minf(SPEED * game.mine_speed_mult(self) * delta, d)
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
