extends Node2D
## 重装部隊（最大1体）。足は遅いが、耐久力と攻撃力が高い。
## マップの中を自由に歩き回り、マップの真ん中に一番近い敵を最優先で倒しに行く。
## 敵がいないときはマップの真ん中で待つ。攻撃は遊撃部隊と同じ扇形の斬撃のみ。

const SlashScript := preload("res://scripts/slash_effect.gd")

const RESPAWN_TIME := 15.0

var game: Node2D
var radius := 22.0
var dead := false
var respawn_left := 0.0
var facing := Vector2.UP
var target: Node2D = null
var record: Dictionary

# --- ステータス
var max_hp := 1350.0
var hp := 1350.0
var regen := 4.0
var move_speed := 60.0
var slash_damage := 135.0
var slash_radius := 105.0
var slash_arc := deg_to_rad(150.0)
var slash_interval := 1.1

var _slash_cd := 0.0
var _hurt_flash := 0.0
var _invuln := 0.0
var _retarget_cd := 0.0

# --- 特別強化
## 連続斬り：1回の斬撃のあとに追加で出る回数
var extra_slashes := 0
## 地割れ
var quake_level := 0
## 吸命の剣：斬撃で与えたダメージのこの割合だけ回復
var lifesteal := 0.0
## 一刀両断：4秒ごとにHPの多い敵へ大ダメージの一撃
var execute := false
var _exec_cd := 2.0
var _pending_slashes := 0
var _followup_cd := 0.0
var _quake_cd := 3.0
## 鉄球投げ：5秒ごとに転がる鉄球を投げる
var iron_ball := false
var _ball_cd := 2.0
## 怒りの闘志：ダメージを受けるたびに与ダメージ +5%（最大+100%）。2秒ダメージがなければ元に戻る
var rage_enabled := false
var rage := 0.0
var _rage_timer := 0.0
## 仁王立ち：近くにいる敵の数（与ダメージ +5% ずつ）
var _near_count := 0
var _count_cd := 0.0


func _ready() -> void:
	record = game.new_record("heavy", "重装兵")


## 敵がいないときの待機場所：マップの真ん中
func post_position() -> Vector2:
	return game.MAP_RECT.get_center()


func _process(delta: float) -> void:
	if dead:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_respawn()
		queue_redraw()
		return
	_slash_cd -= delta
	_followup_cd -= delta
	_quake_cd -= delta
	_exec_cd -= delta
	_ball_cd -= delta
	_rage_timer -= delta
	if game.heavy_provoke:
		_count_cd -= delta
		if _count_cd <= 0.0:
			_count_cd = 0.25
			_near_count = 0
			for e in game.enemies_near(global_position, game.PROVOKE_RANGE):
				if is_instance_valid(e) and not e.dead and global_position.distance_to(e.global_position) < game.PROVOKE_RANGE:
					_near_count += 1
	if _rage_timer <= 0.0:
		rage = 0.0
	_hurt_flash -= delta
	_invuln -= delta
	_retarget_cd -= delta
	hp = minf(max_hp, hp + regen * delta)

	if _retarget_cd <= 0.0 or not _target_valid():
		target = _choose_target(post_position())
		_retarget_cd = 0.3

	# 狙った敵の所へどこまでも歩いていく（斬撃が届く距離まで近づいたら止まる）
	var desired := post_position()
	var stop_dist := 6.0
	if _target_valid():
		desired = target.global_position
		stop_dist = slash_radius * 0.6
	var to := desired - global_position
	if to.length() > stop_dist:
		position += to.normalized() * minf(move_speed * delta, to.length())
	position = game.clamp_to_map(position, radius)

	var look: Node2D = game.nearest_enemy(global_position, slash_radius + 60.0)
	if look == null and _target_valid():
		look = target
	if look != null:
		var want := (look.global_position - global_position).normalized()
		facing = Vector2.from_angle(rotate_toward(facing.angle(), want.angle(), 6.0 * delta))

	if _slash_cd <= 0.0 and _try_slash():
		_slash_cd = slash_interval
		_pending_slashes = extra_slashes
		_followup_cd = 0.18
	elif _pending_slashes > 0 and _followup_cd <= 0.0:
		# 連続斬り：追加の斬撃
		_pending_slashes = _pending_slashes - 1 if _try_slash() else 0
		_followup_cd = 0.18
	if execute and _exec_cd <= 0.0:
		var big := _toughest_enemy(220.0)
		if big != null:
			_exec_cd = 4.0
			var d := (big.global_position - global_position).normalized()
			facing = d
			big.take_damage(dmg() * 6.0, d * 200.0, record)
			var fx := SlashScript.new()
			fx.radius = 60.0
			fx.arc = 0.6
			fx.rotation = d.angle()
			fx.position = big.global_position - d * 30.0
			game.effects.add_child(fx)
			game.spawn_burst(big.global_position, Color(1.0, 0.9, 0.6), 20.0)
	if iron_ball and _ball_cd <= 0.0:
		var far: Node2D = game.nearest_enemy(global_position, 450.0)
		if far != null:
			_ball_cd = 5.0
			var bd := (far.global_position - global_position).normalized()
			game.spawn_missile("ball", global_position + bd * 30.0, bd * 560.0, dmg() * 1.5, 24.0, 3.0, record)
	if quake_level > 0 and _quake_cd <= 0.0 and game.nearest_enemy(global_position, 140.0) != null:
		_quake()
		_quake_cd = 5.0
	queue_redraw()


