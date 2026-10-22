extends RefCounted
## 弓兵部隊全員で共有するステータス

var max_hp := 80.0
## 弓兵の攻撃力。通常の矢は攻撃力の100%。
var attack_power := 90.0
## 矢を放つ間隔（秒）
var interval := 0.8
## 一度に放つ矢の数
var shots := 1
## 射程
var fire_range := 420.0
## 貫通する敵の数
var pierce := 0
var arrow_speed := 900.0
var arrow_scale := 1.0
