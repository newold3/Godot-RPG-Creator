@tool
extends GuiCoreMainMenuDirector

#region ThemeExportsAndNodes
@export var animation_player: AnimationPlayer
@export var help_label: Label
@export var library_scene: PackedScene
@export var status_scene: PackedScene
@export var quests_scene: PackedScene
@export var professions_scene: PackedScene
@export var options_scene: PackedScene
@export var extra_slot_scene: PackedScene
#endregion

#region VirtualHooks
func play_show_item_menu_animation() -> void:
	if animation_player and animation_player.has_animation("Show Item Menu"):
		animation_player.speed_scale = 1.7
		animation_player.play("Show Item Menu")


func play_hide_item_menu_animation() -> void:
	if animation_player and animation_player.has_animation("Hide Item Menu"):
		animation_player.speed_scale = 1.0
		animation_player.play_backwards("Hide Item Menu")


func animate_party_panel(actor: GameActor) -> void:
	if party_scene and party_scene.has_method("get_panel_for_actor"):
		var panel = party_scene.get_panel_for_actor(actor)
		if panel:
			if panel.has_method("glow_animation"):
				panel.glow_animation()
			if panel.has_method("shake_animation"):
				panel.shake_animation()


func update_help_text(text: String) -> void:
	if help_label:
		help_label.text = text


func get_library_scene() -> PackedScene:
	if not library_scene:
		library_scene = load("res://Scenes/GUI/SteamPunkTheme/Library/main_scene.tscn")
	return library_scene


func get_status_scene() -> PackedScene:
	if not status_scene:
		status_scene = load("res://Scenes/GUI/SteamPunkTheme/Status/main_scene.tscn")
	return status_scene


func get_quests_scene() -> PackedScene:
	if not quests_scene:
		quests_scene = load("res://Scenes/GUI/SteamPunkTheme/Quests/main_scene.tscn")
	return quests_scene


func get_professions_scene() -> PackedScene:
	if not professions_scene:
		professions_scene = load("res://Scenes/GUI/SteamPunkTheme/Professions/main_scene.tscn")
	return professions_scene


func get_options_scene() -> PackedScene:
	if not options_scene:
		options_scene = load("res://Scenes/GUI/SteamPunkTheme/Options/main_scene.tscn")
	return options_scene


func get_extra_slot_scene() -> PackedScene:
	if not extra_slot_scene:
		extra_slot_scene = load("res://Scenes/GUI/SteamPunkTheme/ExtraSlot/main_scene.tscn")
	return extra_slot_scene


func on_parent_became_visible() -> void:
	super.on_parent_became_visible()
	var root = get_parent()
	if root:
		if root.has_node("%TitleContainer"):
			root.get_node("%TitleContainer").start()
		if root.has_node("%BottomMainMenu"):
			root.get_node("%BottomMainMenu").restart()
#endregion
