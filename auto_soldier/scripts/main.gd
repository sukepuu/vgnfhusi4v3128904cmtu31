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
const PetFusionScript := preload("res://scripts/pet_fusion.gd")
const HudScript := preload("res://scripts/hud.gd")
const LevelUpScript := preload("res://scripts/level_up_ui.gd")
const DamageTextScript := preload("res://scripts/damage_text.gd")
const BurstScript := preload("res://scripts/burst_effect.gd")
const Upgrades := preload("res://scripts/upgrades.gd")
const StatsScript := preload("res://scripts/stats_ui.gd")
const UpgradesUIScript := preload("res://scripts/upgrades_ui.gd")
const AutoPickUIScript := preload("res://scripts/auto_pick_ui.gd")
const HazardScript := preload("res://scripts/hazard.gd")
const BlastScript := preload("res://scripts/blast.gd")
const MissileScript := preload("res://scripts/missile.gd")
const PlacedScript := preload("res://scripts/placed.gd")
const LightningScript := preload("res://scripts/lightning.gd")
const SniperScript := preload("res://scripts/sniper.gd")
const SniperStats := preload("res://scripts/sniper_stats.gd")
const ArcherScript := preload("res://scripts/archer.gd")
const ArcherStats := preload("res://scripts/archer_stats.gd")
const ArcherFxScript := preload("res://scripts/archer_fx.gd")
const UltimatesScript := preload("res://scripts/ultimates.gd")
const KnightScript := preload("res://scripts/knight.gd")
const KnightStats := preload("res://scripts/knight_stats.gd")
const RepairerScript := preload("res://scripts/repairer.gd")
const RepairStats := preload("res://scripts/repair_stats.gd")
const FunSpecialsScript := preload("res://scripts/fun_specials.gd")
const FunFxScript := preload("res://scripts/fun_fx.gd")
const SummaryScript := preload("res://scripts/summary_ui.gd")
const RecordsUIScript := preload("res://scripts/records_ui.gd")
const DamageUIScript := preload("res://scripts/damage_ui.gd")
const Records := preload("res://scripts/records.gd")
const DebugUIScript := preload("res://scripts/debug_ui.gd")
const MineSiteScript := preload("res://scripts/mine_site.gd")
const MinerScript := preload("res://scripts/miner.gd")
const AutosaveScript := preload("res://scripts/autosave.gd")
const SaveSlotScript := preload("res://scripts/save_slot.gd")
## このレベルごとに特別強化の3択が出る
const SPECIAL_EVERY := 5
## 黒衣の大司教を倒したときの特別強化の3択は、_pending_levels にこの番号（レベルの代わり）で入れる
const BISHOP_BONUS_LEVEL := 0

## フィールドの範囲。城は一番下の中央に置く
const MAP_RECT := Rect2(-700, -780, 1400, 840)
const MAX_ENEMIES := 300
const MAX_SOLDIERS := 5
const MAX_GUARDS := 3
const MAX_BUILDERS := 3
const MAX_ENGINEERS := 3
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
var auto_pick_ui: CanvasLayer
## ゲームオーバー時の戦績まとめ画面
var summary_ui: CanvasLayer
## 歴代記録の画面
var records_ui: CanvasLayer
## 被害状況確認の画面
var damage_ui: CanvasLayer
var changelog_ui: CanvasLayer
## 今回のゲームオーバーで保存した歴代記録の id（TOP20に入らなかったら ""）
## 今回のゲームオーバーで保存した歴代記録の id（TOP20に入らなかったら ""）
var last_record_id := ""
## このゲーム（1回の出撃）の番号。オートセーブに入るので、「前回のLvからリスタート」しても同じ番号のまま。
## ゲームオーバーのとき、同じ番号の歴代記録があれば新しい結果で上書きする
var run_id := ""
## デバッグ設定から出撃したゲームか（歴代記録に「デバッグ」と出す）
var debug_run := false
var debug_ui: CanvasLayer
## デバッグ設定メニューの「この状態で出撃する」の内容（作り直したあとの _ready で使って空にする）
static var debug_start := {}
## 部隊戦績（個体ごとの与ダメージ・被ダメージなど）。new_record() で追加する
var records: Array = []
## 被害状況：やられた側のキー → {"total": 受けたダメージの合計, "by": {敵の名前: ダメージ}}（note_taken() で記録）
var damage_taken := {}
## 直近30秒の被害状況：1秒ごとの入れ物 [[秒, {受けた側: {敵の名前: ダメージ}}], ...]（古い順。30秒より前のものは捨てる）
var _recent_taken: Array = []
const RECENT_WINDOW := 30
## いまダメージを与えている敵の名前（敵・敵の弾・敵の砲弾が、攻撃する間だけ入れる。空なら「その他」）
var dmg_from := ""
## 今ダメージを与えている敵（弾・砲弾なら撃った敵。わからなければ null）。弓兵の追い討ちで使う
var dmg_attacker: Node2D = null

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
## 仁王立ち（重装の特別強化）：近くの敵が重装兵を狙う。重装兵がいなくても取った状態を覚えておく
var heavy_provoke := false
## 仁王立ちで敵を引きつける距離
const PROVOKE_RANGE := 260.0
## 仁王立ち：PROVOKE_INTERVAL 秒ごとに、まわりの敵を PROVOKE_TIME 秒のあいだ挑発する
const PROVOKE_INTERVAL := 10.0
const PROVOKE_TIME := 5.0
## 工兵部隊
var engineers: Array = []
var engineer_stats := EngineerStats.new()
## 狙撃部隊（弓）
var snipers: Array = []
var sniper_stats := SniperStats.new()
var archers: Array = []
var archer_stats := ArcherStats.new()
const MAX_ARCHERS := 3
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
## 採掘場（城の兵装。右に1つ、第二採掘場で左にも1つ）。待機中の兵士が掘りに行って経験値を稼ぐ
var mine_sites: Array = []
## 採掘兵（採掘場の特別強化。採掘だけをする）
var miners: Array = []
## 採掘場の特別強化：岩のかけら・もぐら・快足の鉱夫・宝石の鉱脈・城の補修石・発破用の爆弾・もぐら爆弾
var mine_shards := false
var mine_mole := false
var mine_fast := false
var mine_gem := false
var mine_heal := false
var mine_bomb := false
var mole_bomb := false
## 快足の鉱夫：採掘場から離れた兵士が、この時刻（elapsed）まで2倍の速さで戻る（兵士のインスタンスID → 時刻）
const MINE_RETURN_TIME := 3.0
var _mine_return_until := {}
## 採掘の間隔（秒）と、1回で獲得する経験値（採掘の効率化・豊かな鉱脈で変わる）
var mine_interval := 10.0
var mine_xp := 1
var pets: Array = []
## 遊撃兵1人あたりのペットの数（「遊撃ペット」を取るたびに+1）
var pets_per_soldier := 0
var archer_pets: Array = []
## 弓兵1人あたりのペットの数（「弓兵ペット」を取るたびに+1）
var pets_per_archer := 0
## ペットの攻撃力（あとから付くペットにも反映）
var pet_damage := 12.0
var archer_pet_damage := 32.0
## ペットの射撃間隔・射程（全ペット共通）
var pet_interval := 0.8
var archer_pet_interval := 0.75
var pet_range := 420.0
## 弓兵ペットの斬撃の半径（遊撃兵の剣と同じ85から）
var archer_pet_range := 85.0
## ペットが一度に撃つ弾の数
## 遊撃ペットが一度に撃つ弾の数
var pet_shots := 1
## 弓兵ペットが一度に出す斬撃の回数
var archer_pet_shots := 1
## ペットの特別強化：爆裂ペット弾・巨大ペット・凍える羽根・癒しのさえずり
var pet_burst := false
var pet_giant := false
var pet_frost := false
var pet_heal := false
var archer_pet_burst := false
var archer_pet_giant := false
var archer_pet_charge := false
var archer_pet_frost := false
var archer_shadow := false
var archer_rain := false
var archer_close := false
var archer_link := false
var archer_ult := false
var archer_tornado := false
var archer_counter := false
var archer_execute := false
var archer_giant_tornado := false
var archer_heavy_arrow := false
var archer_pet_dance := false
var archer_pet_charge_burst := false
var archer_pet_flock := false
var archer_pet_body := false
var archer_pet_fusion := false
var archer_pet_heal := false
## 体当たりペット：ペットに触れた敵にペットの12倍ダメージ（pet.gd の BODY_MULT）
var pet_body := false
## 突撃ペット（6秒ごとにHPが一番高い敵へ突進）・爆裂突撃ペット（突進が当たった所で小爆発）
var pet_charge := false
var pet_charge_burst := false
## 毎フレーム更新する敵リスト（各スクリプトから参照）
var enemies_cache: Array = []
var _grid := {}

