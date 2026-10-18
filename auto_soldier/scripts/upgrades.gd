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
	{"id": "recruit", "cat": "soldier", "name": "遊撃兵を増員", "desc": "遊撃部隊の兵士が1人増える（最大5人）", "max": 3, "weight": 1.5},
	{"id": "multishot", "cat": "soldier", "name": "射撃数+1", "desc": "一度に撃つ弾が1発増える", "max": 5},
	{"id": "firerate", "cat": "soldier", "name": "速射", "desc": "射撃の間隔 -10%", "max": 5},
	{"id": "bullet_dmg", "cat": "soldier", "name": "強化弾", "desc": "射撃ダメージ +20%", "max": 5},
	{"id": "pierce", "cat": "soldier", "name": "貫通弾", "desc": "弾が敵をもう1体貫通する", "max": 3},
	{"id": "sword_dmg", "cat": "soldier", "name": "剣術", "desc": "斬撃ダメージ +20%", "max": 5},
	{"id": "sword_range", "cat": "soldier", "name": "大振り", "desc": "斬撃の範囲 +20%", "max": 4},
	{"id": "whirlwind", "cat": "soldier", "name": "回転斬り", "desc": "斬撃が全方位360度になる", "max": 1},
	{"id": "dash", "cat": "soldier", "name": "突進突き", "desc": "4秒ごとに敵へ突進して貫く（突進中は無敵）",
		"desc_up": "突進の間隔 -10%、威力 +30%", "max": 4},
	{"id": "pet", "cat": "soldier", "name": "遊撃ペット", "desc": "全遊撃兵にペットが1匹ずつ付き、自動で射撃してくれる（あとから増えた遊撃兵にも付く）",
		"desc_up": "全遊撃兵にペットがもう1匹ずつ付く、全ペットの攻撃力 +20%", "max": 4},
	{"id": "soldier_hp", "cat": "soldier", "name": "鍛錬", "desc": "遊撃兵の最大HP +25、全員HP全回復", "max": 4},
	# ---- 築城部隊
	{"id": "builder", "cat": "builder", "name": "築城部隊", "desc": "城の上側180度を囲むように、20秒ごとに壁を1枚建てる（壁1枚で敵の攻撃を10発防ぐ）",
		"desc_up": "築城部隊の作業員が1人増える（最大3人、それぞれ別の場所に壁を建てる）", "max": 3, "weight": 0.5},
	{"id": "build_speed", "cat": "builder", "name": "突貫工事", "desc": "壁の建築時間 -10%", "max": 5, "req": "builder"},
	{"id": "wall_hp", "cat": "builder", "name": "石壁強化", "desc": "壁が防げる回数 +2発（建っている壁にも反映。大きな壁は幅に合わせてもっと増える）", "max": 5, "req": "builder"},
	{"id": "wall_width", "cat": "builder", "name": "大きな壁", "desc": "これから建てる壁の幅 +2.4度（少ない枚数で囲める）。防げる回数も幅に合わせて増える", "max": 5, "req": "builder"},
	# ---- 迎撃部隊
	{"id": "guard", "cat": "guard", "name": "迎撃部隊", "desc": "盾と槍を持ち、城の近くで敵を迎え撃つ兵士が加わる（前方からの攻撃は盾でダメージ20%）",
		"desc_up": "迎撃部隊の兵士が1人増える（最大3人）", "max": 3, "weight": 0.5},
	{"id": "shield_arc", "cat": "guard", "name": "大盾", "desc": "盾で防げる範囲 +20度、盾で受けたときのダメージカット +5%（最大で100%カット）", "max": 5, "req": "guard"},
	{"id": "spear_reach", "cat": "guard", "name": "長槍", "desc": "槍のリーチ +25", "max": 5, "req": "guard"},
	{"id": "spear_dmg", "cat": "guard", "name": "槍術", "desc": "槍の攻撃力 +20%", "max": 5, "req": "guard"},
	# 【ペット】（ペットの仲間を取ると出る）
	{"id": "pet_rate", "cat": "pet", "name": "遊撃ペット早撃ち", "desc": "遊撃ペットの射撃の間隔 -10%", "max": 4, "req": "pet"},
	{"id": "pet_fang", "cat": "pet", "name": "遊撃ペットの牙", "desc": "遊撃ペットの弾の威力 +20%", "max": 5, "req": "pet"},
	{"id": "pet_eye", "cat": "pet", "name": "遊撃ペットの目", "desc": "遊撃ペットの射程 +20%", "max": 5, "req": "pet"},
	{"id": "pet_multi", "cat": "pet", "name": "遊撃ペット連射", "desc": "遊撃ペットが一度に撃つ弾 +1発", "max": 3, "req": "pet"},
	# 【近衛】
	{"id": "knight", "cat": "knight", "name": "近衛部隊", "desc": "フィールドの一番下にいる敵を最優先で狙い、近くから一直線に高速突進して貫く騎士が加わる（隠密兵は当たっただけで倒れる）",
		"desc_up": "近衛部隊の騎士が1人増える（最大3人）", "max": 3, "weight": 0.5},
	{"id": "knight_dmg", "cat": "knight", "name": "剛突", "desc": "突進の威力 +20%", "max": 5, "req": "knight"},
	{"id": "knight_rate", "cat": "knight", "name": "疾駆", "desc": "突進の間隔 -10%", "max": 5, "req": "knight"},
	{"id": "knight_width", "cat": "knight", "name": "大槍", "desc": "突進の当たる幅 +30%", "max": 5, "req": "knight"},
	{"id": "knight_move", "cat": "knight", "name": "駿馬", "desc": "近衛兵の移動速度 +20%（突進していないときの歩く速さ）", "max": 5, "req": "knight"},
	# 【修理】
	{"id": "repairer", "cat": "repair", "name": "修理部隊", "desc": "城のまわりで修理をして、城のHPを毎秒1回復する修理兵が加わる",
		"desc_up": "修理兵が1人増える（最大3人）", "max": 3, "weight": 1.0},
	{"id": "repair_skill", "cat": "repair", "name": "熟練工", "desc": "修理兵1人あたりの回復量 +1/秒", "max": 3, "req": "repairer"},
	# 【狙撃】
	{"id": "sniper", "cat": "sniper", "name": "狙撃部隊", "desc": "迎撃部隊の後ろに立ち、遠距離型の敵（弓兵・迫撃砲）を優先して弓で狙い撃つ狙撃兵が加わる",
		"desc_up": "狙撃部隊の狙撃兵が1人増える（最大3人）", "max": 3, "weight": 0.5},
	{"id": "archer", "cat": "archer", "name": "弓兵部隊", "desc": "画面の下半分を自由に動き回りながら射撃する弓兵が加わる（敵から狙われない）",
		"desc_up": "弓兵が1人増える（最大3人）", "max": 3, "weight": 0.6},
	{"id": "archer_rate", "cat": "archer", "name": "早撃ち", "desc": "弓兵が矢を放つ間隔 -10%", "max": 5, "req": "archer"},
	{"id": "archer_multi", "cat": "archer", "name": "多連矢", "desc": "一度に放つ矢 +1本", "max": 3, "req": "archer"},
	{"id": "archer_dmg", "cat": "archer", "name": "強弓", "desc": "矢の威力 +20%", "max": 5, "req": "archer"},
	{"id": "archer_pierce", "cat": "archer", "name": "貫き矢", "desc": "矢が敵をもう1体貫通する", "max": 5, "req": "archer"},
	{"id": "archer_pet", "cat": "archer_pet", "name": "弓兵ペット", "desc": "全弓兵にペットが1匹ずつ付き、斬撃で戦う（遊撃兵の剣と同じ設定）",
		"desc_up": "全弓兵にペットがもう1匹ずつ付く、全ペットの攻撃力 +20%", "max": 4, "req": "archer"},
	{"id": "archer_pet_rate", "cat": "archer_pet", "name": "弓兵ペット早撃ち", "desc": "弓兵ペットの射撃の間隔 -10%", "max": 4, "req": "archer_pet"},
	{"id": "archer_pet_fang", "cat": "archer_pet", "name": "弓兵ペットの牙", "desc": "弓兵ペットの弾の威力 +20%", "max": 5, "req": "archer_pet"},
	{"id": "archer_pet_eye", "cat": "archer_pet", "name": "弓兵ペットの目", "desc": "弓兵ペットの射程 +20%", "max": 5, "req": "archer_pet"},
	{"id": "archer_pet_multi", "cat": "archer_pet", "name": "連続斬撃", "desc": "弓兵ペットの斬撃発生回数 +1", "max": 3, "req": "archer_pet"},
	{"id": "archer_size", "cat": "archer", "name": "大矢", "desc": "弓兵の矢のサイズ +20%", "max": 5, "req": "archer"},
	{"id": "sniper_rate", "cat": "sniper", "name": "早撃ち", "desc": "狙撃兵が矢を放つ間隔 -10%", "max": 5, "req": "sniper"},
	{"id": "sniper_multi", "cat": "sniper", "name": "多連矢", "desc": "一度に放つ矢 +1本", "max": 3, "req": "sniper"},
	{"id": "sniper_dmg", "cat": "sniper", "name": "強弓", "desc": "矢の威力 +20%", "max": 5, "req": "sniper"},
	{"id": "sniper_pierce", "cat": "sniper", "name": "貫き矢", "desc": "矢が敵をもう1体貫通する", "max": 5, "req": "sniper"},
	{"id": "sniper_size", "cat": "sniper", "name": "大矢", "desc": "狙撃兵の矢のサイズ +20%", "max": 5, "req": "sniper"},
	# ---- 重装部隊
	{"id": "heavy", "cat": "heavy", "name": "重装部隊", "desc": "足は遅いが耐久力と攻撃力が高い重装兵が加わる。マップ内を自由に歩き回り、マップの真ん中に一番近い敵を最優先で斬りに行く", "max": 1, "weight": 0.5},
	{"id": "heavy_dmg", "cat": "heavy", "name": "剛剣", "desc": "重装兵の斬撃の威力 +20%", "max": 5, "req": "heavy"},
	{"id": "heavy_haste", "cat": "heavy", "name": "連撃", "desc": "重装兵の斬撃の間隔 -10%", "max": 5, "req": "heavy"},
	{"id": "heavy_range", "cat": "heavy", "name": "大薙ぎ", "desc": "重装兵の斬撃の範囲 +20%", "max": 5, "req": "heavy"},
	{"id": "heavy_hp", "cat": "heavy", "name": "重鎧", "desc": "重装兵の最大HP +40%、HP全回復、自然回復 +3/秒", "max": 5, "req": "heavy"},
	{"id": "heavy_speed", "cat": "heavy", "name": "軽量化", "desc": "重装兵の移動速度 +20%", "max": 5, "req": "heavy"},
	{"id": "heavy_whirl", "cat": "heavy", "name": "旋風斬り", "desc": "重装兵の斬撃が全方位360度になる", "max": 1, "req": "heavy"},
	# ---- 工兵部隊
	{"id": "engineer", "cat": "engineer", "name": "工兵部隊", "desc": "フィールドを回って、爆弾（範囲ダメージ）と落とし穴（範囲ダメージ＋1秒足止め）を交互に仕掛ける工兵が加わる",
		"desc_up": "工兵が1人増える（最大3人）", "max": 3, "weight": 0.5},
	{"id": "trap_dmg", "cat": "engineer", "name": "高性能火薬", "desc": "工兵の攻撃すべての威力 +20%（爆弾・落とし穴・毒沼・子爆弾・自動砲台・からくり兵・絨毯爆撃など。仕掛け済みの罠にも反映）", "max": 5, "req": "engineer"},
	{"id": "trap_speed", "cat": "engineer", "name": "手際", "desc": "罠の設置時間 -20%", "max": 4, "req": "engineer"},
	{"id": "engineer_move", "cat": "engineer", "name": "健脚", "desc": "工兵の移動速度 +15%", "max": 4, "req": "engineer"},
	{"id": "trap_range", "cat": "engineer", "name": "広域罠", "desc": "罠の効果範囲 +20%", "max": 3, "req": "engineer"},
	{"id": "trap_trigger", "cat": "engineer", "name": "敏感な起爆", "desc": "罠が反応する距離 +15%（敵が少し離れていても作動する）", "max": 3, "req": "engineer"},
	{"id": "pit_stun", "cat": "engineer", "name": "深い落とし穴", "desc": "落とし穴の足止め時間 +1秒", "max": 3, "req": "engineer"},
	# ---- 城
	{"id": "tower", "cat": "castle", "name": "矢倉", "desc": "城に矢倉が建ち、近づく敵を自動で射る",
		"desc_up": "矢倉をもう1基追加（最大4基）", "max": 4, "weight": 0.5},
	{"id": "tower_dmg", "cat": "castle", "name": "強弓矢倉", "desc": "矢倉のダメージ +20%", "max": 5, "req": "tower"},
	{"id": "tower_rate", "cat": "castle", "name": "速射矢倉", "desc": "矢倉の発射間隔 -10%", "max": 5, "req": "tower"},
	{"id": "tower_pierce", "cat": "castle", "name": "貫通矢倉", "desc": "矢倉の矢が敵をもう1体貫通する", "max": 5, "req": "tower"},
	{"id": "tower_multi", "cat": "castle", "name": "多連矢", "desc": "矢倉が一度に放つ矢の数 +1", "max": 3, "req": "tower"},
	{"id": "cannon", "cat": "castle", "name": "大砲", "desc": "敵が密集した場所へ砲弾を撃ち込む（範囲攻撃）",
		"desc_up": "大砲をもう1門追加（最大3門）", "max": 3, "weight": 0.5},
	{"id": "catapult", "cat": "castle", "name": "投石器", "desc": "大砲より広い範囲に岩を落とす（発射間隔は長い）",
		"desc_up": "投石器をもう1台追加（最大3台）", "max": 3, "weight": 0.5},
	{"id": "ballista", "cat": "castle", "name": "バリスタ", "desc": "城にバリスタを設置。HPが一番多い敵を最優先で狙う。発射間隔は長いが、高威力・射程無限で敵を何体でも貫通する",
		"desc_up": "バリスタをもう1基追加（最大4基）", "max": 4, "weight": 0.5},
	{"id": "rapid", "cat": "castle", "name": "連射砲", "desc": "城の左右に連射砲を設置。威力が低い代わりに高速で連射する（貫通なし）",
		"desc_up": "連射砲をもう1基追加（最大2基）", "max": 2, "weight": 0.6},
	{"id": "rapid_dmg", "cat": "castle", "name": "連射強化", "desc": "連射砲の威力 +20%", "max": 5, "req": "rapid"},
	{"id": "rapid_rate", "cat": "castle", "name": "超速射", "desc": "連射砲の発射間隔 -10%", "max": 5, "req": "rapid"},
	{"id": "rapid_pierce", "cat": "castle", "name": "貫通連射", "desc": "連射砲の貫通 +1", "max": 5, "req": "rapid"},
	{"id": "rapid_multi", "cat": "castle", "name": "多連射", "desc": "連射砲が一度に放つ弾の数 +1", "max": 3, "req": "rapid"},
	{"id": "ballista_dmg", "cat": "castle", "name": "強化弩", "desc": "バリスタのダメージ +20%", "max": 5, "req": "ballista"},
	{"id": "ballista_rate", "cat": "castle", "name": "速射弩", "desc": "バリスタの発射間隔 -10%", "max": 5, "req": "ballista"},
	{"id": "ballista_multi", "cat": "castle", "name": "多連弩", "desc": "バリスタが一度に放つ矢の数 +1", "max": 3, "req": "ballista"},
	{"id": "artillery", "cat": "castle", "name": "砲術", "desc": "大砲の威力 +20%", "max": 5, "req": "cannon"},
	{"id": "cannon_rate", "cat": "castle", "name": "速射砲術", "desc": "大砲の発射間隔 -10%", "max": 5, "req": "cannon"},
	{"id": "cannon_range", "cat": "castle", "name": "広範囲砲撃", "desc": "大砲の攻撃範囲 +20%", "max": 5, "req": "cannon"},
	{"id": "cannon_multi", "cat": "castle", "name": "多連砲", "desc": "大砲が一度に撃つ砲弾の数 +1", "max": 3, "req": "cannon"},
	{"id": "catapult_dmg", "cat": "castle", "name": "投石強化", "desc": "投石器の威力 +20%", "max": 5, "req": "catapult"},
	{"id": "catapult_rate", "cat": "castle", "name": "連続投石", "desc": "投石器の発射間隔 -10%", "max": 5, "req": "catapult"},
	{"id": "catapult_range", "cat": "castle", "name": "広域投石", "desc": "投石器の攻撃範囲 +20%", "max": 5, "req": "catapult"},
	{"id": "catapult_multi", "cat": "castle", "name": "多連投", "desc": "投石器が一度に投げる岩の数 +1", "max": 3, "req": "catapult"},
	{"id": "frost", "cat": "castle", "name": "氷結の結界", "desc": "城のまわりの敵の動きを遅くする（範囲280、減速10%）", "max": 1, "weight": 0.5},
	{"id": "frost_range", "cat": "castle", "name": "結界拡大", "desc": "氷結の結界の範囲 +15%", "max": 5, "req": "frost"},
	{"id": "frost_slow", "cat": "castle", "name": "極寒の結界", "desc": "氷結の結界の減速率 +5%", "max": 5, "req": "frost"},
	{"id": "mine_site", "cat": "castle", "name": "採掘場", "desc": "城の右側（壁の外）に採掘場ができる。待機中の兵士が1人掘りに行き、掘っている間10秒ごとに経験値を1獲得する（敵が来たら戦いに戻る）", "max": 1, "weight": 0.5},
	{"id": "mine_speed", "cat": "castle", "name": "採掘の効率化", "desc": "採掘の間隔 -1秒（最大で5秒）", "max": 5, "req": "mine_site"},
	{"id": "mine_yield", "cat": "castle", "name": "豊かな鉱脈", "desc": "採掘1回で獲得する経験値 +1（最大6）", "max": 5, "req": "mine_site"},
	{"id": "wall", "cat": "castle", "name": "城壁補強", "desc": "城の最大HP +100、城のHP全回復", "max": 5},
]

