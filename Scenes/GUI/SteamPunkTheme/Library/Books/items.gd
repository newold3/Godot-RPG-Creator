class_name ItemsPage
extends MarginContainer

@onready var page_label: Label = %PaginatorLabel

var _book: PageFlip2D
var _page_idx: int = -1
var _is_left: bool = false
var _is_index: bool = false

var _cached_items: Array = []

var _traits_panel_script
var _effects_panel_script

@warning_ignore("unused_signal")
signal manage_pageflip(give_control_to_book: bool)

func _ready() -> void:
	_book = BookAPI.find_book_controller(self)
	_page_idx = get_meta("page_index", -1)
	
	_traits_panel_script = load("res://addons/RPGData/Scripts/traits_panel.gd").new()
	_traits_panel_script.database = RPGSYSTEM.database
	
	_effects_panel_script = load("res://addons/RPGData/Scripts/effects_panel.gd").new()
	_effects_panel_script.database = RPGSYSTEM.database
	
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
		_build_item_entry.call_deferred()

func _get_focusable_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if _is_index:
		controls.append(%ItemList)
	return controls

func _get_all_items() -> Array:
	if not _cached_items.is_empty():
		return _cached_items
		
	var list = []
	var db = RPGSYSTEM.database
	if not db:
		return list
		
	# 1. Items
	for item in db.items:
		if item and item.id > 0:
			list.append({
				"type": "item",
				"item": item,
				"unlocked": GameManager.is_item_unlocked(0, item.id),
				"icon": item.get_icon()
			})
				
	# 2. Weapons
	for weapon in db.weapons:
		if weapon and weapon.id > 0:
			list.append({
				"type": "weapon",
				"item": weapon,
				"unlocked": GameManager.is_item_unlocked(1, weapon.id),
				"icon": weapon.get_icon()
			})
			
	# 3. Armors
	for armor in db.armors:
		if armor and armor.id > 0:
			list.append({
				"type": "armor",
				"item": armor,
				"unlocked": GameManager.is_item_unlocked(2, armor.id),
				"icon": armor.get_icon()
			})
			
	# 4. Sets/Costumes
	for costume in db.costumes:
		if costume and costume.id > 0:
			list.append({
				"type": "set",
				"item": costume,
				"unlocked": GameManager.is_item_unlocked(3, costume.id),
				"icon": costume.get_icon()
			})
	
	_cached_items = list
	return list

func _build_index() -> void:
	_is_index = true
	%IndexContainer.visible = true
	%ContentsLeftContainer.visible = false
	%ContentsRightContainer.visible = false
	
	%IndexContainer.get_node("VBoxContainer/Title").text = "Inventario"
	%IndexContainer.get_node("VBoxContainer/Header/HBox/Col1").text = "Objeto"
	
	if not %ItemList.item_activated.is_connected(_on_item_list_item_activated):
		%ItemList.item_activated.connect(_on_item_list_item_activated)
	%ItemList.disabled = false
	
	var all_items = _get_all_items()
	var list_items: Array[Dictionary] = []
	
	if all_items.is_empty():
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
		
		var cat_items = []
		for r_idx in range(all_items.size()):
			var r = all_items[r_idx]
			if r.type == cat_type:
				cat_items.append({
					"data": r,
					"page": r_idx * 2 + 2
				})
				
		if cat_items.is_empty():
			continue
			
		list_items.append({
			"name": cat_name,
			"is_title": true,
			"text_color": Color.RED
		})
		
		for entry in cat_items:
			var r = entry.data
			var page = entry.page
			var dict = {}
			
			if r.unlocked:
				dict["name"] = r.item.name
				dict["icon"] = r.icon
				dict["target_page"] = str(page)
			else:
				dict["name"] = "???"
				dict["icon"] = null
				dict["target_page"] = str(page)
				dict["text_color"] = Color.DIM_GRAY
				
			list_items.append(dict)
			
	%ItemList.add_items(list_items)
	
	if _book and (_book.previous_spread == -1 or _book.previous_spread == _book.total_spreads):
		%ItemList.grab_focus.call_deferred()