var level := 1
var xp := 0
## 経験値の獲得倍率と、まだ入っていない端数
const XP_GAIN := 1.4
## レベルが10上がるごとに経験値の倍率が XP_LEVEL_DROP（0.08）ずつ下がる（最低 XP_LEVEL_MIN = 1.0。Lv50で最低になる）
const XP_LEVEL_DROP := 0.08
const XP_LEVEL_MIN := 1.0
## Lv XP_LATE_FROM からは、入る経験値すべて（採掘場・トロッコも）が +XP_LATE_BONUS、そこから Lv1ごとに +XP_LATE_PER_LV ずつ増える
## （Lv120で1.10倍、Lv130で1.20倍、Lv200で1.90倍。上限なし。上の倍率とは別にかかる）
const XP_LATE_FROM := 120
const XP_LATE_BONUS := 0.10
const XP_LATE_PER_LV := 0.01
var _xp_frac := 0.0
var xp_to_next := xp_needed(1)
var kills := 0
var elapsed := 0.0
var upgrade_levels := {}
var pending_levelups := 0
## まだ強化を選んでいないレベル（特別強化のレベルかどうかの判定に使う。BISHOP_BONUS_LEVEL は大司教を倒したぶん）
var _pending_levels: Array = []
var game_over := false
## オート選択モード：レベルアップの強化をランダムで自動的に選ぶ
var auto_pick := false
## 「もう一度」でやり直すとき、オート選択が有効中だったか（やり直した後も有効中のままにする）
static var _retry_auto_pick := false
## オート選択の優先設定（部隊・兵装のキー → 3=最優先、2=優先、1=ちょっと優先）。リトライしても覚えておく
static var auto_priority := {}
## ゲームオーバー画面の「前回のLvからリスタート」：作り直したあとの _ready で、オートセーブを読み込んで始める
static var _load_autosave := false
static var _load_autosave_level := -1
## このフレームの最後にオートセーブする予約が入っているか（1フレームに何回レベルが上がっても保存は1回）
var _autosave_queued := false
## 今出ている強化の候補（リロール用）
var _shown_choices: Array = []
var _shown_special := false
var _shown_level := 1

var _spawn_acc := 0.0
var _next_wave := 50.0
## 黒衣の大司教：BISHOP_EVERY 秒（10分）ごとに出現する（レベルのボスとは別）
const BISHOP_EVERY := 600.0
var _next_bishop := BISHOP_EVERY
## 鉄甲兵：IRONCLAD_EVERY 秒（5分）ごとに IRONCLAD_COUNT 体まとめて出現する（ふつうの出現の上限とは別）
const IRONCLAD_EVERY := 300.0
const IRONCLAD_COUNT := 10
var _next_ironclad := IRONCLAD_EVERY
## Lv100を超えたら、さらに IRONCLAD_LATE_EVERY 秒（1分）ごとに IRONCLAD_LATE_COUNT 体が出る（アナウンスなし）
const IRONCLAD_LATE_FROM := 100
const IRONCLAD_LATE_EVERY := 60.0
const IRONCLAD_LATE_COUNT := 3
var _next_ironclad_late := -1.0
## 出現中のボス（いなければ null）
var boss: Node2D = null
var bosses_spawned := 0
## Lv刻みの敵（ボス・迫撃砲部隊）を、どのレベルの分まで出したか。-1 = わからない（この変数がなかった前のオートセーブ）
var milestone_level := 1
## このレベルごとにボスが出る
const BOSS_EVERY := 10
## Lv DOUBLE_BOSS_FROM 以降は、ボスが2体同時に出る（そのかわり1体のHPは半分）
const DOUBLE_BOSS_FROM := 130
## Lv TRIPLE_BOSS_FROM 以降は、ボスが3体同時に出る（そのかわり1体のHPは1/3）
const TRIPLE_BOSS_FROM := 160


func _ready() -> void:
	randomize()
	# セーブの枠：立ち上げたゲームごとに別の枠を使う（オートセーブがお互いに上書きしあわないように。save_slot.gd）
	var slot: int = SaveSlotScript.ensure(get_tree())
	# ウインドウの名前：「Auto Soldier ver1.2」のようにバージョンを付ける。枠2からは「 [2]」のように枠の番号も付ける
	get_window().title = "%s ver%s%s" % [ProjectSettings.get_setting("application/config/name", "Auto Soldier"), ProjectSettings.get_setting("application/config/version", ""), " [%d]" % slot if slot > 1 else ""]
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

	# 最初は兵士2人でスタート（オートセーブから再開するときは、保存した兵士を戻すので出さない）
	var loading := _load_autosave
	_load_autosave = false
	if not loading:
		add_soldier()
		add_soldier()
		# 新しいゲーム：前のゲームのオートセーブは消す（残っていると「前回のLvからリスタート」で前のゲームを読んでしまう）
		AutosaveScript.clear_slot()

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

	auto_pick_ui = AutoPickUIScript.new()
	auto_pick_ui.game = self
	add_child(auto_pick_ui)

	summary_ui = SummaryScript.new()
	summary_ui.game = self
	add_child(summary_ui)

	records_ui = RecordsUIScript.new()
	records_ui.game = self
	add_child(records_ui)

	damage_ui = DamageUIScript.new()
	damage_ui.game = self
	add_child(damage_ui)

	debug_ui = DebugUIScript.new()
	debug_ui.game = self
	add_child(debug_ui)

	changelog_ui = preload("res://scripts/changelog_ui.gd").new()
	changelog_ui.game = self
	add_child(changelog_ui)
	# 「もう一度」「前回のLvからリスタート」の前にオート選択が有効中だったら、有効中のまま始める
	if _retry_auto_pick:
		_retry_auto_pick = false
		auto_pick = true
		hud.update_auto_button()
	# 新しいゲームの番号（オートセーブから再開するときは、セーブの番号に置き換わる）
	run_id = Records.new_run_id()
	if loading:
		debug_start = {}
		# オートセーブから再開（読み込めなかったら、ふつうに最初から始める）
		if not _restore_autosave():
			add_soldier()
			add_soldier()
			_grant_starting_upgrade.call_deferred()
			milestone_level = 1
			hud.show_notice("前回のセーブを読み込めなかったので、最初から始めます")
	elif not debug_start.is_empty():
		_apply_debug_start.call_deferred(debug_start)
		debug_start = {}
	else:
		# ゲーム開始時（リトライも）、部隊・兵装のどれか1つを最初から加入した状態にする
		_grant_starting_upgrade.call_deferred()

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
	_update_hp_accel()
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