## Lv5ごとに出る特別強化。部隊・設備の種類ごとに5つずつ。どれも1回取れば完成（レベルなし）。
## req = この強化（部隊・設備）を持っていないと出ない（なければ誰でも）
const SPECIAL := [
	# ---- 遊撃部隊
	{"id": "sp_burst", "cat": "soldier", "special": true, "name": "炸裂弾", "desc": "遊撃兵の弾が当たると小爆発する（威力19.25%）", "max": 1},
	{"id": "sp_volley", "cat": "soldier", "special": true, "name": "一斉射撃", "desc": "6秒ごとに全方位へ18発の弾をばらまく（射撃の40倍の威力）", "max": 1},
	{"id": "sp_sword_wave", "cat": "soldier", "special": true, "name": "剣気", "desc": "斬撃と一緒に、敵を貫く大きな三日月形の衝撃波がゆっくり飛ぶ（剣の4倍の威力）", "max": 1},
	{"id": "sp_shadow", "cat": "soldier", "special": true, "name": "影分身", "desc": "遊撃兵の横に半透明の分身が現れ、一緒に弾を撃つ（威力200%）", "max": 1},
	{"id": "sp_shadow_volley", "cat": "soldier", "special": true, "name": "影一斉射撃", "desc": "影分身からも一斉射撃が発射されるようになる（影分身の一斉射撃も同じ威力）\n「影分身」と「一斉射撃」を取得している場合のみ出現", "max": 1, "req_all": ["sp_shadow", "sp_volley"]},
	{"id": "sp_boomerang", "cat": "soldier", "special": true, "name": "ブーメラン", "desc": "3.5秒ごとに大きなブーメランを投げる。行きと帰りで敵を貫く（剣の10.4倍の威力）", "max": 1},
	# ---- 迎撃部隊
	{"id": "sp_bash", "cat": "guard", "special": true, "name": "盾撃", "desc": "盾で攻撃を防ぐたびに、周りの敵へ衝撃波（槍の1.3倍の威力）", "max": 1, "req": "guard"},
	{"id": "sp_trident", "cat": "guard", "special": true, "name": "三叉槍", "desc": "槍の突きが3方向に出る", "max": 1, "req": "guard"},
	{"id": "sp_taunt", "cat": "guard", "special": true, "name": "挑発", "desc": "近くの敵が城より迎撃兵を狙うようになる（正面から来れば盾でダメージ20%）", "max": 1, "req": "guard"},
	{"id": "sp_whirl_spear", "cat": "guard", "special": true, "name": "大旋風槍", "desc": "6秒ごとに槍を振り回し、周りの敵へ槍の3倍の大ダメージ", "max": 1, "req": "guard"},
	{"id": "sp_spikes", "cat": "guard", "special": true, "name": "拒馬の柵", "desc": "8秒ごとに盾の前へトゲの柵を置く。上を通る敵の移動速度を20%下げてダメージ（8秒残る）", "max": 1, "req": "guard"},
	# ---- 重装部隊
	{"id": "sp_multi_slash", "cat": "heavy", "special": true, "name": "連続斬り", "desc": "斬撃が2回連続で出る", "max": 1, "req": "heavy"},
	{"id": "sp_quake", "cat": "heavy", "special": true, "name": "地割れ", "desc": "5秒ごとに地面を叩き、周りの敵に斬撃3倍のダメージ＋1秒気絶", "max": 1, "req": "heavy"},
	{"id": "sp_lifesteal", "cat": "heavy", "special": true, "name": "吸命の剣", "desc": "斬撃で与えたダメージの10%ぶんHPが回復する", "max": 1, "req": "heavy"},
	{"id": "sp_execute", "cat": "heavy", "special": true, "name": "一刀両断", "desc": "8秒ごとに、重装兵のいる高さの横一列を、画面の左端から右端まで白い斬撃が1秒で駆け抜ける（通り道の敵に通常攻撃の50倍のダメージ）", "max": 1, "req": "heavy"},
	{"id": "sp_iron_ball", "cat": "heavy", "special": true, "name": "鉄球投げ", "desc": "5秒ごとにトゲ鉄球を投げる。転がりながら敵をひいて吹き飛ばす（斬撃7.5倍の威力）", "max": 1, "req": "heavy"},
	# ---- 築城部隊
	{"id": "sp_wall_turret", "cat": "builder", "special": true, "name": "砲台壁", "desc": "壁から近くの敵へ弾が発射されるようになる", "max": 1, "req": "builder"},
	{"id": "sp_wall_repair", "cat": "builder", "special": true, "name": "自己修復", "desc": "壁が3秒ごとに1発分ずつ回復する", "max": 1, "req": "builder"},
	{"id": "sp_wall_blast", "cat": "builder", "special": true, "name": "爆裂壁", "desc": "壁が攻撃を防ぐたびに、その場で爆発して周りの敵にダメージ", "max": 1, "req": "builder"},
	{"id": "sp_golden_wall", "cat": "builder", "special": true, "name": "黄金の壁", "desc": "壁が攻撃を防ぐたびに経験値が1入る", "max": 1, "req": "builder"},
	{"id": "sp_watchtower", "cat": "builder", "special": true, "name": "見張り櫓", "desc": "築城兵が壁の内側に見張り櫓を建てる（最大3基）。壁を建てる仕事がなくて待機しているあいだ、築城兵が櫓に乗って近くの敵へ矢を撃つ", "max": 1, "req": "builder"},
	{"id": "sp_tower_turret", "cat": "builder", "special": true, "name": "見張り砲台", "desc": "見張り櫓からも砲台壁の射撃が飛ぶようになる\n「見張り櫓」と「砲台壁」を取得している場合のみ出現", "max": 1, "req": "builder", "req_all": ["sp_watchtower", "sp_wall_turret"]},
	# ---- 工兵部隊
	{"id": "sp_cluster", "cat": "engineer", "special": true, "name": "子爆弾", "desc": "爆弾が爆発すると、周りに小爆弾が6個散らばって爆発する", "max": 1, "req": "engineer"},
	{"id": "sp_poison", "cat": "engineer", "special": true, "name": "毒沼", "desc": "作動した落とし穴の跡が9秒間、毒の沼になる", "max": 1, "req": "engineer"},
	{"id": "sp_double_plant", "cat": "engineer", "special": true, "name": "二重設置", "desc": "1回で爆弾と落とし穴を両方仕掛ける（罠の上限も30個に）", "max": 1, "req": "engineer"},
	{"id": "sp_ap_mine", "cat": "engineer", "special": true, "name": "徹甲地雷", "desc": "爆弾の真上近くにいる敵1体に、追加で爆弾40倍のダメージ", "max": 1, "req": "engineer"},
	{"id": "sp_sentry", "cat": "engineer", "special": true, "name": "自動砲台", "desc": "罠と一緒に自動砲台を置く（30秒間、近くの敵を連射。工兵1人につき3台まで）", "max": 1, "req": "engineer"},
	# ---- 矢倉
	{"id": "sp_homing_arrow", "cat": "castle", "special": true, "name": "矢倉・追尾の矢", "desc": "矢倉の矢が途中で一番近い敵へ向きを変える（1回だけ）", "max": 1, "req": "tower"},
	{"id": "sp_tower_ap", "cat": "castle", "special": true, "name": "矢倉・徹甲矢", "desc": "矢倉の矢が敵を3体貫通し、威力 +60%", "max": 1, "req": "tower"},
	{"id": "sp_tower_crit", "cat": "castle", "special": true, "name": "矢倉・会心の一矢", "desc": "矢倉の矢が25%の確率でダメージ3倍、射程 +40%", "max": 1, "req": "tower"},
	{"id": "sp_arrow_rain", "cat": "castle", "special": true, "name": "矢倉・火矢の雨", "desc": "7秒ごとに、矢倉1基につき1か所、敵が密集した所へ矢の雨が降る（範囲大ダメージ）", "max": 1, "req": "tower"},
	{"id": "sp_homing", "cat": "castle", "special": true, "name": "矢倉・追尾火矢", "desc": "3秒ごとに、矢倉1基につき2本、敵を追いかける火矢を放つ（当たると小爆発）", "max": 1, "req": "tower"},
	# ---- 大砲
	{"id": "sp_scatter", "cat": "castle", "special": true, "name": "大砲・散弾砲", "desc": "砲弾が分裂して、着弾地点の周りにも4発落ちる", "max": 1, "req": "cannon"},
	{"id": "sp_suction", "cat": "castle", "special": true, "name": "大砲・吸引砲", "desc": "着弾地点に0.5秒間、近くの敵を少し吸い寄せる", "max": 1, "req": "cannon"},
	{"id": "sp_incendiary", "cat": "castle", "special": true, "name": "大砲・焼夷弾", "desc": "着弾地点が6秒間燃え続ける", "max": 1, "req": "cannon"},
	{"id": "sp_rapid_cannon", "cat": "castle", "special": true, "name": "大砲・速射砲", "desc": "大砲の発射間隔 -40%", "max": 1, "req": "cannon"},
	{"id": "sp_ap_shell", "cat": "castle", "special": true, "name": "大砲・徹甲榴弾", "desc": "6秒ごとに、大砲1門につき1発、一番HPの多い敵へ80倍ダメージの直射弾（間にいる敵はすり抜けて、狙った敵を追いかける）", "max": 1, "req": "cannon"},
	{"id": "sp_mines", "cat": "castle", "special": true, "name": "大砲・機雷散布", "desc": "砲弾が着弾地点のまわりに機雷を3個ばらまく。敵が触れると爆発（20秒残る）", "max": 1, "req": "cannon"},
	# ---- 投石器
	{"id": "sp_treasure", "cat": "castle", "special": true, "name": "投石器・トレジャーシュート", "desc": "投石器のダメージを敵に与えたとき、5%の確率で経験値+1", "max": 1, "req": "catapult"},
	{"id": "sp_split_rock", "cat": "castle", "special": true, "name": "投石器・分裂岩", "desc": "着弾した岩が砕けて、周りに6個の岩が落ちる", "max": 1, "req": "catapult"},
	{"id": "sp_rock_rain", "cat": "castle", "special": true, "name": "投石器・岩雨", "desc": "撃つたびに、ランダムな敵2体の頭上にも岩が落ちる", "max": 1, "req": "catapult"},
	{"id": "sp_direct_hit", "cat": "castle", "special": true, "name": "投石器・巨岩直撃", "desc": "着弾地点の真ん中にいる敵1体に、追加で35倍ダメージ", "max": 1, "req": "catapult"},
	{"id": "sp_rolling", "cat": "castle", "special": true, "name": "投石器・転がり岩", "desc": "着弾した岩がそのまま城と反対の方へ転がり、敵をひいていく", "max": 1, "req": "catapult"},
	# ---- バリスタ
	{"id": "sp_slow_bolt", "cat": "castle", "special": true, "name": "バリスタ・減速ボルト", "desc": "当たった敵の移動速度を2秒間大きく下げる", "max": 1, "req": "ballista"},
	{"id": "sp_ballista_blast", "cat": "castle", "special": true, "name": "バリスタ・爆裂ボルト", "desc": "貫いた敵ごとに小爆発が起きる（矢の威力の約13.8%）", "max": 1, "req": "ballista"},
	{"id": "sp_big_bolt", "cat": "castle", "special": true, "name": "バリスタ・大型弩", "desc": "矢が大きくなって当たり判定が広がり、威力 +50%", "max": 1, "req": "ballista"},
	{"id": "sp_blast_bolt", "cat": "castle", "special": true, "name": "バリスタ・炸裂大矢", "desc": "矢が最初に当たった敵の場所で大爆発（基本の威力の120%の範囲攻撃）", "max": 1, "req": "ballista"},
	{"id": "sp_lightning", "cat": "castle", "special": true, "name": "バリスタ・雷撃", "desc": "5秒ごとに、バリスタ1基につき1本、敵から敵へ7回飛び移る雷を放つ（基本の威力の12.8倍）", "max": 1, "req": "ballista"},
	# ---- 氷結の結界
	{"id": "sp_freeze", "cat": "castle", "special": true, "name": "結界・絶対零度", "desc": "12秒ごとに結界内の敵すべてを1秒間凍らせる", "max": 1, "req": "frost"},
	{"id": "sp_icicle", "cat": "castle", "special": true, "name": "結界・氷柱", "desc": "1.5秒ごとに結界内の敵2体へ氷柱が降る", "max": 1, "req": "frost"},
	{"id": "sp_blizzard", "cat": "castle", "special": true, "name": "結界・吹雪", "desc": "結界の中の敵にずっとダメージを与え続ける", "max": 1, "req": "frost"},
	{"id": "sp_ice_lance", "cat": "castle", "special": true, "name": "結界・氷槍", "desc": "3秒ごとに、結界内で一番HPの多い敵へ大ダメージの氷の槍", "max": 1, "req": "frost"},
	{"id": "sp_snowman", "cat": "castle", "special": true, "name": "結界・雪だるま", "desc": "5秒ごとに結界のふちへ雪だるまを置く（最大6体）。敵が近づくと爆発して周りを1秒凍らせる", "max": 1, "req": "frost"},
	# ---- 狙撃
	{"id": "sp_counter_battery", "cat": "sniper", "special": true, "name": "対砲兵狙撃", "desc": "迫撃砲を最優先で狙う。遠くの敵ほど矢が痛い（100離れるごとに威力 +10%）", "max": 1, "req": "sniper"},
	{"id": "sp_headshot", "cat": "sniper", "special": true, "name": "急所狙い", "desc": "25%の確率で急所に当たり、ダメージ4倍", "max": 1, "req": "sniper"},
	{"id": "sp_pin", "cat": "sniper", "special": true, "name": "縫い止め矢", "desc": "当たった敵を1秒間その場に縫い止める（動けない・攻撃できない）", "max": 1, "req": "sniper"},
	{"id": "sp_ricochet", "cat": "sniper", "special": true, "name": "跳弾矢", "desc": "狙った敵に当たった矢が、近くの別の敵へ最大3回跳ねる（跳ねたあとは矢の威力が5倍）", "max": 1, "req": "sniper"},
	{"id": "sp_mark", "cat": "sniper", "special": true, "name": "弱点看破", "desc": "矢が当たった敵に赤い印。6秒間、味方全員から受けるダメージ +20%", "max": 1, "req": "sniper"},
	# ---- ペット・近衛・修理
	{"id": "sp_pet_burst", "cat": "pet", "special": true, "name": "爆裂遊撃ペット弾", "desc": "遊撃ペットの弾が当たると小爆発する（威力35%）", "max": 1, "req": "pet"},
	{"id": "sp_pet_giant", "cat": "pet", "special": true, "name": "巨大遊撃ペット", "desc": "遊撃ペットが大きくなり、弾も大きく2体貫通、威力 +40%", "max": 1, "req": "pet"},
	{"id": "sp_pet_charge", "cat": "pet", "special": true, "name": "突撃遊撃ペット", "desc": "一定時間ごとに、遊撃ペットが遊撃兵から離れてHPが一番高い敵へ高速で突進する。突進中に触れた敵に1回ずつダメージ（遊撃ペットの攻撃力の32倍）。戻るときはダメージなし", "max": 1, "req": "pet"},
	{"id": "sp_pet_frost", "cat": "pet", "special": true, "name": "凍える遊撃羽根", "desc": "10秒ごとに、全遊撃ペットが敵を追いかける凍結弾を撃つ。当たった敵は0.5秒凍る", "max": 1, "req": "pet"},
	{"id": "sp_pet_heal", "cat": "pet", "special": true, "name": "癒しの遊撃さえずり", "desc": "遊撃ペット1匹につき、担当の遊撃兵のHPが毎秒2回復する", "max": 1, "req": "pet"},
	{"id": "sp_archer_shadow", "cat": "archer", "special": true, "name": "影縫い", "desc": "弓兵の矢が当たった敵の移動速度を3秒間 -40%", "max": 1, "req": "archer"},
	{"id": "sp_archer_rain", "cat": "archer", "special": true, "name": "矢雨の予兆", "desc": "8秒ごとに、弓兵のいる高さの横一列に薄い矢の雨が降る（低威力）", "max": 1, "req": "archer"},
	{"id": "sp_archer_close", "cat": "archer", "special": true, "name": "近城の矢", "desc": "弓兵の攻撃が当たった敵が城に近いほどダメージ増加（最大+60%）", "max": 1, "req": "archer"},
	{"id": "sp_archer_link", "cat": "archer", "special": true, "name": "連携射撃", "desc": "弓兵の攻撃が当たった敵に連携マークを付ける。マークが付いた敵に、マークを付けた弓兵以外の弓兵が攻撃を当てたときダメージ+60%", "max": 1, "req": "archer"},
	{"id": "sp_archer_ult", "cat": "archer", "special": true, "name": "必殺・連珠の玉", "desc": "15秒ごとに、全弓兵が同時に丸い玉を発射する。玉はゆっくりまっすぐ進み、1秒ごとに全方位へ8発の矢を放つ（貫通1）", "max": 1, "req": "archer"},
	{"id": "sp_archer_tornado", "cat": "archer", "special": true, "name": "竜巻矢", "desc": "10秒ごとに竜巻矢を発射する。命中したところに竜巻が生成され、1秒間付近の敵を吸引する", "max": 1, "req": "archer"},
	{"id": "sp_archer_counter", "cat": "archer", "special": true, "name": "反撃の矢", "desc": "被ダメージ時、通常攻撃を1回行う", "max": 1, "req": "archer"},
	{"id": "sp_archer_execute", "cat": "archer", "special": true, "name": "追い討ち", "desc": "HP50%以下の敵からはダメージを受けず、弓兵が与えるダメージが30%増加する", "max": 1, "req": "archer"},
	{"id": "sp_archer_giant_tornado", "cat": "archer", "special": true, "name": "必殺・巨大竜巻", "desc": "40秒に1回、フィールド中央に巨大な竜巻を発生させ、発生地点にいる敵にダメージを与え押し出す", "max": 1, "req": "archer"},
	{"id": "sp_rapid_overheat", "cat": "castle", "special": true, "name": "連射砲・過熱", "desc": "撃ち続けるほど威力が上がる（最大+50%）。1秒撃たないとリセット", "max": 1, "req": "rapid"},
	{"id": "sp_rapid_stun", "cat": "castle", "special": true, "name": "連射砲・気絶弾", "desc": "命中した敵を気絶させ、0.5秒行動を止める", "max": 1, "req": "rapid"},
	{"id": "sp_rapid_sacrifice", "cat": "castle", "special": true, "name": "連射砲・犠牲", "desc": "射撃する度に城のHP -1、連射砲のダメージ +100%", "max": 1, "req": "rapid"},
	{"id": "sp_rapid_low_hp", "cat": "castle", "special": true, "name": "連射砲・背水", "desc": "城のHPが少ないほど攻撃速度増加（最大+80%）。HP残り20%で最大", "max": 1, "req": "rapid"},
	{"id": "sp_rapid_swarm", "cat": "castle", "special": true, "name": "連射砲・数の力", "desc": "侵攻中の敵が多いほどダメージ増加（最大+50%）。500体で最大", "max": 1, "req": "rapid"},
	{"id": "sp_rapid_hp_scale", "cat": "castle", "special": true, "name": "連射砲・強敵狙い", "desc": "攻撃が当たった敵の体力が多いほどダメージ増加（最大+50%）", "max": 1, "req": "rapid"},
	{"id": "sp_rapid_debuff", "cat": "castle", "special": true, "name": "連射砲・弱点付与", "desc": "連射砲の攻撃が当たった敵の被ダメージを5秒間 +15%", "max": 1, "req": "rapid"},
	{"id": "sp_rapid_ult", "cat": "castle", "special": true, "name": "連射砲・必殺・オーバーヒート", "desc": "15秒ごとにオーバーヒートモードになり、5秒間与ダメージ +30%、城に一番近い敵を攻撃する", "max": 1, "req": "rapid"},
	{"id": "sp_rapid_level", "cat": "castle", "special": true, "name": "連射砲・成長", "desc": "城のLvが高いほどダメージ増加（最大+60%）。Lv150で最大", "max": 1, "req": "rapid"},
	{"id": "sp_rapid_reload", "cat": "castle", "special": true, "name": "連射砲・装填", "desc": "50発射撃する度に3秒間射撃できなくなるが、与ダメージ +80%", "max": 1, "req": "rapid"},
	{"id": "sp_archer_pet_burst", "cat": "archer_pet", "special": true, "name": "爆裂ペット斬撃", "desc": "弓兵ペットの斬撃が当たると小爆発する（威力35%）", "max": 1, "req": "archer_pet"},
	{"id": "sp_archer_pet_giant", "cat": "archer_pet", "special": true, "name": "巨大弓兵ペット", "desc": "弓兵ペットが大きくなり、斬撃も大きく2体貫通、威力 +40%", "max": 1, "req": "archer_pet"},
	{"id": "sp_archer_pet_charge", "cat": "archer_pet", "special": true, "name": "突撃弓兵ペット", "desc": "一定時間ごとに、弓兵ペットが弓兵から離れてHPが一番高い敵へ高速で突進する。突進中に触れた敵に1回ずつダメージ（攻撃力の32倍）。戻るときはダメージなし", "max": 1, "req": "archer_pet"},
	{"id": "sp_archer_pet_frost", "cat": "archer_pet", "special": true, "name": "凍える爪", "desc": "10秒ごとに、全弓兵ペットが敵を追いかける凍結斬撃を放つ。当たった敵は0.5秒凍る", "max": 1, "req": "archer_pet"},
	{"id": "sp_archer_pet_heal", "cat": "archer_pet", "special": true, "name": "癒しの羽ばたき", "desc": "弓兵ペット1匹につき、担当の弓兵のHPが毎秒2回復する", "max": 1, "req": "archer_pet"},
	{"id": "sp_archer_pet_dance", "cat": "archer_pet", "special": true, "name": "弓兵ペットの舞", "desc": "弓兵ペットが虹色に光りながらくるくる回り、5秒ごとに全方位へ虹色の斬撃を12発放つ（攻撃力の20倍の威力）", "max": 1, "req": "archer_pet"},
	{"id": "sp_archer_pet_charge_burst", "cat": "archer_pet", "special": true, "name": "爆裂突撃弓兵ペット", "desc": "突進が命中した敵の位置で小爆発が起きる（突進の70%の威力）\n「爆裂ペット斬撃」と「突撃弓兵ペット」を取得している場合のみ出現", "max": 1, "req": "archer_pet", "req_all": ["sp_archer_pet_burst", "sp_archer_pet_charge"]},
	{"id": "sp_archer_pet_flock", "cat": "archer_pet", "special": true, "name": "必殺・刃の大群", "desc": "15秒ごとに、弓兵ペット1匹につき6本の追尾斬撃を放つ。斬撃は敵を追いかけ、当たった敵にくっついて2回斬る（攻撃力の12倍の威力）", "max": 1, "req": "archer_pet"},
	{"id": "sp_archer_pet_body", "cat": "archer_pet", "special": true, "name": "体当たり弓兵ペット", "desc": "弓兵ペットに触れた敵に、攻撃力の12倍ダメージ", "max": 1, "req": "archer_pet"},
	{"id": "sp_archer_pet_fusion", "cat": "archer_pet", "special": true, "name": "弓兵ペット大合体", "desc": "20秒ごとに、全弓兵ペットが合体して10秒間巨大ペットになる。立ち止まって特大斬撃を連発→まっすぐ高速突進をくり返す。\n合体したペットが多いほど強く大きくなり、強化の効果も乗る。合体中のダメージは1.875倍", "max": 1, "req": "archer_pet"},
	{"id": "sp_chain_dash", "cat": "knight", "special": true, "name": "連続突撃", "desc": "突進のあと、近くのまだ貫いていない敵へ続けて2回まで突進する", "max": 1, "req": "knight"},
	{"id": "sp_dash_quake", "cat": "knight", "special": true, "name": "突撃の衝撃", "desc": "突進が止まった所で爆発が起きる（突進の1.5倍の威力）", "max": 1, "req": "knight"},
	{"id": "sp_knight_stun", "cat": "knight", "special": true, "name": "衝撃の槍", "desc": "突進で貫いた敵を1秒間気絶させる", "max": 1, "req": "knight"},
	{"id": "sp_knight_heal", "cat": "knight", "special": true, "name": "勇猛の突撃", "desc": "突進で敵を1体貫くたびに、近衛兵のHPが8回復する", "max": 1, "req": "knight"},
	{"id": "sp_knight_execute", "cat": "knight", "special": true, "name": "とどめの一撃", "desc": "HPが2割以下の敵（ボス以外）は、突進で一撃で倒す", "max": 1, "req": "knight"},
	{"id": "sp_first_aid", "cat": "repair", "special": true, "name": "応急手当", "desc": "フィールド全体の味方（遊撃・迎撃・近衛・重装）のHPも、修理兵が城を直すのと同じ量だけ回復する", "max": 1, "req": "repairer"},
	{"id": "sp_emergency", "cat": "repair", "special": true, "name": "緊急修理", "desc": "城のHPが3割より少ないとき、修理の速さが2倍になる", "max": 1, "req": "repairer"},
	{"id": "sp_armor", "cat": "repair", "special": true, "name": "鉄壁補強", "desc": "城が受けるダメージ -10%", "max": 1, "req": "repairer"},
	{"id": "sp_maintenance", "cat": "repair", "special": true, "name": "設備点検", "desc": "城の設備（矢倉・大砲・投石器・バリスタ）の発射間隔 -15%", "max": 1, "req": "repairer"},
	{"id": "sp_wall_fix", "cat": "repair", "special": true, "name": "壁職人", "desc": "修理兵が城と一緒に壁も直す（1人につき4秒ごとに1発分）", "max": 1, "req": "repairer"},
	# ---- おもしろ強化（あまり強くないけど、変で派手なやつ）
	{"id": "sp_fun_fireworks", "cat": "soldier", "special": true, "name": "勝利の花火", "desc": "遊撃兵が敵を倒すと、30%で花火が打ち上がる（弾けた所に剣の40倍のダメージ）", "max": 1},
	{"id": "sp_fun_reflect", "cat": "guard", "special": true, "name": "黄金の盾", "desc": "15秒ごとに、迎撃兵が向いている方向へ大きな黄金の盾を飛ばす（ゆっくり進む・盾の2倍の大きさ）。黄金の盾に当たった敵の弾は消え、そのたびに黄金の盾から全方位へ弾を撃つ（槍の5倍の威力）", "max": 1, "req": "guard"},
	{"id": "sp_fun_firework_arrow", "cat": "sniper", "special": true, "name": "花火矢", "desc": "毎回、矢と一緒に花火も撃ち込む", "max": 1, "req": "sniper"},
	{"id": "sp_fun_roar", "cat": "heavy", "special": true, "name": "雄叫び", "desc": "10秒ごとに雄叫びを上げ、周りの敵に斬撃3倍のダメージを与えて思いっきり吹き飛ばす", "max": 1, "req": "heavy"},
	{"id": "sp_fun_jack", "cat": "builder", "special": true, "name": "ビックリ箱壁", "desc": "壁が攻撃を防ぐと、35%でビックリ箱が飛び出して敵を吹き飛ばす", "max": 1, "req": "builder"},
	{"id": "sp_fun_scarecrow", "cat": "engineer", "special": true, "name": "かかし", "desc": "罠と一緒にかかしを立てる。敵の気を引いて、代わりに殴られてくれる（耐久60）", "max": 1, "req": "engineer"},
	{"id": "sp_scarecrow_poison", "cat": "engineer", "special": true, "name": "毒かかし", "desc": "かかしが壊れたとき、その場に毒沼が発生するようになる\n「毒沼」と「かかし」を取得している場合のみ出現", "max": 1, "req": "engineer", "req_all": ["sp_poison", "sp_fun_scarecrow"]},
	{"id": "sp_fun_doves", "cat": "castle", "special": true, "name": "矢倉・伝書鳩部隊", "desc": "6秒ごとに、矢倉から敵を追いかける白い鳩が飛び立つ。当たった敵が生き残っていたらくっついて、1秒ごとにあと2回つつく", "max": 1, "req": "tower"},
	{"id": "sp_fun_billiard", "cat": "castle", "special": true, "name": "大砲・ビリヤード砲弾", "desc": "砲弾が着弾したあと、同じ向きに2回跳ねる（1回目は砲弾の2.5倍、2回目はその半分の威力）", "max": 1, "req": "cannon"},
	{"id": "sp_billiard_mines", "cat": "castle", "special": true, "name": "大砲・ビリヤード機雷", "desc": "ビリヤード砲弾が跳ねて着地したときにも、機雷をばらまくようになる\n「大砲・ビリヤード砲弾」と「大砲・機雷散布」を取得している場合のみ出現", "max": 1, "req": "cannon", "req_all": ["sp_fun_billiard", "sp_mines"]},
	{"id": "sp_meteor_rock", "cat": "castle", "special": true, "name": "投石器・隕石の居座り岩", "desc": "隕石落としの落下地点にも、大きな居座り岩が5秒間残るようになる\n「投石器・必殺・隕石落とし」と「投石器・居座り岩」を取得している場合のみ出現", "max": 1, "req": "catapult", "req_all": ["sp_ult_meteor", "sp_stay_rock"]},
	{"id": "sp_thunder_momentum", "cat": "castle", "special": true, "name": "バリスタ・破竹の雷槍", "desc": "雷神の大槍にも破竹の効果が乗り、敵に当たるたびに威力が +10% ずつ増えていく（最大 +100%）\n「バリスタ・必殺・雷神の大槍」と「バリスタ・破竹の大矢」を取得している場合のみ出現", "max": 1, "req": "ballista", "req_all": ["sp_ult_thunder", "sp_bolt_momentum"]},
	{"id": "sp_snowball_snowman", "cat": "castle", "special": true, "name": "結界・雪だるま合戦", "desc": "雪合戦の雪玉が当たった所に、雪だるまを置くようになる\n「結界・雪だるま」と「結界・雪合戦」を取得している場合のみ出現", "max": 1, "req": "frost", "req_all": ["sp_snowman", "sp_fun_snowball"]},
	{"id": "sp_fun_cow", "cat": "castle", "special": true, "name": "投石器・牛投げ", "desc": "3回に1回、岩のかわりに大きな牛（ふつうの2.1倍）を投げる。着地した牛は6秒間、近くの敵へ何度も突進する", "max": 1, "req": "catapult"},
	{"id": "sp_fun_rainbow", "cat": "castle", "special": true, "name": "バリスタ・虹の矢", "desc": "矢が虹色の尾を引き、当たった敵は1.5秒間混乱してふらふら歩く", "max": 1, "req": "ballista"},
	{"id": "sp_fun_snowball", "cat": "castle", "special": true, "name": "結界・雪合戦", "desc": "城から近くの敵へ雪玉を投げ続ける（ちょっとだけ止まる）", "max": 1, "req": "frost"},
	{"id": "sp_fun_dance", "cat": "pet", "special": true, "name": "遊撃ペットの踊り", "desc": "遊撃ペットが虹色に光りながらくるくる回り、5秒ごとに全方位へ虹色の玉を12発撃つ（遊撃ペットの攻撃力の20倍の威力）", "max": 1, "req": "pet"},
	{"id": "sp_pet_charge_burst", "cat": "pet", "special": true, "name": "爆裂突撃遊撃ペット", "desc": "突進が命中した敵の位置で小爆発が起きる（突進の70%の威力）\n「爆裂遊撃ペット弾」と「突撃遊撃ペット」を取得している場合のみ出現", "max": 1, "req": "pet", "req_all": ["sp_pet_burst", "sp_pet_charge"]},
	{"id": "sp_fun_star", "cat": "knight", "special": true, "name": "流れ星突撃", "desc": "突進の跡にキラキラの星が残って弾ける（小ダメージ）", "max": 1, "req": "knight"},
	{"id": "sp_repair_orb", "cat": "repair", "special": true, "name": "修理玉", "desc": "20秒ごとに城の前へ修理玉を置く（当たり判定なし）。\n置いてから10秒間に回復した城のHPの20倍のダメージの弾を、HPが一番多い敵へゆっくり撃つ（貫通無限）", "max": 1, "req": "repairer"},
	# ---- 15秒ごとの必殺技（各種類の6つ目）
	{"id": "sp_ult_flock", "cat": "pet", "special": true, "name": "必殺・遊撃鳥の大群", "desc": "15秒ごとに、遊撃ペット1匹につき6羽の鳥を呼ぶ。鳥は敵を追いかけ、当たった敵にくっついて2回つつく（遊撃ペットの12倍の威力）", "max": 1, "req": "pet"},
	# ---- 8つ目の特別強化
	{"id": "sp_touch_blast", "cat": "soldier", "special": true, "name": "触爆", "desc": "遊撃兵に触れた敵が爆発し、周りの敵に射撃の1.5倍ダメージ", "max": 1},
	{"id": "sp_berserk_guard", "cat": "guard", "special": true, "name": "捨て身の構え", "desc": "迎撃兵の最大HPが半分になり、盾で防いでも半分のダメージを受ける。そのかわり槍が当たった敵が爆発し、周りに槍の3倍ダメージ", "max": 1, "req": "guard"},
	{"id": "sp_blast_arrow", "cat": "sniper", "special": true, "name": "爆裂矢", "desc": "矢が当たった敵が爆発し、周りの敵に小ダメージ（急所狙いの効果は乗らない）", "max": 1, "req": "sniper"},
	{"id": "sp_firework_blast", "cat": "sniper", "special": true, "name": "花火爆裂矢", "desc": "花火矢の花火が敵に当たったときも爆裂矢が発動し、爆裂矢が発動したときに花火のエフェクトが出る\n「爆裂矢」と「花火矢」を取得している場合のみ出現", "max": 1, "req": "sniper", "req_all": ["sp_blast_arrow", "sp_fun_firework_arrow"]},
	{"id": "sp_rage", "cat": "heavy", "special": true, "name": "怒りの闘志", "desc": "ダメージを受けるたびに重装兵の与ダメージ +5%（最大+40%）。2秒ダメージを受けないと元に戻る", "max": 1, "req": "heavy"},
	{"id": "sp_counter_wall", "cat": "builder", "special": true, "name": "反撃壁", "desc": "敵の弾が壁に当たると、その場所から近くの敵へ弾を撃ち返す", "max": 1, "req": "builder"},
	{"id": "sp_automaton", "cat": "engineer", "special": true, "name": "巨大からくり兵", "desc": "20秒ごとに、ボスの2倍の大きさのからくり兵を置く（10秒で消える）。ゆっくり歩き、広い全方位斬り1回→別々の2か所へ大きな弾（10体貫通）の高速連射をくり返す。消えるときに超広範囲の大爆発", "max": 1, "req": "engineer"},
	{"id": "sp_tower_blast", "cat": "castle", "special": true, "name": "矢倉・爆裂矢", "desc": "矢倉の矢が当たった敵が爆発し、周りの敵に矢の1/8のダメージ", "max": 1, "req": "tower"},
	{"id": "sp_homing_blast", "cat": "castle", "special": true, "name": "矢倉・爆裂追尾火矢", "desc": "追尾火矢が当たった敵にも、爆裂矢の爆発が起きるようになる\n「矢倉・爆裂矢」と「矢倉・追尾火矢」を取得している場合のみ出現", "max": 1, "req": "tower", "req_all": ["sp_tower_blast", "sp_homing"]},
	{"id": "sp_stay_rock", "cat": "castle", "special": true, "name": "投石器・居座り岩", "desc": "着弾地点に大岩が5秒間残り、上にいる敵にダメージを与え続け、移動速度 -30%", "max": 1, "req": "catapult"},
	{"id": "sp_mega_bolt", "cat": "castle", "special": true, "name": "バリスタ・巨大弩砲", "desc": "8秒ごとに、3倍の大きさ・基本の威力の7.2倍の矢を、HPが一番多い敵へゆっくり（速さ1/3）撃つ", "max": 1, "req": "ballista"},
	{"id": "sp_frost_ground", "cat": "castle", "special": true, "name": "結界・凍てつく大地", "desc": "結界の中の地面が凍りつき、中にいる敵にずっとダメージを与える（吹雪と重ねがけできる）", "max": 1, "req": "frost"},
	{"id": "sp_pet_body", "cat": "pet", "special": true, "name": "体当たり遊撃ペット", "desc": "遊撃ペットに触れた敵に、遊撃ペットの攻撃力の12倍ダメージ", "max": 1, "req": "pet"},
	{"id": "sp_carry", "cat": "knight", "special": true, "name": "連行突撃", "desc": "突進で当たった敵（ボス以外）を、突進が終わるまで槍の先に引っかけて連れていく", "max": 1, "req": "knight"},
	{"id": "sp_tool_throw", "cat": "repair", "special": true, "name": "工具投げ", "desc": "城のHPが満タンのとき、修理兵が近くの敵へスパナを投げつける（行って戻ってくる）", "max": 1, "req": "repairer"},
	{"id": "sp_ult_cavalry", "cat": "knight", "special": true, "name": "必殺・百騎突撃", "desc": "15秒ごとに、一番下の敵のあたりを騎士の幻8騎が横一列で駆け抜け、通った敵を全部はねる（突進の37.5倍の威力）", "max": 1, "req": "knight"},
	{"id": "sp_cavalry_star", "cat": "knight", "special": true, "name": "流星百騎", "desc": "百騎突撃の騎士の幻が駆け抜けた跡にも、流れ星が残って弾ける\n「必殺・百騎突撃」と「流れ星突撃」を取得している場合のみ出現", "max": 1, "req": "knight", "req_all": ["sp_ult_cavalry", "sp_fun_star"]},
	{"id": "sp_ult_overhaul", "cat": "repair", "special": true, "name": "必殺・大修繕", "desc": "15秒ごとに、城のHPを最大HPの5%回復し、味方のHPを全回復する（壁は直さない）", "max": 1, "req": "repairer"},
	{"id": "sp_ult_storm", "cat": "soldier", "special": true, "name": "必殺・剣の大嵐", "desc": "15秒ごとに、遊撃兵全員が周りを巻き込む巨大な回転斬り（剣の40倍の威力・大きく吹き飛ばす）", "max": 1},
	{"id": "sp_ult_dome", "cat": "guard", "special": true, "name": "必殺・鉄壁の陣", "desc": "15秒ごとに、城をドームで5秒間包む。ドームに入った敵の弾・砲弾は消える。迎撃兵のHPも全回復", "max": 1, "req": "guard"},
	{"id": "sp_dome_spikes", "cat": "guard", "special": true, "name": "拒馬の陣", "desc": "鉄壁の陣のドームの中にいる敵に、拒馬の柵の効果（移動速度20%ダウン・ダメージ）を与える\n「拒馬の柵」と「必殺・鉄壁の陣」を取得している場合のみ出現", "max": 1, "req": "guard", "req_all": ["sp_spikes", "sp_ult_dome"]},
	{"id": "sp_ult_sky_arrow", "cat": "sniper", "special": true, "name": "必殺・天穿つ一矢", "desc": "15秒ごとに、狙撃兵が敵が一番多く並ぶ方向へ巨大な矢を放つ（基本の威力の180倍で全部貫く。通常の矢の約86倍）", "max": 1, "req": "sniper"},
	{"id": "sp_ult_leap", "cat": "heavy", "special": true, "name": "必殺・大地砕き", "desc": "15秒ごとに、重装兵が近くの敵の群れへ飛び込み、地面を叩き割る（斬撃4倍の範囲攻撃＋1秒気絶）", "max": 1, "req": "heavy"},
	{"id": "sp_ult_wall_burst", "cat": "builder", "special": true, "name": "必殺・城壁の大号令", "desc": "15秒ごとに、すべての壁の耐久が10回復し、全部の壁が外側へ大爆発する", "max": 1, "req": "builder"},
	{"id": "sp_ult_carpet", "cat": "engineer", "special": true, "name": "必殺・絨毯爆撃", "desc": "15秒ごとに、敵が密集した所へ一直線に13個の爆弾が降りそそぐ", "max": 1, "req": "engineer"},
	{"id": "sp_ult_thousand", "cat": "castle", "special": true, "name": "矢倉・必殺・千本矢", "desc": "15秒ごとに、フィールド中の敵30か所へ一斉に矢の雨が降る（矢倉の3倍の威力）", "max": 1, "req": "tower"},
	{"id": "sp_ult_barrage", "cat": "castle", "special": true, "name": "大砲・必殺・一斉砲撃", "desc": "15秒ごとに、12発の砲弾を一気に撃ち込む（大砲の6倍の威力）", "max": 1, "req": "cannon"},
	{"id": "sp_ult_meteor", "cat": "castle", "special": true, "name": "投石器・必殺・隕石落とし", "desc": "15秒ごとに、敵の群れへ巨大な燃える隕石を落とす（投石器の1.5倍の威力・超広範囲、跡が燃える）", "max": 1, "req": "catapult"},
	{"id": "sp_ult_thunder", "cat": "castle", "special": true, "name": "バリスタ・必殺・雷神の大槍", "desc": "15秒ごとに、敵が一番多く並ぶ方向へ雷の大槍を放つ（基本の威力の4.8倍＋1秒しびれる）", "max": 1, "req": "ballista"},
	{"id": "sp_ult_ice_age", "cat": "castle", "special": true, "name": "結界・必殺・氷河期", "desc": "15秒ごとに、結界の2倍以上の広さの敵をまとめて1秒凍らせてダメージ", "max": 1, "req": "frost"},
	# --- 9つ目の特別強化（面白くてしっかり強いもの）
	{"id": "sp_boss_hunt", "cat": "soldier", "special": true, "name": "魔王狩り", "desc": "遊撃兵がボスを最優先で狙うようになる。遊撃兵のボスへのダメージ +10%", "max": 1},
	{"id": "sp_giant_spear", "cat": "guard", "special": true, "name": "神槍投擲", "desc": "8秒ごとに、迎撃兵が一番近い敵の方へ巨大な槍を投げる。槍はゆっくり進み、通った敵を全部貫く（槍の5倍の威力）", "max": 1, "req": "guard"},
	{"id": "sp_rapid_snipe", "cat": "sniper", "special": true, "name": "速射の極意", "desc": "狙撃兵の攻撃力が1/3になるかわりに、攻撃速度が4倍になる", "max": 1, "req": "sniper"},
	{"id": "sp_kill_chain", "cat": "knight", "special": true, "name": "疾風怒濤", "desc": "突進で敵を倒すたびに、すぐ次の敵へ突進し直す（最大5連鎖）", "max": 1, "req": "knight"},
	{"id": "sp_provoke", "cat": "heavy", "special": true, "name": "仁王立ち", "desc": "10秒ごとに、まわりの敵を挑発して5秒のあいだ重装兵を狙わせる。近くの敵1体につき、重装兵の与ダメージ +5%（最大+40%）", "max": 1, "req": "heavy"},
	{"id": "sp_provoke_ball", "cat": "heavy", "special": true, "name": "仁王の鉄球", "desc": "仁王立ちで挑発をかけたらすぐ、挑発した敵全部へ鉄球を投げる\n「仁王立ち」と「鉄球投げ」を取得している場合のみ出現", "max": 1, "req": "heavy", "req_all": ["sp_provoke", "sp_iron_ball"]},
	{"id": "sp_spike_wall", "cat": "builder", "special": true, "name": "剣山の壁", "desc": "敵が壁に触れると、壁からトゲが飛び出して周りの敵にダメージ（壁1枚につき6秒に1回）", "max": 1, "req": "builder"},
	{"id": "sp_automaton_squad", "cat": "engineer", "special": true, "name": "からくり兵団", "desc": "巨大からくり兵を一度に2体置くようになる", "max": 1, "req": "sp_automaton"},
	{"id": "sp_overwork", "cat": "repair", "special": true, "name": "背水の修繕", "desc": "修理兵1人につき、城のHPが毎秒50ずつ減るようになる（最大HPの40%より下にはならない）。かわりに修理兵1人の回復量 +20/秒（城のHPが40%以下のときは +1/秒だけ）", "max": 1, "req": "repairer"},
	{"id": "sp_repair_orb_triple", "cat": "repair", "special": true, "name": "三連修理玉", "desc": "修理玉の弾を3個、3方向に発射するようになる\n「修理玉」と「背水の修繕」を取得している場合のみ出現", "max": 1, "req": "repairer", "req_all": ["sp_repair_orb", "sp_overwork"]},
	{"id": "sp_pet_fusion", "cat": "pet", "special": true, "name": "遊撃ペット大合体", "desc": "20秒ごとに、全遊撃ペットが合体して10秒間巨大ペットになる。立ち止まって特大弾を連射→まっすぐ高速突進をくり返す。\n合体したペットが多いほど強く大きくなり、ペットの強化の効果も乗る。合体中のダメージは1.875倍", "max": 1, "req": "pet"},
	{"id": "sp_tower_lock", "cat": "castle", "special": true, "name": "矢倉・執念の矢", "desc": "狙った敵を倒せなかったら、次も同じ敵を狙う。同じ敵を狙い続けるほど矢が強くなる（1回ごとに+20%、最大3倍）", "max": 1, "req": "tower"},
	{"id": "sp_cannon_bomb", "cat": "castle", "special": true, "name": "大砲・置き土産", "desc": "砲弾が着弾した場所に爆弾を置く。近くに敵が来ると爆発する（大砲の1.5倍の威力）", "max": 1, "req": "cannon"},
	{"id": "sp_iron_chunk", "cat": "castle", "special": true, "name": "投石器・鉄塊投げ", "desc": "4発に1回、ふつうの岩と一緒に、HPが一番多い敵へ鉄塊を投げる（投石器の128倍の威力）", "max": 1, "req": "catapult"},
	{"id": "sp_bolt_momentum", "cat": "castle", "special": true, "name": "バリスタ・破竹の大矢", "desc": "バリスタの矢が敵に当たるたびに、その矢の威力が +10% ずつ増えていく（最大 +100%）", "max": 1, "req": "ballista"},
	{"id": "sp_ice_statue", "cat": "castle", "special": true, "name": "結界・氷像の囮", "desc": "結界の中で倒された敵が20%の確率で氷像になる。氷像はほかの敵に最優先で狙われる（1回攻撃されると砕ける）", "max": 1, "req": "frost"},
	# ---- 採掘場
	{"id": "sp_mine_second", "cat": "castle", "special": true, "name": "採掘場・第二採掘場", "desc": "城の反対側（左側・壁の外）にも採掘場を建てる（採掘の間隔・経験値の強化は両方に効く。どちらも1人ずつ掘れる）", "max": 1, "req": "mine_site"},
	{"id": "sp_mine_miner", "cat": "castle", "special": true, "name": "採掘場・採掘兵", "desc": "採掘だけを行う採掘兵が1人出撃する（戦わない・敵に狙われない。空いている採掘場に入り、兵士が掘っていれば交代する）", "max": 1, "req": "mine_site"},
	{"id": "sp_mine_shards", "cat": "castle", "special": true, "name": "採掘場・岩のかけら", "desc": "掘るたびに、採掘場の近くの敵3体へ岩のかけらを山なりに投げる。外れたら落ちた所に10秒残り、触れた敵に当たる", "max": 1, "req": "mine_site"},
	{"id": "sp_mine_mole", "cat": "castle", "special": true, "name": "採掘場・もぐら", "desc": "3回掘るごとに採掘場からもぐらが出てきて、地面の下を進み、敵の足元から飛び出して攻撃する。また潜って、攻撃を3回くり返す", "max": 1, "req": "mine_site"},
	{"id": "sp_mine_fast", "cat": "castle", "special": true, "name": "採掘場・快足の鉱夫", "desc": "採掘場へ向かうときと、採掘場から戻るときの移動速度が2倍になる", "max": 1, "req": "mine_site"},
	{"id": "sp_ult_trolley", "cat": "castle", "special": true, "name": "採掘場・必殺・暴走トロッコ", "desc": "15秒ごとに、画面の右端から左端へトロッコが突進して、通った敵を全部はねる。はねた敵1体につき経験値+1", "max": 1, "req": "mine_site"},
	{"id": "sp_mine_gem", "cat": "castle", "special": true, "name": "採掘場・宝石の鉱脈", "desc": "掘ったとき10%で宝石が出て、その回の経験値が10になる", "max": 1, "req": "mine_site"},
	{"id": "sp_mine_heal", "cat": "castle", "special": true, "name": "採掘場・城の補修石", "desc": "掘るたびに、城のHPを5回復する", "max": 1, "req": "mine_site"},
	{"id": "sp_mine_bomb", "cat": "castle", "special": true, "name": "採掘場・発破用の爆弾", "desc": "掘ったとき10%で爆弾が出て、採掘場の近くに置く。敵が近づくと爆発", "max": 1, "req": "mine_site"},
	{"id": "sp_mole_bomb", "cat": "castle", "special": true, "name": "採掘場・もぐら爆弾", "desc": "もぐらが攻撃した場所に、発破用の爆弾を置くようになる\n「採掘場・もぐら」と「採掘場・発破用の爆弾」を取得している場合のみ出現", "max": 1, "req": "mine_site", "req_all": ["sp_mine_mole", "sp_mine_bomb"]},
	# --- 城（本体）の特別強化（城はいつもいるので、いつでも候補に出る）
	{"id": "sp_castle_fountain", "cat": "castle", "special": true, "name": "城・生命の泉", "desc": "城の自然回復が毎秒3になる", "max": 1},
	{"id": "sp_castle_rage", "cat": "castle", "special": true, "name": "城・城の怒り", "desc": "城のHPが50%より少ないとき、味方全員（部隊・兵装）の与ダメージ +20%", "max": 1},
	{"id": "sp_castle_last_stand", "cat": "castle", "special": true, "name": "城・不屈の城", "desc": "城のHPが0になったとき、ボス以外の敵を全部消して、HPが20%で立ち直る（1回のゲームで1回まで）", "max": 1},
	{"id": "sp_castle_laser", "cat": "castle", "special": true, "name": "城・城レーザー", "desc": "30秒ごとに、城から、正面から1周してマップ全体を薙ぎ払うレーザーを撃つ（威力はレベル×15）", "max": 1},
	{"id": "sp_castle_sneeze", "cat": "castle", "special": true, "name": "城・城の火炎くしゃみ", "desc": "15秒ごとに城が火炎くしゃみ。城（城ロボ起動中は城ロボ）から、マップの真ん中へ向けて2秒間の火炎放射を吹き出す（威力はレベルに合わせて上がる）", "max": 1},
	{"id": "sp_castle_store", "cat": "castle", "special": true, "name": "城・城の蓄え", "desc": "城がダメージを受けると、10ダメージごとに経験値 +1（背水の修繕で減る分は入らない）", "max": 1},
	{"id": "sp_castle_robot", "cat": "castle", "special": true, "name": "城・城ロボ起動", "desc": "城からロボットが出撃して25秒間暴れまわり、戻ってから25秒後にまた出撃する（城は動かない）", "max": 1},
	# 城ロボの追加の特別強化（城ロボ起動を取っていると出る。オート選択などでは「城」のグループあつかい）
	{"id": "sp_castle_robot_flight", "cat": "castle", "special": true, "name": "城・城ロボ フライトモード", "desc": "城ロボにロボットウイングが付いて空を飛ぶ。両手を上げて遠くの敵へ高速タックル → 両手から誘導ミサイルを30発 をくり返す", "max": 1, "req": "sp_castle_robot", "group": "castle"},
	{"id": "sp_castle_robot_final", "cat": "castle", "special": true, "name": "城・城ロボ ファイナルモード", "desc": "城ロボが画面の真ん中に出撃して動かずに戦う。10本のビームをそれぞれランダムな敵へ撃ち続け（途中にいる敵にも当たる）、城レーザーは上下2本同時に撃ちながら、両手から誘導ミサイルを撃ち続ける（攻撃の切れ目なし）。城に設置する各種兵装の通常強化を全て取得した場合のみ取得可能", "max": 1, "req": "sp_castle_robot_flight", "group": "castle",
		# 候補には出るが、城の兵装（矢倉・大砲・投石器・バリスタ・砲術）の通常強化を全部最大まで取っていないと選べない
		"req_maxed": ["tower", "cannon", "catapult", "ballista", "artillery"]},
	{"id": "sp_castle_robot_true", "cat": "castle", "special": true, "name": "城・城ロボ 真・ファイナルモード", "desc": "真の力を解放する\n「城・城の火炎くしゃみ」と「城・城レーザー」を取得している場合のみ取得できる", "max": 1, "req": "sp_castle_robot_final", "req_owned": ["sp_castle_sneeze", "sp_castle_laser"], "group": "castle"},
]

