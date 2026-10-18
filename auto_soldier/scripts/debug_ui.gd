extends CanvasLayer
## デバッグ設定メニュー（デバッグ用。M キーで出るボタンから開く）。
## 開くと敵を全部消して一時停止し、今の時間・レベル・取った強化をチェックボックスの一覧で出す。
## 部隊・兵装ごとに折りたたんであり、名前をクリックするとその部隊・兵装にチェックを付けて、下に強化を広げる。
## 「この状態で出撃する」を押すと、チェックした内容でゲームを最初から作り直して始める（main.debug_start）。

const Upgrades := preload("res://scripts/upgrades.gd")
## 「この設定を保存」で名前を付けて保存する場所（ゲームを閉じても残る。最大20個）
const SAVE_PATH := "user://debug_presets.json"
## 前の1つだけ保存する方式のファイル（あれば「以前の保存」として一覧に引き継ぐ）
const LEGACY_PATH := "user://debug_preset.json"
const CheckStyle := preload("res://scripts/check_style.gd")
const NamedSaves := preload("res://scripts/named_saves.gd")
const SaveSlotsPopup := preload("res://scripts/save_slots_popup.gd")

## 部隊・兵装を出す強化（見出しのチェックボックスになる）。遊撃と城（本体）は最初からあるのでなし
const UNIT_IDS := {"soldier": "recruit", "pet": "pet", "guard": "guard", "sniper": "sniper", "knight": "knight", "heavy": "heavy",
	"engineer": "engineer", "builder": "builder", "repair": "repairer", "tower": "tower", "cannon": "cannon",
	"catapult": "catapult", "ballista": "ballista", "frost": "frost", "mine_site": "mine_site",
	"archer": "archer", "archer_pet": "archer_pet", "drummer": "drummer", "drum_pet": "drum_pet", "rapid": "rapid"}

var game: Node2D
var _was_paused := false
var _time_edit: LineEdit
var _level_spin: SpinBox
var _list: VBoxContainer
## 強化のid → [チェックボックス, レベルのSpinBox（上限1ならnull）]
var _rows := {}
## 部隊・兵装のキー → 強化の並び（VBox）
var _bodies := {}
var _arrows := {}
var _save_note: Label
var _desc: Label
var _load_btn: Button


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	# 一番上：この状態で出撃する
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)
	var go := Button.new()
	go.text = "この状態で出撃する"
	go.custom_minimum_size = Vector2(300, 48)
	go.add_theme_font_size_override("font_size", 22)
	go.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(_sortie)
	top.add_child(go)
	var close := Button.new()
	close.text = "閉じる（Esc）"
	close.custom_minimum_size = Vector2(180, 48)
	close.add_theme_font_size_override("font_size", 18)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_panel)
	top.add_child(close)
	var save := Button.new()
	save.text = "この設定を保存"
	save.custom_minimum_size = Vector2(180, 48)
	save.add_theme_font_size_override("font_size", 18)
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(_save)
	top.add_child(save)
	_load_btn = Button.new()
	_load_btn.text = "保存した設定を読み込む"
	_load_btn.custom_minimum_size = Vector2(230, 48)
	_load_btn.add_theme_font_size_override("font_size", 18)
	_load_btn.focus_mode = Control.FOCUS_NONE
	_load_btn.pressed.connect(_load)
	top.add_child(_load_btn)
	var reset := Button.new()
	reset.text = "部隊戦績リセット"
	reset.custom_minimum_size = Vector2(180, 48)
	reset.add_theme_font_size_override("font_size", 18)
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset_records)
	top.add_child(reset)
	var title := Label.new()
	title.text = "デバッグ設定"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	top.add_child(title)

	# 時間とレベル
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	box.add_child(info)
	info.add_child(_label("時間", 20, Color(0.85, 0.85, 0.85)))
	_time_edit = LineEdit.new()
	_time_edit.custom_minimum_size = Vector2(120, 0)
	_time_edit.add_theme_font_size_override("font_size", 20)
	_time_edit.placeholder_text = "60:52"
	info.add_child(_time_edit)
	info.add_child(_label("　レベル", 20, Color(0.85, 0.85, 0.85)))
	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 999
	_level_spin.custom_minimum_size = Vector2(120, 0)
	info.add_child(_level_spin)
	var all_btn := Button.new()
	all_btn.text = "全部チェック"
	all_btn.focus_mode = Control.FOCUS_NONE
	all_btn.pressed.connect(_set_all.bind(true))
	info.add_child(all_btn)
	var none_btn := Button.new()
	none_btn.text = "全部はずす"
	none_btn.focus_mode = Control.FOCUS_NONE
	none_btn.pressed.connect(_set_all.bind(false))
	info.add_child(none_btn)
	_save_note = _label("", 18, Color(0.6, 1.0, 0.6))
	info.add_child(_save_note)

	# 強化の説明欄（一覧の強化の名前を押すと出る）
	var desc_panel := PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(0, 62)
	box.add_child(desc_panel)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 17)
	_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_desc.text = "強化の名前を押すと、ここに説明が出ます"
	desc_panel.add_child(_desc)

	# 部隊・兵装ごとの一覧（スクロール）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_build_list()


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## 強化がどの部隊・兵装の欄に入るか
func _section_of(u: Dictionary) -> String:
	for key in UNIT_IDS:
		if UNIT_IDS[key] == u["id"]:
			return key
	return Upgrades.groups_of(u)[0]


