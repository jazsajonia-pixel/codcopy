extends VBoxContainer
## LAN lobby + LAN Team Deathmatch. Honest about scope: local network only, no internet servers.

var menu: Control
var status_l: Label
var peers_l: Label
var ip_edit: LineEdit
var start_btn: Button
var map_btns := {}
var lan_map := "outpost"


func _ready() -> void:
	add_child(UITheme.label("ONLINE (LAN) - EXPERIMENTAL", 30, UITheme.ACCENT))
	var note := UITheme.label("Play Team Deathmatch with other devices on the same Wi-Fi / local network. One device hosts, the others join with the host's IP address. Empty slots are filled with AI bots (tagged [BOT]). There are no internet servers or matchmaking.", 16, UITheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(UITheme.button("HOST LAN LOBBY", func(): NetworkManager.host(), Vector2(260, 60), "confirm"))
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "Host IP, e.g. 192.168.1.20"
	ip_edit.text = "127.0.0.1"
	ip_edit.custom_minimum_size = Vector2(280, 56)
	row.add_child(ip_edit)
	row.add_child(UITheme.button("JOIN", func(): NetworkManager.join(ip_edit.text.strip_edges()), Vector2(140, 60)))
	row.add_child(UITheme.button("LEAVE", func(): NetworkManager.leave(); _refresh(), Vector2(140, 60), "back"))
	status_l = UITheme.label("", 20)
	add_child(status_l)
	add_child(UITheme.label("Your LAN addresses: " + ", ".join(NetworkManager.local_ips()), 16, UITheme.MUTED))
	add_child(UITheme.label("PLAYERS IN LOBBY", 18, UITheme.MUTED))
	peers_l = UITheme.label("", 18)
	add_child(peers_l)
	var mrow := HBoxContainer.new()
	add_child(mrow)
	mrow.add_child(UITheme.label("MAP  ", 18, UITheme.MUTED))
	for id in ["outpost", "crossroads"]:
		var b := UITheme.button(String(GameDB.MP_MAPS[id].name), func(): _set_map(id), Vector2(200, 56), "select")
		b.toggle_mode = true
		mrow.add_child(b)
		map_btns[id] = b
	start_btn = UITheme.button("START LAN TEAM DEATHMATCH", func(): NetworkManager.start_lan_match(lan_map), Vector2(440, 70), "confirm")
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(start_btn)
	_set_map(lan_map)
	NetworkManager.peers_changed.connect(_refresh)
	NetworkManager.status_changed.connect(_refresh.unbind(1))
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	status_l.text = "Status: " + NetworkManager.status
	var t := ""
	for id in NetworkManager.peers.keys():
		t += "%s  (peer %d)%s\n" % [NetworkManager.peers[id].name, id, "  HOST" if int(id) == 1 else ""]
	peers_l.text = t if t != "" else "-"
	var n := NetworkManager.peers.size()
	start_btn.visible = NetworkManager.is_host
	start_btn.disabled = n < 2
	start_btn.text = "START LAN TEAM DEATHMATCH (%d players)" % n if n >= 2 else "WAITING FOR PLAYERS TO JOIN"
	for b in map_btns.values():
		b.disabled = not NetworkManager.is_host
	if NetworkManager.is_online() and not NetworkManager.is_host and n > 0:
		status_l.text += "   -   waiting for the host to start"


func _set_map(id: String) -> void:
	lan_map = id
	for k in map_btns.keys():
		map_btns[k].set_pressed_no_signal(k == id)
