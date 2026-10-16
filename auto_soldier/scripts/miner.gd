extends Node2D
## 採掘兵（採掘場の特別強化）。採掘だけをする作業員で、戦わない。敵からも狙われない。
## 空いている採掘場（右を優先）に入って掘り続ける。ほかの兵士が掘っている採掘場には、交代して入れる。

const SPEED := 120.0

var game: Node2D
var index := 0
var _t := 0.0
var _facing := Vector2.RIGHT
## 今掘っている（掘りに向かっている）採掘場
var _mine: Node2D = null


func _ready() -> void:
	add_to_group("miners")


func _process(delta: float) -> void:
	_t += delta
	var home: Vector2 = game.castle.gate_position() + Vector2(0.0, 30.0 + index * 20.0)
	# 自分の採掘場があればそこ。なければ空いている採掘場（右優先）→ 兵士が掘っている採掘場（交代してもらう）
	if _mine == null or not _mine.is_free_for(self):
		_mine = null
		for force in [false, true]:
			for m in game.mine_sites:
				if m.is_free_for(self, force):
					_mine = m
					break
			if _mine != null:
				break
	var dest := home
	if _mine != null:
		dest = _mine.claim(self, home, true)
	var to := dest - position
	var d := to.length()
	if d > 3.0:
		_facing = to / d
		position += _facing * minf(SPEED * game.mine_speed_mult(self) * delta, d)
	elif _mine != null:
		_facing = (_mine.global_position - global_position).normalized()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 6), 10.0, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, 10.0, Color(0.6, 0.45, 0.3))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, Color(0.3, 0.2, 0.12), 2.0)
	# ヘルメットとライト
	draw_circle(-_facing * 2.0, 6.5, Color(0.95, 0.8, 0.2))
	draw_circle(_facing * 4.0, 2.5, Color(1.0, 1.0, 0.75))
	# つるはし（掘っているときは振る）
	var working: bool = _mine != null and _mine.mining and _mine.worker == self
	var ang := _facing.angle() + (sin(_t * 12.0) * 0.8 if working else 0.6)
	var side := _facing.orthogonal() * 7.0
	var dir := Vector2.from_angle(ang)
	var head := side + dir * 16.0
	draw_line(side, head, Color(0.55, 0.38, 0.2), 3.0)
	draw_line(head + dir.orthogonal() * 7.0, head - dir.orthogonal() * 7.0, Color(0.7, 0.72, 0.78), 3.0)
