extends CanvasLayer
## レベルアップ時の強化3択画面（ゲームは一時停止中）

signal chosen(id: String)

const Upgrades := preload("res://scripts/upgrades.gd")

var _box: VBoxContainer
var _title: Label
var _ids: Array = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	center.add_child(_box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_box.add_child(_title)

	var hint := Label.new()
	hint.text = "強化を1つ選んでください（クリック または 1〜3キー）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(hint)


func show_choices(choices: Array, levels: Dictionary, player_level: int, special: bool = false) -> void:
	if special:
		_title.text = "★ 特別強化 ★  Lv %d" % player_level
		_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.9))
	else:
		_title.text = "LEVEL UP!  Lv %d" % player_level
		_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	for c in _box.get_children():
		if c is Button:
			c.queue_free()
	_ids.clear()
	for i in choices.size():
		var u: Dictionary = choices[i]
		var cur: int = levels.get(u["id"], 0)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(520, 84)
		btn.add_theme_font_size_override("font_size", 20)
		var lv_text := "NEW!" if cur == 0 else "Lv %d → %d" % [cur, cur + 1]
		var star := "★" if u.get("special", false) else ""
		btn.text = "[%d] 【%s】%s%s  (%s)\n%s" % [i + 1, Upgrades.CAT_LABEL[u["cat"]], star, u["name"], lv_text, Upgrades.describe(u, cur)]
		var col: Color = Upgrades.CAT_COLOR[u["cat"]]
		btn.add_theme_color_override("font_color", col)
		btn.add_theme_color_override("font_hover_color", col.lightened(0.4))
		btn.pressed.connect(_pick.bind(u["id"]))
		_box.add_child(btn)
		_ids.append(u["id"])
	visible = true


func _pick(id: String) -> void:
	if not visible:
		return
	visible = false
	chosen.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		match event.keycode:
			KEY_1: idx = 0
			KEY_2: idx = 1
			KEY_3: idx = 2
		if idx >= 0 and idx < _ids.size():
			get_viewport().set_input_as_handled()
			_pick(_ids[idx])
