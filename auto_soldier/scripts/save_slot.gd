extends Node
## セーブの枠（スロット）。ゲームを何個も同時に立ち上げても、オートセーブがお互いに上書きしあわないように、
## 立ち上げたゲームごとに別の枠（1, 2, 3…）を使う。オートセーブは user://autosave_<枠>.dat に書く。
##
## ・起動したら、空いている一番小さい番号の枠を取る（user://slots/slot_<枠>/ というフォルダを作れたら自分のもの）。
##   フォルダを作るのは「先に作った方だけが成功する」ので、2つのゲームを同時に立ち上げても同じ枠にはならない
## ・取った枠のフォルダの中の alive.txt に、数秒ごとに「プロセス番号と今の時刻」を書く（生きている印）
## ・ゲームを閉じたら枠のフォルダを消して空ける（セーブのファイルは残す）。次に立ち上げたら、また枠1とそのセーブを使う
## ・強制終了などでフォルダが残っていても、印が STALE_SEC 秒より古ければ（もう動いていないゲームなので）空いている枠とみなす
## ・前の1つだけのオートセーブ（user://autosave.dat）は、枠1のセーブとして引き継ぐ
## このノードは SceneTree の root に置く（ゲームのシーンを作り直しても消えない・一時停止中も動く・オートセーブには入らない）

const DIR := "user://slots"
const MAX_SLOTS := 50
## 生きている印を書く間隔（秒）
const BEAT_SEC := 2.0
## 印がこれより古ければ、空いている枠とみなす（動いているゲームは一時停止中も BEAT_SEC 秒ごとに書くので、こんなに古くならない）
const STALE_SEC := 15.0
const LEGACY_SAVE := "user://autosave.dat"

## 取った枠の番号（0 = まだ取っていない）
static var slot := 0
static var _node: Node = null

## 最後に印を書いた時刻（ミリ秒。倍速でも一時停止中でも、本当の時間で数える）
var _last_beat := 0


## 枠をまだ取っていなければ取って、生きている印を書くノードを root に置く。取った枠の番号を返す
static func ensure(tree: SceneTree) -> int:
	if slot > 0:
		return slot
	slot = _claim()
	_migrate_legacy()
	_node = load("res://scripts/save_slot.gd").new()
	_node.name = "SaveSlot"
	tree.root.add_child.call_deferred(_node)
	return slot


## 今の枠のオートセーブのファイル
static func save_path() -> String:
	return "user://autosave_%d.dat" % maxi(1, slot)


static func _lock_dir(n: int) -> String:
	return "%s/slot_%d" % [DIR, n]


static func _beat_file(n: int) -> String:
	return _lock_dir(n) + "/alive.txt"


static func _claim() -> int:
	DirAccess.make_dir_recursive_absolute(DIR)
	for n in range(1, MAX_SLOTS + 1):
		for attempt in 2:
			if DirAccess.make_dir_absolute(_lock_dir(n)) == OK:
				_write_beat(n)
				return n
			# もうある：生きているゲームの枠か、閉じ方が悪くて残ったものか
			if not _is_stale(n):
				break
			# 古い枠を片付けてから取り直す。名前を変えるのは1つのゲームしか成功しないので、同時に片付けようとしてもぶつからない
			var trash := "%s/old_%d_%d_%d" % [DIR, n, OS.get_process_id(), Time.get_ticks_usec()]
			if DirAccess.rename_absolute(_lock_dir(n), trash) == OK:
				_remove_dir(trash)
	# 全部うまっていたら、最後の枠を使う（印は書かない）
	return MAX_SLOTS


static func _is_stale(n: int) -> bool:
	var path := _beat_file(n)
	var now := Time.get_unix_time_from_system()
	if not FileAccess.file_exists(path):
		# 作った直後で、まだ印を書いていないだけかもしれない。フォルダの時刻で見る
		var t := FileAccess.get_modified_time(_lock_dir(n))
		return t > 0 and now - t > STALE_SEC
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parts := f.get_as_text().strip_edges().split(" ")
	f.close()
	if parts.size() < 2:
		return now - FileAccess.get_modified_time(path) > STALE_SEC
	return now - float(parts[1]) > STALE_SEC


static func _write_beat(n: int) -> void:
	var tmp := _lock_dir(n) + "/alive.tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("%d %d" % [OS.get_process_id(), int(Time.get_unix_time_from_system())])
	f.close()
	DirAccess.rename_absolute(tmp, _beat_file(n))


static func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d != null:
		for file in d.get_files():
			d.remove(file)
	DirAccess.remove_absolute(path)


## 前の1つだけのオートセーブを、枠1のセーブにする（枠1のセーブがまだないときだけ）
static func _migrate_legacy() -> void:
	if FileAccess.file_exists(LEGACY_SAVE) and not FileAccess.file_exists("user://autosave_1.dat"):
		DirAccess.rename_absolute(LEGACY_SAVE, "user://autosave_1.dat")


## ゲームを閉じるとき：枠を空ける（セーブのファイルは残す）
static func release() -> void:
	if slot <= 0 or slot >= MAX_SLOTS:
		return
	_remove_dir(_lock_dir(slot))
	slot = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_beat < int(BEAT_SEC * 1000.0) or slot <= 0 or slot >= MAX_SLOTS:
		return
	_last_beat = now
	if not DirAccess.dir_exists_absolute(_lock_dir(slot)):
		# 印のフォルダが消されていたら作り直す（ほかのゲームに取られていたら、作れないので何もしない）
		if DirAccess.make_dir_absolute(_lock_dir(slot)) != OK:
			return
	elif not _is_mine(slot):
		return
	_write_beat(slot)


## 枠の印が自分のプロセスのものか（印がまだなければ自分のものとみなす）
static func _is_mine(n: int) -> bool:
	var f := FileAccess.open(_beat_file(n), FileAccess.READ)
	if f == null:
		return true
	var parts := f.get_as_text().strip_edges().split(" ")
	f.close()
	return parts.is_empty() or int(parts[0]) == OS.get_process_id()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		release()
