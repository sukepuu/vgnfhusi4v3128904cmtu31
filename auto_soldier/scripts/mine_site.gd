extends Node2D
## 採掘場（城の兵装）。城の右側・壁の外に置かれる（第二採掘場を取ると、反対の左側にももう1つ）。敵からは狙われない。
## 手の空いた兵士（待機中で、ほかにやることがない兵士）が1か所に1人だけ掘りに来る（採掘兵は兵士より優先）。
## 掘っている間だけ時間が進み、interval 秒ごとに経験値を xp_amount ちょうど獲得する（経験値の倍率は入らない）。
## 兵士は待機中の処理で毎フレーム game.mine_spot() を呼ぶ。呼ばれなくなったら（敵が来た・仕事ができた）採掘をやめる。
## 1回掘れるたびに、取っている特別強化（岩のかけら・城の補修石・宝石の鉱脈・発破用の爆弾・もぐら）が発動する。

const BulletScript := preload("res://scripts/bullet.gd")
const TrapScript := preload("res://scripts/trap.gd")
const MineFxScript := preload("res://scripts/mine_fx.gd")

## 城から見た置き場所（壁の外、城の右側。左の採掘場は x を反対にする）
const OFFSET := Vector2(300, 25)
## 掘っている兵士が立つ場所（採掘場の城側）
const WORK_OFFSET := Vector2(-28, 2)
## この距離まで来ていれば「掘っている」とみなす
const WORK_DIST := 26.0
const ShardScript := preload("res://scripts/mine_shard.gd")
## 岩のかけら：狙う敵までの距離・飛ばす数・基本の威力（時間で上がる）
const SHARD_RANGE := 350.0
const SHARD_COUNT := 3
const SHARD_DAMAGE := 200.0
## 発破用の爆弾：基本の威力（時間で上がる）・範囲・採掘場が置いた爆弾の上限（全採掘場の合計）
const BOMB_DAMAGE := 200.0
const BOMB_RADIUS := 90.0
const MAX_BOMBS := 12
## 宝石の鉱脈：宝石が出る確率と、そのとき獲得する経験値
const GEM_CHANCE := 0.1
const GEM_XP := 10
const BOMB_CHANCE := 0.1
## 城の補修石：1回掘るごとに城が回復する量
const HEAL := 5.0
## もぐら：この回数掘るごとに1匹出る（採掘場ごとに数える）
const MOLE_EVERY := 3

var game: Node2D
## 0 = 右の採掘場、1 = 左の採掘場（第二採掘場）
var index := 0
## 採掘の間隔（秒）と、1回で獲得する経験値
var interval := 10.0
var xp_amount := 1
## 掘っている兵士（いなければ null）
var worker: Node2D = null
## 進み具合（0〜interval）。誰もいない間は止まる
var progress := 0.0
var mining := false
## 今までに掘れた回数
var mined := 0
## 特別強化のダメージを記録する戦績カード（「採掘場1」「採掘場2」）
var record: Dictionary
## テスト用：宝石・爆弾の確率を変えたいとき（負なら決まった確率）
var force_chance := -1.0

var _claim_frame := -100
var _t := 0.0
var _chips: Array = []
var _gem_fx := 0.0


func _ready() -> void:
	record = game.castle._equip_record("mine_site", "採掘場", index)


func _side() -> float:
	return 1.0 if index == 0 else -1.0


func work_spot() -> Vector2:
	return global_position + Vector2(WORK_OFFSET.x * _side(), WORK_OFFSET.y)


## unit がこの採掘場を使えるか（空いている・unit が使っている・force なら採掘兵以外から奪える）
func is_free_for(unit: Node2D, force: bool = false) -> bool:
	if worker == null or worker == unit or not _worker_ok() or Engine.get_process_frames() - _claim_frame > 2:
		return true
	return force and not worker.is_in_group("miners")


## unit が待機中に呼ぶ。使えれば unit が掘りに来る場所、ほかの兵士が掘っていれば home を返す
func claim(unit: Node2D, home: Vector2, force: bool = false) -> Vector2:
	if not is_free_for(unit, force):
		return home
	worker = unit
	_claim_frame = Engine.get_process_frames()
	return work_spot()


