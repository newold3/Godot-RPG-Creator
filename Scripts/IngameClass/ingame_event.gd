class_name IngameEvent
extends RefCounted


var map: RPGMap
var map_id: int
var event_id: int
var uniq_id: int
var relationship: GameRelationship
var event: RPGEvent
var character_data: RPGLPCCharacter
var page_id: int
var lpc_event: Variant
var name_label: Label

const EMPTY_LPC_EVENT = preload("uid://cxt2hyq05twny")
const DEFAULT_NAMELABEL_SETTING = "uid://dedssgyoqloq"



func _init(p_map: RPGMap, p_event: RPGEvent, p_character_data: RPGLPCCharacter, p_lpc_event: Variant, p_map_id: int, p_relationship: GameRelationship = null, p_page_id: int = 1) -> void:
	map = p_map
	event = p_event
	character_data = p_character_data
	lpc_event = p_lpc_event
	if event:
		event_id = event.id
		if "_uniq_id" in event:
			uniq_id = event._uniq_id
		else:
			uniq_id = event.id 
	map_id = p_map_id
	relationship = p_relationship
	page_id = p_page_id


func update_page(new_page: RPGEventPage, new_character_data: RPGLPCCharacter) -> void:
	page_id = new_page.page_id
	character_data = new_character_data


func refresh_page(page: RPGEventPage) -> void:
	page.id = event.id
	var index = lpc_event.get_index() if lpc_event else 0
	if event.legacy_mode:
		handle_legacy_refresh(page)
	else:
		handle_modern_refresh(page)
	
	if lpc_event:
		lpc_event.get_parent().move_child(lpc_event, index)
		lpc_event.z_index = page.z_index
	
	
	
	update_label_name(page)


func update_label_name(page: RPGEventPage) -> void:
	if name_label:
		name_label.queue_free()
	
	if page.options.show_name_in_map:
		var new_name = page.name if not page.name.is_empty() else \
			event.name if not event.name.is_empty() else ""
		if not new_name.is_empty():
			name_label = Label.new()
			name_label.text = new_name
			name_label.y_sort_enabled = false
			name_label.z_index = 128
			if AssetManager.exists(page.options.name_config_path):
				var config: LabelSettings = load(page.options.name_config_path)
				name_label.label_settings = config
			elif AssetManager.exists(DEFAULT_NAMELABEL_SETTING):
				name_label.label_settings = load(DEFAULT_NAMELABEL_SETTING)
			name_label.modulate.a = 0.0
			lpc_event.add_child(name_label)
			lpc_event.set_meta("name_label", name_label)
			await lpc_event.get_tree().process_frame
			var p: Vector2 = Vector2(0, -16)
			var up_node = lpc_event.get_node_or_null("%Up")
			if up_node:
				p += up_node.position
				p.x -= name_label.size.x / 2.0
				p.y -= name_label.size.y
			name_label.position = p
			var t = lpc_event.create_tween()
			t.tween_property(name_label, "modulate:a", 1.0, 0.5)


func handle_modern_refresh(page: RPGEventPage) -> void:
	var interpreter_id = "event_" + str(uniq_id)
	
	GameInterpreter.remove_interpreter_by_id(interpreter_id)
	
	var new_char_data = null
	if ResourceLoader.exists(page.character_path):
		new_char_data = load(page.character_path)
	
	update_page(page, new_char_data if new_char_data is RPGLPCCharacter else null)
	
	var target_dir = page.direction if page.options.fixed_direction else lpc_event.current_direction
	load_event_graphics(page, target_dir)
	
	if page.launcher == RPGEventPage.LAUNCHER_MODE.AUTOMATIC or page.launcher == RPGEventPage.LAUNCHER_MODE.PARALLEL:
		map.call_deferred("deferred_injection", self, page, interpreter_id)


func handle_legacy_refresh(page: RPGEventPage) -> void:
	var interpreter_id = "event_" + str(uniq_id)
	var active_interpreter = GameInterpreter.get_interpreter_with_id(interpreter_id)
	
	if active_interpreter:
		active_interpreter.is_updating = true
	
	var new_char_data = null
	if ResourceLoader.exists(page.character_path):
		new_char_data = load(page.character_path)
	
	update_page(page, new_char_data if new_char_data is RPGLPCCharacter else null)
	
	var target_dir = page.direction if page.options.fixed_direction else lpc_event.current_direction
	load_event_graphics(page, target_dir)
	
	if page.launcher == RPGEventPage.LAUNCHER_MODE.AUTOMATIC or page.launcher == RPGEventPage.LAUNCHER_MODE.PARALLEL:
		inject_parallel_auto_after_interpreter(page)
	
	_final_update(page)


