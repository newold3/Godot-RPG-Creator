class_name MainScene
extends Node2D

@export var transition_manager: Control

var initialize_title_scene: bool = false
var game_state: GameUserData
var current_map: RPGMap
var busy: bool = false
var battle_in_progress: bool = false
var current_scene: Node
var is_test_map: bool = false
var fx_busy: bool:
	get:
		if has_node("%SystemAudioManager"):
			return %SystemAudioManager.fx_busy
		return false
	set(value):
		if has_node("%SystemAudioManager"):
			%SystemAudioManager.fx_busy = value

@onready var interpreter = %Interpreter
@onready var main_camera: Camera2D = %MainCamera
@onready var map_container: Parallax2D = %MapContainer
@onready var animate_items: ItemAnimationControl = %AnimateItems
@onready var main_game_viewport: SubViewport = %MainGameViewport

@warning_ignore("unused_signal")
signal scene_changed()


func _ready() -> void:
	get_viewport().transparent_bg = false
	preload_system_scenes()
	GameManager.main_scene = self
	GameManager.hand_cursor.reparent(self)
	
	if not is_test_map:
		if not initialize_title_scene:
			if has_node("%GameLoaderManager"):
				%GameLoaderManager.setup_new_game()
		else:
			var main_menu_path = RPGSYSTEM.database.system.game_scenes["Scene Title"]
			change_scene(main_menu_path)
	else:
		if has_node("%GameLoaderManager"):
			%GameLoaderManager.setup_test_game()


func show_popup_message(obj: Dictionary) -> void:
	animate_items.add_single_item(obj)



#region Getters Base
func get_main_scene_texture() -> Texture:
	if main_game_viewport:
		return main_game_viewport.get_texture()
	else:
		return null


func get_main_sub_viewport_container() -> SubViewportContainer:
	return %MainSubViewportContainer


func get_screen_effect_canvas() -> CanvasLayer:
	return %ScreenEffectCanvas


func get_image_container() -> Node:
	return %ImageContainer


func get_scene_container() -> Node:
	return %SceneContainer


func get_main_camera() -> Camera2D:
	return %MainCamera


func get_main_interpreter() -> MainInterpreter:
	return GameInterpreter


func get_character_baker() -> CharacterBaker:
	return %CharacterBaker


func get_secondary_transition_node() -> ColorRect:
	return %SecondaryTransition


func get_dynamic_shadows_node() -> Node2D:
	return %DynamicShadows
#endregion


#region SceneManager Wrappers
func clear_current_map() -> void:
	if has_node("%SceneManager"): %SceneManager.clear_current_map()


func set_map(map: RPGMap) -> void:
	if has_node("%SceneManager"): %SceneManager.set_map(map)


func clear_map_repeating() -> void:
	if has_node("%SceneManager"): %SceneManager.clear_map_repeating()


func enable_map_repeating() -> void:
	if has_node("%SceneManager"): %SceneManager.enable_map_repeating()


func change_scene(path: String, destroy_gui: bool = false) -> void:
	if has_node("%SceneManager"): await %SceneManager.change_scene(path, destroy_gui)
#endregion



#region GameLoaderManager Wrappers
func setup_new_game() -> void:
	if has_node("%GameLoaderManager"):
		%GameLoaderManager.setup_new_game()


func setup_test_game() -> void:
	if has_node("%GameLoaderManager"):
		%GameLoaderManager.setup_test_game()


func load_game(data: RPGSavedGameData) -> void:
	if has_node("%GameLoaderManager"):
		%GameLoaderManager.load_game(data)


func preload_system_scenes() -> void:
	if has_node("%GameLoaderManager"):
		%GameLoaderManager.preload_system_scenes()
#endregion



#region PartyManager Wrappers
func add_actor_to_party(actor_id: int) -> void:
	if has_node("%PartyManager"):
		%PartyManager.add_actor_to_party(actor_id)


func remove_actor_from_party(remove_actor_id: int) -> void:
	if has_node("%PartyManager"):
		%PartyManager.remove_actor_from_party(remove_actor_id)


func clear_current_player() -> void:
	if has_node("%PartyManager"):
		%PartyManager.clear_current_player()


func setup_player() -> void:
	if has_node("%PartyManager"):
		%PartyManager.setup_player()


