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
const UpgradesUIScript := preload("res://scripts/upgrades_ui.gd")
const HazardScript := preload("res://scripts/hazard.gd")
const BlastScript := preload("res://scripts/blast.gd")
const MissileScript := preload("res://scripts/missile.gd")
const PlacedScript := preload("res://scripts/placed.gd")
const LightningScript := preload("res://scripts/lightning.gd")
const SniperScript := preload("res://scripts/sniper.gd")
const SniperStats := preload("res://scripts/sniper_stats.gd")
const UltimatesScript := preload("res://scripts/ultimates.gd")
const KnightScript := preload("res://scripts/knight.gd")
const KnightStats := preload("res://scripts/knight_stats.gd")
const RepairerScript := preload("res://scripts/repairer.gd")
const RepairStats := preload("res://scripts/repair_stats.gd")
const FunSpecialsScript := preload("res://scripts/fun_specials.gd")
const FunFxScript := preload("res://scripts/fun_fx.gd")
const SummaryScript := preload("res://scripts/summary_ui.gd")
## このレベルごとに特別強化の3択が出る
const SPECIAL_EVERY := 5

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
var upgrades_ui: CanvasLayer
## ゲームオーバー時の戦績まとめ画面
var summary_ui: CanvasLayer
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
## 狙撃部隊（弓）
var snipers: Array = []
var sniper_stats := SniperStats.new()
const MAX_SNIPERS := 3
## 15秒ごとの必殺技（6つ目の特別強化）をまとめて管理する
var ultimates: Node2D
## おもしろ特別強化のうち、一定時間ごとに出るものを管理する
var fun: Node2D
## 近衛部隊（突進する騎士）
var knights: Array = []
var knight_stats := KnightStats.new()
const MAX_KNIGHTS := 3
## 修理部隊（城のHPを回復）
var repairers: Array = []
var repair_stats := RepairStats.new()
const MAX_REPAIRERS := 3
var pets: Array = []
## 遊撃兵1人あたりのペットの数（「ペットの仲間」を取るたびに+1）
var pets_per_soldier := 0
## ペットの攻撃力（あとから付くペットにも反映）
var pet_damage := 4.2
## ペットの射撃間隔・射程（全ペット共通）
var pet_interval := 0.8
var pet_range := 420.0
## ペットが一度に撃つ弾の数
var pet_shots := 1
## ペットの特別強化：爆裂ペット弾・巨大ペット・追尾ペット弾・凍える羽根・癒しのさえずり
var pet_burst := false
var pet_giant := false
var pet_homing := false
var pet_frost := false
var pet_heal := false
## 体当たりペット：ペットに触れた敵にペットの3倍ダメージ
var pet_body := false
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
## オート選択モード：レベルアップの強化をランダムで自動的に選ぶ
var auto_pick := false
## 今出ている強化の候補（リロール用）
var _shown_choices: Array = []
var _shown_special := false
var _shown_level := 1

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

	ultimates = UltimatesScript.new()
	ultimates.game = self
	effects.add_child(ultimates)

	fun = FunSpecialsScript.new()
	fun.game = self
	effects.add_child(fun)

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
	level_up_ui.reroll_requested.connect(_on_reroll)

	stats_ui = StatsScript.new()
	stats_ui.game = self
	add_child(stats_ui)

	upgrades_ui = UpgradesUIScript.new()
	upgrades_ui.game = self
	add_child(upgrades_ui)

	summary_ui = SummaryScript.new()
	summary_ui.game = self
	add_child(summary_ui)

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
	var list: Array = soldiers + guards + knights
	if heavy != null:
		list.append(heavy)
	# 見張り櫓・かかしなど、耐久のある設置物も敵に狙われる
	for p in get_tree().get_nodes_in_group("attackable"):
		if not p.dead:
			list.append(p)
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


func set_auto_pick(on: bool) -> void:
	auto_pick = on
	hud.update_auto_button()
	# 選択画面が出ている最中に有効にしたら、その場で自動選択
	if on and level_up_ui.visible and not level_up_ui._ids.is_empty():
		var ids: Array = level_up_ui._ids
		level_up_ui._pick(ids[randi() % ids.size()])


func toggle_stats() -> void:
	if level_up_ui.visible or upgrades_ui.visible:
		return
	stats_ui.toggle()


func toggle_upgrades() -> void:
	if level_up_ui.visible or stats_ui.visible:
		return
	upgrades_ui.toggle()


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


func add_sniper() -> void:
	if snipers.size() >= MAX_SNIPERS:
		return
	var s := SniperScript.new()
	s.game = self
	s.index = snipers.size()
	s.position = castle.gate_position()
	world.add_child(s)
	snipers.append(s)


