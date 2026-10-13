extends Node2D
## 特別強化で設置される、いろいろな物。
## spikes    ：迎撃兵の拒馬の柵。上にいる敵にダメージを与え続け、足を止める
## watchtower：築城兵の見張り櫓。ずっと残り、近くの敵へ矢を撃つ
## sentry    ：工兵の自動砲台。しばらくのあいだ近くの敵を連射する
## mine      ：大砲の機雷。敵が触れると爆発
## snowman   ：結界の雪だるま。敵が近づくと爆発して周りを凍らせる
## scarecrow ：工兵のかかし。敵の気を引いて、代わりに殴られてくれる
## boulder   ：投石器の居座り岩。上にいる敵にダメージを与え続け、足を30%遅くする
## repair_orb：修理玉。置いてから10秒間に城が回復した量をためて、最後にHPが一番多い敵へ撃つ
## automaton ：工兵の巨大からくり兵。ゆっくり歩き、全方位斬り→高速連射をくり返す。消えるときに大爆発
## 見張り櫓とかかしには耐久があり、敵に攻撃される（味方と同じあつかい）

const BulletScript := preload("res://scripts/bullet.gd")
const SlashScript := preload("res://scripts/slash_effect.gd")

var game: Node2D
var kind := "spikes"
var damage := 20.0
var radius := 50.0
## 残り時間（0以下ならずっと残る）
var life := 10.0
var src: Dictionary = {}

var _t := 0.0
var _cd := 0.0
var _aim := Vector2.UP
var _forever := false
## からくり兵：今の動き（"slash" 全方位斬り / "fire" 高速連射）と、その残り回数
var _mode := "slash"
var _mode_count := 0
var _gear := 0.0
## 修理玉：置いたときの「城の回復量の合計」（ここからの増えた分がたまった量）
var _heal_start := 0.0
## 耐久（見張り櫓・かかしだけ。0になったら壊れる）
var hp := 0.0
var max_hp := 0.0
var dead := false
var _hurt := 0.0
## 耐久を持つ物の耐久
const DURABILITY := {"watchtower": 50.0, "scarecrow": 60.0}
## 修理玉の大きさ（ボスの半径46の7割くらい）
const ORB_RADIUS := 32.0


func _ready() -> void:
	add_to_group("placed_" + kind)
	_forever = life <= 0.0
	if kind == "repair_orb":
		_heal_start = game.castle.healed_total
	if DURABILITY.has(kind):
		# 敵から味方として狙われる
		max_hp = DURABILITY[kind]
		hp = max_hp
		radius = 16.0
		add_to_group("attackable")
	_cd = randf() * 0.5


func _process(delta: float) -> void:
	_t += delta
	_cd -= delta
	_hurt -= delta
	if not _forever:
		life -= delta
		if life <= 0.0:
			if kind == "repair_orb":
				_fire_orb()
			if kind == "automaton":
				# 消えるときに大爆発
				game.explode(global_position, 170.0, damage * 1.5, src, Color(1.0, 0.6, 0.2), 0.0, 450.0)
				game.spawn_burst(global_position, Color(1.0, 0.9, 0.5), 90.0)
			queue_free()
			return
	match kind:
		"spikes":
			if _cd <= 0.0:
				_cd = 0.5
				for e in _enemies_inside(radius):
					e.take_damage(damage * 0.5, Vector2.ZERO, src)
					e.stun(0.3)
		"watchtower":
			# 時間とともに威力が上がる
			if _cd <= 0.0 and _fire(400.0, damage * (1.0 + game.elapsed / 180.0), 680.0, Color(0.95, 0.85, 0.6)):
				_cd = 0.7
		"sentry":
			if _cd <= 0.0 and _fire(330.0, damage, 720.0, Color(1.0, 0.95, 0.5)):
				_cd = 0.25
		"boulder":
			if _cd <= 0.0:
				_cd = 0.5
				for e in _enemies_inside(radius):
					e.take_damage(damage * 0.5, Vector2.ZERO, src)
					e.slow_left = 0.6
		"automaton":
			_update_automaton(delta)
		"mine", "snowman":
			if not _enemies_inside(radius).is_empty():
				if kind == "mine":
					game.explode(global_position, 75.0, damage, src, Color(1.0, 0.55, 0.2), 0.0, 260.0)
				else:
					game.explode(global_position, 130.0, damage, src, Color(0.75, 0.95, 1.0), 2.5, 200.0)
					game.spawn_burst(global_position, Color(1, 1, 1), 40.0)
				queue_free()
				return
	queue_redraw()