## skip_archer = 紫ひし形（archer）は数えない（迎撃部隊は紫ひし形に反応しない）
func nearest_enemy(pos: Vector2, max_dist: float, skip_archer: bool = false) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for e in enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		if skip_archer and e.kind == "archer":
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


## 敵の攻撃が当たる味方（allies() ＋ 弓兵）。弓兵は敵から狙われないが、流れ弾・爆発・ビームには当たる
func hittables() -> Array:
	var list: Array = allies()
	for a in archers:
		if is_instance_valid(a) and not a.dead:
			list.append(a)
	return list


## 生きているボス（分裂の魔獣の分身も含む）のうち pos に一番近いもの
func nearest_boss(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in enemies_cache:
		if not is_instance_valid(e) or e.dead or not e.is_boss:
			continue
		var d: float = pos.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


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
		"blocked": 0.0, "walls": 0, "wall_blocks": 0, "traps": 0, "healed": 0.0, "wall_fixed": 0, "idx": records.size()}
	records.append(r)
	return r


## 回復した量を戦績カードに記録する（sp_id を渡すと、特別強化ごとの回復量にも入れる）
func add_heal(rec: Dictionary, amount: float, sp_id: String = "") -> void:
	if rec.is_empty() or amount <= 0.0:
		return
	rec["healed"] += amount
	if sp_id != "":
		var by: Dictionary = rec.get_or_add("sp_healed", {})
		by[sp_id] = float(by.get(sp_id, 0.0)) + amount


## 味方 unit のHPを amount 回復して（最大 max_hp まで）、回復した量を rec に記録する
func heal_unit(unit: Node2D, max_hp: float, amount: float, rec: Dictionary, sp_id: String = "") -> void:
	var before: float = unit.hp
	unit.hp = minf(max_hp, unit.hp + amount)
	add_heal(rec, unit.hp - before, sp_id)


## 特別強化ぶんのダメージを分けて記録するための戦績カード。
## rec（兵士・兵装の戦績カード）の代わりに攻撃の src に渡すと、与ダメージ・撃破は rec にも入り、
## さらに rec["sp_dealt"][sp_id] に特別強化ごとのダメージが記録される（部隊戦績で兵士をクリックすると見られる）
func sp_src(rec: Dictionary, sp_id: String) -> Dictionary:
	if rec.is_empty():
		return rec
	# すでに特別強化のカードなら、元の兵士のカードから作り直す（中の特別強化のほうで記録する）
	if rec.has("sp_id"):
		rec = records[rec["rec_idx"]]
	if not rec.has("_sp_src"):
		rec["_sp_src"] = {}
	var cache: Dictionary = rec["_sp_src"]
	if not cache.has(sp_id):
		cache[sp_id] = {"cat": rec["cat"], "name": rec["name"], "sp_id": sp_id, "rec_idx": rec["idx"],
			"dealt": 0.0, "taken": 0.0, "kills": 0, "blocked": 0.0, "walls": 0, "wall_blocks": 0, "traps": 0,
			"robot_boost": rec.get("robot_boost", false)}
	return cache[sp_id]


## デバッグ：部隊戦績をリセットする（与ダメ・撃破・被ダメ・回復などの数字をすべて0に。兵士や兵装の行はそのまま残る）
func reset_records() -> void:
	for r in records:
		_reset_record(r)
		for sub in r.get("_sp_src", {}).values():
			_reset_record(sub)
	damage_taken.clear()
	_recent_taken.clear()


