class_name SaveStore
extends RefCounted
const SAVE_PATH := "user://save.json"

static func write(session: Session, path: String = SAVE_PATH) -> Error:
	var temp := path+".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(session.snapshot(),"\t",true,true)); file.close()
	return DirAccess.rename_absolute(temp,path)

static func read_into(session: Session, path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return false
	var data = JSON.parse_string(file.get_as_text())
	return data is Dictionary and session.restore(data)
