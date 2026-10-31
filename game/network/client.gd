class_name GardenNetwork
extends Node
signal games_changed(games: Array)
signal room_changed(room: Dictionary)
signal field_received(player: String, state: Dictionary)
signal chat_received(player: String, author: String, message: String)
signal status_changed(message: String)
signal issue(code: String, message: String)
signal interrupted
signal entered
signal departed(reason: String)

const SETTINGS := "user://multiplayer.cfg"
var settings := ConfigFile.new()
var address := ""
var display_name := "Gardener"
var chat_sound := true
var id := ""
var room: Dictionary = {}
var games: Array = []
var authenticated := false
var reconnecting := false
var socket: WebSocketPeer
var token := ""
var isolated := false
var _hello_sent := false
var _intentional := true
var _last_received := 0.0
var _ping := 0.0
var _retry := 0.0
var _deadline := 0.0
var _connected_at := 0.0
var _pending_leave := ""

func _ready() -> void:
	if not isolated: settings.load(SETTINGS)
	var defaults := ConfigFile.new()
	defaults.load("res://network/server.cfg")
	address=settings.get_value("connection","address",defaults.get_value("server","url",""))
	display_name=settings.get_value("player","name","Gardener")
	chat_sound=settings.get_value("chat","sound",true)

func save_settings() -> void:
	if isolated: return
	settings.set_value("connection","address",address)
	settings.set_value("player","name",display_name)
	settings.set_value("chat","sound",chat_sound)
	settings.save(SETTINGS)

func reset_identity() -> void:
	settings.set_value("identities",address.sha256_text(),""); token=""; save_settings()

func valid_address(value: String) -> bool:
	for space in [" ","\n","\r","\t"]:
		if value.contains(space): return false
	var secure := value.begins_with("wss://")
	if not secure and not value.begins_with("ws://"): return false
	var authority := value.substr(6 if secure else 5).get_slice("/",0)
	if authority.is_empty() or authority.contains("@") or authority.contains("?") or authority.contains("#"): return false
	if secure: return true
	for host in ["127.0.0.1:","localhost:","[::1]:"]:
		if authority.begins_with(host):
			var port := authority.trim_prefix(host)
			return port.is_valid_int() and int(port)>0 and int(port)<=65535
	return false

func connect_server() -> void:
	if not valid_address(address): issue.emit("address","Set a secure server address in Connection settings (wss://your-server/ws)."); return
	if display_name.strip_edges().is_empty(): issue.emit("name","Choose a player name first."); return
	_intentional=false; _open()

func _open() -> void:
	if socket!=null: socket.close()
	socket=WebSocketPeer.new(); socket.inbound_buffer_size=1024*1024; socket.outbound_buffer_size=1024*1024; socket.max_queued_packets=64
	token=settings.get_value("identities",address.sha256_text(),"")
	authenticated=false; _hello_sent=false; _connected_at=Time.get_ticks_msec()/1000.0; _last_received=_connected_at
	var err := socket.connect_to_url(address)
	status_changed.emit("Reconnecting…" if reconnecting else "Connecting to the garden server…")
	if err!=OK: _lost()

func send(message: Dictionary) -> bool:
	if socket==null or socket.get_ready_state()!=WebSocketPeer.STATE_OPEN: return false
	return socket.send_text(JSON.stringify(message,"",true,true))==OK

func refresh() -> void:
	if authenticated: send({"type":"list"})

func create_game(game_name: String, password: String) -> void:
	if authenticated: send({"type":"create","name":game_name.strip_edges(),"password":password})

func join_game(game_id: String, password: String = "") -> void:
	if authenticated: send({"type":"join","game":game_id,"password":password})
	else: issue.emit("connection","Connect to the server before joining a game.")

func publish(state: Dictionary) -> void:
	if authenticated and not room.is_empty() and not reconnecting and socket.get_current_outbound_buffered_amount()<128*1024:
		send({"type":"state","state":state})

func say(message: String) -> bool:
	return authenticated and not room.is_empty() and not reconnecting and send({"type":"chat","text":message})

