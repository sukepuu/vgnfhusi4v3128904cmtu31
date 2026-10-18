extends Node2D
## 鼓舞部隊。太鼓を持ってフィールドの下半分をふらふら歩きまわり、一定の間隔で太鼓を叩いて、自分のまわりの敵にまとめてダメージを与える。
## 叩いたとき、範囲内の味方（ほかの鼓舞兵・ペット・城の兵装も）に4秒間、与ダメージ+10%のバフをかける。
## HPはない（敵から狙われず、攻撃も当たらない）。ステータスは game.drummer_stats を全員で共有している。
## 特別強化：
##   衝撃の太鼓（叩いた範囲の敵を気絶）・戦の太鼓（叩いた範囲の敵の被ダメージ+20%）・二度打ち（少しあとにもう一度、半分の威力）・
##   響きの波（叩くたびに全方位へ衝撃波）・押し返しの太鼓（叩いた範囲の敵を外へ押し出す）・癒しの調べ（叩くたびに城と範囲内の味方を回復）・
##   共鳴の太鼓（ほかの鼓舞兵の範囲内で叩くと、ダメージ・バフの量・バフの時間が3倍）・士気の鼓動（バフをかけた味方の数だけダメージアップ）・
##   置き太鼓（叩いた場所に太鼓を置き、4秒後に鳴る）・必殺・大太鼓（15秒ごとに全鼓舞兵が特大の一打）

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
## 癒しの調べ：1回で城が回復する量・範囲内の味方が回復する量
const HEAL_CASTLE := 3.0
const HEAL_ALLY := 20.0
## 共鳴の太鼓：ほかの鼓舞兵の範囲内で叩いたときの、ダメージ・バフの量・バフの時間の倍率
const RESONANCE_MULT := 3.0
## 士気の鼓動：バフをかけた味方1人につきダメージ +20%（最大 +200%）
const MORALE_PER := 0.2
const MORALE_MAX := 2.0
## 置き太鼓：置いてから鳴るまでの秒数
const PLACE_DELAY := 4.0
## 必殺・大太鼓：間隔・範囲・威力・気絶
const ULT_EVERY := 15.0
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
## 置き太鼓：{"pos": 置いた場所, "left": 鳴るまでの秒数}
var _placed: Array = []
## 置き太鼓が鳴った直後の見た目：{"pos", "left"}
var _placed_fx: Array = []
## 共鳴の太鼓が起きた直後（見た目用）
var _resonance_fx := 0.0


func _ready() -> void:
	record = game.new_record("drummer", "鼓舞兵%d" % (index + 1))
	_cd = 1.0 + 1.5 * index
	_ult_tick = floori(game.elapsed / ULT_EVERY)
	_pick_new_dest()


func _process(delta: float) -> void:
	_t += delta
	_beat_fx -= delta
	_resonance_fx -= delta
	var st = game.drummer_stats
	_update_placed(delta)
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
	_cd -= delta * game.atk_speed_mult(record)
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
	var buff_bonus: float = game.DRUM_BUFF_BONUS
	var buff_time := BUFF_TIME
	# 共鳴の太鼓：ほかの鼓舞兵の太鼓の範囲内にいたら、ダメージ・バフの量・バフの時間が3倍
	if game.drum_resonance and _in_other_drum_range():
		dmg *= RESONANCE_MULT
		buff_bonus *= RESONANCE_MULT
		buff_time *= RESONANCE_MULT
		_resonance_fx = 0.5
	var buffed: int = game.drum_buff_area(global_position, r, buff_time, self, buff_bonus)
	# 士気の鼓動：バフをかけた味方の数 × 20% ダメージアップ（最大 +200%）
	if game.drum_morale:
		dmg *= 1.0 + minf(MORALE_MAX, MORALE_PER * buffed)
	_hit_area(global_position, r, dmg, src, _beat_stun(), _beat_knock())
	_beat_fx = 0.3
	_beat_r = r
	# 癒しの調べ：城のHP+3、範囲内の味方のHP+20（二度打ちの二打目でも回復する）
	if game.drum_heal:
		game.castle.heal(HEAL_CASTLE, record, "sp_drum_heal")
		game.drum_heal_area(global_position, r, HEAL_ALLY, record, "sp_drum_heal")
	if not main_hit:
		return
	if game.drum_double:
		_double_left = DOUBLE_DELAY
	if game.drum_wave:
		_shock_waves(dmg * WAVE_RATIO)
	# 置き太鼓：叩いた場所に太鼓を置く（4秒後に1回鳴って消える）
	if game.drum_place:
		_placed.append({"pos": global_position, "left": PLACE_DELAY})


func _beat_stun() -> float:
	return SHOCK_STUN if game.drum_shock else 0.0


func _beat_knock() -> float:
	return PUSH_KNOCK if game.drum_push else 0.0


## ほかの鼓舞兵の太鼓の範囲内にいるか
func _in_other_drum_range() -> bool:
	for d in game.drummers:
		if d != self and is_instance_valid(d) and global_position.distance_to(d.global_position) <= game.drummer_stats.radius:
			return true
	return false


## 置き太鼓：時間が来たら、置いた場所で太鼓が鳴る（ダメージ・バフ。気絶・押し出し・戦の太鼓も乗る）
func _update_placed(delta: float) -> void:
	for fx in _placed_fx:
		fx["left"] -= delta
	_placed_fx = _placed_fx.filter(func(fx) -> bool: return fx["left"] > 0.0)
	if _placed.is_empty():
		return
	var st = game.drummer_stats
	for p in _placed:
		p["left"] -= delta
		if p["left"] <= 0.0:
			game.drum_buff_area(p["pos"], st.radius, BUFF_TIME, null)
			_hit_area(p["pos"], st.radius, st.damage, game.sp_src(record, "sp_drum_place"), _beat_stun(), _beat_knock())
			_placed_fx.append({"pos": p["pos"], "left": 0.3})
	_placed = _placed.filter(func(p) -> bool: return p["left"] > 0.0)


func _hit_area(center: Vector2, r: float, dmg: float, src: Dictionary, stun: float, knock: float) -> void:
	for e in game.enemies_near(center, r + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - center
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
	_hit_area(global_position, r, st.damage * ULT_DAMAGE_MULT, game.sp_src(record, "sp_ult_drum"), ULT_STUN, 0.0)
	game.drum_buff_area(global_position, r, BUFF_TIME, self)
	_beat_fx = 0.6
	_beat_r = r
	game.spawn_burst(global_position, Color(1.0, 0.55, 0.45), r * 0.5)


func _draw() -> void:
	# 置き太鼓：置いた太鼓と、鳴るまでの残り時間の輪。鳴った直後は範囲いっぱいの輪
	for p in _placed:
		var lp := to_local(p["pos"])
		draw_circle(lp, 9.0, Color(0.55, 0.32, 0.15))
		draw_circle(lp + Vector2(0, -2), 7.0, Color(0.95, 0.88, 0.7))
		draw_arc(lp, 14.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - p["left"] / PLACE_DELAY), 24, Color(1.0, 0.55, 0.45), 3.0)
	for fx in _placed_fx:
		var k: float = 1.0 - fx["left"] / 0.3
		draw_arc(to_local(fx["pos"]), game.drummer_stats.radius * (0.3 + 0.7 * k), 0.0, TAU, 48, Color(1.0, 0.6, 0.5, 0.8 * (1.0 - k) + 0.1), 4.0)
	# 共鳴の太鼓：金色に光る
	if _resonance_fx > 0.0:
		draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.85, 0.3, 0.5 * _resonance_fx / 0.5))
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
