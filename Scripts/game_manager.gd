@tool
extends Node


class BattleLastActions:
	var last_used_skill: int = -1
	var last_used_item: int = -1
	var last_actor_to_act: int = -1
	var last_enemy_to_act: int = -1
	var last_actor_targeted: int = -1
	var last_enemy_targeted: int = -1


var game_started: bool = false
var main_scene: MainScene
var busy: bool
var database: RPGDATA
var game_state: GameUserData
var current_map: RPGMap
var current_battle
var current_player: LPCCharacter
var current_map_vehicles: Array[RPGVehicle]
var current_map_events: Dictionary[int, RPGMap.IngameEvent]
var current_map_extraction_events: Dictionary[int, RPGMap.IngameExtractionEvent]
var current_vehicle: RPGVehicle
var current_timer: float # Current timer value in seconds
var current_battle_scene # TODO
var message: DialogBase
var current_game_options: RPGGameOptions
var message_container: CanvasLayer
var over_message_layer: CanvasLayer
var options_layer: CanvasLayer
var gui_canvas_layer: CanvasLayer

var key_delay: float = 0.0
var last_key_pressed: String
var last_key_echo: bool

var controller: KeyController

var hand_cursor_path: String = "res://Scenes/GUI/default_hand_cursor.tscn"
var hand_cursor: MainHandCursor
var backup_hand_data: Array = []

var main_menu: Control

var battle_last_actions: BattleLastActions

var current_animations: Array = []
var animation_pool: Array = []

var current_ingame_images: Dictionary[int, GameImage] = {}
var current_ingame_scenes: Dictionary[int, Node] = {}

var sound_volume_mapping: VolumeMapping

var temporally_popup_disabled: bool = false

var over_flow_bag: Array = []
var create_over_flow_bag: bool = false

@warning_ignore("unused_private_class_variable")
var _test_commands_processed: bool = false
@warning_ignore("unused_private_class_variable")
var _transfer_direction: int = -1

var cancel_actors_initialize: bool = false

var current_save_slot: int = -1

var starting_menu: SCENE_TITTLE

var loading_game: bool = false
var interpreter_last_scene_created: Node

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
	"GUI_SCENE": "standard gui scene"
}

var scene_cache: Dictionary = {
	"messages": {},
	"shops": {},
	"main_menus": {},
	"items": {},
	"skills": {},
	"equipment": {},
	"status": {},
	"formation": {},
	"quests": {},
	"save_loads": {},
	"options": {},
	"game_ends": {},
}

const ANIMATE_POPUP = preload("res://Scenes/OtherScenes/animate_popup.tscn")
var last_animated_popup: Dictionary = {}

signal timer_ended


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_process_input(false)
	else:
		hand_cursor = load(hand_cursor_path).instantiate()
		add_child(hand_cursor)
		
		controller = KeyController.new()
		
		sound_volume_mapping = VolumeMapping.new()

		set_process(true)
		set_process_input(true)


func exit() -> void:
	get_tree().quit()


#region Cursor Manager
func manage_cursor(node: Variant, offset: Vector2 = Vector2.ZERO) -> void:
	set_cursor_manipulator(node)
	hide_cursor(false, node)
	set_cursor_offset(offset, node)
	tree_exiting.connect(
		func():
			hide_cursor(false, node)
			set_cursor_offset(Vector2.ZERO, node)
	)


func show_cursor(hand_position: MainHandCursor.HandPosition = MainHandCursor.HandPosition.LEFT, manipulator_context: Variant = null, default_offset: Vector2 = Vector2.ZERO) -> void:
	if hand_cursor:
		hand_cursor.show_cursor(hand_position, manipulator_context, default_offset)


func force_show_cursor() -> void:
	if hand_cursor:
		hand_cursor.force_show()


func force_hide_cursor() -> void:
	if hand_cursor:
		hand_cursor.force_hide()


