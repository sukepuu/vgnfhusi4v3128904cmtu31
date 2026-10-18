extends Node2D
## 鼓舞部隊。太鼓を持ってフィールドの下半分をふらふら歩きまわり、一定の間隔で太鼓を叩いて、自分のまわりの敵にまとめてダメージを与える。
## 叩いたとき、範囲内の味方（ほかの鼓舞兵・ペット・城の兵装も）に4秒間、与ダメージ+10%のバフをかける。
## HPはない（敵から狙われず、攻撃も当たらない）。ステータスは game.drummer_stats を全員で共有している。
## 特別強化：
##   衝撃の太鼓（叩いた範囲の敵を気絶）・戦の太鼓（叩いた範囲の敵の被ダメージ+20%）・二度打ち（少しあとにもう一度、半分の威力）・
##   響きの波（叩くたびに全方位へ衝撃波）・押し返しの太鼓（叩いた範囲の敵を外へ押し出す）・癒しの調べ（叩くたびに城を回復）・
##   必殺・大太鼓（20秒ごとに全鼓舞兵が特大の一打）

const BulletScript := preload("res://scripts/bullet.gd")

## 太鼓を叩くと、範囲内の味方に BUFF_TIME 秒間、与ダメージ+10%のバフ（main.gd の DRUM_BUFF_BONUS）
const BUFF_TIME := 4.0
## 敵がいる方へ寄っていく割合（残りはランダムな場所へ歩く）
const SEEK_CHANCE := 0.6
## 戦の太鼓：叩いた範囲の敵が受けるダメージの倍率・秒数
const WAR_MULT := 1.2
const WAR_TIME := 5.0
## 衝撃の太鼓：気絶させる秒数
const SHOCK_STUN := 0.5
## 二度打ち：二打目までの時間・威力
const DOUBLE_DELAY := 0.4
const DOUBLE_RATIO := 0.5
## 響きの波：衝撃波の数・威力（太鼓の威力 × これ）
const WAVE_COUNT := 8
const WAVE_RATIO := 0.3
## 押し返しの太鼓：押す強さ
const PUSH_KNOCK := 450.0
## 癒しの調べ：1回で城が回復する量
const HEAL_AMOUNT := 10.0
## 必殺・大太鼓：間隔・範囲・威力・気絶
const ULT_EVERY := 20.0
const ULT_RADIUS_MULT := 3.0
const ULT_DAMAGE_MULT := 5.0
const ULT_STUN := 1.0

var game: Node2D
var index := 0
var dead := false
var radius := 12.0
var record: Dictionary

var _cd := 1.0
var _wander_t := 0.0
var _target_pos := Vector2.ZERO
var _t := 0.0
## 叩いた直後の見た目（残り時間・広がる半径）
var _beat_fx := 0.0
var _beat_r := 150.0
## 二度打ちの残り時間（0以下なら予定なし）
var _double_left := -1.0
var _ult_tick := 0


func _ready() -> void:
	record = game.new_record("drummer", "鼓舞兵%d" % (index + 1))
	_cd = 1.0 + 1.5 * index
	_ult_tick = floori(game.elapsed / ULT_EVERY)
	_pick_new_dest()


func _process(delta: float) -> void:
	_t += delta
	_beat_fx -= delta
	var st = game.drummer_stats
	# ふらふら歩く（ゆらゆら左右に揺れながら）
	_wander_t -= delta
	if _wander_t <= 0.0 or position.distance_to(_target_pos) < 20.0:
		_pick_new_dest()
	var to := _target_pos - position
	if to.length() > 4.0:
		var sway := to.normalized().orthogonal() * sin(_t * 2.5) * 0.5
		position += (to.normalized() + sway).normalized() * minf(st.move_speed * delta, to.length())
	position = game.clamp_to_map(position, 20.0)
	# 太鼓を叩く
	_cd -= delta
	if _cd <= 0.0:
		_cd = st.interval
		_beat(st.damage, st.radius, record)
	if _double_left > 0.0:
		_double_left -= delta
		if _double_left <= 0.0:
			_beat(st.damage * DOUBLE_RATIO, st.radius, game.sp_src(record, "sp_drum_double"), false)
	# 必殺・大太鼓：全鼓舞兵が同じタイミングで
	if game.drum_ult:
		var cyc := floori(game.elapsed / ULT_EVERY)
		if cyc > _ult_tick:
			_ult_tick = cyc
			_big_beat()
	else:
		_ult_tick = floori(game.elapsed / ULT_EVERY)
	queue_redraw()


## 下半分の、敵の近く（なければランダムな場所）へ向かう
func _pick_new_dest() -> void:
	var r: Rect2 = game.MAP_RECT
	var lower := Rect2(r.position.x, r.position.y + r.size.y * 0.4, r.size.x, r.size.y * 0.6)
	_target_pos = Vector2(randf_range(lower.position.x + 40, lower.end.x - 40), randf_range(lower.position.y + 40, lower.end.y - 40))
	if randf() < SEEK_CHANCE:
		var e: Node2D = game.nearest_enemy(global_position, 700.0)
		if e != null:
			_target_pos = game.clamp_to_map(e.global_position + Vector2.from_angle(randf() * TAU) * 40.0, 40.0)
	_wander_t = randf_range(2.0, 4.0)


