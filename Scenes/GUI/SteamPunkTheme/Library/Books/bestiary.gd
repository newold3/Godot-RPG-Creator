class_name BestiaryPage
extends MarginContainer

@export var monster_database: Array
@onready var page_label: Label = %PaginatorLabel # Tu nodo de texto abajo

var _book: PageFlip2D
var _page_idx: int = -1
var _is_left: bool = false
var _is_index: bool = false

var silhouette_shade_levels: float = 1.21
var reveal_shade_levels: float = 14.0


@warning_ignore("unused_signal")
signal manage_pageflip(give_control_to_book: bool)


func _ready() -> void:
	_book = BookAPI.find_book_controller(self)
	_page_idx = get_meta("page_index", -1)
	
	set_process(false)
	
	if _book:
		_book.ended_page_flip_animation.connect(
			func():
				if _is_index and BookAPI.is_scene_shown(self):
					var came_from_closed = (_book.previous_spread == -1 or _book.previous_spread == _book.total_spreads)
					if came_from_closed:
						set_process(true)
						
						if BookAPI._last_book_spread == -1:
							%ItemList.grab_focus.call_deferred()
		)
	
	%DescriptionContainer.get_v_scroll_bar().focus_mode = Control.FOCUS_CLICK
	%StatsContainer.get_v_scroll_bar().focus_mode = Control.FOCUS_CLICK
	%DropContainer.get_v_scroll_bar().focus_mode = Control.FOCUS_CLICK
	%DescriptionContainer.get_v_scroll_bar().step = %DescriptionContainer.wheel_scroll_speed
	%StatsContainer.get_v_scroll_bar().step = %StatsContainer.wheel_scroll_speed
	%DropContainer.get_v_scroll_bar().step = %DropContainer.wheel_scroll_speed
	%DescriptionContainer.get_v_scroll_bar().focus_entered.connect(_config_hand_in_description)
	%StatsContainer.get_v_scroll_bar().focus_entered.connect(_config_hand_in_stats)
	%DropContainer.get_v_scroll_bar().focus_entered.connect(_config_hand_in_drops)
	
	update_page(_page_idx)


func _config_hand_in_description() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-2, 0), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_stats() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-2, 0), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_drops() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-2, 0), manipulator)
	GameManager.force_show_cursor()


func _on_item_list_focus_entered() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	GameManager.force_show_cursor()


func update_page(page_index: int) -> void:
	# GameManager.force_hide_cursor()
	set_process(false)
	
	_page_idx = page_index
	_is_left = get_meta("is_left", false)
	_is_index = false
	
	if page_label:
		page_label.text = "- %d -" % (_page_idx + 1)
	
	if _page_idx == 0:
		_build_index.call_deferred()
	else:
		_build_monster_entry.call_deferred()


func _get_focusable_controls() -> Array[Control]:
	var controls: Array[Control] = []
	
	if _is_index:
		controls.append(%ItemList)
	elif not _is_left:
		controls.append(%DescriptionContainer.get_v_scroll_bar())
		controls.append(%StatsContainer.get_v_scroll_bar())
		controls.append(%DropContainer.get_v_scroll_bar())
	
	return controls


#func _process(_delta: float) -> void:
	#if _is_index and BookAPI.is_scene_shown(self):
		#if %ItemList.has_focus() and BookAPI._last_book_spread == -1:
			#GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())


func _build_index() -> void:
	_is_index = true
	%IndexContainer.visible = true
	%ContentsLeftContainer.visible = false
	%ContentsRightContainer.visible = false
	if not %ItemList.item_activated.is_connected(_on_item_list_item_activated):
		%ItemList.item_activated.connect(_on_item_list_item_activated)
	%ItemList.disabled = false
	
	var items: Array[Dictionary] = []
	var enemies = RPGSYSTEM.database.enemies
	
	var grouped_enemies = {}
	var rarity_names = {}
	var rarity_order = []
	
	for i in range(1, enemies.size()):
		var monster = enemies[i]
		if not monster:
			continue
		var r_type = monster.rarity_type
		var r_name = "Unknown"
		var type_data = RPGSYSTEM.get_type_data("enemy", r_type)
		if type_data and type_data.has("name"):
			r_name = type_data.name
		else:
			r_name = str(r_type)
			
		if not grouped_enemies.has(r_type):
			grouped_enemies[r_type] = []
			rarity_names[r_type] = r_name
			rarity_order.append(r_type)
			
		grouped_enemies[r_type].append({
			"monster": monster,
			"original_index": i
		})
		
	for r_type in rarity_order:
		# 1. Rarity title (Red color)
		items.append({
			"name": rarity_names[r_type],
			"is_title": true,
			"text_color": Color.RED
		})
		# 2. Empty title (Red color just in case)
		items.append({
			"name": "",
			"is_title": true,
			"text_color": Color.RED
		})
		# 3. Enemies of this rarity ordered by database ID (original_index)
		for entry in grouped_enemies[r_type]:
			var monster = entry["monster"]
			var idx = entry["original_index"]
			var dict = {}
			
			var killed = false
			if GameManager.game_state:
				var raw_death_counter = GameManager.game_state.find_stat("enemy_kills.%s" % monster._uniq_id)
				var death_counter = raw_death_counter if raw_death_counter != null else 0
				if death_counter > 0:
					killed = true
					
			if killed:
				dict["name"] = monster.name
				if monster.icon and not monster.icon.is_empty():
					dict["icon"] = monster.icon.get_texture()
			else:
				dict["name"] = _obfuscate_text(monster.name)
				
			dict["target_page"] = str((idx - 1) * 2 + 2)
			items.append(dict)
			
	%ItemList.add_items(items)
	
	if _book and (_book.previous_spread == -1 or _book.previous_spread == _book.total_spreads):
		%ItemList.grab_focus.call_deferred()


