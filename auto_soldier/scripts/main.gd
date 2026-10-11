extends Node2D
## ゲーム全体の管理：フィールド、城、兵士、敵の出現、経験値・レベルアップ、UI

const SoldierScript := preload("res://scripts/soldier.gd")
const SoldierStats := preload("res://scripts/soldier_stats.gd")
const GuardScript := preload("res://scripts/guard.gd")
const GuardStats := preload("res://scripts/guard_stats.gd")
const BuilderScript := preload("res://scripts/builder.gd")
const HeavyScript := preload("res://scripts/heavy.gd")
const EngineerScript := preload("res://scripts/engineer.gd")
const EngineerStats := preload("res://scripts/engineer_stats.gd")
const WallsScript := preload("res://scripts/walls.gd")
const CastleScript := preload("res://scripts/castle.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const PetScript := preload("res://scripts/pet.gd")
const HudScript := preload("res://scripts/hud.gd")
const LevelUpScript := preload("res://scripts/level_up_ui.gd")
const DamageTextScript := preload("res://scripts/damage_text.gd")
const BurstScript := preload("res://scripts/burst_effect.gd")
const Upgrades := preload("res://scripts/upgrades.gd")
const StatsScript := preload("res://scripts/stats_ui.gd")
const HazardScript := preload("res://scripts/hazard.gd")
const BlastScript := preload("res://scripts/blast.gd")
## このレベルごとに特別強化の3択が出る
const SPECIAL_EVERY := 7

## フィールドの範囲。城は一番下の中央に置く
const MAP_RECT := Rect2(-700, -780, 1400, 840)
const MAX_ENEMIES := 260
const MAX_SOLDIERS := 5
const MAX_GUARDS := 3
const MAX_BUILDERS := 3
const MAX_ENGINEERS := 2
## 遊撃兵1人あたりのペットの最大数
const MAX_PETS := 4
## 近くの敵を素早く探すための空間グリッドのマス目サイズ
const GRID_CELL := 64.0

var world: Node2D
var effects: Node2D
var camera: Camera2D
var castle: Node2D
var walls: Node2D
## 罠などを置く地面のレイヤー（兵士や敵より下に描く）
var ground: Node2D
var hud: CanvasLayer
var level_up_ui: CanvasLayer
var stats_ui: CanvasLayer
## 部隊戦績（個体ごとの与ダメージ・被ダメージなど）。new_record() で追加する
var records: Array = []

## 兵士全員で共有するステータス（強化はここに入る）
var stats := SoldierStats.new()
var soldiers: Array = []
## 迎撃部隊（盾＋槍）
var guard_stats := GuardStats.new()
var guards: Array = []
## 築城部隊
var builders: Array = []
## 重装部隊（最大1体）
var heavy: Node2D = null
## 工兵部隊
var engineers: Array = []
var engineer_stats := EngineerStats.new()
var pets: Array = []
## 遊撃兵1人あたりのペットの数（「ペットの仲間」を取るたびに+1）
var pets_per_soldier := 0
## ペットの攻撃力（あとから付くペットにも反映）
var pet_damage := 7.0
## 毎フレーム更新する敵リスト（各スクリプトから参照）
var enemies_cache: Array = []
var _grid := {}

var level := 1
var xp := 0
var xp_to_next := xp_needed(1)
var kills := 0
var elapsed := 0.0
var upgrade_levels := {}
var pending_levelups := 0
## まだ強化を選んでいないレベル（特別強化のレベルかどうかの判定に使う）
var _pending_levels: Array = []
var game_over := false

var _spawn_acc := 0.0
var _next_wave := 50.0
## 出現中のボス（いなければ null）
var boss: Node2D = null
var bosses_spawned := 0
## このレベルごとにボスが出る
const BOSS_EVERY := 10


func _ready() -> void:
	randomize()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	effects = Node2D.new()
	effects.name = "Effects"
	effects.z_index = 10
	add_child(effects)

	castle = CastleScript.new()
	castle.game = self
	castle.position = Vector2(MAP_RECT.get_center().x, MAP_RECT.end.y - 70.0)
	world.add_child(castle)

	walls = WallsScript.new()
	walls.game = self
	walls.position = castle.position
	world.add_child(walls)

	ground = Node2D.new()
	ground.name = "Ground"
	world.add_child(ground)

	# 最初は兵士2人でスタート
	add_soldier()
	add_soldier()

	camera = Camera2D.new()
	camera.position = MAP_RECT.get_center()
	add_child(camera)
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)

	hud = HudScript.new()
	hud.game = self
	add_child(hud)

	level_up_ui = LevelUpScript.new()
	add_child(level_up_ui)
	level_up_ui.chosen.connect(_on_upgrade_chosen)

	stats_ui = StatsScript.new()
	stats_ui.game = self
	add_child(stats_ui)

	queue_redraw()


