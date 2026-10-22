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
var _throw_cd := 1.0
var record: Dictionary


func _ready() -> void:
	record = game.new_record("repair", "修理兵%d" % (index + 1))
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
	# 城のHPが満タンで直す仕事がないときは、採掘場が空いていれば掘りに行く
	var dest := _spot
	if castle.hp >= castle.max_hp:
		dest = game.mine_spot(self, _spot)
	var to := dest - position
	_working = to.length() < 6.0
	if not _working:
		position += to.normalized() * minf(110.0 * game.mine_speed_mult(self) * delta, to.length())
	# 城の回復（移動中も少しずつ）
	if castle.hp < castle.max_hp:
		# 緊急修理：城が危ないときは2倍の速さで直す
		# 戦績の回復量は、ふつうの修理・背水の修繕で増えたぶん・緊急修理で増えたぶんに分けて記録
		# 背水の修繕の上乗せ：城のHPが40%より多いときは+20/秒、40%以下のときは+1/秒だけ
		var base_rate: float = st.heal_per_sec - (20.0 if castle.overwork else 0.0)
		var overwork_part := 0.0
		if castle.overwork:
			overwork_part = 20.0 if castle.hp > castle.max_hp * castle.OVERWORK_FLOOR else 1.0
		castle.heal(base_rate * delta, record)
		if overwork_part > 0.0:
			castle.heal(overwork_part * delta, record, "sp_overwork")
		if st.emergency and castle.hp < castle.max_hp * 0.3:
			castle.heal((base_rate + overwork_part) * delta, record, "sp_emergency")
		_spark_cd -= delta
		if _working and _spark_cd <= 0.0:
			_spark_cd = 0.25
			_sparks.append({"p": Vector2(randf_range(-6, 6), -14), "v": Vector2(randf_range(-40, 40), randf_range(-90, -40)), "t": 0.4})
	# 工具投げ：城が満タンでヒマなときは、近くの敵へ工具を投げつける
	if st.tool_throw and castle.hp >= castle.max_hp:
		_throw_cd -= delta
		if _throw_cd <= 0.0:
			var t: Node2D = game.nearest_enemy(global_position, 520.0)
			if t != null:
				_throw_cd = 1.0
				_throw(t)
	# 応急手当：フィールド全体の味方のHPを、城と同じ量だけ回復
	if st.first_aid:
		_first_aid(st.heal_per_sec * delta)
	# 壁職人：ついでに壁も直す
	if st.wall_fix:
		_wall_cd -= delta
		if _wall_cd <= 0.0:
			_wall_cd = 4.0
			for w in game.walls.walls:
				if w["hp"] < w["max"]:
					w["hp"] = minf(w["max"], w["hp"] + 1.0)
					w["flash"] = 0.1
					record["wall_fixed"] += 1
					break
	for s in _sparks:
		s["t"] -= delta
		s["p"] += s["v"] * delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s["t"] > 0.0)
	queue_redraw()


func _throw(t: Node2D) -> void:
	var dir := (t.global_position - global_position).normalized()
	# ブーメランは毎秒1100ずつ減速するので、敵の少し向こうまで届く速さで投げる
	var dist := global_position.distance_to(t.global_position) + 30.0
	var spd := sqrt(2.0 * 1100.0 * dist)
	var b: Node2D = game.spawn_missile("boomerang", global_position, dir * spd, 18.0 * (1.0 + game.elapsed / 150.0), 10.0, 3.0, game.sp_src(record, "sp_tool_throw"))
	b.look = "wrench"
	b.thrower = self


func _first_aid(amount: float) -> void:
	for s in game.soldiers:
		if not s.dead:
			game.heal_unit(s, game.stats.max_hp, amount, record, "sp_first_aid")
	for g in game.guards:
		if not g.dead:
			game.heal_unit(g, game.guard_stats.max_hp, amount, record, "sp_first_aid")
	for k in game.knights:
		if not k.dead:
			game.heal_unit(k, game.knight_stats.max_hp, amount, record, "sp_first_aid")
	for h in game.all_heavies():
		if not h.dead:
			game.heal_unit(h, h.max_hp, amount, record, "sp_first_aid")


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