## 被害状況に記録する。victim = やられた側のキー（soldier・guard・knight・heavy・castle・wall・watchtower など）、
## amount = 実際に減ったHP・耐久。攻撃した敵は dmg_from（空なら「その他」）
func note_taken(victim: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var v: Dictionary = damage_taken.get_or_add(victim, {"total": 0.0, "by": {}})
	v["total"] = float(v["total"]) + amount
	var who := dmg_from if dmg_from != "" else "その他"
	v["by"][who] = float(v["by"].get(who, 0.0)) + amount
	# 直近30秒のぶん（今の1秒の入れ物に足す）
	var sec := int(elapsed)
	if _recent_taken.is_empty() or int(_recent_taken[-1][0]) != sec:
		_prune_recent()
		_recent_taken.append([sec, {}])
	var bucket: Dictionary = _recent_taken[-1][1].get_or_add(victim, {})
	bucket[who] = float(bucket.get(who, 0.0)) + amount


## 直近30秒より前の入れ物を捨てる
func _prune_recent() -> void:
	var oldest := int(elapsed) - RECENT_WINDOW + 1
	while not _recent_taken.is_empty() and int(_recent_taken[0][0]) < oldest:
		_recent_taken.pop_front()


## 直近30秒（ゲーム内の時間で30秒）の被害状況。damage_taken と同じ形
func recent_damage() -> Dictionary:
	_prune_recent()
	var out := {}
	for b in _recent_taken:
		for victim in b[1]:
			var v: Dictionary = out.get_or_add(victim, {"total": 0.0, "by": {}})
			for who in b[1][victim]:
				var amt := float(b[1][victim][who])
				v["total"] = float(v["total"]) + amt
				v["by"][who] = float(v["by"].get(who, 0.0)) + amt
	return out


func _reset_record(r: Dictionary) -> void:
	for k in r.keys():
		if k == "idx" or k == "rec_idx" or k == "_sp_src":
			continue
		var v = r[k]
		if v is float:
			r[k] = 0.0
		elif v is int:
			r[k] = 0
		elif v is Dictionary:
			v.clear()


func set_auto_pick(on: bool) -> void:
	auto_pick = on
	hud.update_auto_button()
	# 選択画面が出ている最中に有効にしたら、その場で自動選択
	if on and level_up_ui.visible and not _shown_choices.is_empty():
		level_up_ui._pick(_auto_pick_from(_shown_choices, _shown_special)["id"])


func toggle_stats() -> void:
	if level_up_ui.visible or upgrades_ui.visible or auto_pick_ui.visible:
		return
	stats_ui.toggle()


func toggle_upgrades() -> void:
	if level_up_ui.visible or stats_ui.visible or auto_pick_ui.visible:
		return
	upgrades_ui.toggle()


func toggle_auto_pick_settings() -> void:
	if level_up_ui.visible or stats_ui.visible or upgrades_ui.visible:
		return
	auto_pick_ui.toggle()


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


func add_archer() -> void:
	if archers.size() >= MAX_ARCHERS:
		return
	var a := ArcherScript.new()
	a.game = self
	a.index = archers.size()
	a.position = castle.gate_position() + Vector2(randf_range(-40, 40), -30)
	world.add_child(a)
	archers.append(a)
	# あとから増えた弓兵にも、弓兵ペットを付ける
	_fill_archer_pets()


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


## 採掘場を置く（1つ目は城の右側、2つ目（第二採掘場）は左側。どちらも壁の外）
func add_mine_site() -> void:
	if mine_sites.size() >= 2:
		return
	var m := MineSiteScript.new()
	m.game = self
	m.index = mine_sites.size()
	m.interval = mine_interval
	m.xp_amount = mine_xp
	var off: Vector2 = MineSiteScript.OFFSET
	if m.index == 1:
		off.x = -off.x
	m.position = castle.position + off
	ground.add_child(m)
	mine_sites.append(m)


## 採掘兵を出撃させる
func add_miner() -> void:
	var m := MinerScript.new()
	m.game = self
	m.index = miners.size()
	m.position = castle.gate_position()
	world.add_child(m)
	miners.append(m)


## 待機中の兵士が、ふつうなら home で待つところで呼ぶ。空いている採掘場（今使っている所 → 近い所）があれば
## 掘りに行く場所を、なければ（ほかの兵士が掘っている・採掘場がない）home をそのまま返す。毎フレーム呼んでいる間だけ掘り続ける
func mine_spot(unit: Node2D, home: Vector2) -> Vector2:
	var best: Node2D = null
	for m in mine_sites:
		if m.worker == unit and m.is_free_for(unit):
			best = m
			break
		if m.is_free_for(unit) and (best == null or unit.global_position.distance_to(m.work_spot()) < unit.global_position.distance_to(best.work_spot())):
			best = m
	if best == null:
		return home
	return best.claim(unit, home)


## 採掘場が、unit が離れたときに呼ぶ（快足の鉱夫の帰り道）
func on_left_mine(unit: Node2D) -> void:
	if mine_fast:
		_mine_return_until[unit.get_instance_id()] = elapsed + MINE_RETURN_TIME


## 快足の鉱夫：採掘場へ向かっている間と、離れてから少しの間（帰り道）は移動速度2倍。それ以外は1倍
func mine_speed_mult(unit: Node2D) -> float:
	if not mine_fast:
		return 1.0
	for m in mine_sites:
		if m.worker == unit and not m.mining:
			return 2.0
	var id := unit.get_instance_id()
	if _mine_return_until.has(id):
		if elapsed < float(_mine_return_until[id]):
			# また採掘場に着いて掘っている間は戻り道ではない
			for m in mine_sites:
				if m.worker == unit and m.mining:
					return 1.0
			return 2.0
		_mine_return_until.erase(id)
	return 1.0


## ペット大合体（ペットの特別強化）を始める
var pet_fusion: Node2D = null


func start_pet_fusion() -> void:
	if pet_fusion != null:
		return
	pet_fusion = PetFusionScript.new()
	pet_fusion.game = self
	world.add_child(pet_fusion)


## 弓兵ペット大合体（弓兵ペットの特別強化）を始める
var archer_fusion: Node2D = null


func start_archer_pet_fusion() -> void:
	archer_pet_fusion = true
	if archer_fusion != null:
		return
	archer_fusion = PetFusionScript.new()
	archer_fusion.game = self
	archer_fusion.archer = true
	world.add_child(archer_fusion)


## 全遊撃兵にペットを1匹ずつ追加する
func add_pet() -> void:
	if pets_per_soldier >= MAX_PETS:
		return
	pets_per_soldier += 1
	_fill_pets()


func add_archer_pet() -> void:
	if pets_per_archer >= MAX_PETS:
		return
	pets_per_archer += 1
	_fill_archer_pets()


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


func _fill_archer_pets() -> void:
	for a in archers:
		var have := 0
		for p in archer_pets:
			if p.owner_soldier == a:
				have += 1
		while have < pets_per_archer:
			var p := PetScript.new()
			p.game = self
			p.owner_soldier = a
			p.index = have
			p.archer = true
			p.damage = archer_pet_damage
			p.position = a.position
			world.add_child(p)
			archer_pets.append(p)
			have += 1


# ---------------------------------------------------------------- 敵の出現

func _update_spawning(delta: float) -> void:
	# 時間とともに出現ペースが上がる
	var rate := minf(SPAWN_BASE + elapsed * SPAWN_GROWTH, SPAWN_MAX)
	_spawn_acc += rate * delta
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if enemies_cache.size() < MAX_ENEMIES:
			var k := _pick_kind()
			var pos := _random_spawn_pos()
			if k == "stealth" or k == "elite_stealth":
				pos = _stealth_spawn_pos()
			elif k == "mortar" or k == "seeker":
				pos = _mortar_spawn_pos()
			_spawn_enemy(k, pos)
	# 10分ごとに黒衣の大司教（まだ前の大司教が残っていれば出さない）
	if elapsed >= _next_bishop:
		_next_bishop += BISHOP_EVERY
		if not bishop_alive():
			_spawn_bishop()
	# 5分ごとに鉄甲兵の部隊。ただし黒衣の大司教が来る10分・20分…の回は出さない（5分・15分・25分…だけ）
	if elapsed >= _next_ironclad:
		var tick := _next_ironclad
		_next_ironclad += IRONCLAD_EVERY
		if not is_zero_approx(fmod(tick, BISHOP_EVERY)):
			_spawn_ironclad_squad()
	# Lv100を超えたら、1分ごとに鉄甲兵3体（アナウンスなし）。超えた時から数え始める
	if level > IRONCLAD_LATE_FROM:
		if _next_ironclad_late < 0.0:
			_next_ironclad_late = elapsed + IRONCLAD_LATE_EVERY
		elif elapsed >= _next_ironclad_late:
			_next_ironclad_late += IRONCLAD_LATE_EVERY
			_spawn_ironclads(IRONCLAD_LATE_COUNT)
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
	# エリート隠密兵：4分から。隠密兵とは別に出る（20分で隠密兵の約1/3の出やすさ）
	if elapsed > 240.0:
		pool.append(["elite_stealth", 0.5 + elapsed / 600.0])
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


## ボスのHP倍率。7体目（Lv70）までは、前の「2乗で加速する」HPの曲線の8割にする
## （ふつうの敵のHPが9分半まで1倍なので、そのままだと序盤〜中盤のボスが柔らかすぎるため）。
## 8体目からは、7体目の倍率をスタートにして、ふつうの敵の倍率が7体目のときから増えたぶんの
## BOSS_LATE_RATIO 倍を足していく（切れ目なく、敵と同じ「だんだん加速する」上がり方で続く）
const BOSS_CURVE_UNTIL := 7
const BOSS_CURVE_RATIO := 0.8
const BOSS_LATE_RATIO := 0.75
## 7体目が出たときの、ボスの倍率とふつうの敵の倍率
var _boss_last_curve_mult := 0.0
var _boss_last_curve_hp := 0.0


## 序盤のボスをさらに硬くする：BOSS_EARLY_UNTIL 分までは ×BOSS_EARLY_MULT。
## そのあとは、BOSS_EARLY_UNTIL 分の時点で上乗せしたぶんをずっと足したまま伸び続ける（下がらない）
const BOSS_EARLY_MULT := 3.0
const BOSS_EARLY_UNTIL := 10.0


func _boss_hp_mult() -> float:
	var base := _boss_curve_mult()
	if elapsed / 60.0 <= BOSS_EARLY_UNTIL:
		return base * BOSS_EARLY_MULT
	return base + (BOSS_EARLY_MULT - 1.0) * _boss_curve_at_early_until()


## BOSS_EARLY_UNTIL 分のときのボス用HP倍率（上乗せ前）
func _boss_curve_at_early_until() -> float:
	var t := BOSS_EARLY_UNTIL * 60.0 * 1.3
	var old := 1.0 + t / 75.0 + pow(t / 170.0, 2.0)
	return maxf(_hp_mult_at(BOSS_EARLY_UNTIL), BOSS_CURVE_RATIO * old)


func _boss_curve_mult() -> float:
	if bosses_spawned > BOSS_CURVE_UNTIL:
		return _boss_last_curve_mult + BOSS_LATE_RATIO * maxf(0.0, _boss_table_mult() - _boss_last_curve_hp)
	var t := elapsed * 1.3
	var old := 1.0 + t / 75.0 + pow(t / 170.0, 2.0)
	var mult := maxf(_boss_table_mult(), BOSS_CURVE_RATIO * old)
	_boss_last_curve_mult = mult
	_boss_last_curve_hp = _boss_table_mult()
	return mult


## 敵の出現ペース（1秒に何体）：SPAWN_BASE から毎秒 SPAWN_GROWTH ずつ増え、SPAWN_MAX で頭打ち
const SPAWN_BASE := 0.8
## 5分（300秒）でちょうど上限になる増え方
const SPAWN_GROWTH := 0.034
const SPAWN_MAX := 11.0
## 出現ペースが上限になる時刻（秒）。5分
const SPAWN_CAP_TIME := (SPAWN_MAX - SPAWN_BASE) / SPAWN_GROWTH
## ボスのHP倍率のもとにする目安表：[分, 倍率]。あいだは直線でつなぐ
const HP_POINTS := [[0.0, 1.0], [1.0, 2.0], [5.0, 6.0], [10.0, 12.0], [15.0, 25.0], [20.0, 40.0], [25.0, 55.0], [30.0, 83.0], [40.0, 150.0], [60.0, 400.0], [90.0, 1200.0]]
## 表の最後（90分）より後は、最後の上がり幅（毎分約+26.7）から、上がり幅が1分ごとに HP_LATE_ACCEL ずつ大きくなる
const HP_LATE_ACCEL := 0.6


## ふつうの敵のHP倍率：0〜10分は1分ごとに +0.5。10分からは上がり幅そのものが1分ごとに +0.2 ずつ大きくなる
## （1分で×1.5、5分で×3.5、10分で×6、20分で×21、30分で×56、40分で×111、60分で×281、90分で×686）
## 170overtime（HP加速）：Lv HP_ACCEL_UP_FROM からは、レベル10ごとに上がり幅の増え方が +HP_ACCEL_UP_STEP ずつ大きくなる（Lv170〜で0.3、Lv180〜で0.4、Lv190〜で0.5…上限なし）。
## そのレベルになった時点から増え方が変わるだけで、倍率がいきなり跳ね上がることはない
const HP_EARLY_PER_MIN := 0.5
const HP_SWITCH_MIN := 10.0
const HP_ACCEL := 0.2
const HP_ACCEL_UP_FROM := 170
const HP_ACCEL_UP_STEP := 0.1
## 増え方が変わった記録：[変わった時刻（分）, 新しい増え方] の並び
var _hp_accel_changes: Array = []
var _hp_accel_now := HP_ACCEL


static func hp_accel_for_level(lv: int) -> float:
	if lv < HP_ACCEL_UP_FROM:
		return HP_ACCEL
	return HP_ACCEL + HP_ACCEL_UP_STEP * (floori(lv / 10.0) - floori(HP_ACCEL_UP_FROM / 10.0) + 1)


func _update_hp_accel() -> void:
	var want := hp_accel_for_level(level)
	if not is_equal_approx(want, _hp_accel_now):
		_hp_accel_changes.append([elapsed / 60.0, want])
		_hp_accel_now = want


func _hp_mult() -> float:
	var m := elapsed / 60.0
	var f := 1.0 + HP_EARLY_PER_MIN * minf(m, HP_SWITCH_MIN)
	if m <= HP_SWITCH_MIN:
		return f
	# 10分からは、上がり幅 r が増え方 a で大きくなっていく（a は途中で変わることがある）
	var t := HP_SWITCH_MIN
	var r := HP_EARLY_PER_MIN
	var a := HP_ACCEL
	for ch in _hp_accel_changes:
		var t1 := clampf(float(ch[0]), t, m)
		var dt := t1 - t
		f += r * dt + a / 2.0 * dt * dt
		r += a * dt
		t = t1
		a = float(ch[1])
	var rest := m - t
	f += r * rest + a / 2.0 * rest * rest
	return f


## 目安表どおりの倍率（ボス用。1分で×2、5分で×6、10分で×12、15分で×25、20分で×40、25分で×55、30分で×83、40分で×150、60分で×400、90分で×1200、120分で約×2270）
func _boss_table_mult() -> float:
	return _hp_mult_at(elapsed / 60.0)


## m 分のときの目安表の倍率（ボス用）
func _hp_mult_at(m: float) -> float:
	for i in range(1, HP_POINTS.size()):
		var p0: Array = HP_POINTS[i - 1]
		var p1: Array = HP_POINTS[i]
		if m <= p1[0]:
			return lerpf(p0[1], p1[1], (m - p0[0]) / (p1[0] - p0[0]))
	var last: Array = HP_POINTS[HP_POINTS.size() - 1]
	var prev: Array = HP_POINTS[HP_POINTS.size() - 2]
	var slope: float = (last[1] - prev[1]) / (last[0] - prev[0])
	var d: float = m - last[0]
	return last[1] + slope * d + HP_LATE_ACCEL / 2.0 * d * d


## 170overtime：Lv OVERTIME_FROM_LV（170）以降の難易度上昇システム。
## ・HP加速：Lv170からHP倍率の増え方が加速（詳細は上の HP_ACCEL_UP_FROM 参照）
## ・時間経過HP増加：Lv170になった時刻から、1分たつごとに、これから出る敵とボス（大司教・手下・鉄甲兵・迫撃砲部隊も）のHPが +OVERTIME_HP_PER_MIN（1%）ずつ増える（足し算・上限なし）。
##   ほかのHPの倍率とは別に、出るときにかける（もう出ている敵は変わらない。分裂の魔獣の分かれた体・分裂体は親の倍率を引き継ぐ）
const OVERTIME_FROM_LV := 170
const OVERTIME_HP_PER_MIN := 0.01
## 170overtime：今のレベルが Lv OVERTIME_FROM_LV 以上のあいだ、敵（ボスも）からのダメージ1回ごとに、
## キャラクターにも建築物（城・壁・設置物）にも +（レベルの百の位）を足す（Lv170〜199で+1、Lv200〜299で+2…）。
## 当たったときのレベルで決まる。受ける側の軽減（盾・城の被ダメージ倍率など）より先に足す
func overtime_dmg_bonus() -> float:
	if level < OVERTIME_FROM_LV:
		return 0.0
	return float(level / 100)


## 170overtime が始まった時刻（秒）。-1 = まだ始まっていない
var overtime_start := -1.0


## 170overtime を始める（Lv OVERTIME_FROM_LV 以上になったとき・デバッグ開始・ロードのときに呼ぶ。始まっていれば何もしない）
func _check_overtime() -> void:
	if overtime_start < 0.0 and level >= OVERTIME_FROM_LV:
		overtime_start = elapsed


## 170overtime の、これから出る敵のHPの倍率（始まってからの丸1分ごとに +1%）
func overtime_hp_mult() -> float:
	if overtime_start < 0.0:
		return 1.0
	return 1.0 + OVERTIME_HP_PER_MIN * floorf(maxf(0.0, elapsed - overtime_start) / 60.0)


func _spawn_enemy(kind: String, pos: Vector2) -> void:
	spawn_enemy_at(kind, pos)


## 指定した場所に敵を出す（hp_mult を省略すると今の時間に合わせた強さ）
func spawn_enemy_at(kind: String, pos: Vector2, hp_mult: float = -1.0) -> Node2D:
	var e := EnemyScript.new()
	e.game = self
	# hp_mult を渡したとき（分裂体など）は親の倍率をそのまま使う（170overtime も親のぶんが入っている）
	e.setup(kind, hp_mult if hp_mult > 0.0 else _hp_mult() * overtime_hp_mult())
	e.position = clamp_to_map(pos, 20.0)
	world.add_child(e)
	return e


## 迫撃砲部隊：マップの端に迫撃砲が8体一気に現れる
func _spawn_mortar_squad() -> void:
	for i in 8:
		spawn_enemy_at("mortar", _mortar_spawn_pos())
	hud.show_banner("⚠ 迫撃砲部隊 襲来！ ⚠", Color(1.0, 0.6, 0.3))


## 鉄甲兵を上端に横一列で n 体出す
func _spawn_ironclads(n: int) -> void:
	for i in n:
		var px := lerpf(MAP_RECT.position.x + 60.0, MAP_RECT.end.x - 60.0, (i + 0.5) / n)
		spawn_enemy_at("ironclad", Vector2(px, MAP_RECT.position.y + 30.0 + randf() * 20.0))


## 鉄甲兵部隊：上端に横一列で IRONCLAD_COUNT 体が一気に現れる
func _spawn_ironclad_squad() -> void:
	_spawn_ironclads(IRONCLAD_COUNT)
	hud.show_banner("⚠ 鉄甲兵部隊 襲来！ ⚠", Color(0.6, 0.75, 0.95))


## 5分（castle.gd の EARLY_HALF_UNTIL）までは、城とキャラクター（遊撃・迎撃・近衛・重装）が受けるダメージが半分。設置物は対象外
func early_damage_mult() -> float:
	return 0.5 if elapsed <= CastleScript.EARLY_HALF_UNTIL else 1.0


## ボス出現（Lv10ごと）。破城の魔王 → 砲台要塞 → 分裂の魔獣 の順に来る。
## Lv130からは、この順番の次の2体が同時に出る（魔王&要塞 → 分裂&魔王 → 要塞&分裂 …）。1体のHPは半分
func _spawn_boss() -> void:
	var n := 3 if level >= TRIPLE_BOSS_FROM else (2 if level >= DOUBLE_BOSS_FROM else 1)
	var titles := PackedStringArray()
	var first: Node2D = null
	for i in n:
		bosses_spawned += 1
		var e := EnemyScript.new()
		e.game = self
		# 何回目のボス戦か（2体同時でも、強さの段階はボス戦の回数で決める）
		e.boss_rank = level / BOSS_EVERY
		var kind: String = ["boss3", "boss", "boss2"][bosses_spawned % 3]
		# 2体同時なら1体のHPは半分、3体同時なら1/3
		e.setup(kind, _boss_hp_mult() / n * overtime_hp_mult())
		# 横に並べる（1体なら真ん中、2体なら左右、3体なら左・真ん中・右）
		var x: float = MAP_RECT.get_center().x + (i - (n - 1) / 2.0) * (520.0 if n == 2 else 360.0)
		e.position = Vector2(x, MAP_RECT.position.y + (110.0 if kind == "boss2" else 60.0))
		world.add_child(e)
		titles.append("「%s」" % e.boss_title)
		if first == null:
			first = e
	boss = first
	hud.show_banner("⚠ BOSS%s出現！ ⚠" % "＆".join(titles), Color(1.0, 0.4, 0.5))


## 黒衣の大司教を出す（HPは時間の倍率に合わせる）
func _spawn_bishop() -> void:
	var e := EnemyScript.new()
	e.game = self
	e.boss_rank = maxi(1, int(elapsed / BISHOP_EVERY))
	# HPはほかのボスと同じボス用の倍率（呼んだときに覚える値は書き換えないよう、元に戻す）
	var keep_mult := _boss_last_curve_mult
	var keep_hp := _boss_last_curve_hp
	var mult := _boss_hp_mult()
	_boss_last_curve_mult = keep_mult
	_boss_last_curve_hp = keep_hp
	e.setup("boss4", mult * overtime_hp_mult())
	e.position = Vector2(MAP_RECT.get_center().x, MAP_RECT.position.y + 60.0)
	world.add_child(e)
	if boss == null or not is_instance_valid(boss) or boss.dead:
		boss = e
	hud.show_banner("⚠ BOSS「黒衣の大司教」出現！ ⚠", Color(0.75, 0.45, 1.0))


## 近衛の突進の基本の威力（遊撃兵の強化は乗らない）
const KNIGHT_BASE_DAMAGE := 80.0


## 近衛兵の突進の威力：基本の威力に剛突の倍率をかける
func knight_damage() -> float:
	return KNIGHT_BASE_DAMAGE * knight_stats.damage


## 黒衣の大司教が生きているか
func bishop_alive() -> bool:
	for e in enemies_cache:
		if is_instance_valid(e) and not e.dead and e.kind == "boss4":
			return true
	return false


## 生きているボス（分裂の魔獣は分かれた体も1体ずつ）
func alive_bosses() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(x: Node2D) -> bool: return x.is_boss and not x.dead)


