extends RefCounted
## オートセーブ：レベルが上がったときに、今のゲームの状態をまるごと user://autosave_<枠>_lv<レベル>.dat に保存する（枠は立ち上げたゲームごと。save_slot.gd）。
## 直近11レベル分を保持し、それより古いものは自動で削除する。
## ゲームオーバー画面の「前回のLvからリスタート」で読み込んで、保存したところから続きを遊べる。
##
## 保存のしかた：城・壁・必殺技・おもしろ特別強化と main.gd の変数、それから World・Ground・Effects に置かれている
## ノード（兵士・ペット・敵・設置物・罠・採掘場…）の「スクリプトの変数」を全部そのまま書き出す。
## 変数を1つずつ名前で書いているわけではないので、あとで変数や部隊・敵を足しても、たいていは何もしなくても保存される。
## ・ほかのノードへの参照（狙っている敵・持ち主の兵士など）は、保存したノードの番号にして書き、ロードで付け直す
## ・部隊戦績のカード（records の中身・特別強化ごとのカード）は番号で書き、同じカードを指すように戻す
## ・同じ辞書を何体かで共有しているもの（分裂の魔獣の split_pool など）は、ロード後も1つの辞書を共有する
## ・敵のインスタンスID をキーにした辞書（ペットの叩きつけの間隔・快足の鉱夫など）は、ロード後の新しい ID に付け替える
## 保存しないもの：飛んでいる弾・砲弾・投げた物・遅れて起きる爆発・見た目だけの演出（SKIP_SCRIPTS）。ロードすると消えている。
## 乱数の続きも保存しない（ロード後は新しい乱数になる）

## 保存するファイルは、立ち上げたゲームごとの枠のもの（save_slot.gd。user://autosave_<枠>_lv<レベル>.dat）
## 直近 KEEP_LEVELS レベル分を残す（それより古いものは削除）
const KEEP_LEVELS := 11
const SaveSlot := preload("res://scripts/save_slot.gd")
## 保存の形式。形式を変えたら上げる（違う形式のファイルは読まない）
const FORMAT := 1
## 保存しないノード（弾・爆発・演出）。ここにないスクリプトのノードは全部保存する
const SKIP_SCRIPTS := [
	"res://scripts/bullet.gd", "res://scripts/shell.gd", "res://scripts/enemy_shell.gd", "res://scripts/missile.gd",
	"res://scripts/mine_shard.gd", "res://scripts/heavy_slash_wave.gd", "res://scripts/blast.gd",
	"res://scripts/burst_effect.gd", "res://scripts/damage_text.gd", "res://scripts/slash_effect.gd",
	"res://scripts/lightning.gd", "res://scripts/fun_fx.gd",
]
## main.gd の変数のうち保存しないもの（ノードの入れ物・画面・設定・ゲームオーバー・毎フレーム作り直すもの）。
## records は別に書く。_shown_choices は強化の id で別に書く
const MAIN_SKIP := [
	"world", "effects", "camera", "castle", "walls", "ground", "hud", "level_up_ui", "stats_ui", "upgrades_ui",
	"auto_pick_ui", "summary_ui", "records_ui", "damage_ui", "changelog_ui", "debug_ui", "ultimates", "fun",
	"last_record_id", "records", "enemies_cache", "_grid", "game_over", "auto_pick", "_shown_choices",
	"_autosave_queued", "debug_start", "_retry_auto_pick", "auto_priority", "_load_autosave",
]
## ノードそのものの性質で保存するもの
const BUILTIN := ["position", "rotation", "scale", "visible", "modulate", "self_modulate", "z_index", "process_mode"]
## main.gd の子の、いつもあるノード（ロードでは作り直さずに中身だけ戻す）
const FIXED := ["main", "world", "ground", "effects", "castle", "walls", "ultimates", "fun"]
## 中身を戻すいつもあるノード（スクリプトの変数があるもの）
const FIXED_WITH_VARS := ["castle", "walls", "ultimates", "fun"]
## 保存したノードの親
const PARENTS := ["world", "ground", "effects"]
## 辞書のキーとして書けなかった（保存しないノードだった）ときの印
const _DROP := "$drop$"
## 辞書は「for k in d」で回さず、かならず d.keys() と d.values() で回す。
## 倒された敵（消えたノード）がキーに残っている辞書を「for k in d」で回すと、消えたノードのメモリが新しいノードに使い回されていたときに
## Godot の辞書の「次のキー」探しが同じ所をぐるぐる回って終わらなくなる（城レーザーの _laser_hit などで起きて、オートセーブ中にゲームが固まっていた）

