extends RefCounted
## 狙撃部隊（弓）全員で共有するステータス

## 矢1本のダメージ
var damage := 67.5
## 矢を放つ間隔（秒）
var interval := 1.6
## 一度に放つ矢の数
var shots := 1
## 射程
var fire_range := 750.0
## 貫通する敵の数
var pierce := 2
var arrow_speed := 1650.0

# --- 特別強化
## 対砲兵狙撃（迫撃砲を最優先で狙い、遠い敵ほどダメージ増加）
var counter_battery := false
## 急所狙い（25%でダメージ4倍）
var headshot := false
## 縫い止め矢（当たった敵を1.5秒動けなくする）
var pin := false
## 跳弾矢（当たると近くの別の敵へ跳ねる回数）
var bounces := 0
## 弱点看破（当たった敵は6秒間、全員からのダメージ +35%）
var mark := false
## 花火矢（4回に1回、矢と一緒に花火も撃ち込む）
var firework_arrow := false
## 爆裂矢（当たった敵が爆発して、周りに矢の3倍ダメージ）
var blast_arrow := false
