extends RefCounted
## 名前を付けた保存（オート選択設定・デバッグ設定メニュー共通）。
## 1つのメニューにつき1ファイルに {"entries": [{name, saved_at, data}, ...], "last": 最後に保存・読み込みした名前} を入れる。
## entries は古い順。MAX 個まであり、それ以上保存しようとすると古いものから自動で消す。
## 同じ名前で保存したら、その保存を上書きする（保存した時刻も新しくなる）。

const MAX := 20
## 前の1つだけ保存する方式のファイルから引き継いだ保存の名前
const LEGACY_NAME := "以前の保存"


## ファイルの中身（なければ、前の方式のファイルを1件として引き継ぐ）
static func _read(path: String, legacy_path: String = "") -> Dictionary:
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.get("entries") is Array:
			var entries: Array = []
			for e in data["entries"]:
				if e is Dictionary and e.has("name"):
					entries.append(e)
			return {"entries": entries, "last": str(data.get("last", ""))}
		return {"entries": [], "last": ""}
	var store := {"entries": [], "last": ""}
	if legacy_path != "" and FileAccess.file_exists(legacy_path):
		var old = JSON.parse_string(FileAccess.get_file_as_string(legacy_path))
		if old is Dictionary:
			var t := int(FileAccess.get_modified_time(legacy_path))
			if t <= 0:
				t = int(Time.get_unix_time_from_system())
			store["entries"].append({"name": LEGACY_NAME, "saved_at": t, "data": old})
			store["last"] = LEGACY_NAME
			_write(path, store)
	return store


static func _write(path: String, store: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(store))
	f.close()
	return true


## 保存の一覧（古い順）
static func entries(path: String, legacy_path: String = "") -> Array:
	return _read(path, legacy_path)["entries"]


## 名前を付けて保存する。{"ok": 保存できたか, "removed": 自動で消した古い保存の名前の配列}
static func save(path: String, name: String, data, legacy_path: String = "") -> Dictionary:
	var store := _read(path, legacy_path)
	var list: Array = store["entries"]
	for i in range(list.size() - 1, -1, -1):
		if str(list[i]["name"]) == name:
			list.remove_at(i)
	var removed: Array = []
	while list.size() >= MAX:
		removed.append(str(list[0]["name"]))
		list.remove_at(0)
	list.append({"name": name, "saved_at": int(Time.get_unix_time_from_system()), "data": data})
	store["last"] = name
	return {"ok": _write(path, store), "removed": removed}


## 名前の保存を消す
static func remove(path: String, name: String, legacy_path: String = "") -> void:
	var store := _read(path, legacy_path)
	var list: Array = store["entries"]
	for i in range(list.size() - 1, -1, -1):
		if str(list[i]["name"]) == name:
			list.remove_at(i)
	if store["last"] == name:
		store["last"] = ""
	_write(path, store)


## 名前の保存（なければ空）。読み込んだら「最後に使った保存」として覚える
static func load_entry(path: String, name: String, legacy_path: String = "") -> Dictionary:
	var store := _read(path, legacy_path)
	for e in store["entries"]:
		if str(e["name"]) == name:
			store["last"] = name
			_write(path, store)
			return e
	return {}


## 最後に保存・読み込みした保存（消されていたら一番新しい保存。何もなければ空）
static func latest(path: String, legacy_path: String = "") -> Dictionary:
	var store := _read(path, legacy_path)
	var list: Array = store["entries"]
	if list.is_empty():
		return {}
	for e in list:
		if str(e["name"]) == store["last"]:
			return e
	return list[list.size() - 1]


## 保存名の初期値（「設定 10/16 01:30」のような形）
static func default_name() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "設定 %02d/%02d %02d:%02d" % [d["month"], d["day"], d["hour"], d["minute"]]


## 保存した時刻（unix時間）を「2026/10/16 01:30」の形に（パソコンの時間帯で）
static func format_time(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%04d/%02d/%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]