var game: Node2D
## 保存：ノード → 番号、インスタンスID → 番号、共有している辞書・オブジェクト
var _ids := {}
var _iids := {}
var _shared_dicts := {}
var _shared_objs := {}
var _next_shared := 0
## ロード：番号 → ノード、共有している辞書・オブジェクト
var _nodes := {}
var _loaded_shared := {}
## スクリプトごとの変数名（毎回 get_property_list しないように覚えておく）
var _names_cache := {}


## 指定レベル（省略時は最新）のオートセーブがあれば {"level", "elapsed", "saved_at", "version", "path"}、なければ空
static func peek(level: int = -1) -> Dictionary:
	var path := _path_for_level(level)
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var head = f.get_var()
	f.close()
	if not (head is Dictionary) or int(head.get("format", -1)) != FORMAT:
		return {}
	head["path"] = path
	return head


## 今の枠で残っているセーブのレベル一覧（新しい順）
static func list_levels() -> Array:
	var dir := DirAccess.open("user://")
	if dir == null:
		return []
	var prefix := "autosave_%d_lv" % maxi(1, SaveSlot.slot)
	var levels: Array = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.begins_with(prefix) and fname.ends_with(".dat"):
			var lv_str := fname.trim_prefix(prefix).trim_suffix(".dat")
			if lv_str.is_valid_int():
				levels.append(int(lv_str))
		fname = dir.get_next()
	dir.list_dir_end()
	levels.sort()
	levels.reverse()
	return levels


static func _path_for_level(level: int = -1) -> String:
	if level < 0:
		var levels := list_levels()
		if levels.is_empty():
			# 旧形式（レベルなし）の互換
			var legacy := SaveSlot.save_path()
			if FileAccess.file_exists(legacy):
				return legacy
			return ""
		level = levels[0]
	return "user://autosave_%d_lv%d.dat" % [maxi(1, SaveSlot.slot), level]


## 今のゲームの状態を保存する。保存できたら true
static func save(g: Node2D) -> bool:
	var s = load("res://scripts/autosave.gd").new()
	s.game = g
	var data: Dictionary = s._capture()
	var head := {"format": FORMAT, "level": g.level, "elapsed": g.elapsed,
		"saved_at": int(Time.get_unix_time_from_system()),
		"version": str(ProjectSettings.get_setting("application/config/version", ""))}
	# 書いている途中で止まっても前の保存が壊れないように、別のファイルに書いてから置き換える
	var path := "user://autosave_%d_lv%d.dat" % [maxi(1, SaveSlot.slot), g.level]
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(head)
	f.store_var(data)
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	if dir.rename(tmp.get_file(), path.get_file()) != OK:
		return false
	# 12以上前（現在レベル - KEEP_LEVELS より古い）を削除
	_prune_old(g.level)
	return true


static func _prune_old(current_level: int) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var prefix := "autosave_%d_lv" % maxi(1, SaveSlot.slot)
	var min_keep := current_level - KEEP_LEVELS + 1
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.begins_with(prefix) and fname.ends_with(".dat"):
			var lv_str := fname.trim_prefix(prefix).trim_suffix(".dat")
			if lv_str.is_valid_int() and int(lv_str) < min_keep:
				dir.remove(fname)
		fname = dir.get_next()
	dir.list_dir_end()


## 保存を読み込んで g（作り直したばかりの main.gd。兵士はまだいない状態）に戻す。
## 読めなかったら空、読めたら {"choices": 出ていた強化の3択の id, "special", "for_level", "rerolled"}
## level を指定するとそのレベルのセーブを読む（省略時は最新）
static func load_into(g: Node2D, level: int = -1) -> Dictionary:
	var path := _path_for_level(level)
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	f.get_var()
	var data = f.get_var()
	f.close()
	if not (data is Dictionary) or not data.has("nodes"):
		return {}
	var s = load("res://scripts/autosave.gd").new()
	s.game = g
	return s._restore(data)


# ---------------------------------------------------------------- 保存

