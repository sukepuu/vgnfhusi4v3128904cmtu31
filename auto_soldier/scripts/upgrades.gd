extends RefCounted
## レベルアップ時の強化一覧。ここに追加すれば3択の候補に出るようになる。
## desc_up があれば、2回目以降はそちらの説明を表示する。

const LIST := [
	{"id": "multishot", "name": "射撃数+1", "desc": "一度に撃つ弾が1発増える", "max": 6},
	{"id": "firerate", "name": "速射", "desc": "射撃の間隔 -15%", "max": 5},
	{"id": "bullet_dmg", "name": "強化弾", "desc": "射撃ダメージ +30%", "max": 5},
	{"id": "pierce", "name": "貫通弾", "desc": "弾が敵をもう1体貫通する", "max": 3},
	{"id": "sword_dmg", "name": "剣術", "desc": "斬撃ダメージ +35%", "max": 5},
	{"id": "sword_range", "name": "大振り", "desc": "斬撃の範囲 +20%", "max": 4},
	{"id": "whirlwind", "name": "回転斬り", "desc": "斬撃が全方位360度になる", "max": 1},
	{"id": "dash", "name": "突進突き", "desc": "4秒ごとに近くの敵へ突進して貫く（突進中は無敵）",
		"desc_up": "突進の間隔 -20%、威力 +30%", "max": 4},
	{"id": "pet", "name": "ペットの仲間", "desc": "自動で射撃してくれる仲間が加わる",
		"desc_up": "ペットがもう1体加わる、全ペットの攻撃力 +20%", "max": 4},
	{"id": "max_hp", "name": "頑丈", "desc": "最大HP +25、HPを全回復", "max": 5},
	{"id": "regen", "name": "再生", "desc": "毎秒HPが1回復する", "max": 3},
	{"id": "speed", "name": "俊足", "desc": "移動速度 +12%", "max": 3},
]


## まだ上限に達していない強化から、ランダムに n 個選ぶ
static func roll(levels: Dictionary, n: int) -> Array:
	var available: Array = []
	for u in LIST:
		if levels.get(u["id"], 0) < u["max"]:
			available.append(u)
	available.shuffle()
	return available.slice(0, n)


static func describe(u: Dictionary, current_level: int) -> String:
	if current_level > 0 and u.has("desc_up"):
		return u["desc_up"]
	return u["desc"]


## new_level = 取得後のレベル（1始まり）
static func apply(id: String, new_level: int, game: Node2D) -> void:
	var s: Node2D = game.soldier
	match id:
		"multishot":
			s.shot_count += 1
		"firerate":
			s.fire_interval *= 0.85
		"bullet_dmg":
			s.bullet_damage *= 1.3
		"pierce":
			s.bullet_pierce += 1
		"sword_dmg":
			s.sword_damage *= 1.35
		"sword_range":
			s.sword_radius *= 1.2
		"whirlwind":
			s.sword_arc = TAU
		"dash":
			s.dash_level = new_level
			if new_level > 1:
				s.dash_interval *= 0.8
				s.dash_damage *= 1.3
		"pet":
			if new_level > 1:
				for p in game.pets:
					p.damage *= 1.2
			game.add_pet()
		"max_hp":
			s.max_hp += 25.0
			s.hp = s.max_hp
		"regen":
			s.regen += 1.0
		"speed":
			s.move_speed *= 1.12
