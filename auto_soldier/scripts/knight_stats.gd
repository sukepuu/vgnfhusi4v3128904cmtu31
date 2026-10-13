extends RefCounted
## 近衛部隊（突進する騎士）全員で共有するステータス

var max_hp := 110.0
var move_speed := 190.0
## 突進の基本の威力。実際は「敵の強さの倍率」をかけるので、隠密兵を1発で倒せる威力を保つ
var damage := 22.0
## 突進の間隔（秒）
var interval := 1.6
## 突進で進む距離
var dash_distance := 260.0

# --- 特別強化
## 連続突撃：突進のあと、続けてもう何回突進できるか
var chain := 0
## 突撃の衝撃：突進の終わりに爆発
var quake := false
## 流れ星突撃：突進の跡に星が残って弾ける
var star_trail := false
