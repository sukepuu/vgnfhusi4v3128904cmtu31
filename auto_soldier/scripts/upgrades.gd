extends RefCounted
## レベルアップ時の強化一覧。ここに追加すれば3択の候補に出るようになる。
##   cat     : "soldier"（遊撃部隊）/ "builder"（築城部隊）/ "guard"（迎撃部隊）/ "castle"（城）
##   req     : この強化を取得済みでないと候補に出ない
##   req_any : このどれかを取得済みでないと候補に出ない
##   max     : 取得できる上限レベル
##   weight  : 候補に出やすさ（省略時 1.0）
##   desc_up : 2回目以降に表示する説明（省略時は desc）

const LIST := [
	# ---- 遊撃部隊
	{"id": "recruit", "cat": "soldier", "name": "遊撃兵を増員", "desc": "遊撃部隊の兵士が1人増える（最大5人）", "max": 3, "weight": 2.0},
	{"id": "multishot", "cat": "soldier", "name": "射撃数+1", "desc": "一度に撃つ弾が1発増える", "max": 5},
	{"id": "firerate", "cat": "soldier", "name": "速射", "desc": "射撃の間隔 -15%", "max": 5},
	{"id": "bullet_dmg", "cat": "soldier", "name": "強化弾", "desc": "射撃ダメージ +30%", "max": 5},
	{"id": "pierce", "cat": "soldier", "name": "貫通弾", "desc": "弾が敵をもう1体貫通する", "max": 3},
	{"id": "sword_dmg", "cat": "soldier", "name": "剣術", "desc": "斬撃ダメージ +35%", "max": 5},
	{"id": "sword_range", "cat": "soldier", "name": "大振り", "desc": "斬撃の範囲 +20%", "max": 4},
	{"id": "whirlwind", "cat": "soldier", "name": "回転斬り", "desc": "斬撃が全方位360度になる", "max": 1},
	{"id": "dash", "cat": "soldier", "name": "突進突き", "desc": "4秒ごとに敵へ突進して貫く（突進中は無敵）",
		"desc_up": "突進の間隔 -20%、威力 +30%", "max": 4},
	{"id": "pet", "cat": "soldier", "name": "ペットの仲間", "desc": "全遊撃兵にペットが1匹ずつ付き、自動で射撃してくれる（あとから増えた遊撃兵にも付く）",
		"desc_up": "全遊撃兵にペットがもう1匹ずつ付く、全ペットの攻撃力 +20%", "max": 4},
	{"id": "soldier_hp", "cat": "soldier", "name": "鍛錬", "desc": "遊撃兵の最大HP +25、全員HP全回復", "max": 4},
	{"id": "speed", "cat": "soldier", "name": "俊足", "desc": "遊撃兵の移動速度 +12%", "max": 3},
	# ---- 築城部隊
	{"id": "builder", "cat": "builder", "name": "築城部隊", "desc": "城の上側180度を囲むように、20秒ごとに壁を1枚建てる（壁1枚で敵の攻撃を10発防ぐ）",
		"desc_up": "築城部隊の作業員が1人増える（最大3人、それぞれ別の場所に壁を建てる）", "max": 3, "weight": 2.0},
	{"id": "build_speed", "cat": "builder", "name": "突貫工事", "desc": "壁の建築時間 -20%", "max": 4, "req": "builder"},
	{"id": "wall_hp", "cat": "builder", "name": "石壁強化", "desc": "壁が防げる回数 +5発（建っている壁にも反映）", "max": 5, "req": "builder"},
	{"id": "wall_width", "cat": "builder", "name": "大きな壁", "desc": "これから建てる壁の幅 +4度（少ない枚数で囲める）", "max": 3, "req": "builder"},
	# ---- 迎撃部隊
	{"id": "guard", "cat": "guard", "name": "迎撃部隊", "desc": "盾と槍を持ち、城の近くで敵を迎え撃つ兵士が加わる（前方からの攻撃は盾で無効）",
		"desc_up": "迎撃部隊の兵士が1人増える（最大3人）", "max": 3, "weight": 2.0},
	{"id": "shield_arc", "cat": "guard", "name": "大盾", "desc": "盾で防げる範囲 +20度", "max": 4, "req": "guard"},
	{"id": "guard_speed", "cat": "guard", "name": "機動訓練", "desc": "迎撃部隊の移動速度 +15%", "max": 3, "req": "guard"},
	{"id": "spear_reach", "cat": "guard", "name": "長槍", "desc": "槍のリーチ +25", "max": 4, "req": "guard"},
	{"id": "spear_dmg", "cat": "guard", "name": "槍術", "desc": "槍の攻撃力 +35%", "max": 5, "req": "guard"},
	# ---- 重装部隊
	{"id": "heavy", "cat": "heavy", "name": "重装部隊", "desc": "足は遅いが耐久力と攻撃力が高い重装兵が加わる。壁の中央の前に陣取り、近づく敵を斬撃で迎え撃つ", "max": 1, "weight": 1.5},
	# ---- 城
	{"id": "tower", "cat": "castle", "name": "矢倉", "desc": "城に矢倉が建ち、近づく敵を自動で射る",
		"desc_up": "矢倉をもう1基追加、全矢倉の威力 +15%", "max": 4, "weight": 1.5},
	{"id": "cannon", "cat": "castle", "name": "大砲", "desc": "敵が密集した場所へ砲弾を撃ち込む（範囲攻撃）",
		"desc_up": "大砲をもう1門追加（最大3門）", "max": 3, "weight": 1.3},
	{"id": "catapult", "cat": "castle", "name": "投石器", "desc": "大砲より広い範囲に岩を落とす（発射間隔は長い）",
		"desc_up": "投石器をもう1台追加（最大3台）", "max": 3},
	{"id": "ballista", "cat": "castle", "name": "バリスタ", "desc": "城にバリスタを設置。発射間隔は長いが、高威力・射程無限で敵を何体でも貫通する",
		"desc_up": "バリスタをもう1基追加（最大3基）", "max": 3},
	{"id": "artillery", "cat": "castle", "name": "砲術", "desc": "大砲と投石器の威力 +30%、発射間隔 -10%", "max": 4, "req_any": ["cannon", "catapult"]},
	{"id": "frost", "cat": "castle", "name": "氷結の結界", "desc": "城のまわりの敵の動きを遅くする",
		"desc_up": "結界の範囲が広がり、さらに遅くなる", "max": 3},
	{"id": "wall", "cat": "castle", "name": "城壁補強", "desc": "城の最大HP +100、城のHP全回復", "max": 5},
	{"id": "repair", "cat": "castle", "name": "修理工", "desc": "城のHPが毎秒2回復する", "max": 3},
]

