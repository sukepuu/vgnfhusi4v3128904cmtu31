extends RefCounted
## 近衛部隊（突進する騎士）全員で共有するステータス

var max_hp := 110.0
var move_speed := 247.0
## 近衛兵の攻撃力（剛突で上がる）。突進はこの攻撃力の100%。
## 隠密兵は威力に関係なく、当たったらダメージなしで倒れる
var attack_power := 100.0
## 突進の間隔（秒）
var interval := 1.0
## 突進で進む距離
var dash_distance := 338.0
## 突進の当たる幅の倍率（大槍で上がる）。近衛兵の体の大きさ＋6px にこれを掛けた幅で当たる
var hit_width := 1.0

# --- 特別強化
## 連続突撃：突進のあと、続けてもう何回突進できるか
var chain := 0
## 疾風怒濤：突進で敵を倒すたびに、次の敵へ突進し直す（最大5連鎖）
var kill_chain := false
## 突撃の衝撃：突進の終わりに爆発
var quake := false
## 流れ星突撃：突進の跡に星が残って弾ける
var star_trail := false
## 流星百騎（百騎突撃の騎士の幻も流れ星を残す）
var cavalry_star := false
## 衝撃の槍：突進で貫いた敵を1秒気絶させる
var stun_hit := false
## 勇猛の突撃：突進で敵を1体貫くたびにHPが8回復
var heal_on_hit := false
## とどめの一撃：HPが2割以下の敵（ボス以外）は突進で一撃で倒し、一撃撃破で10秒間与ダメージ+50%
var execute := false
## 連行突撃：突進で当たった敵を、突進が終わるまで一緒に連れていく（ボス以外）
var carry := false