func _obfuscate_text(input_text: String) -> String:
	var result: String = ""
	
	for i in range(input_text.length()):
		if input_text[i] == " ":
			result += " "
		else:
			result += "?"
			
	return result


func _build_monster_entry() -> void:
	%IndexContainer.visible = false
	%ContentsLeftContainer.visible = false
	%ContentsRightContainer.visible = false
	
	@warning_ignore("integer_division")
	var monster_id = int((_page_idx - 1) / 2) + 1
	
	var monster: RPGEnemy = RPGSYSTEM.get_data("enemies", monster_id)
	
	if monster:
		var uid = monster._uniq_id
		var raw_death_counter = GameManager.game_state.find_stat("enemy_kills.%s" % uid)
		var death_counter: int = raw_death_counter if raw_death_counter != null else 0

		if _is_left:
			if AssetManager.file_exists(monster.battler):
				%MonsterImage.texture = load(monster.battler)
			else:
				%MonsterImage.texture = null
			
			var monster_type = monster.rarity_type
			var type_data = RPGSYSTEM.get_type_data("enemy", monster_type)
			%MosterType.text = type_data.name
			%IconType.texture = type_data.icon
			%MurderedKills.text = GameManager.get_number_formatted(death_counter)
				
			var mat: ShaderMaterial = %MonsterImage.get_material()
			if death_counter > 0:
				%MonsterName.text = monster.name.capitalize()
				mat.set_shader_parameter("pencil_strength", 0.658)
				mat.set_shader_parameter("shade_levels", 14.0)
				%MonsterTypeContainer.visible = true
				%MurderedContainer.visible = true
			else:
				mat.set_shader_parameter("pencil_strength", 0.071)
				mat.set_shader_parameter("shade_levels", 1.197)
				%MonsterName.text = _obfuscate_text(monster.name)
				%MonsterTypeContainer.visible = false
				%MurderedContainer.visible = false
				
		else:
			%DropCanvas.has_been_killed = death_counter > 0
			
			var icon_path: String = RPGSYSTEM.database.system.currency_info.get("icon", "")
			if AssetManager.exists(icon_path):
				%GoldIcon.texture = load(icon_path)
			else:
				%GoldIcon.texture = null
			var enemy = GameEnemy.new(monster_id)
			%Stats.set_enemy.call_deferred(enemy)
			if death_counter > 0:
				%Description.text = monster.description
				%Stats.set_hide_mode(false)
				%ExperienceValue.text = GameManager.get_number_formatted(monster.experience_reward)
				var g1 = monster.gold_reward_from
				var g2 = monster.gold_reward_to
				if g1 == g2:
					%GoldValue.text = GameManager.get_number_formatted(g1)
				else:
					%GoldValue.text = GameManager.get_number_formatted(g1) + \
						" ∼ " + \
						GameManager.get_number_formatted(g2)
				var drops = monster.get_rewards()
				if not drops.is_empty():
					%DropCanvas.set_items(drops)
					%EmptyDrop.visible = false
				else:
					%DropCanvas.clear()
					%EmptyDrop.visible = true
					
			else:
				%Description.text = "Unknown Enemy."
				if not monster.unknown_description.is_empty():
					%Description.text += "\n\n" + monster.unknown_description
				%ExperienceValue.text = "?"
				%GoldValue.text = "?"
				%Stats.set_hide_mode(true)
				%DropCanvas.clear()
				%EmptyDrop.visible = true
	
	if _is_left:
		%ContentsLeftContainer.visible = true
	else:
		%ContentsRightContainer.visible = true


func _on_item_list_item_activated(index: int) -> void:
	var item_data = %ItemList.get_item_data(index)
	if item_data.has("target_page"):
		var target_page = int(item_data["target_page"])
		BookAPI.go_to_page(target_page, BookAPI.JumpTarget.CONTENT_PAGE, true, _book)


func _on_return_to_index_pressed() -> void:
	BookAPI.go_to_page(1, BookAPI.JumpTarget.CONTENT_PAGE, true, _book)


func _on_button_pressed() -> void:
	print("click")