func _build_list() -> void:
	var items := {}
	for u in Upgrades.LIST + Upgrades.SPECIAL:
		var key := _section_of(u)
		if UNIT_IDS.get(key, "") == u["id"]:
			continue
		if not items.has(key):
			items[key] = []
		items[key].append(u)
	for entry in Upgrades.GROUPS:
		var key: String = entry[1]
		var cat_key: String = key if Upgrades.CAT_COLOR.has(key) else "castle"
		var col: Color = Upgrades.CAT_COLOR[cat_key]
		# 見出し：[チェック（部隊・兵装そのもの）] [▶ 名前（クリックで開く）] [レベル]
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		_list.add_child(head)
		var unit_id: String = UNIT_IDS.get(key, "")
		if unit_id != "":
			_add_check(head, _find(unit_id))
		else:
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(34, 0)
			head.add_child(pad)
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", col)
		btn.add_theme_color_override("font_hover_color", col.lightened(0.3))
		btn.custom_minimum_size = Vector2(240, 0)
		btn.pressed.connect(_on_head.bind(key))
		head.add_child(btn)
		_arrows[key] = [btn, entry[0]]
		if unit_id != "":
			_add_spin(head, _find(unit_id))
		# その部隊・兵装の強化をまとめてチェック／はずすボタン
		var ids: Array = []
		if unit_id != "":
			ids.append(unit_id)
		for u in items.get(key, []):
			ids.append(u["id"])
		for pair in [["全取得", true], ["全解除", false]]:
			var gb := Button.new()
			gb.text = pair[0]
			gb.focus_mode = Control.FOCUS_NONE
			gb.add_theme_font_size_override("font_size", 15)
			gb.pressed.connect(_set_ids.bind(ids, pair[1]))
			head.add_child(gb)
		# 中身（ふだんは閉じている）。3列に並べる
		var body := GridContainer.new()
		body.columns = 3
		body.add_theme_constant_override("h_separation", 24)
		body.visible = false
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", 48)
		indent.add_child(body)
		_list.add_child(indent)
		_bodies[key] = body
		for u in items.get(key, []):
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 4)
			cell.custom_minimum_size = Vector2(380, 0)
			body.add_child(cell)
			_add_check(cell, u)
			# 名前を押すと、上の説明欄にその強化の説明が出る
			var name_b := Button.new()
			name_b.flat = true
			name_b.focus_mode = Control.FOCUS_NONE
			name_b.text = ("★" if u.get("special", false) else "") + u["name"]
			name_b.add_theme_font_size_override("font_size", 16)
			var name_col := Color(1.0, 0.85, 0.45) if u.get("special", false) else Color(0.9, 0.9, 0.9)
			name_b.add_theme_color_override("font_color", name_col)
			name_b.add_theme_color_override("font_hover_color", name_col.lightened(0.4))
			name_b.add_theme_color_override("font_pressed_color", name_col)
			name_b.pressed.connect(_show_desc.bind(u))
			cell.add_child(name_b)
			_add_spin(cell, u)
		_update_arrow(key)


func _find(id: String) -> Dictionary:
	for u in Upgrades.LIST + Upgrades.SPECIAL:
		if u["id"] == id:
			return u
	return {}


func _add_check(parent: Control, u: Dictionary) -> void:
	var c := CheckBox.new()
	c.focus_mode = Control.FOCUS_NONE
	CheckStyle.apply(c)
	c.custom_minimum_size = Vector2(34, 28)
	parent.add_child(c)
	_rows[u["id"]] = [c, null]


## 上限が2以上の強化には、取ったレベルを選ぶ欄を付ける
func _add_spin(parent: Control, u: Dictionary) -> void:
	if int(u["max"]) <= 1:
		return
	var s := SpinBox.new()
	s.min_value = 1
	s.max_value = int(u["max"])
	s.prefix = "Lv"
	s.custom_minimum_size = Vector2(90, 0)
	parent.add_child(s)
	_rows[u["id"]][1] = s
	# レベルを変えたら、その強化を取ったことにする
	s.value_changed.connect(func(_v: float) -> void: _rows[u["id"]][0].button_pressed = true)


func _show_desc(u: Dictionary) -> void:
	var text: String = "【%s%s】%s" % ["★" if u.get("special", false) else "", u["name"], u["desc"]]
	if u.has("desc_up"):
		text += "\n（2回目以降：%s）" % u["desc_up"]
	text += "　最大Lv%d" % int(u["max"])
	_desc.text = text