func _worker_ok() -> bool:
	if worker == null or not is_instance_valid(worker):
		return false
	if "dead" in worker and worker.dead:
		return false
	return true


func _process(delta: float) -> void:
	_t += delta
	_gem_fx -= delta
	# 待機中の処理から呼ばれなくなった兵士は、採掘をやめて離れる
	if worker != null and (not _worker_ok() or Engine.get_process_frames() - _claim_frame > 2):
		if is_instance_valid(worker):
			game.on_left_mine(worker)
		worker = null
	mining = worker != null and worker.global_position.distance_to(work_spot()) < WORK_DIST
	if mining:
		progress += delta
		if progress >= interval:
			progress -= interval
			_on_mined()
		# つるはしが当たるたびに石のかけらが飛ぶ
		if int(_t / 0.5) != int((_t - delta) / 0.5):
			for i in 3:
				_chips.append({"p": Vector2(-10, -4), "v": Vector2(randf_range(-30, 50), randf_range(-110, -50)), "t": 0.45})
	for c in _chips:
		c["t"] -= delta
		c["v"].y += 260.0 * delta
		c["p"] += c["v"] * delta
	_chips = _chips.filter(func(c: Dictionary) -> bool: return c["t"] > 0.0)
	queue_redraw()


func _chance(p: float) -> bool:
	return randf() < (force_chance if force_chance >= 0.0 else p)


func _time_mult() -> float:
	return 1.0 + game.elapsed / 120.0


## 1回掘れたとき
func _on_mined() -> void:
	mined += 1
	# 宝石の鉱脈：10%で宝石が出て、経験値が10になる
	var amount := xp_amount
	var gem: bool = game.mine_gem and _chance(GEM_CHANCE)
	if gem:
		amount = GEM_XP
		_gem_fx = 1.0
		game.spawn_burst(global_position + Vector2(0, -10), Color(1.0, 0.6, 0.95), 40.0)
	game.add_raw_xp(amount)
	# 部隊戦績：この採掘場で稼いだ経験値
	record["xp"] = int(record.get("xp", 0)) + amount
	game.spawn_text(global_position + Vector2(0, -34), "+%d EXP" % amount, Color(1.0, 0.6, 1.0) if gem else Color(0.6, 1.0, 0.95), 20 if gem else 16)
	# 城の補修石：城のHPを5回復
	if game.mine_heal:
		game.castle.heal(HEAL, record, "sp_mine_heal")
	if game.mine_shards:
		_throw_shards()
	if game.mine_bomb and _chance(BOMB_CHANCE):
		place_bomb(global_position + Vector2.from_angle(randf() * TAU) * randf_range(50.0, 110.0))
	# もぐら：3回掘るごとに1匹
	if game.mine_mole and mined % MOLE_EVERY == 0:
		var m := MineFxScript.new()
		m.game = game
		m.kind = "mole"
		m.mine = self
		m.position = global_position + Vector2(0, 10)
		game.ground.add_child(m)


