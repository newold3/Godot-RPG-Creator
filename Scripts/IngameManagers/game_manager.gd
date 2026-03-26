@tool
extends Node


#region Classes
class BattleLastActions:
	var last_used_skill: int = -1
	var last_used_item: int = -1
	var last_actor_to_act: int = -1
	var last_enemy_to_act: int = -1
	var last_actor_targeted: int = -1
	var last_enemy_targeted: int = -1
#endregion


#region Constants & Variables
const MANIPULATOR_MODES = {
	"NONE": "",
	"RESET": "reset",
	"MAIN_MENU_MAIN_BUTTONS": "main menu main buttons",
	"PARTY_MENU": "party menu",
	"EQUIP_ACTORS_MENU": "equip actors menu",
	"EQUIP_MENU": "equip menu",
	"EQUIP_MENU_SUB_MENU": "equip menu sub menu",
	"SAVELOAD": "main menu save/load",
	"CONFIRM": "main confirm window",
	"GUI_SCENE": "standard gui scene",
	"ITEM_MENU1": "select item list 1",
	"ITEM_MENU2": "select item list 2",
	"ITEM_MENU3": "select item list 3",
	"ITEM_MENU4": "select item list 4",
	"PAGINATOR1": "select paginator 1",
	"PAGINATOR2": "select paginator 2",
	"PAGINATOR3": "select paginator 3",
	"PAGINATOR4": "select paginator 4"
}

var game_started: bool = false
var busy: bool
var database: RPGDATA
var game_state: GameUserData
var current_game_options: RPGGameOptions

var main_scene: MainScene
var current_map: RPGMap
var current_player: LPCCharacter
var current_vehicle: RPGVehicle

var current_map_vehicles: Array[RPGVehicle]
var current_map_events: Dictionary[int, IngameEvent]
var current_map_extraction_events: Dictionary[int, IngameExtractionEvent]

var is_on_battle: bool = false
var current_battle_scene # TODO
var battle_last_actions: BattleLastActions

var message: DialogBase
var message_container: CanvasLayer
var over_message_layer: CanvasLayer
var options_layer: CanvasLayer
var gui_canvas_layer: CanvasLayer

var controller: KeyController
var key_delay: float = 0.0
var last_key_pressed: String
var last_key_echo: bool

var current_timer: float
var loading_game: bool = false
var cancel_actors_initialize: bool = false
var current_save_slot: int = -1
var interpreter_last_scene_created: Node

var current_animations: Array = []
var animation_pool: Array = []

@warning_ignore("unused_private_class_variable")
var _test_commands_processed: bool = false
@warning_ignore("unused_private_class_variable")
var _transfer_direction: int = -1

var inventory_manager: InventoryManager
var cursor_manager: CursorManager
var extraction_manager: ExtractionManager
var format_manager: FormatManager
var actor_stats_manager: ActorStatsManager
var dynamic_asset_manager: DynamicAssetManager
var gui_manager: GUIManager
var options_manager: OptionsManager
var text_manager: TextManager
var timer_manager: TimerManager
var input_manager: InputManager
var menu_manager: MenuManager
var toast_manager: ToastManager

var hand_cursor_path: String = "res://Scenes/GUI/default_hand_cursor.tscn"
#endregion


#region Virtual Properties
var hand_cursor: MainHandCursor:
	get: return cursor_manager.hand_cursor if cursor_manager else null
	set(value): if cursor_manager: cursor_manager.hand_cursor = value

var backup_hand_data: Array:
	get: return cursor_manager.backup_hand_data if cursor_manager else []
	set(value): if cursor_manager: cursor_manager.backup_hand_data = value

#var over_flow_bag: Array:
	#get: return inventory_manager.over_flow_bag if inventory_manager else []
	#set(value): if inventory_manager: inventory_manager.over_flow_bag = value
#
#var create_over_flow_bag: bool:
	#get: return inventory_manager.create_over_flow_bag if inventory_manager else false
	#set(value): if inventory_manager: inventory_manager.create_over_flow_bag = value

var temporally_popup_disabled: bool:
	get: return gui_manager.temporally_popup_disabled if gui_manager else false
	set(value): if gui_manager: gui_manager.temporally_popup_disabled = value

var main_menu: Control:
	get: return menu_manager.main_menu if menu_manager else null
	set(value): if menu_manager: menu_manager.main_menu = value

