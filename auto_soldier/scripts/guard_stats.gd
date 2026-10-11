extends RefCounted
## 迎撃部隊（盾＋槍）全員で共有するステータス

var max_hp := 120.0
var move_speed := 115.0
## 盾で完全に防げる前方の角度（合計）
var shield_arc := deg_to_rad(60.0)
## 槍：リーチは長いが横幅は狭い
var spear_reach := 110.0
var spear_width := 10.0
var spear_damage := 33.0
var spear_interval := 0.9

# --- 特別強化
## 盾撃（盾で防ぐたびに衝撃波）
var bash_level := 0
## 三叉槍（槍が3方向・5方向に出る）
var trident_level := 0
