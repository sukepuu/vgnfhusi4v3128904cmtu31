extends RefCounted
## 近衛部隊（突進する騎士）全員で共有するステータス

var max_hp := 110.0
var move_speed := 190.0
## 突進の基本の威力（実際は「敵の強さの倍率」をかける）。隠密兵だけは威力に関係なく1発で倒す
var damage := 15.0
## 突進の間隔（秒）
var interval := 1.6
## 突進で進む距離
var dash_distance := 260.0

# --- 特別強化
## 連続突撃：突進のあと、続けてもう何回突進できるか
var chain := 0
## 疾風怒濤：突進で敵を倒すたびに、次の敵へ突進し直す（最大5連鎖）
var kill_chain := false
## 突撃の衝撃：突進の終わりに爆発
var quake := false
## 流れ星突撃：突進の跡に星が残って弾ける
var star_trail := false
## 衝撃の槍：突進で貫いた敵を1秒気絶させる
var stun_hit := false
## 勇猛の突撃：突進で敵を1体貫くたびにHPが8回復
var heal_on_hit := false
## とどめの一撃：HPが2割以下の敵（ボス以外）は突進で一撃で倒す
var execute := false
## 連行突撃：突進で当たった敵を、突進が終わるまで一緒に連れていく（ボス以外）
var carry := false
