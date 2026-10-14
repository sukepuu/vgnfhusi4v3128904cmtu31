extends CanvasLayer
## オート選択設定の画面。部隊・兵装ごとに「最優先」「優先」のチェックをつけられる。
## オート選択中は、チェックのついた部隊・兵装の強化を先に取る（最優先 → 優先 → それ以外の順。同じならランダム）。
## 設定は game.auto_priority（2=最優先、1=優先）に入る。開いているあいだはゲームを一時停止する。

const Upgrades := preload("res://scripts/upgrades.gd")

var game: Node2D
var _was_paused := false
## キー → [最優先のチェックボックス, 優先のチェックボックス]
var _boxes := {}


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
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var title := Label.new()
	title.text = "オート選択設定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	box.add_child(title)

	var hint := Label.new()
	hint.text = "チェックした部隊・兵装の強化を、オート選択中に優先して取ります\n（左＝最優先、右＝優先。どちらもなければランダム）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	box.add_child(hint)

	# 一覧（2列に分けて並べる）
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	cols.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(cols)
	var half := ceili(Upgrades.GROUPS.size() / 2.0)
	var grid: GridContainer = null
	for i in Upgrades.GROUPS.size():
		if i % half == 0:
			grid = GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 14)
			grid.add_theme_constant_override("v_separation", 2)
			cols.add_child(grid)
			grid.add_child(_head("最優先", Color(1.0, 0.55, 0.45)))
			grid.add_child(_head("優先", Color(0.55, 0.85, 1.0)))
			grid.add_child(_head("", Color.WHITE))
		var entry: Array = Upgrades.GROUPS[i]
		var key: String = entry[1]
		var top := _check(Color(1.0, 0.55, 0.45))
		var pri := _check(Color(0.55, 0.85, 1.0))
		top.toggled.connect(_on_toggled.bind(key, 2))
		pri.toggled.connect(_on_toggled.bind(key, 1))
		grid.add_child(top)
		grid.add_child(pri)
		var name_label := Label.new()
		name_label.text = entry[0]
		name_label.add_theme_font_size_override("font_size", 20)
		var cat_key := key if Upgrades.CAT_COLOR.has(key) else "castle"
		name_label.add_theme_color_override("font_color", Upgrades.CAT_COLOR[cat_key])
		name_label.custom_minimum_size = Vector2(130, 0)
		grid.add_child(name_label)
		_boxes[key] = [top, pri]

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(btns)
	var clear := Button.new()
	clear.text = "全部はずす"
	clear.custom_minimum_size = Vector2(160, 44)
	clear.add_theme_font_size_override("font_size", 18)
	clear.pressed.connect(_clear_all)
	btns.add_child(clear)
	var close := Button.new()
	close.text = "閉じる（Esc）"
	close.custom_minimum_size = Vector2(200, 44)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(close_panel)
	btns.add_child(close)


func _head(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _check(col: Color) -> CheckBox:
	var c := CheckBox.new()
	c.focus_mode = Control.FOCUS_NONE
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_theme_color_override("icon_pressed_color", col)
	c.scale = Vector2(1.3, 1.3)
	c.custom_minimum_size = Vector2(44, 34)
	return c


## チェックを切り替えた。最優先と優先はどちらか一方だけ（片方をつけたら、もう片方ははずす）
func _on_toggled(on: bool, key: String, level: int) -> void:
	if on:
		game.auto_priority[key] = level
		var other: CheckBox = _boxes[key][1 if level == 2 else 0]
		other.set_pressed_no_signal(false)
	elif int(game.auto_priority.get(key, 0)) == level:
		game.auto_priority.erase(key)


func _clear_all() -> void:
	game.auto_priority.clear()
	_refresh()


## 今の設定をチェックボックスに反映する
func _refresh() -> void:
	for key in _boxes:
		var p := int(game.auto_priority.get(key, 0))
		_boxes[key][0].set_pressed_no_signal(p == 2)
		_boxes[key][1].set_pressed_no_signal(p == 1)


func open_panel() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh()
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
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_panel()
