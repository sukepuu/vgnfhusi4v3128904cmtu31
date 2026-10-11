extends RefCounted
## 工兵部隊と罠のステータス（全工兵で共有）。
## 罠は作動するときにこの値を読むので、強化はすでに置いてある罠にも効く。

var move_speed := 110.0
## 罠1個の設置にかかる時間（秒）
var plant_time := 5.0

# --- 罠
var bomb_damage := 200.0
var bomb_radius := 110.0
var pit_damage := 100.0
var pit_radius := 90.0
## 敵がこの距離まで近づいたら作動開始
var trigger_radius := 60.0
## 落とし穴の足止め時間（秒）
var stun_time := 10.0

# --- 特別強化
## 子爆弾（爆弾の爆発後に小爆弾が散る）
var cluster_level := 0
## 毒沼（落とし穴の跡が毒の沼になる）
var poison_level := 0
## 二重設置（1回で爆弾と落とし穴を両方）
var double_plant := false
## 徹甲地雷（真上の敵1体に追加ダメージ）
var ap_mine := false
