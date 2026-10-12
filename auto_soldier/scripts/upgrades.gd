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
	{"id": "heavy_dmg", "cat": "heavy", "name": "剛剣", "desc": "重装兵の斬撃の威力 +35%", "max": 5, "req": "heavy"},
	{"id": "heavy_haste", "cat": "heavy", "name": "連撃", "desc": "重装兵の斬撃の間隔 -15%", "max": 4, "req": "heavy"},
	{"id": "heavy_range", "cat": "heavy", "name": "大薙ぎ", "desc": "重装兵の斬撃の範囲 +20%", "max": 4, "req": "heavy"},
	{"id": "heavy_hp", "cat": "heavy", "name": "重鎧", "desc": "重装兵の最大HP +40%、HP全回復、自然回復 +3/秒", "max": 4, "req": "heavy"},
	{"id": "heavy_speed", "cat": "heavy", "name": "軽量化", "desc": "重装兵の移動速度 +20%、持ち場から離れて戦える距離 +40", "max": 3, "req": "heavy"},
	{"id": "heavy_whirl", "cat": "heavy", "name": "旋風斬り", "desc": "重装兵の斬撃が全方位360度になる", "max": 1, "req": "heavy"},
	# ---- 工兵部隊
	{"id": "engineer", "cat": "engineer", "name": "工兵部隊", "desc": "フィールドを回って、爆弾（範囲ダメージ）と落とし穴（範囲ダメージ＋10秒足止め）を交互に仕掛ける工兵が加わる",
		"desc_up": "工兵が1人増える（最大2人）", "max": 2, "weight": 1.5},
	{"id": "trap_dmg", "cat": "engineer", "name": "高性能火薬", "desc": "爆弾と落とし穴の威力 +40%（仕掛け済みの罠にも反映）", "max": 5, "req": "engineer"},
	{"id": "trap_speed", "cat": "engineer", "name": "手際", "desc": "罠の設置時間 -20%、工兵の移動速度 +15%", "max": 4, "req": "engineer"},
	{"id": "trap_range", "cat": "engineer", "name": "広域罠", "desc": "罠の効果範囲 +20%、反応する距離 +15%", "max": 3, "req": "engineer"},
	{"id": "pit_stun", "cat": "engineer", "name": "深い落とし穴", "desc": "落とし穴の足止め時間 +3秒", "max": 3, "req": "engineer"},
	# ---- 城
	{"id": "tower", "cat": "castle", "name": "矢倉", "desc": "城に矢倉が建ち、近づく敵を自動で射る",
		"desc_up": "矢倉をもう1基追加、全矢倉の威力 +15%", "max": 4, "weight": 1.5},
	{"id": "cannon", "cat": "castle", "name": "大砲", "desc": "敵が密集した場所へ砲弾を撃ち込む（範囲攻撃）",
		"desc_up": "大砲をもう1門追加（最大3門）", "max": 3, "weight": 1.3},
	{"id": "catapult", "cat": "castle", "name": "投石器", "desc": "大砲より広い範囲に岩を落とす（発射間隔は長い）",
		"desc_up": "投石器をもう1台追加（最大3台）", "max": 3},
	{"id": "ballista", "cat": "castle", "name": "バリスタ", "desc": "城にバリスタを設置。発射間隔は長いが、高威力・射程無限で敵を何体でも貫通する",
		"desc_up": "バリスタをもう1基追加、全バリスタの威力 +30%（最大3基）", "max": 3},
	{"id": "artillery", "cat": "castle", "name": "砲術", "desc": "大砲と投石器の威力 +30%、発射間隔 -10%", "max": 4, "req_any": ["cannon", "catapult"]},
	{"id": "frost", "cat": "castle", "name": "氷結の結界", "desc": "城のまわりの敵の動きを遅くする",
		"desc_up": "結界の範囲が広がり、さらに遅くなる", "max": 3},
	{"id": "wall", "cat": "castle", "name": "城壁補強", "desc": "城の最大HP +100、城のHP全回復", "max": 5},
	{"id": "repair", "cat": "castle", "name": "修理工", "desc": "城のHPが毎秒2回復する", "max": 3},
]