var starting_menu: SCENE_TITTLE:
	get: return menu_manager.starting_menu if menu_manager else null
	set(value): if menu_manager: menu_manager.starting_menu = value
#endregion


#region Signals
signal timer_ended
#endregion


#region Core Lifecycle
func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_process_input(false)
	else:
		inventory_manager = InventoryManager.new()
		inventory_manager.name = "InventoryManager"
		add_child(inventory_manager)
		
		cursor_manager = CursorManager.new()
		cursor_manager.name = "CursorManager"
		cursor_manager.hand_cursor_path = hand_cursor_path
		add_child(cursor_manager)
		
		extraction_manager = ExtractionManager.new()
		extraction_manager.name = "ExtractionManager"
		add_child(extraction_manager)
		
		format_manager = FormatManager.new()
		format_manager.name = "FormatManager"
		add_child(format_manager)
		
		actor_stats_manager = ActorStatsManager.new()
		actor_stats_manager.name = "ActorStatsManager"
		add_child(actor_stats_manager)
		
		dynamic_asset_manager = DynamicAssetManager.new()
		dynamic_asset_manager.name = "DynamicAssetManager"
		add_child(dynamic_asset_manager)
		
		gui_manager = GUIManager.new()
		gui_manager.name = "GUIManager"
		add_child(gui_manager)
		
		options_manager = OptionsManager.new()
		options_manager.name = "OptionsManager"
		add_child(options_manager)
		
		text_manager = TextManager.new()
		text_manager.name = "TextManager"
		add_child(text_manager)
		
		timer_manager = TimerManager.new()
		timer_manager.name = "TimerManager"
		add_child(timer_manager)
		
		input_manager = InputManager.new()
		input_manager.name = "InputManager"
		add_child(input_manager)
		
		menu_manager = MenuManager.new()
		menu_manager.name = "MenuManager"
		add_child(menu_manager)
		
		toast_manager = ToastManager.new()
		toast_manager.name = "ToastManager"
		add_child(toast_manager)
		
		controller = KeyController.new()

		set_process(true)
		set_process_input(true)


func exit() -> void:
	get_tree().quit()


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	if input_manager:
		input_manager.update_input(delta)
	
	if ControllerManager.is_action_just_pressed("FullScreen"):
		if options_manager: options_manager.toggle_fullscreen()
		get_viewport().set_input_as_handled()
	
	if not game_state: return

	if current_timer > 0:
		current_timer -= delta
		if current_timer <= 0:
			current_timer = 0
			emit_signal("timer_ended")
	
	_refresh_play_time(delta)
	
	#if create_over_flow_bag and over_flow_bag.size() > 0:
		#if current_player:
			#_spawn_overflow_bag(current_player.global_position, over_flow_bag)
		#over_flow_bag.clear()
		#create_over_flow_bag = false

	if ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]) and not busy and !get_cursor_manipulator():
		get_viewport().set_input_as_handled()
		call_deferred("show_menu")
#endregion


#region Global State & Progression
func _spawn_overflow_bag(_bag_position, _bag_items) -> void:
	pass


func _refresh_play_time(delta: float) -> void:
	if game_state:
		game_state.stats.play_time += delta


func update_data(value: Variant, type: String, index: int) -> void:
	if type in game_state:
		var data = game_state[type]
		if data and data.size() > index:
			data[index] = value
			if current_map:
				current_map.need_refresh = true


func get_switch(id: int) -> bool:
	if game_state and game_state.game_switches.size() > id:
		return game_state.game_switches[id]
	return false


func set_switch_variable(from: int, to: int, value: bool) -> void:
	if game_state:
		var switches = GameManager.game_state.game_switches
		for i in range(from, to + 1, 1):
			if switches.size() > i:
				switches[i] = 1 if value else 0
		GameManager.current_map.need_refresh = true


func get_variable(id: int) -> int:
	if game_state and game_state.game_variables.size() > id:
		return game_state.game_variables[id]
	return 0


func set_variable(from: int, to: int, operation_type: int, target_value: float) -> void:
	if game_state:
		var variables = GameManager.game_state.game_variables
		for i in range(from, to + 1, 1):
			if variables.size() > i:
				match operation_type:
					0: variables[i] = target_value
					1: variables[i] += target_value
					2: variables[i] -= target_value
					3: variables[i] *= target_value
					4: variables[i] /= target_value
					5: variables[i] = fmod(variables[i], target_value)
		GameManager.current_map.need_refresh = true


