class_name GuiCoreBestiaryPage
extends MarginContainer

#region ExportsAndVariables
@export var monster_database: Array
@onready var page_label: Label = %PaginatorLabel

var _book: PageFlip2D
var _page_idx: int = -1
var _is_left: bool = false
var _is_index: bool = false

@warning_ignore("unused_signal")
signal manage_pageflip(give_control_to_book: bool)
#endregion



#region VirtualPresentationHooks
func _apply_monster_shader(_mat: ShaderMaterial, _is_killed: bool) -> void:
	pass


func _config_hand_in_description() -> void:
	pass


func _config_hand_in_stats() -> void:
	pass


func _config_hand_in_drops() -> void:
	pass


func _config_hand_in_item_list() -> void:
	pass
#endregion



#region Lifecycle
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
						if BookAPI._last_book_spread == -1 and has_node("%ItemList"):
							get_node("%ItemList").grab_focus.call_deferred()
		)
	
	if has_node("%DescriptionContainer"):
		var dc = get_node("%DescriptionContainer")
		dc.get_v_scroll_bar().focus_mode = Control.FOCUS_CLICK
		dc.get_v_scroll_bar().step = dc.wheel_scroll_speed
		dc.get_v_scroll_bar().focus_entered.connect(_on_description_focus_entered)
	if has_node("%StatsContainer"):
		var sc = get_node("%StatsContainer")
		sc.get_v_scroll_bar().focus_mode = Control.FOCUS_CLICK
		sc.get_v_scroll_bar().step = sc.wheel_scroll_speed
		sc.get_v_scroll_bar().focus_entered.connect(_on_stats_focus_entered)
	if has_node("%DropContainer"):
		var drc = get_node("%DropContainer")
		drc.get_v_scroll_bar().focus_mode = Control.FOCUS_CLICK
		drc.get_v_scroll_bar().step = drc.wheel_scroll_speed
		drc.get_v_scroll_bar().focus_entered.connect(_on_drops_focus_entered)
	
	update_page(_page_idx)


func _on_description_focus_entered() -> void:
	_config_hand_in_description()


func _on_stats_focus_entered() -> void:
	_config_hand_in_stats()


func _on_drops_focus_entered() -> void:
	_config_hand_in_drops()


func _on_item_list_focus_entered() -> void:
	_config_hand_in_item_list()
#endregion



#region PageBuilding
func update_page(page_index: int) -> void:
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
	if _is_index and has_node("%ItemList"):
		controls.append(get_node("%ItemList"))
	elif not _is_left:
		if has_node("%DescriptionContainer"): controls.append(get_node("%DescriptionContainer").get_v_scroll_bar())
		if has_node("%StatsContainer"): controls.append(get_node("%StatsContainer").get_v_scroll_bar())
		if has_node("%DropContainer"): controls.append(get_node("%DropContainer").get_v_scroll_bar())
	return controls


func _build_index() -> void:
	_is_index = true
	if has_node("%IndexContainer"): get_node("%IndexContainer").visible = true
	if has_node("%ContentsLeftContainer"): get_node("%ContentsLeftContainer").visible = false
	if has_node("%ContentsRightContainer"): get_node("%ContentsRightContainer").visible = false
	
	var item_list = get_node("%ItemList") if has_node("%ItemList") else null
	if item_list:
		if not item_list.item_activated.is_connected(_on_item_list_item_activated):
			item_list.item_activated.connect(_on_item_list_item_activated)
		item_list.disabled = false
	
	var items: Array[Dictionary] = []
	var enemies = RPGSYSTEM.database.enemies
	
	var grouped_enemies = {}
	var rarity_names = {}
	var rarity_order = []
	
	for i in range(1, enemies.size()):
		var monster = enemies[i]
		if not monster or ("separator" in monster and monster.separator != null):
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
		items.append({
			"name": rarity_names[r_type],
			"is_title": true,
			"text_color": Color.RED
		})
		items.append({
			"name": "",
			"is_title": true,
			"text_color": Color.RED
		})
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
			
	if item_list and item_list.has_method("add_items"):
		item_list.add_items(items)
	
	if _book and (_book.previous_spread == -1 or _book.previous_spread == _book.total_spreads):
		if item_list:
			item_list.grab_focus.call_deferred()


func _obfuscate_text(input_text: String) -> String:
	var result: String = ""
	for i in range(input_text.length()):
		if input_text[i] == " ":
			result += " "
		else:
			result += "?"
	return result


