extends Node2D
## 弾（味方・敵共通）

var game: Node2D
var velocity := Vector2.ZERO
var damage := 10.0
var pierce := 0
var radius := 5.0
var from_enemy := false
## 敵の弾：撃った敵の名前（被害状況の記録用）
var from_name := ""
## ボスの弾：味方でも壁でも、BOSS_HITS 回当たるまで突き抜けて飛ぶ（例：壁＋迎撃兵で消える。城に当たったら消える）
var boss_pierce := false
const BOSS_HITS := 2
var _boss_hits_left := BOSS_HITS
var _hit_walls := {}
## 壁を素通りする（黒衣の大司教が号令で撃つ、貫通無限の弾）
var ignore_walls := false
var color := Color(1, 1, 0.5)
var life := 1.0
## true ならバリスタの矢（太く長く描く）
var bolt := false
## 撃った味方の戦績カード
var src: Dictionary = {}
## 当たったときに小爆発する（炸裂弾・爆裂ボルト）。0なら爆発しない
var explode_radius := 0.0
var explode_ratio := 0.0
## 爆発・最初の大爆発だけ別の戦績カードに記録したいとき（特別強化の分け記録）。空なら src
var explode_src: Dictionary = {}
## 爆発したとき、花火のエフェクトも出す（花火爆裂矢）
var explode_firework := false
var first_blast_src: Dictionary = {}
## 矢倉・追尾の矢：飛んでいる途中で一度だけ、一番近い敵へ向きを変える
var homing := false
var _homed := false
## 当たった敵の移動速度を、この秒数だけ40%下げる（影縫い・減速ボルト）
var slow_on_hit := 0.0
## 弓兵の矢（近城の矢・追い討ちの威力アップがかかる）
var archer_hit := false
## 連携射撃：当たった敵に連携マークを付ける。ほかの弓兵のマークが付いた敵には+60%
var link_mark := false
## 竜巻矢：当たった所に竜巻ができる
var tornado_on_hit := false
## 連射砲・強敵狙い：当たった敵の残りHPの割合が多いほど威力アップ（最大+50%）
var hp_scale := false
## 連射砲・弱点付与：当たった敵の被ダメージを5秒間 +15%
var debuff_on_hit := false
## 撃った敵（敵の弾のとき。追い討ちで、HPが半分以下の敵の弾を受けないため）
var shooter: Node2D = null
## 跳ねたあとのダメージを記録する戦績カード（跳弾矢の分け記録）。空なら src のまま
var bounce_src: Dictionary = {}
## 跳弾矢：最初に跳ねたとき、矢の威力をこの倍率にする（跳ねたあとの命中と爆発が強くなる）
var bounce_mult := 1.0
var _bounced := false
## true なら剣気の衝撃波（三日月形に描く）
var wave := false
## 炸裂大矢：最初に当たった敵の場所で大爆発（0なら無し）
var first_blast_radius := 0.0
var first_blast_damage := 0.0
## 敵の弾が城に当たったときのダメージ倍率（ボスの弾幕は城には弱め）
var castle_ratio := 1.0
## ボスが撃った弾（序盤は城へのダメージが半分）
var from_boss := false
## キャラクター狙いの誘導弾：城には当たらず、すり抜ける
var no_castle := false
## 徹甲榴弾：この敵だけを追いかけて当たる（ほかの敵はすり抜ける）。null なら普通の弾
var only_target: Node2D = null
## この敵を追いかけて飛ぶ（当たり判定はほかの敵にもある）。当たったら追いかけるのをやめてまっすぐ飛ぶ
var aim_target: Node2D = null
## 誘導砲兵の誘導弾：この味方を追いかける（倒れたらまっすぐ飛ぶ）
var seek: Node2D = null
## 狙撃部隊の特別強化：当たった敵を動けなくする秒数・弱点看破・跳ねる回数・会心（見た目用）
var stun_on_hit := 0.0
var mark_on_hit := false
var bounces := 0
## 跳弾矢：この敵（狙った敵）に当たったときだけ跳ねる。跳ねた先の敵が次の「狙った敵」になる
var bounce_target: Node2D = null
var crit := false
## 修理玉の弾（水色の大きな玉として描く。半透明じゃない）
var orb := false
## 神槍投擲の巨大な槍の見た目
var spear := false
## 当たるたびに威力が増える割合（破竹の大矢：0.1 で +10%ずつ）
var grow_on_hit := 0.0
## 当たるたびに増えた倍率（撃ったときの威力の2倍＝+100%で止まる）
const GROW_MAX := 2.0
var _grow_mult := 1.0
## 雪だるま合戦（結界の条件付き強化）：当たった所に雪だるまを置く
var drop_snowman := false
## 虹の矢（バリスタのおもしろ強化）：虹色の尾＋当たった敵が混乱する秒数
var rainbow := false
var confuse_on_hit := 0.0

