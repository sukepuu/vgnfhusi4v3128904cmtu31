extends CanvasLayer
## 戦績まとめ画面（ゲームオーバー画面のボタンから開く）。
## 部隊・設備の種類ごとに、配置数・与ダメージの合計と、強化・特別強化を何個取ったかを一覧で出す。
## 中身は snapshot() で辞書にまとめてから表示する（歴代記録にもこの辞書を保存して、あとで同じ表示を出す）。

const Upgrades := preload("res://scripts/upgrades.gd")

## 表示する種類：[表示名, 種類のキー]
const GROUPS := [
	["遊撃", "soldier"], ["ペット", "pet"], ["迎撃", "guard"], ["狙撃", "sniper"], ["近衛", "knight"],
	["重装", "heavy"], ["工兵", "engineer"], ["築城", "builder"], ["修理", "repair"],
	["弓兵", "archer"], ["弓兵ペット", "archer_pet"], ["鼓舞", "drummer"], ["鼓舞ペット", "drum_pet"],
	["矢倉", "tower"], ["大砲", "cannon"], ["投石器", "catapult"], ["バリスタ", "ballista"], ["連射砲", "rapid"],
	["氷結の結界", "frost"], ["採掘場", "mine_site"], ["城（本体）", "castle"]]
## 城の設備の戦績カードは名前で見分ける（「矢倉1」「大砲2」など）
const EQUIP_PREFIX := {"矢倉": "tower", "大砲": "cannon", "投石器": "catapult", "バリスタ": "ballista", "連射砲": "rapid", "採掘場": "mine_site", "氷結の結界": "frost", "城（本体）": "castle"}

var game: Node2D
var _grid: GridContainer
var _header: Label
var _scroll: ScrollContainer
var _close: Button
## 歴代記録から開いたときの「被害状況」ボタン（被害状況が保存された記録だけ）
var _damage_btn: Button
var _rec_damage: Dictionary = {}
## 記録の直近30秒の被害状況（この機能より前の記録なら null）
var _rec_recent = null
var _rec_date := ""
## 採掘場で稼いだ経験値（表の下に出す。採掘場がなかった・古い記録なら出さない）
var _mine_note: Label
## 歴代記録から開いたか（閉じると歴代記録の一覧に戻る）
var _from_record := false


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
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(980, 480)
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 36)
	_grid.add_theme_constant_override("v_separation", 4)
	content.add_child(_grid)

	_mine_note = Label.new()
	_mine_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mine_note.add_theme_font_size_override("font_size", 18)
	_mine_note.add_theme_color_override("font_color", Color(0.6, 1.0, 0.95))
	_mine_note.visible = false
	content.add_child(_mine_note)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(btns)
	_close = Button.new()
	_close.text = "閉じる（Esc）"
	_close.custom_minimum_size = Vector2(260, 44)
	_close.add_theme_font_size_override("font_size", 18)
	_close.pressed.connect(close_panel)
	btns.add_child(_close)
	_damage_btn = Button.new()
	_damage_btn.text = "被害状況"
	_damage_btn.custom_minimum_size = Vector2(200, 44)
	_damage_btn.add_theme_font_size_override("font_size", 18)
	_damage_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	_damage_btn.visible = false
	_damage_btn.pressed.connect(func() -> void: game.damage_ui.open_data(_rec_damage, _rec_date, "戦績まとめに戻る（Esc）", _rec_recent))
	btns.add_child(_damage_btn)


## 今のゲームの戦績まとめを開く
func open_panel() -> void:
	_from_record = false
	_close.text = "閉じる（Esc）"
	_damage_btn.visible = false
	_render(snapshot())
	visible = true


## 歴代記録の戦績まとめを開く（閉じると歴代記録の一覧に戻る）
func open_record(rec: Dictionary) -> void:
	_from_record = true
	_close.text = "歴代記録に戻る（Esc）"
	# 被害状況が保存されている記録（この機能より後の記録）なら「被害状況」ボタンを出す
	var dmg = rec.get("summary", {}).get("damage_taken")
	_rec_damage = dmg if dmg is Dictionary else {}
	var recent = rec.get("summary", {}).get("damage_recent")
	_rec_recent = recent if recent is Dictionary else null
	_rec_date = str(rec.get("date", ""))
	_damage_btn.visible = dmg is Dictionary
	_render(rec.get("summary", {}), str(rec.get("date", "")))
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
	# 合体合体合体ペットは、ペットのダメージに入れる（部隊戦績と同じ）
	if r["cat"] == "triple_pet":
		return "pet"
	if r["cat"] != "castle":
		return r["cat"]
	for prefix in EQUIP_PREFIX:
		if String(r["name"]).begins_with(prefix):
			return EQUIP_PREFIX[prefix]
	return "castle"


## 強化が、どの種類のものか
func _group_of_upgrade(u: Dictionary) -> String:
	# 部隊・兵装の分け方は強化一覧（upgrades.gd の groups_of）と同じ
	return Upgrades.groups_of(u)[0]