## 修理玉のたまった量（10秒間に城が回復したHP）
func _orb_charge() -> float:
	return game.castle.healed_total - _heal_start


## 修理玉：たまった量のダメージの弾を、HPが一番多い敵へゆっくり撃つ（ほかの敵はすり抜ける）
func _fire_orb() -> void:
	var dmg := _orb_charge()
	var t: Node2D = game.castle._toughest_enemy_in(global_position, INF)
	if dmg <= 0.0 or t == null:
		game.spawn_burst(global_position, Color(0.5, 1.0, 0.6), 20.0)
		return
	var b := BulletScript.new()
	b.game = game
	b.velocity = (t.global_position - global_position).normalized() * 220.0
	b.damage = dmg
	# 撃った玉は、置いた玉の1.5倍の大きさの、水色の玉（半透明じゃない）
	b.radius = ORB_RADIUS * 1.5
	b.color = Color(0.3, 0.85, 1.0)
	b.orb = true
	b.only_target = t
	b.life = 12.0
	b.position = global_position
	b.src = src
	game.world.add_child(b)


## からくり兵：一番近い敵へゆっくり歩きながら、全方位斬り3回 → 高速連射12発 をくり返す
func _update_automaton(delta: float) -> void:
	_gear += delta * 4.0
	var t: Node2D = game.nearest_enemy(global_position, 900.0)
	if t != null:
		_aim = (t.global_position - global_position).normalized()
		if global_position.distance_to(t.global_position) > 90.0:
			position += _aim * 45.0 * delta
			position = game.clamp_to_map(position, radius)
	if _cd > 0.0:
		return
	if _mode == "slash":
		_cd = 0.6
		game.explode(global_position, 130.0, damage * 0.35, src, Color(0.9, 0.85, 0.7), 0.0, 300.0)
		var fx := SlashScript.new()
		fx.radius = 130.0
		fx.arc = TAU
		fx.duration = 0.25
		fx.position = global_position
		game.effects.add_child(fx)
		_mode_count += 1
		if _mode_count >= 3:
			_mode = "fire"
			_mode_count = 0
	else:
		_cd = 0.08
		if t != null:
			_fire(600.0, damage * 0.1, 800.0, Color(1.0, 0.8, 0.4))
		_mode_count += 1
		if _mode_count >= 12:
			_mode = "slash"
			_mode_count = 0
			_cd = 0.4


## 敵の攻撃を受ける（見張り櫓・かかし）
func take_damage(amount: float, _from_pos: Vector2 = Vector2.INF) -> void:
	if dead or max_hp <= 0.0:
		return
	hp -= amount
	_hurt = 0.15
	game.spawn_damage_text(global_position, amount, Color(1.0, 0.6, 0.4))
	if hp <= 0.0:
		dead = true
		game.spawn_burst(global_position, Color(0.6, 0.45, 0.3), 30.0)
		queue_free()


func _enemies_inside(r: float) -> Array:
	var list: Array = []
	for e in game.enemies_near(global_position, r + 30.0):
		if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < r + e.radius:
			list.append(e)
	return list


## 一番近い敵へ弾を撃つ。撃てたら true
func _fire(rng: float, dmg: float, spd: float, col: Color) -> bool:
	var from := global_position + Vector2(0, -22.0 if kind == "watchtower" else -8.0)
	var t: Node2D = game.nearest_enemy(from, rng)
	if t == null:
		return false
	_aim = (t.global_position - from).normalized()
	var b := BulletScript.new()
	b.game = game
	b.velocity = _aim * spd
	b.damage = dmg
	b.radius = 4.0
	b.color = col
	b.life = rng / spd + 0.2
	b.position = from
	b.src = src
	game.world.add_child(b)
	return true