# ---------------------------------------------------------------- 経験値・レベルアップ

func on_enemy_killed(e: Node2D) -> void:
	kills += 1
	if e.is_boss:
		# ボスが全部いなくなったら撃破（分裂の魔獣は、分かれた体が全部いなくなるまで撃破にならない）
		var rest: Array = alive_bosses().filter(func(x: Node2D) -> bool: return x != e)
		boss = rest[0] if not rest.is_empty() else null
		if boss == null:
			hud.show_banner("BOSS 撃破！", Color(1.0, 0.85, 0.3))
		elif e.kind != "boss3" or _alive_split_piece() == null:
			hud.show_banner("BOSS「%s」撃破！" % e.boss_title, Color(1.0, 0.85, 0.3))
		spawn_burst(e.global_position, Color(1.0, 0.85, 0.3), 60.0)
	spawn_burst(e.global_position, e.color, e.radius)
	# 氷像の囮：結界の中で倒された敵（ボス以外）が20%の確率で氷像になる（同時に12体まで）
	if castle.ice_statue and not e.is_boss and castle.frost_radius > 0.0 and randf() < 0.2 \
			and castle.global_position.distance_to(e.global_position) < castle.frost_radius \
			and get_tree().get_nodes_in_group("placed_ice_statue").size() < 12:
		spawn_placed("ice_statue", e.global_position, 0.0, 16.0, 20.0, castle.record)
	add_xp(e.xp_value)
	# 黒衣の大司教を倒したら、特別強化の3択が1回ぶん出る（レベルアップと同じ順番待ちに入る）
	if e.kind == "boss4" and not game_over:
		pending_levelups += 1
		_pending_levels.append(BISHOP_BONUS_LEVEL)
		if not level_up_ui.visible:
			_open_level_up()
		request_autosave()