func get_text_variable(id: int) -> String:
	if game_state and game_state.game_text_variables.size() > id:
		return game_state.game_text_variables[id]
	return ""


func set_text_variable(id: int, value: String, operation: int = 0, replace_text = "") -> void:
	var variables = game_state.game_text_variables
	if game_state and variables.size() > id:
		match operation:
			0: # Set
				variables[id] = value
			1: # Add
				variables[id] = variables[id] + value
			_: # Replace
				variables[id] = variables[id].replace(value, replace_text)


func get_local_switch(switch_id: int, target: int) -> bool:
	if game_state and current_map:
		if target == 0 and GameInterpreter.current_event:
			target = GameInterpreter.current_event._uniq_id
		
		if target != 0:
			var switch_key = "%s_%s_%s" % [current_map.internal_id, target, switch_id]
			return game_state.game_self_switches.get(switch_key, false)
			
	return false


func set_local_switch(switch_id: int, value: bool, target: int = 0) -> void:
	if GameManager.current_map:
		var map_id = GameManager.current_map.internal_id
		var switch_name = RPGSYSTEM.system.self_switches.get_self_switch_name(switch_id)
		if switch_name:
			if target == 0 and GameInterpreter.current_event:
				target = GameInterpreter.current_event._uniq_id
			
			if target != 0:
				var switch_key = "%s_%s_%s" % [map_id, target, switch_id]
				GameManager.game_state.game_self_switches[switch_key] = value
				GameManager.current_map.need_refresh = true


func is_item_in_possesion(item_type, item_id) -> bool:
	if game_state:
		match item_type:
			0:
				for obj in game_state.items:
					if obj.id == item_id: return true
			1:
				for obj in game_state.weapons:
					if obj.id == item_id: return true
			2:
				for obj in game_state.armors:
					if obj.id == item_id: return true
	return false


func load_game(slot_id: int) -> void:
	if not main_scene: return
	var game_data: RPGSavedGameData = SaveLoadManager.load_game(slot_id)
	if game_data:
		main_scene.load_game(game_data)
#endregion


#region UI, Menus & Shops
## Performs a hard reset of the game state and recreates the main scene to return to the title.
func restart() -> void:
	if GameManager.hand_cursor and not GameManager.hand_cursor.is_ancestor_of(self):
		GameManager.hand_cursor.reparent(self)
		
	force_hide_cursor()
		
	busy = true
	var viewport_img = get_viewport().get_texture().get_image()
	var static_tex = ImageTexture.create_from_image(viewport_img)
	
	var overlay_canvas = CanvasLayer.new()
	overlay_canvas.layer = 128
	
	var bg_rect = ColorRect.new()
	bg_rect.color = Color.BLACK
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var overlay_rect = TextureRect.new()
	overlay_rect.texture = static_tex
	overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	overlay_canvas.add_child(bg_rect)
	overlay_canvas.add_child(overlay_rect)
	overlay_canvas.add_child(fade_rect)
	get_tree().root.add_child(overlay_canvas)
	
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(fade_rect, "color:a", 1.0, 0.4)
	if main_scene and is_instance_valid(main_scene):
		if main_scene.has_method("stop_bgm"): main_scene.stop_bgm(0.3)
		if main_scene.has_method("stop_bgs"): main_scene.stop_bgs(0.3)
		if main_scene.has_method("stop_se"): main_scene.stop_se()
	await fade_out_tween.finished
	
	overlay_rect.visible = false
	
	game_started = false
	GameInterpreter.clear()
	
	if main_scene and is_instance_valid(main_scene):
		main_scene.get_parent().remove_child(main_scene)
		main_scene.queue_free()
		
	main_scene = null
	current_map = null
	current_player = null
	game_state = null
	
	await get_tree().process_frame
	
	var node = preload("res://Scenes/main_scene.tscn")
	var ins = node.instantiate()
	ins.initialize_title_scene = true
	get_tree().root.add_child(ins)
	
	for i in range(5):
		await get_tree().process_frame
		
	overlay_canvas.queue_free()
	busy = false


func add_shop_timer(shop_id: String, shop_timer: float, stock_data: Dictionary = {}) -> RPGShopTimer:
	if game_state:
		game_state.active_shop_timers[shop_id] = RPGShopTimer.new(shop_id, shop_timer, stock_data)
		return game_state.active_shop_timers[shop_id]
	return null


func get_shop_timer(shop_id: String) -> RPGShopTimer:
	if game_state and shop_id in game_state.active_shop_timers:
		return game_state.active_shop_timers[shop_id]
	return null
