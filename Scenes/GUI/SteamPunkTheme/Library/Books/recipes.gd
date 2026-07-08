class_name RecipesPage
extends MarginContainer

@onready var page_label: Label = %PaginatorLabel

var _book: PageFlip2D
var _page_idx: int = -1
var _is_left: bool = false
var _is_index: bool = false

var _cached_recipes: Array = []

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
	
	update_page(_page_idx)


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
		_build_recipe_entry.call_deferred()


func _get_focusable_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if _is_index:
		controls.append(%ItemList)
	return controls


func _get_all_recipes() -> Array:
	if not _cached_recipes.is_empty():
		return _cached_recipes
		
	var list = []
	var db = RPGSYSTEM.database
	if not db:
		return list
		
	# 1. Items
	for item in db.items:
		if item and not item.recipes.is_empty():
			for i in range(item.recipes.size()):
				var recipe = item.recipes[i]
				if GameManager.is_recipe_learned(0, item._uniq_id, i):
					list.append({
						"type": "item",
						"item": item,
						"quantity": recipe.quantity,
						"recipe": recipe,
						"icon": item.get_icon(),
						"craft_materials": recipe.get_materials(),
						"craft_cost": recipe.price,
						"disassemble_materials": item.get_disassemble_materials(),
						"disassemble_cost": item.disassemble_cost
					})
				
	# 2. Weapons
	for weapon in db.weapons:
		if weapon:
			if GameManager.is_recipe_learned(1, weapon._uniq_id):
				list.append({
					"type": "weapon",
					"item": weapon,
					"recipe": weapon,
					"quantity": 1,
					"icon": weapon.get_icon(),
					"craft_materials": weapon.get_craft_materials(),
					"craft_cost": weapon.craft_cost,
					"disassemble_materials": weapon.get_disassemble_materials(),
					"disassemble_cost": weapon.disassemble_cost
				})
			
	# 3. Armors
	for armor in db.armors:
		if armor:
			if GameManager.is_recipe_learned(2, armor._uniq_id):
				list.append({
					"type": "armor",
					"item": armor,
					"recipe": armor,
					"quantity": 1,
					"icon": armor.get_icon(),
					"craft_materials": armor.get_craft_materials(),
					"craft_cost": armor.craft_cost,
					"disassemble_materials": armor.get_disassemble_materials(),
					"disassemble_cost": armor.disassemble_cost
				})
			
	# 4. Sets/Costumes
	for costume in db.costumes:
		if costume:
			if GameManager.is_recipe_learned(2, costume._uniq_id):
				list.append({
					"type": "set",
					"item": costume,
					"recipe": costume,
					"quantity": 1,
					"icon": costume.get_icon(),
					"craft_materials": costume.get_craft_materials(),
					"craft_cost": costume.craft_cost,
					"disassemble_materials": costume.get_disassemble_materials(),
					"disassemble_cost": costume.disassemble_cost
				})
	
	_cached_recipes = list
	return list


func _is_recipe_learned(entry: Dictionary) -> bool:
	if not GameManager or not GameManager.game_state:
		return false
	if GameManager.game_state.crafting_recipes.get(entry.recipe_key, false):
		return true
	if "learned_by_default" in entry.recipe and entry.recipe.learned_by_default:
		return true
	return false


func _build_index() -> void:
	_is_index = true
	%IndexContainer.visible = true
	%ContentsLeftContainer.visible = false
	%ContentsRightContainer.visible = false
	
	if not %ItemList.item_activated.is_connected(_on_item_list_item_activated):
		%ItemList.item_activated.connect(_on_item_list_item_activated)
	%ItemList.disabled = false
	
	var all_recipes = _get_all_recipes()
	var list_items: Array[Dictionary] = []
	
	if all_recipes.is_empty():
		list_items.append({
			"name": "No existen registros.",
			"is_title": true,
			"text_color": Color.GRAY,
			"selectable": false
		})
		%ItemList.add_items(list_items)
		if _book and (_book.previous_spread == -1 or _book.previous_spread == _book.total_spreads):
			%ItemList.grab_focus.call_deferred()
		return
	
	var categories = ["Items", "Armas", "Armaduras", "Sets"]
	var category_types = ["item", "weapon", "armor", "set"]
	
	for cat_idx in range(categories.size()):
		var cat_name = categories[cat_idx]
		var cat_type = category_types[cat_idx]
		
		var cat_recipes = []
		for r_idx in range(all_recipes.size()):
			var r = all_recipes[r_idx]
			if r.type == cat_type:
				cat_recipes.append({
					"recipe": r,
					"page": r_idx * 2 + 2
				})
				
		if cat_recipes.is_empty():
			continue
			
		list_items.append({
			"name": cat_name,
			"is_title": true,
			"text_color": Color.RED
		})
		
		for entry in cat_recipes:
			var r = entry.recipe
			var page = entry.page
			var dict = {}
			
			dict["name"] = r.recipe.name
			dict["icon"] = r.icon
			dict["target_page"] = str(page)
			list_items.append(dict)
			
	%ItemList.add_items(list_items)
	
	if _book and (_book.previous_spread == -1 or _book.previous_spread == _book.total_spreads):
		%ItemList.grab_focus.call_deferred()