func hide_cursor(instant_hide: bool = false, manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.hide_cursor(instant_hide, manipulator_context)


func get_hand_style() -> MainHandCursor.HandPosition:
	return hand_cursor.current_hand_position


func set_cursor_manipulator(manipulator_context: Variant = null) -> void:
	# must be called before show_cursor or hide_cursor methods
	if hand_cursor:
		hand_cursor.set_manipulator(manipulator_context)


func get_cursor_manipulator() -> Variant:
	# must be called before show_cursor or hide_cursor methods
	if hand_cursor:
		return hand_cursor.manipulator
	else:
		return ""


func set_hand_properties(
	current_hand_position: MainHandCursor.HandPosition = MainHandCursor.HandPosition.LEFT,
	hand_offset: Vector2 = Vector2.ZERO,
	confined_area: Rect2 = Rect2(),
	manipulator_context: Variant = null) -> void:
	hand_cursor.manipulator = manipulator_context
	hand_cursor.hand_offset = hand_offset
	hand_cursor.confined_area = confined_area
	hand_cursor.current_hand_position = current_hand_position


func backup_hand_properties() -> void:
	backup_hand_data.append({
		"manipulator": hand_cursor.manipulator,
		"hand_offset": hand_cursor.hand_offset,
		"confined_area": hand_cursor.confined_area,
		"current_hand_position": hand_cursor.current_hand_position
	})


func restore_hand_properties() -> void:
	if backup_hand_data and not backup_hand_data.is_empty():
		var hand_data = backup_hand_data.pop_back()
		hand_cursor.manipulator = hand_data.manipulator
		hand_cursor.hand_offset = hand_data.hand_offset
		hand_cursor.confined_area = hand_data.confined_area
		hand_cursor.current_hand_position = hand_data.current_hand_position


func set_confin_area(area: Rect2, manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.set_confin_area(area, manipulator_context)


func set_hand_position(hand_position: MainHandCursor.HandPosition = MainHandCursor.HandPosition.LEFT, _manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.current_hand_position = hand_position


func force_hand_position_over_node(manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.force_hand_position_over_node(manipulator_context)


func get_cursor_position() -> Vector2:
	if hand_cursor:
		return hand_cursor.get_cursor_position()
	else:
		return Vector2.INF


func set_cursor_offset(offset: Vector2, manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.set_cursor_offset(offset, manipulator_context)
#endregion


func set_options(options: RPGGameOptions) -> void:
	current_game_options = options
	
	# set language:
	TranslationServer.set_locale(options.language)
	
	# Limit fps
	
	Engine.set_max_fps(options.max_fps)
	
	# Set audio bus volumes
	sound_volume_mapping.set_volume_from_slider(AudioServer.get_bus_index("Master"), options.sound_master)
	sound_volume_mapping.set_volume_from_slider(AudioServer.get_bus_index("BGM"), options.sound_music)
	sound_volume_mapping.set_volume_from_slider(AudioServer.get_bus_index("SE"), options.sound_fx)
	sound_volume_mapping.set_volume_from_slider(AudioServer.get_bus_index("Ambient"), options.sound_ambient)
	
	# Set vsync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if options.vsync
		else DisplayServer.VSYNC_DISABLED
	)
	
	# Set fullscreen
	if DisplayServer.window_get_mode() != (DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN if options.fullscreen else DisplayServer.WindowMode.WINDOW_MODE_WINDOWED):
		if not Engine.is_embedded_in_editor():
			DisplayServer.window_set_mode(
				DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN if options.fullscreen
				else DisplayServer.WindowMode.WINDOW_MODE_WINDOWED
			)
	
	# set brightness
	if main_scene:
		main_scene.set_canvas_modulate_color(main_scene.get_canvas_modulate_color())
	if starting_menu:
		starting_menu.set_brightness()


func get_font_data() -> Dictionary:
	var config: Dictionary
	var font_data: Dictionary = {}
	if game_state:
		config = game_state.current_message_config
	else:
		config = RPGSYSTEM.database.system.default_message_config
	var font_path = config.get("font", "res://addons/CustomControls/Resources/Fontsunifont-13.0.01.ttf")
	if ResourceLoader.exists(font_path):
		font_data.font = load(font_path)
	else:
		font_data.font = null
	font_data.text_size = config.get("text_size", 22)
	font_data.outline_size = config.get("outline", 8)
	font_data.outline_color = config.get("outline_color", Color.BLACK)
	font_data.shadow_offset = config.get("shadow_offset", Vector2.ZERO)
	font_data.shadow_color = config.get("shadow_color", Color(0, 0, 0, 0.5765))
	
	return font_data


func set_text_config(node: Node, set_outline: bool = true, set_shadow: bool = true) -> void:
	var config = get_font_data()
	
	if config.font:
		node.propagate_call("set", ["theme_override_fonts/font", config.font])
		node.propagate_call("set", ["theme_override_fonts/normal_font", config.font])
		
	if set_outline:
		node.propagate_call("set", ["theme_override_constants/outline_size", config.outline_size])
		node.propagate_call("set", ["theme_override_colors/font_outline_color", config.outline_color])
		
	if set_shadow:
		node.propagate_call("set", ["theme_override_constants/shadow_offset_x", config.shadow_offset.x])
		node.propagate_call("set", ["theme_override_constants/shadow_offset_y", config.shadow_offset.y])
		node.propagate_call("set", ["theme_override_colors/font_shadow_color", config.shadow_color])


func is_key_pressed(keys: Variant, allow_echo: bool = true) -> bool:
	var keys_array = []
	if keys is String:
		keys_array = [keys]
	elif keys is Array:
		keys_array = keys
	else:
		return false

	if controller:
		return controller.is_any_key_pressed(keys_array, allow_echo)
	else:
		return false


func add_key_callback(key: String, callable: Callable, allow_echo: bool = true, id: Variant = null) -> void:
	if controller:
		controller.register_key(key, callable, allow_echo, id)


func remove_key_callback(id: Variant) -> void:
	controller.unregister_key_by_id(id)


func get_last_key_pressed() -> String:
	if controller:
		return controller.current_action_pressed
	else:
		return ""


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	if controller:
		controller.update(delta)
	
	hand_cursor.update(delta)
	
	if ControllerManager.is_action_just_pressed("FullScreen"):
		if not Engine.is_embedded_in_editor():
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				if GameManager.current_game_options:
					GameManager.current_game_options.fullscreen = false
					_save_options()
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				if GameManager.current_game_options:
					GameManager.current_game_options.fullscreen = true
					_save_options()
			get_viewport().set_input_as_handled()
		else:
			printerr("Cannot maximize the screen when running the game embedded in the editor")
		get_viewport().set_input_as_handled()
	
	if not game_state: return

	if current_timer > 0:
		current_timer -= delta
		if current_timer <= 0:
			current_timer = 0
			emit_signal("timer_ended")
	
	_refresh_play_time(delta)
	
	if create_over_flow_bag and over_flow_bag.size() > 0:
		if current_player:
			_spawn_overflow_bag(current_player.global_position, over_flow_bag)
		over_flow_bag.clear()
		create_over_flow_bag = false

	if ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]) and not busy and !GameManager.get_cursor_manipulator():
		get_viewport().set_input_as_handled()
		call_deferred("show_menu")


func _spawn_overflow_bag(_bag_position, _bag_items) -> void:
	pass


func _refresh_play_time(delta: float) -> void:
	if game_state:
		game_state.stats.play_time += delta


func _save_options() -> void:
	if GameManager.current_game_options:
		var save_path = "user://game_options.res"
		ResourceSaver.save(GameManager.current_game_options, save_path)


func update_data(value: Variant, type: String, index: int) -> void:
	print(value)
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


func get_variable(id: int) -> int:
	if game_state and game_state.game_variables.size() > id:
		return game_state.game_variables[id]
	
	return 0


func get_text_variable(id: int) -> String:
	if game_state and game_state.game_text_variables.size() > id:
		return game_state.game_text_variables[id]
	
	return ""


func get_item_amount(id: int) -> int:
	var quantity: int = 0
	if game_state.items.has(id):
		for item: GameItem in game_state.items[id]:
			quantity += item.quantity
	
	return quantity


func create_image(type: int, index: int, image_path: String) -> GameImage:
	if ResourceLoader.exists(image_path):
		var target: Node = current_map if type == 0 else null if not main_scene else main_scene.get_image_container()
		if target:
			var img = GameImage.new(index, image_path)
			target.add_child(img)
			if index in current_ingame_images:
				current_ingame_images[index].queue_free()
			current_ingame_images[index] = img
			return img
	
	return null


func get_image(index: int) -> GameImage:
	return current_ingame_images.get(index, null)


func remove_image(index: int) -> void:
	if index in current_ingame_images:
		if is_instance_valid(current_ingame_images[index]):
			current_ingame_images[index].end()
		current_ingame_images.erase(index)


func create_scene(index: int, scene_path: String, is_map_scene: bool = false) -> Node:
	if ResourceLoader.exists(scene_path) and main_scene:
		var target: Node
		if current_map and is_map_scene:
			target = current_map
		else:
			target = main_scene.get_scene_container()
		if target:
			if index in current_ingame_scenes:
				current_ingame_scenes[index].queue_free()
				current_ingame_scenes.erase(index)
				await get_tree().process_frame
			await get_tree().process_frame
			var scn = load(scene_path).instantiate()
			target.add_child(scn)
			current_ingame_scenes[index] = scn
			return scn
	
	return null


func get_scene(index: int) -> Node:
	return current_ingame_scenes.get(index, null)


func get_scene_from_cache(cache_path: String, scene_path: String, type_required: String = "", cache_instance: bool = false) -> Node:
	var ins
	var current_cache_files
	
	if cache_path.is_empty():
		if not "other_scenes" in scene_cache:
			scene_cache["other_scenes"] = {}
		current_cache_files = scene_cache["other_scenes"]
	else:
		if not cache_path in scene_cache:
			scene_cache[cache_path] = {}
		current_cache_files = scene_cache[cache_path]

	if ResourceLoader.exists(scene_path):
		if scene_path in current_cache_files:
			if is_instance_valid(current_cache_files[scene_path]):
				if current_cache_files[scene_path] is PackedScene:
					ins = current_cache_files[scene_path].instantiate()
				else:
					ins = current_cache_files[scene_path]
			elif ResourceLoader.exists(scene_path):
				var scn = ResourceLoader.load(scene_path)
				ins = scn.instantiate()
			
		else:
			var scn
			if scene_path in RPGSYSTEM.database.system.preload_scenes:
				while ResourceLoader.load_threaded_get_status(scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
					if is_inside_tree():
						await get_tree().process_frame
					break
				if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
					scn = ResourceLoader.load_threaded_get(scene_path)
						
			if not scn:
				scn = load(scene_path)
			ins = scn.instantiate()
			if type_required.is_empty() or ins.get_class() == type_required:
				if not cache_instance:
					current_cache_files[scene_path] = scn
				else:
					current_cache_files[scene_path] = ins
			else:
				ins.queue_free()
				ins = null
	
	return ins


func get_camera() -> Camera2D:
	if main_scene:
		return main_scene.get_node("%MainCamera")
	else:
		return get_viewport().get_camera_2d()


func camera_past_reposition() -> void:
	var camera: Camera2D = get_camera()
	if camera:
		camera.fast_reposition.call_deferred()


func get_camera_zoom() -> Vector2:
	var camera: Camera2D = get_camera()
	if camera:
		return camera.zoom
		
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


func remove_scene(index: int) -> void:
	if index in current_ingame_scenes:
		if is_instance_valid(current_ingame_scenes[index]):
			current_ingame_scenes[index].queue_free()
		current_ingame_scenes.erase(index)


## Helper function to count total used slots across all inventories
func _get_total_used_slots() -> int:
	var total = 0
	
	# Count items
	for item_list in game_state.items.values():
		total += item_list.size()
	
	# Count weapons
	for weapon_list in game_state.weapons.values():
		total += weapon_list.size()
	
	# Count armors
	for armor_list in game_state.armors.values():
		total += armor_list.size()
	
	return total


# Helper function to calculate how many slots are needed for a given amount
func _calculate_slots_needed(amount: int, max_per_stack: int) -> int:
	if max_per_stack <= 0: # No stack limit
		return 1
	return int(ceil(float(amount) / float(max_per_stack)))


# Helper function to split amount into stacks based on max_items_per_stack
func _split_into_stacks(amount: int, max_per_stack: int) -> Array:
	var stacks = []
	if max_per_stack <= 0: # No stack limit
		stacks.append(amount)
		return stacks
	
	while amount > 0:
		var stack_size = min(amount, max_per_stack)
		stacks.append(stack_size)
		amount -= stack_size
	
	return stacks


# Generic function to handle addition logic for items, weapons, and armor
func _add_generic_amount(collection: Dictionary, data: Array, id: int, amount: int, level: int, item_type: int) -> int:
	amount = abs(amount)

	if id <= 0 or data.size() <= id or amount <= 0:
		return 0
	
	var real_item = data[id]
	var max_inventory = RPGSYSTEM.database.system.max_items_in_inventory
	var max_per_stack = RPGSYSTEM.database.system.max_items_per_stack
	var remaining_amount = amount
	var added_amount = 0
	
	# Initialize collection if it doesn't exist
	if not collection.has(id):
		collection[id] = []
	
	var item_list = collection[id]
	
	# First, try to add to existing compatible stacks
	for item in item_list:
		if remaining_amount <= 0:
			break
			
		var compatible = false
		var can_stack_more = false
		
		if item_type == 0: # Items
			# Items are compatible if they're not perishable and not equipped
			compatible = not item.is_perishable
			if compatible and max_per_stack > 0:
				can_stack_more = item.quantity < max_per_stack
			elif compatible:
				can_stack_more = true # No stack limit
		else: # Weapons/Armor
			# Weapons/Armor are compatible if max_levels == 1 and not equipped
			compatible = real_item.upgrades.max_levels == 1 and not item.equipped
			if compatible and max_per_stack > 0:
				can_stack_more = item.quantity < max_per_stack
			elif compatible:
				can_stack_more = true # No stack limit
		
		if compatible and can_stack_more:
			var can_add = remaining_amount
			if max_per_stack > 0:
				can_add = min(remaining_amount, max_per_stack - item.quantity)
			
			item.quantity += can_add
			remaining_amount -= can_add
			added_amount += can_add
	
	# If there's still amount to add, create new stacks
	if remaining_amount > 0:
		var current_slots = _get_total_used_slots()
		var available_slots = max_inventory - current_slots if max_inventory > 0 else -1
		
		# Check if we have inventory space (only if max_inventory > 0)
		if max_inventory > 0 and available_slots <= 0:
			return added_amount # No more space, return what we managed to add
		
		# Split remaining amount into stacks
		var stacks = _split_into_stacks(remaining_amount, max_per_stack)
		var slots_needed = stacks.size()
		
		# Limit stacks if we don't have enough inventory space
		if max_inventory > 0 and slots_needed > available_slots:
			# We can only create as many stacks as we have slots available
			stacks = stacks.slice(0, available_slots)
		
		# Create the stacks
		for stack_amount in stacks:
			if item_type == 0: # Items
				if not real_item.perishable.is_enabled():
					# Non-perishable items can stack
					var game_item = GameItem.new(id, stack_amount, 0)
					game_item.is_perishable = false
					item_list.append(game_item)
					added_amount += stack_amount
				else:
					# Perishable items are created individually (each takes one slot)
					var items_to_create = stack_amount
					if max_inventory > 0:
						var current_slots_check = _get_total_used_slots()
						var available_slots_check = max_inventory - current_slots_check
						items_to_create = min(stack_amount, available_slots_check)
					
					for i in items_to_create:
						var game_item = GameItem.new(id, 1, 0)
						game_item.is_perishable = true
						game_item.lifetime = real_item.perishable.duration
						item_list.append(game_item)
						added_amount += 1
			else: # Weapons/Armor
				if real_item.upgrades.max_levels == 1:
					# Items with max_levels == 1 can stack
					var game_item
					if item_type == 1: # Weapon
						game_item = GameWeapon.new(id, stack_amount, 1)
					else: # Armor
						game_item = GameArmor.new(id, stack_amount, 2)
					game_item.current_level = max(1, min(level, real_item.upgrades.max_levels))
					item_list.append(game_item)
					added_amount += stack_amount
				else:
					# Items with max_levels > 1 are created individually (each takes one slot)
					var items_to_create = stack_amount
					if max_inventory > 0:
						var current_slots_check = _get_total_used_slots()
						var available_slots_check = max_inventory - current_slots_check
						items_to_create = min(stack_amount, available_slots_check)
					
					for i in items_to_create:
						var game_item
						if item_type == 1: # Weapon
							game_item = GameWeapon.new(id, 1, 1)
						else: # Armor
							game_item = GameArmor.new(id, 1, 2)
						game_item.current_level = max(1, min(level, real_item.upgrades.max_levels))
						item_list.append(game_item)
						added_amount += 1

	return added_amount


func load_game(slot_id: int) -> void:
	if not main_scene: return
	
	var game_data: RPGSavedGameData = SaveLoadManager.load_game(slot_id)
	if game_data:
		main_scene.load_game(game_data)


func clear_map_repeating() -> void:
	if main_scene: main_scene.clear_map_repeating()


func enable_map_repeating() -> void:
	if main_scene: main_scene.enable_map_repeating()


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
	if main_scene:
		main_scene.set_canvas_modulate_color(color)


func set_map_color(color: Color) -> void:
	if main_scene:
		main_scene.set_map_color(color)


func set_tint_color(color: Color, duration: float) -> void:
	if main_scene:
		main_scene.set_tint_color(color, duration)


func remove_tint_color(duration: float) -> void:
	if main_scene:
		main_scene.remove_tint_color(duration)


func set_day_color(color: Color) -> void:
	if main_scene:
		main_scene.set_day_color(color)


func set_weather_color(color: Color, duration: float) -> void:
	if main_scene:
		main_scene.set_weather_color(color, duration)


func set_weather_flash(color: Color, duration: float) -> void:
	if main_scene:
		main_scene.set_weather_flash(color, duration)


func remove_weather_color(duration: float) -> void:
	if main_scene:
		main_scene.remove_weather_color(duration)


# Generic function to handle removal logic for items, weapons, and armor
func _remove_generic_amount(collection: Dictionary, id: int, amount: int, include_equipment: bool = false, use_perishable_logic: bool = false) -> void:
	amount = abs(amount)
	if not collection.has(id):
		return
	
	var item_list = collection[id]
	var remaining_to_remove = amount
	
	# Main loop until no items left to remove
	while remaining_to_remove > 0 and not item_list.is_empty():
		var item_found = false
		
		if use_perishable_logic:
			# Items logic: search from last to first for non-perishable items
			for i in range(item_list.size() - 1, -1, -1):
				var item = item_list[i]
				if not item.is_perishable:
					item_found = true
					
					if item.quantity >= remaining_to_remove:
						# Item has enough quantity
						item.quantity -= remaining_to_remove
						remaining_to_remove = 0
						
						# If quantity reaches 0, remove the item
						if item.quantity <= 0:
							item_list.erase(item)
					else:
						# Item doesn't have enough quantity, remove it completely
						remaining_to_remove -= item.quantity
						item_list.erase(item)
					
					break # Process one item at a time
			
			# If no non-perishable items found, search for perishable with lowest lifetime
			if not item_found and remaining_to_remove > 0:
				var perishable_item = null
				var min_lifetime = INF
				
				for i in range(item_list.size()):
					var item = item_list[i]
					if item.is_perishable and item.lifetime < min_lifetime:
						min_lifetime = item.lifetime
						perishable_item = item
				
				# If we found a perishable item, process it
				if perishable_item != null:
					if perishable_item.quantity >= remaining_to_remove:
						# Item has enough quantity
						perishable_item.quantity -= remaining_to_remove
						remaining_to_remove = 0
						
						# If quantity reaches 0, remove the item
						if perishable_item.quantity <= 0:
							item_list.erase(perishable_item)
					else:
						# Item doesn't have enough quantity, remove it completely
						remaining_to_remove -= perishable_item.quantity
						item_list.erase(perishable_item)
				else:
					# No more items available
					break
		else:
			# Weapons/Armor logic: sort by level and experience, then process unequipped first
			item_list.sort_custom(func(a, b):
				if a.current_level != b.current_level:
					return a.current_level < b.current_level
				return a.current_experience < b.current_experience
			)
			
			# Phase 1: Look for unequipped items first
			for i in range(item_list.size()):
				var item = item_list[i]
				if not item.equipped:
					item_found = true
					
					if item.quantity >= remaining_to_remove:
						# Item has enough quantity
						item.quantity -= remaining_to_remove
						remaining_to_remove = 0
						
						# If quantity reaches 0, remove the item
						if item.quantity <= 0:
							item_list.erase(item)
					else:
						# Item doesn't have enough quantity, remove it completely
						remaining_to_remove -= item.quantity
						item_list.erase(item)
					
					break # Process one item at a time
			
			# Phase 2: If include_equipment is true and still need to remove items
			if not item_found and remaining_to_remove > 0 and include_equipment:
				# Look for equipped items
				for i in range(item_list.size()):
					var item = item_list[i]
					if item.equipped:
						item_found = true
						
						if item.quantity >= remaining_to_remove:
							# Item has enough quantity
							item.quantity -= remaining_to_remove
							remaining_to_remove = 0
							
							# If quantity reaches 0, remove the item
							if item.quantity <= 0:
								item_list.erase(item)
						else:
							# Item doesn't have enough quantity, remove it completely
							remaining_to_remove -= item.quantity
							item_list.erase(item)
						
						break # Process one item at a time
		
		# If no item was found, break the loop
		if not item_found:
			break
	
	# If the list is empty, remove the id from the dictionary
	if item_list.is_empty():
		collection.erase(id)


func add_item_amount(id: int, amount: int, auto_popup_enabled: bool = false, popup_prefix: String = "") -> int:
	var added = _add_generic_amount(game_state.items, RPGSYSTEM.database.items, id, amount, 0, 0)
	
	if added > 0:
		if auto_popup_enabled or RPGSYSTEM.database.system.options.get("auto_popup_on_pick_up_items", false):
			call_deferred("_create_popup_message", 0, id, added, popup_prefix)
		
		# Update statistics
		var item_id = "0" + "_" + str(id)
		if not item_id in game_state.stats.items_found:
			game_state.stats.items_found[item_id] = 0
		game_state.stats.items_found[item_id] += added
	
	if added != amount:
		over_flow_bag.append(
			{
				"type": 0,
				"id": id,
				"amount": amount - added,
				"auto_popup_enabled": auto_popup_enabled,
				"popup_prefix": popup_prefix,
			}
		)
		create_over_flow_bag = true
	
	return added


func remove_item_amount(id: int, amount: int) -> void:
	_remove_generic_amount(game_state.items, id, amount, false, true)


func get_weapon_amount(id: int) -> int:
	var quantity: int = 0
	if game_state.weapons.has(id):
		for item: GameWeapon in game_state.weapons[id]:
			quantity += item.quantity
	
	return quantity


func add_weapon_amount(id: int, amount: int, level: int = 1, auto_popup_enabled: bool = false, popup_prefix: String = "", _item_level: int = -1) -> int:
	var added = _add_generic_amount(game_state.weapons, RPGSYSTEM.database.weapons, id, amount, level, 1)
	if added > 0:
		if auto_popup_enabled or RPGSYSTEM.database.system.options.get("auto_popup_on_pick_up_items", false):
			call_deferred("_create_popup_message", 1, id, added, popup_prefix, level)
		
		# Update statistics
		var item_id = "1" + "_" + str(id)
		if not item_id in game_state.stats.items_found:
			game_state.stats.items_found[item_id] = 0
		game_state.stats.items_found[item_id] += added
	
	if added != amount:
		over_flow_bag.append(
			{
				"type": 1,
				"id": id,
				"amount": amount - added,
				"level": level,
				"auto_popup_enabled": auto_popup_enabled,
				"popup_prefix": popup_prefix,
			}
		)
		create_over_flow_bag = true
	
	return added


func remove_weapon_amount(id: int, amount: int, include_equipment: bool) -> void:
	_remove_generic_amount(game_state.weapons, id, amount, include_equipment, false)


func get_armor_amount(id: int) -> int:
	var quantity: int = 0
	if game_state.armors.has(id):
		for item: GameArmor in game_state.armors[id]:
			quantity += item.quantity
	
	return quantity


func add_armor_amount(id: int, amount: int, level: int = 1, auto_popup_enabled: bool = false, popup_prefix: String = "") -> int:
	var added = _add_generic_amount(game_state.armors, RPGSYSTEM.database.armors, id, amount, level, 2)
	
	if added > 0:
		if auto_popup_enabled or RPGSYSTEM.database.system.options.get("auto_popup_on_pick_up_items", false):
			call_deferred("_create_popup_message", 2, id, added, popup_prefix, level)
		
		# Update statistics
		var item_id = "2" + "_" + str(id)
		if not item_id in game_state.stats.items_found:
			game_state.stats.items_found[item_id] = 0
		game_state.stats.items_found[item_id] += added
	
	if added != amount:
		over_flow_bag.append(
			{
				"type": 2,
				"id": id,
				"amount": amount - added,
				"level": level,
				"auto_popup_enabled": auto_popup_enabled,
				"popup_prefix": popup_prefix,
			}
		)
		create_over_flow_bag = true
	
	return added


func remove_armor_amount(id: int, amount: int, include_equipment: bool) -> void:
	_remove_generic_amount(game_state.armors, id, amount, include_equipment, false)


func get_actor_parameter(actor_id: int, parameter_id: String) -> int:
	var result: int = 0
	parameter_id = parameter_id.to_lower()
	if game_state.actors.has(actor_id):
		var actor: GameActor = game_state.actors[actor_id]
		if parameter_id == "level":
			result = actor.current_level
		elif parameter_id == "experience":
			result = actor.current_experience
		elif parameter_id == "tp":
			pass # need battle TODO
		else:
			result = actor.get_parameter(parameter_id)
	
	return result


func get_actor_user_parameter(actor_id: int, parameter_id: int) -> float:
	var result: float = 0
	if game_state.actors.has(actor_id):
		var actor: GameActor = game_state.actors[actor_id]
		result = actor.get_user_parameter(parameter_id)
		
	return result


func get_global_user_parameter(parameter_id: int) -> float:
	var result: float = 0
	if game_state.game_user_parameters.size() > parameter_id and parameter_id > 0:
		result = game_state.game_user_parameters[parameter_id]
		
	return result


func set_actor_parameter(actor: GameActor, parameter_id: String, operation: int, amount: int) -> void:
	parameter_id = parameter_id.to_lower()
	
	if parameter_id == "level":
		if operation == 0: # Add
			actor.change_level(actor.current_level + amount)
		else: # Sub
			actor.change_level(actor.current_level + amount)
	elif parameter_id == "experience":
		actor.add_experience(amount)
	elif parameter_id == "tp":
		pass # need battle TODO
	else:
		actor.set_parameter(parameter_id, amount, operation)
	
	actor.parameter_changed.emit()


func get_enemy_parameter(enemy_id: int, parameter_id: String) -> int:
	var result: int = 0
	parameter_id = parameter_id.to_lower()
	if enemy_id > 0 and RPGSYSTEM.database.enemies.size() > enemy_id:
		var enemy: RPGEnemy = RPGSYSTEM.database.enemies[enemy_id]
		if parameter_id == "tp":
			pass # need battle TODO
		else:
			result = enemy.get_parameter(parameter_id)
	
	return result


func _get_weapon_or_armor_parameter(data: Variant, parameter: String, level: int) -> int:
	if data is RPGWeapon or data is RPGArmor:
		return data.get_parameter(parameter, level)
	
	return 0


func get_weapon_parameter(weapon_id: int, parameter_id: String, weapon_level: int) -> int:
	if weapon_id > 0 and RPGSYSTEM.database.weapons.size() > weapon_id:
		return _get_weapon_or_armor_parameter(RPGSYSTEM.database.weapons[weapon_id], parameter_id, weapon_level)
		
	return 0


func get_armor_parameter(armor_id: int, parameter_id: String, armor_level: int) -> int:
	if armor_id > 0 and RPGSYSTEM.database.weapons.size() > armor_id:
		return _get_weapon_or_armor_parameter(RPGSYSTEM.database.armor[armor_id], parameter_id, armor_level)
		
	return 0


func get_local_switch(id: int) -> bool:
	if game_state and current_map:
		print({
			"ids": game_state.game_self_switches,
			"Current id": "%s-%s" % [current_map.internal_id, id]
		})
		return game_state.game_self_switches.get("%s_%s" % [current_map.internal_id, id], false)
		
	return false


func get_profession_level(profession: RPGProfession) -> int:
	if game_state:
		var profession_level = 0
		var actor_profession_level = game_state.profession_levels.get(profession.id, {}) # {level, sub_level, available, experiencie}
		var profession_is_available = actor_profession_level.get("available", false)
		var level = actor_profession_level.get("level", -1)
		for i in level - 1:
			profession_level += profession.levels[i].max_levels
		var sub_level = actor_profession_level.get("sub_level", 1)
		profession_level += sub_level
		return -1 if not profession_is_available else profession_level
		
	return 0


func get_event_relationship_level(event_id: int) -> int:
	var result = 0
	
	if current_map:
		var ingame_event = current_map.get_in_game_event(event_id)
		if ingame_event:
			var relationship: GameRelationship = ingame_event.relationship
			result = relationship.current_level
			
	return result


func is_item_in_possesion(item_type, item_id) -> bool:
	if game_state:
		match item_type:
			0: # Items
				for obj in game_state.items:
					if obj.id == item_id:
						return true
			1: # Weapons
				for obj in game_state.weapons:
					if obj.id == item_id:
						return true
			2: # Armors
				for obj in game_state.armors:
					if obj.id == item_id:
						return true
	return false


func is_actor_in_group(id: int) -> bool:
	if game_state:
		for actor_id in game_state.current_party:
			if actor_id == id:
				return true
	
	return false


func get_actor(id: int) -> GameActor:
	if game_state:
		for actor_id in game_state.actors:
			if actor_id == id:
				return game_state.actors[actor_id]
	
	return null


func get_real_actor(id: int) -> RPGActor:
	if id > 0 and RPGSYSTEM.database.actors.size() > id:
		return RPGSYSTEM.database.actors[id]
	
	return null


func add_party_member(actor_id: int, initialize: bool) -> void:
	if game_state and not is_actor_in_group(actor_id):
		if actor_id > 0 and RPGSYSTEM.database.actors.size() > actor_id:
			if not actor_id in game_state.current_party:
				game_state.current_party.append(actor_id)

			var actor: GameActor = get_actor(actor_id)
			if actor and initialize:
				actor.initialize()
			else:
				actor = GameActor.new(actor_id)
				game_state.actors[actor_id] = actor


func remove_party_member(actor_id: int) -> void:
	if game_state and is_actor_in_group(actor_id):
		for i in range(game_state.current_party.size()):
			if game_state.current_party[i] == actor_id:
				game_state.current_party.remove_at(i)
				break


func change_formation(actor_id1: int, actor_id2: int) -> void:
	if game_state and is_actor_in_group(actor_id1) and is_actor_in_group(actor_id2):
		# Check if any actor is locked
		if is_party_member_locked(actor_id1) or is_party_member_locked(actor_id2):
			return
		
		var p1 = game_state.current_party.find(actor_id1)
		var p2 = game_state.current_party.find(actor_id2)

		if p1 != -1 and p2 != -2:
			var temp = game_state.current_party[p1]
			game_state.current_party[p1] = game_state.current_party[p2]
			game_state.current_party[p2] = temp
			if 0 in [p1, p2]:
				update_character_graphics(current_player, game_state.current_party[0])
			_update_follower()


func update_character_graphics(node: Node, new_player_id: int) -> void:
	# TODO Add logic to update graphics when change equip
	if node and new_player_id > 0 and RPGSYSTEM.database.actors.size() > new_player_id:
		if not "current_data" in node: return
		var actor = RPGSYSTEM.database.actors[new_player_id]
		var scene_path = actor.character_data_file
		if ResourceLoader.exists(scene_path):
			var scene_data: RPGLPCCharacter = load(scene_path)
			current_player.set_data(scene_data)


func show_followers(value: bool) -> void:
	if not game_state: return
	game_state.followers_enabled = value
	_update_follower()


func _update_follower() -> void:
	if not game_state or not game_state.followers_enabled: return
	# TODO
	pass


func is_party_member_locked(actor_id: int) -> bool:
	if game_state:
		return actor_id in game_state.party_member_locked
		
	return false


func change_leader(leader_id: int, is_locked: bool) -> void:
	if game_state:
		for i in range(game_state.current_party.size()):
			if game_state.current_party[i] == leader_id:
				game_state.current_party.remove_at(i)
				break
		game_state.current_party.insert(0, leader_id)

		while game_state.current_party.size() > RPGSYSTEM.database.system.party_active_members:
			game_state.current_party.resize(game_state.current_party.size() - 1)

		if is_locked:
			game_state.party_member_locked.append(leader_id)
		else:
			for i in range(game_state.party_member_locked.size()):
				if game_state.party_member_locked[i] == leader_id:
					game_state.party_member_locked.remove_at(i)
					break


func get_main_scene() -> MainScene:
	if main_scene: return main_scene
	return null


func setup_gui_scene(scene: Node) -> void:
	if main_scene: main_scene._setup_gui_scene(scene)


func change_scene(path: String, destroy_gui: bool = false) -> void:
	if main_scene: main_scene.change_scene(path, destroy_gui)


func set_combat_experience_mode_leader(type: int) -> void:
	if game_state:
		game_state.experience_mode = type


func _get_timer(timer_id: int) -> TimerScene:
	if timer_id in GameManager.game_state.active_timers:
		for child in main_scene.get_screen_effect_canvas().get_children():
			if child is TimerScene and child.id == timer_id:
				return child
	
	return null


func manage_timer(config: Dictionary) -> void:
	var operation_type = config.get("operation_type", 0)
	var timer_id = config.get("timer_id", 0)
	var minutes = config.get("minutes", 0)
	var seconds = config.get("seconds", 0)
	var total_time_in_seconds = minutes * 60 + seconds
	
	if operation_type == 0: # Create Timer
		var timer: TimerScene = _get_timer(timer_id)
		if timer:
			timer.stop()
		var timer_scene = config.get("timer_scene", "")
		var timer_name = config.get("timer_title", "")
		var extra_config = config.get("extra_config", {})
		if timer_scene.is_empty() or not ResourceLoader.exists(timer_scene):
			return
		var scene = load(timer_scene).instantiate()
		main_scene.get_screen_effect_canvas().add_child(scene)
		scene.set_config(timer_id, timer_name, extra_config)
		scene.tree_exited.connect(func(): GameManager.game_state.active_timers.erase(timer_id))
		GameManager.game_state.active_timers[timer_id] = {
			"config": config,
			"current_time": seconds
		}
		scene.start(total_time_in_seconds)
		
	else:
		var timer: TimerScene = _get_timer(timer_id)
		if timer:
			match operation_type:
				1: # Destroy Timer
					timer.stop()
				2: # Pause Timer
					timer.pause()
				3: # Resume Timer
					timer.resume()
				4: # Add Time To Timer
					timer.add_time(total_time_in_seconds)
				5: # Remove Time From Timer
					timer.subtract_time(total_time_in_seconds)


func _create_popup_message(type: int, item_id: int, quantity: int, popup_prefix = "", level = -1) -> void:
	if temporally_popup_disabled: return
	
	var obj: Dictionary
	
	if item_id > 0:
		@warning_ignore("incompatible_ternary")
		var data = RPGSYSTEM.database.items if type == 0 \
			else RPGSYSTEM.database.weapons if type == 1 \
			else RPGSYSTEM.database.armors
		
		if data.size() > item_id:
			var real_data = data[item_id]
			var rarity_type = real_data.rarity_type
			var types = RPGSYSTEM.database.types.item_rarity_color_types if type == 0 \
				else RPGSYSTEM.database.types.weapon_rarity_color_types if type == 1 \
				else RPGSYSTEM.database.types.armor_rarity_color_types
			
			var color = Color.WHITE if rarity_type < 1 or types.size() <= rarity_type else types[rarity_type]
		
			obj = {
				"icon_path": real_data.icon,
				"item_name": real_data.name + ("" if level == -1 else " (" + tr("Lv ") + str(level) + ")"),
				"item_color": color,
				"quantity": quantity,
				"prefix": popup_prefix
			}
	
	if obj:
		show_popup_message(obj)


func show_popup_message(obj: Dictionary) -> void:
	if temporally_popup_disabled: return
	
	if main_scene:
		main_scene.show_popup_message(obj)


func _show_alert_message(text: String, initial_position: Vector2) -> void:
	var alert_id = str(text) + "_" + str(initial_position)
	if alert_id in last_animated_popup or not GameManager.current_map:
		return
		
	var label: RichTextLabel = ANIMATE_POPUP.instantiate()
	GameManager.current_map.add_child(label)
	label.z_index = 500
	label.set_data(text, initial_position)
	last_animated_popup[alert_id] = true
	label.tree_exited.connect(_on_alert_tree_exited.bind(alert_id))


func _on_alert_tree_exited(alert_id: String) -> void:
	if alert_id in last_animated_popup:
		last_animated_popup.erase(alert_id)


func manage_extraction_scene(node: Node) -> void:
	var data: RPGExtractionItem = node.data
	var extraction_data: GameExtractionItem = node.extraction_data
	var profession = data.get_profession()
	var alert_message: String
	if profession:
		if not has_profession(profession.id):
			alert_message = tr("Profession required") + "\n< [color=red]%s[/color] >" % profession.name
			var top_node = get_node_or_null("%Top")
			_show_alert_message(alert_message, node.global_position if not top_node else top_node.global_position)
			return
			
		var player_level = get_profession_level(profession)
		if not data.no_level_restrictions and (player_level < data.min_required_profession_level or player_level > data.max_required_profession_level):
			if player_level < data.min_required_profession_level:
				alert_message = tr("You need a higher\nlevel to extract") + "\n< [color=red]%s[/color]  >" % data.name
			else:
				alert_message = tr("Your level is too\nhigh to extract") + "\n< [color=red]%s[/color]  >" % data.name
			var top_node = get_node_or_null("%Top")
			_show_alert_message(alert_message, node.global_position if not top_node else top_node.global_position)
			return
		
		var level_difference = data.current_level - player_level
		if level_difference >= 10:
			alert_message = tr("Cannot extract") + "\n< [color=red]%s[/color] >\n" % data.name + tr("Item level too high")
			var top_node = get_node_or_null("%Top")
			_show_alert_message(alert_message, node.global_position if not top_node else top_node.global_position)
			return
		
		#if level_difference < -10:
			#alert_message = tr("Cannot extract") + "\n< [color=red]%s[/color] >\n" % data.name + tr("Item level too low")
			#var top_node = get_node_or_null("%Top")
			#_show_alert_message(alert_message,  node.global_position if not top_node else top_node.global_position)
			#return
			
		if gui_canvas_layer:
			busy = true
			if node.has_method("start_extraction"):
				node.start_extraction()
			var scene = preload("res://Scenes/ExtractionScenes/default_manager_extraction_scene.tscn").instantiate()
			gui_canvas_layer.add_child(scene)
			scene.start(data, extraction_data)

			var _result = await scene.finished
			
			extraction_data.current_uses -= 1
			if extraction_data.current_uses == 0:
				if node.has_method("end"):
					extraction_data.depleted_date = game_state.stats.play_time
					extraction_data.current_respawn_time = data.respawn_time
					node.end()
			
			if node.has_method("end_extraction"):
				node.end_extraction()
			busy = false


func has_profession(profession_id: int) -> bool:
	if not game_state or not profession_id in game_state.profession_levels or not game_state.profession_levels[profession_id].available:
		return false

	return true


func add_profession_experience(event_data: RPGExtractionItem, experience: float) -> void:
	var profession_id = event_data.required_profession
	if not game_state or not profession_id in game_state.profession_levels or not game_state.profession_levels[profession_id].available:
		return
	
	var level: Dictionary = game_state.profession_levels[profession_id]
	
	if "current_level_completed" in level:
		return
	
	var profession = event_data.get_profession()
	if not profession:
		return
		
	var current_profession_level = get_profession_level(profession)
	
	while experience > 0:
		# make sure current level index exists
		if profession.levels.size() <= level.level - 1:
			break
		
		var last_level = profession.levels.size()
		var is_last_level = level.level == last_level
		
		# If at last level, cap experience and sublevel
		if is_last_level:
			level.level = last_level
			level.sub_level = 1
			level.experience = 0
			experience = 0
		else:
			var profession_level_component: RPGExtractionLevelComponent = profession.levels[level.level - 1]
			var current_experience_base_needed: int = int(profession_level_component.experience_to_complete * pow(1.1, level.sub_level - 1))
			var max_sub_levels = profession_level_component.max_levels
			
			if level.experience + experience >= current_experience_base_needed:
				# consume required exp to reach next sublevel
				experience = level.experience + experience - current_experience_base_needed
				level.experience = 0
				level.sub_level += 1
				
				# check if sublevel exceeds maximum
				if level.sub_level > max_sub_levels:
					if level.level + 1 <= profession.levels.size():
						if profession.auto_upgrade_level:
							level.sub_level = 1
							level.level += 1
							if profession.call_global_event_on_level_up:
								if profession.target_global_event > 0 and RPGSYSTEM.database.common_events.size() > profession.target_global_event:
									var global_event: RPGCommonEvent = RPGSYSTEM.database.common_events[profession.target_global_event]
									GameInterpreter.start_common_event(null, global_event.list)
						else:
							level.experience = 0
							level.sub_level -= 1
							level["current_level_completed"] = true # mark level as completed (need use an Event Command to reaches a new level)
							experience = 0
					else:
						# reached maximum level and sublevel
						level.experience = 0
						level.sub_level = max_sub_levels
						level.level = profession.levels.size()
						level["current_level_completed"] = true # mark level as completed
						experience = 0 # discard remaining exp
			else:
				# not enough exp to level up, just accumulate
				level.experience += experience
				experience = 0
	
	var final_profession_level = get_profession_level(profession)
	if current_profession_level != final_profession_level and current_map:
		current_map.refresh_extraction_events()
		

func update_timer_time(timer_id: int, value: float) -> void:
	if not Engine.is_editor_hint():
		if GameManager.game_state.active_timers.has(timer_id):
			GameManager.game_state.active_timers[timer_id].current_time = value


func show_menu() -> void:
	if main_menu and main_menu.visible: return
	if not busy and not GameInterpreter.is_busy() and game_state and not game_state.menu_scene_prohibited:
		busy = true
		if RPGSYSTEM.database.system.pause_day_night_in_menu:
			DayNightManager.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().process_frame
		if not main_menu:
			create_main_menu()
		if main_menu:
			if main_menu.is_inside_tree():
				main_menu.get_parent().remove_child(main_menu)
				return
			gui_canvas_layer.add_child(main_menu)
			main_menu.show()
			main_menu.start()


func create_main_menu() -> void:
	if gui_canvas_layer:
		var scene_path = RPGSYSTEM.database.system.game_scenes["Scene Main Menu"]
		var scn = load(scene_path)
		main_menu = scn.instantiate()
		main_menu.visible = false
		main_menu.visibility_changed.connect(
			func():
				busy = main_menu.visible
				if not main_menu.visible and main_menu.is_inside_tree():
					gui_canvas_layer.remove_child(main_menu)
		)
		main_menu.end.connect(
			func():
				busy = false
				if RPGSYSTEM.database.system.pause_day_night_in_menu:
					DayNightManager.process_mode = Node.PROCESS_MODE_INHERIT
		)


func is_mouse_over_current_control_focused() -> bool:
	var control = get_viewport().gui_get_focus_owner()
	if control and control.get_global_rect().has_point(control.get_global_mouse_position()):
		return true
		
	return false


func get_number_formatted(number: float, decimals: int = 0, prefix: String = "", suffix: String = "", force_zero_decimal: bool = false) -> String:
	var options = RPGSYSTEM.database.system.options
	var use_thousands_separator = options.get("use_thousands_separator", true)
	var show_abbreviated = options.get("show_abbreviated_in_battle", true) if current_battle else options.get("show_abbreviated_in_menu", true)
	
	if show_abbreviated:
		return prefix + _format_compact_number(number, decimals, force_zero_decimal) + suffix
	elif use_thousands_separator:
		return prefix + _format_number(number, decimals, "", force_zero_decimal) + suffix
	
	var format_string = "%." + str(decimals) + "f"
	return prefix + (format_string % number) + suffix


func _format_compact_number(number: float, decimals: int = 0, force_zero_decimal: bool = false) -> String:
	if number == 0: return "0"
	
	var abs_number: float = abs(number)
	
	var suffixes = [
		{"value": 1000000000000000.0, "suffix": "Q"}, # (quadrillion)
		{"value": 1000000000000.0, "suffix": "T"}, # (trillion)
		{"value": 1000000000.0, "suffix": "B"}, # (billion)
		{"value": 1000000.0, "suffix": "M"}, # (million)
		{"value": 1000.0, "suffix": "k"} # (thousand)
	]
	
	for suffix_data in suffixes:
		if abs_number >= suffix_data.value:
			var value = abs_number / suffix_data.value
			
			if value >= 1000.0:
				continue
			
			var format_string = "%." + str(decimals) + "f"
			var formatted_value = format_string % value
			
			if decimals == 0 and value == int(value):
				return str(int(value)) + suffix_data.suffix
			
			return formatted_value + suffix_data.suffix
	
	if decimals == 0 or (force_zero_decimal and number == int(number)):
		return str(int(abs_number))
	else:
		var format_string = "%." + str(decimals) + "f"
		return format_string % abs_number


func _format_number(number: float, decimals: int = 0, separator: String = "", force_zero_decimal: bool = false) -> String:
	if number == 0: return "0"
	
	if separator == "":
		separator = _get_thousands_separator_by_language()
	
	var format_string = "%." + str(decimals) + "f"
	var num_str = format_string % number
	
	var parts = num_str.split(".")
	var integer_part = parts[0]
	var decimal_part = parts[1] if parts.size() > 1 else ""
	
	var regex = RegEx.new()
	regex.compile("(\\d)(?=(\\d{3})+(?!\\d))")
	var formatted_integer = regex.sub(integer_part, "$1" + separator, true)
	
	if decimals == 0 or (force_zero_decimal and number == int(number)):
		return formatted_integer
	else:
		return formatted_integer + "." + decimal_part


func _get_thousands_separator_by_language() -> String:
	var locale = OS.get_locale()
	var language = locale.split("_")[0]
	
	match language:
		"es", "de", "pt", "it", "fr", "nl", "pl", "ru", "sv", "da", "no":
			return "."
		"en", "ja", "ko", "zh", "th", "hi":
			return ","
		_:
			return "."


func format_time(total_seconds: float) -> String:
	var int_seconds = int(total_seconds)
	var hours: int = int(int_seconds / 3600.0)
	var minutes: int = int((int_seconds % 3600) / 60.0)
	var seconds: int = int(int_seconds % 60)
	
	var time_str: String
	if hours >= 1:
		time_str = "%sh %sm" % [_format_number(hours), minutes]
	elif total_seconds > 60:
		time_str = "%sm %ss" % [minutes, seconds]
	else:
		time_str = "%.1fs" % total_seconds
	
	return time_str


func format_game_time(seconds: int, colon_visible: bool = true) -> String:
	var h: int = seconds / 3600.0
	var m: int = (seconds % 3600) / 60.0
	var s: int = seconds % 60
	
	if seconds < 60:
		var second_text = tr("Second") if s == 1 else tr("Seconds")
		return "%02d %s" % [s, second_text]
	
	var colon = ":" if colon_visible else " "
	
	if seconds < 3600:
		return "%02dM%s%02dS" % [m, colon, s]
	
	else:
		return "%02dH%s%02dM%s%02dS" % [h, colon, m, colon, s]


func add_shop_timer(shop_id: String, shop_timer: float, stock_data: Dictionary = {}) -> RPGShopTimer:
	if game_state:
		game_state.active_shop_timers[shop_id] = RPGShopTimer.new(shop_id, shop_timer, stock_data)
		
		return game_state.active_shop_timers[shop_id]
	
	return null


func get_shop_timer(shop_id: String) -> RPGShopTimer:
	if game_state and shop_id in game_state.active_shop_timers:
		return game_state.active_shop_timers[shop_id]
	
	return null


func play_music(id: Variant) -> void:
	if main_scene:
		main_scene.play_music(id)


func play_video(path: String, loop: bool = false, fade_out_time: float = 0.0) -> VideoStreamPlayer:
	if main_scene:
		return main_scene.play_video(path, loop, fade_out_time)
	
	return null


func set_fx_busy(value: bool) -> void:
	if main_scene:
		main_scene.fx_busy = value


func play_fx(id: Variant) -> void:
	if main_scene:
		main_scene.play_fx(id)


func play_me(me: Variant, volume: float = 0.0, pitch: float = 1.0) -> void:
	if main_scene:
		main_scene.play_me(me, volume, pitch)


func play_se(fx: Variant, volume: float = 0.0, pitch: float = 1.0) -> void:
	if main_scene:
		main_scene.play_se(fx, volume, pitch)


func save_bgm() -> void:
	if main_scene: main_scene.save_bgm()


func restore_bgm() -> void:
	if main_scene: main_scene.restore_bgm()


func play_bgm(bgm: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	if main_scene:
		main_scene.play_bgm(bgm, volume, pitch, fade_duration)


func play_bgs(bgs: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	if main_scene:
		main_scene.play_bgs(bgs, volume, pitch, fade_duration)


func stop_bgm(fade_duration: float = 0) -> void:
	if main_scene:
		main_scene.stop_bgm(fade_duration)


func stop_bgs(fade_duration: float = 0) -> void:
	if main_scene:
		main_scene.stop_bgs(fade_duration)


func stop_se() -> void:
	if main_scene:
		main_scene.stop_se()


func stop_video() -> void:
	if main_scene:
		main_scene.stop_video()