#endregion


#region Map & Events
func get_ingame_events() -> Array[IngameEvent]:
	if current_map: return current_map.get_in_game_events()
	return []


func get_in_game_event_by_id(id: int) -> Variant:
	if current_map:
		return current_map.get_in_game_event_by_id(id)
	return null


func get_in_game_event_by_uniq_id(uniq_id: int, return_ingame_event: bool = false) -> Variant:
	if current_map:
		return current_map.get_in_game_event_by_uniq_id(uniq_id, return_ingame_event)
	return null


func get_event_relationship_level(event_id: int) -> int:
	var result = 0
	if current_map:
		var ingame_event = current_map.get_in_game_event(event_id)
		if ingame_event:
			var relationship: GameRelationship = ingame_event.relationship
			result = relationship.current_level
	return result
#endregion


#region Followers & Characters
func get_followers() -> Array:
	return get_tree().get_nodes_in_group("follower")


func show_followers(value: bool, instant: bool = false) -> void:
	if not game_state:
		return
		
	game_state.followers_enabled = value
	
	if main_scene:
		main_scene.process_follower_command("show", value, instant)


func disappear_followers(time: float = 0.5, reset_followers_tracking: bool = false) -> void:
	if main_scene: main_scene.process_follower_command("disappear")
	if current_player and current_player.has_method("clear_movement_history"):
		current_player.clear_movement_history()
	var followers = get_followers()
	if followers:
		for follower in followers:
			follower.disappear(time)
	if reset_followers_tracking:
		await get_tree().create_timer(time).timeout
		disable_followers_tracking(0.0)


func appear_followers() -> void:
	if main_scene: main_scene.process_follower_command("appear")
	if current_player and current_player.has_method("clear_movement_history"):
		current_player.clear_movement_history()
	var followers = get_followers()
	if followers and followers.size() > 0:
		for i in followers.size():
			followers[i].appear()


func regroup_followers(time: float = 0.6, remove_followers: bool = false) -> void:
	if main_scene: main_scene.process_follower_command("regroup", time, remove_followers)


func disable_followers_tracking(time: float = 0.5) -> void:
	if game_state: game_state.followers_tracking_enabled = false
	if main_scene:
		main_scene.process_follower_command("disable_tracking", time)


func shift_up_follower() -> void:
	if main_scene: await main_scene.process_follower_command("shift_up")


func shift_down_follower() -> void:
	if main_scene: await main_scene.process_follower_command("shift_down")


func destroy_followers() -> void:
	if main_scene: main_scene.process_follower_command("destroy")
	if current_player and current_player.has_method("clear_movement_history"):
		current_player.clear_movement_history()
	var followers = get_tree().get_nodes_in_group("follower")
	if followers:
		for follower in followers:
			follower.destroy()


func update_character_graphics(node: Node, new_player_id: int) -> void:
	if node and new_player_id > 0 and RPGSYSTEM.database.actors.size() > new_player_id:
		if not "current_data" in node: return
		var actor = RPGSYSTEM.database.actors[new_player_id]
		var scene_path = actor.character_data_file
		if AssetManager.exists(scene_path):
			current_player.set_meta("actor_id", new_player_id)
			current_player.set_meta("party_id", 0)
			var scene_data: RPGLPCCharacter = load(scene_path)
			current_player.set_data(scene_data)


func set_combat_experience_mode_leader(type: int) -> void:
	if game_state: game_state.experience_mode = type
#endregion


#region Main Scene Wrappers
func get_main_scene() -> MainScene:
	if main_scene: return main_scene
	return null


func get_map_tile_size() -> Vector2i:
	if current_map: return current_map.tile_size
	return Vector2i.ZERO


func get_camera() -> Camera2D:
	if main_scene: return main_scene.get_node("%MainCamera")
	return get_viewport().get_camera_2d()


func camera_past_reposition() -> void:
	var camera: Camera2D = get_camera()
	if camera: camera.fast_reposition.call_deferred()


func get_camera_zoom() -> Vector2:
	var camera: Camera2D = get_camera()
	if camera: return camera.zoom
	return Vector2.ONE


func get_screen_effect_canvas() -> CanvasLayer:
	if main_scene: return main_scene.get_screen_effect_canvas()
	return null


func get_secondary_transition_node() -> ColorRect:
	if main_scene: return main_scene.get_secondary_transition_node()
	return null