func add_knight() -> void:
	if knights.size() >= MAX_KNIGHTS:
		return
	var k := KnightScript.new()
	k.game = self
	k.index = knights.size()
	k.position = castle.gate_position()
	world.add_child(k)
	knights.append(k)


func add_repairer() -> void:
	if repairers.size() >= MAX_REPAIRERS:
		return
	var r := RepairerScript.new()
	r.game = self
	r.index = repairers.size()
	r.position = castle.gate_position()
	world.add_child(r)
	repairers.append(r)


## 通常速度 ⇔ 2倍速 の切り替え
func toggle_speed() -> void:
	Engine.time_scale = 1.0 if Engine.time_scale > 1.0 else 2.0
	hud.update_speed_button()


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
			var k := _pick_kind()
			var pos := _random_spawn_pos()
			if k == "stealth":
				pos = _stealth_spawn_pos()
			elif k == "mortar" or k == "seeker":
				pos = _mortar_spawn_pos()
			_spawn_enemy(k, pos)
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
	if elapsed > 90.0:
		pool.append(["stealth", 1.5 + elapsed / 200.0])
	# 迫撃砲は同時に出すぎないように上限つき
	if elapsed > 180.0 and _count_kind("mortar") < 2 + int(elapsed / 300.0):
		pool.append(["mortar", 0.6 + elapsed / 400.0])
	if elapsed > 150.0:
		pool.append(["ringer", 0.8 + elapsed / 300.0])
	# 誘導砲兵も同時に出すぎないように上限つき
	if elapsed > 200.0 and _count_kind("seeker") < 2 + int(elapsed / 300.0):
		pool.append(["seeker", 0.5 + elapsed / 400.0])
	var total := 0.0
	for entry in pool:
		total += entry[1]
	var r := randf() * total
	for entry in pool:
		r -= entry[1]
		if r <= 0.0:
			return entry[0]
	return "grunt"


func _count_kind(k: String) -> int:
	var n := 0
	for e in enemies_cache:
		if is_instance_valid(e) and not e.dead and e.kind == k:
			n += 1
	return n


## 迫撃砲：マップの上端か左右の端（城より上の方）に陣取る
func _mortar_spawn_pos() -> Vector2:
	var m := 30.0
	if randf() < 0.5:
		return Vector2(randf_range(MAP_RECT.position.x + m, MAP_RECT.end.x - m), MAP_RECT.position.y + m)
	var x := MAP_RECT.position.x + m if randf() < 0.5 else MAP_RECT.end.x - m
	return Vector2(x, randf_range(MAP_RECT.position.y + m, MAP_RECT.end.y - 260.0))


## 隠密兵：右下か左下の隅から出てくる
func _stealth_spawn_pos() -> Vector2:
	var x := MAP_RECT.position.x + 25.0 if randf() < 0.5 else MAP_RECT.end.x - 25.0
	return Vector2(x, MAP_RECT.end.y - randf_range(25.0, 120.0))


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


## 迫撃砲部隊：マップの端に迫撃砲が8体一気に現れる
func _spawn_mortar_squad() -> void:
	for i in 8:
		spawn_enemy_at("mortar", _mortar_spawn_pos())
	hud.show_banner("⚠ 迫撃砲部隊 襲来！ ⚠", Color(1.0, 0.6, 0.3))


## ボス出現（Lv10ごと）。破城の魔王 → 砲台要塞 → 分裂の魔獣 の順に来る
func _spawn_boss() -> void:
	bosses_spawned += 1
	var e := EnemyScript.new()
	e.game = self
	e.boss_rank = bosses_spawned
	var kind: String = ["boss3", "boss", "boss2"][bosses_spawned % 3]
	e.setup(kind, _hp_mult())
	e.position = Vector2(MAP_RECT.get_center().x, MAP_RECT.position.y + (110.0 if kind == "boss2" else 60.0))
	world.add_child(e)
	boss = e
	hud.show_banner("⚠ BOSS「%s」出現！ ⚠" % e.boss_title, Color(1.0, 0.4, 0.5))


# ---------------------------------------------------------------- 経験値・レベルアップ

func on_enemy_killed(e: Node2D) -> void:
	kills += 1
	if e == boss:
		boss = null
		# 分裂の魔獣は、分かれた体が全部いなくなるまで撃破にならない
		if e.kind == "boss3":
			boss = _alive_split_piece()
		if boss == null:
			hud.show_banner("BOSS 撃破！", Color(1.0, 0.85, 0.3))
		spawn_burst(e.global_position, Color(1.0, 0.85, 0.3), 60.0)
	spawn_burst(e.global_position, e.color, e.radius)
	add_xp(e.xp_value)