const CAT_LABEL := {"soldier": "遊撃", "pet": "ペット", "builder": "築城", "guard": "迎撃", "sniper": "狙撃", "knight": "近衛",
	"heavy": "重装", "engineer": "工兵", "repair": "修理", "archer": "弓兵", "archer_pet": "弓兵ペット", "castle": "城"}
const CAT_COLOR := {
	"pet": Color(0.55, 1.0, 0.75), "knight": Color(1.0, 0.82, 0.4), "repair": Color(0.55, 0.75, 1.0),
	"sniper": Color(0.75, 0.95, 0.45), "archer": Color(0.9, 0.7, 0.5), "archer_pet": Color(0.7, 0.9, 0.6),
	"soldier": Color(0.6, 0.85, 1.0), "builder": Color(1.0, 0.88, 0.45),
	"guard": Color(0.6, 1.0, 0.65), "heavy": Color(0.85, 0.75, 1.0), "engineer": Color(0.8, 0.9, 0.5), 
	"castle": Color(1.0, 0.7, 0.45), "rapid": Color(1.0, 0.6, 0.3)}


## オート選択設定などで使う「部隊・兵装」の一覧（表示名, キー）
const GROUPS := [
	["遊撃", "soldier"], ["ペット", "pet"], ["迎撃", "guard"], ["狙撃", "sniper"], ["近衛", "knight"],
	["重装", "heavy"], ["工兵", "engineer"], ["築城", "builder"], ["修理", "repair"],
	["弓兵", "archer"], ["弓兵ペット", "archer_pet"],
	["矢倉", "tower"], ["大砲", "cannon"], ["投石器", "catapult"], ["バリスタ", "ballista"], ["連射砲", "rapid"],
	["氷結の結界", "frost"], ["採掘場", "mine_site"], ["城（本体）", "castle"]]