func _draw() -> void:
	# 消える直前は点滅
	var fade := 1.0
	if not _forever and life < 2.0 and int(life * 8.0) % 2 == 0:
		fade = 0.4
	modulate.a = fade
	if _hurt > 0.0:
		modulate = Color(1.0, 0.5, 0.5, fade)
	else:
		modulate = Color(1, 1, 1, fade)
	if max_hp > 0.0 and hp < max_hp:
		# 耐久バー
		var top := Vector2(-16, -48)
		draw_rect(Rect2(top, Vector2(32, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(32 * hp / max_hp, 4)), Color(0.9, 0.75, 0.3))
	match kind:
		"spikes":
			draw_circle(Vector2.ZERO, radius, Color(0.45, 0.3, 0.15, 0.18))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.5, 0.35, 0.2, 0.5), 2.0)
			# 交差した木の杭
			for i in 5:
				var p := Vector2.from_angle(TAU * i / 5.0 + 0.3) * radius * 0.55
				draw_line(p + Vector2(-9, 8), p + Vector2(9, -10), Color(0.55, 0.38, 0.2), 4.0)
				draw_line(p + Vector2(9, 8), p + Vector2(-9, -10), Color(0.55, 0.38, 0.2), 4.0)
				draw_circle(p + Vector2(9, -10), 2.0, Color(0.85, 0.85, 0.8))
				draw_circle(p + Vector2(-9, -10), 2.0, Color(0.85, 0.85, 0.8))
		"watchtower":
			draw_circle(Vector2(0, 8), 14.0, Color(0, 0, 0, 0.3))
			# 4本の柱と、上の見張り台
			for x in [-10.0, 10.0]:
				draw_line(Vector2(x, 8), Vector2(x * 0.7, -18), Color(0.5, 0.33, 0.18), 4.0)
			draw_line(Vector2(-10, -2), Vector2(10, -10), Color(0.45, 0.3, 0.15), 2.0)
			draw_rect(Rect2(Vector2(-14, -28), Vector2(28, 10)), Color(0.62, 0.42, 0.22))
			draw_colored_polygon(PackedVector2Array([Vector2(-16, -28), Vector2(0, -40), Vector2(16, -28)]), Color(0.7, 0.25, 0.2))
			draw_line(Vector2(0, -23), Vector2(0, -23) + _aim * 14.0, Color(0.3, 0.2, 0.1), 2.0)
		"sentry":
			draw_circle(Vector2(0, 6), 11.0, Color(0, 0, 0, 0.3))
			# 三脚と回る砲身
			for a in [0.5, PI - 0.5, PI * 0.5]:
				draw_line(Vector2.ZERO, Vector2.from_angle(a) * 13.0, Color(0.3, 0.3, 0.32), 3.0)
			draw_circle(Vector2(0, -8), 8.0, Color(0.45, 0.5, 0.4))
			draw_line(Vector2(0, -8), Vector2(0, -8) + _aim * 16.0, Color(0.15, 0.15, 0.15), 4.0)
			if _cd > 0.18:
				draw_circle(Vector2(0, -8) + _aim * 18.0, 4.0, Color(1.0, 0.9, 0.4))
		"mine":
			var blink := int(_t * 3.0) % 2 == 0
			draw_circle(Vector2.ZERO, 9.0, Color(0.2, 0.2, 0.22))
			for i in 6:
				var d := Vector2.from_angle(TAU * i / 6.0)
				draw_line(d * 8.0, d * 12.0, Color(0.35, 0.35, 0.38), 2.0)
			draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.2, 0.2) if blink else Color(0.4, 0.1, 0.1))
		"boulder":
			# 地面に残った大岩（足元に砂ぼこりの輪）
			draw_circle(Vector2.ZERO, radius, Color(0.55, 0.45, 0.3, 0.18))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.6, 0.5, 0.35, 0.5), 2.0)
			draw_circle(Vector2(0, 8), 26.0, Color(0, 0, 0, 0.3))
			draw_circle(Vector2.ZERO, 26.0, Color(0.45, 0.42, 0.4))
			draw_circle(Vector2(-8, -8), 9.0, Color(0.58, 0.55, 0.52))
			draw_line(Vector2(-6, 4), Vector2(8, -2), Color(0.3, 0.28, 0.26), 2.0)
			draw_line(Vector2(8, -2), Vector2(14, 8), Color(0.3, 0.28, 0.26), 2.0)
		"repair_orb":
			# 当たり判定のない、水色の半透明の玉。水色にふわ〜っと光っている
			var glow := 0.5 + 0.5 * sin(_t * 3.0)
			for i in 4:
				var rr := ORB_RADIUS * (1.15 + 0.22 * i + 0.08 * glow)
				draw_circle(Vector2.ZERO, rr, Color(0.3, 0.9, 1.0, (0.16 + 0.1 * glow) / (i + 1)))
			draw_circle(Vector2.ZERO, ORB_RADIUS, Color(0.35, 0.88, 1.0, 0.5 + 0.12 * glow))
			draw_circle(Vector2.ZERO, ORB_RADIUS * 0.6, Color(0.7, 0.98, 1.0, 0.3 + 0.15 * glow))
			draw_arc(Vector2.ZERO, ORB_RADIUS, 0.0, TAU, 48, Color(0.75, 1.0, 1.0, 0.85), 2.5)
			draw_circle(Vector2(-ORB_RADIUS * 0.35, -ORB_RADIUS * 0.35), ORB_RADIUS * 0.25, Color(1, 1, 1, 0.5))
			# 発射までの時間の輪と、たまった量
			draw_arc(Vector2.ZERO, ORB_RADIUS + 7.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(life / 10.0, 0.0, 1.0), 40, Color(0.8, 0.97, 1.0, 0.7), 2.0)
			var font := ThemeDB.fallback_font
			var txt := str(int(_orb_charge()))
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2(-w / 2.0, 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
		"automaton":
			# ボスと同じくらい大きな、木と鉄のからくり兵
			var r := 46.0
			draw_circle(Vector2(0, 14), r, Color(0, 0, 0, 0.3))
			for i in 8:
				var d := Vector2.from_angle(_gear + TAU * i / 8.0)
				draw_line(d * r * 0.8, d * (r + 8.0), Color(0.45, 0.4, 0.35), 7.0)
			draw_circle(Vector2.ZERO, r, Color(0.6, 0.45, 0.28))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.3, 0.22, 0.12), 4.0)
			draw_circle(Vector2.ZERO, r * 0.45, Color(0.5, 0.5, 0.55))
			draw_arc(Vector2.ZERO, r * 0.45, _gear, _gear + TAU * 0.8, 16, Color(0.75, 0.75, 0.8), 3.0)
			# 光る目と、連射用の砲身
			draw_circle(Vector2(-12, -14), 5.0, Color(1.0, 0.85, 0.3))
			draw_circle(Vector2(12, -14), 5.0, Color(1.0, 0.85, 0.3))
			draw_line(_aim * r * 0.4, _aim * (r + 16.0), Color(0.25, 0.25, 0.28), 10.0)
			# 残り時間のバー
			draw_rect(Rect2(Vector2(-30, -r - 14), Vector2(60, 5)), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(Vector2(-30, -r - 14), Vector2(60 * clampf(life / 10.0, 0.0, 1.0), 5)), Color(1.0, 0.8, 0.3))
		"scarecrow":
			# 揺れるかかし（叩かれると大きく揺れる）
			var sway := sin(_t * 3.0) * 0.12 + (sin(_t * 40.0) * 0.3 if _hurt > 0.0 else 0.0)
			draw_circle(Vector2(0, 10), 10.0, Color(0, 0, 0, 0.25))
			draw_set_transform(Vector2(0, 10), sway, Vector2.ONE)
			draw_line(Vector2(0, 0), Vector2(0, -34), Color(0.5, 0.35, 0.2), 3.0)
			draw_line(Vector2(-16, -24), Vector2(16, -24), Color(0.5, 0.35, 0.2), 3.0)
			draw_rect(Rect2(Vector2(-9, -30), Vector2(18, 16)), Color(0.75, 0.3, 0.25))
			draw_circle(Vector2(0, -38), 8.0, Color(0.95, 0.85, 0.55))
			draw_colored_polygon(PackedVector2Array([Vector2(-13, -42), Vector2(0, -54), Vector2(13, -42)]), Color(0.85, 0.75, 0.3))
			draw_line(Vector2(-4, -40), Vector2(-2, -38), Color(0, 0, 0), 1.5)
			draw_line(Vector2(4, -40), Vector2(2, -38), Color(0, 0, 0), 1.5)
			draw_arc(Vector2(0, -36), 3.0, 0.2, PI - 0.2, 6, Color(0, 0, 0), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"snowman":
			draw_circle(Vector2(0, 10), 14.0, Color(0, 0, 0, 0.25))
			draw_circle(Vector2(0, 2), 13.0, Color(0.95, 0.97, 1.0))
			draw_circle(Vector2(0, -15), 9.0, Color(0.95, 0.97, 1.0))
			draw_circle(Vector2(-3, -17), 1.5, Color(0.1, 0.1, 0.1))
			draw_circle(Vector2(3, -17), 1.5, Color(0.1, 0.1, 0.1))
			draw_line(Vector2(0, -15), Vector2(6, -13), Color(1.0, 0.55, 0.1), 2.5)
			draw_rect(Rect2(Vector2(-7, -28), Vector2(14, 6)), Color(0.2, 0.35, 0.7))
			draw_line(Vector2(-12, -2), Vector2(-20, -10), Color(0.45, 0.3, 0.15), 2.0)
			draw_line(Vector2(12, -2), Vector2(20, -10), Color(0.45, 0.3, 0.15), 2.0)
