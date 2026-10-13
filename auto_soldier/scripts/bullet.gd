extends Node2D
## 弾（味方・敵共通）

var game: Node2D
var velocity := Vector2.ZERO
var damage := 10.0
var pierce := 0
var radius := 5.0
var from_enemy := false
var color := Color(1, 1, 0.5)
var life := 1.0
## true ならバリスタの矢（太く長く描く）
var bolt := false
## 撃った味方の戦績カード
var src: Dictionary = {}
## 当たったときに小爆発する（炸裂弾・爆裂ボルト）。0なら爆発しない
var explode_radius := 0.0
var explode_ratio := 0.0
## true なら剣気の衝撃波（三日月形に描く）
var wave := false
## 炸裂大矢：最初に当たった敵の場所で大爆発（0なら無し）
var first_blast_radius := 0.0
var first_blast_damage := 0.0
## 敵の弾が城に当たったときのダメージ倍率（ボスの弾幕は城には弱め）
var castle_ratio := 1.0
## 徹甲榴弾：この敵だけを追いかけて当たる（ほかの敵はすり抜ける）。null なら普通の弾
var only_target: Node2D = null
## 追尾ペット弾：近くの敵の方へ少しずつ曲がる
var homing := false
## 誘導砲兵の誘導弾：この味方を追いかける（倒れたらまっすぐ飛ぶ）
var seek: Node2D = null
## 狙撃部隊の特別強化：当たった敵を動けなくする秒数・弱点看破・跳ねる回数・会心（見た目用）
var stun_on_hit := 0.0
var mark_on_hit := false
var bounces := 0
## 跳弾矢：この敵（狙った敵）に当たったときだけ跳ねる。跳ねた先の敵が次の「狙った敵」になる
var bounce_target: Node2D = null
var crit := false
## 虹の矢（バリスタのおもしろ強化）：虹色の尾＋当たった敵が混乱する秒数
var rainbow := false
var confuse_on_hit := 0.0

var _hit := {}


func _ready() -> void:
	if from_enemy:
		add_to_group("enemy_bullets")


func _process(delta: float) -> void:
	if seek != null:
		if is_instance_valid(seek) and not seek.dead:
			var want := (seek.global_position - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(want, clampf(2.5 * delta, 0.0, 1.0)).normalized() * velocity.length()
		else:
			seek = null
	if homing and not from_enemy:
		var near: Node2D = game.nearest_enemy(global_position, 260.0)
		if near != null:
			var want := (near.global_position - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(want, clampf(5.0 * delta, 0.0, 1.0)).normalized() * velocity.length()
	if only_target != null:
		if is_instance_valid(only_target) and not only_target.dead:
			# 狙った敵が動いても外れないように、まっすぐ追いかける
			velocity = (only_target.global_position - global_position).normalized() * velocity.length()
		else:
			# 先に倒されたら、そこから先は普通の弾として飛ぶ
			only_target = null
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
		for s in game.allies():
			if not s.dead and global_position.distance_to(s.global_position) < radius + s.radius:
				# 弾が飛んできた方向を渡す（迎撃部隊の盾の判定用）
				s.take_damage(damage, global_position - velocity.normalized() * 30.0)
				queue_free()
				return
		var wi: int = game.walls.hit_test(global_position, radius)
		if wi >= 0:
			# 壁が1発分防ぐ
			game.walls.absorb(wi, global_position)
			queue_free()
			return
		if game.castle.distance_to_point(global_position) < radius:
			game.castle.take_damage(damage * castle_ratio)
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
			e.take_damage(damage, velocity.normalized() * 120.0, src)
			if first_blast_radius > 0.0:
				game.explode(global_position, first_blast_radius, first_blast_damage, src, Color(1.0, 0.5, 0.2), 0.0, 300.0)
				first_blast_radius = 0.0
			if explode_radius > 0.0:
				game.explode(global_position, explode_radius, damage * explode_ratio, src, Color(1.0, 0.7, 0.3), 0.0, 120.0)
			_hit[e] = true
			# 跳弾矢：狙った敵に当たったら、近くの別の敵へ跳ねる（威力は7割に）
			# 途中で当たったほかの敵は、ふつうに貫通するだけ
			if bounces > 0 and is_instance_valid(bounce_target) and e == bounce_target:
				var next := _bounce_target(e)
				if next != null:
					bounces -= 1
					damage *= 0.7
					bounce_target = next
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
