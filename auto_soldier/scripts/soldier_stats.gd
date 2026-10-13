extends RefCounted
## 兵士全員で共有するステータス。
## 強化はここに反映されるので、あとから増員された兵士も同じ強さになる。

var max_hp := 80.0
var move_speed := 165.0

# --- 射撃（点）
var shot_count := 1
var fire_interval := 0.55
var bullet_damage := 10.0
var bullet_speed := 680.0
var bullet_pierce := 0
var fire_range := 460.0

# --- 剣（面）
var sword_damage := 16.0
var sword_radius := 85.0
var sword_arc := deg_to_rad(150.0)
var sword_interval := 0.75

# --- 突進突き（強化で解放）
var dash_level := 0
var dash_interval := 4.0
var dash_damage := 40.0

# --- 特別強化
## 炸裂弾（弾が当たると小爆発）
var burst_level := 0
## 一斉射撃（定期的に全方位へ弾をばらまく）
var volley_level := 0
## 剣気（斬撃と一緒に衝撃波が飛ぶ）
var sword_wave := false
## 影分身（横に分身が現れて一緒に撃つ）
var shadow := false
## ブーメラン（定期的にブーメランを投げる）
var boomerang := false
## 勝利の花火（敵を倒すと、たまに花火が上がる）
var fireworks := false
## 触爆（触れた敵が爆発して、周りに射撃の3倍ダメージ）
var touch_blast := false