func _build_recipe_entry() -> void:
	%IndexContainer.visible = false
	%ContentsLeftContainer.visible = false
	%ContentsRightContainer.visible = false
	
	@warning_ignore("integer_division")
	var recipe_idx = int((_page_idx - 1) / 2)
	var all_recipes = _get_all_recipes()
	
	if recipe_idx < 0 or recipe_idx >= all_recipes.size():
		return
		
	var r = all_recipes[recipe_idx]
	
	if _is_left:
		%ContentsLeftContainer.visible = true
		%RecipeName.text = r.recipe.name
		%RecipeImage.texture = r.icon
		%RecipeImageShadow.texture = r.icon
		
		if r.icon:
			call_deferred("_update_icon_shadow")
	else:
		%ContentsRightContainer.visible = true
		%ItemName.text = r.item.name
		%ItemQuantity.text = "x %s" % r.quantity
		
		var icon_path: String = RPGSYSTEM.database.system.currency_info.get("icon", "")
		if AssetManager.exists(icon_path):
			%GoldIconList1.texture = load(icon_path)
			%GoldIconList2.texture = load(icon_path)
		else:
			%GoldIconList1.texture = null
			%GoldIconList2.texture = null
		
		var tex = null
		if r.type == "set":
			if r.item.icon and not r.item.icon.is_empty():
				if AssetManager.exists(r.item.icon):
					tex = load(r.item.icon)
		else:
			if r.item.icon:
				tex = r.item.icon.get_texture()
		%ItemIcon.texture = tex
		%ItemDescription.text = r.item.description
		
		%CraftList.percent_mode = 3 # NEVER_SHOW
		%DissasembleList.percent_mode = 3 # NEVER_SHOW
		
		%CraftList.set_items(_format_materials_for_list(r.craft_materials))
		%DissasembleList.set_items(_format_materials_for_list(r.disassemble_materials))
		
		%GoldValueList1.text = str(r.craft_cost)
		%GoldValueList2.text = str(r.disassemble_cost)
		
		%EmptyCraftList.visible = r.craft_materials.is_empty()
		%EmptyDissasembleList.visible = r.disassemble_materials.is_empty()


func _update_icon_shadow() -> void:
	var target_w: float = %RecipeImage.size.x * 1.3
	var target_h: float = %RecipeImage.size.y * 0.7
	%RecipeImageShadow.size = Vector2(target_w, target_h)

	%RecipeImageShadow.position = Vector2i(
		%RecipeImage.size.x * 0.5 - target_w * 0.5,
		%RecipeImage.size.y - target_h * 0.95
	)


func _format_materials_for_list(materials: Array) -> Array[Dictionary]:
	var formatted_list: Array[Dictionary] = []
	for mat in materials:
		if typeof(mat) != TYPE_DICTIONARY:
			continue
			
		var quantity: int = mat.get("quantity", 1)
		var item = mat.get("item", null)
		var is_unlocked: bool = mat.get("unlocked", true)
		
		var in_inventory: int = 0
		if item is RPGItem:
			in_inventory = GameManager.get_item_amount(item._uniq_id)
		elif item is RPGWeapon:
			in_inventory = GameManager.get_weapon_amount(item._uniq_id)
		elif item is RPGArmor:
			in_inventory = GameManager.get_armor_amount(item._uniq_id)
		elif item is RPGCostume:
			in_inventory = GameManager.get_costume_amount(item._uniq_id)
		
		var tex = null
		var item_name = "???"
		var color = null
		var unavailable_color: String = "ffb5a9"
		
		if item:
			if is_unlocked:
				item_name = item.name
				if item.has_method("get_icon"):
					tex = item.get_icon()
				elif "icon" in item and item.icon:
					tex = item.icon.get_texture()
					
				if in_inventory < quantity:
					color = unavailable_color
			else:
				color = unavailable_color
		
		var dict = {
			"icon": tex,
			"name": item_name,
			"min_quantity": quantity,
			"max_quantity": quantity
		}
		
		if color:
			dict["color"] = color
			
		if item and is_unlocked:
			dict["possessed_quantity"] = in_inventory
			
		formatted_list.append(dict)
	return formatted_list


func _on_item_list_item_activated(index: int) -> void:
	var item_data = %ItemList.get_item_data(index)
	if item_data.has("target_page"):
		var target_page = int(item_data["target_page"])
		BookAPI.go_to_page(target_page, BookAPI.JumpTarget.CONTENT_PAGE, true, _book)


func _on_return_to_index_pressed() -> void:
	BookAPI.go_to_page(1, BookAPI.JumpTarget.CONTENT_PAGE, true, _book)


func _on_button_pressed() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	GameManager.force_show_cursor()


func _on_item_list_focus_entered() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	GameManager.force_show_cursor()