## 城の通常強化がどの兵装のものか
const CASTLE_UPGRADE_GROUPS := {"tower": ["tower"], "tower_dmg": ["tower"], "tower_rate": ["tower"], "tower_pierce": ["tower"], "tower_multi": ["tower"], "cannon": ["cannon"], "cannon_multi": ["cannon"], "catapult": ["catapult"], "catapult_multi": ["catapult"], "ballista": ["ballista"], "ballista_dmg": ["ballista"], "ballista_rate": ["ballista"], "ballista_multi": ["ballista"], "rapid": ["rapid"],
	"rapid_dmg": ["rapid"], "rapid_rate": ["rapid"], "rapid_pierce": ["rapid"], "rapid_multi": ["rapid"],
	"artillery": ["cannon"], "cannon_rate": ["cannon"], "cannon_range": ["cannon"],
	"catapult_dmg": ["catapult"], "catapult_rate": ["catapult"], "catapult_range": ["catapult"],
	"frost": ["frost"], "frost_range": ["frost"], "frost_slow": ["frost"],
	"mine_site": ["mine_site"], "mine_speed": ["mine_site"], "mine_yield": ["mine_site"], "wall": ["castle"]}


## 強化がどの部隊・兵装のものか（複数のこともある）
static func groups_of(u: Dictionary) -> Array:
	if u["cat"] != "castle":
		return [u["cat"]]
	if u.has("group"):
		return [u["group"]]
	if u.get("special", false):
		return [u.get("req", "castle")]
	return CASTLE_UPGRADE_GROUPS.get(u["id"], ["castle"])