## フィールド全体が画面に収まるようにズームする
func _fit_camera() -> void:
	var vp := get_viewport().get_visible_rect().size
	var need := MAP_RECT.size + Vector2(60, 140)
	var z := minf(vp.x / need.x, vp.y / need.y)
	camera.zoom = Vector2(z, z)
	# HUDのぶん少し上に余白をとる
	camera.position = MAP_RECT.get_center() + Vector2(0, -30)


func _process(delta: float) -> void:
	enemies_cache = get_tree().get_nodes_in_group("enemies")
	_rebuild_grid()
	if game_over:
		return
	elapsed += delta
	_update_spawning(delta)
	hud.refresh()


# ---------------------------------------------------------------- フィールド

func _draw() -> void:
	draw_rect(MAP_RECT.grow(3000), Color(0.05, 0.06, 0.05))
	draw_rect(MAP_RECT, Color(0.16, 0.24, 0.15))
	var grid_col := Color(1, 1, 1, 0.05)
	var x := MAP_RECT.position.x
	while x <= MAP_RECT.end.x:
		draw_line(Vector2(x, MAP_RECT.position.y), Vector2(x, MAP_RECT.end.y), grid_col, 1.0)
		x += 100.0
	var y := MAP_RECT.position.y
	while y <= MAP_RECT.end.y:
		draw_line(Vector2(MAP_RECT.position.x, y), Vector2(MAP_RECT.end.x, y), grid_col, 1.0)
		y += 100.0
	# 草っぽい模様
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 220:
		var p := Vector2(rng.randf_range(MAP_RECT.position.x, MAP_RECT.end.x), rng.randf_range(MAP_RECT.position.y, MAP_RECT.end.y))
		draw_circle(p, rng.randf_range(3.0, 9.0), Color(0.2, 0.32, 0.18, 0.6))
	# 城へ続く道
	var road_top := Vector2(0, MAP_RECT.position.y)
	draw_line(road_top, Vector2(0, MAP_RECT.end.y), Color(0.42, 0.36, 0.25, 0.35), 70.0)
	draw_rect(MAP_RECT, Color(0.55, 0.45, 0.3), false, 6.0)


func clamp_to_map(p: Vector2, r: float) -> Vector2:
	return Vector2(
		clampf(p.x, MAP_RECT.position.x + r, MAP_RECT.end.x - r),
		clampf(p.y, MAP_RECT.position.y + r, MAP_RECT.end.y - r))


# ---------------------------------------------------------------- 空間グリッド

func _rebuild_grid() -> void:
	_grid.clear()
	for e in enemies_cache:
		var key := Vector2i(floori(e.position.x / GRID_CELL), floori(e.position.y / GRID_CELL))
		if _grid.has(key):
			_grid[key].append(e)
		else:
			_grid[key] = [e]