func _fixed_nodes() -> Dictionary:
	return {"main": game, "world": game.world, "ground": game.ground, "effects": game.effects,
		"castle": game.castle, "walls": game.walls, "ultimates": game.ultimates, "fun": game.fun}


## 保存するノードか（弾・演出・消える途中のもの・倒された敵は保存しない）
func _should_save(n: Node) -> bool:
	if n.is_queued_for_deletion() or n.get_script() == null:
		return false
	var path: String = n.get_script().resource_path
	if path in SKIP_SCRIPTS:
		return false
	if path == "res://scripts/enemy.gd" and n.dead:
		return false
	return true


func _capture() -> Dictionary:
	var fixed := _fixed_nodes()
	var next_id := 0
	for key in FIXED:
		_register(fixed[key], next_id)
		next_id += 1
	var list: Array = []
	for parent_key in PARENTS:
		for c in fixed[parent_key].get_children():
			if _ids.has(c) or not _should_save(c):
				continue
			_register(c, next_id)
			list.append([next_id, parent_key, c])
			next_id += 1
	# 書く順番（ロードもこの順で読む）：戦績カード → main → いつもあるノード → 保存したノード
	var out := {}
	var recs: Array = []
	for r in game.records:
		recs.append(_enc_record(r))
	out["records"] = recs
	out["main"] = _props(game, MAIN_SKIP)
	var fixed_out: Array = []
	for key in FIXED_WITH_VARS:
		var n: Node = fixed[key]
		fixed_out.append({"key": key, "props": _props(n, []), "builtin": _builtin(n), "meta": _meta(n)})
	out["fixed"] = fixed_out
	var nodes_out: Array = []
	for item in list:
		var n: Node = item[2]
		nodes_out.append({"id": item[0], "parent": item[1], "script": n.get_script().resource_path,
			"props": _props(n, []), "builtin": _builtin(n), "groups": _groups(n), "meta": _meta(n)})
	out["nodes"] = nodes_out
	# レベルアップの3択が出ている最中なら、その3択（リロールしたかも）を覚える
	var choices: Array = []
	if game.level_up_ui.visible and not game._shown_choices.is_empty():
		for u in game._shown_choices:
			choices.append(str(u["id"]))
	out["levelup"] = {"choices": choices, "special": game._shown_special, "for_level": game._shown_level,
		"rerolled": bool(game.level_up_ui._rerolled)}
	return out


func _register(n: Node, id: int) -> void:
	_ids[n] = id
	_iids[n.get_instance_id()] = id


## スクリプトの変数の名前（保存する対象）
func _var_names(obj: Object) -> Array:
	var sc = obj.get_script()
	if _names_cache.has(sc):
		return _names_cache[sc]
	var names: Array = []
	for p in obj.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(str(p["name"]))
	_names_cache[sc] = names
	return names


## [[変数名, 値], ...]（順番を守るため配列にする）
func _props(obj: Object, skip: Array) -> Array:
	var out: Array = []
	for name in _var_names(obj):
		if name in skip:
			continue
		out.append([name, _enc(obj.get(name))])
	return out


func _builtin(n: Node) -> Array:
	var out: Array = []
	for name in BUILTIN:
		if name in n:
			out.append([name, n.get(name)])
	return out


func _groups(n: Node) -> Array:
	var out: Array = []
	for g in n.get_groups():
		if not str(g).begins_with("_"):
			out.append(str(g))
	return out


func _meta(n: Node) -> Array:
	var out: Array = []
	for k in n.get_meta_list():
		out.append([str(k), _enc(n.get_meta(k))])
	return out


## 部隊戦績のカードそのもの（中の特別強化ごとのカードもそのまま書く）
func _enc_record(r: Dictionary) -> Array:
	var out: Array = []
	for k in r.keys():
		if k == "_sp_src":
			var subs: Array = []
			for sp in r[k].keys():
				subs.append([sp, _enc_plain(r[k][sp])])
			out.append([k, {"$sub": subs}])
		else:
			out.append([k, _enc(r[k])])
	return out


func _enc_plain(d: Dictionary) -> Array:
	var out: Array = []
	for k in d.keys():
		out.append([k, _enc(d[k])])
	return out