## 強化の優先度（2=最優先、1=優先、0=なし）
static func priority_of(u: Dictionary, priority: Dictionary) -> int:
	var p := 0
	for g in groups_of(u):
		p = maxi(p, int(priority.get(g, 0)))
	return p


## オート選択：候補の中から、優先度（3=最優先、2=優先、1=ちょっと優先、0=なし）が一番高いものを選ぶ。同じならランダム
static func auto_choose(choices: Array, priority: Dictionary) -> Dictionary:
	var best: Array = []
	var best_p := -1
	for u in choices:
		var p := priority_of(u, priority)
		if p > best_p:
			best_p = p
			best = [u]
		elif p == best_p:
			best.append(u)
	return best[randi() % best.size()]


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
		# req_all：ここに書いた強化を全部取っていないと候補に出ない
		if u.has("req_all") and u["req_all"].any(func(r) -> bool: return int(levels.get(r, 0)) <= 0):
			continue
		available.append(u)
	# 出やすさに合わせて、重なりなしでランダムに選ぶ
	var result: Array = []
	while result.size() < n and not available.is_empty():
		var total := 0.0
		for u in available:
			total += special_weight(u, levels)
		var r := randf() * total
		var pick: int = available.size() - 1
		for i in available.size():
			r -= special_weight(available[i], levels)
			if r <= 0.0:
				pick = i
				break
		result.append(available[pick])
		available.remove_at(pick)
	return result