func _build_item_entry() -> void:
	%IndexContainer.visible = false
	%ContentsLeftContainer.visible = false
	%ContentsRightContainer.visible = false
	
	@warning_ignore("integer_division")
	var item_idx = int((_page_idx - 1) / 2)
	var all_items = _get_all_items()
	
	if item_idx < 0 or item_idx >= all_items.size():
		return
		
	var r = all_items[item_idx]
	var unlocked = r.unlocked
	
	if _is_left:
		%ContentsLeftContainer.visible = true
		if unlocked:
			%RecipeName.text = r.item.name
			%RecipeImage.texture = r.icon
			%RecipeImageShadow.texture = r.icon
			if r.icon:
				call_deferred("_update_icon_shadow")
		else:
			%RecipeName.text = "???"
			%RecipeImage.texture = null
			%RecipeImageShadow.texture = null
	else:
		%ContentsRightContainer.visible = true
		
		var info_canvas = %InfoCanvas
		
		if not unlocked:
			%ItemDescription.text = "Objeto desconocido."
			var info: Array[Dictionary] = []
			if info_canvas: info_canvas.set_items(info)
			return
			
		var tex = null
		if r.type == "set":
			if r.item.icon and not r.item.icon.is_empty():
				if AssetManager.exists(r.item.icon):
					tex = load(r.item.icon)
		else:
			if r.item.icon:
				tex = r.item.icon.get_texture()
		%ItemDescription.text = r.item.description
		
		var stats_data: Array[Dictionary] = []
		
		var add_title = func(text: String):
			stats_data.append({"is_title": true, "text": text, "value": ""})
			
		var add_stat = func(text: String, value: String = ""):
			stats_data.append({"is_title": false, "text": text, "value": value})
		
		if r.type == "item":
			add_title.call("Propiedades")
			
			var itm: RPGItem = r.item
			add_stat.call("Consumible:", "Sí" if itm.consumable else "No")
			add_stat.call("Precio:", str(itm.price))
			
			# Scope
			var scope_str = "Usuario"
			if itm.scope.number == 1: scope_str = "Todos"
			elif itm.scope.number == 2: scope_str = "Aleatorio"
			add_stat.call("Objetivo:", scope_str)
			
			# Damage / Recover
			if itm.damage.type != 0:
				var types = ["None", "Daño HP", "Daño MP", "Recuperar HP", "Recuperar MP", "Drenar HP", "Drenar MP"]
				var type_name = types[itm.damage.type] if itm.damage.type < types.size() else "Daño"
				add_stat.call("Efecto Base:", type_name)
			
			# Effects
			if itm.effects.size() > 0:
				add_title.call("Efectos")
				for eff in itm.effects:
					var cols = _effects_panel_script.get_column(eff)
					if cols.size() > 1:
						add_stat.call(cols[0], cols[1])
					elif cols.size() > 0:
						add_stat.call(cols[0], "")
			
		elif r.type == "weapon" or r.type == "armor" or r.type == "set":
			if r.type == "weapon" or r.type == "armor":
				add_title.call("Parámetros")
				var param_names = RPGActor.get_parameter_list(false)
				var base_params = r.item.params
				var i = 0
				for p in base_params:
					if p != 0 and i < param_names.size():
						add_stat.call(param_names[i], ("+" if p > 0 else "") + str(p))
					i += 1
					
			add_title.call("Atributos (Traits)")
			var traits = r.item.traits
			if traits.is_empty():
				add_stat.call("Ninguno", "")
			else:
				for tr in traits:
					var cols = _traits_panel_script.get_column(tr)
					if cols.size() > 1:
						add_stat.call(cols[0], cols[1])
					elif cols.size() > 0:
						add_stat.call(cols[0], "")

		if info_canvas:
			info_canvas.set_items(stats_data)

func _update_icon_shadow() -> void:
	var target_w: float = %RecipeImage.size.x * 1.3
	var target_h: float = %RecipeImage.size.y * 0.7
	%RecipeImageShadow.size = Vector2(target_w, target_h)
	%RecipeImageShadow.position = Vector2i(
		%RecipeImage.size.x * 0.5 - target_w * 0.5,
		%RecipeImage.size.y - target_h * 0.95
	)

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
