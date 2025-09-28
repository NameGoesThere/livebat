extends Node

const PACKET_READ_LIMIT: int = 32

var is_host: bool = false
var lobby_id: int = 0
var lobby_members: Array = []
const lobby_members_max: int = 128

var player_positions: Dictionary = {}
var player_rotations: Dictionary = {}
var player_levels: Dictionary = {}

const CHANNEL_MAIN = 0


func _ready():
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.p2p_session_request.connect(on_p2p_session_request)


func _process(delta: float):
	if lobby_id > 0:
		read_all_p2p_packets()


func create_lobby(lobby_type: int = Steam.LOBBY_TYPE_PUBLIC):
	if lobby_id == 0:
		is_host = true
		Steam.createLobby(lobby_type, lobby_members_max)


func _on_lobby_created(_connect: int, this_lobby_id: int):
	if _connect == 1:
		lobby_id = this_lobby_id
		print("Created lobby with id: " + str(lobby_id))

		Steam.setLobbyJoinable(lobby_id, true)
		Steam.setLobbyData(lobby_id, "name", Steam.getPersonaName() + "'s Lobby")

		var _set_relay: bool = Steam.allowP2PPacketRelay(true)
	else:
		print("Failed to create lobby.")
		is_host = false


func join_lobby(this_lobby_id: int):
	Steam.joinLobby(this_lobby_id)


func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int):
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_id = this_lobby_id
		print("Joined lobby with id: " + str(lobby_id))

		get_lobby_members()
		make_p2p_handshake()

	else:
		print("Failed to join lobby.")


func leave_lobby():
	send_p2p_packet(0, {"message": "leave", "id": Steam.getSteamID()})

	Steam.leaveLobby(lobby_id)
	is_host = false
	lobby_id = 0

	for this_member in lobby_members:
		if this_member["steam_id"] != Steam.getSteamID():
			Steam.closeP2PSessionWithUser(this_member["steam_id"])

	lobby_members.clear()
	player_positions.clear()
	player_rotations.clear()
	player_levels.clear()


func get_lobby_members():
	lobby_members.clear()

	player_positions.clear()
	player_rotations.clear()
	player_levels.clear()

	var bats = get_tree().get_root().get_node("livebat_bats")

	for bat in bats.get_children():
		bat.queue_free()

	var lobby_members_len: int = Steam.getNumLobbyMembers(lobby_id)

	for member in range(0, lobby_members_len):
		var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, member)
		var member_steam_name: String = Steam.getFriendPersonaName(member_steam_id)

		lobby_members.append({"steam_id": member_steam_id, "steam_name": member_steam_name})


func send_p2p_packet(this_target: int, packet_data: Dictionary, send_type: int = 0):
	var channel: int = CHANNEL_MAIN

	var this_data: PackedByteArray
	this_data.append_array(var_to_bytes(packet_data))

	if this_target == 0:
		if lobby_members.size() > 1:
			for member in lobby_members:
				if member["steam_id"] != Steam.getSteamID():
					Steam.sendP2PPacket(member["steam_id"], this_data, send_type, channel)
	else:
		Steam.sendP2PPacket(this_target, this_data, send_type, channel)


func on_p2p_session_request(remote_id: int):
	var _this_requester: String = Steam.getFriendPersonaName(remote_id)

	Steam.acceptP2PSessionWithUser(remote_id)


func make_p2p_handshake():
	send_p2p_packet(
		0,
		{"message": "handshake", "steam_id": Steam.getSteamID(), "username": Steam.getPersonaName()}
	)


func read_all_p2p_packets(read_count: int = 0):
	if read_count >= PACKET_READ_LIMIT:
		return

	if Steam.getAvailableP2PPacketSize(0) > 0:
		read_p2p_packet()
		read_all_p2p_packets(read_count + 1)


func read_p2p_packet():
	var packet_size: int = Steam.getAvailableP2PPacketSize(0)

	if packet_size > 0:
		var this_packet: Dictionary = Steam.readP2PPacket(packet_size, CHANNEL_MAIN)

		var packet_sender: int = this_packet["remote_steam_id"]

		var packet_code: PackedByteArray = this_packet["data"]
		var readable_data: Dictionary = bytes_to_var(packet_code)

		if readable_data.has("message"):
			match readable_data["message"]:
				"handshake":
					print("Player: " + readable_data["username"] + " has joined.")
					get_lobby_members()
				"position":
					player_positions[readable_data["id"]] = readable_data["position"]
					player_rotations[readable_data["id"]] = readable_data["rotation"]
					player_levels[readable_data["id"]] = readable_data["level"]
				"leave":
					get_lobby_members()
					(
						get_tree()
						. get_root()
						. get_node("livebat_bats")
						. get_node("BAT " + str(readable_data["id"]))
						. queue_free()
					)