func kick(player: String) -> void: send({"type":"kick","player":player})

func leave_game() -> void:
	if not room.is_empty():
		if authenticated: send({"type":"leave","game":room.id})
		else: _pending_leave=room.id
	room={}; reconnecting=false; departed.emit("")

func disconnect_server() -> void:
	leave_game(); _intentional=true; authenticated=false
	games=[]; games_changed.emit(games)
	if socket!=null: socket.close(1000,"Leaving")

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()/1000.0
	if reconnecting and now>=_deadline:
		_intentional=true; authenticated=false; reconnecting=false
		if socket!=null: socket.close()
		room={}; departed.emit("Your reserved place expired. Your garden is safe; join a game again."); return
	if socket==null:
		if reconnecting and now>=_retry: _open()
		return
	socket.poll()
	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _hello_sent:
				_hello_sent=true; send({"type":"hello","version":1,"name":display_name.strip_edges(),"token":token})
			var budget := 64
			while socket!=null and socket.get_available_packet_count()>0 and budget>0:
				budget-=1
				var packet := socket.get_packet()
				if packet.size()>512*1024: continue
				var data = JSON.parse_string(packet.get_string_from_utf8())
				if data is Dictionary: _last_received=now; _receive(data)
			_ping+=delta
			if _ping>=10.0: _ping=0; send({"type":"ping"})
			if now-_last_received>25: _lost()
		WebSocketPeer.STATE_CLOSED: _lost()
		WebSocketPeer.STATE_CONNECTING:
			if now-_connected_at>8: _lost()

func _lost() -> void:
	if socket!=null: socket.close(); socket=null
	authenticated=false
	if _intentional: return
	if not room.is_empty():
		if not reconnecting:
			reconnecting=true; _deadline=Time.get_ticks_msec()/1000.0+60; interrupted.emit()
		_retry=Time.get_ticks_msec()/1000.0+2
		status_changed.emit("Connection lost. Your garden is paused; reconnecting…")
	else:
		_intentional=true; games=[]; games_changed.emit(games); status_changed.emit("Could not reach the server. Check Connection settings and try again.")

func _receive(data: Dictionary) -> void:
	match data.get("type",""):
		"welcome":
			id=str(data.get("id","")); token=str(data.get("token","")); authenticated=true
			settings.set_value("identities",address.sha256_text(),token); save_settings()
			status_changed.emit("Connected. Choose a garden or create your own.")
			if not _pending_leave.is_empty(): send({"type":"leave","game":_pending_leave}); _pending_leave=""
			if reconnecting and not room.is_empty(): send({"type":"resume","game":room.id})
		"games":
			if data.get("games") is Array: games=data.games; games_changed.emit(games)
		"joined":
			if data.get("game") is Dictionary:
				var returning := reconnecting
				room=data.game; reconnecting=false; entered.emit(); room_changed.emit(room)
				if returning: status_changed.emit("Reconnected. Your garden is paused; resume when you are ready.")
		"room":
			if data.get("game") is Dictionary and data.game.get("id")==room.get("id"): room=data.game; room_changed.emit(room)
		"state":
			if data.get("game")==room.get("id") and data.get("state") is Dictionary:
				var player := str(data.get("player",""))
				if player!=id and room.get("players",[]).any(func(p): return p.get("id")==player): field_received.emit(player,data.state)
		"chat": chat_received.emit(str(data.get("player","")),str(data.get("name","Player")),str(data.get("text","")))
		"kicked":
			room={}; reconnecting=false; departed.emit(str(data.get("message","You were removed from the game.")))
		"error":
			var code := str(data.get("code","")); var message := str(data.get("message","Unable to complete that action."))
			if code in ["identity","duplicate","hello"]:
				_intentional=true; authenticated=false
				if socket!=null: socket.close(); socket=null
				if reconnecting: room={}; reconnecting=false; departed.emit(message)
			if code in ["expired","banned"] and reconnecting: room={}; reconnecting=false; departed.emit(message)
			issue.emit(code,message)