func _target_valid() -> bool:
	return target != null and is_instance_valid(target) and not target.dead


## マップの真ん中に一番近い敵
func _choose_target(center: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in game.enemies_cache:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = e.global_position.distance_to(center)
		if d < best_d:
			best_d = d
			best = e
	return best


## 遊撃部隊と同じ扇形の斬撃
func _try_slash() -> bool:
	var near: Node2D = game.nearest_enemy(global_position, slash_radius)
	if near == null:
		return false
	var dir := (near.global_position - global_position).normalized()
	facing = dir
	var dealt_before: float = record["dealt"]
	for e in game.enemies_near(global_position, slash_radius + 30.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - global_position
		if rel.length() > slash_radius + e.radius:
			continue
		if slash_arc < TAU and absf(dir.angle_to(rel)) > slash_arc / 2.0 + 0.2:
			continue
		e.take_damage(dmg(), rel.normalized() * 420.0, record)
	if lifesteal > 0.0:
		hp = minf(max_hp, hp + (record["dealt"] - dealt_before) * lifesteal)
	# 斬撃で敵の弾もかき消す
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		var to_b: Vector2 = b.global_position - global_position
		if to_b.length() <= slash_radius and (slash_arc >= TAU or absf(dir.angle_to(to_b)) <= slash_arc / 2.0):
			b.queue_free()
	var fx := SlashScript.new()
	fx.radius = slash_radius
	fx.arc = slash_arc
	fx.rotation = dir.angle()
	fx.position = global_position
	game.effects.add_child(fx)
	return true


## 近くで一番HPの多い敵
func _toughest_enemy(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_hp := 0.0
	for e in game.enemies_near(global_position, max_dist):
		if not is_instance_valid(e) or e.dead:
			continue
		if global_position.distance_to(e.global_position) < max_dist and e.hp > best_hp:
			best_hp = e.hp
			best = e
	return best


## 地割れ：周りの敵に大ダメージ＋気絶
func _quake() -> void:
	var r := 150.0 + 50.0 * (quake_level - 1)
	game.explode(global_position, r, dmg() * 0.6, record, Color(0.65, 0.5, 0.3), 2.0 + 1.5 * (quake_level - 1), 380.0)
	game.spawn_burst(global_position, Color(0.9, 0.8, 0.6), r / 1.6)


## 今の攻撃力（怒りの闘志の上乗せ込み）
func dmg() -> float:
	var provoke := 0.05 * _near_count if game.heavy_provoke else 0.0
	return slash_damage * (1.0 + rage) * (1.0 + provoke)


func take_damage(amount: float, _from_pos: Vector2 = Vector2.INF) -> void:
	if dead or _invuln > 0.0:
		return
	if rage_enabled:
		rage = minf(1.0, rage + 0.05)
		_rage_timer = 2.0
	record["taken"] += minf(amount, hp)
	hp -= amount
	_hurt_flash = 0.15
	_invuln = 0.2
	game.spawn_damage_text(global_position, amount, Color(1.0, 0.35, 0.35))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		target = null
		respawn_left = RESPAWN_TIME


func _respawn() -> void:
	dead = false
	hp = max_hp
	position = game.castle.gate_position()
	_invuln = 2.0
	game.spawn_burst(global_position, Color(0.8, 0.7, 1.0), 26.0)


func _draw() -> void:
	if dead:
		draw_circle(Vector2.ZERO, radius * 0.8, Color(0.35, 0.3, 0.4, 0.5))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-20, 6), str(ceili(respawn_left)), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(1, 1, 1, 0.8))
		return
	draw_circle(Vector2(0, 9), radius, Color(0, 0, 0, 0.35))
	if rage > 0.0:
		# 怒りのオーラ（たまるほど大きく赤く）
		draw_circle(Vector2.ZERO, radius + 6.0 + rage * 10.0, Color(1.0, 0.2, 0.1, 0.15 + rage * 0.25))
	var body := Color(0.45, 0.42, 0.55)
	if _hurt_flash > 0.0:
		body = Color(1, 1, 1)
	draw_circle(Vector2.ZERO, radius, body)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.15, 0.12, 0.2), 3.5)
	# 肩当て
	var side := facing.orthogonal()
	draw_circle(side * radius * 0.75, 8.0, Color(0.6, 0.58, 0.7))
	draw_circle(-side * radius * 0.75, 8.0, Color(0.6, 0.58, 0.7))
	# 兜
	draw_circle(-facing * 3.0, radius * 0.55, Color(0.3, 0.28, 0.38))
	draw_line(facing * radius * 0.1 - side * 6.0, facing * radius * 0.1 + side * 6.0, Color(0.1, 0.1, 0.12), 3.0)
	# 大剣
	var hilt := side * radius * 0.9
	draw_line(hilt - facing * 6.0, hilt + facing * 40.0, Color(0.85, 0.88, 0.95), 6.0)
	draw_line(hilt - side * 7.0, hilt + side * 7.0, Color(0.55, 0.45, 0.2), 4.0)
	# HPバー
	if hp < max_hp:
		var w := radius * 2.4
		var top := Vector2(-w / 2.0, -radius - 12.0)
		draw_rect(Rect2(top, Vector2(w, 5)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * hp / max_hp, 5)), Color(0.3, 0.9, 0.4))
