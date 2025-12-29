@tool
extends MarginContainer

@export var preview_time: float =  0.25
@export var preview_pause_time: float =  0.25
@export var normal_tick_animation_time: float =  0.35
@export var critical_tick_animation_time: float =  0.2
@export var final_pause_time: float =  0.5

var main_tween: Tween
var bars_tween: Tween

var simulation: Dictionary
var is_started: bool = false
var critical_in_process: bool = false

@onready var energy_ball: AnimatedSprite2D = %EnergyBall
@onready var success_progress_bar: ColorRect = %SuccessProgressBar
@onready var failure_progress_bar: ColorRect = %FailureProgressBar



signal finished(result: bool)


func _ready() -> void:
	GameManager.set_text_config(self, false)
	_reset_bar_parameters()


func _process(delta: float) -> void:
	if is_started:
		if ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]):
			# Update statistics
			GameManager.game_state.stats.extractions.total_unfinished += 1
			GameManager.play_fx("extraction_cancel")
			GameManager.stop_bgs(0.1)
			finished.emit(false)
			end()
		
		
		if critical_in_process:
			energy_ball.modulate.a = min(1.0, energy_ball.modulate.a + delta * 10)
			var progress_bar = success_progress_bar
			var  mat: ShaderMaterial = progress_bar.get_material()
			var current_progress = mat.get_shader_parameter("progress")
			energy_ball.global_position = Vector2(
				progress_bar.global_position.x + current_progress * progress_bar.size.x,
				progress_bar.global_position.y + progress_bar.size.y * 0.5
			)
		else:
			energy_ball.modulate.a = max(0.0, energy_ball.modulate.a - delta * 10)


func _animate_bar(animation_data: Dictionary) -> void:
	var progress_bar = success_progress_bar if animation_data.get("type", "failure") == "success" else failure_progress_bar
	var  mat: ShaderMaterial = progress_bar.get_material()
	
	var is_critical = animation_data.get("is_critical", false) or animation_data.get("is_super_critical", false)

	var animation_timer: float = critical_tick_animation_time if is_critical else normal_tick_animation_time
	var t = create_tween()
	if is_critical:
		t.tween_callback(
			func():
				GameManager.play_fx("extraction_critical")
				mat.set_shader_parameter("enable_flare", true)
				mat.set_shader_parameter("target_progress", mat.get_shader_parameter("progress"))
				critical_in_process = true
		)
		t.tween_property(mat, "shader_parameter/target_progress", animation_data.current_step, preview_time)
		t.tween_interval(preview_pause_time)
	t.tween_property(mat, "shader_parameter/progress", animation_data.current_step, animation_timer).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if is_critical:
		t.tween_callback(
			func():
				mat.set_shader_parameter("enable_flare", false)
				critical_in_process = false
		)
		t.tween_interval(preview_pause_time)


func _reset_bar_parameters() -> void:
	var mat1: ShaderMaterial = success_progress_bar.get_material()
	var mat2: ShaderMaterial = failure_progress_bar.get_material()
	mat1.set_shader_parameter("target_progress", 0.0)
	mat1.set_shader_parameter("progress", 0.0)
	mat2.set_shader_parameter("target_progress", 0.0)
	mat2.set_shader_parameter("progress", 0.0)
	energy_ball.visible = true
	energy_ball.modulate.a = 0.0


func _set_item_info(data: RPGExtractionItem) -> void:
	# Set Item Name
	var name_label = %ItemName
	name_label.text = data.name
	# Set  Item Level
	var item_level_label = %ItemLevel
	item_level_label.text = " (" + str(data.current_level) + ")"
	
	var profession: RPGProfession = data.get_profession()
	if profession:
		# Set Profession Name
		var profession_label = %Profession
		profession_label.text = profession.name
		var actor_profession_level = GameManager.get_profession_level(profession)
		%PlayerLevel.text = str(actor_profession_level)
		
		var text_color: Color = profession.get_interpolated_color(data.current_level, actor_profession_level)

		# Set Label Colors
		name_label.set("theme_override_colors/font_color", text_color)
		item_level_label.set("theme_override_colors/font_color", text_color)

	# Draw Item Icon
	var scene_path = data.scene_path.get_basename() + "_preview" + ".png"
	if ResourceLoader.exists(scene_path):
		var contents: Texture = ResourceLoader.load(scene_path)
		%Icon.texture = contents


func start(event_data: RPGExtractionItem, extraction_event: GameExtractionItem) -> void:
	if is_started: return
	
	if main_tween:
		main_tween.kill()
	
	_set_item_info(event_data)
	
	# Update statistics
	if not event_data.name in GameManager.game_state.stats.extractions.resources_interactions:
		GameManager.game_state.stats.extractions.resources_interactions[event_data.name] = 1
	else:
		GameManager.game_state.stats.extractions.resources_interactions[event_data.name] += 1
	
	var profession: RPGProfession = event_data.get_profession()
	if profession:
		simulation = extraction_event.harvest(GameManager.get_profession_level(profession))
		
		modulate = Color.TRANSPARENT
		
		main_tween = create_tween()
		main_tween.tween_property(self, "modulate",  Color.WHITE, 0.15)
		main_tween.tween_callback(
			func():
				is_started = true
				var bgs = GameManager.get_fx_path("start_extraction")
				GameManager.play_bgs(bgs, 0.0, 1.0, 0.25)
		)
		
		for step: Dictionary in simulation.steps:
			main_tween.tween_callback(_animate_bar.bind(step))
			if step.get("is_critical", false) or step.get("is_super_critical", false):
				main_tween.tween_interval(preview_time + preview_pause_time * 2 + critical_tick_animation_time)
			else:
				main_tween.tween_interval(preview_time + normal_tick_animation_time)
		
		main_tween.tween_callback(
			func():
				GameManager.stop_bgs(0.1)
				if simulation.final_success:
					GameManager.play_fx("extraction_success")
					_flash_screen()
					if simulation.final_success:
						_add_rewards(event_data)
						GameManager.add_profession_experience(event_data, simulation.experience)
				else:
					_shake_me()
					GameManager.play_fx("extraction_cancel")
		)
		
		main_tween.tween_interval(final_pause_time)
		
		main_tween.tween_callback(
			func():
				finished.emit(simulation.final_success)
				# Update statistics
				for step: Dictionary in simulation.steps:
					if step.get("is_critical", false):
						GameManager.game_state.stats.extractions.critical_performs += 1
					elif step.get("is_super_critical", false):
						GameManager.game_state.stats.extractions.super_critical_performs += 1
				if simulation.final_success:
					GameManager.game_state.stats.extractions.total_success += 1
				else:
					GameManager.game_state.stats.extractions.total_failure += 1
				GameManager.game_state.stats.extractions.total_finished += 1
				end()
		)


