extends CanvasLayer
## 強化状態の確認画面。取得した強化を部隊・設備ごとに一覧表示する（スクロール可）。
## 項目をクリックすると、右側に詳しい内容を表示する。開いているあいだはゲームを一時停止する。

const Upgrades := preload("res://scripts/upgrades.gd")
const CAT_ORDER := ["soldier", "guard", "heavy", "builder", "engineer", "castle"]

var game: Node2D
var _list: VBoxContainer
var _detail_title: Label
var _detail_body: Label
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
	title.text = "強化状態"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	box.add_child(title)

	var hint := Label.new()
	hint.text = "項目をクリックすると詳しい内容が見られます"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	box.add_child(hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)

	# 左：取得した強化の一覧（スクロール）
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# 右：選んだ強化の詳細
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 470)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.16)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	row.add_child(panel)
	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", 12)
	panel.add_child(dbox)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 24)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dbox.add_child(_detail_title)
	_detail_body = Label.new()
	_detail_body.add_theme_font_size_override("font_size", 17)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.custom_minimum_size = Vector2(420, 0)
	dbox.add_child(_detail_body)

	var close := Button.new()
	close.text = "閉じる（U）"
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
	if event.keycode == KEY_U:
		get_viewport().set_input_as_handled()
		if visible:
			close_panel()
		elif not game.level_up_ui.visible and not game.stats_ui.visible:
			open_panel()
	elif event.keycode == KEY_ESCAPE and visible:
		get_viewport().set_input_as_handled()
		close_panel()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var first: Dictionary = {}
	for cat in CAT_ORDER:
		var owned: Array = []
		for u in Upgrades.LIST + Upgrades.SPECIAL:
			if u["cat"] == cat and game.upgrade_levels.get(u["id"], 0) > 0:
				owned.append(u)
		if owned.is_empty():
			continue
		var col: Color = Upgrades.CAT_COLOR[cat]
		var header := Label.new()
		header.text = "■ " + Upgrades.CAT_LABEL[cat]
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", col)
		_list.add_child(header)
		for u in owned:
			var lv: int = game.upgrade_levels.get(u["id"], 0)
			var btn := Button.new()
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 16)
			btn.add_theme_color_override("font_color", col.lightened(0.2))
			btn.focus_mode = Control.FOCUS_NONE
			if u.get("special", false):
				btn.text = "  ★" + u["name"]
			else:
				btn.text = "  %s  Lv%d" % [u["name"], lv]
			btn.pressed.connect(_show_detail.bind(u))
			_list.add_child(btn)
			if first.is_empty():
				first = u
	if first.is_empty():
		_detail_title.text = "まだ強化を取っていません"
		_detail_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_detail_body.text = "レベルアップすると、ここに取った強化が並びます。"
	else:
		_show_detail(first)


func _show_detail(u: Dictionary) -> void:
	var lv: int = game.upgrade_levels.get(u["id"], 0)
	var col: Color = Upgrades.CAT_COLOR[u["cat"]]
	var special: bool = u.get("special", false)
	_detail_title.text = ("★" if special else "") + u["name"]
	_detail_title.add_theme_color_override("font_color", col)
	var lines := PackedStringArray()
	lines.append("種類：【%s】%s" % [Upgrades.CAT_LABEL[u["cat"]], "　特別強化" if special else ""])
	if special:
		lines.append("状態：取得済み（1回きりの強化）")
	else:
		lines.append("レベル：%d / %d%s" % [lv, u["max"], "（最大）" if lv >= u["max"] else ""])
	lines.append("")
	lines.append("【効果】")
	lines.append(u["desc"])
	if u.has("desc_up"):
		lines.append("")
		lines.append("【2回目以降に取ったときの効果】")
		lines.append(u["desc_up"])
		if lv > 1:
			lines.append("（%d回ぶん重なっています）" % (lv - 1))
	_detail_body.text = "\n".join(lines)