## 候補に出ているけど、まだ取れない強化か（取るための条件を満たしていない）
static func is_locked(u: Dictionary, levels: Dictionary) -> bool:
	if u.has("req_maxed") and not _all_maxed(u["req_maxed"], levels):
		return true
	# req_owned：ここに書いた強化（特別強化も可）を全部取っていないと選べない（候補には出る）
	if u.has("req_owned"):
		for id in u["req_owned"]:
			if int(levels.get(id, 0)) <= 0:
				return true
	return false


## ids の通常強化が全部最大レベルまで取れているか
static func _all_maxed(ids: Array, levels: Dictionary) -> bool:
	for id in ids:
		for u in LIST:
			if u["id"] == id and int(levels.get(id, 0)) < int(u["max"]):
				return false
	return true


## 城の兵装（矢倉・大砲・投石器・バリスタ）の強化レベルの合計が、1つ増えるごとに「城ロボ起動」が出やすくなる割合
## （1/14。全部取った合計14レベルでちょうど2倍）
const ROBOT_WEIGHT_PER_LEVEL := 1.0 / 14.0


## 特別強化の出やすさ（ふつうは1）。城ロボ起動は、城の兵装をたくさん取っているほど出やすい
static func special_weight(u: Dictionary, levels: Dictionary) -> float:
	if u["id"] == "sp_castle_robot":
		var n := 0
		for k in ["tower", "cannon", "catapult", "ballista"]:
			n += int(levels.get(k, 0))
		return 1.0 + ROBOT_WEIGHT_PER_LEVEL * n
	return 1.0


