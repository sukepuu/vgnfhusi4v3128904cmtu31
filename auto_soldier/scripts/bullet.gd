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

var _hit := {}


func _ready() -> void:
	if from_enemy:
		add_to_group("enemy_bullets")


func _process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if from_enemy:
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
			game.castle.take_damage(damage)
			queue_free()
		return
	for e in game.enemies_near(position, radius + 26.0):
		if not is_instance_valid(e) or e.dead or _hit.has(e):
			continue
		if global_position.distance_to(e.global_position) < radius + e.radius:
			e.take_damage(damage, velocity.normalized() * 120.0, src)
			if first_blast_radius > 0.0:
				game.explode(global_position, first_blast_radius, first_blast_damage, src, Color(1.0, 0.5, 0.2), 0.0, 300.0)
				first_blast_radius = 0.0
			if explode_radius > 0.0:
				game.explode(global_position, explode_radius, damage * explode_ratio, src, Color(1.0, 0.7, 0.3), 0.0, 120.0)
			_hit[e] = true
			if pierce <= 0:
				queue_free()
				return
			pierce -= 1


func _draw() -> void:
	if from_enemy:
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 1, 1, 0.8))
	elif wave:
		var a := velocity.angle()
		draw_arc(Vector2.ZERO, radius, a - 1.1, a + 1.1, 16, Color(color, 0.85), 5.0)
		draw_arc(Vector2(-4, 0).rotated(a), radius * 0.8, a - 0.9, a + 0.9, 12, Color(1, 1, 1, 0.5), 2.0)
	elif bolt:
		var dir := velocity.normalized()
		draw_line(-dir * 34.0, dir * 6.0, Color(0.45, 0.3, 0.15), 4.0)
		draw_colored_polygon(PackedVector2Array([
			dir * 16.0, dir * 4.0 + dir.orthogonal() * 6.0, dir * 4.0 - dir.orthogonal() * 6.0]), Color(0.85, 0.88, 0.95))
		draw_line(-dir * 34.0 + dir.orthogonal() * 5.0, -dir * 26.0, Color(0.9, 0.9, 0.85), 2.0)
		draw_line(-dir * 34.0 - dir.orthogonal() * 5.0, -dir * 26.0, Color(0.9, 0.9, 0.85), 2.0)
	else:
		var tail := -velocity.normalized() * 14.0
		draw_line(tail, Vector2.ZERO, Color(color, 0.5), radius * 1.2)
		draw_circle(Vector2.ZERO, radius * 0.8, color)