func get_transition_manager() -> Control:
	if main_scene: return main_scene.transition_manager
	return null


func get_dynamic_shadows_from_main_scene() -> Node2D:
	if main_scene: return main_scene.get_dynamic_shadows_node()
	return null


func get_character_baker() -> CharacterBaker:
	if main_scene: return main_scene.get_character_baker()
	return null


func get_main_interpreter() -> MainInterpreter:
	if main_scene: return main_scene.get_main_interpreter()
	return null


func get_main_scene_texture() -> Texture:
	if main_scene: return main_scene.get_main_scene_texture()
	return null


func get_fx_path(id: Variant) -> String:
	if main_scene: return main_scene.get_fx_path(id)
	return ""


func get_canvas_modulate_color() -> Color:
	if main_scene: return main_scene.get_canvas_modulate_color()
	return Color.WHITE


func set_canvas_modulate_color(color: Color) -> void:
	if main_scene: main_scene.set_canvas_modulate_color(color)


func set_map_color(color: Color) -> void:
	if main_scene: main_scene.set_map_color(color)


func set_tint_color(color: Color, duration: float) -> void:
	if main_scene: main_scene.set_tint_color(color, duration)


func remove_tint_color(duration: float) -> void:
	if main_scene: main_scene.remove_tint_color(duration)


func set_day_color(color: Color) -> void:
	if main_scene: main_scene.set_day_color(color)


func set_weather_color(color: Color, duration: float) -> void:
	if main_scene: main_scene.set_weather_color(color, duration)


func set_weather_flash(color: Color, duration: float) -> void:
	if main_scene: main_scene.set_weather_flash(color, duration)


func remove_weather_color(duration: float) -> void:
	if main_scene: main_scene.remove_weather_color(duration)


func setup_gui_scene(scene: Node) -> void:
	if main_scene: main_scene._setup_gui_scene(scene)


func change_scene(path: String, destroy_gui: bool = false) -> void:
	if main_scene: main_scene.change_scene(path, destroy_gui)


func clear_map_repeating() -> void:
	if main_scene: main_scene.clear_map_repeating()


func enable_map_repeating() -> void:
	if main_scene: main_scene.enable_map_repeating()


func play_music(id: Variant) -> void:
	if main_scene: main_scene.play_music(id)


func play_video(path: String, loop: bool = false, fade_out_time: float = 0.0) -> VideoStreamPlayer:
	if main_scene: return main_scene.play_video(path, loop, fade_out_time)
	return null


func set_fx_busy(value: bool) -> void:
	if main_scene: main_scene.fx_busy = value


func play_fx(id: Variant) -> void:
	if main_scene: main_scene.play_fx(id)


func play_me(me: Variant, volume: float = 0.0, pitch: float = 1.0) -> void:
	if main_scene: main_scene.play_me(me, volume, pitch)


func play_se(fx: Variant, volume: float = 0.0, pitch: float = 1.0) -> void:
	if main_scene: main_scene.play_se(fx, volume, pitch)


func save_bgm() -> void:
	if main_scene: main_scene.save_bgm()


func restore_bgm() -> void:
	if main_scene: main_scene.restore_bgm()


