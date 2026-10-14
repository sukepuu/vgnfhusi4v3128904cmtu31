extends CanvasLayer
## レベルアップ時の強化3択画面（ゲームは一時停止中）

signal chosen(id: String)
## リロールボタンが押された（候補の引き直しは main.gd がやる）
signal reroll_requested

const Upgrades := preload("res://scripts/upgrades.gd")

var _box: VBoxContainer
var _title: Label
var _ids: Array = []
## 選べない候補（id → true）
var _locked := {}
var _reroll_btn: Button
## この画面でリロールをもう使ったか（1画面につき1回まで）
var _rerolled := false


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

	# リロールボタン（3つ目の選択肢のすぐ下。show_choices で一番下に並べ直す）
	_reroll_btn = Button.new()
	_reroll_btn.add_theme_font_size_override("font_size", 22)
	_reroll_btn.custom_minimum_size = Vector2(300, 50)
	_reroll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_btn.focus_mode = Control.FOCUS_NONE
	_reroll_btn.pressed.connect(_on_reroll)
	_box.add_child(_reroll_btn)


## rerolled = true ならリロール後の表示（リロールボタンは使用済みになる）
func show_choices(choices: Array, levels: Dictionary, player_level: int, special: bool = false, rerolled: bool = false) -> void:
	_rerolled = rerolled
	_reroll_btn.disabled = rerolled
	_reroll_btn.text = "リロール済み" if rerolled else "🎲 リロール（R）"
	if special:
		_title.text = "★ 特別強化 ★  Lv %d" % player_level
		_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.9))
	else:
		_title.text = "LEVEL UP!  Lv %d" % player_level
		_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	for c in _box.get_children():
		if c is Button and c != _reroll_btn:
			c.queue_free()
	_ids.clear()
	_locked.clear()
	for i in choices.size():
		var u: Dictionary = choices[i]
		var cur: int = levels.get(u["id"], 0)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(520, 84)
		btn.add_theme_font_size_override("font_size", 20)
		var lv_text := "NEW!" if cur == 0 else "Lv %d → %d" % [cur, cur + 1]
		if u.get("special", false):
			lv_text = "特別"
		var star := "★" if u.get("special", false) else ""
		btn.text = "[%d] 【%s】%s%s  (%s)\n%s" % [i + 1, Upgrades.CAT_LABEL[u["cat"]], star, u["name"], lv_text, _wrap(Upgrades.describe(u, cur))]
		var col: Color = Upgrades.CAT_COLOR[u["cat"]]
		btn.add_theme_color_override("font_color", col)
		btn.add_theme_color_override("font_hover_color", col.lightened(0.4))
		btn.pressed.connect(_pick.bind(u["id"]))
		# 条件を満たしていない強化は、候補には出るが選べない（灰色）
		if Upgrades.is_locked(u, levels):
			btn.disabled = true
			btn.text += "\n（まだ取得できません）"
			_locked[u["id"]] = true
		_box.add_child(btn)
		_ids.append(u["id"])
	# リロールボタンは選択肢の一番下へ
	_box.move_child(_reroll_btn, -1)
	visible = true



## 説明文が長いときは、だいたい WRAP_CHARS 文字ごとに改行する（「。」「、」の後ろで切れるならそこで切る）
const WRAP_CHARS := 34


func _wrap(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		while line.length() > WRAP_CHARS:
			var cut := WRAP_CHARS
			# 区切りのいい所（句読点の後ろ）を、上限の少し手前から探す
			for i in range(WRAP_CHARS, WRAP_CHARS - 12, -1):
				var ch := line.substr(i - 1, 1)
				if ch == "。" or ch == "、" or ch == "）" or ch == "→":
					cut = i
					break
			# 次の行が「。」「、」などで始まらないように、それも前の行に入れる
			while cut < line.length() and "。、）".contains(line.substr(cut, 1)):
				cut += 1
			out.append(line.substr(0, cut))
			line = line.substr(cut)
		if line != "":
			out.append(line)
	return "\n".join(out)

func _on_reroll() -> void:
	if not visible or _rerolled:
		return
	_rerolled = true
	reroll_requested.emit()


func _pick(id: String) -> void:
	if not visible or _locked.has(id):
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
			KEY_R:
				get_viewport().set_input_as_handled()
				_on_reroll()
				return
		if idx >= 0 and idx < _ids.size():
			get_viewport().set_input_as_handled()
			_pick(_ids[idx])