func _build_monster_entry() -> void:
	if has_node("%IndexContainer"): get_node("%IndexContainer").visible = false
	if has_node("%ContentsLeftContainer"): get_node("%ContentsLeftContainer").visible = false
	if has_node("%ContentsRightContainer"): get_node("%ContentsRightContainer").visible = false
	
	@warning_ignore("integer_division")
	var monster_id = int((_page_idx - 1) / 2) + 1
	
	var monster: RPGEnemy = RPGSYSTEM.get_data("enemies", monster_id)
	
	if monster:
		var uid = monster._uniq_id
		var raw_death_counter = GameManager.game_state.find_stat("enemy_kills.%s" % uid) if GameManager.game_state else null
		var death_counter: int = raw_death_counter if raw_death_counter != null else 0

		if _is_left:
			if AssetManager.file_exists(monster.battler) and has_node("%MonsterImage"):
				get_node("%MonsterImage").texture = load(monster.battler)
			elif has_node("%MonsterImage"):
				get_node("%MonsterImage").texture = null
			
			var monster_type = monster.rarity_type
			var type_data = RPGSYSTEM.get_type_data("enemy", monster_type)
			if has_node("%MosterType"): get_node("%MosterType").text = type_data.name if type_data else ""
			if has_node("%IconType"): get_node("%IconType").texture = type_data.icon if type_data else null
			if has_node("%MurderedKills"): get_node("%MurderedKills").text = GameManager.get_number_formatted(death_counter)
				
			var mat: ShaderMaterial = get_node("%MonsterImage").get_material() if has_node("%MonsterImage") else null
			_apply_monster_shader(mat, death_counter > 0)
			
			if death_counter > 0:
				if has_node("%MonsterName"): get_node("%MonsterName").text = monster.name.capitalize()
				if has_node("%MonsterTypeContainer"): get_node("%MonsterTypeContainer").visible = true
				if has_node("%MurderedContainer"): get_node("%MurderedContainer").visible = true
			else:
				if has_node("%MonsterName"): get_node("%MonsterName").text = _obfuscate_text(monster.name)
				if has_node("%MonsterTypeContainer"): get_node("%MonsterTypeContainer").visible = false
				if has_node("%MurderedContainer"): get_node("%MurderedContainer").visible = false
				
		else:
			if has_node("%DropCanvas"):
				get_node("%DropCanvas").has_been_killed = death_counter > 0
			
			var icon_path: String = RPGSYSTEM.database.system.currency_info.get("icon", "")
			if has_node("%GoldIcon"):
				if AssetManager.exists(icon_path):
					get_node("%GoldIcon").texture = load(icon_path)
				else:
					get_node("%GoldIcon").texture = null
			var enemy = GameEnemy.new(monster_id)
			if has_node("%Stats"):
				get_node("%Stats").set_enemy.call_deferred(enemy)
			if death_counter > 0:
				if has_node("%Description"): get_node("%Description").text = monster.description
				if has_node("%Stats") and get_node("%Stats").has_method("set_hide_mode"):
					get_node("%Stats").set_hide_mode(false)
				if has_node("%ExperienceValue"): get_node("%ExperienceValue").text = GameManager.get_number_formatted(monster.experience_reward)
				var g1 = monster.gold_reward_from
				var g2 = monster.gold_reward_to
				if has_node("%GoldValue"):
					if g1 == g2:
						get_node("%GoldValue").text = GameManager.get_number_formatted(g1)
					else:
						get_node("%GoldValue").text = GameManager.get_number_formatted(g1) + " ∼ " + GameManager.get_number_formatted(g2)
				var drops = monster.get_rewards()
				if not drops.is_empty():
					if has_node("%DropCanvas"): get_node("%DropCanvas").set_items(drops)
					if has_node("%EmptyDrop"): get_node("%EmptyDrop").visible = false
				else:
					if has_node("%DropCanvas"): get_node("%DropCanvas").clear()
					if has_node("%EmptyDrop"): get_node("%EmptyDrop").visible = true
					
			else:
				if has_node("%Description"):
					get_node("%Description").text = "Unknown Enemy."
					if not monster.unknown_description.is_empty():
						get_node("%Description").text += "\n\n" + monster.unknown_description
				if has_node("%ExperienceValue"): get_node("%ExperienceValue").text = "?"
				if has_node("%GoldValue"): get_node("%GoldValue").text = "?"
				if has_node("%Stats") and get_node("%Stats").has_method("set_hide_mode"):
					get_node("%Stats").set_hide_mode(true)
				if has_node("%DropCanvas"): get_node("%DropCanvas").clear()
				if has_node("%EmptyDrop"): get_node("%EmptyDrop").visible = true
	
	if _is_left:
		if has_node("%ContentsLeftContainer"): get_node("%ContentsLeftContainer").visible = true
	else:
		if has_node("%ContentsRightContainer"): get_node("%ContentsRightContainer").visible = true


func _on_item_list_item_activated(index: int) -> void:
	var item_list = get_node("%ItemList") if has_node("%ItemList") else null
	if item_list and item_list.has_method("get_item_data"):
		var item_data = item_list.get_item_data(index)
		if item_data.has("target_page"):
			var target_page = int(item_data["target_page"])
			BookAPI.go_to_page(target_page, BookAPI.JumpTarget.CONTENT_PAGE, true, _book)


func _on_return_to_index_pressed() -> void:
	BookAPI.go_to_page(1, BookAPI.JumpTarget.CONTENT_PAGE, true, _book)


func _on_button_pressed() -> void:
	pass
#endregion
