class_name SaveStore
extends RefCounted
const SAVE_PATH := "user://save.json"
const ACHIEVEMENTS_PATH := "user://achievements.json"

static func write_json(data: Dictionary, path: String) -> Error:
	var temp := path+".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data,"\t",true,true)); file.flush()
	var error := file.get_error(); file.close()
	if error!=OK: return error
	return DirAccess.rename_absolute(temp,path)

static func write(session: Session, path: String = SAVE_PATH) -> Error:
	if path==SAVE_PATH:
		var error := finish_reset()
		if error!=OK: return error
	return write_json(session.snapshot(),path)

static func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path+".reset")

static func read_into(session: Session, path: String = SAVE_PATH) -> bool:
	# An interrupted reset is authoritative until both normal files are replaced.
	if FileAccess.file_exists(path+".reset"): path+=".reset"
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return false
	var data = JSON.parse_string(file.get_as_text())
	return data is Dictionary and session.restore(data)

static func write_achievements(book: Achievements, path: String = ACHIEVEMENTS_PATH) -> Error:
	if path==ACHIEVEMENTS_PATH:
		var error := finish_reset()
		if error!=OK: return error
	return write_json(book.snapshot(),path)

static func read_achievements(book: Achievements, path: String = ACHIEVEMENTS_PATH, save_path: String = SAVE_PATH) -> bool:
	# Never merge pre-reset achievements back into the committed fresh garden.
	if FileAccess.file_exists(save_path+".reset"): return true
	if not FileAccess.file_exists(path): return true
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return false
	var data = JSON.parse_string(file.get_as_text())
	if not Achievements.valid(data): return false
	book.merge(data,true)
	return true

static func reset_progress(session: Session, path: String = SAVE_PATH, achievements_path: String = ACHIEVEMENTS_PATH) -> Error:
	# This contains ONLY the fresh state, never an undo copy of the old progress.
	# Its atomic rename commits the reset even if the process stops between files.
	var error := write_json(session.snapshot(),path+".reset")
	if error!=OK: return error
	finish_reset(path,achievements_path)
	return OK

static func finish_reset(path: String = SAVE_PATH, achievements_path: String = ACHIEVEMENTS_PATH) -> Error:
	if not FileAccess.file_exists(path+".reset"): return OK
	var fresh := Session.new()
	if not read_into(fresh,path): return ERR_FILE_CORRUPT
	var error := write_json(fresh.achievements.snapshot(),achievements_path)
	if error!=OK: return error
	error=write_json(fresh.snapshot(),path)
	if error!=OK: return error
	return DirAccess.remove_absolute(path+".reset")
