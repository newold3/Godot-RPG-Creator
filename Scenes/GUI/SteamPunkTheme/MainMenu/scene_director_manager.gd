@tool
extends GuiCoreMainMenuDirector

#region ThemeExportsAndNodes
@export var animation_player: AnimationPlayer
@export var help_label: Label
@export var library_scene: PackedScene = preload("uid://dcdwnws1525xh")
@export var status_scene: PackedScene = preload("uid://cfstatusmain01")
@export var quests_scene: PackedScene = preload("uid://cfquestsmain01")
@export var professions_scene: PackedScene = preload("uid://cfprofessions01")
@export var options_scene: PackedScene = preload("uid://blg3j1imwfeog")
@export var extra_slot_scene: PackedScene = preload("uid://cfextraslot01")
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
	return library_scene


func get_status_scene() -> PackedScene:
	return status_scene


func get_quests_scene() -> PackedScene:
	return quests_scene


func get_professions_scene() -> PackedScene:
	return professions_scene


func get_options_scene() -> PackedScene:
	return options_scene


func get_extra_slot_scene() -> PackedScene:
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