func play_bgm(bgm: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	if main_scene: main_scene.play_bgm(bgm, volume, pitch, fade_duration)


func play_bgs(bgs: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	if main_scene: main_scene.play_bgs(bgs, volume, pitch, fade_duration)


func stop_bgm(fade_duration: float = 0) -> void:
	if main_scene: main_scene.stop_bgm(fade_duration)


func stop_bgs(fade_duration: float = 0) -> void:
	if main_scene: main_scene.stop_bgs(fade_duration)


func stop_se() -> void:
	if main_scene: main_scene.stop_se()


func stop_video() -> void:
	if main_scene: main_scene.stop_video()
#endregion


#region OptionsManager Wrappers
func set_options(options: RPGGameOptions) -> void:
	if options_manager: options_manager.set_options(options)
#endregion


#region TextManager Wrappers
func get_font_data() -> Dictionary:
	if text_manager: return text_manager.get_font_data()
	return {}


func set_text_config(node: Node, set_outline: bool = true, set_shadow: bool = true) -> void:
	if text_manager: text_manager.set_text_config(node, set_outline, set_shadow)
#endregion


#region InputManager Wrappers
func is_key_pressed(keys: Variant, allow_echo: bool = true) -> bool:
	if input_manager: return input_manager.is_key_pressed(keys, allow_echo)
	return false



func add_key_callback(key: String, callable: Callable, allow_echo: bool = true, id: Variant = null) -> void:
	if input_manager: input_manager.add_key_callback(key, callable, allow_echo, id)



func remove_key_callback(id: Variant) -> void:
	if input_manager: input_manager.remove_key_callback(id)



func get_last_key_pressed() -> String:
	if input_manager: return input_manager.get_last_key_pressed()
	return ""
#endregion


#region MenuManager Wrappers
func show_menu() -> void:
	if menu_manager: menu_manager.show_menu()


func show_save_menu(hide_load: bool = true) -> void:
	if menu_manager: await menu_manager.show_save_menu(hide_load)


func create_main_menu() -> void:
	if menu_manager: menu_manager.create_main_menu()


func get_items(include_hidden_items: bool = false, sort_mode: int = 0, collection: int = 0) -> Array:
	if inventory_manager: return inventory_manager.get_items(include_hidden_items, sort_mode, collection)
	return []


func get_skills_for_actor(actor: GameActor, sort_mode: int = 0) -> Array:
	if actor_stats_manager: return actor_stats_manager.get_skills_for_actor(actor, sort_mode)
	return []
#endregion


#region TimerManager Wrappers
func manage_timer(config: Dictionary) -> void:
	if timer_manager: timer_manager.manage_timer(config)


func update_timer_time(timer_id: int, value: float) -> void:
	if timer_manager: timer_manager.update_timer_time(timer_id, value)
#endregion


#region InventoryManager Wrappers
func get_item_amount(id: int) -> int:
	if inventory_manager: return inventory_manager.get_item_amount(id)
	return 0


func add_item_amount(id: int, amount: int, auto_popup_enabled: bool = false, popup_prefix: String = "") -> int:
	if inventory_manager: return inventory_manager.add_item_amount(id, amount, auto_popup_enabled, popup_prefix)
	return 0


func remove_item_amount(id: int, amount: int) -> void:
	if inventory_manager: inventory_manager.remove_item_amount(id, amount)


func get_weapon_amount(id: int) -> int:
	if inventory_manager: return inventory_manager.get_weapon_amount(id)
	return 0


func add_weapon_amount(id: int, amount: int, level: int = 1, auto_popup_enabled: bool = false, popup_prefix: String = "", _item_level: int = -1) -> int:
	if inventory_manager: return inventory_manager.add_weapon_amount(id, amount, level, auto_popup_enabled, popup_prefix, _item_level)
	return 0


func remove_weapon_amount(id: int, amount: int, include_equipment: bool) -> void:
	if inventory_manager: inventory_manager.remove_weapon_amount(id, amount, include_equipment)


func get_armor_amount(id: int) -> int:
	if inventory_manager: return inventory_manager.get_armor_amount(id)
	return 0


func add_armor_amount(id: int, amount: int, level: int = 1, auto_popup_enabled: bool = false, popup_prefix: String = "") -> int:
	if inventory_manager: return inventory_manager.add_armor_amount(id, amount, level, auto_popup_enabled, popup_prefix)
	return 0


func remove_armor_amount(id: int, amount: int, include_equipment: bool) -> void:
	if inventory_manager: inventory_manager.remove_armor_amount(id, amount, include_equipment)
#endregion


#region CursorManager Wrappers
func manage_cursor(node: Variant, offset: Vector2 = Vector2.ZERO) -> void:
	if cursor_manager: cursor_manager.manage_cursor(node, offset)


func show_cursor(hand_position: MainHandCursor.HandPosition = MainHandCursor.HandPosition.LEFT, manipulator_context: Variant = null, default_offset: Vector2 = Vector2.ZERO) -> void:
	if cursor_manager: cursor_manager.show_cursor(hand_position, manipulator_context, default_offset)


func force_show_cursor() -> void:
	if cursor_manager: cursor_manager.force_show_cursor()


func force_hide_cursor() -> void:
	if cursor_manager: cursor_manager.force_hide_cursor()


func hide_cursor(instant_hide: bool = false, manipulator_context: Variant = null) -> void:
	if cursor_manager: cursor_manager.hide_cursor(instant_hide, manipulator_context)


func get_hand_style() -> MainHandCursor.HandPosition:
	if cursor_manager: return cursor_manager.get_hand_style()
	return MainHandCursor.HandPosition.LEFT


func set_focusable_control_threshold(horizontal: int = 30, vertical: int = 30):
	ControllerManager.set_focusable_control_threshold(horizontal, vertical)


func set_cursor_manipulator(manipulator_context: Variant = null, reset_control_threshold: bool = true) -> void:
	if cursor_manager: cursor_manager.set_cursor_manipulator(manipulator_context)
	if reset_control_threshold:
		set_focusable_control_threshold(30, 30)


func get_cursor_manipulator() -> Variant:
	if cursor_manager: return cursor_manager.get_cursor_manipulator()
	return ""


func set_hand_properties(
	current_hand_position: MainHandCursor.HandPosition = MainHandCursor.HandPosition.LEFT,
	hand_offset: Vector2 = Vector2.ZERO,
	confined_area: Rect2 = Rect2(),
	manipulator_context: Variant = null) -> void:
	if cursor_manager: cursor_manager.set_hand_properties(current_hand_position, hand_offset, confined_area, manipulator_context)


func backup_hand_properties() -> void:
	if cursor_manager: cursor_manager.backup_hand_properties()


func restore_hand_properties() -> void:
	if cursor_manager: cursor_manager.restore_hand_properties()


func set_confin_area(area: Rect2, manipulator_context: Variant = null) -> void:
	if cursor_manager: cursor_manager.set_confin_area(area, manipulator_context)


func set_hand_position(hand_position: MainHandCursor.HandPosition = MainHandCursor.HandPosition.LEFT, manipulator_context: Variant = null) -> void:
	if cursor_manager: cursor_manager.set_hand_position(hand_position, manipulator_context)


func force_hand_position_over_node(manipulator_context: Variant = null) -> void:
	if cursor_manager: cursor_manager.force_hand_position_over_node(manipulator_context)


func get_cursor_position() -> Vector2:
	if cursor_manager: return cursor_manager.get_cursor_position()
	return Vector2.INF


func set_cursor_offset(offset: Vector2, manipulator_context: Variant = null) -> void:
	if cursor_manager: cursor_manager.set_cursor_offset(offset, manipulator_context)
#endregion


#region ExtractionManager Wrappers
func get_profession_level(profession: RPGProfession) -> int:
	if extraction_manager: return extraction_manager.get_profession_level(profession)
	return 0


func manage_extraction_scene(node: Node) -> void:
	if extraction_manager: extraction_manager.manage_extraction_scene(node)


func has_profession(profession_id: int) -> bool:
	if extraction_manager: return extraction_manager.has_profession(profession_id)
	return false


func add_profession_experience(event_data: RPGExtractionItem, experience: float) -> void:
	if extraction_manager: extraction_manager.add_profession_experience(event_data, experience)
#endregion


#region FormatManager Wrappers
func get_number_formatted(number: float, decimals: int = 0, prefix: String = "", suffix: String = "", force_zero_decimal: bool = false) -> String:
	if format_manager: return format_manager.get_number_formatted(number, decimals, prefix, suffix, force_zero_decimal)
	return str(number)


func format_time(total_seconds: float) -> String:
	if format_manager: return format_manager.format_time(total_seconds)
	return ""


func format_game_time(seconds: int, colon_visible: bool = true) -> String:
	if format_manager: return format_manager.format_game_time(seconds, colon_visible)
	return ""
#endregion


#region ActorStatsManager Wrappers
func get_actor_parameter(actor_id: int, parameter_id: String) -> int:
	if actor_stats_manager: return actor_stats_manager.get_actor_parameter(actor_id, parameter_id)
	return 0


func get_actor_user_parameter(actor_id: int, parameter_id: int) -> float:
	if actor_stats_manager: return actor_stats_manager.get_actor_user_parameter(actor_id, parameter_id)
	return 0.0


func get_global_user_parameter(parameter_id: int) -> float:
	if actor_stats_manager: return actor_stats_manager.get_global_user_parameter(parameter_id)
	return 0.0


func set_actor_parameter(actor: GameActor, parameter_id: String, operation: int, amount: int) -> void:
	if actor_stats_manager: actor_stats_manager.set_actor_parameter(actor, parameter_id, operation, amount)


func get_enemy_parameter(enemy_id: int, parameter_id: String) -> int:
	if actor_stats_manager: return actor_stats_manager.get_enemy_parameter(enemy_id, parameter_id)
	return 0


func get_weapon_parameter(weapon_id: int, parameter_id: String, weapon_level: int) -> int:
	if actor_stats_manager: return actor_stats_manager.get_weapon_parameter(weapon_id, parameter_id, weapon_level)
	return 0


func get_armor_parameter(armor_id: int, parameter_id: String, armor_level: int) -> int:
	if actor_stats_manager: return actor_stats_manager.get_armor_parameter(armor_id, parameter_id, armor_level)
	return 0


func is_actor_in_group(id: int) -> bool:
	if actor_stats_manager: return actor_stats_manager.is_actor_in_group(id)
	return false


func get_actor(id: int) -> GameActor:
	if actor_stats_manager: return actor_stats_manager.get_actor(id)
	return null


func get_actor_weapon(id: int) -> GameWeapon:
	if actor_stats_manager: return actor_stats_manager.get_actor_weapon(id)
	return null


func get_actor_weapon_db(id: int) -> RPGWeapon:
	if actor_stats_manager: return actor_stats_manager.get_actor_weapon_db(id)
	return null


func get_real_actor(id: int) -> RPGActor:
	if actor_stats_manager: return actor_stats_manager.get_real_actor(id)
	return null


func add_party_member(actor_id: int, initialize: bool = true) -> void:
	if actor_stats_manager: actor_stats_manager.add_party_member(actor_id, initialize)


func remove_party_member(actor_id: int) -> void:
	if actor_stats_manager: actor_stats_manager.remove_party_member(actor_id)


func change_formation(actor_id1: int, actor_id2: int) -> void:
	if actor_stats_manager: actor_stats_manager.change_formation(actor_id1, actor_id2)


func is_party_member_locked(actor_id: int) -> bool:
	if actor_stats_manager: return actor_stats_manager.is_party_member_locked(actor_id)
	return false


func change_leader(leader_id: int, is_locked: bool) -> void:
	if actor_stats_manager: actor_stats_manager.change_leader(leader_id, is_locked)
#endregion


#region DynamicAssetManager Wrappers
func create_image(type: int, index: int, image_path: String) -> GameImage:
	if dynamic_asset_manager: return dynamic_asset_manager.create_image(type, index, image_path)
	return null


func get_image(index: int) -> GameImage:
	if dynamic_asset_manager: return dynamic_asset_manager.get_image(index)
	return null


func remove_image(index: int) -> void:
	if dynamic_asset_manager: dynamic_asset_manager.remove_image(index)


func create_scene(index: int, scene_path: String, is_map_scene: bool = false) -> Node:
	if dynamic_asset_manager: return await dynamic_asset_manager.create_scene(index, scene_path, is_map_scene)
	return null


func get_scene(index: int) -> Node:
	if dynamic_asset_manager: return dynamic_asset_manager.get_scene(index)
	return null


func remove_scene(index: int) -> void:
	if dynamic_asset_manager: dynamic_asset_manager.remove_scene(index)


func get_scene_from_cache(cache_path: String, scene_path: String, type_required: String = "", cache_instance: bool = false) -> Node:
	if dynamic_asset_manager: return await dynamic_asset_manager.get_scene_from_cache(cache_path, scene_path, type_required, cache_instance)
	return null


func get_current_ingame_scenes() -> Array:
	if dynamic_asset_manager: return dynamic_asset_manager.current_ingame_scenes.values()
	
	return []


func get_current_ingame_images() -> Array:
	if dynamic_asset_manager: return dynamic_asset_manager.current_ingame_images.values()
	
	return []
#endregion


#region GUIManager Wrappers
func toast_message(_message: String, start_position: ToastManager.ToastPos = ToastManager.ToastPos.BOTTOM_RIGHT, target_node: Node = null, y_offset: float = 0.0) -> void:
	if toast_manager: toast_manager.show_message(_message, start_position, target_node, y_offset)


func toast_overflow_message(items, start_position: ToastManager.ToastPos = ToastManager.ToastPos.BOTTOM_RIGHT, target_node: Node = null, y_offset: float = 0.0) -> void:
	if toast_manager: toast_manager.show_overflow_error(items, start_position, target_node, y_offset)


func _create_popup_message(type: int, item_id: int, quantity: int, popup_prefix = "", level = -1) -> void:
	if gui_manager: gui_manager._create_popup_message(type, item_id, quantity, popup_prefix, level)


func show_popup_message(obj: Dictionary) -> void:
	if gui_manager: gui_manager.show_popup_message(obj)


func is_mouse_over_current_control_focused() -> bool:
	if gui_manager: return gui_manager.is_mouse_over_current_control_focused()
	return false
#endregion