## まだ生きている分裂の魔獣の体（いなければ null）
func _alive_split_piece() -> Node2D:
	for x in get_tree().get_nodes_in_group("enemies"):
		if x.kind == "boss3" and not x.dead:
			return x
	return null


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
		# Lv5・15・25…で迫撃砲部隊（8体）が襲来
		if level % 10 == 5:
			_spawn_mortar_squad()
	if pending_levelups > 0 and not level_up_ui.visible and not game_over:
		_open_level_up()


func _open_level_up() -> void:
	var for_level: int = _pending_levels[0] if not _pending_levels.is_empty() else level
	var special := false
	var choices: Array = []
	# Lv5ごとに特別強化（候補がなければ通常の強化）
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
	if auto_pick:
		# オート選択：画面を止めずにランダムで選ぶ
		var u: Dictionary = choices[randi() % choices.size()]
		hud.show_notice("オート選択：【%s】%s%s" % [Upgrades.CAT_LABEL[u["cat"]], "★" if u.get("special", false) else "", u["name"]])
		_on_upgrade_chosen(u["id"])
		return
	hud.refresh()
	get_tree().paused = true
	_shown_choices = choices
	_shown_special = special
	_shown_level = for_level
	level_up_ui.show_choices(choices, upgrade_levels, for_level, special)


## リロール：今出ている候補とはなるべく別のものを3つ引き直す（1画面1回まで）
func _on_reroll() -> void:
	var pool: Array
	if _shown_special:
		pool = Upgrades.roll_special(upgrade_levels, 999)
	else:
		pool = Upgrades.roll(upgrade_levels, 999, self)
	var old_ids: Array = _shown_choices.map(func(u: Dictionary) -> String: return u["id"])
	var fresh: Array = pool.filter(func(u: Dictionary) -> bool: return not u["id"] in old_ids)
	var choices: Array = fresh.slice(0, 3)
	# 新しい候補が3つに足りなければ、前の候補から埋める
	for u in pool:
		if choices.size() >= 3:
			break
		if not choices.has(u):
			choices.append(u)
	_shown_choices = choices
	level_up_ui.show_choices(choices, upgrade_levels, _shown_level, _shown_special, true)


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


## 浮かび上がる文字（今は使っていない。必要になったら使える）
func spawn_text(pos: Vector2, text: String, col: Color, size: int = 18) -> void:
	if effects.get_child_count() > 150:
		return
	var t := DamageTextScript.new()
	t.text = text
	t.color = col
	t.font_size = size
	t.duration = 1.1
	t.position = pos
	effects.add_child(t)


## おもしろ特別強化の見た目（kind: "firework" / "jack" / "kusudama" / "roar"）
func spawn_fun_fx(kind: String, pos: Vector2) -> Node2D:
	var f := FunFxScript.new()
	f.game = self
	f.kind = kind
	f.position = pos
	f.start = pos
	f.end = pos
	effects.add_child(f)
	return f


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


## 特別強化で飛ぶ物（kind: "boomerang" / "ball" / "homing"）
func spawn_missile(kind: String, pos: Vector2, velocity: Vector2, dmg: float, radius: float, life: float, src: Dictionary) -> Node2D:
	var m := MissileScript.new()
	m.game = self
	m.kind = kind
	m.velocity = velocity
	m.damage = dmg
	m.radius = radius
	m.life = life
	m.src = src
	m.position = pos
	world.add_child(m)
	return m


## 特別強化で置かれる物（kind: "spikes" / "watchtower" / "sentry" / "mine" / "snowman"）。life <= 0 ならずっと残る
func spawn_placed(kind: String, pos: Vector2, dmg: float, radius: float, life: float, src: Dictionary) -> Node2D:
	var p := PlacedScript.new()
	p.game = self
	p.kind = kind
	p.damage = dmg
	p.radius = radius
	p.life = life
	p.src = src
	p.position = clamp_to_map(pos, 20.0)
	ground.add_child(p)
	return p


## 連鎖する雷：first から近くの敵へ次々に飛び移ってダメージ
func chain_lightning(from: Vector2, first: Node2D, jumps: int, dmg: float, jump_range: float, src: Dictionary) -> void:
	var pts := PackedVector2Array([from])
	var hit := {}
	var cur: Node2D = first
	for i in jumps:
		if cur == null:
			break
		hit[cur] = true
		var p: Vector2 = cur.global_position
		pts.append(p)
		cur.take_damage(dmg, Vector2.ZERO, src)
		cur.stun(0.3)
		var next: Node2D = null
		var best := jump_range
		for e in enemies_near(p, jump_range):
			if not is_instance_valid(e) or e.dead or hit.has(e):
				continue
			var d: float = p.distance_to(e.global_position)
			if d < best:
				best = d
				next = e
		cur = next
	var fx := LightningScript.new()
	fx.points = pts
	effects.add_child(fx)


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
	upgrades_ui.close_panel()
	get_tree().paused = true
	hud.show_game_over()


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
