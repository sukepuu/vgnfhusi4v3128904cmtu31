extends Node2D
## ゲーム全体の管理：マップ、敵の出現、経験値・レベルアップ、UI

const SoldierScript := preload("res://scripts/soldier.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const PetScript := preload("res://scripts/pet.gd")
const HudScript := preload("res://scripts/hud.gd")
const LevelUpScript := preload("res://scripts/level_up_ui.gd")
const DamageTextScript := preload("res://scripts/damage_text.gd")
const BurstScript := preload("res://scripts/burst_effect.gd")
const Upgrades := preload("res://scripts/upgrades.gd")

## マップの範囲（原点中心）
const MAP_RECT := Rect2(-1600, -1600, 3200, 3200)
const MAX_ENEMIES := 240
const MAX_PETS := 4
## 近くの敵を素早く探すための空間グリッドのマス目サイズ
const GRID_CELL := 64.0

var soldier: Node2D
var world: Node2D
var effects: Node2D
var hud: CanvasLayer
var level_up_ui: CanvasLayer

## 毎フレーム更新する敵リスト（各スクリプトから参照）
var enemies_cache: Array = []
var pets: Array = []
var _grid := {}

var level := 1
var xp := 0
var xp_to_next := 5
var kills := 0
var elapsed := 0.0
var upgrade_levels := {}
var pending_levelups := 0
var game_over := false

var _spawn_acc := 0.0
var _next_wave := 60.0


func _ready() -> void:
	randomize()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	effects = Node2D.new()
	effects.name = "Effects"
	effects.z_index = 10
	add_child(effects)

	soldier = SoldierScript.new()
	soldier.game = self
	world.add_child(soldier)
	soldier.died.connect(_on_soldier_died)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.limit_left = int(MAP_RECT.position.x) - 200
	cam.limit_top = int(MAP_RECT.position.y) - 200
	cam.limit_right = int(MAP_RECT.end.x) + 200
	cam.limit_bottom = int(MAP_RECT.end.y) + 200
	soldier.add_child(cam)

	hud = HudScript.new()
	hud.game = self
	add_child(hud)

	level_up_ui = LevelUpScript.new()
	add_child(level_up_ui)
	level_up_ui.chosen.connect(_on_upgrade_chosen)

	queue_redraw()


func _process(delta: float) -> void:
	enemies_cache = get_tree().get_nodes_in_group("enemies")
	_rebuild_grid()
	if game_over:
		return
	elapsed += delta
	_update_spawning(delta)
	hud.refresh()


# ---------------------------------------------------------------- マップ

func _draw() -> void:
	var margin := 2000.0
	draw_rect(MAP_RECT.grow(margin), Color(0.05, 0.06, 0.05))
	draw_rect(MAP_RECT, Color(0.16, 0.24, 0.15))
	var step := 100.0
	var grid_col := Color(1, 1, 1, 0.05)
	var x := MAP_RECT.position.x
	while x <= MAP_RECT.end.x:
		draw_line(Vector2(x, MAP_RECT.position.y), Vector2(x, MAP_RECT.end.y), grid_col, 1.0)
		x += step
	var y := MAP_RECT.position.y
	while y <= MAP_RECT.end.y:
		draw_line(Vector2(MAP_RECT.position.x, y), Vector2(MAP_RECT.end.x, y), grid_col, 1.0)
		y += step
	# 草っぽい模様
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 500:
		var p := Vector2(rng.randf_range(MAP_RECT.position.x, MAP_RECT.end.x), rng.randf_range(MAP_RECT.position.y, MAP_RECT.end.y))
		draw_circle(p, rng.randf_range(3.0, 9.0), Color(0.2, 0.32, 0.18, 0.6))
	draw_rect(MAP_RECT, Color(0.55, 0.45, 0.3), false, 8.0)


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
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var key := Vector2i(x, y)
			if _grid.has(key):
				result.append_array(_grid[key])
	return result


# ---------------------------------------------------------------- 敵の出現

func _update_spawning(delta: float) -> void:
	# 時間とともに出現ペースが上がる
	var rate := minf(1.0 + elapsed * 0.025, 8.0)
	_spawn_acc += rate * delta
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if enemies_cache.size() < MAX_ENEMIES:
			_spawn_enemy(_pick_kind(), _random_spawn_pos())
	# 定期的に包囲ウェーブ
	if elapsed >= _next_wave:
		_next_wave += 50.0
		var count := 10 + int(elapsed / 20.0)
		for i in count:
			var ang := TAU * i / count
			var pos := clamp_to_map(soldier.global_position + Vector2.from_angle(ang) * 650.0, 20.0)
			_spawn_enemy("grunt", pos)


func _pick_kind() -> String:
	var pool := [["grunt", 10.0]]
	if elapsed > 20.0:
		pool.append(["archer", 3.0 + elapsed / 60.0])
	if elapsed > 40.0:
		pool.append(["runner", 4.0])
	if elapsed > 80.0:
		pool.append(["brute", 1.0 + elapsed / 120.0])
	var total := 0.0
	for entry in pool:
		total += entry[1]
	var r := randf() * total
	for entry in pool:
		r -= entry[1]
		if r <= 0.0:
			return entry[0]
	return "grunt"


func _random_spawn_pos() -> Vector2:
	var pos := Vector2.ZERO
	for i in 8:
		pos = soldier.global_position + Vector2.from_angle(randf() * TAU) * randf_range(720.0, 900.0)
		pos = clamp_to_map(pos, 20.0)
		if pos.distance_to(soldier.global_position) > 500.0:
			return pos
	return pos


func _spawn_enemy(kind: String, pos: Vector2) -> void:
	var e := EnemyScript.new()
	e.game = self
	e.setup(kind, 1.0 + elapsed / 90.0)
	e.position = pos
	world.add_child(e)


# ---------------------------------------------------------------- 経験値・レベルアップ

func on_enemy_killed(e: Node2D) -> void:
	kills += 1
	spawn_burst(e.global_position, e.color, e.radius)
	add_xp(e.xp_value)


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = 4 + level * 3
		pending_levelups += 1
	if pending_levelups > 0 and not level_up_ui.visible and not game_over:
		_open_level_up()


func _open_level_up() -> void:
	var choices := Upgrades.roll(upgrade_levels, 3)
	if choices.is_empty():
		# 全部取りきったら回復だけ
		pending_levelups = 0
		soldier.hp = soldier.max_hp
		return
	hud.refresh()
	get_tree().paused = true
	level_up_ui.show_choices(choices, upgrade_levels, level)


func _on_upgrade_chosen(id: String) -> void:
	var lv: int = upgrade_levels.get(id, 0) + 1
	upgrade_levels[id] = lv
	Upgrades.apply(id, lv, self)
	pending_levelups -= 1
	level_up_ui.hide()
	if pending_levelups > 0:
		_open_level_up()
	else:
		get_tree().paused = false


func add_pet() -> void:
	if pets.size() >= MAX_PETS:
		return
	var p := PetScript.new()
	p.game = self
	p.index = pets.size()
	p.position = soldier.position
	world.add_child(p)
	pets.append(p)


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
	var b := BurstScript.new()
	b.color = col
	b.max_radius = r * 2.2
	b.position = pos
	effects.add_child(b)


# ---------------------------------------------------------------- ゲームオーバー

func _on_soldier_died() -> void:
	game_over = true
	level_up_ui.hide()
	get_tree().paused = true
	hud.show_game_over()


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