## まだ生きている分裂の魔獣の体（いなければ null）
func _alive_split_piece() -> Node2D:
	for x in get_tree().get_nodes_in_group("enemies"):
		if x.kind == "boss3" and not x.dead:
			return x
	return null


## レベル lv から次のレベルまでに必要な経験値
## （元の式を 1.44 = 1.2×1.2 で割って、レベルの上がりやすさを元の約1.44倍にしている。
## Lv² の部分は ÷7。高いレベルほど少し上がりにくい）
func xp_needed(lv: int) -> int:
	return maxi(1, roundi((4.0 + lv * 3.0 + lv * lv / 7.0) / 1.44))


## 今の経験値の獲得倍率（Lv1〜9で1.4倍。Lv10ごとに0.08ずつ下がる：Lv10で×1.32、Lv30で×1.16、Lv50以降は×1.0）
func xp_mult() -> float:
	return maxf(XP_LEVEL_MIN, XP_GAIN - XP_LEVEL_DROP * floorf(level / 10.0))


## Lv XP_LATE_FROM からの経験値の倍率（それより前は1倍）
func xp_late_mult() -> float:
	if level < XP_LATE_FROM:
		return 1.0
	return 1.0 + XP_LATE_BONUS + XP_LATE_PER_LV * (level - XP_LATE_FROM)