## 太鼓を1回叩く：自分を中心に、範囲の敵へまとめてダメージ
## main_hit = 二度打ちの元になる一打か（二打目からはもう二度打ちしない）
func _beat(dmg: float, r: float, src: Dictionary, main_hit: bool = true) -> void:
	var knock: float = PUSH_KNOCK if game.drum_push else 0.0
	var stun: float = SHOCK_STUN if game.drum_shock else 0.0
	_hit_area(r, dmg, src, stun, knock)
	game.drum_buff_area(global_position, r, BUFF_TIME, self)
	_beat_fx = 0.3
	_beat_r = r
	if not main_hit:
		return
	if game.drum_double:
		_double_left = DOUBLE_DELAY
	if game.drum_wave:
		_shock_waves(dmg * WAVE_RATIO)
	if game.drum_heal:
		game.castle.heal(HEAL_AMOUNT, record, "sp_drum_heal")


func _hit_area(r: float, dmg: float, src: Dictionary, stun: float, knock: float) -> void:
	for e in game.enemies_near(global_position, r + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - global_position
		if rel.length() > r + e.radius:
			continue
		if stun > 0.0:
			e.stun(stun)
		# 戦の太鼓：しばらく受けるダメージが増える（連射砲の弱点付与と重なったら強いほう）
		if game.drum_war:
			e.debuff_left = maxf(e.debuff_left, WAR_TIME)
			e.debuff_mult = maxf(e.debuff_mult, WAR_MULT)
		e.take_damage(dmg, rel.normalized() * knock, src)


## 響きの波：全方位へ衝撃波（三日月形の弾。2体まで貫通）
func _shock_waves(dmg: float) -> void:
	for i in WAVE_COUNT:
		var dir := Vector2.from_angle(TAU * i / WAVE_COUNT + _t)
		var b := BulletScript.new()
		b.game = game
		b.position = global_position
		b.velocity = dir * 360.0
		b.damage = dmg
		b.radius = 14.0
		b.wave = true
		b.pierce = 2
		b.color = Color(1.0, 0.6, 0.5)
		b.life = 1.2
		b.src = game.sp_src(record, "sp_drum_wave")
		game.world.add_child(b)


## 必殺・大太鼓：とても広い範囲に、特大の一打（気絶つき）
func _big_beat() -> void:
	var st = game.drummer_stats
	var r: float = st.radius * ULT_RADIUS_MULT
	_hit_area(r, st.damage * ULT_DAMAGE_MULT, game.sp_src(record, "sp_ult_drum"), ULT_STUN, 0.0)
	game.drum_buff_area(global_position, r, BUFF_TIME, self)
	_beat_fx = 0.6
	_beat_r = r
	game.spawn_burst(global_position, Color(1.0, 0.55, 0.45), r * 0.5)


func _draw() -> void:
	# 叩いた直後：自分を中心に、範囲いっぱいまで広がる輪
	if _beat_fx > 0.0:
		var k := 1.0 - _beat_fx / 0.3 if _beat_fx <= 0.3 else 1.0 - (_beat_fx - 0.3) / 0.3
		k = clampf(k, 0.0, 1.0)
		draw_arc(Vector2.ZERO, _beat_r * (0.3 + 0.7 * k), 0.0, TAU, 48, Color(1.0, 0.6, 0.5, 0.8 * (1.0 - k) + 0.1), 5.0)
		draw_circle(Vector2.ZERO, _beat_r * (0.3 + 0.7 * k), Color(1.0, 0.5, 0.4, 0.12 * (1.0 - k)))
	var bob := absf(sin(_t * 5.0)) * 2.0
	draw_circle(Vector2(0, 9), 9.0, Color(0, 0, 0, 0.25))
	# 体（赤い法被）
	draw_circle(Vector2(0, -bob), 10.0, Color(0.9, 0.35, 0.3))
	draw_circle(Vector2(0, -8 - bob), 5.0, Color(1.0, 0.85, 0.7))
	# 太鼓（体の前）
	var drum_c := Vector2(0, 8 - bob)
	draw_circle(drum_c, 8.0, Color(0.55, 0.32, 0.15))
	draw_circle(drum_c + Vector2(0, -2), 6.0, Color(0.95, 0.88, 0.7))
	# ばち（叩いた直後は振り下ろした形）
	var down := _beat_fx > 0.15
	for s in [-1.0, 1.0]:
		var hand := Vector2(s * 9.0, -2 - bob)
		var tip := drum_c + Vector2(s * 3.0, -3) if down else hand + Vector2(s * 4.0, -10)
		draw_line(hand, tip, Color(0.4, 0.25, 0.1), 2.0)
		draw_circle(tip, 2.0, Color(0.9, 0.3, 0.25))