func load_event_graphics(page: RPGEventPage, direction: int) -> void:
	var old_scene = lpc_event
	var new_scene: Variant = null
	var new_character_data: RPGLPCCharacter = null
	
	match page.character_type:
		0:
			if ResourceLoader.exists(page.character_path):
				new_character_data = load(page.character_path)
				if new_character_data and ResourceLoader.exists(new_character_data.scene_path):
					new_scene = load(new_character_data.scene_path).instantiate()
					
		1:
			if ResourceLoader.exists(map.GENERIC_EVENT_SCENE_PATH):
				new_scene = load(map.GENERIC_EVENT_SCENE_PATH).instantiate()
				var sc = load(map.GENERIC_EVENT_SCRIPT_PATH)
				new_scene.set_script(sc)
				
			if new_scene and ResourceLoader.exists(page.character_path):
				if "custom_texture" in new_scene:
					new_scene.custom_texture = load(page.character_path)
					if new_scene.has_method("update_character_rect"):
						new_scene.update_character_rect.call_deferred(page.character_region)
					
		2:
			if ResourceLoader.exists(map.GENERIC_EVENT_SCENE_PATH):
				new_scene = load(map.GENERIC_EVENT_SCENE_PATH).instantiate()
				var sc = load(map.GENERIC_EVENT_SCRIPT_PATH)
				new_scene.set_script(sc)
				
			if new_scene and ResourceLoader.exists(page.character_path):
				if "custom_scene" in new_scene:
					new_scene.custom_scene = load(page.character_path)

	if not new_scene:
		new_scene = EMPTY_LPC_EVENT.new()
		
	map.add_child(new_scene)
	
	if "display_mode" in new_scene:
		new_scene.display_mode = page.character_type
	
	if "event_data" in new_scene:
		new_scene.event_data = new_character_data
	
	if new_scene.has_method("_build"):
		new_scene._build()
	
	lpc_event = new_scene
	character_data = new_character_data
	page_id = page.page_id
	
	var pos = Vector2i(event.x, event.y)
	if GameManager.game_state and event_id in GameManager.game_state.current_events:
		pos = GameManager.game_state.current_events[event_id].position
		
	map.set_event_position(new_scene, pos, direction)
	update_scene_properties(new_scene, page)
	
	# Force visual update immediately so the first rendered frame has the correct direction
	if new_scene.has_method("run_animation"):
		new_scene.run_animation()
	
	var valid_old_scene = is_instance_valid(old_scene)
	var valid_new_scene = is_instance_valid(new_scene)
	
	if event.fade_page_swap_enabled:
		if old_scene and "is_invalid_event" in old_scene:
			old_scene.is_invalid_event = true
		new_scene.modulate.a = 0
		var t = map.create_tween().set_parallel(true)
		if valid_old_scene:
			t.tween_property(old_scene, "modulate:a", 0.0, 0.25)
		if valid_new_scene:
			if valid_old_scene:
				t.tween_property(new_scene, "modulate:a", 1.0, 0.25).set_delay(0.25)
			else:
				t.tween_property(new_scene, "modulate:a", 1.0, 0.25)
		t.chain().tween_callback(func(): if valid_old_scene: old_scene.queue_free())
	else:
		if valid_old_scene:
			old_scene.queue_free()
	
	_final_update(page)


func _final_update(page: RPGEventPage) -> void:
	if lpc_event:
		lpc_event.z_index = page.z_index
	
		if page.condition.use_pressure:
			lpc_event.z_index = 0
		else:
			lpc_event.z_index = page.z_index


func update_scene_properties(scene: Variant, page: RPGEventPage) -> void:
	scene.name = "Event %s - %s" % [event.name, map.generate_16_digit_id()]
	scene.current_event = event
	scene.movement_current_mode = CharacterBase.MOVEMENTMODE.EVENT
	scene.current_event_page = page
	scene.event_movement_type = page.movement_type
	scene.event_movement_frequency = page.frequency
	scene.movement_speed = page.speed
	
	if page.movement_type == 4:
		scene.route_commands = page.movement_route
	else:
		scene.route_commands = null
	
	scene.current_map_tile_size = map.tile_size
	scene.calculate_grid_move_duration()
	
	if "character_options" in scene:
		scene.character_options.fixed_direction = page.options.fixed_direction
		scene.character_options.walking_animation = page.options.walking_animation
		scene.character_options.idle_animation = page.options.idle_animation
		scene.character_options.passable = page.options.passable
		scene.character_options.movement_type = page.movement_type
		scene.character_options.movement_speed = page.speed
		scene.character_options.movement_frequency = page.frequency

		if page.options.passable:
			scene.call_deferred("_disable_collision_shape", true)
	
	if page.launcher == page.LAUNCHER_MODE.CALLER:
		scene.character_options.passable = true
	
	if not scene.is_in_group("event"):
		scene.add_to_group("event")


func inject_parallel_auto_after_interpreter(page: RPGEventPage) -> void:
	var interpreter_id = "event_" + str(uniq_id)
	var active_interpreter = GameInterpreter.get_interpreter_with_id(interpreter_id)
	
	if active_interpreter and not active_interpreter.is_parallel() and not active_interpreter.is_complete():
		active_interpreter.all_commands_processed.connect(
			func(_i): perform_injection(page, interpreter_id),
			CONNECT_ONE_SHOT
		)
	else:
		if active_interpreter and active_interpreter.is_parallel():
			active_interpreter.end()
		
		perform_injection(page, interpreter_id)


func perform_injection(page: RPGEventPage, interpreter_id: String) -> void:
	if page.launcher == RPGEventPage.LAUNCHER_MODE.AUTOMATIC:
		GameInterpreter.auto_start_automatic_events([{"obj": lpc_event, "commands": page.list, "id": interpreter_id}])
	elif page.launcher == RPGEventPage.LAUNCHER_MODE.PARALLEL:
		GameInterpreter.register_interpreter(lpc_event, page.list, true, interpreter_id)


func is_pressed_by_targets(valid_groups: Array[String]) -> bool:
	if not map or not map.map_layout or not is_instance_valid(lpc_event):
		return false
		
	var current_pos = lpc_event.global_position
	var entities = map.map_layout.get_events_near_position(current_pos)
	var current_tile = lpc_event.get_current_tile()
	
	for entity in entities:
		if entity == lpc_event:
			continue
			
		if entity.has_method("get_current_tile") and entity.get_current_tile() == current_tile:
			for group in valid_groups:
				if entity.is_in_group(group) or entity is RPGVehicle and GameManager.current_player.is_in_group(group):
					return true
					
	return false