func update_party_visuals(instant: bool = false) -> void:
	if has_node("%PartyManager"):
		%PartyManager.update_party_visuals(instant)


func process_follower_command(command_id: String, ...values: Array) -> void:
	if has_node("%PartyManager"):
		match command_id:
			"show":
				var is_show: bool = values[0] if values.size() > 0 else true
				var instant: bool = values[1] if values.size() > 1 else false
				if is_show:
					%PartyManager.update_party_visuals(instant)
					
					await %PartyManager.appear(instant)
				else:
					await %PartyManager.disappear(instant, true)
				
			"update":
				var instant: bool = values[0] if values.size() > 0 else false
				%PartyManager.update_party_visuals(instant)
				
			"disappear":
				var instant: bool = values[0] if values.size() > 0 else false
				await %PartyManager.disappear(instant, false)
				
			"appear":
				var instant: bool = values[0] if values.size() > 0 else false
				await %PartyManager.appear(instant)
				
			"regroup":
				var time: float = values[0] if values.size() > 0 else 0.6
				var delete_followers: bool = values[1] if values.size() > 1 else false
				await %PartyManager.regroup(time, delete_followers)
			
			"disable_tracking":
				var time: float = values[0] if values.size() > 0 else 0.5
				await %PartyManager.disable_split_mode(time)
				
			"shift_up":
				await %PartyManager.change_leader_to("up")
				
			"shift_down":
				await %PartyManager.change_leader_to("down")
				
			"destroy":
				%PartyManager.destroy()
#endregion



#region SystemAudioManager Wrappers
func play_bgm(bgm: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.play_bgm(bgm, volume, pitch, fade_duration)


func play_bgs(bgs: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.play_bgs(bgs, volume, pitch, fade_duration)


func play_se(fx: Variant, volume: float = 0.0, pitch: float = 1.0) -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.play_se(fx, volume, pitch)


func play_me(me: Variant, volume: float = 0.0, pitch: float = 1.0) -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.play_me(me, volume, pitch)


func stop_bgm(fade_duration: float = 0) -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.stop_bgm(fade_duration)


func stop_bgs(fade_duration: float = 0) -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.stop_bgs(fade_duration)


func stop_se() -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.stop_se()


func save_bgm() -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.save_bgm()


func restore_bgm() -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.restore_bgm()


func play_fx(id: Variant) -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.play_fx(id)


func play_music(id: Variant) -> void:
	if has_node("%SystemAudioManager"): %SystemAudioManager.play_music(id)


func get_fx_path(id: Variant) -> String:
	if has_node("%SystemAudioManager"): return %SystemAudioManager.get_fx_path(id)
	return ""
#endregion



#region ScreenVisualsManager Wrappers
func set_day_color(new_color: Color) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.set_day_color(new_color)


func set_use_day_night(enabled: bool) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.set_use_day_night(enabled)


func set_map_color(new_color: Color) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.set_map_color(new_color)


func set_weather_color(new_color: Color, duration: float) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.set_weather_color(new_color, duration)


func remove_weather_color(duration: float) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.remove_weather_color(duration)


func set_weather_flash(color: Color, duration: float) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.set_weather_flash(color, duration)


func set_tint_color(new_color: Color, duration: float) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.set_tint_color(new_color, duration)


func remove_tint_color(duration: float) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.remove_tint_color(duration)


func get_modulate_scenes() -> Dictionary:
	if has_node("%ScreenVisualsManager"): return %ScreenVisualsManager.get_modulate_scenes()
	return {}


func set_canvas_modulate_color(color: Color) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.set_canvas_modulate_color(color)


func set_weather_modulate_color(color: Color) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.set_weather_modulate_color(color)


func get_canvas_modulate_color() -> Color:
	if has_node("%ScreenVisualsManager"): return %ScreenVisualsManager.get_canvas_modulate_color()
	return Color.WHITE


func set_flash_color(color: Color, blend: CanvasItemMaterial.BlendMode) -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.set_flash_color(color, blend)


func play_video(path: String, loop: bool = false, fade_out_time: float = 0.0) -> VideoStreamPlayer:
	if has_node("%ScreenVisualsManager"): return %ScreenVisualsManager.play_video(path, loop, fade_out_time)
	return null


func stop_video() -> void:
	if has_node("%ScreenVisualsManager"): %ScreenVisualsManager.stop_video()
#endregion
