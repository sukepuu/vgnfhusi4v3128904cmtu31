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
var _enemy_label: Label
var _soldier_label: Label
var _game_over: Control
var _boss_bar: ProgressBar
var _boss_label: Label
## 2体目のボス用（Lv130からの2体同時）。1本目のすぐ下に出る
var _boss_bar2: ProgressBar
var _boss_label2: Label
## 3本目（黒衣の大司教とボス2体が同時にいるとき）
var _boss_bar3: ProgressBar
var _boss_label3: Label
## 4本目（ボス3体同時＋黒衣の大司教のとき）
var _boss_bar4: ProgressBar
var _boss_label4: Label
var _banner: Label
var _banner_left := 0.0
var _auto_btn: Button
var _auto_set_btn: Button
var _debug_btn: Button
var _changelog_btn: Button
## デバッグ用：オート選択のボタンを表示しているか（M キーで切り替え。ふだんは隠しておく）
static var debug_auto_visible := false
var _speed_btn: Button
var _notice: Label
var _notice_left := 0.0
var _result_label: Label
## ゲームオーバー画面の「前回のLvからリスタート」（オートセーブがあるときだけ出す）
var _load_btn: Button
## 11Lv前（保持している一番古いセーブ）から再開
var _load_old_btn: Button


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

	# 侵攻中の敵の数（撃破数の下）
	_enemy_label = _make_label(20)
	_enemy_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_enemy_label.offset_left = -260
	_enemy_label.offset_right = -16
	_enemy_label.offset_top = 52
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemy_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	root.add_child(_enemy_label)

	_soldier_label = _make_label(20)
	_soldier_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_soldier_label.offset_left = -220
	_soldier_label.offset_right = -16
	_soldier_label.offset_top = 80
	_soldier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_soldier_label)


	# ボスのHPバー（画面上の中央）
	_boss_bar = _make_bar(Color(0.75, 0.2, 0.85))
	_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.offset_left = -260
	_boss_bar.offset_right = 260
	_boss_bar.offset_top = 66
	_boss_bar.offset_bottom = 82
	_boss_bar.visible = false
	root.add_child(_boss_bar)
	_boss_label = _make_label(16)
	_boss_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_label.offset_left = -260
	_boss_label.offset_right = 260
	_boss_label.offset_top = 64
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.visible = false
	root.add_child(_boss_label)
	_boss_bar2 = _make_bar(Color(0.85, 0.35, 0.2))
	_boss_bar2.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar2.offset_left = -260
	_boss_bar2.offset_right = 260
	_boss_bar2.offset_top = 90
	_boss_bar2.offset_bottom = 106
	_boss_bar2.visible = false
	root.add_child(_boss_bar2)
	_boss_label2 = _make_label(16)
	_boss_label2.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_label2.offset_left = -260
	_boss_label2.offset_right = 260
	_boss_label2.offset_top = 88
	_boss_label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label2.visible = false
	root.add_child(_boss_label2)
	_boss_bar3 = _make_bar(Color(0.55, 0.3, 0.9))
	_boss_bar3.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar3.offset_left = -260
	_boss_bar3.offset_right = 260
	_boss_bar3.offset_top = 114
	_boss_bar3.offset_bottom = 130
	_boss_bar3.visible = false
	root.add_child(_boss_bar3)
	_boss_label3 = _make_label(16)
	_boss_label3.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_label3.offset_left = -260
	_boss_label3.offset_right = 260
	_boss_label3.offset_top = 112
	_boss_label3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label3.visible = false
	root.add_child(_boss_label3)
	_boss_bar4 = _make_bar(Color(0.35, 0.6, 0.9))
	_boss_bar4.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar4.offset_left = -260
	_boss_bar4.offset_right = 260
	_boss_bar4.offset_top = 138
	_boss_bar4.offset_bottom = 154
	_boss_bar4.visible = false
	root.add_child(_boss_bar4)
	_boss_label4 = _make_label(16)
	_boss_label4.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_label4.offset_left = -260
	_boss_label4.offset_right = 260
	_boss_label4.offset_top = 136
	_boss_label4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label4.visible = false
	root.add_child(_boss_label4)

	# 「BOSS出現！」などの大きな表示
	_banner = _make_label(44)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = -160
	_banner.offset_bottom = -100
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	root.add_child(_banner)

	# 部隊戦績ボタン
	var stats_btn := Button.new()
	stats_btn.text = "部隊戦績（Tab）"
	stats_btn.add_theme_font_size_override("font_size", 16)
	# 城のHPバーのすぐ下（左上）
	stats_btn.position = Vector2(16, 84)
	stats_btn.size = Vector2(170, 34)
	stats_btn.focus_mode = Control.FOCUS_NONE
	stats_btn.pressed.connect(func() -> void: game.toggle_stats())
	root.add_child(stats_btn)

	# 強化状態ボタン（部隊戦績ボタンの下）
	var up_btn := Button.new()
	up_btn.text = "強化状態（U）"
	up_btn.add_theme_font_size_override("font_size", 16)
	up_btn.position = Vector2(16, 124)
	up_btn.size = Vector2(170, 34)
	up_btn.focus_mode = Control.FOCUS_NONE
	up_btn.pressed.connect(func() -> void: game.toggle_upgrades())
	root.add_child(up_btn)

	# オート選択ボタン（強化状態ボタンの下）
	_auto_btn = Button.new()
	_auto_btn.add_theme_font_size_override("font_size", 16)
	_auto_btn.position = Vector2(16, 164)
	_auto_btn.size = Vector2(230, 34)
	_auto_btn.focus_mode = Control.FOCUS_NONE
	_auto_btn.pressed.connect(func() -> void: game.set_auto_pick(not game.auto_pick))
	root.add_child(_auto_btn)
	update_auto_button()

	# オート選択設定ボタン（オート選択ボタンの下）
	_auto_set_btn = Button.new()
	_auto_set_btn.text = "オート選択設定"
	_auto_set_btn.add_theme_font_size_override("font_size", 16)
	_auto_set_btn.position = Vector2(16, 204)
	_auto_set_btn.size = Vector2(170, 34)
	_auto_set_btn.focus_mode = Control.FOCUS_NONE
	_auto_set_btn.pressed.connect(func() -> void: game.toggle_auto_pick_settings())
	root.add_child(_auto_set_btn)
	# デバッグ設定ボタン（オート選択設定ボタンの下）
	_debug_btn = Button.new()
	_debug_btn.text = "デバッグ設定"
	_debug_btn.add_theme_font_size_override("font_size", 16)
	_debug_btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_debug_btn.position = Vector2(16, 244)
	_debug_btn.size = Vector2(170, 34)
	_debug_btn.focus_mode = Control.FOCUS_NONE
	_debug_btn.pressed.connect(func() -> void: game.open_debug())
	root.add_child(_debug_btn)
	# 更新内容ボタン（デバッグ設定ボタンの下。ほかのデバッグ用ボタンと一緒に、ふだんは隠して M キーで表示）
	_changelog_btn = Button.new()
	_changelog_btn.text = "更新内容"
	_changelog_btn.add_theme_font_size_override("font_size", 16)
	_changelog_btn.position = Vector2(16, 284)
	_changelog_btn.size = Vector2(170, 34)
	_changelog_btn.focus_mode = Control.FOCUS_NONE
	_changelog_btn.pressed.connect(func() -> void:
		if not game.level_up_ui.visible:
			game.changelog_ui.open_panel())
	root.add_child(_changelog_btn)
	# オート選択まわりとデバッグ設定はデバッグ用。ふだんは隠しておく（M キーで表示）
	set_debug_visible(debug_auto_visible)

	# 速度切り替えボタン（画面右下）
	_speed_btn = Button.new()
	_speed_btn.add_theme_font_size_override("font_size", 18)
	_speed_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_speed_btn.offset_left = -216
	_speed_btn.offset_right = -16
	_speed_btn.offset_top = -56
	_speed_btn.offset_bottom = -16
	_speed_btn.focus_mode = Control.FOCUS_NONE
	_speed_btn.pressed.connect(func() -> void: game.toggle_speed())
	root.add_child(_speed_btn)
	update_speed_button()

	# オート選択で何を選んだかのお知らせ（画面下）
	_notice = _make_label(18)
	_notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice.offset_left = -400
	_notice.offset_right = 400
	_notice.offset_top = -64
	_notice.offset_bottom = -36
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_notice.visible = false
	root.add_child(_notice)

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