var _hit := {}


func _ready() -> void:
	if from_enemy:
		add_to_group("enemy_bullets")


func _process(delta: float) -> void:
	if not from_enemy:
		_step(delta)
		return
	# 敵の弾が当たったダメージは、撃った敵のものとして被害状況に記録する
	game.dmg_from = from_name
	game.dmg_attacker = shooter if is_instance_valid(shooter) else null
	_step(delta)
	game.dmg_from = ""
	game.dmg_attacker = null


func _step(delta: float) -> void:
	if homing and not _homed and not from_enemy:
		var nearest: Node2D = null
		var best_d := 280.0
		for e in game.enemies_cache:
			if not is_instance_valid(e) or e.dead:
				continue
			var d := global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				nearest = e
		if nearest != null:
			velocity = (nearest.global_position - global_position).normalized() * velocity.length()
		_homed = true
	if seek != null:
		if is_instance_valid(seek) and not seek.dead:
			var want := (seek.global_position - global_position).normalized() * velocity.length()
			# 誘導砲兵の弾は、しつこく曲がって追いかける
			velocity = velocity.lerp(want, clampf(6.0 * delta, 0.0, 1.0)).normalized() * velocity.length()
		else:
			seek = null
	if only_target != null:
		if is_instance_valid(only_target) and not only_target.dead:
			# 狙った敵が動いても外れないように、まっすぐ追いかける
			velocity = (only_target.global_position - global_position).normalized() * velocity.length()
		else:
			# 先に倒されたら、そこから先は普通の弾として飛ぶ
			only_target = null
	if aim_target != null:
		if is_instance_valid(aim_target) and not aim_target.dead and not _hit.has(aim_target):
			velocity = (aim_target.global_position - global_position).normalized() * velocity.length()
		else:
			aim_target = null
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if from_enemy:
		# 鉄壁の陣（迎撃部隊の必殺）のドームに入った敵の弾は消える
		if game.ultimates.dome_blocks(global_position):
			game.spawn_burst(global_position, Color(0.6, 1.0, 0.7), 10.0)
			queue_free()
			return
		for s in game.hittables():
			if not s.dead and not _hit.has(s) and global_position.distance_to(s.global_position) < radius + s.radius:
				# 弾が飛んできた方向を渡す（迎撃部隊の盾の判定用）
				s.take_damage(damage, global_position - velocity.normalized() * 30.0)
				# ボスの弾は、2回当たるまで突き抜ける（味方・壁どちらに当たっても1回）
				if boss_pierce:
					_boss_hits_left -= 1
				if boss_pierce and _boss_hits_left > 0:
					_hit[s] = true
					# 追いかけていた相手に当たったら、そこからはまっすぐ飛ぶ
					if seek == s:
						seek = null
					continue
				queue_free()
				return
		var wi: int = -1 if ignore_walls else game.walls.hit_test(global_position, radius)
		if wi >= 0 and not _hit_walls.has(wi):
			# 壁が1発分防ぐ
			game.walls.absorb(wi, global_position)
			# 反撃壁：防いだ場所から、敵へ弾を撃ち返す
			if game.walls.counter:
				game.walls.counter_shot(global_position)
			if boss_pierce:
				_boss_hits_left -= 1
				if _boss_hits_left > 0:
					_hit_walls[wi] = true
					return
			queue_free()
			return
		if not no_castle and game.castle.distance_to_point(global_position) < radius:
			if castle_ratio > 0.0:
				game.castle.take_damage(damage * castle_ratio, from_boss)
			queue_free()
		return
	for e in game.enemies_near(position, radius + 26.0):
		if not is_instance_valid(e) or e.dead or _hit.has(e):
			continue
		if only_target != null and e != only_target:
			continue
		if global_position.distance_to(e.global_position) < radius + e.radius:
			if stun_on_hit > 0.0:
				e.stun(stun_on_hit)
			if mark_on_hit:
				e.mark_left = 6.0
			if confuse_on_hit > 0.0:
				e.confuse(confuse_on_hit)
			if slow_on_hit > 0.0:
				e.slow(slow_on_hit, 0.4)
			if tornado_on_hit:
				game.spawn_tornado(global_position, 1.0)
			# 当たった敵によって変わる威力アップは、この1回だけにかける（貫通した次の敵には持ち越さない）
			var dmg := damage
			if hp_scale and e.max_hp > 0.0:
				dmg *= 1.0 + 0.5 * clampf(e.hp / e.max_hp, 0.0, 1.0)
			if debuff_on_hit:
				e.debuff_left = 5.0
				e.debuff_mult = 1.15
			if archer_hit:
				# 近城の矢：城に近い敵ほど痛い（城から100以内で+60%、800離れると+0%）
				if game.archer_close:
					var d: float = game.castle.distance_to_point(e.global_position)
					dmg *= 1.0 + 0.6 * clampf(1.0 - (d - 100.0) / 700.0, 0.0, 1.0)
				# 追い討ち：HPが半分以下の敵には+30%
				if game.archer_execute and e.hp <= e.max_hp * 0.5:
					dmg *= 1.3
			if link_mark:
				# 連携射撃：ほかの弓兵が付けたマークの敵なら+60%。当てた敵には自分のマークを付ける
				var me: int = int(src.get("rec_idx", src.get("idx", -1)))
				if e.link_left > 0.0 and e.link_archer != me:
					dmg *= 1.6
				e.link_archer = me
				e.link_left = 5.0
			e.take_damage(dmg, Vector2.ZERO, src)
			# 射撃のノックバック（下側へは押さない。クールタイムは敵側で管理）
			e.shot_knockback(velocity.normalized() * 120.0)
			if first_blast_radius > 0.0:
				game.explode(global_position, first_blast_radius, first_blast_damage, src if first_blast_src.is_empty() else first_blast_src, Color(1.0, 0.5, 0.2), 0.0, 300.0)
				first_blast_radius = 0.0
			if explode_radius > 0.0:
				game.explode(global_position, explode_radius, damage * explode_ratio, src if explode_src.is_empty() else explode_src, Color(1.0, 0.7, 0.3), 0.0, 120.0)
				if explode_firework:
					var fw: Node2D = game.spawn_fun_fx("firework", global_position)
					fw.rise_time = 0.01
			_hit[e] = true
			if drop_snowman:
				drop_snowman = false
				# 置きすぎないように、雪だるまは全部で18体まで
				if game.get_tree().get_nodes_in_group("placed_snowman").size() < 18:
					game.spawn_placed("snowman", global_position, 18.75 * (1.0 + game.elapsed / 120.0), 40.0, 10.0,
						game.sp_src(game.castle._equip_record("frost", "氷結の結界", 0), "sp_snowman"))
			if grow_on_hit > 0.0:
				var nm: float = minf(_grow_mult * (1.0 + grow_on_hit), GROW_MAX)
				damage *= nm / _grow_mult
				_grow_mult = nm
			# 跳弾矢：狙った敵に当たったら、近くの別の敵へ跳ねる（跳ねたあとは bounce_mult 倍）
			# 途中で当たったほかの敵は、ふつうに貫通するだけ
			if bounces > 0 and is_instance_valid(bounce_target) and e == bounce_target:
				var next := _bounce_target(e)
				if next != null:
					bounces -= 1
					bounce_target = next
					if not _bounced:
						_bounced = true
						damage *= bounce_mult
					if not bounce_src.is_empty():
						src = bounce_src
					velocity = (next.global_position - global_position).normalized() * velocity.length()
					life = maxf(life, 0.5)
					continue
			if pierce <= 0:
				queue_free()
				return
			pierce -= 1


