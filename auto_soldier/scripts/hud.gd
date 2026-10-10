extends CanvasLayer
## 画面上の表示（城のHP・経験値・時間・撃破数・兵士数）とゲームオーバー画面

const Upgrades := preload("res://scripts/upgrades.gd")

var game: Node2D

var _xp_bar: ProgressBar
var _hp_bar: ProgressBar
var _level_label: Label
var _hp_label: Label
var _time_label: Label
var _kill_label: Label
var _soldier_label: Label
var _skills_label: Label
var _game_over: Control
var _result_label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 経験値バー（画面上端いっぱい）
	_xp_bar = _make_bar(Color(0.3, 0.7, 1.0))
	_xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_xp_bar.offset_bottom = 14
	root.add_child(_xp_bar)

	_level_label = _make_label(24)
	_level_label.position = Vector2(16, 20)
	root.add_child(_level_label)

	# 城のHPバー
	_hp_bar = _make_bar(Color(1.0, 0.6, 0.2))
	_hp_bar.position = Vector2(16, 56)
	_hp_bar.size = Vector2(300, 20)
	root.add_child(_hp_bar)
	_hp_label = _make_label(14)
	_hp_label.position = Vector2(22, 56)
	root.add_child(_hp_label)

	_time_label = _make_label(28)
	_time_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_time_label.offset_left = -100
	_time_label.offset_right = 100
	_time_label.offset_top = 20
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_time_label)

	_kill_label = _make_label(22)
	_kill_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_kill_label.offset_left = -220
	_kill_label.offset_right = -16
	_kill_label.offset_top = 22
	_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_kill_label)

	_soldier_label = _make_label(20)
	_soldier_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_soldier_label.offset_left = -220
	_soldier_label.offset_right = -16
	_soldier_label.offset_top = 52
	_soldier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_soldier_label)

	_skills_label = _make_label(15)
	_skills_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_skills_label.offset_left = 16
	_skills_label.offset_top = -260
	_skills_label.offset_right = 400
	_skills_label.offset_bottom = -16
	_skills_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(_skills_label)

	_build_game_over()


func _make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func refresh() -> void:
	var castle: Node2D = game.castle
	_xp_bar.max_value = game.xp_to_next
	_xp_bar.value = game.xp
	_level_label.text = "Lv %d" % game.level
	_hp_bar.max_value = castle.max_hp
	_hp_bar.value = castle.hp
	_hp_label.text = "城 HP %d / %d" % [ceili(castle.hp), int(castle.max_hp)]
	var alive := 0
	for s in game.soldiers:
		if not s.dead:
			alive += 1
	_soldier_label.text = "兵士 %d / %d" % [alive, game.soldiers.size()]
	var t := int(game.elapsed)
	_time_label.text = "%02d:%02d" % [t / 60, t % 60]
	_kill_label.text = "撃破 %d" % game.kills
	var lines := PackedStringArray()
	for u in Upgrades.LIST:
		var lv: int = game.upgrade_levels.get(u["id"], 0)
		if lv > 0:
			lines.append("【%s】%s  Lv%d" % [Upgrades.CAT_LABEL[u["cat"]], u["name"], lv])
	_skills_label.text = "\n".join(lines)


# ---------------------------------------------------------------- ゲームオーバー

func _build_game_over() -> void:
	_game_over = Control.new()
	_game_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over.visible = false
	add_child(_game_over)

	var dim := ColorRect.new()
	dim.color = Color(0.1, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := _make_label(56)
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	box.add_child(title)

	_result_label = _make_label(24)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_label)

	var btn := Button.new()
	btn.text = "もう一度（R）"
	btn.custom_minimum_size = Vector2(260, 56)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func() -> void: game.restart())
	box.add_child(btn)


func show_game_over() -> void:
	refresh()
	var t := int(game.elapsed)
	_result_label.text = "城が落とされた…\n\n防衛時間 %02d:%02d\nレベル %d\n撃破数 %d" % [t / 60, t % 60, game.level, game.kills]
	_game_over.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _game_over.visible and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		game.restart()