func update_auto_button() -> void:
	if game.auto_pick:
		_auto_btn.text = "オート選択：有効中（A）"
		_auto_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		_auto_btn.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.8))
	else:
		_auto_btn.text = "オート選択：無効中（A）"
		_auto_btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		_auto_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))


func update_speed_button() -> void:
	if Engine.time_scale > 1.0:
		_speed_btn.text = "▶▶ 2倍速中（F）"
		_speed_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		_speed_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.6))
	else:
		_speed_btn.text = "▶ 通常速度中（F）"
		_speed_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		_speed_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))


func show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice_left = 2.5


func show_banner(text: String, col: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_banner.visible = true
	_banner_left = 3.0


func _process(delta: float) -> void:
	if _notice_left > 0.0 and not get_tree().paused:
		_notice_left -= delta
		_notice.modulate.a = clampf(_notice_left, 0.0, 1.0)
		if _notice_left <= 0.0:
			_notice.visible = false
	if _banner_left > 0.0 and not get_tree().paused:
		_banner_left -= delta
		_banner.modulate.a = clampf(_banner_left, 0.0, 1.0)
		if _banner_left <= 0.0:
			_banner.visible = false


## ボスのHPゲージ1本ぶん（同じ種類のボスたち。分裂の魔獣は分かれた体ぜんぶの合計）
func _fill_boss_bar(bar: ProgressBar, label: Label, group: Array) -> void:
	var b: Node2D = group[0]
	var total := 0.0
	var total_max := 0.0
	for x in group:
		total += x.hp
		total_max += x.max_hp
	bar.max_value = maxf(total_max, 1.0)
	bar.value = total
	if b.kind == "boss3":
		label.text = "BOSS「%s」（%d体目）  残り%d体  %d / %d" % [b.boss_title, b.boss_rank, group.size(), ceili(total), ceili(total_max)]
	else:
		label.text = "BOSS「%s」（%d体目）  %d / %d" % [b.boss_title, b.boss_rank, ceili(total), ceili(total_max)]


func refresh() -> void:
	var b: Node2D = game.boss
	var has_boss: bool = b != null and is_instance_valid(b) and not b.dead
	var all_bosses: Array = game.alive_bosses() if has_boss else []
	# ボスの種類ごとにまとめる（分裂の魔獣は分かれた体ぜんぶで1つ）。2体同時なら上下2本のゲージに分けて出す
	var kinds: Array = []
	for x in all_bosses:
		if not kinds.has(x.kind):
			kinds.append(x.kind)
	var bars := [[_boss_bar, _boss_label], [_boss_bar2, _boss_label2], [_boss_bar3, _boss_label3], [_boss_bar4, _boss_label4]]
	for i in bars.size():
		var show: bool = i < kinds.size()
		bars[i][0].visible = show
		bars[i][1].visible = show
		if show:
			_fill_boss_bar(bars[i][0], bars[i][1], all_bosses.filter(func(x: Node2D) -> bool: return x.kind == kinds[i]))
	var castle: Node2D = game.castle
	_xp_bar.max_value = game.xp_to_next
	_xp_bar.value = game.xp
	_level_label.text = "Lv %d" % game.level
	_hp_bar.max_value = castle.max_hp
	_hp_bar.value = castle.hp
	_hp_label.text = "城 HP %d / %d" % [ceili(castle.hp), int(castle.max_hp)]
	var lines_r := PackedStringArray()
	if not game.soldiers.is_empty():
		lines_r.append("遊撃 %d / %d" % [_alive(game.soldiers), game.soldiers.size()])
	if not game.guards.is_empty():
		lines_r.append("迎撃 %d / %d" % [_alive(game.guards), game.guards.size()])
	if not game.snipers.is_empty():
		lines_r.append("狙撃 %d人" % game.snipers.size())
	if not game.knights.is_empty():
		lines_r.append("近衛 %d / %d" % [_alive(game.knights), game.knights.size()])
	if not game.repairers.is_empty():
		lines_r.append("修理 %d人（+%d/秒）" % [game.repairers.size(), int(game.repairers.size() * game.repair_stats.heal_per_sec)])
	if game.heavy != null:
		lines_r.append("重装 %s" % ("復活待ち" if game.heavy.dead else "戦闘中"))
	if not game.engineers.is_empty():
		lines_r.append("工兵 %d人 罠 %d個" % [game.engineers.size(), get_tree().get_nodes_in_group("traps").size()])
	if not game.builders.is_empty():
		lines_r.append("壁 %d枚" % game.walls.walls.size())
	_soldier_label.text = "\n".join(lines_r)
	var t := int(game.elapsed)
	_time_label.text = "%02d:%02d" % [t / 60, t % 60]
	_kill_label.text = "撃破 %d" % game.kills
	_enemy_label.text = "侵攻中の敵 %d体" % game.enemies_cache.size()



func _alive(units: Array) -> int:
	var n := 0
	for u in units:
		if not u.dead:
			n += 1
	return n


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

	# ボタンは2列：左は遊び直す（もう一度・リスタート）、右は記録を見る
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	cols.add_child(right)

	var btn := Button.new()
	btn.text = "もう一度（R）"
	btn.custom_minimum_size = Vector2(340, 56)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func() -> void: game.retry())
	left.add_child(btn)

	# 前回のLvからリスタート（もう一度の下）：レベルが上がったときのオートセーブを読み込んで、そこから続ける
	_load_btn = Button.new()
	_load_btn.text = "前回のLvからリスタート"
	_load_btn.custom_minimum_size = Vector2(340, 44)
	_load_btn.add_theme_font_size_override("font_size", 18)
	_load_btn.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	_load_btn.pressed.connect(func() -> void: game.restart_from_autosave())
	left.add_child(_load_btn)

	# 11Lv前（保持している一番古いセーブ）から再開
	_load_old_btn = Button.new()
	_load_old_btn.text = "11Lv前から再開"
	_load_old_btn.custom_minimum_size = Vector2(340, 44)
	_load_old_btn.add_theme_font_size_override("font_size", 18)
	_load_old_btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_load_old_btn.pressed.connect(_on_load_old_pressed)
	left.add_child(_load_old_btn)

	var stats_btn := Button.new()
	stats_btn.text = "部隊戦績を見る"
	stats_btn.custom_minimum_size = Vector2(340, 44)
	stats_btn.add_theme_font_size_override("font_size", 18)
	stats_btn.pressed.connect(func() -> void: game.stats_ui.open_panel())
	right.add_child(stats_btn)

	var sum_btn := Button.new()
	sum_btn.text = "戦績まとめ"
	sum_btn.custom_minimum_size = Vector2(340, 44)
	sum_btn.add_theme_font_size_override("font_size", 18)
	sum_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	sum_btn.pressed.connect(func() -> void: game.summary_ui.open_panel())
	right.add_child(sum_btn)

	var up_btn := Button.new()
	up_btn.text = "強化状態を見る"
	up_btn.custom_minimum_size = Vector2(340, 44)
	up_btn.add_theme_font_size_override("font_size", 18)
	up_btn.pressed.connect(func() -> void: game.upgrades_ui.open_panel())
	right.add_child(up_btn)

	# 歴代記録（強化状態を見るの下）
	var rec_btn := Button.new()
	rec_btn.text = "歴代記録"
	rec_btn.custom_minimum_size = Vector2(340, 44)
	rec_btn.add_theme_font_size_override("font_size", 18)
	rec_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	rec_btn.pressed.connect(func() -> void: game.records_ui.open_panel())
	right.add_child(rec_btn)

	# 被害状況確認（歴代記録の下）
	var dmg_btn := Button.new()
	dmg_btn.text = "被害状況確認"
	dmg_btn.custom_minimum_size = Vector2(340, 44)
	dmg_btn.add_theme_font_size_override("font_size", 18)
	dmg_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	dmg_btn.pressed.connect(func() -> void: game.damage_ui.open_panel())
	right.add_child(dmg_btn)


