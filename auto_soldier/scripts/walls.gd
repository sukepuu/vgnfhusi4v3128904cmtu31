extends Node2D
## 城を中心とした半円状（城の上側180度）の壁。築城部隊が1枚ずつ建てる。
## 壁はダメージの大きさに関係なく、耐久回数（最初は10発）ぶんの攻撃を完全に防ぐ。
## 角度はGodotの向き（右=0、y軸が下向き）なので、上半分は PI〜TAU になる。

const RADIUS := 215.0
const THICKNESS := 14.0
const ARC_START := PI
const ARC_END := TAU
const TOP := PI * 1.5

var game: Node2D

# --- 築城部隊のステータス（強化で変わる）
var build_time := 20.0
## 壁1枚が防げる攻撃の回数
var wall_max_hp := 10.0
var wall_width := deg_to_rad(12.0)

# --- 特別強化
## 砲台壁（壁から弾を撃つ）
var turret_level := 0
## 自己修復（壁が少しずつ回復）
var repair_level := 0
## 爆裂壁（防ぐたびにその場で爆発）
var explode_on_block := false

const BulletScript := preload("res://scripts/bullet.gd")

## 建っている壁。{"a0": 開始角, "a1": 終了角, "hp": 残り回数, "max": 最大回数, "flash": 被弾演出}
var walls: Array = []


func _process(delta: float) -> void:
	for w in walls:
		w["flash"] = maxf(0.0, w["flash"] - delta)
		if turret_level > 0:
			_update_turret(w, delta)
		if repair_level > 0 and w["hp"] < w["max"]:
			w["rep"] = w.get("rep", 0.0) + delta
			if w["rep"] >= 3.0:
				w["rep"] = 0.0
				w["hp"] = minf(w["max"], w["hp"] + 1.0)
	queue_redraw()


## 砲台壁：壁の中央から近くの敵へ弾を撃つ（時間とともに威力も上がる）
func _update_turret(w: Dictionary, delta: float) -> void:
	w["cd"] = w.get("cd", randf() * 1.5) - delta
	if w["cd"] > 0.0:
		return
	var from := point_at((w["a0"] + w["a1"]) / 2.0)
	var target: Node2D = game.nearest_enemy(from, 340.0)
	if target == null:
		return
	w["cd"] = 2.0 / (1.0 + 0.5 * (turret_level - 1))
	var dir := (target.global_position - from).normalized()
	var b := BulletScript.new()
	b.game = game
	b.velocity = dir * 640.0
	b.damage = 15.0 * turret_level * (1.0 + game.elapsed / 180.0)
	b.radius = 5.0
	b.color = Color(0.85, 0.8, 0.7)
	b.life = 340.0 / 640.0 + 0.2
	b.position = from
	b.src = w["src"]
	game.world.add_child(b)


func point_at(angle: float, r: float = RADIUS) -> Vector2:
	return global_position + Vector2.from_angle(angle) * r


## 位置 p（半径 r）が壁に触れていれば壁の番号を返す。触れていなければ -1
func hit_test(p: Vector2, r: float) -> int:
	if walls.is_empty():
		return -1
	var rel := p - global_position
	var d := rel.length()
	if absf(d - RADIUS) > THICKNESS / 2.0 + r:
		return -1
	var a := rel.angle()
	if a < 0.0:
		a += TAU
	var da := r / RADIUS
	for i in walls.size():
		if a >= walls[i]["a0"] - da and a <= walls[i]["a1"] + da:
			return i
	return -1


## 壁 i で攻撃を1発防ぐ（ダメージの大きさに関係なく1回分）。pos = 防いだ場所
func absorb(i: int, pos: Vector2 = Vector2.INF) -> void:
	var w: Dictionary = walls[i]
	if explode_on_block and pos != Vector2.INF:
		game.explode(pos, 75.0, 40.0 * (1.0 + game.elapsed / 180.0), w["src"], Color(0.9, 0.75, 0.5))
	w["hp"] -= 1.0
	w["flash"] = 0.15
	if not w["src"].is_empty():
		w["src"]["wall_blocks"] += 1
	if w["hp"] <= 0.0:
		var mid: float = (w["a0"] + w["a1"]) / 2.0
		game.spawn_burst(point_at(mid), Color(0.7, 0.65, 0.55), 20.0)
		walls.remove_at(i)


## src = 建てた築城兵の戦績カード（防いだ回数を記録する）
func add_wall(seg: Vector2, src: Dictionary = {}) -> void:
	walls.append({"a0": seg.x, "a1": seg.y, "hp": wall_max_hp, "max": wall_max_hp, "flash": 0.0, "src": src})


