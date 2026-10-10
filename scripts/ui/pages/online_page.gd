extends VBoxContainer
## LAN lobby (networking foundation). Honest about scope: no online gameplay yet.

var menu: Control
var status_l: Label
var peers_l: Label
var ip_edit: LineEdit


func _ready() -> void:
	add_child(UITheme.label("ONLINE (LAN LOBBY - EXPERIMENTAL)", 30, UITheme.ACCENT))
	var note := UITheme.label("This build has no online matchmaking or servers. You can host or join a local-network lobby to test the networking layer; matches themselves are still offline against AI bots. Networked gameplay is the next milestone (see README).", 16, UITheme.MUTED)
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
	add_child(UITheme.label("PEERS", 18, UITheme.MUTED))
	peers_l = UITheme.label("", 18)
	add_child(peers_l)
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