func add_xp(amount: int) -> void:
	_add_xp_scaled(amount * xp_mult() * xp_late_mult())


## 経験値を amount だけ入れる（レベルの倍率なし。採掘場・トロッコで使う）。Lv XP_LATE_FROM からは xp_late_mult() 倍
func add_raw_xp(amount: int) -> void:
	_add_xp_scaled(amount * xp_late_mult())


## 倍率をかけたあとの経験値を入れる。端数はためておいて、1たまったら入る
func _add_xp_scaled(value: float) -> void:
	_xp_frac += value
	var whole := int(floor(_xp_frac + 0.000001))
	_xp_frac = maxf(0.0, _xp_frac - whole)
	_gain_xp(whole)


## 経験値をそのまま amount だけ入れる。たまったらレベルアップ
func _gain_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var leveled := false
	while xp >= xp_to_next:
		leveled = true
		xp -= xp_to_next
		level += 1
		xp_to_next = xp_needed(level)
		pending_levelups += 1
		_pending_levels.append(level)
		_spawn_level_milestone()
		_check_overtime()
	if pending_levelups > 0 and not level_up_ui.visible and not game_over:
		_open_level_up()
	# レベルが上がったらオートセーブ（3択を出したあと、このフレームの最後に保存する）
	if leveled:
		request_autosave()


# ---------------------------------------------------------------- オートセーブ

## Lv刻みの敵：Lv10ごとにボス、Lv5・15・25…で迫撃砲部隊（8体）が襲来。今のレベルの分を出す（同じレベルで2回は出さない）
func _spawn_level_milestone() -> void:
	if milestone_level >= level:
		return
	milestone_level = level
	if level % BOSS_EVERY == 0:
		_spawn_boss()
	if level % 10 == 5:
		_spawn_mortar_squad()


## オートセーブを予約する。倒した敵の分裂などが全部終わってから保存したいので、このフレームの最後に保存する
func request_autosave() -> void:
	if _autosave_queued:
		return
	_autosave_queued = true
	_do_autosave.call_deferred()


func _do_autosave() -> void:
	_autosave_queued = false
	# 同じフレームで城が落とされていたら保存しない（前の保存を残す）
	if game_over:
		return
	AutosaveScript.save(self)


## ゲームオーバー画面の「前回のLvからリスタート」：ゲームを作り直して、オートセーブから続きを始める
## level を指定するとそのレベルのセーブから（省略時は最新）
func restart_from_autosave(level: int = -1) -> void:
	if AutosaveScript.peek(level).is_empty():
		return
	_retry_auto_pick = auto_pick
	_load_autosave = true
	_load_autosave_level = level
	restart()


## オートセーブを読み込んで、保存したときの状態に戻す（_ready の最後で呼ぶ）。読み込めなかったら false
func _restore_autosave() -> bool:
	# 前の形式のセーブには milestone_level がないので、そのときは -1（わからない）のままになる
	milestone_level = -1
	# run_id がない前の形式のセーブは、保存した時刻から番号を作る（同じセーブから何回リスタートしても同じ番号）
	var new_id := run_id
	var head: Dictionary = AutosaveScript.peek(_load_autosave_level)
	run_id = ""
	var info: Dictionary = AutosaveScript.load_into(self, _load_autosave_level)
	_load_autosave_level = -1
	if info.is_empty():
		run_id = new_id
		return false
	if run_id == "":
		run_id = "save_%d" % int(head.get("saved_at", 0))
	# 170overtime がない前の形式のセーブで、もう Lv OVERTIME_FROM_LV 以上なら、ロードした時刻から始める
	_check_overtime()
	game_over = false
	get_tree().paused = false
	enemies_cache = get_tree().get_nodes_in_group("enemies")
	_rebuild_grid()
	# 保存したレベルの Lv刻みの敵がまだ出ていなかったら、ここで出す（-1 = 前の形式のセーブなので、わからないから出さない）
	if milestone_level >= 0 and milestone_level < level:
		_spawn_level_milestone()
		enemies_cache = get_tree().get_nodes_in_group("enemies")
	hud.show_notice("Lv%d から再開しました（%02d:%02d）" % [level, int(elapsed) / 60, int(elapsed) % 60])
	hud.refresh()
	# 保存したときに強化の3択が出ていたら、同じ3択をもう一度出す（引き直しにはならない）
	var choices: Array = []
	for id in info.get("choices", []):
		for u in Upgrades.LIST + Upgrades.SPECIAL:
			if u["id"] == id:
				choices.append(u)
				break
	if pending_levelups > 0:
		if choices.is_empty():
			_open_level_up()
		elif auto_pick:
			var u: Dictionary = _auto_pick_from(choices, bool(info.get("special", false)))
			hud.show_notice("オート選択：【%s】%s%s" % [Upgrades.CAT_LABEL[u["cat"]], "★" if u.get("special", false) else "", u["name"]])
			_on_upgrade_chosen(u["id"])
		else:
			get_tree().paused = true
			_shown_choices = choices
			_shown_special = bool(info.get("special", false))
			_shown_level = int(info.get("for_level", level))
			level_up_ui.show_choices(choices, upgrade_levels, _shown_level, _shown_special, bool(info.get("rerolled", false)))
	return true


func _open_level_up() -> void:
	var for_level: int = _pending_levels[0] if not _pending_levels.is_empty() else level
	var special := false
	var choices: Array = []
	# Lv5ごとと、大司教を倒したときに特別強化（候補がなければ通常の強化）
	if for_level % SPECIAL_EVERY == 0:
		choices = Upgrades.roll_special(upgrade_levels, 3)
		# 候補が「まだ取れないもの」だけなら、通常の強化にする
		if choices.all(func(c: Dictionary) -> bool: return Upgrades.is_locked(c, upgrade_levels)):
			choices = []
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
		# オート選択：画面を止めずに選ぶ（オート選択設定で優先にしたものを先に取る。同じならランダム。
		# 優先のものが1つもなければ1回リロール）
		var u: Dictionary = _auto_pick_from(choices, special)
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
	var choices := _rerolled_choices(_shown_choices, _shown_special)
	_shown_choices = choices
	level_up_ui.show_choices(choices, upgrade_levels, _shown_level, _shown_special, true)


