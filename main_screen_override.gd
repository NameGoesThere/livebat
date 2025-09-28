extends "res://scripts/ui/main_screen.gd"

var Network

var livebat_container = VBoxContainer.new()

var button_preload = preload("res://addons/ModLoader/mods_settings/button_generic.tscn")
var host_button
var join_button
var leave_button

var line_edit_preload = preload("res://addons/ModLoader/mods_settings/line_edit.tscn")
var lobby_id_edit
var lobby_id_edit_old_text = ""


func _ready():
	super._ready()

	Network = get_tree().get_root().get_node("Network")

	add_child(livebat_container)

	host_button = button_preload.instantiate()
	host_button.text = "Host"
	host_button.name = "LiveBatHostButton"
	host_button.pressed.connect(_on_host_button_up)

	join_button = button_preload.instantiate()
	join_button.text = "Join"
	join_button.name = "LiveBatJoinButton"
	join_button.pressed.connect(_on_join_button_up)

	lobby_id_edit = line_edit_preload.instantiate()
	lobby_id_edit.placeholder_text = "Lobby ID"
	lobby_id_edit.name = "LiveBatLobbyIDEdit"
	lobby_id_edit.text_changed.connect(_on_lobby_id_changed)

	leave_button = button_preload.instantiate()
	leave_button.text = "Leave"
	leave_button.name = "LiveBatLeaveButton"
	leave_button.pressed.connect(_on_leave_button_up)

	livebat_container.add_child(host_button)
	livebat_container.add_child(join_button)
	livebat_container.add_child(lobby_id_edit)
	livebat_container.add_child(leave_button)


func _process(delta: float):
	if Network.is_host:
		if lobby_id_edit.text != str(Network.lobby_id):
			lobby_id_edit.text = str(Network.lobby_id)
			lobby_id_edit_old_text = lobby_id_edit.text


func _on_host_button_up():
	Network.create_lobby()


func _on_join_button_up():
	Network.join_lobby(lobby_id_edit.text.to_int())


func _on_leave_button_up():
	if Network.lobby_id:
		Network.leave_lobby()

		var bats = get_tree().get_root().get_node("livebat_bats")

		for bat in bats.get_children():
			bat.queue_free()


func _on_lobby_id_changed(new_text):
	if (new_text.is_empty() or new_text.is_valid_int()) and not Network.is_host:
		lobby_id_edit_old_text = new_text
	else:
		lobby_id_edit.text = lobby_id_edit_old_text
		lobby_id_edit.set_caret_column(lobby_id_edit_old_text.length())