static func describe(u: Dictionary, current_level: int) -> String:
	if current_level > 0 and u.has("desc_up"):
		return u["desc_up"]
	return u["desc"]


## new_level = 取得後のレベル（1始まり）
## ペットの攻撃力 = 基本 ×（1 + 0.2 × 牙のレベル）× 1.2^(ペットの強化のレベル - 1)。
## 「ペット」の2回目以降の+20%と「牙」の+20%の両方が乗るように、毎回レベルから計算し直して、いるペット全員に入れる
static func _update_pet_damage(game: Node2D) -> void:
	var lv: Dictionary = game.upgrade_levels
	game.pet_damage = 12.0 * (1.0 + 0.2 * int(lv.get("pet_fang", 0))) * pow(1.2, maxi(0, int(lv.get("pet", 0)) - 1))
	for p in game.pets:
		p.damage = game.pet_damage
	game.archer_pet_damage = 32.0 * (1.0 + 0.2 * int(lv.get("archer_pet_fang", 0))) * pow(1.2, maxi(0, int(lv.get("archer_pet", 0)) - 1))
	for p in game.archer_pets:
		p.damage = game.archer_pet_damage


static func apply(id: String, new_level: int, game: Node2D) -> void:
	var st = game.stats
	var castle: Node2D = game.castle
	match id:
		"recruit":
			game.add_soldier()
		"multishot":
			st.shot_count += 1
		"firerate":
			st.fire_interval = maxf(0.1, 0.55 * (1.0 - 0.1 * new_level))
		"bullet_dmg":
			st.bullet_damage = 10.0 * (1.0 + 0.2 * new_level)
		"pierce":
			st.bullet_pierce += 1
		"sword_dmg":
			st.sword_damage = 32.0 * (1.0 + 0.2 * new_level)
		"sword_range":
			st.sword_radius = 85.0 * (1.0 + 0.2 * new_level)
		"whirlwind":
			st.sword_arc = TAU
		"dash":
			st.dash_level = new_level
			if new_level > 1:
				st.dash_interval = maxf(0.5, 4.0 * (1.0 - 0.1 * new_level))
				st.dash_damage *= 1.3
		"pet":
			game.add_pet()
			_update_pet_damage(game)
		"soldier_hp":
			st.max_hp += 25.0
			for s in game.soldiers:
				if not s.dead:
					s.hp = st.max_hp
		"builder":
			game.add_builder()
		"build_speed":
			game.walls.build_time *= 0.8
		"wall_hp":
			game.walls.add_wall_hp(2.0)
		"wall_width":
			game.walls.wall_width += deg_to_rad(2.4)
		"guard":
			game.add_guard()
		"shield_arc":
			game.guard_stats.shield_arc += deg_to_rad(20.0)
			game.guard_stats.shield_taken = maxf(0.0, 0.2 - 0.05 * new_level)
		"spear_reach":
			game.guard_stats.spear_reach += 25.0
		"spear_dmg":
			game.guard_stats.spear_damage = 46.0 * (1.0 + 0.2 * new_level)
		"catapult":
			castle.catapult_level = new_level
		"ballista":
			castle.ballista_level = new_level
		"rapid":
			castle.rapid_level = new_level
		"rapid_dmg":
			castle.rapid_damage = 12.5 * (1.0 + 0.2 * new_level)
		"rapid_rate":
			castle.rapid_interval = maxf(0.03, 0.125 * (1.0 - 0.1 * new_level))
		"rapid_pierce":
			castle.rapid_pierce += 1
		"rapid_multi":
			castle.rapid_shots += 1
		"ballista_dmg":
			castle.ballista_damage = 274.56 * (1.0 + 0.2 * new_level)
		"ballista_rate":
			castle.ballista_interval = maxf(0.5, 4.0 * (1.0 - 0.1 * new_level))
		"ballista_multi":
			castle.ballista_shots += 1
		"artillery":
			castle.cannon_damage = 104.0 * (1.0 + 0.2 * new_level)
		"cannon_rate":
			castle.cannon_interval = maxf(0.5, 4.0 * (1.0 - 0.1 * new_level))
		"cannon_range":
			castle.cannon_radius = 90.0 * (1.0 + 0.2 * new_level)
		"cannon_multi":
			castle.cannon_shots += 1
		"catapult_dmg":
			castle.catapult_damage = 134.4 * (1.0 + 0.2 * new_level)
		"catapult_rate":
			castle.catapult_interval = maxf(1.0, 9.0 * (1.0 - 0.1 * new_level))
		"catapult_range":
			castle.catapult_radius = 150.0 * (1.0 + 0.2 * new_level)
		"catapult_multi":
			castle.catapult_shots += 1
		"heavy":
			game.add_heavy()
		"engineer":
			game.add_engineer()
		"heavy_dmg":
			game.heavy.slash_damage = 31.5 * (1.0 + 0.2 * new_level)
		"heavy_haste":
			game.heavy.slash_interval = maxf(0.2, 1.1 * (1.0 - 0.1 * new_level))
		"heavy_range":
			game.heavy.slash_radius = 105.0 * (1.0 + 0.2 * new_level)
		"heavy_hp":
			game.heavy.max_hp = 270.0 * (1.0 + 0.4 * new_level)
			game.heavy.regen += 3.0
			if not game.heavy.dead:
				game.heavy.hp = game.heavy.max_hp
		"heavy_speed":
			game.heavy.move_speed = 60.0 * (1.0 + 0.2 * new_level)
		"heavy_whirl":
			game.heavy.slash_arc = TAU
		"trap_dmg":
			game.engineer_stats.bomb_damage = 160.0 * (1.0 + 0.2 * new_level)
			game.engineer_stats.pit_damage = 80.0 * (1.0 + 0.2 * new_level)
			game.engineer_stats.power_mult = 1.0 + 0.2 * new_level
		"trap_speed":
			game.engineer_stats.plant_time = maxf(1.0, 6.0 * (1.0 - 0.1 * new_level))
		"engineer_move":
			game.engineer_stats.move_speed = 110.0 * (1.0 + 0.15 * new_level)
		"trap_range":
			game.engineer_stats.bomb_radius = 110.0 * (1.0 + 0.2 * new_level)
			game.engineer_stats.pit_radius = 90.0 * (1.0 + 0.2 * new_level)
		"trap_trigger":
			game.engineer_stats.trigger_radius = 60.0 * (1.0 + 0.15 * new_level)
		"pit_stun":
			game.engineer_stats.stun_time += 1.0
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
			game.heavy.extra_slashes = 1
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
		"sp_homing_arrow":
			castle.homing_arrow = true
		"sp_tower_ap":
			castle.tower_pierce += 3
			castle.tower_damage *= 1.6
		"sp_tower_crit":
			castle.tower_crit = true
			castle.tower_range *= 1.4
		"sp_scatter":
			castle.scatter_level = 2
		"sp_suction":
			castle.suction = true
		"sp_incendiary":
			castle.fire_level = 2
		"sp_rapid_cannon":
			castle.cannon_interval *= 0.6
		"sp_treasure":
			castle.treasure_shoot = true
		"sp_split_rock":
			castle.split_level = 2
		"sp_rock_rain":
			castle.rock_rain = true
		"sp_slow_bolt":
			castle.slow_bolt = true
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
		"sp_shadow_volley":
			st.shadow_volley = true
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
		"sp_provoke_ball":
			game.heavy.provoke_ball = true
		"sp_watchtower":
			game.walls.watchtower = true
		"sp_tower_turret":
			game.walls.tower_turret = true
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
			game.pet_interval = maxf(0.1, 0.8 * (1.0 - 0.1 * new_level))
		"pet_fang":
			_update_pet_damage(game)
		"pet_eye":
			game.pet_range = 280.0 * (1.0 + 0.2 * new_level)
		"pet_multi":
			game.pet_shots += 1
		"sp_pet_charge":
			game.pet_charge = true
		"sp_pet_charge_burst":
			game.pet_charge_burst = true
		"sp_pet_frost":
			game.pet_frost = true
		"sp_pet_heal":
			game.pet_heal = true
		"sp_archer_shadow":
			game.archer_shadow = true
		"sp_archer_rain":
			game.archer_rain = true
		"sp_archer_close":
			game.archer_close = true
		"sp_archer_link":
			game.archer_link = true
		"sp_archer_ult":
			game.archer_ult = true
		"sp_archer_tornado":
			game.archer_tornado = true
		"sp_archer_counter":
			game.archer_counter = true
		"sp_archer_execute":
			game.archer_execute = true
		"sp_archer_giant_tornado":
			game.archer_giant_tornado = true
		"sp_archer_heavy_arrow":
			game.archer_heavy_arrow = true
		"sp_rapid_overheat":
			game.castle.rapid_overheat = true
		"sp_rapid_stun":
			game.castle.rapid_stun = true
		"sp_rapid_sacrifice":
			game.castle.rapid_sacrifice = true
		"sp_rapid_low_hp":
			game.castle.rapid_low_hp = true
		"sp_rapid_swarm":
			game.castle.rapid_swarm = true
		"sp_rapid_hp_scale":
			game.castle.rapid_hp_scale = true
		"sp_rapid_debuff":
			game.castle.rapid_debuff = true
		"sp_rapid_ult":
			game.castle.rapid_ult = true
		"sp_rapid_level":
			game.castle.rapid_level_scale = true
		"sp_rapid_reload":
			game.castle.rapid_reload = true
		"sp_archer_pet_burst":
			game.archer_pet_burst = true
		"sp_archer_pet_giant":
			game.archer_pet_giant = true
		"sp_archer_pet_charge":
			game.archer_pet_charge = true
		"sp_archer_pet_frost":
			game.archer_pet_frost = true
		"sp_archer_pet_heal":
			game.archer_pet_heal = true
		"sp_archer_pet_dance":
			game.archer_pet_dance = true
		"sp_archer_pet_charge_burst":
			game.archer_pet_charge_burst = true
		"sp_archer_pet_flock":
			game.archer_pet_flock = true
		"sp_archer_pet_body":
			game.archer_pet_body = true
		"sp_archer_pet_fusion":
			game.start_archer_pet_fusion()
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
			game.knight_stats.damage = 1.0 * (1.0 + 0.2 * new_level)
		"knight_rate":
			game.knight_stats.interval = maxf(0.3, 1.6 * (1.0 - 0.1 * new_level))
		"knight_width":
			game.knight_stats.hit_width = 1.0 * (1.0 + 0.3 * new_level)
		"knight_move":
			game.knight_stats.move_speed = 190.0 * (1.0 + 0.2 * new_level)
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
		"sp_firework_blast":
			game.sniper_stats.firework_blast = true
		"sp_rage":
			game.heavy.rage_enabled = true
		"sp_counter_wall":
			game.walls.counter = true
		"sp_automaton":
			game.fun.automaton = true
		"sp_tower_blast":
			castle.tower_blast = true
		"sp_homing_blast":
			castle.homing_blast = true
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
		"sp_scarecrow_poison":
			game.engineer_stats.scarecrow_poison = true
		"sp_fun_doves":
			game.fun.doves = true
		"sp_fun_billiard":
			castle.billiard = true
		"sp_billiard_mines":
			castle.billiard_mines = true
		"sp_meteor_rock":
			castle.meteor_rock = true
		"sp_thunder_momentum":
			castle.thunder_momentum = true
		"sp_snowball_snowman":
			castle.snowball_snowman = true
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
		"sp_cavalry_star":
			game.knight_stats.cavalry_star = true
		"sp_repair_orb":
			game.fun.repair_orb = true
		"sp_repair_orb_triple":
			game.fun.repair_orb_triple = true
		# ---- 狙撃部隊
		"sniper":
			game.add_sniper()
		"archer":
			game.add_archer()
		"archer_pet":
			game.add_archer_pet()
			_update_pet_damage(game)
		"archer_pet_rate":
			game.archer_pet_interval = maxf(0.2, 0.75 * (1.0 - 0.1 * new_level))
		"archer_pet_fang":
			_update_pet_damage(game)
		"archer_pet_eye":
			game.archer_pet_range = 85.0 * (1.0 + 0.2 * new_level)
		"archer_pet_multi":
			game.archer_pet_shots += 1
		"archer_rate":
			game.archer_stats.interval = maxf(0.1, 0.8 * (1.0 - 0.1 * new_level))
		"archer_multi":
			game.archer_stats.shots += 1
		"archer_dmg":
			game.archer_stats.damage = 30.0 * (1.0 + 0.2 * new_level)
		"archer_pierce":
			game.archer_stats.pierce += 1
		"archer_size":
			game.archer_stats.arrow_scale = 1.0 + 0.2 * new_level
		"sniper_rate":
			game.sniper_stats.interval = maxf(0.2, 1.6 * (1.0 - 0.1 * new_level))
		"sniper_multi":
			game.sniper_stats.shots += 1
		"sniper_dmg":
			game.sniper_stats.damage = 141.75 * (1.0 + 0.2 * new_level)
		"sniper_pierce":
			game.sniper_stats.pierce += 1
		"sniper_size":
			game.sniper_stats.arrow_scale = 1.0 + 0.2 * new_level
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
		"sp_dome_spikes":
			game.ultimates.dome_spikes = true
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
		"sp_boss_hunt":
			st.boss_hunt = true
		"sp_giant_spear":
			game.guard_stats.giant_spear = true
		"sp_rapid_snipe":
			game.sniper_stats.damage /= 3.0
			game.sniper_stats.interval /= 4.0
		"sp_kill_chain":
			game.knight_stats.kill_chain = true
		"sp_provoke":
			game.heavy_provoke = true
		"sp_spike_wall":
			game.walls.spike = true
		"sp_automaton_squad":
			game.fun.automaton_squad = true
		"sp_overwork":
			castle.overwork = true
			game.repair_stats.heal_per_sec += 20.0
		"sp_pet_fusion":
			game.start_pet_fusion()
		"sp_tower_lock":
			castle.tower_lock = true
		"sp_cannon_bomb":
			castle.cannon_bomb = true
		"sp_iron_chunk":
			castle.iron_chunk = true
		"sp_bolt_momentum":
			castle.bolt_momentum = true
		"sp_ice_statue":
			castle.ice_statue = true
		"sp_castle_fountain":
			castle.regen = 3.0
		"sp_castle_rage":
			castle.rage = true
		"sp_castle_last_stand":
			castle.last_stand = true
		"sp_castle_laser":
			castle.laser = true
		"sp_castle_sneeze":
			castle.sneeze = true
		"sp_castle_store":
			castle.store = true
		"sp_castle_robot":
			castle.robot_enabled = true
		"sp_castle_robot_flight":
			castle.robot_flight = true
		"sp_castle_robot_final":
			castle.robot_final = true
		"sp_castle_robot_true":
			castle.enable_robot_true()
		"tower":
			castle.tower_count = new_level
		"tower_dmg":
			castle.tower_damage = 192.0 * (1.0 + 0.2 * new_level)
		"tower_rate":
			castle.tower_interval = maxf(0.2, 0.9 * (1.0 - 0.1 * new_level))
		"tower_pierce":
			castle.tower_pierce += 1
		"tower_multi":
			castle.tower_shots += 1
		"cannon":
			castle.cannon_level = new_level
		"frost":
			castle.frost_radius = 280.0
			castle.frost_slow = 0.10
		"frost_range":
			castle.frost_radius = 280.0 * (1.0 + 0.15 * new_level)
		"frost_slow":
			castle.frost_slow = minf(0.95, castle.frost_slow + 0.05)
		"mine_site":
			game.add_mine_site()
		"mine_speed":
			# 10秒から1秒ずつ短く（最大レベル5で5秒）
			game.mine_interval = 10.0 - new_level
			for m in game.mine_sites:
				m.interval = game.mine_interval
		"mine_yield":
			game.mine_xp = 1 + new_level
			for m in game.mine_sites:
				m.xp_amount = game.mine_xp
		"sp_mine_second":
			game.add_mine_site()
		"sp_mine_miner":
			game.add_miner()
		"sp_mine_shards":
			game.mine_shards = true
		"sp_mine_mole":
			game.mine_mole = true
		"sp_mine_fast":
			game.mine_fast = true
		"sp_mine_gem":
			game.mine_gem = true
		"sp_mine_heal":
			game.mine_heal = true
		"sp_mine_bomb":
			game.mine_bomb = true
		"sp_mole_bomb":
			game.mole_bomb = true
		"sp_ult_trolley":
			game.ultimates.trolley = true
		"wall":
			castle.max_hp += 100.0
			castle.hp = castle.max_hp
