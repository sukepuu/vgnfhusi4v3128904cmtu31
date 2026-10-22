extends CanvasLayer
## 被害結果確認の画面（ゲームオーバー画面の「被害結果確認」ボタン、歴代記録の戦績まとめの「被害状況」ボタンから開く）。
## キャラクター・城・設置物ごとに、受けたダメージの合計と、どの敵からどれだけ受けたか（多い順・割合つき）を出す。
## 上の「全体」「直近30秒」ボタンで、ゲーム全体と、直近30秒（ゲーム内の30秒）を切り替える（最初は全体）。
## どの行も最初はたたんであり、行をクリックすると内訳が開く（もう一度クリックで閉じる）。設置物は「■ 設置物」の下にまとめる。
## 中身は game.damage_taken（main.gd の note_taken() で記録）と同じ形の辞書。

const StatsScript := preload("res://scripts/stats_ui.gd")

## [キー, 表示名, 設置物か]
const VICTIMS := [
	["soldier", "遊撃部隊", false], ["guard", "迎撃部隊", false], ["knight", "近衛部隊", false],
	["heavy", "重装部隊", false], ["castle", "城", false],
	["wall", "壁", true], ["watchtower", "見張り櫓", true], ["scarecrow", "かかし", true], ["ice_statue", "氷像", true]]
const PLACED_COLOR := Color(0.85, 0.75, 0.55)
const COL_WIDTHS := [320, 160, 120]

var game: Node2D
var _list: VBoxContainer
var _scroll: ScrollContainer
var _title: Label
var _close: Button
var _data: Dictionary = {}
## 全体・直近30秒の中身（直近30秒が無い古い記録なら null）
var _all: Dictionary = {}
var _recent = null
## 今どちらを見ているか（"all" / "recent"）
var _tab := "all"
var _tab_all: Button
var _tab_recent: Button
## 開いている行（タブ → {キー → true}）
var _expanded_by := {"all": {}, "recent": {}}
var _expanded: Dictionary = _expanded_by["all"]


func _ready() -> void:
	# 戦績まとめ（31）より上に出す
	layer = 32
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
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	box.add_child(_title)

	# 全体 ／ 直近30秒 の切り替え
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(tabs)
	_tab_all = _tab_button("全体", "all")
	tabs.add_child(_tab_all)
	_tab_recent = _tab_button("直近30秒", "recent")
	tabs.add_child(_tab_recent)

	var hint := Label.new()
	hint.text = "どの敵からどれだけダメージを受けたか（盾などで防いだぶんは入らない。壁・氷像は削られた耐久）\n行をクリックすると、どの敵からかの内訳が開きます"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	box.add_child(hint)

	box.add_child(_make_row(["受けた側 ／ 攻撃した敵", "ダメージ", "割合"], Color(0.8, 0.8, 0.8), 16))

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(660, 480)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)

	_close = Button.new()
	_close.custom_minimum_size = Vector2(240, 44)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.add_theme_font_size_override("font_size", 18)
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(close_panel)
	box.add_child(_close)


func _tab_button(text: String, tab: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(160, 40)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_set_tab.bind(tab))
	return b


## 今のゲームの被害状況を開く
func open_panel() -> void:
	open_data(game.damage_taken, "", "閉じる（Esc）", game.recent_damage())


## 被害状況の辞書を開く（歴代記録から開くときは date に日付、閉じるボタンは「戦績まとめに戻る」）。
## recent = 直近30秒の辞書（null なら「直近30秒」ボタンを出さない）
func open_data(data: Dictionary, date: String = "", back_text: String = "閉じる（Esc）", recent = null) -> void:
	_all = data
	_recent = recent if recent is Dictionary else null
	_title.text = "被害状況" if date == "" else "被害状況（%s の記録）" % date
	_close.text = back_text
	_tab_recent.visible = _recent != null
	# どの行も最初はたたんでおく
	for k in _expanded_by:
		_expanded_by[k].clear()
	_set_tab("all")
	visible = true


## 全体 ／ 直近30秒 を切り替える
func _set_tab(tab: String) -> void:
	if tab == "recent" and _recent == null:
		tab = "all"
	_tab = tab
	_data = _all if tab == "all" else _recent
	_expanded = _expanded_by[tab]
	_tab_all.button_pressed = tab == "all"
	_tab_recent.button_pressed = tab == "recent"
	_rebuild()
	_scroll.scroll_vertical = 0


func close_panel() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_panel()


func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var any := false
	var placed_head := false
	# 表に無いキー（あとで増えた設置物など）も最後に出す
	var order: Array = VICTIMS.duplicate()
	var known := {}
	for v in VICTIMS:
		known[v[0]] = true
	for k in _data:
		if not known.has(k):
			order.append([k, str(k), true])
	for v in order:
		var key: String = v[0]
		var d = _data.get(key)
		if not d is Dictionary or float(d.get("total", 0.0)) <= 0.0:
			continue
		if v[2] and not placed_head:
			placed_head = true
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 8)
			_list.add_child(sp)
			_list.add_child(_make_row(["■ 設置物", "", ""], PLACED_COLOR, 17))
		any = true
		var col: Color = PLACED_COLOR if v[2] else StatsScript.CAT_COLOR.get(key, Color(0.92, 0.92, 0.92))
		var total := float(d["total"])
		var open: bool = _expanded.has(key)
		var row := _make_row([("▼ " if open else "▶ ") + v[1], _fmt(total), ""], col, 17)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(_on_row_input.bind(key))
		_list.add_child(row)
		if open:
			var by: Dictionary = d.get("by", {})
			var names: Array = by.keys()
			names.sort_custom(func(a, b) -> bool: return float(by[a]) > float(by[b]))
			for n in names:
				var amt := float(by[n])
				_list.add_child(_make_row(["　　" + str(n), _fmt(amt), _pct(amt, total)], Color(0.85, 0.85, 0.85), 15))
			var sp2 := Control.new()
			sp2.custom_minimum_size = Vector2(0, 4)
			_list.add_child(sp2)
	if not any:
		var l := Label.new()
		l.text = "ダメージを受けた記録はありません" if _tab == "all" else "直近30秒はダメージを受けていません"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(640, 0)
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_list.add_child(l)


## 行をクリック：内訳を開く・閉じる（スクロール位置はそのまま）
func _on_row_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _expanded.has(key):
			_expanded.erase(key)
		else:
			_expanded[key] = true
		var keep := _scroll.scroll_vertical
		_rebuild()
		await get_tree().process_frame
		_scroll.scroll_vertical = keep


func _make_row(texts: Array, col: Color, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	for i in texts.size():
		var l := Label.new()
		l.text = texts[i]
		l.custom_minimum_size = Vector2(COL_WIDTHS[i], 0)
		l.add_theme_font_size_override("font_size", font_size)
		l.add_theme_color_override("font_color", col)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i > 0:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
	return row


## 全体に対する割合の文字（例："（35.2%）"）
func _pct(v: float, total: float) -> String:
	if total <= 0.0:
		return ""
	return "（%.1f%%）" % (v / total * 100.0)


## 12345 → "12,345"（1未満の端数は四捨五入）
func _fmt(v: float) -> String:
	var s := str(int(round(v)))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