## pos から距離 r 以内にいる「かもしれない」敵を返す（厳密な距離判定は呼び出し側で）
func enemies_near(pos: Vector2, r: float) -> Array:
	var result: Array = []
	var x0 := floori((pos.x - r) / GRID_CELL)
	var x1 := floori((pos.x + r) / GRID_CELL)
	var y0 := floori((pos.y - r) / GRID_CELL)
	var y1 := floori((pos.y + r) / GRID_CELL)
	for gx in range(x0, x1 + 1):
		for gy in range(y0, y1 + 1):
			var key := Vector2i(gx, gy)
			if _grid.has(key):
				result.append_array(_grid[key])
	return result


func nearest_enemy(pos: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for e in enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = pos.distance_to(e.global_position) - e.radius
		if d < best_d:
			best_d = d
			best = e
	return best


## 敵に狙われる味方（遊撃部隊＋迎撃部隊＋重装部隊）。築城部隊は狙われない
func allies() -> Array:
	var list: Array = soldiers + guards
	if heavy != null:
		list.append(heavy)
	return list


## 生きている味方のうち pos に一番近いもの
func nearest_ally(pos: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for s in allies():
		if s.dead:
			continue
		var d: float = pos.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


# ---------------------------------------------------------------- 部隊戦績

## 戦績カードを1枚作る。弾や罠にこのカードを持たせて、与えたダメージを記録する
func new_record(cat: String, name_text: String) -> Dictionary:
	var r := {"cat": cat, "name": name_text, "dealt": 0.0, "taken": 0.0, "kills": 0,
		"blocked": 0.0, "walls": 0, "wall_blocks": 0, "traps": 0}
	records.append(r)
	return r


func toggle_stats() -> void:
	if level_up_ui.visible:
		return
	stats_ui.toggle()


# ---------------------------------------------------------------- 兵士・ペット

func add_soldier() -> void:
	if soldiers.size() >= MAX_SOLDIERS:
		return
	var s := SoldierScript.new()
	s.game = self
	s.index = soldiers.size()
	s.position = castle.gate_position() + Vector2(randf_range(-40, 40), -20)
	world.add_child(s)
	soldiers.append(s)
	# 新しく増えた遊撃兵にもペットを付ける
	_fill_pets()


func add_guard() -> void:
	if guards.size() >= MAX_GUARDS:
		return
	var g := GuardScript.new()
	g.game = self
	g.index = guards.size()
	g.position = castle.gate_position()
	world.add_child(g)
	guards.append(g)


func add_heavy() -> void:
	if heavy != null:
		return
	heavy = HeavyScript.new()
	heavy.game = self
	heavy.position = castle.gate_position()
	world.add_child(heavy)


func add_engineer() -> void:
	if engineers.size() >= MAX_ENGINEERS:
		return
	var e := EngineerScript.new()
	e.game = self
	e.index = engineers.size()
	e.position = castle.gate_position()
	world.add_child(e)
	engineers.append(e)


func add_builder() -> void:
	if builders.size() >= MAX_BUILDERS:
		return
	var b := BuilderScript.new()
	b.game = self
	b.index = builders.size()
	b.position = castle.gate_position()
	world.add_child(b)
	builders.append(b)


## 全遊撃兵にペットを1匹ずつ追加する
func add_pet() -> void:
	if pets_per_soldier >= MAX_PETS:
		return
	pets_per_soldier += 1
	_fill_pets()


## 各遊撃兵のペットが pets_per_soldier 匹になるように足りない分を付ける
func _fill_pets() -> void:
	for s in soldiers:
		var have := 0
		for p in pets:
			if p.owner_soldier == s:
				have += 1
		while have < pets_per_soldier:
			var p := PetScript.new()
			p.game = self
			p.owner_soldier = s
			p.index = have
			p.damage = pet_damage
			p.position = s.position
			world.add_child(p)
			pets.append(p)
			have += 1


# ---------------------------------------------------------------- 敵の出現

func _update_spawning(delta: float) -> void:
	# 時間とともに出現ペースが上がる
	var rate := minf(0.8 + elapsed * 0.018, 11.0)
	_spawn_acc += rate * delta
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if enemies_cache.size() < MAX_ENEMIES:
			_spawn_enemy(_pick_kind(), _random_spawn_pos())
	# 定期的に横一列の大群
	if elapsed >= _next_wave:
		_next_wave += 50.0
		var count := 8 + int(elapsed / 25.0)
		for i in count:
			var px := lerpf(MAP_RECT.position.x + 60.0, MAP_RECT.end.x - 60.0, (i + 0.5) / count)
			_spawn_enemy("grunt", Vector2(px, MAP_RECT.position.y + 20.0 + randf() * 40.0))


func _pick_kind() -> String:
	var pool := [["grunt", 10.0]]
	if elapsed > 25.0:
		pool.append(["archer", 2.0 + elapsed / 90.0])
	if elapsed > 45.0:
		pool.append(["runner", 4.0])
	if elapsed > 80.0:
		pool.append(["brute", 1.0 + elapsed / 120.0])
	if elapsed > 75.0:
		pool.append(["hunter", 1.0 + elapsed / 200.0])
	if elapsed > 60.0:
		pool.append(["splitter", 2.0])
	if elapsed > 100.0:
		pool.append(["healer", 1.2])
	if elapsed > 120.0:
		pool.append(["bomber", 1.0 + elapsed / 240.0])
	var total := 0.0
	for entry in pool:
		total += entry[1]
	var r := randf() * total
	for entry in pool:
		r -= entry[1]
		if r <= 0.0:
			return entry[0]
	return "grunt"


## 上端か、左右の上半分から出てくる
func _random_spawn_pos() -> Vector2:
	var m := 20.0
	var side := randf()
	if side < 0.6:
		return Vector2(randf_range(MAP_RECT.position.x + m, MAP_RECT.end.x - m), MAP_RECT.position.y + m)
	var y := randf_range(MAP_RECT.position.y + m, MAP_RECT.get_center().y)
	if side < 0.8:
		return Vector2(MAP_RECT.position.x + m, y)
	return Vector2(MAP_RECT.end.x - m, y)


func _hp_mult() -> float:
	return 1.0 + elapsed / 75.0 + pow(elapsed / 170.0, 2.0)


func _spawn_enemy(kind: String, pos: Vector2) -> void:
	spawn_enemy_at(kind, pos)


## 指定した場所に敵を出す（hp_mult を省略すると今の時間に合わせた強さ）
func spawn_enemy_at(kind: String, pos: Vector2, hp_mult: float = -1.0) -> Node2D:
	var e := EnemyScript.new()
	e.game = self
	e.setup(kind, hp_mult if hp_mult > 0.0 else _hp_mult())
	e.position = clamp_to_map(pos, 20.0)
	world.add_child(e)
	return e


## ボス出現（Lv10ごと）
func _spawn_boss() -> void:
	bosses_spawned += 1
	var e := EnemyScript.new()
	e.game = self
	e.boss_rank = bosses_spawned
	e.setup("boss", _hp_mult())
	e.position = Vector2(MAP_RECT.get_center().x, MAP_RECT.position.y + 60.0)
	world.add_child(e)
	boss = e
	hud.show_banner("⚠ BOSS 出現！ ⚠", Color(1.0, 0.4, 0.5))


# ---------------------------------------------------------------- 経験値・レベルアップ

func on_enemy_killed(e: Node2D) -> void:
	kills += 1
	if e == boss:
		boss = null
		hud.show_banner("BOSS 撃破！", Color(1.0, 0.85, 0.3))
		spawn_burst(e.global_position, Color(1.0, 0.85, 0.3), 60.0)
	spawn_burst(e.global_position, e.color, e.radius)
	add_xp(e.xp_value)


## レベル lv から次のレベルまでに必要な経験値
## （元の式を 1.44 = 1.2×1.2 で割って、レベルの上がりやすさを元の約1.44倍にしている）
func xp_needed(lv: int) -> int:
	return maxi(1, roundi((4.0 + lv * 3.0 + lv * lv / 8.0) / 1.44))


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = xp_needed(level)
		pending_levelups += 1
		_pending_levels.append(level)
		if level % BOSS_EVERY == 0:
			_spawn_boss()
	if pending_levelups > 0 and not level_up_ui.visible and not game_over:
		_open_level_up()


func _open_level_up() -> void:
	var for_level: int = _pending_levels[0] if not _pending_levels.is_empty() else level
	var special := false
	var choices: Array = []
	# Lv7ごとに特別強化（候補がなければ通常の強化）
	if for_level % SPECIAL_EVERY == 0:
		choices = Upgrades.roll_special(upgrade_levels, 3)
		special = not choices.is_empty()
	if choices.is_empty():
		choices = Upgrades.roll(upgrade_levels, 3, self)
	if choices.is_empty():
		# 全部取りきったら城を回復
		pending_levelups = 0
		_pending_levels.clear()
		castle.hp = castle.max_hp
		return
	hud.refresh()
	get_tree().paused = true
	level_up_ui.show_choices(choices, upgrade_levels, for_level, special)


func _on_upgrade_chosen(id: String) -> void:
	var lv: int = upgrade_levels.get(id, 0) + 1
	upgrade_levels[id] = lv
	Upgrades.apply(id, lv, self)
	pending_levelups -= 1
	if not _pending_levels.is_empty():
		_pending_levels.pop_front()
	level_up_ui.hide()
	if pending_levelups > 0:
		_open_level_up()
	else:
		get_tree().paused = false


# ---------------------------------------------------------------- 演出

func spawn_damage_text(pos: Vector2, amount: float, col: Color) -> void:
	if effects.get_child_count() > 150:
		return
	var t := DamageTextScript.new()
	t.text = str(int(round(amount)))
	t.color = col
	t.position = pos + Vector2(randf_range(-8, 8), -10)
	effects.add_child(t)


func spawn_burst(pos: Vector2, col: Color, r: float) -> void:
	if effects.get_child_count() > 260:
		return
	var b := BurstScript.new()
	b.color = col
	b.max_radius = r * 2.2
	b.position = pos
	effects.add_child(b)


## 範囲爆発。範囲内の敵にダメージ（stun > 0 なら気絶も）
func explode(pos: Vector2, radius: float, dmg: float, src: Dictionary, col: Color, stun: float = 0.0, knock: float = 220.0) -> void:
	for e in enemies_near(pos, radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - pos
		if rel.length() > radius + e.radius:
			continue
		if stun > 0.0:
			e.stun(stun)
		e.take_damage(dmg, rel.normalized() * knock, src)
	spawn_burst(pos, col, radius / 2.2)


## 一定時間残るダメージ地帯（炎・毒沼など）
func spawn_hazard(pos: Vector2, radius: float, dps: float, duration: float, col: Color, src: Dictionary) -> void:
	var h := HazardScript.new()
	h.game = self
	h.radius = radius
	h.dps = dps
	h.duration = duration
	h.color = col
	h.src = src
	h.position = pos
	ground.add_child(h)


## 少し遅れて起きる爆発（look: "bomb" / "rock" / "ice"）
func spawn_blast(pos: Vector2, delay: float, radius: float, dmg: float, src: Dictionary, col: Color, look: String = "bomb", stun: float = 0.0) -> void:
	var b := BlastScript.new()
	b.game = self
	b.delay = delay
	b.radius = radius
	b.damage = dmg
	b.src = src
	b.color = col
	b.look = look
	b.stun = stun
	b.position = clamp_to_map(pos, 10.0)
	effects.add_child(b)


# ---------------------------------------------------------------- ゲームオーバー

func on_castle_destroyed() -> void:
	if game_over:
		return
	game_over = true
	level_up_ui.hide()
	stats_ui.close_panel()
	get_tree().paused = true
	hud.show_game_over()


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
