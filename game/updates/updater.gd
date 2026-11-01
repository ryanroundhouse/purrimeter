class_name GameUpdater
extends Node
signal changed
signal ready_to_exit
var state := "idle"
var message := "Check for game updates."
var latest: Dictionary = {}
var server := ""
var operation := ""
var process_id := -1
var installer_pid := -1
var helper := ""
var work := ""
var elapsed := 0.0
var last_failure := ""
var result_file := ""
var isolated := false
var progress_second := -1

static func build() -> Dictionary:
	var config := ConfigFile.new()
	config.load("res://network/build.cfg")
	return {"id":config.get_value("release","id","development"),"sequence":config.get_value("release","sequence",0),"version":config.get_value("release","version","Development")}

func _ready() -> void:
	work=ProjectSettings.globalize_path("res://../build/update-test-%d"%OS.get_process_id() if isolated else "user://updates")
	DirAccess.make_dir_recursive_absolute(work)
	var suffix := ".exe" if OS.get_name()=="Windows" else ""
	helper=OS.get_executable_path().get_base_dir().path_join("PurrimeterUpdater"+suffix)
	if OS.has_feature("editor"): helper=ProjectSettings.globalize_path("res://../build/PurrimeterUpdater"+suffix)

func check(address: String) -> void:
	if not operation.is_empty() or installer_pid>0: return
	server=address; latest={}; last_failure=""
	var endpoint := address.replace("wss://","https://").replace("ws://","http://")
	if not endpoint.ends_with("/ws"):
		fail("Use a multiplayer server address ending in /ws to check for updates."); return
	state="checking"; message="Checking for updates… Single player is ready."
	run_helper("check",["--url",endpoint.trim_suffix("/ws")+"/updates"])

func download() -> void:
	if state!="available" or not operation.is_empty(): return
	state="downloading"; message="Downloading the update. You can keep playing."
	run_helper("download",[])

func install() -> void:
	if OS.has_feature("editor"):
		fail("Install the downloaded Purrimeter game to use automatic updates."); return
	if state!="downloaded" or not operation.is_empty(): return
	state="preparing"; message="Checking the download and preparing a safe replacement…"
	run_helper("prepare",["--executable",OS.get_executable_path()])

func run_helper(mode: String, extra: Array) -> void:
	if not FileAccess.file_exists(helper): fail("The updater is missing. Download the current game from purrimeter.graham.pub."); return
	operation=mode; elapsed=0.0; progress_second=-1
	if not result_file.is_empty(): DirAccess.remove_absolute(result_file)
	result_file=work.path_join("result-%d.json"%Time.get_ticks_usec())
	var args := PackedStringArray([mode,"--work",work,"--result",result_file]); args.append_array(extra)
	process_id=OS.create_process(helper,args)
	if process_id<0: operation=""; fail("Could not start the updater. Retry or install the download manually.")
	changed.emit()

func _process(delta: float) -> void:
	if installer_pid>0:
		if FileAccess.file_exists(work.path_join("ready")):
			installer_pid=-1; ready_to_exit.emit()
		elif not OS.is_process_running(installer_pid):
			installer_pid=-1; fail("Could not start installation. Your current game is unchanged; retry or install manually.")
		return
	if operation.is_empty(): return
	elapsed+=delta
	if state=="downloading" and int(elapsed)!=progress_second and latest.has("packages"):
		progress_second=int(elapsed)
		var partial := FileAccess.open(work.path_join("package.zip.part"),FileAccess.READ)
		if partial!=null:
			var platform := "windows" if OS.get_name()=="Windows" else "macos"
			var total := float(latest.packages[platform].size)
			message="Downloading update · %d%%. You can keep playing."%mini(99,int(100.0*partial.get_length()/total)); partial.close(); changed.emit()
	if not FileAccess.file_exists(result_file):
		if process_id>0 and not OS.is_process_running(process_id): operation=""; process_id=-1; fail("The updater stopped. Your current game is unchanged. Please retry.")
		return
	var result = JSON.parse_string(FileAccess.get_file_as_string(result_file))
	var completed := operation; operation=""; process_id=-1
	if not result is Dictionary or not result.get("ok",false):
		last_failure=completed
		fail(str(result.get("error","Update failed. Please retry.")) if result is Dictionary else "Update failed. Please retry."); return
	match completed:
		"check":
			latest=result.release
			var installed := build()
			if latest.id==installed.id: state="current"; message="You’re up to date. Multiplayer is ready to connect."
			elif int(latest.sequence)>int(installed.sequence): state="available"; message="Purrimeter %s is available. Update to join multiplayer; single player is always ready."%latest.version
			else: state="newer"; message="This server requires an older release (%s). Downgrades aren’t supported. You can keep playing single player."%latest.version
			if state=="available" and result.get("cached",false): state="downloaded"; message="Your update is verified and ready. Restarting saves your garden and leaves multiplayer."
		"download": state="downloaded"; message="Your update is verified and ready. Restarting saves your garden and leaves multiplayer."
		"prepare":
			DirAccess.remove_absolute(work.path_join("ready"))
			var runner := work.path_join("runner.exe" if OS.get_name()=="Windows" else "runner")
			installer_pid=OS.create_process(runner,["install","--work",work,"--parent",str(OS.get_process_id())])
			if installer_pid<0: fail("Could not start installation. Your current game is unchanged.")
	changed.emit()

func fail(reason: String) -> void:
	state="error"; message=reason+" Single player is still available."; changed.emit()

func retry() -> void:
	if last_failure=="download": state="available"; download()
	elif last_failure=="prepare": state="downloaded"; install()
	else: check(server)

func cancel_worker() -> void:
	if process_id>0 and OS.is_process_running(process_id): OS.kill(process_id)
	process_id=-1; operation=""

func _exit_tree() -> void: cancel_worker()
