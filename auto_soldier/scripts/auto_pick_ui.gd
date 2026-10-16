extends CanvasLayer
## オート選択設定の画面。部隊・兵装ごとに「最優先」「優先」「ちょっと優先」のチェックをつけられる。
## オート選択中は、チェックのついた部隊・兵装の強化を先に取る（最優先 → 優先 → ちょっと優先 → それ以外の順。同じならランダム）。
## 設定は game.auto_priority（3=最優先、2=優先、1=ちょっと優先）に入る。開いているあいだはゲームを一時停止する。
## （前の「最優先（2）」「優先（1）」は、そのままの数字で「優先」「ちょっと優先」に一段下がる）

const Upgrades := preload("res://scripts/upgrades.gd")
const CheckStyle := preload("res://scripts/check_style.gd")
const NamedSaves := preload("res://scripts/named_saves.gd")
const SaveSlotsPopup := preload("res://scripts/save_slots_popup.gd")
## 「設定を保存」で名前を付けて保存するファイル（最大20個）。ゲームを起動したときに、最後に保存・読み込みした設定を読み込む
const SAVE_PATH := "user://auto_pick_presets.json"
## 前の1つだけ保存する方式のファイル（あれば「以前の保存」として一覧に引き継ぐ）
const LEGACY_PATH := "user://auto_pick.json"

## 保存した設定を、起動してから一度だけ読み込んだか
static var _loaded := false

var game: Node2D
var _was_paused := false
## 段の [見出し, 色, 優先度]（左から）
const LEVELS := [["最優先", Color(1.0, 0.5, 0.45), 3], ["優先", Color(1.0, 0.82, 0.4), 2], ["ちょっと優先", Color(0.55, 0.85, 1.0), 1]]

## キー → [最優先, 優先, ちょっと優先 のチェックボックス]
var _boxes := {}
var _save_note: Label
var _load_btn: Button


func _ready() -> void:
	layer = 30
	if not _loaded:
		_loaded = true
		_load_saved()
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
	hint.text = "チェックした部隊・兵装の強化を、オート選択中に優先して取ります\n（左から 最優先 → 優先 → ちょっと優先 の順に取る。どれもなければランダム）"
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
			grid.columns = LEVELS.size() + 1
			grid.add_theme_constant_override("h_separation", 14)
			grid.add_theme_constant_override("v_separation", 2)
			cols.add_child(grid)
			for lv in LEVELS:
				grid.add_child(_head(lv[0], lv[1]))
			grid.add_child(_head("", Color.WHITE))
		var entry: Array = Upgrades.GROUPS[i]
		var key: String = entry[1]
		var row_boxes: Array = []
		for lv in LEVELS:
			var c := _check(lv[1])
			c.toggled.connect(_on_toggled.bind(key, int(lv[2])))
			grid.add_child(c)
			row_boxes.append(c)
		var name_label := Label.new()
		name_label.text = entry[0]
		name_label.add_theme_font_size_override("font_size", 20)
		var cat_key := key if Upgrades.CAT_COLOR.has(key) else "castle"
		name_label.add_theme_color_override("font_color", Upgrades.CAT_COLOR[cat_key])
		name_label.custom_minimum_size = Vector2(130, 0)
		grid.add_child(name_label)
		_boxes[key] = row_boxes

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
	var save := Button.new()
	save.text = "設定を保存"
	save.custom_minimum_size = Vector2(160, 44)
	save.add_theme_font_size_override("font_size", 18)
	save.pressed.connect(_save)
	btns.add_child(save)
	_load_btn = Button.new()
	_load_btn.text = "読み込む"
	_load_btn.custom_minimum_size = Vector2(160, 44)
	_load_btn.add_theme_font_size_override("font_size", 18)
	_load_btn.pressed.connect(_load)
	btns.add_child(_load_btn)
	var close := Button.new()
	close.text = "閉じる（Esc）"
	close.custom_minimum_size = Vector2(200, 44)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(close_panel)
	btns.add_child(close)

	_save_note = Label.new()
	_save_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_note.add_theme_font_size_override("font_size", 15)
	_save_note.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	box.add_child(_save_note)


## 「設定を保存」：名前を付けて保存する小窓を出す
func _save() -> void:
	var pop := SaveSlotsPopup.new()
	add_child(pop)
	pop.setup_save(_save_as)


## 今の設定を、名前を付けて保存する（20個あったら古いものから消える。次にゲームを起動したときはこの設定になる）
func _save_as(save_name: String) -> void:
	var res := NamedSaves.save(SAVE_PATH, save_name, game.auto_priority.duplicate(), LEGACY_PATH)
	if not res["ok"]:
		_save_note.text = "保存できませんでした"
		return
	_save_note.text = "「%s」を保存しました（%d個）" % [save_name, game.auto_priority.size()]
	if not res["removed"].is_empty():
		_save_note.text += "　古い「%s」を消しました" % "」「".join(PackedStringArray(res["removed"]))
	_update_load_btn()


## 「読み込む」：保存の一覧の小窓を出す
func _load() -> void:
	var pop := SaveSlotsPopup.new()
	add_child(pop)
	pop.setup_load(SAVE_PATH, LEGACY_PATH, _on_pick, _on_saves_changed)


func _on_pick(entry: Dictionary) -> void:
	_apply(entry.get("data", {}))
	_refresh()
	_save_note.text = "「%s」を読み込みました" % str(entry.get("name", ""))


func _on_saves_changed() -> void:
	_save_note.text = "保存を消しました"
	_update_load_btn()


func _update_load_btn() -> void:
	_load_btn.disabled = NamedSaves.entries(SAVE_PATH, LEGACY_PATH).is_empty()


## 起動したとき：最後に保存・読み込みした設定を読み込む（消されていたら一番新しい保存）
func _load_saved() -> void:
	var e := NamedSaves.latest(SAVE_PATH, LEGACY_PATH)
	if not e.is_empty():
		_apply(e.get("data", {}))


## 保存した設定を game.auto_priority に入れる
func _apply(data) -> void:
	if not data is Dictionary:
		return
	game.auto_priority.clear()
	for k in data:
		var v := int(data[k])
		if v >= 1 and v <= 3:
			game.auto_priority[k] = v


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
	CheckStyle.apply(c)
	c.custom_minimum_size = Vector2(44, 34)
	return c


## チェックを切り替えた。どの段も1つの部隊・兵装につき1つだけ（つけたら、ほかの段ははずす）
func _on_toggled(on: bool, key: String, level: int) -> void:
	if on:
		game.auto_priority[key] = level
		for i in LEVELS.size():
			if int(LEVELS[i][2]) != level:
				_boxes[key][i].set_pressed_no_signal(false)
	elif int(game.auto_priority.get(key, 0)) == level:
		game.auto_priority.erase(key)


func _clear_all() -> void:
	game.auto_priority.clear()
	_refresh()


## 今の設定をチェックボックスに反映する
func _refresh() -> void:
	for key in _boxes:
		var p := int(game.auto_priority.get(key, 0))
		for i in LEVELS.size():
			_boxes[key][i].set_pressed_no_signal(p == int(LEVELS[i][2]))


func open_panel() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh()
	_save_note.text = ""
	_update_load_btn()
	visible = true


func close_panel() -> void:
	if not visible:
		return
	for c in get_children():
		if c is SaveSlotsPopup:
			c.queue_free()
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