func _bounce_target(from_e: Node2D) -> Node2D:
	var best: Node2D = null
	var best_d := 260.0
	for o in game.enemies_near(global_position, 260.0):
		if o == from_e or not is_instance_valid(o) or o.dead or _hit.has(o):
			continue
		var d: float = global_position.distance_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best


func _draw() -> void:
	if from_enemy and seek != null:
		# 誘導弾：炎の尾を引くミサイル
		var dir := velocity.normalized()
		for i in 4:
			draw_circle(-dir * (8.0 + i * 6.0), 5.0 - i, Color(1.0, 0.6 - i * 0.1, 0.1, 0.6 - i * 0.12))
		draw_line(-dir * 8.0, dir * 8.0, Color(0.35, 0.35, 0.38), 6.0)
		draw_circle(dir * 8.0, 3.5, Color(1.0, 0.3, 0.2))
	elif from_enemy:
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 1, 1, 0.8))
	elif orb:
		draw_circle(Vector2.ZERO, radius * 1.35, Color(color, 0.18))
		draw_circle(Vector2.ZERO, radius * 1.15, Color(color, 0.3))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.6, Color(0.75, 0.98, 1.0))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.85, 1.0, 1.0), 3.0)
		draw_circle(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.22, Color(1, 1, 1))
	elif spear:
		# 巨大な槍（柄・穂先・房飾り）。radius が大きいほど長く太い
		var dir := velocity.normalized()
		var side := dir.orthogonal()
		var shaft := radius * 3.2
		draw_line(-dir * shaft, dir * radius * 0.6, Color(0.5, 0.33, 0.16), radius * 0.35)
		draw_colored_polygon(PackedVector2Array([dir * radius * 1.6, dir * radius * 0.4 + side * radius * 0.55,
			dir * radius * 0.6, dir * radius * 0.4 - side * radius * 0.55]), Color(0.88, 0.92, 1.0))
		draw_colored_polygon(PackedVector2Array([dir * radius * 1.6, dir * radius * 0.4 + side * radius * 0.25,
			dir * radius * 0.4 - side * radius * 0.25]), Color(1.0, 1.0, 1.0, 0.7))
		draw_circle(dir * radius * 0.3, radius * 0.22, Color(0.85, 0.2, 0.2))
		draw_circle(Vector2.ZERO, radius * 1.2, Color(0.7, 1.0, 0.75, 0.12))
	elif wave:
		var a := velocity.angle()
		draw_arc(Vector2.ZERO, radius, a - 1.1, a + 1.1, 16, Color(color, 0.85), 5.0)
		draw_arc(Vector2(-4, 0).rotated(a), radius * 0.8, a - 0.9, a + 0.9, 12, Color(1, 1, 1, 0.5), 2.0)
	elif bolt:
		var dir := velocity.normalized()
		if rainbow:
			# 虹色の尾
			var side := dir.orthogonal()
			for i in 6:
				var off := side * (i - 2.5) * 3.0
				draw_line(off - dir * 34.0, off - dir * 130.0, Color.from_hsv(i / 6.0, 0.8, 1.0, 0.6), 3.0)
		draw_line(-dir * 34.0, dir * 6.0, Color(0.45, 0.3, 0.15), 4.0)
		draw_colored_polygon(PackedVector2Array([
			dir * 16.0, dir * 4.0 + dir.orthogonal() * 6.0, dir * 4.0 - dir.orthogonal() * 6.0]), Color(0.85, 0.88, 0.95))
		draw_line(-dir * 34.0 + dir.orthogonal() * 5.0, -dir * 26.0, Color(0.9, 0.9, 0.85), 2.0)
		draw_line(-dir * 34.0 - dir.orthogonal() * 5.0, -dir * 26.0, Color(0.9, 0.9, 0.85), 2.0)
		if crit:
			draw_circle(dir * 10.0, 7.0, Color(1.0, 0.3, 0.2, 0.7))
	else:
		var tail := -velocity.normalized() * 14.0
		draw_line(tail, Vector2.ZERO, Color(color, 0.5), radius * 1.2)
		draw_circle(Vector2.ZERO, radius * 0.8, color)
