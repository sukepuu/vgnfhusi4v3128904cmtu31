extends Node2D
## ペット大合体の合体中に、突撃ペットで体の中心から飛び出すペット。
## ふつうの突撃ペットと同じように、HPが一番高い敵へ高速で突進して、行きに触れた敵に1回ずつダメージ
## （遊撃ペットは攻撃力の16倍、弓兵ペットは約4.27倍、鼓舞ペットは笛と同じ威力。pet.gd の倍率を使用。爆裂突撃ペットなら当たった所で小爆発）。そのあと合体ペットの中心へ戻って消える（戻りはダメージなし）。
## ダメージは合体前のペットの戦績に「突撃ペット」「爆裂突撃ペット」として記録する。

const PetScript := preload("res://scripts/pet.gd")

var game: Node2D
## 飛び出してきた合体ペット（戻る場所）
var fusion: Node2D
## ダメージを記録する、合体前のペットの戦績カード
var record: Dictionary = {}
## 弓兵ペット大合体から飛び出したか（攻撃力・特別強化・色を弓兵ペットのものにする）
var archer := false
## 鼓舞ペット大合体から飛び出したか
var drum := false
var damage_mult := 1.0
var target: Node2D = null
## 1 = 突進中 / 2 = 戻り中
var _state := 1
var _t := 0.0
var _aim := Vector2.UP
var _hits := {}
var _trail: Array = []
## ペットの踊りの虹色のずれ（1匹ずつ色を変える）
var _hue_ofs := randf()


func _process(delta: float) -> void:
	_t += delta
	scale = Vector2(1.7, 1.7) if (game.archer_pet_giant if archer else (game.drum_pet_giant if drum else game.pet_giant)) else Vector2.ONE
	if _state == 1:
		# 狙った敵が倒れたら、別の一番HPが高い敵へ。いなければ戻る
		if not is_instance_valid(target) or target.dead:
			target = PetScript.strongest_enemy_of(game)
		if target == null:
			_state = 2
		else:
			var to: Vector2 = target.global_position - global_position
			_aim = to.normalized()
			global_position += to.limit_length(PetScript.CHARGE_SPEED * delta)
			_push_trail()
			_hit()
			var reach: float = 9.0 * scale.x + target.radius
			if global_position.distance_to(target.global_position) <= reach or _t >= PetScript.CHARGE_MAX_TIME:
				_state = 2
	else:
		# 戻るときはダメージなし。合体ペットの中心に着いたら消える（合体が終わっていても、その場所へ戻って消える）
		var home: Vector2 = fusion.global_position if is_instance_valid(fusion) else global_position
		var back: Vector2 = home - global_position
		_aim = back.normalized() if back.length() > 0.1 else _aim
		global_position += back.limit_length(PetScript.CHARGE_RETURN_SPEED * delta)
		_push_trail()
		if global_position.distance_to(home) < 8.0:
			queue_free()
	queue_redraw()


func _push_trail() -> void:
	_trail.append(global_position)
	if _trail.size() > 10:
		_trail.pop_front()


## 突進中に触れた敵に1回ずつダメージ（ふつうの突撃ペットと同じ）
func _hit() -> void:
	var r := 9.0 * scale.x
	for e in game.enemies_near(global_position, r + 60.0):
		if not is_instance_valid(e) or e.dead:
			continue
		var id: int = e.get_instance_id()
		if _hits.has(id):
			continue
		if global_position.distance_to(e.global_position) < r + e.radius + 3.0:
			_hits[id] = true
			var dmg: float = game.archer_pet_attack_power * PetScript.ARCHER_CHARGE_MULT if archer else \
				(game.drum_pet_attack_power * PetScript.DRUM_LAUNCH_CHARGE_MULT if drum else game.pet_attack_power * PetScript.CHARGE_MULT)
			dmg *= damage_mult
			var hit_pos: Vector2 = e.global_position
			e.take_damage(dmg, _aim * 260.0, game.sp_src(record, "sp_archer_pet_charge" if archer else ("sp_drum_pet_charge" if drum else "sp_pet_charge")))
			if game.archer_pet_charge_burst if archer else (false if drum else game.pet_charge_burst):
				var burst_dmg: float = game.archer_pet_attack_power * PetScript.ARCHER_CHARGE_BURST_MULT if archer else dmg * PetScript.PET_CHARGE_BURST_RATIO
				game.explode(hit_pos, PetScript.CHARGE_BURST_RADIUS, burst_dmg, game.sp_src(record, "sp_archer_pet_charge_burst" if archer else "sp_pet_charge_burst"), Color(1.0, 0.7, 0.3))


func _draw() -> void:
	# 残像の線（突進中は黄色、戻り中は緑）
	if _trail.size() >= 2:
		var col := Color(1.0, 0.85, 0.4) if _state == 1 else Color(0.6, 1.0, 0.8)
		for i in range(1, _trail.size()):
			var a: float = float(i) / _trail.size()
			draw_line(to_local(_trail[i - 1]), to_local(_trail[i]), Color(col, 0.6 * a), 3.0 + 7.0 * a)
	# ふつうのペットと同じ小鳥
	var c := Vector2.ZERO
	var dance: bool = game.archer_pet_dance if archer else (game.drum_pet_dance if drum else game.fun.pet_dance)
	if dance:
		# ペットの踊り：ふつうのペットと同じく、虹色に光りながらくるくる回る
		var hue := fmod(_t * 0.8 + _hue_ofs, 1.0)
		draw_circle(c, 15.0, Color.from_hsv(hue, 0.7, 1.0, 0.35))
		for i in 6:
			var a := _t * 4.0 + TAU * i / 6.0
			draw_circle(c + Vector2.from_angle(a) * 14.0, 2.5, Color.from_hsv(fmod(hue + i / 6.0, 1.0), 0.8, 1.0))
		draw_set_transform(c, _t * 9.0, Vector2.ONE)
	var body_col := Color(0.8, 0.65, 1.0) if archer else (Color(1.0, 0.6, 0.5) if drum else Color(0.45, 0.95, 0.65))
	var wing_col := Color(0.6, 0.45, 0.85) if archer else (Color(0.85, 0.38, 0.32) if drum else Color(0.3, 0.75, 0.5))
	draw_circle(c, 9.0, Color.from_hsv(fmod(_t * 0.8 + _hue_ofs, 1.0), 0.55, 1.0) if dance else body_col)
	var wing := sin(_t * 18.0) * 4.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-15, -4 - wing), c + Vector2(-8, 5)]), wing_col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(6, 0), c + Vector2(15, -4 - wing), c + Vector2(8, 5)]), wing_col)
	draw_circle(c + _aim * 4.0 + Vector2(-2, -2), 1.8, Color(0.1, 0.1, 0.1))
	draw_circle(c + _aim * 4.0 + Vector2(2, -2), 1.8, Color(0.1, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([c + _aim * 12.0, c + _aim * 7.0 + _aim.orthogonal() * 3.0, c + _aim * 7.0 - _aim.orthogonal() * 3.0]), Color(1.0, 0.8, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
