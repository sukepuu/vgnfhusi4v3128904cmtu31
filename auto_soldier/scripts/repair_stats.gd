extends RefCounted
## 修理部隊（全員で共有）のステータス

# --- 修理部隊
## 修理兵1人が1秒に回復する城のHP
var heal_per_sec := 3.0
## 壁職人：ついでに壁も直す
var wall_fix := false
## くす玉割り：ときどきくす玉を割って、城と味方を回復
var kusudama := false
## 応急手当：フィールド全体の味方のHPも、城と同じ量だけ回復する
var first_aid := false
## 緊急修理：城のHPが3割より少ないとき、修理の速さが2倍
var emergency := false
## 工具投げ：城のHPが満タンのとき、近くの敵へ工具を投げる
var tool_throw := false
