extends RefCounted
## 迎撃部隊（盾＋槍）全員で共有するステータス

var max_hp := 120.0
var move_speed := 230.0
## 盾で受けられる前方の角度（合計）
var shield_arc := deg_to_rad(60.0)
## 盾で受けたときに通るダメージの割合（大盾で5%ずつ減って、最大レベル4で0% = 完全に防ぐ）
var shield_taken := 0.2
## 槍：リーチは長いが横幅は狭い
var spear_reach := 110.0
var spear_width := 10.0
var spear_damage := 46.0
var spear_interval := 0.9

# --- 特別強化
## 盾撃（盾で防ぐたびに衝撃波）
var bash_level := 0
## 三叉槍（槍が3方向・5方向に出る）
var trident_level := 0
## 挑発（近くの敵が迎撃兵を狙う）
var taunt := false
## 大旋風槍（定期的に周りへ大ダメージ）
var whirl := false
## 拒馬の柵（定期的に前に柵を置く）
var spikes := false
## 黄金の盾（15秒ごとに前へ黄金の盾を飛ばす。当たった敵の弾を消して全方位に撃つ）
var reflect := false
## 捨て身の構え：HPが半分、盾で防いでも半分くらう。そのかわり槍が当たった敵が爆発（槍の3倍）
var berserk := false
## 神槍投擲：8秒ごとに巨大な槍を投げる
var giant_spear := false