func _shake_me() -> void:
	var steps: int = 12
	var max_offset_x: float = 6.0
	var max_offset_y: float = 2.0
	var mod_time = final_pause_time / float(steps)
	var original_position = position
	var t = create_tween()
	for i in steps:
		var p = original_position + Vector2(randf() * max_offset_x, randf() * max_offset_y)
		t.tween_property(self, "position", p, mod_time)
	t.tween_property(self, "position", original_position, 0.001)


func _flash_screen() -> void:
	var main_scene = GameManager.get_main_scene()
	if main_scene:
		var mod_time = final_pause_time / 2.0
		var flash_color = Color(1.0, 1.0, 1.0, 0.294)
		var t = create_tween()
		t.tween_method(
			func(offset: float):
				var color = flash_color
				color.a = flash_color.a * offset
				main_scene.set_flash_color(color, CanvasItemMaterial.BLEND_MODE_ADD)
		, 0.0, 1.0, mod_time)
		t.tween_method(
			func(offset: float):
				var color = flash_color
				color.a = flash_color.a * offset
				main_scene.set_flash_color(color, CanvasItemMaterial.BLEND_MODE_ADD)
		, 1.0, 0.0, mod_time)


func _add_rewards(event_data: RPGExtractionItem) -> void:
	var drop_table: Array[RPGItemDrop] = event_data.drop_table
	if drop_table.size() == 0:
		return
	var roll = randf() * 100
	var valid_items = []
	for item: RPGItemDrop in drop_table:
		if item.percent >= roll:
			var item_id = item.item.item_id
			if item_id > 0:
				var item_type = item.item.data_id
				@warning_ignore("incompatible_ternary")
				var data = \
					RPGSYSTEM.database.items if item_type == 0 \
					else RPGSYSTEM.database.weapons if item_type == 1 \
					else RPGSYSTEM.database.armors
				if data.size() > item_id:
					var level = 1 if item_type == 0 \
						else item.min_level if item.min_level == item.max_level \
						else randi_range(item.min_level, item.max_level)
					var quantity = item.quantity if item.quantity == item.quantity2 \
						else randi_range(item.quantity, item.quantity2)
					valid_items.append({"type": item_type, "id": item_id, "quantity": quantity, "level": level})
	
	if valid_items.is_empty():
		var max_percent = 0
		var best_items = []
		
		for item: RPGItemDrop in drop_table:
			if item.percent > max_percent:
				max_percent = item.percent

		for item: RPGItemDrop in drop_table:
			if item.percent == max_percent:
				var item_id = item.item.item_id
				if item_id > 0:
					var item_type = item.item.data_id
					@warning_ignore("incompatible_ternary")
					var data = \
						RPGSYSTEM.database.items if item_type == 0 \
						else RPGSYSTEM.database.weapons if item_type == 1 \
						else RPGSYSTEM.database.armors
					if data.size() > item_id:
						var level = 0 if item_type == 0 \
							else item.min_level if item.min_level == item.max_level \
							else randi_range(item.min_level, item.max_level)
						var quantity = item.quantity if item.quantity == item.quantity2 \
							else randi_range(item.quantity, item.quantity2)
						best_items.append({"type": item_type, "id": item_id, "quantity": quantity, "level": level})
		
		valid_items = best_items

	for item in valid_items:
		var prefix = tr("Item Adquired") if item.type == 0 \
			else tr("Weapon Adquired") if item.type == 1 \
			else tr("Armor Adquired")
		
		prefix += ": "
			
		if item.type == 0:
			GameManager.add_item_amount(item.id, item.quantity, true, prefix)
		elif item.type == 1:
			GameManager.add_weapon_amount(item.id, item.quantity, item.level, true, prefix)
		else:
			GameManager.add_armor_amount(item.id, item.quantity, item.level, true, prefix)
		
		# Update statistics
		var stats = GameManager.game_state.stats.extractions.items_found
		if  not event_data.required_profession in stats:
			stats[event_data.required_profession] = {}
		var item_id = str(item.type) + "_" + str(item.id)
		if not item_id in stats[event_data.required_profession]:
			stats[event_data.required_profession][item_id] = {}
		if not item.level in stats[event_data.required_profession][item_id]:
			stats[event_data.required_profession][item_id][item.level] = 0
		stats[event_data.required_profession][item_id][item.level] += item.quantity


func end() -> void:
	if not is_started: return
	
	is_started = false
	
	if main_tween:
		main_tween.kill()
	
	main_tween = create_tween()
	main_tween.tween_property(self, "modulate",  Color.TRANSPARENT, 0.15)
	main_tween.tween_callback(queue_free)