## 耐久回数アップ（建っている壁にも反映）
func add_wall_hp(amount: float) -> void:
	wall_max_hp += amount
	for w in walls:
		w["max"] += amount
		w["hp"] += amount


## 次に壁を建てる場所（Vector2(開始角, 終了角)）を返す。全部埋まっていれば null。
## reserved = ほかの築城部隊が建設中の場所。上（敵が多く来る方向）から順に埋めていく。
func find_build_spot(reserved: Array) -> Variant:
	var segs: Array = []
	for w in walls:
		segs.append(Vector2(w["a0"], w["a1"]))
	segs.append_array(reserved)
	segs.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
	var gaps: Array = []
	var cur := ARC_START
	for s in segs:
		if s.x > cur + 0.01:
			gaps.append(Vector2(cur, s.x))
		cur = maxf(cur, s.y)
	if cur < ARC_END - 0.01:
		gaps.append(Vector2(cur, ARC_END))
	if gaps.is_empty():
		return null
	# 真上に一番近いすき間を選ぶ
	var best: Vector2 = gaps[0]
	var best_d := INF
	for g in gaps:
		var dist := 0.0 if (TOP >= g.x and TOP <= g.y) else minf(absf(TOP - g.x), absf(TOP - g.y))
		if dist < best_d:
			best_d = dist
			best = g
	var w := wall_width
	var center: float
	if best.y - best.x <= w:
		center = (best.x + best.y) / 2.0
	else:
		center = clampf(TOP, best.x + w / 2.0, best.y - w / 2.0)
	var a0 := center - w / 2.0
	var a1 := center + w / 2.0
	# 半円の端からはみ出さないように
	if a0 < ARC_START:
		a1 += ARC_START - a0
		a0 = ARC_START
	if a1 > ARC_END:
		a0 -= a1 - ARC_END
		a1 = ARC_END
	return Vector2(a0, a1)


func _draw() -> void:
	# 築城部隊がいれば、壁を建てる予定の線をうっすら表示
	if not game.builders.is_empty():
		draw_arc(Vector2.ZERO, RADIUS, ARC_START, ARC_END, 64, Color(0.8, 0.75, 0.6, 0.12), THICKNESS)
	# 建設中の壁
	for b in game.builders:
		if b.state == "building":
			draw_arc(Vector2.ZERO, RADIUS, b.plan.x, b.plan.y, 12, Color(0.8, 0.75, 0.6, 0.3), THICKNESS)
			var a_end: float = lerpf(b.plan.x, b.plan.y, b.progress)
			draw_arc(Vector2.ZERO, RADIUS, b.plan.x, a_end, 12, Color(0.75, 0.68, 0.55, 0.8), THICKNESS * 0.5)
	# 建っている壁
	for w in walls:
		var ratio: float = w["hp"] / w["max"]
		var col := Color(0.42, 0.38, 0.34).lerp(Color(0.72, 0.68, 0.6), ratio)
		if w["flash"] > 0.0:
			col = Color(1, 0.9, 0.8)
		var steps := maxi(4, int((w["a1"] - w["a0"]) / 0.03))
		draw_arc(Vector2.ZERO, RADIUS, w["a0"], w["a1"], steps, Color(0.25, 0.22, 0.2), THICKNESS + 4.0)
		draw_arc(Vector2.ZERO, RADIUS, w["a0"] + 0.004, w["a1"] - 0.004, steps, col, THICKNESS)
		# 残り回数
		var font := ThemeDB.fallback_font
		var label_pos := Vector2.from_angle((w["a0"] + w["a1"]) / 2.0) * (RADIUS + THICKNESS + 8.0)
		draw_string_outline(font, label_pos + Vector2(-15, 5), str(int(w["hp"])), HORIZONTAL_ALIGNMENT_CENTER, 30, 13, 3, Color(0, 0, 0, 0.8))
		draw_string(font, label_pos + Vector2(-15, 5), str(int(w["hp"])), HORIZONTAL_ALIGNMENT_CENTER, 30, 13, Color(1.0, 0.9, 0.6))
		# 耐久の目盛り
		draw_arc(Vector2.ZERO, RADIUS + THICKNESS / 2.0 + 3.0, w["a0"], lerpf(w["a0"], w["a1"], ratio), steps, Color(1.0, 0.85, 0.4, 0.8), 2.0)