## Lv5ごとに出る特別強化。部隊・設備の種類ごとに5つずつ。どれも1回取れば完成（レベルなし）。
## req = この強化（部隊・設備）を持っていないと出ない（なければ誰でも）
const SPECIAL := [
	# ---- 遊撃部隊
	{"id": "sp_burst", "cat": "soldier", "special": true, "name": "炸裂弾", "desc": "遊撃兵の弾が当たると小爆発する（威力55%）", "max": 1},
	{"id": "sp_volley", "cat": "soldier", "special": true, "name": "一斉射撃", "desc": "6秒ごとに全方位へ18発の弾をばらまく", "max": 1},
	{"id": "sp_sword_wave", "cat": "soldier", "special": true, "name": "剣気", "desc": "斬撃と一緒に、敵を貫く三日月形の衝撃波が飛ぶ", "max": 1},
	{"id": "sp_shadow", "cat": "soldier", "special": true, "name": "影分身", "desc": "遊撃兵の横に半透明の分身が現れ、一緒に弾を撃つ（威力50%）", "max": 1},
	{"id": "sp_boomerang", "cat": "soldier", "special": true, "name": "ブーメラン", "desc": "3.5秒ごとにブーメランを投げる。行きと帰りで敵を貫く（剣の1.3倍の威力）", "max": 1},
	# ---- 迎撃部隊
	{"id": "sp_bash", "cat": "guard", "special": true, "name": "盾撃", "desc": "盾で攻撃を防ぐたびに、周りの敵へ衝撃波（槍の1.3倍の威力）", "max": 1, "req": "guard"},
	{"id": "sp_trident", "cat": "guard", "special": true, "name": "三叉槍", "desc": "槍の突きが3方向に出る", "max": 1, "req": "guard"},
	{"id": "sp_taunt", "cat": "guard", "special": true, "name": "挑発", "desc": "近くの敵が城より迎撃兵を狙うようになる（正面から来れば盾で無効）", "max": 1, "req": "guard"},
	{"id": "sp_whirl_spear", "cat": "guard", "special": true, "name": "大旋風槍", "desc": "6秒ごとに槍を振り回し、周りの敵へ槍の3倍の大ダメージ", "max": 1, "req": "guard"},
	{"id": "sp_spikes", "cat": "guard", "special": true, "name": "拒馬の柵", "desc": "8秒ごとに盾の前へトゲの柵を置く。上を通る敵の足を止めてダメージ（14秒残る）", "max": 1, "req": "guard"},
	# ---- 重装部隊
	{"id": "sp_multi_slash", "cat": "heavy", "special": true, "name": "連続斬り", "desc": "斬撃が3回連続で出る", "max": 1, "req": "heavy"},
	{"id": "sp_quake", "cat": "heavy", "special": true, "name": "地割れ", "desc": "5秒ごとに地面を叩き、周りの敵に大ダメージ＋3.5秒気絶", "max": 1, "req": "heavy"},
	{"id": "sp_lifesteal", "cat": "heavy", "special": true, "name": "吸命の剣", "desc": "斬撃で与えたダメージの10%ぶんHPが回復する", "max": 1, "req": "heavy"},
	{"id": "sp_execute", "cat": "heavy", "special": true, "name": "一刀両断", "desc": "4秒ごとに、近くで一番HPの多い敵へ斬撃6倍の一撃", "max": 1, "req": "heavy"},
	{"id": "sp_iron_ball", "cat": "heavy", "special": true, "name": "鉄球投げ", "desc": "5秒ごとにトゲ鉄球を投げる。転がりながら敵をひいて吹き飛ばす（斬撃1.5倍の威力）", "max": 1, "req": "heavy"},
	# ---- 築城部隊
	{"id": "sp_wall_turret", "cat": "builder", "special": true, "name": "砲台壁", "desc": "壁から近くの敵へ弾が発射されるようになる", "max": 1, "req": "builder"},
	{"id": "sp_wall_repair", "cat": "builder", "special": true, "name": "自己修復", "desc": "壁が3秒ごとに1発分ずつ回復する", "max": 1, "req": "builder"},
	{"id": "sp_wall_blast", "cat": "builder", "special": true, "name": "爆裂壁", "desc": "壁が攻撃を防ぐたびに、その場で爆発して周りの敵にダメージ", "max": 1, "req": "builder"},
	{"id": "sp_golden_wall", "cat": "builder", "special": true, "name": "黄金の壁", "desc": "壁が攻撃を防ぐたびに経験値が1入る", "max": 1, "req": "builder"},
	{"id": "sp_watchtower", "cat": "builder", "special": true, "name": "見張り櫓", "desc": "築城兵が壁の外に見張り櫓を建てる（最大4基）。櫓は近くの敵へ矢を撃ち続ける", "max": 1, "req": "builder"},
	# ---- 工兵部隊
	{"id": "sp_cluster", "cat": "engineer", "special": true, "name": "子爆弾", "desc": "爆弾が爆発すると、周りに小爆弾が6個散らばって爆発する", "max": 1, "req": "engineer"},
	{"id": "sp_poison", "cat": "engineer", "special": true, "name": "毒沼", "desc": "作動した落とし穴の跡が9秒間、毒の沼になる", "max": 1, "req": "engineer"},
	{"id": "sp_double_plant", "cat": "engineer", "special": true, "name": "二重設置", "desc": "1回で爆弾と落とし穴を両方仕掛ける（罠の上限も30個に）", "max": 1, "req": "engineer"},
	{"id": "sp_ap_mine", "cat": "engineer", "special": true, "name": "徹甲地雷", "desc": "爆弾の真上近くにいる敵1体に、追加で爆弾4倍のダメージ", "max": 1, "req": "engineer"},
	{"id": "sp_sentry", "cat": "engineer", "special": true, "name": "自動砲台", "desc": "罠と一緒に自動砲台を置く（30秒間、近くの敵を連射。工兵1人につき2台まで）", "max": 1, "req": "engineer"},
	# ---- 矢倉
	{"id": "sp_tower_multi", "cat": "castle", "special": true, "name": "矢倉・連射", "desc": "矢倉が一度に3本の矢を放つ", "max": 1, "req": "tower"},
	{"id": "sp_tower_ap", "cat": "castle", "special": true, "name": "矢倉・徹甲矢", "desc": "矢倉の矢が敵を3体貫通し、威力 +60%", "max": 1, "req": "tower"},
	{"id": "sp_tower_crit", "cat": "castle", "special": true, "name": "矢倉・会心の一矢", "desc": "矢倉の矢が25%の確率でダメージ3倍、射程 +40%", "max": 1, "req": "tower"},
	{"id": "sp_arrow_rain", "cat": "castle", "special": true, "name": "矢倉・火矢の雨", "desc": "7秒ごとに、矢倉1基につき1か所、敵が密集した所へ矢の雨が降る（範囲大ダメージ）", "max": 1, "req": "tower"},
	{"id": "sp_homing", "cat": "castle", "special": true, "name": "矢倉・追尾火矢", "desc": "3秒ごとに、矢倉1基につき2本、敵を追いかける火矢を放つ（当たると小爆発）", "max": 1, "req": "tower"},
	# ---- 大砲
	{"id": "sp_scatter", "cat": "castle", "special": true, "name": "大砲・散弾砲", "desc": "砲弾が分裂して、着弾地点の周りにも4発落ちる", "max": 1, "req": "cannon"},
	{"id": "sp_incendiary", "cat": "castle", "special": true, "name": "大砲・焼夷弾", "desc": "着弾地点が6秒間燃え続ける", "max": 1, "req": "cannon"},
	{"id": "sp_rapid_cannon", "cat": "castle", "special": true, "name": "大砲・速射砲", "desc": "大砲の発射間隔 -40%", "max": 1, "req": "cannon"},
	{"id": "sp_ap_shell", "cat": "castle", "special": true, "name": "大砲・徹甲榴弾", "desc": "6秒ごとに、大砲1門につき1発、一番HPの多い敵へ8倍ダメージの直射弾（間にいる敵はすり抜けて、狙った敵を追いかける）", "max": 1, "req": "cannon"},
	{"id": "sp_mines", "cat": "castle", "special": true, "name": "大砲・機雷散布", "desc": "砲弾が着弾地点のまわりに機雷を3個ばらまく。敵が触れると爆発（20秒残る）", "max": 1, "req": "cannon"},
	# ---- 投石器
	{"id": "sp_big_rock", "cat": "castle", "special": true, "name": "投石器・大岩", "desc": "岩の範囲 +40%・威力 +80%", "max": 1, "req": "catapult"},
	{"id": "sp_split_rock", "cat": "castle", "special": true, "name": "投石器・分裂岩", "desc": "着弾した岩が砕けて、周りに6個の岩が落ちる", "max": 1, "req": "catapult"},
	{"id": "sp_rock_rain", "cat": "castle", "special": true, "name": "投石器・岩雨", "desc": "撃つたびに、ランダムな敵2体の頭上にも岩が落ちる", "max": 1, "req": "catapult"},
	{"id": "sp_direct_hit", "cat": "castle", "special": true, "name": "投石器・巨岩直撃", "desc": "着弾地点の真ん中にいる敵1体に、追加で4倍ダメージ", "max": 1, "req": "catapult"},
	{"id": "sp_rolling", "cat": "castle", "special": true, "name": "投石器・転がり岩", "desc": "着弾した岩がそのまま城と反対の方へ転がり、敵をひいていく", "max": 1, "req": "catapult"},
	# ---- バリスタ
	{"id": "sp_ballista_multi", "cat": "castle", "special": true, "name": "バリスタ・連装", "desc": "バリスタが一度に3発撃つ", "max": 1, "req": "ballista"},
	{"id": "sp_ballista_blast", "cat": "castle", "special": true, "name": "バリスタ・爆裂ボルト", "desc": "貫いた敵ごとに小爆発が起きる（威力45%）", "max": 1, "req": "ballista"},
	{"id": "sp_big_bolt", "cat": "castle", "special": true, "name": "バリスタ・大型弩", "desc": "矢が大きくなって当たり判定が広がり、威力 +50%", "max": 1, "req": "ballista"},
	{"id": "sp_blast_bolt", "cat": "castle", "special": true, "name": "バリスタ・炸裂大矢", "desc": "矢が最初に当たった敵の場所で大爆発（威力150%の範囲攻撃）", "max": 1, "req": "ballista"},
	{"id": "sp_lightning", "cat": "castle", "special": true, "name": "バリスタ・雷撃", "desc": "5秒ごとに、バリスタ1基につき1本、敵から敵へ7回飛び移る雷を放つ（威力80%）", "max": 1, "req": "ballista"},
	# ---- 氷結の結界
	{"id": "sp_freeze", "cat": "castle", "special": true, "name": "結界・絶対零度", "desc": "8秒ごとに結界内の敵すべてを3.5秒間凍らせる", "max": 1, "req": "frost"},
	{"id": "sp_icicle", "cat": "castle", "special": true, "name": "結界・氷柱", "desc": "1.5秒ごとに結界内の敵2体へ氷柱が降る", "max": 1, "req": "frost"},
	{"id": "sp_blizzard", "cat": "castle", "special": true, "name": "結界・吹雪", "desc": "結界の中の敵にずっとダメージを与え続ける", "max": 1, "req": "frost"},
	{"id": "sp_ice_lance", "cat": "castle", "special": true, "name": "結界・氷槍", "desc": "3秒ごとに、結界内で一番HPの多い敵へ大ダメージの氷の槍", "max": 1, "req": "frost"},
	{"id": "sp_snowman", "cat": "castle", "special": true, "name": "結界・雪だるま", "desc": "5秒ごとに結界のふちへ雪だるまを置く（最大6体）。敵が近づくと爆発して周りを凍らせる", "max": 1, "req": "frost"},
]