func _enc(v):
	match typeof(v):
		TYPE_OBJECT:
			if not is_instance_valid(v):
				return null
			if v is Node:
				return {"$n": _ids[v]} if _ids.has(v) else null
			if v is RefCounted and not (v is Resource) and v.get_script() != null:
				# 強化ステータスなど（同じものを何か所かで持っていても1つにまとめる）
				var oid: int = v.get_instance_id()
				if _shared_objs.has(oid):
					return {"$or": _shared_objs[oid]}
				var sid := _next_shared
				_next_shared += 1
				_shared_objs[oid] = sid
				return {"$o": v.get_script().resource_path, "$id": sid, "p": _props(v, [])}
			return {"$x": true}
		TYPE_DICTIONARY:
			return _enc_dict(v)
		TYPE_ARRAY:
			var a: Array = []
			for x in v:
				a.append(_enc(x))
			return a
		TYPE_INT:
			if _iids.has(v):
				return {"$i": _iids[v]}
			return v
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return {"$x": true}
	return v


func _enc_dict(d: Dictionary):
	var recs: Array = game.records
	# 部隊戦績のカード → 番号
	if d.has("idx") and d.has("cat"):
		var i = d["idx"]
		if i is int and i >= 0 and i < recs.size() and is_same(recs[i], d):
			return {"$r": i}
	# 特別強化ごとのカード → [元のカードの番号, 特別強化の id]
	if d.has("sp_id") and d.has("rec_idx"):
		var ri = d["rec_idx"]
		if ri is int and ri >= 0 and ri < recs.size():
			var cache: Dictionary = recs[ri].get("_sp_src", {})
			if is_same(cache.get(d["sp_id"]), d):
				return {"$s": [ri, d["sp_id"]]}
	# 同じ辞書を何か所かで持っているなら、2回目からは番号だけ（空の辞書は数えない）
	var sid := -1
	if not d.is_empty():
		var bucket: Array = _shared_dicts.get_or_add(d.hash(), [])
		for e in bucket:
			if is_same(e[0], d):
				return {"$sr": e[1]}
		sid = _next_shared
		_next_shared += 1
		bucket.append([d, sid])
	var flat: Array = []
	# キーと値は keys() / values() で取り出す（消えたノードがキーのときに d[k] で引くと、別のキーの値が返ることがあるため）
	var keys: Array = d.keys()
	var vals: Array = d.values()
	for i in keys.size():
		var ek = _enc_key(keys[i])
		if ek is String and ek == _DROP:
			continue
		flat.append(ek)
		flat.append(_enc(vals[i]))
	return {"$d": flat, "$id": sid}


func _enc_key(k):
	if typeof(k) == TYPE_OBJECT:
		if not is_instance_valid(k) or not (k is Node) or not _ids.has(k):
			return _DROP
		return {"$n": _ids[k]}
	return _enc(k)


# ---------------------------------------------------------------- ロード

func _restore(data: Dictionary) -> Dictionary:
	var fixed := _fixed_nodes()
	for i in FIXED.size():
		_nodes[i] = fixed[FIXED[i]]
	# 保存したノードを先に全部作る（参照を付け直すため。まだツリーには入れない）
	var created: Array = []
	for nd in data["nodes"]:
		var path: String = nd["script"]
		if not ResourceLoader.exists(path):
			continue
		var n = load(path).new()
		_nodes[int(nd["id"])] = n
		created.append([n, nd])
	# 書いた順に読む：戦績カード → main → いつもあるノード → 保存したノード
	var recs: Array = []
	for r in data["records"]:
		recs.append(_dec_record(r))
	game.records = recs
	var main_props := _dec_props(data["main"])
	var fixed_props: Array = []
	for fd in data["fixed"]:
		fixed_props.append([fixed[fd["key"]], _dec_props(fd["props"]), fd["builtin"], _dec_props(fd["meta"])])
	var node_props: Array = []
	for item in created:
		var nd: Dictionary = item[1]
		node_props.append([item[0], _dec_props(nd["props"]), nd["builtin"], nd["groups"], _dec_props(nd["meta"]), PARENTS.find(nd["parent"])])
	# main といつもあるノードの中身を戻す（採掘場の一覧なども、ノードを入れる前に戻しておく）
	_apply(game, main_props, false)
	for fp in fixed_props:
		_apply_node(fp[0], fp[1], fp[2], fp[3])
	# 保存したノードを入れる：先に参照・数値だけ入れて（_ready で使うため）ツリーに入れ、そのあと全部の変数を上書きする
	for np in node_props:
		var n: Node = np[0]
		_apply_builtin(n, np[2])
		_apply(n, np[1], true)
		for g in np[3]:
			n.add_to_group(g)
	var parents := [game.world, game.ground, game.effects]
	for np in node_props:
		parents[maxi(0, np[5])].add_child(np[0])
	for np in node_props:
		var n: Node = np[0]
		_apply_node(n, np[1], np[2], np[4])
		# _ready で入ったグループのうち、保存したときに入っていなかったものは外す
		for g in n.get_groups():
			if not str(g).begins_with("_") and not str(g) in np[3]:
				n.remove_from_group(g)
	# _ready が書き換えたかもしれないので、main といつもあるノードをもう一度戻す
	_apply(game, main_props, false)
	for fp in fixed_props:
		_apply_node(fp[0], fp[1], fp[2], fp[3])
	# _ready が作った新しい戦績カードは捨てる
	game.records = recs
	recs.resize(data["records"].size())
	return data.get("levelup", {}).merged({"ok": true})