## 見出しをクリック：部隊・兵装にチェックを付けて、中身を開く（開いていたら閉じる）
func _on_head(key: String) -> void:
	var body: Control = _bodies[key]
	body.visible = not body.visible
	if body.visible and UNIT_IDS.has(key):
		_rows[UNIT_IDS[key]][0].button_pressed = true
	_update_arrow(key)


func _update_arrow(key: String) -> void:
	var a: Array = _arrows[key]
	a[0].text = ("▼ " if _bodies[key].visible else "▶ ") + a[1]


func _set_all(on: bool) -> void:
	_set_ids(_rows.keys(), on)


## 指定した強化をまとめてチェックする（レベルは最大に）／はずす
func _set_ids(ids: Array, on: bool) -> void:
	for id in ids:
		if not _rows.has(id):
			continue
		_rows[id][0].button_pressed = on
		if on and _rows[id][1] != null:
			_rows[id][1].set_value_no_signal(_rows[id][1].max_value)


## 今のゲームの状態を一覧に入れる
func _refresh() -> void:
	var t := int(game.elapsed)
	_time_edit.text = "%02d:%02d" % [t / 60, t % 60]
	_level_spin.set_value_no_signal(game.level)
	for id in _rows:
		var lv: int = int(game.upgrade_levels.get(id, 0))
		_rows[id][0].set_pressed_no_signal(lv > 0)
		if _rows[id][1] != null:
			_rows[id][1].set_value_no_signal(lv if lv > 0 else _rows[id][1].max_value)


## "60:52" → 秒（"1:00:52" や、分だけの "60" も読める）
func _parse_time(text: String) -> float:
	var parts := text.strip_edges().split(":")
	var sec := 0.0
	for p in parts:
		sec = sec * 60.0 + float(p.to_int())
	if parts.size() == 1:
		sec *= 60.0
	return maxf(sec, 0.0)


## 今のメニューの内容
func _current() -> Dictionary:
	var levels := {}
	for id in _rows:
		if _rows[id][0].button_pressed:
			levels[id] = int(_rows[id][1].value) if _rows[id][1] != null else 1
	return {"elapsed": _parse_time(_time_edit.text), "level": int(_level_spin.value), "levels": levels}


func _sortie() -> void:
	game.start_debug(_current())


## 「この設定を保存」：名前を付けて保存する小窓を出す
func _save() -> void:
	var pop := SaveSlotsPopup.new()
	add_child(pop)
	pop.setup_save(_save_as)


## 今のメニューの内容を、名前を付けて保存する（20個あったら古いものから消える）
func _save_as(save_name: String) -> void:
	var cfg := _current()
	var t := int(cfg["elapsed"])
	var res := NamedSaves.save(SAVE_PATH, save_name, cfg, LEGACY_PATH)
	if not res["ok"]:
		_save_note.text = "保存できませんでした"
		return
	_save_note.text = "「%s」を保存しました（%02d:%02d・Lv%d・強化%d個）" % [save_name, t / 60, t % 60, cfg["level"], cfg["levels"].size()]
	if not res["removed"].is_empty():
		_save_note.text += "　古い「%s」を消しました" % "」「".join(PackedStringArray(res["removed"]))
	_update_load_btn()


## 「保存した設定を読み込む」：保存の一覧の小窓を出す
func _load() -> void:
	var pop := SaveSlotsPopup.new()
	add_child(pop)
	pop.setup_load(SAVE_PATH, LEGACY_PATH, _apply_saved, _on_saves_changed)


func _on_saves_changed() -> void:
	_save_note.text = "保存を消しました"
	_update_load_btn()


func _update_load_btn() -> void:
	_load_btn.disabled = NamedSaves.entries(SAVE_PATH, LEGACY_PATH).is_empty()


## 選んだ保存をメニューに入れる（出撃はまだしない）
func _apply_saved(entry: Dictionary) -> void:
	var cfg = entry.get("data", {})
	if not cfg is Dictionary:
		return
	var t := int(cfg.get("elapsed", 0.0))
	_time_edit.text = "%02d:%02d" % [t / 60, t % 60]
	_level_spin.set_value_no_signal(int(cfg.get("level", 1)))
	var levels: Dictionary = cfg.get("levels", {})
	for id in _rows:
		var lv := int(levels.get(id, 0))
		_rows[id][0].set_pressed_no_signal(lv > 0)
		if _rows[id][1] != null:
			_rows[id][1].set_value_no_signal(lv if lv > 0 else _rows[id][1].max_value)
	_save_note.text = "「%s」を読み込みました" % str(entry.get("name", ""))


func open_panel() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh()
	_save_note.text = ""
	_update_load_btn()
	visible = true


## 部隊戦績の数字をすべて0に戻す（ゲームはそのまま続く）
func _reset_records() -> void:
	game.reset_records()
	_save_note.text = "部隊戦績をリセットしました"


func close_panel() -> void:
	if not visible:
		return
	_close_popups()
	visible = false
	get_tree().paused = _was_paused


## 開いている保存・読み込みの小窓を消す
func _close_popups() -> void:
	for c in get_children():
		if c is SaveSlotsPopup:
			c.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_panel()