const CAT_LABEL := {"soldier": "遊撃", "builder": "築城", "guard": "迎撃", "heavy": "重装", "castle": "城"}
const CAT_COLOR := {
	"soldier": Color(0.6, 0.85, 1.0), "builder": Color(1.0, 0.88, 0.45),
	"guard": Color(0.6, 1.0, 0.65), "heavy": Color(0.85, 0.75, 1.0), "castle": Color(1.0, 0.7, 0.45)}


## まだ上限に達していない強化から、出やすさに応じてランダムに n 個選ぶ
static func roll(levels: Dictionary, n: int, game: Node2D) -> Array:
	var available: Array = []
	for u in LIST:
		if levels.get(u["id"], 0) >= u["max"]:
			continue
		if u["id"] == "recruit" and game.soldiers.size() >= game.MAX_SOLDIERS:
			continue
		# 部隊がいないと出ない強化
		if u.has("req") and levels.get(u["req"], 0) <= 0:
			continue
		if u.has("req_any"):
			var ok := false
			for r in u["req_any"]:
				if levels.get(r, 0) > 0:
					ok = true
			if not ok:
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
				game.pet_damage *= 1.2
				for p in game.pets:
					p.damage = game.pet_damage
			game.add_pet()
		"soldier_hp":
			st.max_hp += 25.0
			for s in game.soldiers:
				if not s.dead:
					s.hp = st.max_hp
		"speed":
			st.move_speed *= 1.12
		"builder":
			game.add_builder()
		"build_speed":
			game.walls.build_time *= 0.8
		"wall_hp":
			game.walls.add_wall_hp(5.0)
		"wall_width":
			game.walls.wall_width += deg_to_rad(4.0)
		"guard":
			game.add_guard()
		"shield_arc":
			game.guard_stats.shield_arc += deg_to_rad(20.0)
		"guard_speed":
			game.guard_stats.move_speed *= 1.15
		"spear_reach":
			game.guard_stats.spear_reach += 25.0
		"spear_dmg":
			game.guard_stats.spear_damage *= 1.35
		"catapult":
			castle.catapult_level = new_level
		"ballista":
			castle.ballista_level = new_level
		"artillery":
			castle.cannon_damage *= 1.3
			castle.catapult_damage *= 1.3
			castle.cannon_interval *= 0.9
			castle.catapult_interval *= 0.9
		"heavy":
			game.add_heavy()
		"tower":
			castle.tower_count = new_level
			if new_level > 1:
				castle.tower_damage *= 1.15
		"cannon":
			castle.cannon_level = new_level
		"frost":
			castle.frost_radius = 220.0 + 60.0 * new_level
			castle.frost_slow = 0.25 + 0.1 * new_level
		"wall":
			castle.max_hp += 100.0
			castle.hp = castle.max_hp
		"repair":
			castle.regen += 2.0