func _apply_node(n: Node, props: Array, builtin: Array, meta: Array) -> void:
	_apply_builtin(n, builtin)
	_apply(n, props, false)
	for m in meta:
		n.set_meta(m[0], m[1])


func _apply_builtin(n: Node, builtin: Array) -> void:
	for b in builtin:
		n.set(b[0], b[1])


## 変数を戻す。only_simple = true なら辞書・配列は後回し（ツリーに入れる前の分）
func _apply(obj: Object, props: Array, only_simple: bool) -> void:
	var names := _var_names(obj)
	for p in props:
		if not names.has(p[0]):
			continue
		if only_simple and (p[1] is Dictionary or p[1] is Array):
			continue
		obj.set(p[0], p[1])


## [[変数名, 値], ...] を読む（保存しなかった物 "$x" は飛ばして、今の値のままにする）
func _dec_props(props: Array) -> Array:
	var out: Array = []
	for p in props:
		var raw = p[1]
		if raw is Dictionary and raw.has("$x"):
			continue
		out.append([p[0], _dec(raw)])
	return out


func _dec_record(r: Array) -> Dictionary:
	var d := {}
	for p in r:
		var raw = p[1]
		if raw is Dictionary and raw.has("$sub"):
			var subs := {}
			for s in raw["$sub"]:
				var sd := {}
				for q in s[1]:
					sd[q[0]] = _dec(q[1])
				subs[s[0]] = sd
			d[p[0]] = subs
		else:
			d[p[0]] = _dec(raw)
	return d


func _dec(v):
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_dec(x))
		return a
	if not (v is Dictionary):
		return v
	if v.has("$n"):
		return _nodes.get(int(v["$n"]))
	if v.has("$r"):
		var i := int(v["$r"])
		return game.records[i] if i < game.records.size() else {}
	if v.has("$s"):
		var ri := int(v["$s"][0])
		if ri >= game.records.size():
			return {}
		var rec: Dictionary = game.records[ri]
		var cache: Dictionary = rec.get("_sp_src", {})
		if cache.has(v["$s"][1]):
			return cache[v["$s"][1]]
		return game.sp_src(rec, v["$s"][1])
	if v.has("$i"):
		var n = _nodes.get(int(v["$i"]))
		return n.get_instance_id() if n != null else 0
	if v.has("$sr") or v.has("$or"):
		return _loaded_shared.get(int(v.get("$sr", v.get("$or"))))
	if v.has("$o"):
		var path: String = v["$o"]
		if not ResourceLoader.exists(path):
			return null
		var obj = load(path).new()
		_loaded_shared[int(v["$id"])] = obj
		_apply(obj, _dec_props(v["p"]), false)
		return obj
	if v.has("$x"):
		return null
	if v.has("$d"):
		var d := {}
		var sid := int(v.get("$id", -1))
		if sid >= 0:
			_loaded_shared[sid] = d
		var flat: Array = v["$d"]
		for i in range(0, flat.size(), 2):
			var rk = flat[i]
			var k = _dec(rk)
			# 保存しなかったノードがキーだったものは捨てる
			if k == null and rk is Dictionary and rk.has("$n"):
				continue
			d[k] = _dec(flat[i + 1])
		return d
	return v
