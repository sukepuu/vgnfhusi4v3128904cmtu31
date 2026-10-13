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
	{"id": "spear_reach", "cat": "guard", "name": "長槍", "desc": "槍のリーチ +25", "max": 4, "req": "guard"},
	{"id": "spear_dmg", "cat": "guard", "name": "槍術", "desc": "槍の攻撃力 +35%", "max": 5, "req": "guard"},
	# 【ペット】（ペットの仲間を取ると出る）
	{"id": "pet_rate", "cat": "pet", "name": "早撃ちペット", "desc": "ペットの射撃の間隔 -15%", "max": 4, "req": "pet"},
	{"id": "pet_fang", "cat": "pet", "name": "ペットの牙", "desc": "ペットの弾の威力 +30%", "max": 5, "req": "pet"},
	{"id": "pet_eye", "cat": "pet", "name": "ペットの目", "desc": "ペットの射程 +20%", "max": 3, "req": "pet"},
	{"id": "pet_multi", "cat": "pet", "name": "連射ペット", "desc": "ペットが一度に撃つ弾 +1発", "max": 3, "req": "pet"},
	# 【近衛】
	{"id": "knight", "cat": "knight", "name": "近衛部隊", "desc": "フィールドの一番下にいる敵を最優先で狙い、近くから一直線に高速突進して貫く騎士が加わる（隠密兵を1発で倒せる威力）",
		"desc_up": "近衛部隊の騎士が1人増える（最大3人）", "max": 3, "weight": 1.5},
	{"id": "knight_dmg", "cat": "knight", "name": "剛突", "desc": "突進の威力 +35%", "max": 5, "req": "knight"},
	{"id": "knight_rate", "cat": "knight", "name": "疾駆", "desc": "突進の間隔 -15%", "max": 4, "req": "knight"},
	{"id": "knight_reach", "cat": "knight", "name": "長駆", "desc": "突進で進む距離 +25%", "max": 3, "req": "knight"},
	# 【修理】
	{"id": "repairer", "cat": "repair", "name": "修理部隊", "desc": "城のまわりで修理をして、城のHPを毎秒3回復する修理兵が加わる",
		"desc_up": "修理兵が1人増える（最大3人）", "max": 3, "weight": 1.8},
	{"id": "repair_skill", "cat": "repair", "name": "熟練工", "desc": "修理兵1人あたりの回復量 +1/秒", "max": 3, "req": "repairer"},
	# 【狙撃】
	{"id": "sniper", "cat": "sniper", "name": "狙撃部隊", "desc": "迎撃部隊の後ろに立ち、遠距離型の敵（弓兵・迫撃砲）を優先して弓で狙い撃つ狙撃兵が加わる",
		"desc_up": "狙撃部隊の狙撃兵が1人増える（最大3人）", "max": 3, "weight": 1.6},
	{"id": "sniper_rate", "cat": "sniper", "name": "早撃ち", "desc": "狙撃兵が矢を放つ間隔 -15%", "max": 4, "req": "sniper"},
	{"id": "sniper_multi", "cat": "sniper", "name": "多連矢", "desc": "一度に放つ矢 +1本", "max": 3, "req": "sniper"},
	{"id": "sniper_dmg", "cat": "sniper", "name": "強弓", "desc": "矢の威力 +35%", "max": 5, "req": "sniper"},
	{"id": "sniper_pierce", "cat": "sniper", "name": "貫き矢", "desc": "矢が敵をもう1体貫通する", "max": 3, "req": "sniper"},
	# ---- 重装部隊
	{"id": "heavy", "cat": "heavy", "name": "重装部隊", "desc": "足は遅いが耐久力と攻撃力が高い重装兵が加わる。マップ内を自由に歩き回り、マップの真ん中に一番近い敵を最優先で斬りに行く", "max": 1, "weight": 1.5},
	{"id": "heavy_dmg", "cat": "heavy", "name": "剛剣", "desc": "重装兵の斬撃の威力 +35%", "max": 5, "req": "heavy"},
	{"id": "heavy_haste", "cat": "heavy", "name": "連撃", "desc": "重装兵の斬撃の間隔 -15%", "max": 4, "req": "heavy"},
	{"id": "heavy_range", "cat": "heavy", "name": "大薙ぎ", "desc": "重装兵の斬撃の範囲 +20%", "max": 4, "req": "heavy"},
	{"id": "heavy_hp", "cat": "heavy", "name": "重鎧", "desc": "重装兵の最大HP +40%、HP全回復、自然回復 +3/秒", "max": 4, "req": "heavy"},
	{"id": "heavy_speed", "cat": "heavy", "name": "軽量化", "desc": "重装兵の移動速度 +20%", "max": 3, "req": "heavy"},
	{"id": "heavy_whirl", "cat": "heavy", "name": "旋風斬り", "desc": "重装兵の斬撃が全方位360度になる", "max": 1, "req": "heavy"},
	# ---- 工兵部隊
	{"id": "engineer", "cat": "engineer", "name": "工兵部隊", "desc": "フィールドを回って、爆弾（範囲ダメージ）と落とし穴（範囲ダメージ＋10秒足止め）を交互に仕掛ける工兵が加わる",
		"desc_up": "工兵が1人増える（最大3人）", "max": 3, "weight": 1.5},
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
	{"id": "ballista", "cat": "castle", "name": "バリスタ", "desc": "城にバリスタを設置。HPが一番多い敵を最優先で狙う。発射間隔は長いが、高威力・射程無限で敵を何体でも貫通する",
		"desc_up": "バリスタをもう1基追加、全バリスタの威力 +30%（最大3基）", "max": 3},
	{"id": "artillery", "cat": "castle", "name": "砲術", "desc": "大砲と投石器の威力 +30%、発射間隔 -10%", "max": 4, "req_any": ["cannon", "catapult"]},
	{"id": "frost", "cat": "castle", "name": "氷結の結界", "desc": "城のまわりの敵の動きを遅くする",
		"desc_up": "結界の範囲が広がり、さらに遅くなる", "max": 3},
	{"id": "wall", "cat": "castle", "name": "城壁補強", "desc": "城の最大HP +100、城のHP全回復", "max": 5},
]

