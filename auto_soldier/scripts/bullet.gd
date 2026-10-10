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
		var s: Node2D = game.soldier
		if not s.dead and global_position.distance_to(s.global_position) < radius + s.radius:
			s.take_damage(damage)
			queue_free()
		return
	for e in game.enemies_near(position, radius + 26.0):
		if not is_instance_valid(e) or e.dead or _hit.has(e):
			continue
		if global_position.distance_to(e.global_position) < radius + e.radius:
			e.take_damage(damage, velocity.normalized() * 120.0)
			_hit[e] = true
			if pierce <= 0:
				queue_free()
				return
			pierce -= 1


func _draw() -> void:
	if from_enemy:
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 1, 1, 0.8))
	else:
		var tail := -velocity.normalized() * 14.0
		draw_line(tail, Vector2.ZERO, Color(color, 0.5), radius * 1.2)
		draw_circle(Vector2.ZERO, radius * 0.8, color)
