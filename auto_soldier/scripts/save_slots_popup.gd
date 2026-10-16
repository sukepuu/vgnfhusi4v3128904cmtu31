extends Control
## 名前を付けて保存／保存した設定を読み込む ための小窓（オート選択設定・デバッグ設定メニュー共通）。
## メニューの CanvasLayer の一番上に足して使う。後ろは暗くしてクリックできないようにする。閉じると自分を消す。
## 保存：名前の欄（初期値は「設定 月/日 時:分」）＋「保存」「キャンセル」。Enter でも保存。
## 読み込み：保存の一覧（新しい順に縦に並ぶ）。名前を押すと読み込んで閉じる。右端のゴミ箱ボタンで消す。

const NamedSaves := preload("res://scripts/named_saves.gd")

var _box: VBoxContainer
var _edit: LineEdit
var _list: VBoxContainer
var _path := ""
var _legacy := ""
## 読み込み：on_pick(保存) / on_change()（消したとき）。保存：on_save(名前)
var _on_pick: Callable
var _on_change: Callable
var _on_save: Callable

static var _trash_tex: ImageTexture


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14)
	sb.border_color = Color(1.0, 0.9, 0.4, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	panel.add_child(_box)


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_box.add_child(l)


func _button(text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	return b


## 名前を付けて保存の小窓にする。on_save(名前) は「保存」を押したときに呼ぶ
func setup_save(on_save: Callable) -> void:
	_on_save = on_save
	_title("名前を付けて保存")
	var hint := Label.new()
	hint.text = "保存できるのは%d個まで（いっぱいなら古いものから消えます）\n同じ名前なら上書きします" % NamedSaves.MAX
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_box.add_child(hint)
	_edit = LineEdit.new()
	_edit.text = NamedSaves.default_name()
	_edit.max_length = 40
	_edit.custom_minimum_size = Vector2(420, 44)
	_edit.add_theme_font_size_override("font_size", 20)
	_edit.text_submitted.connect(func(_t: String) -> void: _do_save())
	_box.add_child(_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(row)
	var ok := _button("保存", 160)
	ok.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	ok.pressed.connect(_do_save)
	row.add_child(ok)
	var cancel := _button("キャンセル", 160)
	cancel.pressed.connect(queue_free)
	row.add_child(cancel)
	# 開いたらすぐ名前を打てるように（全部選んだ状態）
	_edit.call_deferred("grab_focus")
	_edit.call_deferred("select_all")


func _do_save() -> void:
	var n := _edit.text.strip_edges()
	if n == "":
		n = NamedSaves.default_name()
	_on_save.call(n)
	queue_free()


## 保存した設定を読み込む小窓にする。on_pick(保存) は名前を押したとき、on_change() は消したときに呼ぶ
func setup_load(path: String, legacy_path: String, on_pick: Callable, on_change: Callable) -> void:
	_path = path
	_legacy = legacy_path
	_on_pick = on_pick
	_on_change = on_change
	_title("保存した設定を読み込む")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var close := _button("閉じる", 160)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	_box.add_child(close)
	_fill_list()


## 一覧を作り直す（新しい順）
func _fill_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var list := NamedSaves.entries(_path, _legacy)
	if list.is_empty():
		var l := Label.new()
		l.text = "保存した設定がありません"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(l)
		return
	for i in range(list.size() - 1, -1, -1):
		var e: Dictionary = list[i]
		var n := str(e["name"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_list.add_child(row)
		var b := Button.new()
		b.text = "%s　　（%s）" % [n, NamedSaves.format_time(int(e.get("saved_at", 0)))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 18)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick.bind(n))
		row.add_child(b)
		var del := Button.new()
		del.icon = _trash_icon()
		del.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		del.tooltip_text = "この保存を消す"
		del.custom_minimum_size = Vector2(48, 44)
		del.focus_mode = Control.FOCUS_NONE
		del.add_theme_color_override("icon_hover_color", Color(1.0, 0.5, 0.45))
		del.add_theme_color_override("icon_pressed_color", Color(1.0, 0.4, 0.35))
		del.pressed.connect(_delete.bind(n))
		row.add_child(del)


func _pick(n: String) -> void:
	var e := NamedSaves.load_entry(_path, n, _legacy)
	if not e.is_empty():
		_on_pick.call(e)
	queue_free()


func _delete(n: String) -> void:
	NamedSaves.remove(_path, n, _legacy)
	_fill_list()
	if _on_change.is_valid():
		_on_change.call()


## ゴミ箱の絵（白。ボタンの色の設定で色が変わる）
static func _trash_icon() -> ImageTexture:
	if _trash_tex != null:
		return _trash_tex
	var s := 24
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var w := Color(0.92, 0.92, 0.95)
	img.fill_rect(Rect2i(9, 2, 6, 2), w)      # 取っ手
	img.fill_rect(Rect2i(3, 4, 18, 3), w)     # ふた
	# 入れ物（下に向かって少し細くなる）
	for y in range(8, 22):
		var inset := 5 + int((y - 8) / 7.0)
		img.fill_rect(Rect2i(inset, y, s - inset * 2, 1), w)
	# 縦の溝
	for x in [8, 11, 14]:
		img.fill_rect(Rect2i(x, 10, 2, 9), Color(0, 0, 0, 0))
	_trash_tex = ImageTexture.create_from_image(img)
	return _trash_tex


## Esc でこの小窓だけ閉じる（後ろのメニューは閉じない）
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()
