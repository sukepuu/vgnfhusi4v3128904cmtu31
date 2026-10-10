extends RefCounted
## レベルアップ時の強化一覧。ここに追加すれば3択の候補に出るようになる。
##   cat     : "soldier"（兵士の強化）か "castle"（城の迎撃システム）
##   max     : 取得できる上限レベル
##   weight  : 候補に出やすさ（省略時 1.0）
##   desc_up : 2回目以降に表示する説明（省略時は desc）

const LIST := [
	# ---- 兵士
	{"id": "recruit", "cat": "soldier", "name": "兵士を増員", "desc": "遊撃部隊の兵士が1人増える（最大5人）", "max": 3, "weight": 2.0},
	{"id": "multishot", "cat": "soldier", "name": "射撃数+1", "desc": "一度に撃つ弾が1発増える", "max": 5},
	{"id": "firerate", "cat": "soldier", "name": "速射", "desc": "射撃の間隔 -15%", "max": 5},
	{"id": "bullet_dmg", "cat": "soldier", "name": "強化弾", "desc": "射撃ダメージ +30%", "max": 5},
	{"id": "pierce", "cat": "soldier", "name": "貫通弾", "desc": "弾が敵をもう1体貫通する", "max": 3},
	{"id": "sword_dmg", "cat": "soldier", "name": "剣術", "desc": "斬撃ダメージ +35%", "max": 5},
	{"id": "sword_range", "cat": "soldier", "name": "大振り", "desc": "斬撃の範囲 +20%", "max": 4},
	{"id": "whirlwind", "cat": "soldier", "name": "回転斬り", "desc": "斬撃が全方位360度になる", "max": 1},
	{"id": "dash", "cat": "soldier", "name": "突進突き", "desc": "4秒ごとに敵へ突進して貫く（突進中は無敵）",
		"desc_up": "突進の間隔 -20%、威力 +30%", "max": 4},
	{"id": "pet", "cat": "soldier", "name": "ペットの仲間", "desc": "兵士について回り、自動で射撃してくれる仲間が加わる",
		"desc_up": "ペットがもう1体加わる、全ペットの攻撃力 +20%", "max": 4},
	{"id": "soldier_hp", "cat": "soldier", "name": "鍛錬", "desc": "兵士の最大HP +25、全員HP全回復", "max": 4},
	{"id": "speed", "cat": "soldier", "name": "俊足", "desc": "兵士の移動速度 +12%", "max": 3},
	# ---- 城
	{"id": "tower", "cat": "castle", "name": "矢倉", "desc": "城に矢倉が建ち、近づく敵を自動で射る",
		"desc_up": "矢倉をもう1基追加、全矢倉の威力 +15%", "max": 4, "weight": 1.5},
	{"id": "cannon", "cat": "castle", "name": "大砲", "desc": "敵が密集した場所へ砲弾を撃ち込む（範囲攻撃）",
		"desc_up": "大砲の間隔 -20%、威力 +30%", "max": 4, "weight": 1.3},
	{"id": "frost", "cat": "castle", "name": "氷結の結界", "desc": "城のまわりの敵の動きを遅くする",
		"desc_up": "結界の範囲が広がり、さらに遅くなる", "max": 3},
	{"id": "wall", "cat": "castle", "name": "城壁補強", "desc": "城の最大HP +100、城のHP全回復", "max": 5},
	{"id": "repair", "cat": "castle", "name": "修理工", "desc": "城のHPが毎秒2回復する", "max": 3},
]

const CAT_LABEL := {"soldier": "兵士", "castle": "城"}
const CAT_COLOR := {"soldier": Color(0.6, 0.85, 1.0), "castle": Color(1.0, 0.8, 0.5)}


## まだ上限に達していない強化から、出やすさに応じてランダムに n 個選ぶ
static func roll(levels: Dictionary, n: int, game: Node2D) -> Array:
	var available: Array = []
	for u in LIST:
		if levels.get(u["id"], 0) >= u["max"]:
			continue
		if u["id"] == "recruit" and game.soldiers.size() >= game.MAX_SOLDIERS:
			continue
		available.append(u)
	var result: Array = []
	while result.size() < n and not available.is_empty():
		var total := 0.0
		for u in available:
			total += u.get("weight", 1.0)
		var r := randf() * total
		var pick: int = available.size() - 1
		for i in available.size():
			r -= available[i].get("weight", 1.0)
			if r <= 0.0:
				pick = i
				break
		result.append(available[pick])
		available.remove_at(pick)
	return result


static func describe(u: Dictionary, current_level: int) -> String:
	if current_level > 0 and u.has("desc_up"):
		return u["desc_up"]
	return u["desc"]


## new_level = 取得後のレベル（1始まり）
static func apply(id: String, new_level: int, game: Node2D) -> void:
	var st = game.stats
	var castle: Node2D = game.castle
	match id:
		"recruit":
			game.add_soldier()
		"multishot":
			st.shot_count += 1
		"firerate":
			st.fire_interval *= 0.85
		"bullet_dmg":
			st.bullet_damage *= 1.3
		"pierce":
			st.bullet_pierce += 1
		"sword_dmg":
			st.sword_damage *= 1.35
		"sword_range":
			st.sword_radius *= 1.2
		"whirlwind":
			st.sword_arc = TAU
		"dash":
			st.dash_level = new_level
			if new_level > 1:
				st.dash_interval *= 0.8
				st.dash_damage *= 1.3
		"pet":
			if new_level > 1:
				for p in game.pets:
					p.damage *= 1.2
			game.add_pet()
		"soldier_hp":
			st.max_hp += 25.0
			for s in game.soldiers:
				if not s.dead:
					s.hp = st.max_hp
		"speed":
			st.move_speed *= 1.12
		"tower":
			castle.tower_count = new_level
			if new_level > 1:
				castle.tower_damage *= 1.15
		"cannon":
			castle.cannon_level = new_level
			if new_level > 1:
				castle.cannon_interval *= 0.8
				castle.cannon_damage *= 1.3
		"frost":
			castle.frost_radius = 220.0 + 60.0 * new_level
			castle.frost_slow = 0.25 + 0.1 * new_level
		"wall":
			castle.max_hp += 100.0
			castle.hp = castle.max_hp
		"repair":
			castle.regen += 2.0
