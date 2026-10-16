extends RefCounted
## 歴代記録（ゲームオーバーのたびに保存する。ゲームを閉じても残る）。
## 順位は レベルが高い順 → 同じなら防衛時間が長い順 → それも同じなら先に出した記録が上。上位 MAX 件だけ残す。
## 記録にはゲームのバージョン（project.godot の config/version）を付ける。歴代記録には今のバージョンの記録だけを出す
## （ほかのバージョンの記録は消さずに残す。バージョンが付いていない昔の記録は 1.0 として扱う）。上位 MAX 件はバージョンごと
## 1件：{"id", "version", "level", "elapsed", "kills", "date"（yyyy/mm/dd）, "saved_at"（unix時間）, "debug"（デバッグ設定から出撃したか）, "summary"（戦績まとめの中身）,
## "run"（どのゲームの記録か。main.gd の run_id）}
## 「前回のLvからリスタート」したゲームは同じ run なので、ゲームオーバーのとき前の記録を消して新しい結果に置き換える（1ゲーム1件）

const PATH := "user://records.json"
const MAX := 20


## 今のゲームのバージョン
static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "1.0"))


## 記録のバージョン（付いていない昔の記録は 1.0）
static func version_of(r: Dictionary) -> String:
	return str(r.get("version", "1.0"))


## 今のバージョンの記録だけの一覧（順位の順）。歴代記録の画面はこれを出す
static func load_current(path: String = PATH) -> Array:
	var v := current_version()
	return load_all(path).filter(func(r: Dictionary) -> bool: return version_of(r) == v)


## 記録の一覧（全バージョン。順位の順）
static func load_all(path: String = PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Array:
		return []
	var out: Array = []
	for r in data:
		if r is Dictionary:
			out.append(r)
	out.sort_custom(_better)
	return out


## a が b より上の順位か
static func _better(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("level", 0)) != int(b.get("level", 0)):
		return int(a.get("level", 0)) > int(b.get("level", 0))
	if int(a.get("elapsed", 0.0)) != int(b.get("elapsed", 0.0)):
		return float(a.get("elapsed", 0.0)) > float(b.get("elapsed", 0.0))
	return int(a.get("saved_at", 0)) < int(b.get("saved_at", 0))


## 新しいゲームの番号
static func new_run_id() -> String:
	return "run_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 1000000000]


## 記録を足して上位 MAX 件だけ残す。足した記録の id を返す（圏外で残らなければ ""）。
## run を渡すと、同じ run の記録（前のバージョンのものも）を消してから足す（＝最新の結果で上書き。前より悪くても置き換える）
static func add(level: int, elapsed: float, kills: int, summary: Dictionary, debug_run: bool = false, path: String = PATH, run: String = "") -> String:
	var list := load_all(path)
	if run != "":
		list = list.filter(func(r: Dictionary) -> bool: return str(r.get("run", "")) != run)
	var d := Time.get_datetime_dict_from_system()
	var now := int(Time.get_unix_time_from_system())
	var id := "%d_%d" % [now, randi() % 1000000]
	var ver := current_version()
	list.append({"id": id, "version": ver, "level": level, "elapsed": elapsed, "kills": kills,
		"date": "%04d/%02d/%02d" % [d["year"], d["month"], d["day"]], "saved_at": now,
		"debug": debug_run, "summary": summary, "run": run})
	list.sort_custom(_better)
	# 上位 MAX 件だけ残すのは、同じバージョンの記録の中で（ほかのバージョンの記録はそのまま）
	var kept: Array = []
	var n := 0
	for r in list:
		if version_of(r) == ver:
			n += 1
			if n > MAX:
				continue
		kept.append(r)
	list = kept
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(list))
	f.close()
	for r in list:
		if r["id"] == id:
			return id
	return ""