## Lv5ごとに出る特別強化。部隊・設備の種類ごとに5つずつ。どれも1回取れば完成（レベルなし）。
## req = この強化（部隊・設備）を持っていないと出ない（なければ誰でも）
const SPECIAL := [
	# ---- 遊撃部隊
	{"id": "sp_burst", "cat": "soldier", "special": true, "name": "炸裂弾", "desc": "遊撃兵の弾が当たると小爆発する（威力55%）", "max": 1},
	{"id": "sp_volley", "cat": "soldier", "special": true, "name": "一斉射撃", "desc": "6秒ごとに全方位へ18発の弾をばらまく", "max": 1},
	{"id": "sp_sword_wave", "cat": "soldier", "special": true, "name": "剣気", "desc": "斬撃と一緒に、敵を貫く大きな三日月形の衝撃波がゆっくり飛ぶ", "max": 1},
	{"id": "sp_shadow", "cat": "soldier", "special": true, "name": "影分身", "desc": "遊撃兵の横に半透明の分身が現れ、一緒に弾を撃つ（威力50%）", "max": 1},
	{"id": "sp_boomerang", "cat": "soldier", "special": true, "name": "ブーメラン", "desc": "3.5秒ごとにブーメランを投げる。行きと帰りで敵を貫く（剣の1.3倍の威力）", "max": 1},
	# ---- 迎撃部隊
	{"id": "sp_bash", "cat": "guard", "special": true, "name": "盾撃", "desc": "盾で攻撃を防ぐたびに、周りの敵へ衝撃波（槍の1.3倍の威力）", "max": 1, "req": "guard"},
	{"id": "sp_trident", "cat": "guard", "special": true, "name": "三叉槍", "desc": "槍の突きが3方向に出る", "max": 1, "req": "guard"},
	{"id": "sp_taunt", "cat": "guard", "special": true, "name": "挑発", "desc": "近くの敵が城より迎撃兵を狙うようになる（正面から来れば盾で無効）", "max": 1, "req": "guard"},
	{"id": "sp_whirl_spear", "cat": "guard", "special": true, "name": "大旋風槍", "desc": "6秒ごとに槍を振り回し、周りの敵へ槍の3倍の大ダメージ", "max": 1, "req": "guard"},
	{"id": "sp_spikes", "cat": "guard", "special": true, "name": "拒馬の柵", "desc": "8秒ごとに盾の前へトゲの柵を置く。上を通る敵の足を止めてダメージ（8秒残る）", "max": 1, "req": "guard"},
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
	{"id": "sp_watchtower", "cat": "builder", "special": true, "name": "見張り櫓", "desc": "築城兵が壁の内側に見張り櫓を建てる（最大4基）。櫓は近くの敵へ矢を撃ち続ける", "max": 1, "req": "builder"},
	# ---- 工兵部隊
	{"id": "sp_cluster", "cat": "engineer", "special": true, "name": "子爆弾", "desc": "爆弾が爆発すると、周りに小爆弾が6個散らばって爆発する", "max": 1, "req": "engineer"},
	{"id": "sp_poison", "cat": "engineer", "special": true, "name": "毒沼", "desc": "作動した落とし穴の跡が9秒間、毒の沼になる", "max": 1, "req": "engineer"},
	{"id": "sp_double_plant", "cat": "engineer", "special": true, "name": "二重設置", "desc": "1回で爆弾と落とし穴を両方仕掛ける（罠の上限も30個に）", "max": 1, "req": "engineer"},
	{"id": "sp_ap_mine", "cat": "engineer", "special": true, "name": "徹甲地雷", "desc": "爆弾の真上近くにいる敵1体に、追加で爆弾4倍のダメージ", "max": 1, "req": "engineer"},
	{"id": "sp_sentry", "cat": "engineer", "special": true, "name": "自動砲台", "desc": "罠と一緒に自動砲台を置く（30秒間、近くの敵を連射。工兵1人につき3台まで）", "max": 1, "req": "engineer"},
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
	{"id": "sp_freeze", "cat": "castle", "special": true, "name": "結界・絶対零度", "desc": "10秒ごとに結界内の敵すべてを3.5秒間凍らせる", "max": 1, "req": "frost"},
	{"id": "sp_icicle", "cat": "castle", "special": true, "name": "結界・氷柱", "desc": "1.5秒ごとに結界内の敵2体へ氷柱が降る", "max": 1, "req": "frost"},
	{"id": "sp_blizzard", "cat": "castle", "special": true, "name": "結界・吹雪", "desc": "結界の中の敵にずっとダメージを与え続ける", "max": 1, "req": "frost"},
	{"id": "sp_ice_lance", "cat": "castle", "special": true, "name": "結界・氷槍", "desc": "3秒ごとに、結界内で一番HPの多い敵へ大ダメージの氷の槍", "max": 1, "req": "frost"},
	{"id": "sp_snowman", "cat": "castle", "special": true, "name": "結界・雪だるま", "desc": "5秒ごとに結界のふちへ雪だるまを置く（最大6体）。敵が近づくと爆発して周りを凍らせる", "max": 1, "req": "frost"},
	# ---- 狙撃
	{"id": "sp_counter_battery", "cat": "sniper", "special": true, "name": "対砲兵狙撃", "desc": "迫撃砲を最優先で狙う。遠くの敵ほど矢が痛い（100離れるごとに威力 +10%）", "max": 1, "req": "sniper"},
	{"id": "sp_headshot", "cat": "sniper", "special": true, "name": "急所狙い", "desc": "25%の確率で急所に当たり、ダメージ4倍", "max": 1, "req": "sniper"},
	{"id": "sp_pin", "cat": "sniper", "special": true, "name": "縫い止め矢", "desc": "当たった敵を1.5秒間その場に縫い止める（動けない・攻撃できない）", "max": 1, "req": "sniper"},
	{"id": "sp_ricochet", "cat": "sniper", "special": true, "name": "跳弾矢", "desc": "狙った敵に当たった矢が、近くの別の敵へ最大3回跳ねる（跳ねるたびに威力70%）", "max": 1, "req": "sniper"},
	{"id": "sp_mark", "cat": "sniper", "special": true, "name": "弱点看破", "desc": "矢が当たった敵に赤い印。6秒間、味方全員から受けるダメージ +35%", "max": 1, "req": "sniper"},
	# ---- ペット・近衛・修理
	{"id": "sp_pet_burst", "cat": "pet", "special": true, "name": "爆裂ペット弾", "desc": "ペットの弾が当たると小爆発する（威力60%）", "max": 1, "req": "pet"},
	{"id": "sp_pet_giant", "cat": "pet", "special": true, "name": "巨大ペット", "desc": "ペットが大きくなり、弾も大きく2体貫通、威力 +40%", "max": 1, "req": "pet"},
	{"id": "sp_pet_homing", "cat": "pet", "special": true, "name": "追尾ペット弾", "desc": "ペットの弾が、近くの敵の方へ曲がって追いかける", "max": 1, "req": "pet"},
	{"id": "sp_pet_frost", "cat": "pet", "special": true, "name": "凍える羽根", "desc": "ペットの弾が氷になり、当たった敵が0.4秒止まる", "max": 1, "req": "pet"},
	{"id": "sp_pet_heal", "cat": "pet", "special": true, "name": "癒しのさえずり", "desc": "ペット1匹につき、担当の遊撃兵のHPが毎秒2回復する", "max": 1, "req": "pet"},
	{"id": "sp_chain_dash", "cat": "knight", "special": true, "name": "連続突撃", "desc": "突進のあと、近くのまだ貫いていない敵へ続けて2回まで突進する", "max": 1, "req": "knight"},
	{"id": "sp_dash_quake", "cat": "knight", "special": true, "name": "突撃の衝撃", "desc": "突進が止まった所で爆発が起きる（突進の60%の威力）", "max": 1, "req": "knight"},
	{"id": "sp_knight_stun", "cat": "knight", "special": true, "name": "衝撃の槍", "desc": "突進で貫いた敵を1秒間気絶させる", "max": 1, "req": "knight"},
	{"id": "sp_knight_heal", "cat": "knight", "special": true, "name": "勇猛の突撃", "desc": "突進で敵を1体貫くたびに、近衛兵のHPが8回復する", "max": 1, "req": "knight"},
	{"id": "sp_knight_execute", "cat": "knight", "special": true, "name": "とどめの一撃", "desc": "HPが2割以下の敵（ボス以外）は、突進で一撃で倒す", "max": 1, "req": "knight"},
	{"id": "sp_first_aid", "cat": "repair", "special": true, "name": "応急手当", "desc": "フィールド全体の味方（遊撃・迎撃・近衛・重装）のHPも、修理兵が城を直すのと同じ量だけ回復する", "max": 1, "req": "repairer"},
	{"id": "sp_emergency", "cat": "repair", "special": true, "name": "緊急修理", "desc": "城のHPが3割より少ないとき、修理の速さが2倍になる", "max": 1, "req": "repairer"},
	{"id": "sp_armor", "cat": "repair", "special": true, "name": "鉄壁補強", "desc": "城が受けるダメージ -10%", "max": 1, "req": "repairer"},
	{"id": "sp_maintenance", "cat": "repair", "special": true, "name": "設備点検", "desc": "城の設備（矢倉・大砲・投石器・バリスタ）の発射間隔 -15%", "max": 1, "req": "repairer"},
	{"id": "sp_wall_fix", "cat": "repair", "special": true, "name": "壁職人", "desc": "修理兵が城と一緒に壁も直す（1人につき4秒ごとに1発分）", "max": 1, "req": "repairer"},
	# ---- おもしろ強化（あまり強くないけど、変で派手なやつ）
	{"id": "sp_fun_fireworks", "cat": "soldier", "special": true, "name": "勝利の花火", "desc": "遊撃兵が敵を倒すと、30%で花火が打ち上がる（弾けた所に小ダメージ）", "max": 1},
	{"id": "sp_fun_reflect", "cat": "guard", "special": true, "name": "はね返し盾", "desc": "盾で防いだ弾を虹色の弾にして打ち返す", "max": 1, "req": "guard"},
	{"id": "sp_fun_firework_arrow", "cat": "sniper", "special": true, "name": "花火矢", "desc": "4回に1回、矢と一緒に花火も撃ち込む", "max": 1, "req": "sniper"},
	{"id": "sp_fun_roar", "cat": "heavy", "special": true, "name": "雄叫び", "desc": "10秒ごとに雄叫びを上げ、周りの敵に斬撃3倍のダメージを与えて思いっきり吹き飛ばす", "max": 1, "req": "heavy"},
	{"id": "sp_fun_jack", "cat": "builder", "special": true, "name": "ビックリ箱壁", "desc": "壁が攻撃を防ぐと、35%でビックリ箱が飛び出して敵を吹き飛ばす", "max": 1, "req": "builder"},
	{"id": "sp_fun_scarecrow", "cat": "engineer", "special": true, "name": "かかし", "desc": "罠と一緒にかかしを立てる。敵の気を引いて、代わりに殴られてくれる（耐久60）", "max": 1, "req": "engineer"},
	{"id": "sp_fun_doves", "cat": "castle", "special": true, "name": "矢倉・伝書鳩部隊", "desc": "6秒ごとに、矢倉から敵を追いかける白い鳩が飛び立つ。当たった敵が生き残っていたらくっついて、1秒ごとにあと2回つつく", "max": 1, "req": "tower"},
	{"id": "sp_fun_billiard", "cat": "castle", "special": true, "name": "大砲・ビリヤード砲弾", "desc": "砲弾が着弾したあと、同じ向きに2回跳ねる（跳ねるたびに威力半分）", "max": 1, "req": "cannon"},
	{"id": "sp_fun_cow", "cat": "castle", "special": true, "name": "投石器・牛投げ", "desc": "3回に1回、岩のかわりに牛を投げる。着地した牛は6秒間、近くの敵へ何度も突進する", "max": 1, "req": "catapult"},
	{"id": "sp_fun_rainbow", "cat": "castle", "special": true, "name": "バリスタ・虹の矢", "desc": "矢が虹色の尾を引き、当たった敵は1.5秒間混乱してふらふら歩く", "max": 1, "req": "ballista"},
	{"id": "sp_fun_snowball", "cat": "castle", "special": true, "name": "結界・雪合戦", "desc": "城から近くの敵へ雪玉を投げ続ける（ちょっとだけ止まる）", "max": 1, "req": "frost"},
	{"id": "sp_fun_dance", "cat": "pet", "special": true, "name": "ペットの踊り", "desc": "ペットが虹色に光りながらくるくる回り、5秒ごとに全方位へ虹色の玉を12発撃つ", "max": 1, "req": "pet"},
	{"id": "sp_fun_star", "cat": "knight", "special": true, "name": "流れ星突撃", "desc": "突進の跡にキラキラの星が残って弾ける（小ダメージ）", "max": 1, "req": "knight"},
	{"id": "sp_repair_orb", "cat": "repair", "special": true, "name": "修理玉", "desc": "20秒ごとに城の前へ修理玉を置く（当たり判定なし）。置いてから10秒間に回復した城のHPの6倍のダメージの弾を、HPが一番多い敵へゆっくり撃つ（貫通無限）", "max": 1, "req": "repairer"},
	# ---- 15秒ごとの必殺技（各種類の6つ目）
	{"id": "sp_ult_flock", "cat": "pet", "special": true, "name": "必殺・鳥の大群", "desc": "15秒ごとに、ペット1匹につき6羽の鳥を呼ぶ。鳥は敵を追いかけ、当たった敵にくっついて2回つつく（ペットの3倍の威力）", "max": 1, "req": "pet"},
	# ---- 8つ目の特別強化
	{"id": "sp_touch_blast", "cat": "soldier", "special": true, "name": "触爆", "desc": "遊撃兵に触れた敵が爆発し、周りの敵に射撃の3倍ダメージ", "max": 1},
	{"id": "sp_berserk_guard", "cat": "guard", "special": true, "name": "捨て身の構え", "desc": "迎撃兵の最大HPが半分になり、盾で防いでも半分のダメージを受ける。そのかわり槍が当たった敵が爆発し、周りに槍の3倍ダメージ", "max": 1, "req": "guard"},
	{"id": "sp_blast_arrow", "cat": "sniper", "special": true, "name": "爆裂矢", "desc": "矢が当たった敵が爆発し、周りの敵に矢の3倍ダメージ", "max": 1, "req": "sniper"},
	{"id": "sp_rage", "cat": "heavy", "special": true, "name": "怒りの闘志", "desc": "ダメージを受けるたびに重装兵の与ダメージ +5%（最大+100%）。2秒ダメージを受けないと元に戻る", "max": 1, "req": "heavy"},
	{"id": "sp_counter_wall", "cat": "builder", "special": true, "name": "反撃壁", "desc": "敵の弾が壁に当たると、その場所から近くの敵へ弾を撃ち返す", "max": 1, "req": "builder"},
	{"id": "sp_automaton", "cat": "engineer", "special": true, "name": "巨大からくり兵", "desc": "20秒ごとに、ボスくらい大きなからくり兵を置く（10秒で消える）。ゆっくり歩き、全方位斬り→高速連射をくり返す。消えるときに大爆発", "max": 1, "req": "engineer"},
	{"id": "sp_tower_blast", "cat": "castle", "special": true, "name": "矢倉・爆裂矢", "desc": "矢倉の矢が当たった敵が爆発し、周りの敵に矢の3倍ダメージ", "max": 1, "req": "tower"},
	{"id": "sp_double_cannon", "cat": "castle", "special": true, "name": "大砲・二連砲", "desc": "大砲が一度に2発撃つ（2発目は別の密集地へ）", "max": 1, "req": "cannon"},
	{"id": "sp_stay_rock", "cat": "castle", "special": true, "name": "投石器・居座り岩", "desc": "着弾地点に大岩が5秒間残り、上にいる敵にダメージを与え続け、移動速度 -30%", "max": 1, "req": "catapult"},
	{"id": "sp_mega_bolt", "cat": "castle", "special": true, "name": "バリスタ・巨大弩砲", "desc": "8秒ごとに、3倍の大きさ・3倍の威力の矢を、HPが一番多い敵へゆっくり（速さ1/3）撃つ", "max": 1, "req": "ballista"},
	{"id": "sp_frost_ground", "cat": "castle", "special": true, "name": "結界・凍てつく大地", "desc": "結界の中の地面が凍りつき、中にいる敵にずっとダメージを与える（吹雪と重ねがけできる）", "max": 1, "req": "frost"},
	{"id": "sp_pet_body", "cat": "pet", "special": true, "name": "体当たりペット", "desc": "ペットに触れた敵に、ペットの弾の3倍ダメージ", "max": 1, "req": "pet"},
	{"id": "sp_carry", "cat": "knight", "special": true, "name": "連行突撃", "desc": "突進で当たった敵（ボス以外）を、突進が終わるまで槍の先に引っかけて連れていく", "max": 1, "req": "knight"},
	{"id": "sp_tool_throw", "cat": "repair", "special": true, "name": "工具投げ", "desc": "城のHPが満タンのとき、修理兵が近くの敵へスパナを投げつける（行って戻ってくる）", "max": 1, "req": "repairer"},
	{"id": "sp_ult_cavalry", "cat": "knight", "special": true, "name": "必殺・百騎突撃", "desc": "15秒ごとに、一番下の敵のあたりを騎士の幻8騎が横一列で駆け抜け、通った敵を全部はねる（突進の2.5倍の威力）", "max": 1, "req": "knight"},
	{"id": "sp_ult_overhaul", "cat": "repair", "special": true, "name": "必殺・大修繕", "desc": "15秒ごとに、城のHPを最大HPの10%回復し、味方のHPを全回復する（壁は直さない）", "max": 1, "req": "repairer"},
	{"id": "sp_ult_storm", "cat": "soldier", "special": true, "name": "必殺・剣の大嵐", "desc": "15秒ごとに、遊撃兵全員が周りを巻き込む巨大な回転斬り（剣の5倍の威力・大きく吹き飛ばす）", "max": 1},
	{"id": "sp_ult_dome", "cat": "guard", "special": true, "name": "必殺・鉄壁の陣", "desc": "15秒ごとに、城をドームで6秒間包む。ドームに入った敵の弾・砲弾は消える。迎撃兵のHPも全回復", "max": 1, "req": "guard"},
	{"id": "sp_ult_sky_arrow", "cat": "sniper", "special": true, "name": "必殺・天穿つ一矢", "desc": "15秒ごとに、狙撃兵が敵が一番多く並ぶ方向へ巨大な矢を放つ（12倍の威力で全部貫く）", "max": 1, "req": "sniper"},
	{"id": "sp_ult_leap", "cat": "heavy", "special": true, "name": "必殺・大地砕き", "desc": "15秒ごとに、重装兵が近くの敵の群れへ飛び込み、地面を叩き割る（斬撃4倍の範囲攻撃＋2秒気絶）", "max": 1, "req": "heavy"},
	{"id": "sp_ult_wall_burst", "cat": "builder", "special": true, "name": "必殺・城壁の大号令", "desc": "15秒ごとに、すべての壁の耐久が10回復し、全部の壁が外側へ大爆発する", "max": 1, "req": "builder"},
	{"id": "sp_ult_carpet", "cat": "engineer", "special": true, "name": "必殺・絨毯爆撃", "desc": "15秒ごとに、敵が密集した所へ一直線に13個の爆弾が降りそそぐ", "max": 1, "req": "engineer"},
	{"id": "sp_ult_thousand", "cat": "castle", "special": true, "name": "矢倉・必殺・千本矢", "desc": "15秒ごとに、フィールド中の敵30か所へ一斉に矢の雨が降る（矢倉の3倍の威力）", "max": 1, "req": "tower"},
	{"id": "sp_ult_barrage", "cat": "castle", "special": true, "name": "大砲・必殺・一斉砲撃", "desc": "15秒ごとに、12発の砲弾を一気に撃ち込む（大砲の2倍の威力）", "max": 1, "req": "cannon"},
	{"id": "sp_ult_meteor", "cat": "castle", "special": true, "name": "投石器・必殺・隕石落とし", "desc": "15秒ごとに、敵の群れへ巨大な燃える隕石を落とす（投石器の6倍の威力・超広範囲、跡が燃える）", "max": 1, "req": "catapult"},
	{"id": "sp_ult_thunder", "cat": "castle", "special": true, "name": "バリスタ・必殺・雷神の大槍", "desc": "15秒ごとに、敵が一番多く並ぶ方向へ雷の大槍を放つ（バリスタの6倍の威力＋1秒しびれる）", "max": 1, "req": "ballista"},
	{"id": "sp_ult_ice_age", "cat": "castle", "special": true, "name": "結界・必殺・氷河期", "desc": "15秒ごとに、結界の2倍以上の広さの敵をまとめて3秒凍らせてダメージ", "max": 1, "req": "frost"},
]

