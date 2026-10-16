extends CanvasLayer
## 歴代記録の画面（ゲームオーバー画面の「歴代記録」ボタンから開く）。
## TOP20 を順位・レベル・防衛時間・日付で縦に並べる（スクロールできる）。今回の記録は色を変えて「NEW」を付ける。
## 記録を押すと、その時の戦績まとめを出す（戦績まとめを閉じるとこの一覧に戻る）。

const Records := preload("res://scripts/records.gd")
const SummaryScript := preload("res://scripts/summary_ui.gd")

var game: Node2D
var _list: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	layer = 30
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
	title.text = "歴代記録"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	box.add_child(title)

	var hint := Label.new()
	hint.text = "レベルが高い順（同じなら防衛時間が長い順）のTOP%d。記録を押すと戦績まとめが見られます" % Records.MAX
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	box.add_child(hint)

	# 見出し
	box.add_child(_row_labels(["順位", "レベル", "防衛時間", "日付"], Color(0.8, 0.8, 0.8)))

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(700, 480)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

	var close := Button.new()
	close.text = "閉じる（Esc）"
	close.custom_minimum_size = Vector2(220, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 18)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_panel)
	box.add_child(close)


## 順位・レベル・防衛時間・日付を同じ幅で並べた行
func _row_labels(texts: Array, col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	var widths := [110, 150, 170, 250]
	for i in texts.size():
		var l := Label.new()
		l.text = texts[i]
		l.custom_minimum_size = Vector2(widths[i], 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", col)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
	return row


func open_panel() -> void:
	_fill()
	_scroll.scroll_vertical = 0
	visible = true


func close_panel() -> void:
	visible = false


func _fill() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var list := Records.load_current()
	if list.is_empty():
		var l := Label.new()
		l.text = "まだ記録がありません"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		_list.add_child(l)
		return
	var last_id := str(game.last_record_id) if game != null else ""
	for i in list.size():
		var r: Dictionary = list[i]
		var is_new: bool = last_id != "" and str(r.get("id", "")) == last_id
		var b := Button.new()
		b.custom_minimum_size = Vector2(680, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_new:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.35, 0.28, 0.05)
			sb.border_color = Color(1.0, 0.85, 0.3)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(4)
			b.add_theme_stylebox_override("normal", sb)
			var sbh := sb.duplicate()
			sbh.bg_color = Color(0.45, 0.36, 0.08)
			b.add_theme_stylebox_override("hover", sbh)
			b.add_theme_stylebox_override("pressed", sbh)
		var col := Color(1.0, 0.9, 0.4) if is_new else (Color(1.0, 0.8, 0.5) if i < 3 else Color(0.92, 0.92, 0.92))
		var date := str(r.get("date", ""))
		if is_new:
			date += " NEW"
		elif r.get("debug", false):
			date += "（デバッグ）"
		var row := _row_labels(["%d位" % (i + 1), "Lv %d" % int(r.get("level", 0)),
			SummaryScript.time_text(int(r.get("elapsed", 0.0))), date], col)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(row)
		b.pressed.connect(_open.bind(r))
		_list.add_child(b)


## 記録の戦績まとめを出す（戦績まとめのほうが上に出る。閉じるとこの一覧に戻る）
func _open(r: Dictionary) -> void:
	game.summary_ui.open_record(r)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if game != null and game.summary_ui.visible:
			return
		get_viewport().set_input_as_handled()
		close_panel()