const CAT_LABEL := {"soldier": "遊撃", "builder": "築城", "guard": "迎撃", "heavy": "重装", "engineer": "工兵", "castle": "城"}
const CAT_COLOR := {
	"soldier": Color(0.6, 0.85, 1.0), "builder": Color(1.0, 0.88, 0.45),
	"guard": Color(0.6, 1.0, 0.65), "heavy": Color(0.85, 0.75, 1.0), "engineer": Color(0.8, 0.9, 0.5), "castle": Color(1.0, 0.7, 0.45)}


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


## 特別強化から n 個選ぶ（持っている部隊・設備のものだけ）
static func roll_special(levels: Dictionary, n: int) -> Array:
	var available: Array = []
	for u in SPECIAL:
		if levels.get(u["id"], 0) >= u["max"]:
			continue
		if u.has("req") and levels.get(u["req"], 0) <= 0:
			continue
		available.append(u)
	available.shuffle()
	return available.slice(0, n)


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
			if new_level > 1:
				castle.ballista_damage *= 1.3
		"artillery":
			castle.cannon_damage *= 1.3
			castle.catapult_damage *= 1.3
			castle.cannon_interval *= 0.9
			castle.catapult_interval *= 0.9
		"heavy":
			game.add_heavy()
		"engineer":
			game.add_engineer()
		"heavy_dmg":
			game.heavy.slash_damage *= 1.35
		"heavy_haste":
			game.heavy.slash_interval *= 0.85
		"heavy_range":
			game.heavy.slash_radius *= 1.2
		"heavy_hp":
			game.heavy.max_hp *= 1.4
			game.heavy.regen += 3.0
			if not game.heavy.dead:
				game.heavy.hp = game.heavy.max_hp
		"heavy_speed":
			game.heavy.move_speed *= 1.2
			game.heavy.leash += 40.0
		"heavy_whirl":
			game.heavy.slash_arc = TAU
		"trap_dmg":
			game.engineer_stats.bomb_damage *= 1.4
			game.engineer_stats.pit_damage *= 1.4
		"trap_speed":
			game.engineer_stats.plant_time *= 0.8
			game.engineer_stats.move_speed *= 1.15
		"trap_range":
			game.engineer_stats.bomb_radius *= 1.2
			game.engineer_stats.pit_radius *= 1.2
			game.engineer_stats.trigger_radius *= 1.15
		"pit_stun":
			game.engineer_stats.stun_time += 3.0
		# ---- 特別強化（1回きり。効果の中身はそれぞれのスクリプトが処理する）
		"sp_burst":
			st.burst_level = 2
		"sp_volley":
			st.volley_level = 2
		"sp_sword_wave":
			st.sword_wave = true
		"sp_bash":
			game.guard_stats.bash_level = 2
		"sp_trident":
			game.guard_stats.trident_level = 1
		"sp_taunt":
			game.guard_stats.taunt = true
		"sp_multi_slash":
			game.heavy.extra_slashes = 2
		"sp_quake":
			game.heavy.quake_level = 2
		"sp_lifesteal":
			game.heavy.lifesteal = 0.1
		"sp_wall_turret":
			game.walls.turret_level = 2
		"sp_wall_repair":
			game.walls.repair_level = 2
		"sp_wall_blast":
			game.walls.explode_on_block = true
		"sp_cluster":
			game.engineer_stats.cluster_level = 2
		"sp_poison":
			game.engineer_stats.poison_level = 2
		"sp_double_plant":
			game.engineer_stats.double_plant = true
		"sp_tower_multi":
			castle.tower_shots = 3
		"sp_tower_ap":
			castle.tower_pierce += 3
			castle.tower_damage *= 1.6
		"sp_tower_crit":
			castle.tower_crit = true
			castle.tower_range *= 1.4
		"sp_scatter":
			castle.scatter_level = 2
		"sp_incendiary":
			castle.fire_level = 2
		"sp_rapid_cannon":
			castle.cannon_interval *= 0.6
		"sp_big_rock":
			castle.catapult_radius *= 1.4
			castle.catapult_damage *= 1.8
		"sp_split_rock":
			castle.split_level = 2
		"sp_rock_rain":
			castle.rock_rain = true
		"sp_ballista_multi":
			castle.ballista_shots = 3
		"sp_ballista_blast":
			castle.bolt_blast_level = 2
		"sp_big_bolt":
			castle.big_bolt = true
			castle.ballista_damage *= 1.5
		"sp_freeze":
			castle.freeze_level = 2
		"sp_icicle":
			castle.icicle_level = 2
		"sp_blizzard":
			castle.blizzard = true
		"sp_shadow":
			st.shadow = true
		"sp_whirl_spear":
			game.guard_stats.whirl = true
		"sp_execute":
			game.heavy.execute = true
		"sp_golden_wall":
			game.walls.golden = true
		"sp_ap_mine":
			game.engineer_stats.ap_mine = true
		"sp_arrow_rain":
			castle.arrow_rain = true
		"sp_ap_shell":
			castle.ap_shell = true
		"sp_direct_hit":
			castle.direct_hit = true
		"sp_blast_bolt":
			castle.blast_bolt = true
		"sp_ice_lance":
			castle.ice_lance = true
		"sp_boomerang":
			st.boomerang = true
		"sp_spikes":
			game.guard_stats.spikes = true
		"sp_iron_ball":
			game.heavy.iron_ball = true
		"sp_watchtower":
			game.walls.watchtower = true
		"sp_sentry":
			game.engineer_stats.sentry = true
		"sp_homing":
			castle.homing_arrow = true
		"sp_mines":
			castle.cannon_mines = true
		"sp_rolling":
			castle.rolling_rock = true
		"sp_lightning":
			castle.lightning = true
		"sp_snowman":
			castle.snowman = true
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