const CAT_LABEL := {"soldier": "遊撃", "pet": "ペット", "builder": "築城", "guard": "迎撃", "sniper": "狙撃", "knight": "近衛",
	"heavy": "重装", "engineer": "工兵", "repair": "修理", "castle": "城"}
const CAT_COLOR := {
	"pet": Color(0.55, 1.0, 0.75), "knight": Color(1.0, 0.82, 0.4), "repair": Color(0.55, 0.75, 1.0),
	"sniper": Color(0.75, 0.95, 0.45),
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
		# ---- ペット
		"pet_rate":
			game.pet_interval *= 0.85
		"pet_fang":
			game.pet_damage *= 1.3
			for p in game.pets:
				p.damage = game.pet_damage
		"pet_eye":
			game.pet_range *= 1.2
		"pet_multi":
			game.pet_shots += 1
		"sp_pet_homing":
			game.pet_homing = true
		"sp_pet_frost":
			game.pet_frost = true
		"sp_pet_heal":
			game.pet_heal = true
		"sp_ult_flock":
			game.ultimates.flock = true
		"sp_pet_burst":
			game.pet_burst = true
		"sp_pet_giant":
			game.pet_giant = true
		# ---- 近衛部隊
		"knight":
			game.add_knight()
		"knight_dmg":
			game.knight_stats.damage *= 1.35
		"knight_rate":
			game.knight_stats.interval *= 0.85
		"knight_reach":
			game.knight_stats.dash_distance *= 1.25
		"sp_chain_dash":
			game.knight_stats.chain = 2
		"sp_dash_quake":
			game.knight_stats.quake = true
		# ---- 修理部隊
		"repairer":
			game.add_repairer()
		"repair_skill":
			game.repair_stats.heal_per_sec += 1.0
		"sp_wall_fix":
			game.repair_stats.wall_fix = true
		"sp_knight_stun":
			game.knight_stats.stun_hit = true
		"sp_knight_heal":
			game.knight_stats.heal_on_hit = true
		"sp_knight_execute":
			game.knight_stats.execute = true
		"sp_first_aid":
			game.repair_stats.first_aid = true
		"sp_emergency":
			game.repair_stats.emergency = true
		"sp_armor":
			castle.damage_taken_mult *= 0.9
		"sp_maintenance":
			castle.tower_interval *= 0.85
			castle.cannon_interval *= 0.85
			castle.catapult_interval *= 0.85
			castle.ballista_interval *= 0.85
		"sp_ult_cavalry":
			game.ultimates.cavalry = true
		# ---- 8つ目の特別強化
		"sp_touch_blast":
			st.touch_blast = true
		"sp_berserk_guard":
			game.guard_stats.berserk = true
			game.guard_stats.max_hp /= 2.0
			for g in game.guards:
				g.hp = minf(g.hp, game.guard_stats.max_hp)
		"sp_blast_arrow":
			game.sniper_stats.blast_arrow = true
		"sp_rage":
			game.heavy.rage_enabled = true
		"sp_counter_wall":
			game.walls.counter = true
		"sp_automaton":
			game.fun.automaton = true
		"sp_tower_blast":
			castle.tower_blast = true
		"sp_double_cannon":
			castle.double_cannon = true
		"sp_stay_rock":
			castle.stay_rock = true
		"sp_mega_bolt":
			castle.mega_bolt = true
		"sp_frost_ground":
			castle.frost_ground = true
		"sp_pet_body":
			game.pet_body = true
		"sp_carry":
			game.knight_stats.carry = true
		"sp_tool_throw":
			game.repair_stats.tool_throw = true
		"sp_ult_overhaul":
			game.ultimates.overhaul = true
		# ---- おもしろ強化
		"sp_fun_fireworks":
			st.fireworks = true
		"sp_fun_reflect":
			game.guard_stats.reflect = true
		"sp_fun_firework_arrow":
			game.sniper_stats.firework_arrow = true
		"sp_fun_roar":
			game.fun.roar = true
		"sp_fun_jack":
			game.walls.jack = true
		"sp_fun_scarecrow":
			game.engineer_stats.scarecrow = true
		"sp_fun_doves":
			game.fun.doves = true
		"sp_fun_billiard":
			castle.billiard = true
		"sp_fun_cow":
			castle.cow_throw = true
		"sp_fun_rainbow":
			castle.rainbow_bolt = true
		"sp_fun_snowball":
			game.fun.snowball = true
		"sp_fun_dance":
			game.fun.pet_dance = true
		"sp_fun_star":
			game.knight_stats.star_trail = true
		"sp_repair_orb":
			game.fun.repair_orb = true
		# ---- 狙撃部隊
		"sniper":
			game.add_sniper()
		"sniper_rate":
			game.sniper_stats.interval *= 0.85
		"sniper_multi":
			game.sniper_stats.shots += 1
		"sniper_dmg":
			game.sniper_stats.damage *= 1.35
		"sniper_pierce":
			game.sniper_stats.pierce += 1
		"sp_counter_battery":
			game.sniper_stats.counter_battery = true
		"sp_headshot":
			game.sniper_stats.headshot = true
		"sp_pin":
			game.sniper_stats.pin = true
		"sp_ricochet":
			game.sniper_stats.bounces = 3
		"sp_mark":
			game.sniper_stats.mark = true
		# ---- 必殺技（中身は ultimates.gd）
		"sp_ult_storm":
			game.ultimates.storm = true
		"sp_ult_dome":
			game.ultimates.dome = true
		"sp_ult_sky_arrow":
			game.ultimates.sky_arrow = true
		"sp_ult_leap":
			game.ultimates.leap = true
		"sp_ult_wall_burst":
			game.ultimates.wall_burst = true
		"sp_ult_carpet":
			game.ultimates.carpet = true
		"sp_ult_thousand":
			game.ultimates.thousand = true
		"sp_ult_barrage":
			game.ultimates.barrage = true
		"sp_ult_meteor":
			game.ultimates.meteor = true
		"sp_ult_thunder":
			game.ultimates.thunder_spear = true
		"sp_ult_ice_age":
			game.ultimates.ice_age = true
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