## デバッグ用ボタン（オート選択・オート選択設定・デバッグ設定・更新内容）の表示・非表示
func set_debug_visible(v: bool) -> void:
	debug_auto_visible = v
	_auto_btn.visible = v
	_auto_set_btn.visible = v
	_debug_btn.visible = v
	_changelog_btn.visible = v


func show_game_over() -> void:
	refresh()
	var t := int(game.elapsed)
	_result_label.text = "城が落とされた…\n\n防衛時間 %02d:%02d\nレベル %d\n撃破数 %d" % [t / 60, t % 60, game.level, game.kills]
	# オートセーブがあれば「前回のLvからリスタート（Lv○・mm:ss）」を出す
	var save: Dictionary = game.AutosaveScript.peek()
	_load_btn.visible = not save.is_empty()
	if not save.is_empty():
		var st := int(save.get("elapsed", 0.0))
		_load_btn.text = "前回のLvからリスタート（Lv%d・%02d:%02d）" % [int(save.get("level", 1)), st / 60, st % 60]
	# 11Lv前（一番古い保持セーブ）があれば出す
	_update_old_load_btn()
	_game_over.visible = true


func _update_old_load_btn() -> void:
	var levels: Array = game.AutosaveScript.list_levels()
	if levels.size() < 2:
		_load_old_btn.visible = false
		return
	var oldest := int(levels[levels.size() - 1])
	var old_save: Dictionary = game.AutosaveScript.peek(oldest)
	if old_save.is_empty():
		_load_old_btn.visible = false
		return
	var st := int(old_save.get("elapsed", 0.0))
	var diff := int(levels[0]) - oldest
	_load_old_btn.text = "%dLv前から再開（Lv%d・%02d:%02d）" % [diff, oldest, st / 60, st % 60]
	_load_old_btn.visible = true


func _on_load_old_pressed() -> void:
	var levels: Array = game.AutosaveScript.list_levels()
	if levels.is_empty():
		return
	var oldest := int(levels[levels.size() - 1])
	game.restart_from_autosave(oldest)


func _unhandled_input(event: InputEvent) -> void:
	if _game_over.visible and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		game.retry()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_A and not _game_over.visible and debug_auto_visible:
		get_viewport().set_input_as_handled()
		game.set_auto_pick(not game.auto_pick)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		# デバッグ用：オート選択のボタンを表示・非表示
		get_viewport().set_input_as_handled()
		set_debug_visible(not debug_auto_visible)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and not _game_over.visible:
		get_viewport().set_input_as_handled()
		game.toggle_speed()
