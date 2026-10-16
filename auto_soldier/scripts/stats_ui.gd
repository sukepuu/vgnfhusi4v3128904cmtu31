extends CanvasLayer
## 部隊戦績画面。各部隊の個体ごとに、与ダメージ・撃破数・被ダメージ・回復量を一覧表示する。
## 個体の行をクリックすると、その下に特別強化ごとの与ダメージ・回復量の内訳が開く（もう一度クリックで閉じる）。
## 開いているあいだはゲームを一時停止する。

const Upgrades := preload("res://scripts/upgrades.gd")

const CAT_ORDER := ["soldier", "pet", "guard", "sniper", "knight", "heavy", "engineer", "builder", "repair", "castle"]
const CAT_LABEL := {
	"soldier": "遊撃部隊", "pet": "ペット", "guard": "迎撃部隊", "sniper": "狙撃部隊", "knight": "近衛部隊", "heavy": "重装部隊", "repair": "修理部隊",
	"engineer": "工兵部隊", "builder": "築城部隊", "castle": "城"}
const CAT_COLOR := {
	"soldier": Color(0.6, 0.85, 1.0), "pet": Color(0.55, 1.0, 0.75), "guard": Color(0.6, 1.0, 0.65),
	"sniper": Color(0.75, 0.95, 0.45), "knight": Color(1.0, 0.82, 0.4), "repair": Color(0.55, 0.75, 1.0),
	"heavy": Color(0.85, 0.75, 1.0), "engineer": Color(0.8, 0.9, 0.5), "builder": Color(1.0, 0.88, 0.45),
	"castle": Color(1.0, 0.7, 0.45)}
const COL_WIDTHS := [250, 115, 65, 115, 115, 190]

var game: Node2D
var _list: VBoxContainer
var _scroll: ScrollContainer
var _was_paused := false
## 内訳を開いている個体（戦績カードの idx → true）
var _expanded := {}
## 特別強化の id → 名前
var _sp_names := {}


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

	box.add_child(_make_row(["名前", "与ダメージ", "撃破", "被ダメージ", "回復", "その他"], Color(0.8, 0.8, 0.8), 16))

	var hint := Label.new()
	hint.text = "兵士・兵装の行をクリックすると、特別強化ごとのダメージ・回復量が見られます"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	box.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(940, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_scroll = scroll
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	for u in Upgrades.SPECIAL:
		_sp_names[u["id"]] = u["name"]
	# 特別強化ではない内訳の名前
	_sp_names["robot_true_cool"] = "真・ファイナルモード・クールタイムロボ"

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
		var total_healed := 0.0
		for r in recs:
			total_dealt += r["dealt"]
			total_kills += r["kills"]
			total_taken += r["taken"]
			total_healed += r["healed"]
		var header := _make_row(["■ " + CAT_LABEL[cat], _fmt(total_dealt), str(total_kills), _fmt(total_taken), _fmt_heal(total_healed), "（部隊合計）"], col, 17)
		_list.add_child(header)
		for r in recs:
			var open: bool = _expanded.has(r["idx"])
			var row := _make_row([("▼ " if open else "▶ ") + r["name"], _fmt(r["dealt"]), str(r["kills"]), _fmt(r["taken"]), _fmt_heal(r["healed"]), _note(r)], Color(0.92, 0.92, 0.92), 15)
			# 行をクリックで内訳を開く・閉じる
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			row.gui_input.connect(_on_row_input.bind(r["idx"]))
			_list.add_child(row)
			if open:
				_add_breakdown(r)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		_list.add_child(spacer)


func _on_row_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _expanded.has(idx):
			_expanded.erase(idx)
		else:
			_expanded[idx] = true
		# スクロール位置はそのままで作り直す
		var keep := _scroll.scroll_vertical
		_rebuild()
		await get_tree().process_frame
		_scroll.scroll_vertical = keep


## 個体の下に、特別強化ごとの与ダメージの内訳を並べる（多い順。残りは「通常攻撃・その他」）。
## 回復したことがあれば、回復量の内訳も並べる
func _add_breakdown(r: Dictionary) -> void:
	var col := Color(1.0, 0.85, 0.5)
	var total: float = r["dealt"]
	var by: Dictionary = r.get("sp_dealt", {})
	var ids: Array = by.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return by[a] > by[b])
	var sp_sum := 0.0
	for id in ids:
		var v: float = by[id]
		sp_sum += v
		_list.add_child(_make_row(["　　★" + str(_sp_names.get(id, id)), _fmt(v), "", "", "", _pct(v, total)], col, 14))
	if total > 0.0 or ids.is_empty():
		var normal := maxf(0.0, total - sp_sum)
		_list.add_child(_make_row(["　　通常攻撃・その他", _fmt(normal), "", "", "", _pct(normal, total)], Color(0.75, 0.75, 0.75), 14))
	# 回復量の内訳
	var healed: float = r["healed"]
	if healed > 0.0:
		var hcol := Color(0.55, 1.0, 0.6)
		var hby: Dictionary = r.get("sp_healed", {})
		var hids: Array = hby.keys()
		hids.sort_custom(func(a: String, b: String) -> bool: return hby[a] > hby[b])
		var h_sum := 0.0
		for id in hids:
			var v: float = hby[id]
			h_sum += v
			_list.add_child(_make_row(["　　♥" + str(_sp_names.get(id, id)), "", "", "", _fmt(v), _pct(v, healed)], hcol, 14))
		var base := maxf(0.0, healed - h_sum)
		if base >= 0.5:
			_list.add_child(_make_row(["　　♥通常の回復", "", "", "", _fmt(base), _pct(base, healed)], Color(0.7, 0.85, 0.7), 14))
	if ids.is_empty() and healed <= 0.0:
		_list.add_child(_make_row(["　　（特別強化のダメージ・回復はまだありません）", "", "", "", "", ""], Color(0.6, 0.6, 0.6), 13))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_list.add_child(spacer)


## 全体に対する割合の文字（例："（35.2%）"）
func _pct(v: float, total: float) -> String:
	if total <= 0.0:
		return ""
	return "（%.1f%%）" % (v / total * 100.0)


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
	if r["wall_fixed"] > 0:
		parts.append("直した壁 %d回分" % r["wall_fixed"])
	if int(r.get("xp", 0)) > 0:
		parts.append("獲得経験値 %s" % _fmt(r["xp"]))
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
		if i in [1, 2, 3, 4]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if i == 5:
			l.add_theme_font_size_override("font_size", font_size - 2)
		row.add_child(l)
	return row


## 回復量の列（0なら空欄）
func _fmt_heal(v: float) -> String:
	return _fmt(v) if v >= 0.5 else ""


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