## 今のゲームの戦績まとめの中身（そのままJSONに保存できる形）
func snapshot() -> Dictionary:
	# 与ダメージの合計
	var dealt := {}
	var mine_xp := 0
	for r in game.records:
		var g := _group_of_record(r)
		dealt[g] = dealt.get(g, 0.0) + r["dealt"]
		mine_xp += int(r.get("xp", 0))
	# 強化（通常はレベルの合計、特別強化は取った数）
	var normal := {}
	var special := {}
	for u in Upgrades.LIST:
		var lv: int = game.upgrade_levels.get(u["id"], 0)
		if lv > 0:
			var g := _group_of_upgrade(u)
			normal[g] = normal.get(g, 0) + lv
	# 特別強化の数（取った数 / 全部の数）
	var special_total := {}
	for u in Upgrades.SPECIAL:
		var g := _group_of_upgrade(u)
		special_total[g] = special_total.get(g, 0) + 1
		if game.upgrade_levels.get(u["id"], 0) > 0:
			special[g] = special.get(g, 0) + 1
	# 配置数（現在数 / 上限）。ペットは担当キャラ数に応じた最大数
	var placement_counts := {
		"soldier": [game.soldiers.size(), game.MAX_SOLDIERS],
		"pet": [game.pets.size(), game.soldiers.size() * game.MAX_PETS],
		"guard": [game.guards.size(), game.MAX_GUARDS],
		"sniper": [game.snipers.size(), game.MAX_SNIPERS],
		"knight": [game.knights.size(), game.MAX_KNIGHTS],
		"heavy": [game.all_heavies().size(), 2],
		"engineer": [game.engineers.size(), game.MAX_ENGINEERS],
		"builder": [game.builders.size(), game.MAX_BUILDERS],
		"repair": [game.repairers.size(), game.MAX_REPAIRERS],
		"archer": [game.archers.size(), game.MAX_ARCHERS],
		"archer_pet": [game.archer_pets.size(), game.archers.size() * game.MAX_PETS],
		"drummer": [game.drummers.size(), game.MAX_DRUMMERS],
		"drum_pet": [game.drum_pets.size(), game.drummers.size() * game.MAX_PETS],
		"tower": [game.castle.tower_count, 4],
		"cannon": [mini(game.castle.cannon_level, game.castle.MAX_GUNS), game.castle.MAX_GUNS],
		"catapult": [mini(game.castle.catapult_level, game.castle.MAX_GUNS), game.castle.MAX_GUNS],
		"ballista": [mini(game.castle.ballista_level, game.castle.MAX_BALLISTAS), game.castle.MAX_BALLISTAS],
		"rapid": [mini(game.castle.rapid_level, 2), 2],
		"frost": [1 if game.castle.frost_radius > 0.0 else 0, 1],
		"mine_site": [game.mine_sites.size(), 2],
		"castle": [1, 1],
	}
	var rows: Array = []
	for entry in GROUPS:
		var key: String = entry[1]
		var count_text := ""
		if placement_counts.has(key):
			var counts: Array = placement_counts[key]
			count_text = "%d/%d" % [int(counts[0]), int(counts[1])]
		rows.append({"key": key, "name": entry[0], "dealt": float(dealt.get(key, 0.0)),
			"normal": int(normal.get(key, 0)), "special": int(special.get(key, 0)),
			"special_total": int(special_total.get(key, 0)), "placement_count": count_text,
			"used": dealt.get(key, 0.0) > 0.0 or normal.has(key) or special.has(key)})
	return {"level": int(game.level), "elapsed": float(game.elapsed), "kills": int(game.kills), "rows": rows, "mine_xp": mine_xp, "has_mine": not game.mine_sites.is_empty(),
		"damage_taken": game.damage_taken.duplicate(true), "damage_recent": game.recent_damage()}


## 中身を表に出す（date があれば見出しに「○○の記録」と出す）
func _render(snap: Dictionary, date: String = "") -> void:
	var t := int(snap.get("elapsed", 0.0))
	_header.text = "敗北時のレベル  Lv %d　　防衛時間 %s　　撃破数 %d" % [int(snap.get("level", 0)), time_text(t), int(snap.get("kills", 0))]
	if date != "":
		_header.text = "%s の記録\n" % date + _header.text
	# 採掘場で稼いだ経験値（採掘場があったときだけ。前の記録には入っていないので出さない）
	var mxp := int(snap.get("mine_xp", 0))
	_mine_note.visible = snap.has("mine_xp") and (bool(snap.get("has_mine", false)) or mxp > 0)
	_mine_note.text = "採掘場で稼いだ経験値  %s" % _fmt(mxp)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var head_col := Color(0.8, 0.8, 0.8)
	_grid.add_child(_cell("種類", head_col, 18))
	_grid.add_child(_cell("配置数", head_col, 18, true))
	_grid.add_child(_cell("与ダメージ合計", head_col, 18, true))
	_grid.add_child(_cell("強化", head_col, 18, true))
	_grid.add_child(_cell("特別強化", head_col, 18, true))
	for row in snap.get("rows", []):
		var key: String = str(row.get("key", "castle"))
		# 通常強化・特別強化のどちらも取っていない種類は表示しない
		if int(row.get("normal", 0)) <= 0 and int(row.get("special", 0)) <= 0:
			continue
		var used: bool = bool(row.get("used", false))
		var col := Color(1, 1, 1) if used else Color(0.45, 0.45, 0.45)
		var cat_key := key if Upgrades.CAT_COLOR.has(key) else "castle"
		if used:
			col = Upgrades.CAT_COLOR[cat_key]
		_grid.add_child(_cell(str(row.get("name", "")), col))
		# unit_count は以前の記録との互換用
		var placement_count: String = str(row.get("placement_count", row.get("unit_count", "")))
		_grid.add_child(_cell(placement_count if placement_count != "" else "—", col, 18, true))
		_grid.add_child(_cell(_fmt(float(row.get("dealt", 0.0))), col, 18, true))
		_grid.add_child(_cell("%d" % int(row.get("normal", 0)), col, 18, true))
		_grid.add_child(_cell("%d / %d" % [int(row.get("special", 0)), int(row.get("special_total", 0))], col, 18, true))


## 秒 → "mm:ss"（ゲームのほかの表示と同じく、1時間以上も分で数える。例 "75:30"）
static func time_text(t: int) -> String:
	return "%02d:%02d" % [t / 60, t % 60]


func _fmt(v: float) -> String:
	# 3けたごとにカンマ
	var s := str(int(round(v)))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
