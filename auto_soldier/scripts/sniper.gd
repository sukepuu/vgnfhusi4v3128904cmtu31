extends Node2D

## 狙撃部隊（最大3人）。迎撃部隊の後ろ（城のすぐ上）に立ち、弓で遠くの敵を狙い撃つ。
## 一番近い「遠距離型の敵」（弓兵・迫撃砲）を優先して狙う。いなければ一番近い敵。
## 作業員と同じく敵からは狙われない。ステータスは game.sniper_stats を全員で共有している。

## 通常攻撃の矢の威力（以前は基本の2.1倍だったが、基本値に吸収）
## 爆裂矢の爆発の威力（矢の威力 × これ）
const BLAST_RATIO := 0.18
## 跳弾矢：跳ねたあとの矢の威力の倍率
const RICOCHET_MULT := 12.0
## 花火矢の花火の威力（攻撃力 × これ）
const FIREWORK_MULT := 11.52

const BulletScript := preload("res://scripts/bullet.gd")
## 遠距離型の敵の種類
const RANGED_KINDS := ["archer", "mortar"]

var game: Node2D
var index := 0
var dead := false
var record: Dictionary
var aim := Vector2.UP

var _cd := 0.5
var _draw_t := 0.0
var _volleys := 0


func _ready() -> void:
	record = game.new_record("sniper", "狙撃兵%d" % (index + 1))
	_cd = 0.4 * index


## 持ち場：迎撃部隊（城から140）より内側、城の屋根の上あたりに扇状に並ぶ
func post_position() -> Vector2:
	var n: int = game.snipers.size()
	var ang := PI + 0.7 + (PI - 1.4) * (index + 1) / (n + 1)
	return game.castle.global_position + Vector2.from_angle(ang) * 95.0


func _process(delta: float) -> void:
	var st = game.sniper_stats
	_cd -= delta * game.atk_speed_mult(record)
	_draw_t -= delta
	var target := _choose_target(st)
	# 狙える敵がいなければ、採掘場が空いていれば掘りに行く（敵が射程に入ったら持ち場へ戻る）
	var dest: Vector2 = post_position() if target != null else game.mine_spot(self, post_position())
	var to := dest - position
	if to.length() > 3.0:
		position += to.normalized() * minf(200.0 * game.mine_speed_mult(self) * delta, to.length())
	if target != null:
		aim = (target.global_position - global_position).normalized()
		if _cd <= 0.0:
			_cd = st.interval
			_shoot(target, st)
	queue_redraw()


func _choose_target(st) -> Node2D:
	var best: Node2D = null
	var best_d: float = st.fire_range
	var best_mortar: Node2D = null
	var best_mortar_d: float = st.fire_range
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead or not e.kind in RANGED_KINDS:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
		if e.kind == "mortar" and d < best_mortar_d:
			best_mortar_d = d
			best_mortar = e
	# 対砲兵狙撃：迫撃砲がいればそっちが最優先
	if st.counter_battery and best_mortar != null:
		return best_mortar
	if best != null:
		return best
	return game.nearest_enemy(global_position, st.fire_range)


func _shoot(target: Node2D, st) -> void:
	var dist: float = global_position.distance_to(target.global_position)
	for k in st.shots:
		# 矢は少しずつ横にずらして放つが、どれも狙った敵の真ん中へ向かう
		# （角度で広げると、遠くの小さい敵の左右をすり抜けてしまうため）
		var offset: Vector2 = aim.orthogonal() * (k - (st.shots - 1) / 2.0) * 7.0
		var dir: Vector2 = (target.global_position - (global_position + offset)).normalized()
		var b := BulletScript.new()
		b.game = game
		b.velocity = dir * st.arrow_speed
		# 通常攻撃の矢は、基本の威力の ARROW_MULT 倍（花火矢・天穿つ一矢は基本の威力から計算するので、この倍率は入らない）
		var dmg: float = st.attack_power
		# 対砲兵狙撃：遠い敵ほど痛い（100離れるごとに +10%）
		if st.counter_battery:
			dmg *= 1.0 + dist / 1000.0
		# 急所狙い：25%でダメージ4倍
		if st.headshot and randf() < 0.25:
			dmg *= 4.0
			b.crit = true
		b.damage = dmg
		b.pierce = st.pierce
		b.radius = 5.0 * st.arrow_scale
		b.bolt = true
		b.scale = Vector2(0.6, 0.6) * st.arrow_scale
		b.life = st.fire_range / st.arrow_speed + 0.3
		# 急所狙いは矢そのものを強くするだけなので、通常攻撃として数える
		b.src = record
		if st.bounces > 0:
			b.bounce_src = game.sp_src(record, "sp_ricochet")
			b.bounce_mult = RICOCHET_MULT
		b.stun_on_hit = 1.0 if st.pin else 0.0
		b.mark_on_hit = st.mark
		b.bounces = st.bounces
		b.bounce_target = target
		if st.blast_arrow:
			b.explode_radius = 70.0
			# 爆発は矢の BLAST_RATIO 倍。急所狙いの4倍は爆発には乗らない
			b.explode_ratio = BLAST_RATIO / 4.0 if b.crit else BLAST_RATIO
			b.explode_src = game.sp_src(record, "sp_blast_arrow")
			# 花火爆裂矢：爆裂矢が発動したとき、花火のエフェクトも出る
			b.explode_firework = st.firework_blast
		b.position = global_position + offset + dir * 12.0
		game.world.add_child(b)
	_draw_t = 0.15
	# 花火矢：毎回、狙った敵の所へ花火を打ち込む
	_volleys += 1
	if st.firework_arrow:
		var f: Node2D = game.spawn_fun_fx("firework", global_position)
		f.end = target.global_position
		f.rise_time = clampf(dist / 900.0, 0.2, 0.9)
		f.damage = st.attack_power * FIREWORK_MULT
		f.radius = 80.0
		f.src = game.sp_src(record, "sp_fun_firework_arrow")
		# 花火爆裂矢：花火が敵に当たったときも爆裂矢が発動（ふつうの矢の爆発と同じ威力）
		if st.firework_blast and st.blast_arrow:
			f.blast_damage = st.attack_power * BLAST_RATIO
			f.blast_radius = 70.0
			f.blast_src = game.sp_src(record, "sp_blast_arrow")


func _draw() -> void:
	draw_circle(Vector2(0, 7), 11.0, Color(0, 0, 0, 0.3))
	# 緑のフードの射手
	draw_circle(Vector2.ZERO, 11.0, Color(0.3, 0.5, 0.25))
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color(0.15, 0.25, 0.1), 2.0)
	draw_circle(-aim * 2.0, 6.0, Color(0.2, 0.35, 0.15))
	# 弓（引いているときは弦が後ろへ）
	var grip := aim * 12.0
	draw_arc(grip - aim * 6.0, 12.0, aim.angle() - 1.1, aim.angle() + 1.1, 12, Color(0.55, 0.35, 0.15), 3.0)
	var top := grip - aim * 6.0 + Vector2.from_angle(aim.angle() - 1.1) * 12.0
	var bottom := grip - aim * 6.0 + Vector2.from_angle(aim.angle() + 1.1) * 12.0
	var pull := grip - aim * (6.0 if _draw_t > 0.0 else 12.0)
	draw_line(top, pull, Color(0.9, 0.9, 0.85), 1.0)
	draw_line(pull, bottom, Color(0.9, 0.9, 0.85), 1.0)
	if _draw_t <= 0.0:
		# 次の矢をつがえている
		draw_line(pull, grip + aim * 4.0, Color(0.6, 0.45, 0.25), 2.0)
