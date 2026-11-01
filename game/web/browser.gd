class_name BrowserPlatform
extends Node
signal event_received(kind: String, value: String)
var bridge: JavaScriptObject
var callback: JavaScriptObject
static var current: BrowserPlatform

func _ready() -> void:
	current=self
	if not OS.has_feature("web"): return
	bridge=JavaScriptBridge.get_interface("PurrimeterBrowser")
	callback=JavaScriptBridge.create_callback(func(args): event_received.emit(str(args[0]),str(args[1])))
	bridge.subscribe(callback)

static func enabled() -> bool:
	return OS.has_feature("web") and current!=null and current.bridge!=null

static func may_save() -> bool:
	return not enabled() or bool(current.bridge.active())

static func load_garden(session: Session) -> bool:
	if not enabled(): return true
	var raw: String=current.bridge.initial()
	if raw.is_empty(): return true
	var data = JSON.parse_string(raw)
	return data is Dictionary and session.restore(data)

static func save_garden(session: Session) -> void:
	if enabled(): current.bridge.save(JSON.stringify(session.snapshot(),"",true,true))

static func commit_garden(session: Session) -> bool:
	if not enabled(): return false
	# Session-only completion may be synchronous; do not wait for a signal emitted before await.
	if session_only(): current.bridge.save(JSON.stringify(session.snapshot(),"",true,true)); return may_save()
	current.bridge.commitSave(JSON.stringify(session.snapshot(),"",true,true))
	while true:
		var event: Array = await current.event_received
		if event[0]=="draft_saved": return event[1]=="ok"
	return false

static func session_only() -> bool:
	return enabled() and bool(current.bridge.sessionOnly())

static func load_settings(name: String, config: ConfigFile) -> void:
	if enabled(): config.parse(str(current.bridge.settings(name)))

static func save_settings(name: String, config: ConfigFile) -> void:
	if enabled(): current.bridge.setSettings(name,config.encode_to_text())

static func touch() -> bool:
	return enabled() and bool(current.bridge.touch())
