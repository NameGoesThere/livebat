extends "res://addons/ModLoader/mod_node.gd"

var Network

var bats_node
var bat_visual


func init():
	ModLoader.mod_log(name_pretty + " mod loaded")

	Network = load(path_to_dir + "/network.gd").new()
	Network.name = "Network"

	get_tree().get_root().call_deferred("add_child", Network)

	bat_visual = load(path_to_dir + "/bat_visual.tscn")

	bats_node = Node.new()
	bats_node.name = "livebat_bats"
	get_tree().get_root().call_deferred("add_child", bats_node)

	var menu_script_override = load(path_to_dir + "/main_screen_override.gd")
	menu_script_override.take_over_path("res://scripts/ui/main_screen.gd")


func _physics_process(_delta):
	if Network.lobby_id:
		if GameManager.get_player().position:
			Network.send_p2p_packet(
				0,
				{
					"message": "position",
					"position": GameManager.get_player().position,
					"rotation": GameManager.get_player().rotation,
					"level": GameManager.get_tree_root().scene_file_path,
					"id": Steam.getSteamID()
				}
			)

		for lobby_member in Network.lobby_members:
			var id = lobby_member["steam_id"]

			var bat = bats_node.get_node_or_null("BAT " + str(id))

			if bat:
				bat.position = Network.player_positions[id]
				bat.rotation = Network.player_rotations[id]

				bat.visible = (
					GameManager.get_tree_root().scene_file_path == Network.player_levels[id]
				)

				bat.get_node("Name").text = lobby_member["steam_name"]
			else:
				bat = bat_visual.instantiate()
				bat.name = "BAT " + str(id)

				bats_node.call_deferred("add_child", bat)

				var animation_player = bat.get_node("bat_combined_4_0/AnimationPlayer")
				animation_player.play("fly")
				animation_player.speed_scale = 2.0