## 岩のかけら：近くの敵（最大3体）へ岩のかけらを飛ばす
func _throw_shards() -> void:
	var near: Array = []
	for e in game.enemies_near(global_position, SHARD_RANGE):
		if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < SHARD_RANGE:
			near.append(e)
	near.sort_custom(func(a: Node2D, b: Node2D) -> bool: return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	var dmg := SHARD_DAMAGE * _time_mult()
	for i in mini(SHARD_COUNT, near.size()):
		var e: Node2D = near[i]
		# 投げた時の敵の位置へ山なりに飛ぶ。外れたらその場に残り、触れた敵に当たる
		var r := ShardScript.new()
		r.game = game
		r.start = global_position + Vector2(0, -12)
		r.target = e.global_position
		r.damage = dmg
		r.src = game.sp_src(record, "sp_mine_shards")
		game.world.add_child(r)


## 発破用の爆弾を置く（もぐら爆弾でも使う。記録はどちらも「発破用の爆弾」）
func place_bomb(pos: Vector2) -> void:
	if game.get_tree().get_nodes_in_group("mine_bombs").size() >= MAX_BOMBS:
		return
	var b := TrapScript.new()
	b.game = game
	b.kind = "bomb"
	b.from_cannon = true
	b.fixed_damage = BOMB_DAMAGE * _time_mult()
	b.fixed_radius = BOMB_RADIUS
	b.src = game.sp_src(record, "sp_mine_bomb")
	b.position = game.clamp_to_map(pos, 20.0)
	b.add_to_group("mine_bombs")
	game.ground.add_child(b)


func _draw() -> void:
	var s := _side()
	# 地面のくぼみ
	draw_circle(Vector2(0, 8), 26.0, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(0, 4), 24.0, Color(0.32, 0.27, 0.2))
	# 岩山
	var rock := PackedVector2Array([Vector2(-22, 10), Vector2(-16, -10), Vector2(-4, -20), Vector2(10, -16), Vector2(22, -2), Vector2(20, 10)])
	draw_colored_polygon(rock, Color(0.5, 0.48, 0.45))
	draw_polyline(rock + PackedVector2Array([rock[0]]), Color(0.28, 0.26, 0.24), 2.0)
	draw_line(Vector2(-4, -20), Vector2(0, -2), Color(0.38, 0.36, 0.34), 2.0)
	draw_line(Vector2(0, -2), Vector2(14, 4), Color(0.38, 0.36, 0.34), 2.0)
	# 鉱石（きらっと光る）
	var glow := 0.75 + 0.25 * sin(_t * 3.0)
	for p in [Vector2(-10, -4), Vector2(6, -10), Vector2(12, 4)]:
		draw_circle(p, 3.5, Color(0.45 * glow, 0.95 * glow, 1.0 * glow))
	# 宝石が出たとき：ピンクの宝石がきらきら浮かぶ
	if _gem_fx > 0.0:
		var gp := Vector2(0, -30 - (1.0 - _gem_fx) * 20.0)
		var a := clampf(_gem_fx * 2.0, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -9), gp + Vector2(7, 0), gp + Vector2(0, 9), gp + Vector2(-7, 0)]), Color(1.0, 0.45, 0.85, a))
		for i in 4:
			var d := Vector2.from_angle(_t * 4.0 + i * PI / 2.0) * 13.0
			draw_line(gp + d * 0.7, gp + d, Color(1, 1, 1, a), 2.0)
	# 立てかけたつるはし（誰もいないとき）／掘っているときは振り下ろす
	var swing := sin(_t * 12.0) * 0.6 if mining else 0.0
	var base := Vector2(WORK_OFFSET.x * s + 6.0 * s, WORK_OFFSET.y - 4.0)
	var dir := Vector2.from_angle(-PI * 0.75 + swing)
	if s < 0.0:
		dir.x = -dir.x
	if not mining:
		base = Vector2(20 * s, -18)
		dir = Vector2.from_angle(-PI * 0.6)
		dir.x *= s
	var head := base + dir * 18.0
	draw_line(base, head, Color(0.55, 0.38, 0.2), 3.0)
	draw_line(head + dir.orthogonal() * 8.0, head - dir.orthogonal() * 8.0, Color(0.7, 0.72, 0.78), 3.0)
	for c in _chips:
		draw_circle(Vector2(c["p"].x * s, c["p"].y), 2.0, Color(0.6, 0.58, 0.55, clampf(c["t"] / 0.45, 0.0, 1.0)))
	# 採掘完了までのメーター（採掘場の上・横向きの黄色）。掘るのを中断しても、たまった分はそのまま残る
	var k := clampf(progress / interval, 0.0, 1.0)
	var bar := Rect2(Vector2(-24, -34), Vector2(48, 6))
	draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color(1.0, 0.85, 0.15))
	draw_rect(bar.grow(1.0), Color(0.35, 0.3, 0.1), false, 1.0)
