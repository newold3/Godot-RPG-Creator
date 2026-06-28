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
	
	GameManager.force_hide_cursor()
	set_process(false)
	
	if _book:
		_book.ended_page_flip_animation.connect(
			func():
				if _is_index and BookAPI.is_scene_shown(self):
					set_process(true)
					%ItemList.grab_focus.call_deferred()
		)
	
	update_page(_page_idx)


func update_page(page_index: int) -> void:
	GameManager.force_hide_cursor()
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


func _process(_delta: float) -> void:
	if _is_index and BookAPI.is_scene_shown(self):
		GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())


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
	
	for i in range(1, enemies.size()):
		var monster = enemies[i]
		if not monster:
			continue
			
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
			
		dict["target_page"] = str((i - 1) * 2 + 2)
		items.append(dict)
		
	%ItemList.add_items(items)
	
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
	var target_page = (index * 2) + 2
	BookAPI.go_to_page(target_page, BookAPI.JumpTarget.CONTENT_PAGE, true, _book)


func _on_return_to_index_pressed() -> void:
	BookAPI.go_to_page(1, BookAPI.JumpTarget.CONTENT_PAGE, true, _book)


func _on_button_pressed() -> void:
	print("click")
