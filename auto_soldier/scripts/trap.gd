extends Node2D
## 工兵部隊が仕掛ける罠。
## bomb（爆弾）：近くに敵が来たら1秒後に爆発して範囲ダメージ。
## pit（落とし穴）：近くに敵が来たら1秒後に作動して範囲ダメージ＋範囲内の敵を10秒間動けなくする。
## どちらも1回作動したら消える。

const TRIGGER_RADIUS := 60.0
const FUSE := 1.0

var game: Node2D
var kind := "bomb"
var damage := 100.0
var blast_radius := 110.0
var stun_time := 10.0

var _fuse_left := -1.0
var _t := 0.0
## 作動した落とし穴の跡を少しのあいだ表示する
var _hole_left := 0.0


func _ready() -> void:
	add_to_group("traps")
	if kind == "pit":
		damage = 50.0
		blast_radius = 90.0


func is_spent() -> bool:
	return _hole_left > 0.0


func _process(delta: float) -> void:
	_t += delta
	if _hole_left > 0.0:
		_hole_left -= delta
		if _hole_left <= 0.0:
			queue_free()
		queue_redraw()
		return
	if _fuse_left < 0.0:
		# 敵が近くに来たら作動開始
		for e in game.enemies_near(global_position, TRIGGER_RADIUS + 30.0):
			if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < TRIGGER_RADIUS + e.radius:
				_fuse_left = FUSE
				break
	else:
		_fuse_left -= delta
		if _fuse_left <= 0.0:
			_activate()
			return
	queue_redraw()


func _activate() -> void:
	for e in game.enemies_near(global_position, blast_radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - global_position
		if rel.length() > blast_radius + e.radius:
			continue
		if kind == "pit":
			e.stun(stun_time)
			e.take_damage(damage)
		else:
			e.take_damage(damage, rel.normalized() * 350.0)
	if kind == "pit":
		game.spawn_burst(global_position, Color(0.45, 0.32, 0.2), blast_radius / 2.2)
		remove_from_group("traps")
		_hole_left = 1.5
		queue_redraw()
	else:
		game.spawn_burst(global_position, Color(1.0, 0.45, 0.15), blast_radius / 2.2)
		game.spawn_burst(global_position, Color(1.0, 0.85, 0.3), blast_radius / 3.5)
		queue_free()


func _draw() -> void:
	var lit := _fuse_left >= 0.0 and int(_t * 12.0) % 2 == 0
	if kind == "bomb":
		draw_circle(Vector2(0, 4), 10.0, Color(0, 0, 0, 0.3))
		draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.3, 0.2) if lit else Color(0.18, 0.18, 0.2))
		draw_circle(Vector2(-3, -3), 3.0, Color(0.5, 0.5, 0.55))
		draw_line(Vector2(4, -8), Vector2(8, -14), Color(0.6, 0.5, 0.35), 2.0)
		if _fuse_left >= 0.0:
			draw_circle(Vector2(8, -14), 3.0, Color(1.0, 0.85, 0.3))
	else:
		if _hole_left > 0.0:
			draw_circle(Vector2.ZERO, 26.0, Color(0.12, 0.08, 0.05, 0.8 * minf(_hole_left, 1.0)))
			return
		# 地面に隠れた落とし穴（うっすら見える）
		var col := Color(1.0, 0.4, 0.3, 0.7) if lit else Color(0.5, 0.38, 0.22, 0.6)
		draw_circle(Vector2.ZERO, 18.0, col)
		for i in 4:
			var a := TAU * i / 4.0 + PI / 4.0
			draw_line(Vector2.from_angle(a) * 4.0, Vector2.from_angle(a) * 17.0, Color(0.35, 0.25, 0.12, 0.8), 2.0)
	# 作動範囲の目安
	if _fuse_left >= 0.0:
		draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, 40, Color(1.0, 0.5, 0.3, 0.5), 2.0)
