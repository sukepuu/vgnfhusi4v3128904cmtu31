extends CanvasLayer
## 更新内容の画面（左上の「更新内容」ボタンから開く）。
## 今のバージョンの更新内容を上に、そのあとに前のバージョンの内容を新しい順に出す。
## 出力（書き出し）のたびに、CHANGES の先頭に新しいバージョンの内容を足す。

## [バージョン, [更新内容の行…]]（新しい順）
const CHANGES := [
	["2.2", [
		"「エリート隠密兵」を追加（隠密兵の半分の速さ・3倍のHP）",
		"遊撃の射撃を10に、一斉射撃・剣気・ブーメラン・剣の大嵐の威力を2倍に",
		"ペットの攻撃力を3に、体当たりペット・突撃ペット・鳥の大群の威力を2倍に",
	]],
	["2.1", [
		"合体中の巨大ペットの爆裂ペット弾を80%に",
		"Lv120から経験値が+10%、そこから1Lvごとに+1%",
		"リスタートした回は、歴代記録の同じ1件を上書きするように",
		"大司教を倒すと特別強化がもらえるように",
		"城ロボ起動の出やすさを、城の兵装を全部取って2倍までに",
		"真・ファイナルモード中の城レーザーのダメージを1/4に",
		"「170overtime」を追加：Lv170以降の難易度上昇（HP加速：増え方が+0.2→+0.3〜、1分ごとに敵・ボスHP+1%、ダメージにLvの百の位を加算）",
	]],
	["2.0", [
		"デバッグやロードで区切りのLvから始めても、そのLvのボスなどが出るように修正",
		"ゲームを複数立ち上げても、セーブがそれぞれ別になるように（2つ目からはウインドウ名に番号）",
		"遊撃の射撃ダメージを13に",
		"合体ペットのダメージを1.5倍に",
		"敵のダメージがLvで上がるしくみを削除（ボスの弾・ビームも一定に）",
	]],
	["1.9", [
		"ゲーム中にたまに固まる不具合を修正（オートセーブが終わらなくなることがあった）",
		"ペットの踊りを取っていると、突撃ペットで飛んでいくペットも踊りの見た目に",
	]],
	["1.8", [
		"「爆裂突進ペット」を「爆裂突撃ペット」に改名",
		"突撃ペット・ペットの踊りの威力を2倍に",
		"ペットの通常攻撃をさらに2倍に。爆裂ペット弾の割合は半分に",
		"遊撃の通常攻撃（射撃・剣・突進突き）を2倍に。影分身も2倍、触爆は半分、炸裂弾は70%に",
		"狙撃：跳弾矢と天穿つ一矢を5倍、花火矢を1/3に",
		"重装の一刀両断を10倍に",
		"工兵の高性能火薬を1レベル+40%に",
		"築城の見張り櫓を2倍に",
		"結界の雪だるまを半分に",
	]],
	["1.7", [
		"オート選択設定に「ちょっと優先」を追加（前の最優先・優先は一段下がる）",
		"デバッグ用ボタンの「非表示（M）」ボタンを削除（Mキーで隠す）",
		"レベルが上がるたびにオートセーブ。ゲームオーバー画面に「前回のLvからリスタート」ボタン",
		"突撃ペット：全ペットがいっせいに突進。ペット大合体中も0.5秒おきに1匹ずつ飛び出して突進",
		"影分身の威力を2倍、一斉射撃（影一斉射撃も）を半分の20倍に",
		"近衛の「長駆」を「大槍」（突進の当たる幅+30%）に入れ替え",
		"ゲーム開始時のランダム加入から氷結の結界を外す",
		"ペットの通常攻撃を2倍に",
		"矢倉の爆裂矢・追尾火矢・伝書鳩を2倍に",
		"大砲・投石器・バリスタの威力を全部2倍に（特別強化・必殺も）。牛投げも2倍",
		"火炎くしゃみを1.5倍に",
		"破竹の大矢・破竹の雷槍の伸びを最大+100%に",
	]],
	["1.6", [
		"ボスがHPの減りぐあいで速くなるしくみ：残り25%で最大の速さに（前は10%）",
	]],
	["1.5", [
		"破城の魔王：手下を呼ぶ間隔を8秒に",
		"分裂の魔獣：分かれても弾と体当たりの威力が下がらないように。城を殴るダメージは20に",
		"黒衣の大司教：弾が城に当たったときのダメージを減らさないように",
		"ボスのHPの85%補正を復活",
		"追尾ペット弾・追尾の舞を削除",
		"特別強化「突撃ペット」「爆裂突進ペット」を追加",
		"鉄甲兵部隊：大司教が来る10分・20分…の回は出ないように",
	]],
	["1.4", [
		"強化の出やすさ：0.25だった加入・追加系を0.5に。ランダムで5種類0.75になる仕組みは削除",
		"ゲーム開始時、部隊・城の兵装の中からランダムで1つが最初から加入",
		"遊撃の一斉射撃の威力を2倍（40倍）に",
		"「四影一斉射撃」を「影一斉射撃」に改名。影分身が4体に増える効果は削除",
		"岩のかけら：飛んでいく岩が見えるように。外れても着弾地点に10秒残る",
		"鉄甲兵：Lv100を超えてからの出現を1分ごとに3体に",
		"Lv130からの「10レベルごとにHP+15%」の上乗せを削除",
		"ふつうの敵のHP：伸びの増え方はLv169まで+0.2、Lv170から10レベルごとに+0.1ずつ大きく",
		"ボスのHPを85%にしたのを取り消し",
		"ボスの序盤のHP補正を1.5倍から1.3倍に（Lv40から1.0倍）",
	]],
	["1.3", [
		"更新内容ボタンも、ふだんは隠してMキーで表示するように",
		"被害状況の「直近1分」を「直近30秒」に",
		"ボスのHPを全体に85%に",
		"分裂の魔獣：分かれた体ぜんぶの合計HPを破城の魔王と同じに",
	]],
	["1.2", [
		"ウインドウの名前に「ver」とバージョンを表示",
		"「更新内容」ボタンと、デバッグ用ボタンを隠す「非表示（M）」ボタンを追加",
		"被害状況：最初は全部たたんだ状態に。「直近1分」の被害も見られるように",
		"強化の出やすさ：加入・追加系を0.25に（迎撃部隊も）、修理部隊は1に",
		"ゲーム開始時、出やすさ0.25の強化からランダムで5種類がその試合だけ0.75に",
		"紫ひし形：出てきてから8秒たつと撃ち始める",
		"鉄甲兵：Lv100を超えると、1分ごとに4体出てくる（アナウンスなし）",
		"ふつうの敵のHP：10分からの伸びを+0.2に。Lv130で+0.3、Lv160で+0.4、Lv200で+0.5",
	]],
	["1.1", [
		"歴代記録は今のバージョンの記録だけを表示",
		"ゲームオーバー画面に「被害状況確認」ボタンを追加",
		"ボスと鉄甲兵がほかの敵とぶつからないように（分裂の魔獣どうし・鉄甲兵どうしはぶつかる）",
		"最初の5分は、城と同じくキャラクターの受けるダメージも半分に（設置物は除く）",
		"遊撃兵の影分身の威力を半分に",
		"ふつうの敵のHP：10分からの伸びを+0.25に",
	]],
	["1.0", [
		"最初のバージョン",
	]],
]

var game: Node2D
var _text: RichTextLabel
var _was_paused := false


func _ready() -> void:
	layer = 32
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
	title.text = "更新内容"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	box.add_child(title)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.custom_minimum_size = Vector2(760, 500)
	_text.add_theme_font_size_override("normal_font_size", 17)
	_text.add_theme_font_size_override("bold_font_size", 22)
	box.add_child(_text)

	var close := Button.new()
	close.text = "閉じる（Esc）"
	close.custom_minimum_size = Vector2(240, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 18)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_panel)
	box.add_child(close)


func open_panel() -> void:
	var cur := str(ProjectSettings.get_setting("application/config/version", ""))
	var s := ""
	for entry in CHANGES:
		var now: bool = entry[0] == cur
		s += "[b][color=%s]ver%s%s[/color][/b]\n" % ["#ffe066" if now else "#9fb4d0", entry[0], "（今のバージョン）" if now else ""]
		for line in entry[1]:
			s += "・%s\n" % line
		s += "\n"
	_text.text = s
	_text.scroll_to_line(0)
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true


func close_panel() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_panel()
