extends CanvasLayer
## 戦績まとめ画面（ゲームオーバー画面のボタンから開く）。
## 部隊・設備の種類ごとに、与ダメージの合計と、強化・特別強化を何個取ったかを一覧で出す。

const Upgrades := preload("res://scripts/upgrades.gd")

## 表示する種類：[表示名, 種類のキー]
const GROUPS := [
	["遊撃", "soldier"], ["ペット", "pet"], ["迎撃", "guard"], ["狙撃", "sniper"], ["近衛", "knight"],
	["重装", "heavy"], ["工兵", "engineer"], ["築城", "builder"], ["修理", "repair"],
	["矢倉", "tower"], ["大砲", "cannon"], ["投石器", "catapult"], ["バリスタ", "ballista"],
	["氷結の結界", "frost"], ["城（本体）", "castle"]]
## 城の設備の戦績カードは名前で見分ける（「矢倉1」「大砲2」など）
const EQUIP_PREFIX := {"矢倉": "tower", "大砲": "cannon", "投石器": "catapult", "バリスタ": "ballista", "氷結の結界": "frost", "城（本体）": "castle"}
## 城の通常強化がどの設備のものか（砲術は大砲と投石器の両方に効くが、大砲に数える）
const CASTLE_UPGRADE_GROUP := {"tower": "tower", "cannon": "cannon", "catapult": "catapult", "ballista": "ballista",
	"artillery": "cannon", "frost": "frost", "wall": "castle"}

var game: Node2D
var _grid: GridContainer
var _header: Label


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "戦績まとめ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	box.add_child(title)

	_header = Label.new()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_font_size_override("font_size", 20)
	box.add_child(_header)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 36)
	_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(_grid)

	var close := Button.new()
	close.text = "閉じる（Esc）"
	close.custom_minimum_size = Vector2(220, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(close_panel)
	box.add_child(close)


func open_panel() -> void:
	_rebuild()
	visible = true


func close_panel() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_panel()


func _cell(text: String, col: Color, size: int = 18, right: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if right:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## 戦績カードが、どの種類のものか
func _group_of_record(r: Dictionary) -> String:
	if r["cat"] != "castle":
		return r["cat"]
	for prefix in EQUIP_PREFIX:
		if String(r["name"]).begins_with(prefix):
			return EQUIP_PREFIX[prefix]
	return "castle"


## 強化が、どの種類のものか
func _group_of_upgrade(u: Dictionary) -> String:
	if u["cat"] != "castle":
		return u["cat"]
	if u.get("special", false):
		return u.get("req", "castle")
	return CASTLE_UPGRADE_GROUP.get(u["id"], "castle")


func _rebuild() -> void:
	var t := int(game.elapsed)
	_header.text = "敗北時のレベル  Lv %d　　防衛時間 %02d:%02d　　撃破数 %d" % [game.level, t / 60, t % 60, game.kills]
	for c in _grid.get_children():
		c.queue_free()
	# 与ダメージの合計
	var dealt := {}
	for r in game.records:
		var g := _group_of_record(r)
		dealt[g] = dealt.get(g, 0.0) + r["dealt"]
	# 強化（通常はレベルの合計、特別強化は取った数）
	var normal := {}
	var special := {}
	for u in Upgrades.LIST:
		var lv: int = game.upgrade_levels.get(u["id"], 0)
		if lv > 0:
			var g := _group_of_upgrade(u)
			normal[g] = normal.get(g, 0) + lv
	for u in Upgrades.SPECIAL:
		if game.upgrade_levels.get(u["id"], 0) > 0:
			var g := _group_of_upgrade(u)
			special[g] = special.get(g, 0) + 1

	var head_col := Color(0.8, 0.8, 0.8)
	_grid.add_child(_cell("種類", head_col, 18))
	_grid.add_child(_cell("与ダメージ合計", head_col, 18, true))
	_grid.add_child(_cell("強化", head_col, 18, true))
	_grid.add_child(_cell("特別強化", head_col, 18, true))
	for entry in GROUPS:
		var key: String = entry[1]
		var used: bool = dealt.get(key, 0.0) > 0.0 or normal.has(key) or special.has(key)
		var col := Color(1, 1, 1) if used else Color(0.45, 0.45, 0.45)
		var cat_key := key if Upgrades.CAT_COLOR.has(key) else "castle"
		if used:
			col = Upgrades.CAT_COLOR[cat_key]
		_grid.add_child(_cell(entry[0], col))
		var d: float = dealt.get(key, 0.0)
		_grid.add_child(_cell(_fmt(d), col, 18, true))
		_grid.add_child(_cell("%d" % normal.get(key, 0), col, 18, true))
		# 城（本体）には特別強化がない
		_grid.add_child(_cell("-" if key == "castle" else "%d / 8" % special.get(key, 0), col, 18, true))


func _fmt(v: float) -> String:
	# 3けたごとにカンマ
	var s := str(int(round(v)))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