## リロールした候補：old とはなるべく別のものを3つ
func _rerolled_choices(old: Array, special: bool) -> Array:
	var pool: Array
	if special:
		pool = Upgrades.roll_special(upgrade_levels, 999)
	else:
		pool = Upgrades.roll(upgrade_levels, 999, self)
	var old_ids: Array = old.map(func(u: Dictionary) -> String: return u["id"])
	var fresh: Array = pool.filter(func(u: Dictionary) -> bool: return not u["id"] in old_ids)
	var choices: Array = fresh.slice(0, 3)
	# 新しい候補が3つに足りなければ、前の候補から埋める
	for u in pool:
		if choices.size() >= 3:
			break
		if not choices.has(u):
			choices.append(u)
	return choices


## オート選択で1つ選ぶ。3つの中に、設定してある一番上の段（最優先 → 優先 → ちょっと優先）がなければ、1回だけリロールして引き直す
func _auto_pick_from(choices: Array, special: bool) -> Dictionary:
	# まだ取れない候補（条件未達成）はオート選択でも選ばない
	var open: Array = choices.filter(func(c: Dictionary) -> bool: return not Upgrades.is_locked(c, upgrade_levels))
	if not open.is_empty():
		choices = open
	var u: Dictionary = Upgrades.auto_choose(choices, auto_priority)
	var want := 0
	for v in auto_priority.values():
		want = maxi(want, int(v))
	if want > 0 and Upgrades.priority_of(u, auto_priority) < want:
		var again: Array = _rerolled_choices(choices, special).filter(func(c: Dictionary) -> bool: return not Upgrades.is_locked(c, upgrade_levels))
		if not again.is_empty():
			u = Upgrades.auto_choose(again, auto_priority)
	return u


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


## おもしろ特別強化の見た目（kind: "firework" / "jack" / "roar"）
func spawn_fun_fx(kind: String, pos: Vector2) -> Node2D:
	var f := FunFxScript.new()
	f.game = self
	f.kind = kind
	f.position = pos
	f.start = pos
	f.end = pos
	effects.add_child(f)
	return f


## 竜巻（弓兵の竜巻矢）：duration 秒のあいだ、まわりの敵を中心へ吸い寄せる
func spawn_tornado(pos: Vector2, duration: float) -> void:
	var t := ArcherFxScript.new()
	t.game = self
	t.kind = "tornado"
	t.radius = 130.0
	t.duration = duration
	t.position = pos
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
	auto_pick_ui.close_panel()
	get_tree().paused = true
	# 歴代記録に保存する（上位20件だけ残る。同じゲームの記録がもうあれば、新しい結果で上書きする）
	last_record_id = Records.add(level, elapsed, kills, summary_ui.snapshot(), debug_run, Records.PATH, run_id)
	hud.show_game_over()


# ---------------------------------------------------------------- デバッグ

## デバッグ設定メニューを開く（敵を全部消してから）
func open_debug() -> void:
	if level_up_ui.visible or game_over:
		return
	stats_ui.close_panel()
	upgrades_ui.close_panel()
	auto_pick_ui.close_panel()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			e.dead = true
			e.remove_from_group("enemies")
			e.queue_free()
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		b.queue_free()
	boss = null
	enemies_cache = []
	debug_ui.open_panel()


## デバッグ設定の内容で、ゲームを最初から作り直して始める
func start_debug(cfg: Dictionary) -> void:
	debug_start = cfg
	restart()


## ゲーム開始時にランダムで1つ加入した状態にする部隊・兵装
const STARTING_UPGRADE_POOL := ["builder", "guard", "knight", "sniper", "heavy", "engineer",
	"tower", "cannon", "catapult", "ballista", "mine_site"]


func _grant_starting_upgrade() -> void:
	var id: String = STARTING_UPGRADE_POOL[randi() % STARTING_UPGRADE_POOL.size()]
	var u: Dictionary = {}
	for x in Upgrades.LIST:
		if x["id"] == id:
			u = x
	if u.is_empty():
		return
	upgrade_levels[id] = 1
	Upgrades.apply(id, 1, self)
	hud.show_notice("最初から加入：%s" % u["name"])
	hud.refresh()


func _apply_debug_start(cfg: Dictionary) -> void:
	debug_run = true
	elapsed = float(cfg["elapsed"])
	level = int(cfg["level"])
	xp = 0
	_xp_frac = 0.0
	xp_to_next = xp_needed(level)
	# ボスの出現順・強さの段階、大司教・大群の時刻を、このレベル・時間に合わせる
	var n_boss := 0
	for lv in range(BOSS_EVERY, level + 1, BOSS_EVERY):
		n_boss += 3 if lv >= TRIPLE_BOSS_FROM else (2 if lv >= DOUBLE_BOSS_FROM else 1)
	if n_boss > BOSS_CURVE_UNTIL:
		# 7体目のボスが出たころ（今のレベルの割合で見積もった時間）のHP倍率をもとにする
		var keep := elapsed
		elapsed = keep * float(BOSS_CURVE_UNTIL * BOSS_EVERY) / float(level)
		bosses_spawned = BOSS_CURVE_UNTIL
		_boss_hp_mult()
		elapsed = keep
	bosses_spawned = n_boss
	# 始めるレベルがちょうど Lv刻みの敵のレベル（Lv10・15・20…）なら、そのレベルの分をすぐに出す。
	# それより前のレベルの分はもう済んだことにする（ボスの出現順は、上の bosses_spawned で合わせてある）
	milestone_level = level - 1
	if level % BOSS_EVERY == 0:
		bosses_spawned -= 3 if level >= TRIPLE_BOSS_FROM else (2 if level >= DOUBLE_BOSS_FROM else 1)
	_next_bishop = (floorf(elapsed / BISHOP_EVERY) + 1.0) * BISHOP_EVERY
	_next_wave = (floorf(elapsed / 50.0) + 1.0) * 50.0
	_next_ironclad = (floorf(elapsed / IRONCLAD_EVERY) + 1.0) * IRONCLAD_EVERY
	_next_ironclad_late = -1.0
	# 強化は、取る前の強化（req）がそろう順に、レベル1から順番に入れる
	var want: Dictionary = cfg["levels"]
	for u in Upgrades.LIST + Upgrades.SPECIAL:
		if u.has("req") and not want.has(u["req"]) and want.has(u["id"]):
			want[u["req"]] = 1
		if want.has(u["id"]):
			for r in u.get("req_all", []):
				if not want.has(r):
					want[r] = 1
	for u in Upgrades.LIST + Upgrades.SPECIAL:
		var id: String = u["id"]
		for lv in range(1, int(want.get(id, 0)) + 1):
			upgrade_levels[id] = lv
			Upgrades.apply(id, lv, self)
	hud.show_notice("デバッグ：%02d:%02d・Lv%d で出撃" % [int(elapsed) / 60, int(elapsed) % 60, level])
	# Lv OVERTIME_FROM_LV 以上で出撃したら、170overtime はこの時刻から始まる
	overtime_start = -1.0
	_check_overtime()
	# 始めるレベルの Lv刻みの敵（ボス・迫撃砲部隊）
	_spawn_level_milestone()
	hud.refresh()


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## ゲームオーバー画面の「もう一度」：オート選択の有効・無効はそのままでやり直す
func retry() -> void:
	_retry_auto_pick = auto_pick
	restart()
