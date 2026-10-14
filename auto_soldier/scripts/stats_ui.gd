extends CanvasLayer
## 部隊戦績画面。各部隊の個体ごとに、与ダメージ・撃破数・被ダメージを一覧表示する。
## 開いているあいだはゲームを一時停止する。

const CAT_ORDER := ["soldier", "pet", "guard", "sniper", "knight", "heavy", "engineer", "builder", "repair", "castle"]
const CAT_LABEL := {
	"soldier": "遊撃部隊", "pet": "ペット", "guard": "迎撃部隊", "sniper": "狙撃部隊", "knight": "近衛部隊", "heavy": "重装部隊", "repair": "修理部隊",
	"engineer": "工兵部隊", "builder": "築城部隊", "castle": "城"}
const CAT_COLOR := {
	"soldier": Color(0.6, 0.85, 1.0), "pet": Color(0.55, 1.0, 0.75), "guard": Color(0.6, 1.0, 0.65),
	"sniper": Color(0.75, 0.95, 0.45), "knight": Color(1.0, 0.82, 0.4), "repair": Color(0.55, 0.75, 1.0),
	"heavy": Color(0.85, 0.75, 1.0), "engineer": Color(0.8, 0.9, 0.5), "builder": Color(1.0, 0.88, 0.45),
	"castle": Color(1.0, 0.7, 0.45)}
const COL_WIDTHS := [230, 130, 80, 130, 260]

var game: Node2D
var _list: VBoxContainer
var _was_paused := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "部隊戦績"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	box.add_child(title)

	box.add_child(_make_row(["名前", "与ダメージ", "撃破", "被ダメージ", "その他"], Color(0.8, 0.8, 0.8), 16))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(940, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	var close := Button.new()
	close.text = "閉じる（Tab）"
	close.custom_minimum_size = Vector2(220, 44)
	close.add_theme_font_size_override("font_size", 18)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_panel)
	box.add_child(close)


func open_panel() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_rebuild()
	visible = true


func close_panel() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func toggle() -> void:
	if visible:
		close_panel()
	else:
		open_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		if visible:
			close_panel()
		elif not game.level_up_ui.visible and not game.upgrades_ui.visible and not game.auto_pick_ui.visible:
			open_panel()
	elif event.keycode == KEY_ESCAPE and visible:
		get_viewport().set_input_as_handled()
		close_panel()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	for cat in CAT_ORDER:
		var recs: Array = game.records.filter(func(r: Dictionary) -> bool: return r["cat"] == cat)
		if recs.is_empty():
			continue
		var col: Color = CAT_COLOR[cat]
		# 部隊ごとの見出しと合計
		var total_dealt := 0.0
		var total_kills := 0
		var total_taken := 0.0
		for r in recs:
			total_dealt += r["dealt"]
			total_kills += r["kills"]
			total_taken += r["taken"]
		var header := _make_row(["■ " + CAT_LABEL[cat], _fmt(total_dealt), str(total_kills), _fmt(total_taken), "（部隊合計）"], col, 17)
		_list.add_child(header)
		for r in recs:
			_list.add_child(_make_row(["　" + r["name"], _fmt(r["dealt"]), str(r["kills"]), _fmt(r["taken"]), _note(r)], Color(0.92, 0.92, 0.92), 15))
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		_list.add_child(spacer)


## 部隊ごとの追加情報
func _note(r: Dictionary) -> String:
	var parts := PackedStringArray()
	if r["blocked"] > 0.0:
		parts.append("盾で防いだ %s" % _fmt(r["blocked"]))
	if r["walls"] > 0:
		parts.append("建てた壁 %d枚" % r["walls"])
	if r["wall_blocks"] > 0:
		parts.append("壁が防いだ %d発" % r["wall_blocks"])
	if r["traps"] > 0:
		parts.append("仕掛けた罠 %d個" % r["traps"])
	return "  ".join(parts)


func _make_row(texts: Array, col: Color, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	for i in texts.size():
		var l := Label.new()
		l.text = texts[i]
		l.custom_minimum_size = Vector2(COL_WIDTHS[i], 0)
		l.add_theme_font_size_override("font_size", font_size)
		l.add_theme_color_override("font_color", col)
		if i in [1, 2, 3]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if i == 4:
			l.add_theme_font_size_override("font_size", font_size - 2)
		row.add_child(l)
	return row


## 12345 → "12,345"
func _fmt(v: float) -> String:
	var s := str(int(round(v)))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0 and s[i - 1] != "-":
			out = "," + out
	return out
