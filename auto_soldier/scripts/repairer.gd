extends Node2D
## 修理部隊（最大3人）。城のまわりを歩きながら、城のHPを毎秒回復する。
## 作業員なので敵からは狙われない。ステータスは game.repair_stats を全員で共有している。

var game: Node2D
var index := 0
var dead := false

var _t := 0.0
var _spot := Vector2.ZERO
var _move_cd := 0.0
var _working := false
var _wall_cd := 2.0
var _spark_cd := 0.0
var _sparks: Array = []


func _ready() -> void:
	_t = index * 0.7


func _process(delta: float) -> void:
	_t += delta
	var st = game.repair_stats
	var castle: Node2D = game.castle
	# ときどき城のまわりの別の場所へ移動して、そこで修理する
	_move_cd -= delta
	if _move_cd <= 0.0:
		_move_cd = randf_range(4.0, 7.0)
		var half: Vector2 = castle.HALF
		var side := randf_range(-1.0, 1.0)
		_spot = castle.global_position + Vector2(side * (half.x + 14.0), randf_range(-half.y - 14.0, half.y * 0.5))
	var to := _spot - position
	_working = to.length() < 6.0
	if not _working:
		position += to.normalized() * minf(110.0 * delta, to.length())
	# 城の回復（移動中も少しずつ）
	if castle.hp < castle.max_hp:
		# 緊急修理：城が危ないときは3倍の速さで直す
		var rate: float = st.heal_per_sec * (3.0 if st.emergency and castle.hp < castle.max_hp * 0.3 else 1.0)
		castle.hp = minf(castle.max_hp, castle.hp + rate * delta)
		_spark_cd -= delta
		if _working and _spark_cd <= 0.0:
			_spark_cd = 0.25
			_sparks.append({"p": Vector2(randf_range(-6, 6), -14), "v": Vector2(randf_range(-40, 40), randf_range(-90, -40)), "t": 0.4})
	# 応急手当：近くの味方のHPを毎秒4回復
	if st.first_aid:
		_first_aid(delta)
	# 壁職人：ついでに壁も直す
	if st.wall_fix:
		_wall_cd -= delta
		if _wall_cd <= 0.0:
			_wall_cd = 4.0
			for w in game.walls.walls:
				if w["hp"] < w["max"]:
					w["hp"] = minf(w["max"], w["hp"] + 1.0)
					w["flash"] = 0.1
					break
	for s in _sparks:
		s["t"] -= delta
		s["p"] += s["v"] * delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s["t"] > 0.0)
	queue_redraw()


func _first_aid(delta: float) -> void:
	for s in game.soldiers:
		if not s.dead and position.distance_to(s.position) < 220.0:
			s.hp = minf(game.stats.max_hp, s.hp + 4.0 * delta)
	for g in game.guards:
		if not g.dead and position.distance_to(g.position) < 220.0:
			g.hp = minf(game.guard_stats.max_hp, g.hp + 4.0 * delta)
	for k in game.knights:
		if not k.dead and position.distance_to(k.position) < 220.0:
			k.hp = minf(game.knight_stats.max_hp, k.hp + 4.0 * delta)
	var h: Node2D = game.heavy
	if h != null and not h.dead and position.distance_to(h.position) < 220.0:
		h.hp = minf(h.max_hp, h.hp + 4.0 * delta)


func _draw() -> void:
	draw_circle(Vector2(0, 6), 10.0, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, 10.0, Color(0.35, 0.55, 0.85))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, Color(0.15, 0.25, 0.45), 2.0)
	# 白いキャップ
	draw_circle(Vector2(0, -3), 6.0, Color(0.95, 0.95, 0.95))
	# スパナ（作業中はトントン動く）
	var swing := sin(_t * 16.0) * 0.8 if _working else 0.3
	var arm := Vector2.from_angle(-PI / 2.0 + swing)
	draw_line(Vector2(8, 0), Vector2(8, 0) + arm * 14.0, Color(0.7, 0.7, 0.75), 3.0)
	draw_arc(Vector2(8, 0) + arm * 15.0, 4.0, 0.0, TAU * 0.75, 8, Color(0.7, 0.7, 0.75), 2.5)
	# 修理の火花
	for s in _sparks:
		draw_circle(s["p"], 2.0, Color(1.0, 0.9, 0.4, s["t"] / 0.4))
