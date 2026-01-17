@tool
extends MarginContainer

#region Script Control Variables
var data: Dictionary

var current_character: EditorCharacterData = EditorCharacterData.new()

var current_palettes: Dictionary

var enable_pick_random_color: bool = false

var palette_dialog_need_set_to_visible: bool

var busy: bool = false

var is_started: bool = false

var saving_container

var main_dialog

var _thread: Thread = null

var backup_visibility
var backup_animation

var data_is_ready: bool = false

var _visibility_dirty: bool = false

const ACTOR_BASE_SCENE = preload("res://addons/rpg_character_creator/Other/actor_base_scene.tscn")
const GENERIC_LPC_BASE_SCENE = preload("res://addons/rpg_character_creator/Other/generic_lpc_base_scene.tscn")
const PARTS_ROOT_DIR = "res://Assets/Parts"
const PARTS_MANIFEST_PATH = PARTS_ROOT_DIR + "/parts_manifest.json"

# Preview Parts
const PREVIEW_SIZE = Vector2i(36, 36)
@export var preview_character: EditorCharacter = null
var preview_busy: bool = false
var preview_cache: Dictionary = {}
var preview_queue: Array = []
var high_preview_queue: Array = []
var ultra_high_preview_queue: Array = []
var current_queue_keys: Dictionary = {}
var rebuild_timer: Dictionary = {}
var is_generating_previews: bool = false

@onready var palette_dialog: LPCPaletteDialog = %PaletteDialog

signal data_loaded()

#endregion


func _ready() -> void:
	%AnimatedSprite2D.play("default")
	pass


func start() -> void:
	data_loaded.connect(_on_data_loaded)
	%EditorCharacter.current_data = current_character
	%LoadingData.visible = true
	set_connections()
	_load_initial_data_in_thread()
	palette_dialog.visible = false
	#set_data()
	#is_started = true


func _on_button_about_to_popup(button: CharacterEditorPaletteButton) -> void:
	var part_id = button.part_id
	_rebuild_icons_for_part(part_id)


func set_connections() -> void:
	# Character Editor
	%EditorCharacter.attack.connect(_on_attack)
	%EditorCharacter.animation_finished.connect(_on_animation_finished)
	# Body parts
	var body_parts = [%Gender, %Body, %Eyes, %Wings, %Tail, %Horns, %Hair, %HairAddon, %Ears, %Nose, %FacialHair, %BodyAddon1, %BodyAddon2, %BodyAddon3]
	for button: CharacterEditorPaletteButton in body_parts:
		button.item_selected.connect(_on_body_part_item_selected)
		button.palette_button_pressed.connect(_on_body_part_palette_button_pressed)
		button.palette_button_pressed.connect(force_show_palette_dialog)
		button.locked_button_pressed.connect(_on_body_part_locked_button_pressed)
		button.get_popup().about_to_popup.connect(_on_button_about_to_popup.bind(button), CONNECT_DEFERRED)
	
	# Equipment Parts
	var equipment_parts = [%Mask, %Hat, %GearFacial, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants, %Shoes, %Back, %MainHand, %Ammo, %Offhand]
	for button: CharacterEditorPaletteButton in equipment_parts:
		button.item_selected.connect(_on_gear_part_item_selected)
		button.palette_button_pressed.connect(_on_gear_part_palette_button_pressed)
		button.palette_button_pressed.connect(force_show_palette_dialog)
		button.locked_button_pressed.connect(_on_gear_part_locked_button_pressed)
	
	palette_dialog.refresh_item.connect(_on_refresh_part_required)
	palette_dialog.hightlight_color.connect(%EditorCharacter.set_highlight_color)
	palette_dialog.input_action_requested.connect(%EditorCharacter._input)
	palette_dialog.palette_changed.connect(_on_palette_changed)
	palette_dialog.part_changed.connect(_request_change_part_palette)


func _on_palette_changed(part_id: String, palettes: Dictionary) -> void:
	call_deferred("_update_palette", part_id, palettes)


func _update_palette(part_id: String, palettes: Dictionary) -> void:
	pass
	#var textures = current_character.get_textures_from_part(part_id)
	#if textures.front:
		#textures.front.palette1.blend_color = palettes.blend_color1
		#textures.front.palette2.blend_color = palettes.blend_color2
		#textures.front.palette3.blend_color = palettes.blend_color3
		#textures.front.palette1.lightness = palettes.lightness1
		#textures.front.palette2.lightness = palettes.lightness2
		#textures.front.palette3.lightness = palettes.lightness3
		#textures.front.palette1.colors.clear()
		#textures.front.palette2.colors.clear()
		#textures.front.palette3.colors.clear()
		#textures.front.palette1.colors + palettes.palette1
		#textures.front.palette2.colors + palettes.palette2
		#textures.front.palette3.colors + palettes.palette3
#
	#if textures.back:
		#textures.back.palette1.blend_color = palettes.blend_color1
		#textures.back.palette2.blend_color = palettes.blend_color2
		#textures.back.palette3.blend_color = palettes.blend_color3
		#textures.back.palette1.lightness = palettes.lightness1
		#textures.back.palette2.lightness = palettes.lightness2
		#textures.back.palette3.lightness = palettes.lightness3
		#textures.front.palette1.colors.clear()
		#textures.back.palette2.colors.clear()
		#textures.back.palette3.colors.clear()
		#textures.back.palette1.colors + palettes.palette1
		#textures.back.palette2.colors + palettes.palette2
		#textures.back.palette3.colors + palettes.palette3



func _rebuild_icons_for_part(part_id: String) -> void:
	var valid_parts = [
		"eyes", "wings", "tail", "horns", "hair", "hairadd", "ears",
		"nose", "facial", "add1", "add2", "add3", "mask", "hat", "glasses",
		"suit", "jacket", "shirt", "gloves", "belt", "pants", "shoes", "back",
		"mainhand", "ammo", "offhand"
	]
	var nodes = [
		%Eyes, %Wings, %Tail, %Horns, %Hair, %HairAddon, %Ears, %Nose, %FacialHair,
		%BodyAddon1, %BodyAddon2, %BodyAddon3,
		%Mask, %Hat, %GearFacial, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants,
		%Shoes, %Back, %MainHand, %Ammo, %Offhand
	]
	if not part_id in valid_parts: return
	var index = valid_parts.find(part_id)
	var node = nodes[index]
	if node:
		var items: Array = node.get_items()
		var item_data: Dictionary = {}
		var selected_id = node.get_selected_id()
		for item in items:
			item_data[item] = true
		_add_preview_task(node, part_id, item_data, true, selected_id, true)


func _on_attack(animation_id: String) -> void:
	if current_character.character.mainhand:
		var weapon_data = data.gear.mainhand[current_character.character.mainhand]
		var body_type = current_character.character["body_type"]
		var head_type = current_character.character["head_type"]
		var texture_found = false
		
		for texture in weapon_data.get("textures", []):
			var texture_body = texture.get("body", body_type)
			var texture_head = texture.get("head", head_type)
			var texture_spriteset = texture.get("spritesheet", "")
			if texture_body == body_type and texture_head == head_type and texture_spriteset.find(animation_id) != -1:
				%EditorCharacter.set_texture("mainhand", texture)
				texture_found = true
				break
		
		if !texture_found:
			for texture in weapon_data.get("textures", []):
				var texture_body = texture.get("body", body_type)
				var texture_head = texture.get("head", head_type)
				var texture_spriteset = texture.get("spritesheet", "")
				if (
					texture_body == body_type and texture_head == head_type and
					(texture_spriteset == "char_base" or texture_spriteset == "")
				):
					%EditorCharacter.set_texture("mainhand", texture)
					break


func _on_animation_finished() -> void:
	_on_attack("walk")


func _sort_by_index(array: Array, index: int) -> Array:
	if array.is_empty() or index < 0 or index >= array.size():
		return array.duplicate()
	
	var result = []
	var left = index - 1
	var right = index + 1
	
	# Add the central index element
	result.append(array[index])
	
	# Alternate between left and right
	while left >= 0 or right < array.size():
		# Add left element
		if left >= 0:
			result.append(array[left])
			left -= 1
		
		# Add right element
		if right < array.size():
			result.append(array[right])
			right += 1
	
	return result


func _add_preview_task(node: CharacterEditorPaletteButton, part_id: String, item_data: Dictionary, ignore_cache: bool = false, selected_index: int = -1, is_high_priority: bool = false, real_ordered_data: Array = []) -> void:
	var item_keys = item_data.keys()
	if item_keys.is_empty():
		return

	var gear_keys = ["ammo", "back", "belt", "glasses", "gloves", "hat", "jacket", "mainhand", "mask", "offhand", "pants", "shirt", "shoes", "suit"]
	
	var offset = 1 if not part_id in gear_keys and not ignore_cache and node.has_none() else 0

	for i in item_keys.size():
		var item_id = item_keys[i]
		if item_id == "none":
			node.set_item_icon_at_index(i + offset, null)
			continue
			
		var cache_key = "%s_%s_%s" % [node, part_id, item_id]
		if preview_cache.has(cache_key):
			if not ignore_cache:
				var preview_texture: Texture2D = preview_cache[cache_key]
				node.set_item_icon_at_index(i + offset, preview_texture)
				continue
			else:
				preview_cache.erase(cache_key)
				
		var backup_part_id = part_id
		# Special weapon without icon, uses the ammunition icon instead.
		if part_id == "mainhand" and (item_id == "boomerang" or item_id == "whip"):
			part_id = "ammo"
			
		var index = i + offset if real_ordered_data.is_empty() else real_ordered_data.find(item_id)  + offset
		var item = {
			"node": node,
			"index": index + offset,
			"part_id": part_id,
			"item_id": item_id,
			"high_priority": is_high_priority,
			"ignore_cache": ignore_cache
		}
		var queue_key = str(item)
		
		current_queue_keys[queue_key] = true
		var list = ultra_high_preview_queue if selected_index == i \
			else preview_queue if not is_high_priority \
			else high_preview_queue
		if i == selected_index:
			list.insert(0, item)
		else:
			list.append(item)
		
		part_id = backup_part_id


func _process(delta: float) -> void:
	if busy or not is_started:
		return

	if _visibility_dirty:
		update_items_visibility()
		_visibility_dirty = false

	if (preview_queue.size() > 0 or high_preview_queue.size() > 0 or ultra_high_preview_queue.size() > 0) and !is_generating_previews:
		var task = ultra_high_preview_queue.pop_front() if not ultra_high_preview_queue.is_empty() \
			else high_preview_queue.pop_front() if not high_preview_queue.is_empty() \
			else preview_queue.pop_front()
		var queue_key = str(task)
		current_queue_keys.erase(queue_key)
		is_generating_previews = true
		call_deferred("_generate_and_set_preview", task)
	
	if not rebuild_timer.is_empty():
		for part_id in rebuild_timer.keys():
			rebuild_timer[part_id] -= delta
			if rebuild_timer[part_id] <= 0.0:
				rebuild_timer.erase(part_id)
				call_deferred("_rebuild_icons_for_part", part_id)
			break


func request_visibility_update() -> void:
	_visibility_dirty = true


func lock_items() -> void:
	var body_parts = [%Gender, %Body, %Eyes, %Wings, %Tail, %Horns, %Hair, %HairAddon, %Ears, %Nose, %FacialHair, %BodyAddon1, %BodyAddon2, %BodyAddon3]
	var gear_parts = [%Mask, %Hat, %GearFacial, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants, %Shoes, %Back, %MainHand, %Ammo, %Offhand]
	
	var items = [current_character.slotsset, current_character.slotshidden]
	for item in items:
		for id in current_character.slotsset:
			for obj in body_parts:
				if obj.name.to_lower().find(id) != -1:
					obj.lock()
					break
			for obj in gear_parts:
				if obj.name.to_lower().find(id) != -1:
					obj.lock()
					break


func unlock_items() -> void:
	var body_parts = [%Gender, %Body, %Eyes, %Wings, %Tail, %Horns, %Hair, %HairAddon, %Ears, %Nose, %FacialHair, %BodyAddon1, %BodyAddon2, %BodyAddon3]
	var gear_parts = [%Mask, %Hat, %GearFacial, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants, %Shoes, %Back, %MainHand, %Ammo, %Offhand]
	
	var items = [current_character.slotsset, current_character.slotshidden]
	for item in items:
		for id in current_character.slotsset:
			for obj in body_parts:
				if obj.name.to_lower().find(id) != -1:
					obj.unlock()
					break
			for obj in gear_parts:
				if obj.name.to_lower().find(id) != -1:
					obj.unlock()
					break


func get_items_hidden() -> Array:
	var items_hidden: Array = []
	
	for id: String in current_character.textures.keys():
		var texture_data: CharacterPart = current_character.textures[id]
		var part_id = texture_data.part_id
		var item_id = texture_data.item_id
		if part_id == "mainhand" and item_id == "boomerang":
			items_hidden.append("mainhand")
		elif part_id and item_id and part_id != "none" and item_id != "none":
			var current_data: Dictionary
			if data.characters.has(part_id):
				if part_id != "body":
					current_data = data.characters[part_id][item_id]
				else:
					var current_body = get_current_body()
					current_data = data.characters[part_id][current_body.body[0]]
			else:
				current_data = data.gear[part_id][item_id]
				
			if current_data:
				items_hidden.append_array(current_data.get("slotshidden", []))
				items_hidden.append_array(current_data.get("slotsset", []))
	
	var unique_items_hidden: Array = []
	for item in items_hidden:
		if !unique_items_hidden.has(item):
			unique_items_hidden.append(item)
		
	
	return unique_items_hidden


func update_items_visibility() -> void:
	unlock_items()
	current_character.slotsalt.clear()
	current_character.slotshidden.clear()
	current_character.slotsset.clear()
	

	var ammo_is_hidden = false
	for id: String in current_character.textures.keys():
		var texture_data: CharacterPart = current_character.textures[id]
		var part_id = texture_data.part_id
		var item_id = texture_data.item_id
		if part_id == "mainhand" and item_id == "boomerang":
			%EditorCharacter.set_items_visibility(["mainhand"], [])
			ammo_is_hidden = true
			continue
		if part_id and item_id and part_id != "none" and item_id != "none":
			var current_data: Dictionary
			if data.characters.has(part_id):
				if part_id != "body":
					current_data = data.characters[part_id][item_id]
				else:
					var current_body = get_current_body()
					current_data = data.characters[part_id][current_body.body[0]]
			else:
				current_data = data.gear[part_id][item_id]
				
			if current_data:
				var slotsalt = current_data.get("slotsalt", [])
				var slotshidden = current_data.get("slotshidden", [])
				var slotsset = current_data.get("slotsset", [])

				current_character.slotsalt.append_array(slotsalt)
				current_character.slotshidden.append_array(slotshidden)
				current_character.slotsset.append_array(slotsset)
				
				%EditorCharacter.set_items_visibility(current_character.slotshidden, current_character.slotsset)
				
				lock_items()
				
				update_items_alt()
	if ammo_is_hidden:
		%EditorCharacter.set_items_visibility(["ammo"], [])


func update_items_alt() -> void:
	var parts_updated = []
	for texture: CharacterPart in current_character.textures.values():
		if texture.is_alt:
			texture.is_alt = false
			if texture.part_id and texture.item_id:
				var item_data: Dictionary
				if data.characters.has(texture.part_id):
					item_data = data.characters[texture.part_id][texture.item_id]
				else:
					item_data = data.gear[texture.part_id][texture.item_id]
				var current_texture_data = get_current_texture_data(item_data)
				current_texture_data.part_id = texture.part_id
				current_texture_data.item_id = texture.item_id
				texture.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
				if !parts_updated.has(texture):
					parts_updated.append(texture)
		
	for id: String in current_character.slotsalt:
		var texture1 = current_character.textures.get(id + "_texture", null)
		var texture2 = current_character.textures.get(id + "_texture_back", null)
		var texture3 = current_character.textures.get(id + "_texture_front", null)
		for texture in [texture1, texture2, texture3]:
			if texture:
				texture.is_alt = true
				if texture.alt_id:
					var item_data: Dictionary
					if data.characters.has(texture.part_id):
						item_data = data.characters[texture.part_id][texture.alt_id]
					else:
						item_data = data.gear[texture.part_id][texture.alt_id]
					var current_texture_data = get_current_texture_data(item_data)
					current_texture_data.part_id = texture.part_id
					current_texture_data.item_id = texture.item_id
					texture.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
					if parts_updated.has(texture):
						parts_updated.erase(texture)
					parts_updated.append(texture)
	
	for texture: CharacterPart in parts_updated:
		%EditorCharacter.update_texture(texture)


#region SET ALL DATA
func clear_all() -> void:
	data.clear()
	current_palettes.clear()
	current_character.character.clear()
	for tex: CharacterPart in current_character.textures.values():
		tex.clear()


func get_files(path: String, filter: Array) -> Array:
	var files = []
	var dir: DirAccess = DirAccess.open(path)
	
	if DirAccess.get_open_error() == OK:
		dir.list_dir_begin()
		
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir():
				files.append_array(get_files(dir.get_current_dir().path_join(file_name), files))
			else:
				if filter.size() == 0 or file_name.get_extension().to_lower() in filter:
					files.append(dir.get_current_dir().path_join(file_name))
			
			file_name = dir.get_next()
	
	return files


func _load_initial_data_in_thread() -> void:
	_thread = Thread.new()
	_thread.start(set_data.bind("_end_thread"))


func _end_thread() -> void:
	data_is_ready = true
	_thread.wait_to_finish()


func set_data(_thread_callable: String = "") -> void:
	clear_all()
	set_body_data()
	set_gear_data()
	set_colormap_data()
	set_credits_data()
	call_deferred("_data_loaded")
	if not _thread_callable.is_empty():
		call_deferred(_thread_callable)


func _data_loaded() -> void:
	data_loaded.emit()
	request_visibility_update()


func _on_data_loaded() -> void:
	preview_character.current_data = current_character.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	
	set_animations_data()
	fill_palettes()
	fill_races()
	if is_inside_tree():
		await get_tree().process_frame
	_on_body_part_palette_button_pressed("body", false)
	
	%LoadingData.visible = false
	
	is_started = true
	
	preview_character.position = -Vector2.INF
	preview_character.modulate.a = 0.0
	preview_character.refresh()
	preview_character.reset_animation()
	request_visibility_update()


func set_body_data() -> void:
	data = {}
	data.characters = {}
	var keys = ["add1", "add2", "add3", "body", "ears", "eyes", "facial", "horns", "hair", "hairadd", "head", "nose", "race", "shadow", "tail", "wings"]
	for key in keys:
		var path = "res://addons/rpg_character_creator/Data/character/%s" % key + "/"
		var files = get_files(path, [])
		data.characters[key] = {}
		for file in files:
			var f = FileAccess.open(file, FileAccess.READ)
			var json = f.get_as_text()
			f.close()
			var obj: Dictionary = JSON.parse_string(json)
			var id: String = obj.get("id", "-")
			obj.erase("id")
			obj.config_path = file
			if key == "race":
				var body_data := {}
				var genders := {}
				for i in obj.configs.size():
					var body_id = obj.configs[i].id
					body_data[body_id] = obj.configs[i].duplicate(true)
					body_data[body_id].erase("id")
					body_data[body_id].chargen = true
					body_data[body_id].default = obj.configs[i].get("default", false)
					var body_gender = obj.configs[i].get("gender", "")
					if body_gender and !genders.has(body_gender):
						genders[body_gender] = {"name": body_gender.capitalize(), "chargen": true, "default": genders.size() == 0}
				obj.genders = genders
				obj.configs = body_data
				
			data.characters[key][id] = obj


func set_gear_data() -> void:
	data.gear = {}
	var keys = ["ammo", "back", "belt", "glasses", "gloves", "hat", "jacket", "mainhand", "mask", "offhand", "pants", "shirt", "shoes", "suit"]
	for key in keys:
		var path = "res://addons/rpg_character_creator/Data/gear/%s" % key + "/"
		var files = get_files(path, [])
		data.gear[key] = {}
		for file in files:
			var f = FileAccess.open(file, FileAccess.READ)
			var json = f.get_as_text()
			f.close()
			var obj: Dictionary = JSON.parse_string(json)
			var id: String = obj.get("id", "-")
			obj.erase("id")
			obj.config_path = file
			data.gear[key][id] = obj


func set_colormap_data() -> void:
	data.colormaps = {}
	var path = "res://addons/rpg_character_creator/Data/ColorMaps/"
	var files = get_files(path, ["cm"])
	for file in files:
		var f = FileAccess.open(file, FileAccess.READ)
		var json = f.get_as_text()
		f.close()
		var obj: Dictionary = JSON.parse_string(json)
		var id: String = obj.get("id", "-")
		obj.erase("id")
		var items = {}
		for item in obj.items:
			var item_id = item.id
			item.erase("id")
			items[item_id] = item
		obj.items = items
		obj.config_path = file
		data.colormaps[id] = obj


func set_credits_data() -> void:
	data.credits = {}
	var path = "res://addons/rpg_character_creator/Data/credits/"
	var files = get_files(path, ["credits"])
	for file in files:
		var f = FileAccess.open(file, FileAccess.READ)
		var json = f.get_as_text()
		f.close()
		var obj: Dictionary = JSON.parse_string(json)
		var id: String = obj.get("id", "-")
		obj.erase("id")
		obj.config_path = file
		data.credits[id] = obj


func set_animations_data() -> void:
	data.player_animations = RPGSYSTEM.player_animations_data
	data.weapon_animations = RPGSYSTEM.weapon_animations_data
	%EditorCharacter.animations = {"player": data.player_animations.animations, "weapon": data.weapon_animations.animations}
	%PreviewCharacter.animations = {"player": data.player_animations.animations, "weapon": data.weapon_animations.animations}
#endregion


#region Fill Option Buttons
func get_current_body() -> Dictionary:
	var race = data.characters.race[current_character.character.get("race", "human")]
	var body = current_character.character.get("body", "")
	var current_body = race.configs.get(body if body else race.configs.keys()[0])
	return current_body


func get_current_texture_data(item_data: Dictionary) -> Dictionary:
	var current_texture_data = {}
	var body_type = current_character.character["body_type"]
	var head_type = current_character.character["head_type"]
	var textures = item_data.get("textures", [])
	for t in textures:
		var texture_back = t.get("back", "none")
		var texture_front = t.get("front", "none")
		if texture_back != "none" or texture_front != "none":
			var texture_body = t.get("body", body_type)
			var texture_head = t.get("head", head_type)
			if (texture_body == body_type and texture_head == head_type) or texture_body == texture_head:
				current_texture_data.texture = t
				current_texture_data.alt_id = item_data.get("alt", "")
				current_texture_data.primarycolors = item_data.get("primarycolors", [])
				current_texture_data.secondarycolors = item_data.get("secondarycolors", [])
				current_texture_data.fixedcolors = item_data.get("fixedcolors", [])
				break
	
	return current_texture_data


func fill_races() -> void:
	var node = %Races
	node.clear()
	var id_selected: int = 0
	for id in data.characters.race.keys():
		node.add_item(data.characters.race[id].name)
		node.set_item_metadata(-1, id)
		if id == "01human":
			id_selected = node.get_item_count() - 1
	
	node.select(id_selected)
	node.item_selected.emit(id_selected)


func fill_palettes() -> void:
	var node: OptionButton = %Palettes
	node.clear()
	var item_selected := 0
	for id in data.colormaps.keys():
		node.add_item(data.colormaps[id].name)
		node.set_item_metadata(-1, id)
		if id == "default":
			item_selected = node.get_item_count() - 1
	
	if node.get_item_count() > item_selected:
		node.select(item_selected)
		node.item_selected.emit(item_selected)


func fill_genders(genders: Dictionary) -> void:
	%Gender.fill(genders, current_character.character.get("gender", ""))


func fill_body(bodies: Dictionary) -> void:
	var current_bodies = {}
	for key in bodies.keys():
		if bodies[key].get("gender", "") == current_character.character.gender:
			current_bodies[key] = bodies[key]
	%Body.fill(current_bodies, current_character.character.get("body", ""))


func fill_body_parts(current_body: Dictionary) -> void:
	preview_busy = true
	
	var body_parts = [
		{"id": "eyes", "node": %Eyes},
		{"id": "wings", "node": %Wings},
		{"id": "tail", "node": %Tail},
		{"id": "horns", "node": %Horns},
		{"id": "hair", "node": %Hair},
		{"id": "hairadd", "node": %HairAddon},
		{"id": "ears", "node": %Ears},
		{"id": "nose", "node": %Nose},
		{"id": "facial", "node": %FacialHair},
		{"id": "add1", "node": %BodyAddon1},
		{"id": "add2", "node": %BodyAddon2},
		{"id": "add3", "node": %BodyAddon3}
	]
	for item in body_parts:
		var current_data = data.characters[item.id]
		var fill_data = {}
		var obj = current_body.get(item.id, [])
		var keys = current_data.keys()
		for index in keys.size():
			var key = keys[index]
			if key in obj:
				fill_data[key] = {
					"name": current_data[key].get("name", ""),
					"chargen": current_data[key].get("chargen", true),
					"default": current_data[key].get("default", false)
				}

		item.node.fill(fill_data, current_character.character.get(item.id, current_body.get(item.id, ["none"])[0]))
		var selected_id = item.node.get_selected_id()
		_add_preview_task(item.node, item.id, fill_data, false, selected_id)
		
	preview_busy = false


func fill_equipment_parts() -> void:
	preview_busy = true
	
	var body_id = current_character.character.get("body_type", "")
	var head_id = current_character.character.get("head_type", "")
	var equipment_parts = [
		{"id": "mask", "node": %Mask},
		{"id": "hat", "node": %Hat},
		{"id": "glasses", "node": %GearFacial},
		{"id": "suit", "node": %Suit},
		{"id": "jacket", "node": %Jacket},
		{"id": "shirt", "node": %Shirt},
		{"id": "gloves", "node": %Gloves},
		{"id": "belt", "node": %Belt},
		{"id": "pants", "node": %Pants},
		{"id": "shoes", "node": %Shoes},
		{"id": "back", "node": %Back},
		{"id": "mainhand", "node": %MainHand},
		{"id": "offhand", "node": %Offhand}
	]
	for item in equipment_parts:
		var current_data = data.gear[item.id]
		var fill_data = {}
		fill_data["none"] = {
			"name": "None",
			"chargen": true,
			"default": false
		}
		var keys = current_data.keys()
		for index in keys.size():
			var key = keys[index]
			var obj = current_data[key]
			var textures = obj.get("textures", [])
			for t in textures:
				if (
					t is Dictionary and
					("head" in t or "body" in t) and
					t.get("head", head_id) == head_id and
					t.get("body", body_id) == body_id
				):
					fill_data[key] = {
						"name": current_data[key].get("name", ""),
						"chargen": current_data[key].get("chargen", true),
						"default": current_data[key].get("default", false)
					}
					break

		item.node.fill(fill_data, current_character.character.get(item.id, "none"))
		var selected_id = item.node.get_selected_id()
		_add_preview_task(item.node, item.id, fill_data, false, selected_id)
	
	preview_busy = false


func fill_ammo_part() -> void:
	preview_busy = true
	
	var body_id = current_character.character.get("body_type", "")
	var head_id = current_character.character.get("head_type", "")
	var main_hand = data.gear.mainhand.get(current_character.character.get("mainhand", ""), "")
	if main_hand:
		var supported_ammo = main_hand.get("ammo", null)
		var ammo_part = {"id": "ammo", "node": %Ammo}
		if supported_ammo:
			var current_data = data.gear.ammo
			var fill_data = {}
			var keys = current_data.keys()
			for index in keys.size():
				var ammo_id = keys[index]
				if supported_ammo.has(ammo_id):
					var obj = current_data[ammo_id]
					fill_data[ammo_id] = {
						"name": obj.get("name", ""),
						"chargen": obj.get("chargen", true),
						"default": obj.get("default", false)
					}
			ammo_part.node.fill(fill_data, current_character.character.get(ammo_part.id, current_data.keys()[0]))
			var selected_id = ammo_part.node.get_selected_id()
			_add_preview_task(ammo_part.node, ammo_part.id, fill_data, false, selected_id)
		else:
			ammo_part.node.fill({}, "")
	
	preview_busy = false

#endregion


#region On Option Button Item Selected
func _on_palettes_item_selected(index: int) -> void:
	var palette_id = %Palettes.get_item_metadata(index)
	current_character.character.palette = palette_id
	palette_dialog.set_data_colors(data.colormaps[current_character.character.palette])
	%Races.item_selected.emit(%Races.get_selected_id())


func _on_races_item_selected(index: int) -> void:
	var race_id = %Races.get_item_metadata(index)
	if !race_id:
		return
	current_character.character.race = race_id
	var race = data.characters.race[race_id]
	fill_genders(race.genders)
	fill_body(race.configs)


func there_are_colors_in(data: Dictionary) -> bool:
	var primarycolors = data.get("primarycolors", [])
	var secondarycolors = data.get("secondarycolors", [])
	var fixedcolors = data.get("fixedcolors", [])
	
	return !primarycolors.is_empty() or !secondarycolors.is_empty() or !fixedcolors.is_empty()


func _on_body_part_item_selected(part_id: String, item_id: String) -> void:
	current_character.character[part_id] = item_id
	if part_id == "body":
		current_character.character["body_type"] = data.characters.race[current_character.character.race].configs[item_id].get("body-type", "")
		current_character.character["head_type"] = data.characters.race[current_character.character.race].configs[item_id].get("head-type", "")

	if part_id != "gender":
		var current_data: Dictionary
		if part_id != "body":
			current_data = data.characters[part_id][item_id]
		else:
			var current_body = get_current_body()
			current_data = data.characters[part_id][current_body.body[0]]
			
		var current_texture_data: Dictionary = get_current_texture_data(current_data)

		current_texture_data.part_id = part_id
		current_texture_data.item_id = item_id
		
		var texture1 = current_character.textures.get(part_id + "_texture", null)
		if texture1:
			texture1.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
		var texture2 = current_character.textures.get(part_id + "_texture_back", null)
		if texture2:
			texture2.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
		var texture3 = current_character.textures.get(part_id + "_texture_front", null)
		if texture3:
			texture3.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
		
		if part_id == "body":
			var other_part_ids = ["ears", "nose", "head"]
			for other_part_id in other_part_ids:
				var texture = current_character.textures[other_part_id + "_texture"]
				var palette_ids = ["palette1", "palette2", "palette3"]
				for palette_id in palette_ids:
					texture[palette_id] = current_character.textures["body_texture"][palette_id].duplicate(true)
		elif !there_are_colors_in(current_texture_data):
			var textures = [texture1, texture2, texture3]
			for texture in textures:
				if texture:
					var palette_ids = ["palette1", "palette2", "palette3"]
					for palette_id in palette_ids:
						texture[palette_id] = current_character.textures["body_texture"][palette_id].duplicate(true)

		if part_id == "body" or part_id == "gender":
			if part_id == "body":
				var current_body = get_current_body()
				fill_body_parts(current_body)
				fill_equipment_parts()
				_on_body_part_item_selected("head", current_body.head[0])
			%EditorCharacter.refresh()
		else:
			for texture_data in [texture1, texture2, texture3]:
				if texture_data:
					%EditorCharacter.update_texture(texture_data)
	else:
		var race = data.characters.race[current_character.character["race"]]
		fill_body(race.configs)
	
	_on_body_part_palette_button_pressed(part_id, false)
	request_visibility_update()


func _on_gear_part_item_selected(part_id: String, item_id: String) -> void:
	current_character.character[part_id] = item_id
	var current_data = data.gear[part_id][item_id]
	
	if part_id == "mainhand":
		fill_ammo_part()
		current_character.weapon_data.actions = current_data.get("actions", [])
		current_character.weapon_data.ammo = current_data.get("ammo", [])
		current_character.weapon_data.sounds = current_data.get("sounds", [])
	
	var current_texture_data = get_current_texture_data(current_data)

	current_texture_data.part_id = part_id
	current_texture_data.item_id = item_id
	var texture1 = current_character.textures.get(part_id + "_texture", null)
	if texture1:
		texture1.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
	var texture2 = current_character.textures.get(part_id + "_texture_back", null)
	if texture2:
		texture2.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
	var texture3 = current_character.textures.get(part_id + "_texture_front", null)
	if texture3:
		texture3.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
	
	for texture_data in [texture1, texture2, texture3]:
		if texture_data:
			%EditorCharacter.update_texture(texture_data)
	
	_on_gear_part_palette_button_pressed(part_id, false)
	request_visibility_update()


func _on_body_part_palette_button_pressed(part_id: String, show_dialog: bool = true) -> void:
	for key in current_character.textures.keys():
		if key.to_lower().find(part_id) != -1:
			var current_texture: CharacterPart = current_character.textures[key]
			var item_id = current_texture.item_id
			var current_data: Dictionary
			if part_id == "body":
				var current_body = get_current_body()
				current_data = data.characters.body[current_body.body[0]]
			else:
				current_data = data.characters[part_id].get(item_id, {})
			show_palette_dialog(part_id, current_texture, current_data, show_dialog)
			break


func _on_gear_part_palette_button_pressed(part_id: String, show_dialog: bool = true) -> void:
	for key in current_character.textures.keys():
		if key.to_lower().find(part_id) != -1:
			var current_texture: CharacterPart = current_character.textures[key]
			var item_id = current_texture.item_id
			var current_data: Dictionary = data.gear[part_id].get(item_id, {})
			show_palette_dialog(part_id, current_texture, current_data, show_dialog)
			break


func _request_change_part_palette(part_id: String) -> void:
	var item_id = current_character.character.get(part_id, "none")
	var body_parts = [
		"body", "head", "eyes", "wings", "tail", "horns", "hair", "hairadd",
		"ears", "nose", "facial", "add1", "add2", "add3"
	]
	var gear_parts = [
		"mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt",
		"pants", "shoes", "back", "mainhand", "offhand", "ammo"
	]
	var current_data
	
	if body_parts.has(part_id):
		_on_body_part_palette_button_pressed(part_id, false)
	elif gear_parts.has(part_id):
		_on_gear_part_palette_button_pressed(part_id, false)


func show_palette_dialog(part_id: String, current_texture: CharacterPart, current_data: Dictionary, show_dialog: bool = true) -> void:
	var palette_data = {}
	palette_data.part_id = part_id
	palette_data.palette1 = current_texture.palette1
	palette_data.palette2 = current_texture.palette2
	palette_data.palette3 = current_texture.palette3
	palette_data.colors = {
		"primary_colors": current_data.get("primarycolors", []),
		"secondary_colors": current_data.get("secondarycolors", []),
		"fixed_colors": current_data.get("fixedcolors", [])
	}
	palette_dialog.set_data(palette_data)
	
	if show_dialog: # and !palette_dialog.visible:
		palette_dialog.size.y = 0
		call_deferred("try_show_palette_dialog")


func try_show_palette_dialog() -> void:
	if !palette_dialog.visible:
		palette_dialog.show()
	else:
		palette_dialog.hide()
		palette_dialog.show.call_deferred()


func force_show_palette_dialog(_part_id: String = "", _show_dialog: bool = true) -> void:
	if !palette_dialog.visible:
		palette_dialog.show()


func try_hide_palette_dialog() -> void:
	if palette_dialog.visible:
		palette_dialog.hide_all()
		palette_dialog_need_set_to_visible = true
	
	


func _on_body_part_locked_button_pressed(part_id: String) -> void:
	pass


func _on_gear_part_locked_button_pressed(part_id: String) -> void:
	pass
#endregion


func _on_create_character_and_equipment_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/confirm_create_character_dialog.tscn"
	var parent = RPGDialogFunctions.get_current_dialog()
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	var busy = true
	if "busy" in parent:
		parent.busy = true
	var selfparent = get_parent().get_parent()
	if "confirm_dialog_options" in selfparent and selfparent.confirm_dialog_options is RPGCharacterCreationOptions:
		var options: RPGCharacterCreationOptions = selfparent.confirm_dialog_options
		dialog.set_options(selfparent.confirm_dialog_options)
	dialog.ok_pressed.connect(_on_save)
	dialog.tree_exited.connect(
		func():
			busy = false
			if "busy" in parent:
				parent.busy = false
	)


func clean_numbers(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\d+")
	text = regex.sub(text, "")
	return text


func _on_random_body_pressed() -> void:
	enable_pick_random_color = true
	var options = [%Gender, %Body, %Eyes, %Wings, %Tail, %Horns, %Hair, %HairAddon, %Ears, %Nose, %FacialHair, %BodyAddon1, %BodyAddon2, %BodyAddon3]
	var randomizer = [0.5, 0.5, 0.5, 0.5, 0.95, 0.5, 0.85, 0.85, 0.8, 0.05, 0.05, 0.3, 0.3, 0.05]
	for i in options.size():
		if randf() <= randomizer[i]:
			var obj = options[i]
			if !obj.is_locked:
				obj.pick_random()
	enable_pick_random_color = false
	_on_body_part_palette_button_pressed("body", false)


func _on_random_gear_pressed() -> void:
	enable_pick_random_color = true
	var options = [%Mask, %Hat, %GearFacial, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants, %Shoes, %Back, %MainHand, %Offhand]
	var randomizer = [0.1, 0.4, 0.4, 0.02, 0.4, 0.1, 0.7, 0.7, 0.65, 0.6, 0.4, 0.8, 0.8]
	for i in options.size():
		if randf() <= randomizer[i]:
			var obj = options[i]
			if !obj.is_locked:
				obj.pick_random()
	enable_pick_random_color = false


func _on_clear_body_pressed() -> void:
	var options = [%Eyes, %Wings, %Tail, %Horns, %Hair, %HairAddon, %Ears, %Nose, %FacialHair, %BodyAddon1, %BodyAddon2, %BodyAddon3]
	var part_ids = [
		"wings_texture_back", "wings_texture_front", "body_texture",
		"add2_texture", "add3_texture", "head_texture", "eyes_texture",
		"facial_texture", "ears_texture", "nose_texture", "add1_texture",
		"hair_texture", "hairadd_texture", "horns_texture", "tail_texture_back",
		"tail_texture_front"
	]
	for id in part_ids:
		var character_part: CharacterPart = current_character.textures[id]
		character_part.palette1.item_selected = 0
		character_part.palette2.item_selected = 0
		character_part.palette3.item_selected = 0
		character_part.palette1.blend_color = 0
		character_part.palette2.blend_color = 0
		character_part.palette3.blend_color = 0
	for obj in options:
		obj.reset()
	
	%Body.call_item_selected_signal()


func _on_clear_gear_pressed() -> void:
	var options = [%Mask, %Hat, %GearFacial, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants, %Shoes, %Back, %MainHand, %Offhand]
	var part_ids = [
		"back_texture_back", "back_texture_front", "suit_texture",
		"pants_texture", "shoes_texture", "gloves_texture", "shirt_texture",
		"belt_texture", "jacket_texture", "mask_texture", "glasses_texture",
		"hat_texture", "mainhand_texture_back", "mainhand_texture_front",
		"offhand_texture_back", "offhand_texture_front", "ammo_texture_back",
		"ammo_texture_front"
	]
	for id in part_ids:
		var character_part: CharacterPart = current_character.textures[id]
		character_part.palette1.item_selected = 0
		character_part.palette2.item_selected = 0
		character_part.palette3.item_selected = 0
		character_part.palette1.blend_color = 0
		character_part.palette2.blend_color = 0
		character_part.palette3.blend_color = 0
	for obj in options:
		obj.reset()


func _on_refresh_part_required(colors_data: Dictionary) -> void:
	%EditorCharacter.refresh_texture(colors_data)
	
	if colors_data.part_id == "body":
		var ids = ["ears", "nose", "head"]
		for id in ids:
			var texture_id = id + "_texture"
			var current_data = data.characters[id][current_character.textures[texture_id].item_id]
			var current_texture_data = get_current_texture_data(current_data)
			if !there_are_colors_in(current_texture_data):
				var palette_ids = ["palette1", "palette2", "palette3"]
				for palette_id in palette_ids:
					var current_texture: CharacterPart
					if current_character.textures.has("%s_texture" % id):
						current_texture = current_character.textures["%s_texture" % id]
					elif current_character.textures.has("%s_texture_front" % id):
						current_texture = current_character.textures["%s_texture_front" % id]
					var item_selected = current_texture[palette_id].item_selected
					if item_selected != -2 or true: # Default behavior. Remove or true to other effects
						current_texture[palette_id] = current_character.textures["body_texture"][palette_id].duplicate(true)
					else:
						current_texture[palette_id].lightness = current_character.textures["body_texture"][palette_id].lightness
						current_texture[palette_id].blend_color = current_character.textures["body_texture"][palette_id].blend_color
				colors_data = {
					"part_id": id,
					"palette1": current_character.textures[texture_id].palette1,
					"palette2": current_character.textures[texture_id].palette2,
					"palette3": current_character.textures[texture_id].palette3
				}
				%EditorCharacter.refresh_texture(colors_data)


func is_mouse_over_palette_window() -> bool:
	var rect: Rect2 = Rect2(palette_dialog.position - RPGDialogFunctions.get_current_dialog().position, palette_dialog.size)
	var p = get_viewport().get_mouse_position()
	return rect.has_point(p)


func get_palette_window() -> Window:
	return palette_dialog


func _on_import_data_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.target_callable = import_data
	dialog.destroy_on_hide = true
	
	dialog.fill_mix_files(["characters", "events", "equipment_parts"])


#func import_data(data_path: String) -> void:
	#if !data_path:
		#return
		#
	#var res = load(data_path)
	#if not res:
		#return
#
	#var gear_map = {
		#"mask": %Mask, "hat": %Hat, "glasses": %GearFacial,
		#"suit": %Suit, "jacket": %Jacket, "shirt": %Shirt,
		#"gloves": %Gloves, "belt": %Belt, "pants": %Pants,
		#"shoes": %Shoes, "back": %Back, "mainhand": %MainHand,
		#"ammo": %Ammo, "offhand": %Offhand
	#}
	#
	#var body_map = {
		#"eyes": %Eyes, "wings": %Wings, "tail": %Tail, "horns": %Horns,
		#"hair": %Hair, "hairadd": %HairAddon, "ears": %Ears, "nose": %Nose,
		#"facial": %FacialHair, "add1": %BodyAddon1, "add2": %BodyAddon2, "add3": %BodyAddon3
	#}
#
	#var get_id_from_config = func(config_path: String) -> String:
		#if config_path.is_empty(): return "none"
		#var f = FileAccess.open(config_path, FileAccess.READ)
		#if f:
			#var json = f.get_as_text()
			#f.close()
			#var obj = JSON.parse_string(json)
			#return obj.get("id", "none")
		#return "none"
#
	#var apply_part_to_ui = func(ui_node: Control, part_res: Resource, slot_id: String):
		## 1. Obtener ID del item
		#var item_id = "none"
		#if part_res and not part_res.config_path.is_empty():
			#item_id = get_id_from_config.call(part_res.config_path)
		#
		## print("Importing Part: ", slot_id, " ID: ", item_id) # DEBUG
#
		## 2. UI: Sincronizar Dropdown/OptionButton
		#if ui_node is OptionButton:
			#var found = false
			## A) Intentar por Metadata (ID real)
			#for i in ui_node.get_item_count():
				#if ui_node.get_item_metadata(i) == item_id:
					#ui_node.select(i)
					#found = true
					#break
			## B) Intentar por Texto (Fallback)
			#if not found:
				#for i in ui_node.get_item_count():
					#if ui_node.get_item_text(i) == item_id:
						#ui_node.select(i)
						#found = true
						#break
			## C) Si falla, seleccionar 'none' (normalmente índice 0)
			#if not found: ui_node.select(0)
#
		## 3. UI: Actualizar ColorPickers
		#if part_res:
			#update_colors_for(slot_id, part_res.palette1, part_res.palette2, part_res.palette3)
#
		## ==========================================================
		## 4. DATOS INTERNOS (EditorCharacterData)
		## ==========================================================
		#
		## A) Actualizar ID en el diccionario plano
		#if "character" in current_character and current_character.character is Dictionary:
			#current_character.character[slot_id] = item_id
#
		## B) Mapeo de texturas (Slot -> Claves internas)
		#var target_texture_keys = []
		#
		#var simple_map = {
			#"body": "body_texture", "head": "head_texture", "eyes": "eyes_texture",
			#"nose": "nose_texture", "ears": "ears_texture", "facial": "facial_texture",
			#"hair": "hair_texture", "hairadd": "hairadd_texture", "horns": "horns_texture",
			#"mask": "mask_texture", "hat": "hat_texture", "glasses": "glasses_texture",
			#"suit": "suit_texture", "jacket": "jacket_texture", "shirt": "shirt_texture",
			#"gloves": "gloves_texture", "belt": "belt_texture", "pants": "pants_texture",
			#"shoes": "shoes_texture", "add1": "add1_texture", "add2": "add2_texture", "add3": "add3_texture"
		#}
		#
		#if slot_id in simple_map:
			#target_texture_keys.append(simple_map[slot_id])
			#
		## Mapeo complejo
		#match slot_id:
			#"mainhand": target_texture_keys.append_array(["mainhand_texture_front", "mainhand_texture_back"])
			#"offhand": target_texture_keys.append_array(["offhand_texture_front", "offhand_texture_back"])
			#"ammo": target_texture_keys.append_array(["ammo_texture_front", "ammo_texture_back"])
			#"wings": target_texture_keys.append_array(["wings_texture_front", "wings_texture_back"])
			#"tail": target_texture_keys.append_array(["tail_texture_front", "tail_texture_back"])
			#"back": target_texture_keys.append_array(["back_texture_front", "back_texture_back"])
#
		## C) Aplicar datos a las texturas
		#for key in target_texture_keys:
			#if not current_character.textures.has(key): continue
			#
			#var char_part = current_character.textures[key]
			#
			#if part_res and item_id != "none":
				## Definir path
				#var is_front = key.ends_with("_front")
				#char_part.path = part_res.front_texture if is_front else part_res.back_texture
				#char_part.part_id = part_res.part_id
				#
				## Copiar Paletas (Valores RAW)
				#char_part.palette1.colors = part_res.palette1.colors.duplicate()
				#char_part.palette1.blend_color = part_res.palette1.blend_color
				#char_part.palette1.lightness = part_res.palette1.lightness
				#
				#char_part.palette2.colors = part_res.palette2.colors.duplicate()
				#char_part.palette2.blend_color = part_res.palette2.blend_color
				#char_part.palette2.lightness = part_res.palette2.lightness
				#
				#char_part.palette3.colors = part_res.palette3.colors.duplicate()
				#char_part.palette3.blend_color = part_res.palette3.blend_color
				#char_part.palette3.lightness = part_res.palette3.lightness
			#else:
				#char_part.path = ""
#
		#if has_method("_update_texture"):
			#call("_update_texture", slot_id)
		#elif has_method("update_texture"):
			#call("update_texture", slot_id)
#
		#update_colors_for(slot_id, part_res.palette1, part_res.palette2, part_res.palette3)
#
	#if res is IngameCostume:
		#for key in body_map.keys():
			#var part = res.body_parts.get(key)
			#apply_part_to_ui.call(body_map[key], part, key)
			#
		#for key in gear_map.keys():
			#var part = res.equipment_parts.get(key)
			#apply_part_to_ui.call(gear_map[key], part, key)
#
		#if res.body_parts.body:
			#update_colors_for("body", res.body_parts.body.palette1, res.body_parts.body.palette2, res.body_parts.body.palette3)
		#
		#update_items_visibility()
#
	#elif res is RPGLPCEquipmentData:
		#var mode = res.get("application_mode")
		#if mode == null: mode = 0 # Default Strict
		#
		#var weapon_slots = ["mainhand", "offhand", "ammo"]
		#
		#for key in gear_map.keys():
			#var part = res.get(key)
			#var has_part = part and part is RPGLPCEquipmentPart and not part.config_path.is_empty()
			#
			#if has_part:
				#apply_part_to_ui.call(gear_map[key], part, key)
			#else:
				#match mode:
					#0: # Strict
						#gear_map[key].select("none")
					#1: # Hybrid
						#if not key in weapon_slots:
							#gear_map[key].select("none")
					#2: # Partial
						#pass
		#
		#update_items_visibility()
#
	#elif res is RPGLPCEquipmentPart:
		#if res.body_type == current_character.character["body_type"]: # Simple check
			#if res.part_id in gear_map:
				#apply_part_to_ui.call(gear_map[res.part_id], res, res.part_id)
				#update_items_visibility()
		#else:
			#printerr("Character Creator: Part body type mismatch.")
#
	#elif res is RPGLPCCharacter:
		#var parent = get_parent().get_parent()
		#if "confirm_dialog_options" in parent and parent.confirm_dialog_options is RPGCharacterCreationOptions:
			#var options = parent.confirm_dialog_options
			#var actor_name = data_path.get_file().get_basename()
			#options.name = actor_name
			#options.character_folder = data_path.get_base_dir() + "/"
			#options.equipment_folder = options.character_folder
#
		#var palettes_node = %Palettes
		#palettes_node.select(0)
		#for i in palettes_node.get_item_count():
			#if palettes_node.get_item_metadata(i) == res.palette:
				#palettes_node.select(i)
				#break
				#
		#var race_node = %Races
		#race_node.select(0)
		#for i in race_node.get_item_count():
			#if race_node.get_item_metadata(i) == res.race:
				#race_node.select(i)
				#break
		#race_node.item_selected.emit(race_node.get_selected())
		#
		#%Gender.select(res.gender)
		#%Body.select(res.body_type)
#
		#if res.body_parts.body:
			#update_colors_for("body", res.body_parts.body.palette1, res.body_parts.body.palette2, res.body_parts.body.palette3)
#
		#for key in body_map.keys():
			#var part = res.body_parts.get(key)
			#apply_part_to_ui.call(body_map[key], part, key)
#
		#for key in gear_map.keys():
			#var part = res.equipment_parts.get(key)
			#apply_part_to_ui.call(gear_map[key], part, key)
#
		#update_items_visibility()
		#
		#res.unreference()


func import_data(data_path: String) -> void:
	if !data_path:
		return
		
	var res = load(data_path)
	if not res:
		return

	if res is RPGLPCEquipmentPart:
		_import_single_part(res)
	elif res is RPGLPCCharacter:
		_import_full_character(res)
	elif res is RPGLPCEquipmentData:
		_import_equipment_set(res)
	elif res is IngameCostume:
		_import_ingame_costume(res)
		
	if res is RefCounted:
		res.unreference()


func _get_id_from_config(config_path: String) -> String:
	if config_path.is_empty():
		return "none"
	var f = FileAccess.open(config_path, FileAccess.READ)
	if f:
		var json_text = f.get_as_text()
		f.close()
		var obj = JSON.parse_string(json_text)
		if obj:
			return obj.get("id", "none")
	return "none"


func _is_item_compatible_with_current_body(slot_id: String, item_id: String) -> bool:
	if not data.gear.has(slot_id): return false
	if not data.gear[slot_id].has(item_id): return false
	
	var item_config = data.gear[slot_id][item_id]
	
	if not "textures" in item_config:
		return true
		
	var current_body = current_character.character["body_type"]
	var current_head = current_character.character["head_type"]
	
	for tex in item_config.textures:
		var body_match = (not tex.has("body")) or (tex.body == current_body)
		var head_match = (not tex.has("head")) or (tex.head == current_head)
		
		if body_match and head_match:
			return true
			
	return false


func _updata_colors_and_select_item(res: RPGLPCEquipmentPart) -> void:
	var parts = {
		"mask": %Mask, "hat": %Hat, "glasses": %GearFacial, "suit": %Suit,
		"jacket": %Jacket, "shirt": %Shirt, "gloves": %Gloves, "belt": %Belt,
		"pants": %Pants, "shoes": %Shoes, "back": %Back,"mainhand": %MainHand,
		"ammo": %Ammo, "offhand": %Offhand
	}

	var config_path: String = res.config_path
	var f = FileAccess.open(config_path, FileAccess.READ)
	var json: String = f.get_as_text()
	f.close()
	var obj: Dictionary = JSON.parse_string(json)
	update_colors_for(res.part_id, res.palette1, res.palette2, res.palette3)
	parts[res.part_id].select(obj.get("id", "none"))
	update_items_visibility()


func _import_single_part(res: RPGLPCEquipmentPart) -> void:
	var parts = {
		"mask": %Mask, "hat": %Hat, "glasses": %GearFacial,
		"suit": %Suit, "jacket": %Jacket, "shirt": %Shirt,
		"gloves": %Gloves, "belt": %Belt, "pants": %Pants,
		"shoes": %Shoes, "back": %Back, "mainhand": %MainHand,
		"ammo": %Ammo, "offhand": %Offhand
	}
	
	if not res.part_id in parts:
		return

	var item_id = _get_id_from_config(res.config_path)
	if item_id == "none":
		return

	if not _is_item_compatible_with_current_body(res.part_id, item_id):
		printerr("Item '%s' (Slot: %s) not compatible with current body type." % [item_id, res.part_id])
		return

	_updata_colors_and_select_item(res)


func _import_full_character(res: RPGLPCCharacter) -> void:
	# 1. Set Global Stats (Palette, Race, Gender, Body)
	var palettes_node = %Palettes
	palettes_node.select(0)
	for i in palettes_node.get_item_count():
		if palettes_node.get_item_metadata(i) == res.palette:
			palettes_node.select(i)
			break
			
	var race_node = %Races
	race_node.select(0)
	for i in race_node.get_item_count():
		if race_node.get_item_metadata(i) == res.race:
			race_node.select(i)
			break
	race_node.item_selected.emit(race_node.get_selected())
	
	%Gender.select(res.gender)
	%Body.select(res.body_type)

	# 2. Extract and Apply Base Body Colors
	# (Logic preserved exactly from your snippet)
	var palette_data = {
		"c1a": res.body_parts.body.palette1, "c1b": res.body_parts.body.palette2, "c1c": res.body_parts.body.palette3,
		"c2a": res.body_parts.head.palette1, "c2b": res.body_parts.head.palette2, "c2c": res.body_parts.head.palette3,
		"c3a": res.body_parts.nose.palette1, "c3b": res.body_parts.nose.palette2, "c3c": res.body_parts.nose.palette3,
		"c4a": res.body_parts.ears.palette1, "c4b": res.body_parts.ears.palette2, "c4c": res.body_parts.ears.palette3
	}
	var type_id = "body"
	if not palette_data.c1a.colors:
		if palette_data.c2a.colors: type_id = "head"
		elif palette_data.c3a.colors: type_id = "nose"
		else: type_id = "ears"
		
	var current_var_id = 1
	if type_id == "head": current_var_id = 2
	elif type_id == "nose": current_var_id = 3
	elif type_id == "ears": current_var_id = 4
	
	var pal1 = palette_data["c%sa" % current_var_id]
	var pal2 = palette_data["c%sb" % current_var_id]
	var pal3 = palette_data["c%sc" % current_var_id]
	
	update_colors_for("body", pal1, pal2, pal3)

	# 3. Apply Body Parts
	var body_nodes = [%Eyes, %Wings, %Tail, %Horns, %Hair, %HairAddon, %Ears, %Nose, %FacialHair, %BodyAddon1, %BodyAddon2, %BodyAddon3]
	var body_ids = ["eyes", "wings", "tail", "horns", "hair", "hairadd", "ears", "nose", "facial", "add1", "add2", "add3"]
	
	for i in body_nodes.size():
		var id = body_ids[i]
		var part = res.body_parts.get(id)
		if part:
			var id_name = _get_id_from_config(part.config_path)
			body_nodes[i].select(id_name)
			update_colors_for(id, part.palette1, part.palette2, part.palette3)

	# 4. Apply Gear Parts
	var gear_nodes = [%Mask, %Hat, %GearFacial, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants, %Shoes, %Back, %MainHand, %Ammo, %Offhand]
	var gear_ids = ["mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt", "pants", "shoes", "back", "mainhand", "ammo", "offhand"]
	
	for i in gear_nodes.size():
		var id = gear_ids[i]
		var part = res.equipment_parts.get(id)
		if part:
			var id_name = _get_id_from_config(part.config_path)
			gear_nodes[i].select(id_name)
			update_colors_for(id, part.palette1, part.palette2, part.palette3)

	update_items_visibility()


func _import_equipment_set(res: RPGLPCEquipmentData) -> void:
	var gear_nodes = {
		"mask": %Mask, "hat": %Hat, "glasses": %GearFacial,
		"suit": %Suit, "jacket": %Jacket, "shirt": %Shirt,
		"gloves": %Gloves, "belt": %Belt, "pants": %Pants,
		"shoes": %Shoes, "back": %Back, "mainhand": %MainHand,
		"ammo": %Ammo, "offhand": %Offhand
	}
	
	# Determine Mode (Default Strict = 0)
	var mode = res.get("application_mode")
	if mode == null: mode = 0
	var weapon_slots = ["mainhand", "offhand", "ammo"]

	for id in gear_nodes.keys():
		var part = res.get(id)
		var has_part = part and part is RPGLPCEquipmentPart and not part.config_path.is_empty()
		
		if has_part:
			# Apply Part
			var id_name = _get_id_from_config(part.config_path)
			update_colors_for(id, part.palette1, part.palette2, part.palette3)
			gear_nodes[id].select(id_name)
		else:
			# Handle Missing Part based on Mode
			match mode:
				0: # Strict (Clear everything not in set)
					gear_nodes[id].select("none")
				1: # Hybrid (Clear clothes, keep weapons)
					if not id in weapon_slots:
						gear_nodes[id].select("none")
				2: # Partial (Do nothing)
					pass
					
	update_items_visibility()


func _import_ingame_costume(res: IngameCostume) -> void:
	# Logic is similar to full character but we don't set Race/Gender/Global Palette
	# We only strictly apply the visual parts stored in the costume
	
	# 1. Apply Body Parts
	var body_nodes = {
		"eyes": %Eyes, "wings": %Wings, "tail": %Tail, "horns": %Horns, 
		"hair": %Hair, "hairadd": %HairAddon, "ears": %Ears, "nose": %Nose, 
		"facial": %FacialHair, "add1": %BodyAddon1, "add2": %BodyAddon2, "add3": %BodyAddon3
	}
	
	for id in body_nodes.keys():
		var part = res.body_parts.get(id)
		if part:
			var id_name = _get_id_from_config(part.config_path)
			update_colors_for(id, part.palette1, part.palette2, part.palette3)
			body_nodes[id].select(id_name)
			
	# 2. Apply Gear Parts
	var gear_nodes = {
		"mask": %Mask, "hat": %Hat, "glasses": %GearFacial,
		"suit": %Suit, "jacket": %Jacket, "shirt": %Shirt,
		"gloves": %Gloves, "belt": %Belt, "pants": %Pants,
		"shoes": %Shoes, "back": %Back, "mainhand": %MainHand,
		"ammo": %Ammo, "offhand": %Offhand
	}

	for id in gear_nodes.keys():
		var part = res.equipment_parts.get(id)
		if part:
			var id_name = _get_id_from_config(part.config_path)
			update_colors_for(id, part.palette1, part.palette2, part.palette3)
			gear_nodes[id].select(id_name)

	# 3. Base Body Color (if stored in body_parts.body)
	if res.body_parts.body:
		var p = res.body_parts.body
		update_colors_for("body", p.palette1, p.palette2, p.palette3)

	update_items_visibility()


func update_colors_for(part_id: String, pal1: RPGLPCPalette, pal2: RPGLPCPalette, pal3: RPGLPCPalette, clone_palettes: bool = true) -> void:
	if clone_palettes:
		pal1 = pal1.clone(true)
		pal2 = pal2.clone(true)
		pal3 = pal3.clone(true)
	var ids = ["%s_texture_back" % part_id, "%s_texture" % part_id, "%s_texture_front" % part_id]
	for id in ids:
		var tex: CharacterPart = current_character.textures.get(id)
		if tex:
			tex.palette1.item_selected = -2
			tex.palette1.blend_color = pal1.blend_color
			tex.palette1.lightness = pal1.lightness
			tex.palette1.colors = pal1.colors
			tex.palette2.item_selected = -2
			tex.palette2.blend_color = pal2.blend_color
			tex.palette2.lightness = pal2.lightness
			tex.palette2.colors = pal2.colors
			tex.palette3.item_selected = -2
			tex.palette3.blend_color = pal3.blend_color
			tex.palette3.lightness = pal3.lightness
			tex.palette3.colors = pal3.colors
	
	var palette_data: Dictionary = {
		"blend_color1": pal1.blend_color,
		"blend_color2": pal2.blend_color,
		"blend_color3": pal3.blend_color,
		"lightness1": pal1.lightness,
		"lightness2": pal2.lightness,
		"lightness3": pal3.lightness,
		"palette1": pal1.colors,
		"palette2": pal2.colors,
		"palette3": pal3.colors,
		"original_palette1": pal1.colors,
		"original_palette2": pal2.colors,
		"original_palette3": pal3.colors
	}
	_on_palette_changed(part_id, palette_data)
	
	if part_id == "body":
		update_colors_for("head", pal1, pal2, pal3)
		update_colors_for("nose", pal1, pal2, pal3)
		update_colors_for("ears", pal1, pal2, pal3)


func _on_reset_pressed() -> void:
	set_data()


#region Save Data
func _on_save(options: RPGCharacterCreationOptions) -> void:
	_setup_folders(options)
	var character_data = _create_character_data(options)
	_setup_saving_ui()
	
	await _prepare_character_for_saving()
	
	if options.create_face_preview:
		await _save_face_preview(options, character_data)
	
	if options.create_character_preview:
		await _save_character_preview(options, character_data)
	
	if options.create_battler_preview:
		await _save_battler_preview(options, character_data)
	
	if options.create_event_character:
		await _save_event_preview(options, character_data)
	
	if options.create_character:
		_save_character_scene(options, character_data)

	if options.create_character or options.create_event_character:
		await _save_walking_texture(options)
	
	if options.create_event_character:
		await _save_event_scene(options, character_data)
	
	if options.create_equipment_parts:
		_update_progress(20)
		await _save_equipment_parts(options, character_data)
	
	if options.create_equipment_set:
		_update_progress(30)
		await _save_equipment_set_process(options, character_data)
	
	if options.create_ingame_costume:
		_update_progress(40)
		await _save_ingame_costume_process(options, character_data)
	
	_cleanup_saving()
	
	EditorInterface.get_resource_filesystem().scan()


# Setup Methods
func _setup_folders(options: RPGCharacterCreationOptions) -> void:
	var character_folder = _get_character_folder_path(options)
	var equipment_folder = options.equipment_folder if options.create_equipment_parts else ""
	
	if _should_create_character_folder(options):
		_create_directory_if_needed(character_folder)
	
	if equipment_folder:
		_create_directory_if_needed(equipment_folder)


func _get_character_folder_path(options: RPGCharacterCreationOptions) -> String:
	var folder = options.character_folder
	if options.create_sub_folder:
		folder = folder.path_join(options.name.capitalize().replace(" ", "_"))
	return folder + "/" if !folder.ends_with("/") else folder


func _should_create_character_folder(options: RPGCharacterCreationOptions) -> bool:
	return (
		options.create_character or
		options.create_battler_preview or
		options.create_character_preview or
		options.create_face_preview or
		options.create_event_character
	)


func _create_directory_if_needed(path: String) -> void:
	var absolute_path = ProjectSettings.globalize_path(path)
	if !DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_recursive_absolute(absolute_path)


# Character Data Creation
func _create_character_data(options: RPGCharacterCreationOptions) -> RPGLPCCharacter:
	var character_data = RPGLPCCharacter.new()
	_set_character_basic_data(character_data, options)
	_set_body_parts(character_data)
	_set_equipment_parts(character_data)
	return character_data


func _set_character_basic_data(character_data: RPGLPCCharacter, options: RPGCharacterCreationOptions) -> void:
	character_data.body_type = current_character.character["body_type"]
	character_data.head_type = current_character.character["head_type"]
	character_data.palette = current_character.character.palette
	character_data.race = current_character.character.race
	character_data.gender = current_character.character.gender
	character_data.inmutable = options.inmutable
	character_data.always_show_weapon = options.always_show_weapon
	character_data.hidden_items = get_items_hidden()


func _set_body_parts(character_data: RPGLPCCharacter) -> void:
	var body_part_items = [
		"body", "head", "eyes", "wings", "tail", "horns", "hair", "hairadd",
		"ears", "nose", "facial", "add1", "add2", "add3"
	]
	
	for item in body_part_items:
		var item_data = _create_body_part_data(item)
		character_data.body_parts[item] = item_data


func _create_body_part_data(item: String) -> RPGLPCBodyPart:
	var texture_back_data = current_character.textures.get(item + "_texture_back", null)
	var texture_front_data = _get_front_texture_data(item)
	
	var item_data = RPGLPCBodyPart.new()
	item_data.part_id = item
	item_data.is_large_texture = texture_front_data.is_large_texture
	item_data.is_alt = texture_front_data.is_alt
	
	_set_config_path(item_data, item, texture_front_data)
	_set_textures(item_data, texture_back_data, texture_front_data)
	_set_palettes(item_data, item)
	
	return item_data


func _get_front_texture_data(item: String) -> CharacterPart:
	var texture_front_data = current_character.textures.get(item + "_texture_front", null)
	if !texture_front_data:
		texture_front_data = current_character.textures.get(item + "_texture", null)
	return texture_front_data


func _set_config_path(item_data: RPGLPCBodyPart, item: String, texture_front_data: CharacterPart) -> void:
	if item == "body":
		var current_body = get_current_body()
		var body_data = data.characters[item][current_body.body[0]]
		item_data.config_path = body_data.config_path
	else:
		item_data.config_path = data.characters[texture_front_data.part_id][texture_front_data.item_id].config_path
	
	if item == "hair":
		_set_hair_alt_config(item_data, texture_front_data)


func _set_hair_alt_config(item_data: RPGLPCBodyPart, texture_front_data: CharacterPart) -> void:
	var alt = data.characters[texture_front_data.part_id][texture_front_data.item_id].get("alt", "")
	var alt_data = data.characters[texture_front_data.part_id].get(alt, null)
	if alt_data:
		item_data.alt_config_path = alt_data.config_path


func _set_textures(item_data, texture_back_data, texture_front_data) -> void:
	if texture_back_data:
		item_data.back_texture = texture_back_data.texture.get_path() if texture_back_data.texture else ""
	if texture_front_data:
		item_data.front_texture = texture_front_data.texture.get_path() if texture_front_data.texture else ""


func _set_palettes(item_data, item: String) -> void:
	if current_palettes.has(item):
		for id in range(1, 4, 1):
			var palette = "palette%s" % id
			item_data[palette].lightness = current_palettes[item]["lightness%s" % id]
			item_data[palette].colors = current_palettes[item][palette]
			item_data[palette].blend_color = int(current_palettes[item]["blend_color%s" % id])


func _set_equipment_parts(character_data: RPGLPCCharacter) -> void:
	var equipment_items = [
		"mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt",
		"pants", "shoes", "back", "mainhand", "offhand", "ammo"
	]
	
	for item in equipment_items:
		var item_data = _create_equipment_part_data(item, character_data)
		character_data.equipment_parts[item] = item_data


func _create_equipment_part_data(item: String, character_data: RPGLPCCharacter) -> RPGLPCEquipmentPart:
	var texture_back_data: CharacterPart = current_character.textures.get(item + "_texture_back", null)
	var texture_front_data: CharacterPart = _get_front_texture_data(item)
	
	var item_data = RPGLPCEquipmentPart.new()
	item_data.part_id = item
	item_data.head_type = character_data.head_type
	item_data.body_type = character_data.body_type
	item_data.config_path = data.gear[texture_front_data.part_id][texture_front_data.item_id].config_path
	item_data.is_large_texture = texture_front_data.is_large_texture
	item_data.name = data.gear[texture_front_data.part_id][texture_front_data.item_id].name
	
	_set_textures(item_data, texture_back_data, texture_front_data)
	_set_palettes(item_data, item)
	
	if item == "mainhand":
		var ammo_id = current_character.character.get("ammo", "")
		if ammo_id and ammo_id.to_lower() != "none":
			var ammo_part_resource = _create_equipment_part_for_saving("ammo", character_data)
			item_data.ammo = ammo_part_resource
	
	return item_data


# UI Setup
func _setup_saving_ui() -> void:
	busy = true
	%EditorCharacter.busy = true
	
	if saving_container:
		_create_saving_overlay()


func _create_saving_overlay() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var overlay = TextureRect.new()
	overlay.texture = tex
	
	var black_back: Image = Image.create(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8)
	black_back.fill(Color(0, 0, 0, 0.65))
	var tex_black_back = ImageTexture.create_from_image(black_back)
	var background = TextureRect.new()
	background.texture = tex_black_back
	
	saving_container.add_child(background)
	saving_container.move_child(background, 0)
	saving_container.add_child(overlay)
	saving_container.move_child(overlay, 0)
	saving_container.visible = true
	
	var progressbar = saving_container.get_node("%ProgressBar")
	progressbar.value = 0


# Character Preparation
func _prepare_character_for_saving() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	backup_visibility = %EditorCharacter.get_texture_visibility()
	backup_animation = %EditorCharacter.get_current_animation_state()
	
	%EditorCharacter.reset_animation()
	
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


#  Preview Saving Methods
func _save_face_preview(options: RPGCharacterCreationOptions, character_data: RPGLPCCharacter) -> void:
	%EditorCharacter.hide_weapon()
	await get_tree().process_frame 
	await RenderingServer.frame_post_draw
	
	var face_img = _create_face_preview_image()
	var image_path = _get_character_folder_path(options) + options.name + "_face.png"
	face_img.save_png(image_path)
	character_data.face_preview = image_path
	_update_progress(10)


func _create_face_preview_image() -> Image:
	var img2: Image = %EditorCharacter.get_face()
	var used_rect = img2.get_used_rect()
	var img3 = Image.create(used_rect.size.x, used_rect.size.y, true, img2.get_format())
	img3.blit_rect(img2, used_rect, Vector2.ZERO)
	
	var sc = min(64 / img3.get_width(), 64 / img3.get_height())
	img3.resize(img3.get_width() * sc, img3.get_height() * sc, Image.INTERPOLATE_NEAREST)
	
	var img = Image.create(64, 64, true, img3.get_format())
	var p = Vector2(32, 64) - Vector2(img3.get_width() * 0.5, img3.get_height())
	img.blit_rect(img3, Rect2(0, 0, img3.get_width(), img3.get_height()), p)
	
	return img


func _save_character_preview(options: RPGCharacterCreationOptions, character_data: RPGLPCCharacter) -> void:
	if options.always_show_weapon:
		%EditorCharacter.show_weapon()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	
	var preview_img = _create_character_preview_image()
	var image_path = _get_character_folder_path(options) + options.name + "_character.png"
	preview_img.save_png(image_path)
	character_data.character_preview = image_path
	_update_progress(10)


func _save_battler_preview(options: RPGCharacterCreationOptions, character_data: RPGLPCCharacter) -> void:
	%EditorCharacter.show_weapon()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var battler_img = _create_character_preview_image()
	var image_path = _get_character_folder_path(options) + options.name + "_battler.png"
	battler_img.save_png(image_path)
	character_data.battler_preview = image_path
	_update_progress(10)


func _save_event_preview(options: RPGCharacterCreationOptions, character_data: RPGLPCCharacter) -> void:
	%EditorCharacter.show_weapon()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var event_img = _create_character_preview_image()
	var image_path = _get_character_folder_path(options) + options.name + "_event.png"
	event_img.save_png(image_path)
	character_data.event_preview = image_path
	_update_progress(10)


func _create_character_preview_image() -> Image:
	var img2: Image = %EditorCharacter.get_full_character()
	var used_rect = img2.get_used_rect()
	var img = Image.create(used_rect.size.x, used_rect.size.y, true, img2.get_format())
	img.blit_rect(img2, used_rect, Vector2.ZERO)
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return img


# Scene Saving Methods
func _save_character_scene(options: RPGCharacterCreationOptions, character_data: RPGLPCCharacter) -> void:
	var character_folder = _get_character_folder_path(options)
	var file_path = character_folder + options.name + "_data.tres"
	var scene_file_path = character_folder + options.name + ".tscn"
	var script_file_path = character_folder + options.name + ".gd"
	
	character_data.scene_path = scene_file_path
	ResourceSaver.save(character_data, file_path)
	
	_create_character_script(script_file_path)
	_create_character_scene_file(script_file_path, scene_file_path, character_data, options.name)

func _create_character_script(script_file_path: String) -> void:
	var script = GDScript.new()
	script.source_code = "@tool\nextends LPCCharacter"
	ResourceSaver.save(script, script_file_path)


func _create_character_scene_file(script_file_path: String, scene_file_path: String, character_data: RPGLPCCharacter, name: String) -> void:
	var scn = ACTOR_BASE_SCENE.instantiate()
	scn.set_script(load(script_file_path))
	scn.actor_data = character_data
	scn.name = name.to_pascal_case()
	scn.add_to_group("player")
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(scn)
	ResourceSaver.save(packed_scene, scene_file_path)
	
	scn.free()


func _save_event_scene(options: RPGCharacterCreationOptions, character_data: RPGLPCCharacter) -> void:
	var character_folder = _get_character_folder_path(options)
	var file_path = character_folder + options.name + "_data.tres"
	var scene_file_path = character_folder + options.name + "_event.tscn"
	var script_file_path = character_folder + options.name + "_event.gd"
	
	character_data.scene_path = scene_file_path
	ResourceSaver.save(character_data, file_path)
	
	var scn = await _create_event_scene(script_file_path, options, character_data)
	_save_event_scene_file(scn, scene_file_path, script_file_path, character_data, options.name)


func _create_event_scene(script_file_path: String, options: RPGCharacterCreationOptions, character_data: RPGLPCCharacter):
	var script = GDScript.new()
	var scn
	
	if not options.is_generic_lpc_event:
		script.source_code = "@tool\nextends LPCEvent"
		scn = ACTOR_BASE_SCENE.instantiate()
		scn.collision_layer = 1 << 2
		scn.collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3)
	else:
		script.source_code = "@tool\nextends GenericLPCEvent"
		scn = GENERIC_LPC_BASE_SCENE.instantiate()
	
	ResourceSaver.save(script, script_file_path)
	return scn


func _save_walking_texture(options: RPGCharacterCreationOptions) -> void:
	var img2: Image = %EditorCharacter.get_full_character()
	var img = Image.create(9 * 192, 4 * 192, true, img2.get_format())
	var directions = [
		%EditorCharacter.DIRECTIONS.LEFT,
		%EditorCharacter.DIRECTIONS.DOWN,
		%EditorCharacter.DIRECTIONS.RIGHT,
		%EditorCharacter.DIRECTIONS.UP
	]
	
	var y = 0
	for direction in directions:
		await _create_walking_frames_for_direction(direction, img, y)
		y += 192
	
	var character_folder = _get_character_folder_path(options)
	var absolute_path = ProjectSettings.globalize_path(character_folder)
	if !DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_recursive_absolute(absolute_path)
		
	var image_path = character_folder + options.name + "_character_minimalist.png"
	img.save_png(image_path)
	
	await _refresh_filesystem()


func _create_walking_frames_for_direction(direction: int, img: Image, y: int) -> void:
	var x = 0
	
	# Idle frame
	%EditorCharacter.current_animation = "idle"
	%EditorCharacter.current_frame = 0
	%EditorCharacter.current_direction = direction
	%EditorCharacter.run_animation()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 = %EditorCharacter.get_full_character()
	img.blit_rect(img2, Rect2i(0, 0, 192, 192), Vector2i(x, y))
	x += 192
	
	# Walking frames
	for i in 8:
		%EditorCharacter.current_animation = "walk"
		%EditorCharacter.current_frame = i
		%EditorCharacter.run_animation()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		img2 = %EditorCharacter.get_full_character()
		img.blit_rect(img2, Rect2i(0, 0, 192, 192), Vector2i(x, y))
		x += 192


func _refresh_filesystem() -> void:
	var editor_fs = EditorInterface.get_resource_filesystem()
	editor_fs.scan()
	editor_fs.scan_sources()
	await editor_fs.filesystem_changed
	
	%EditorCharacter.current_animation = "idle"
	%EditorCharacter.current_frame = 0
	%EditorCharacter.current_direction = %EditorCharacter.DIRECTIONS.DOWN
	%EditorCharacter.run_animation()
	await RenderingServer.frame_post_draw


func _save_event_scene_file(scn, scene_file_path: String, script_file_path: String, character_data: RPGLPCCharacter, name: String) -> void:
	scn.set_script(load(script_file_path))
	scn.event_data = character_data
	scn.name = name.to_pascal_case()
	scn.add_to_group("event")
	#scn._build()
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(scn)
	ResourceSaver.save(packed_scene, scene_file_path)
	
	scn.free()


# Equipment Parts Saving
func _save_equipment_parts(options: RPGCharacterCreationOptions, character_data: RPGLPCCharacter) -> void:
	if !DirAccess.dir_exists_absolute(PARTS_ROOT_DIR):
		DirAccess.make_dir_recursive_absolute(PARTS_ROOT_DIR)

	var keys = ["mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt", "pants", "shoes", "back", "mainhand", "offhand", "ammo"]
	var perc = 70.0 / keys.size()
	
	for key in keys:
		_update_progress(perc)
		if options.save_parts[key] == false: 
			continue
		
		await _save_equipment_part(key, PARTS_ROOT_DIR, character_data)


func _save_equipment_part(key: String, _equipment_folder: String, character_data: RPGLPCCharacter) -> void:
	_prepare_character_for_equipment_part(key)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	if !_should_save_equipment_part(key):
		return
	
	var equipment_part_data = _create_equipment_part_for_saving(key, character_data)
	var img = await _capture_equipment_part_image(key)
	
	if !img:
		return
	
	_save_equipment_part_files_hashed(key, equipment_part_data, img)


func _prepare_character_for_equipment_part(key: String) -> void:
	%EditorCharacter.hide_all()
	%EditorCharacter.show_parts_with_id(key)
	
	if ["back", "offhand"].has(key):
		%EditorCharacter.reset_animation(%EditorCharacter.DIRECTIONS.UP)
	else:
		%EditorCharacter.reset_animation(%EditorCharacter.DIRECTIONS.DOWN)


func _should_save_equipment_part(key: String) -> bool:
	return current_character.character[key] and current_character.character[key].to_lower() != "none"


func _create_equipment_part_for_saving(slot_id: String, character_data: RPGLPCCharacter) -> RPGLPCEquipmentPart:
	var original_part = character_data.equipment_parts.get(slot_id)
	if original_part == null: return null

	var new_part = original_part.duplicate()
	
	
	var texture_key = _get_representative_texture_key(slot_id)
	if "textures" in current_character and current_character.textures.has(texture_key):
		var visual_data = current_character.textures[texture_key]
		new_part.palette1.colors = visual_data.palette1.colors.duplicate()
		new_part.palette2.colors = visual_data.palette2.colors.duplicate()
		new_part.palette3.colors = visual_data.palette3.colors.duplicate()
		print("SAVING [", slot_id, "]: User didn't modify colors, taking from visual memory.")

	return new_part

# Helper necesario para saber qué textura mirar (Front vs Back vs Normal)
func _get_representative_texture_key(slot_id: String) -> String:
	var simple_map = {
		"mask": "mask_texture", "hat": "hat_texture", "glasses": "glasses_texture",
		"suit": "suit_texture", "jacket": "jacket_texture", "shirt": "shirt_texture",
		"gloves": "gloves_texture", "belt": "belt_texture", "pants": "pants_texture",
		"shoes": "shoes_texture", 
		# Items complejos: usamos la capa frontal como referencia de color
		"back": "back_texture_front", 
		"mainhand": "mainhand_texture_front", 
		"ammo": "ammo_texture_front", 
		"offhand": "offhand_texture_front",
		"wings": "wings_texture_front",
		"tail": "tail_texture_front",
		# Partes del cuerpo
		"body": "body_texture", "eyes": "eyes_texture", "hair": "hair_texture"
	}
	
	if slot_id in simple_map:
		return simple_map[slot_id]
	
	# Fallback genérico
	return slot_id + "_texture"


func _save_equipment_set_process(options: RPGCharacterCreationOptions, character_data: RPGLPCCharacter) -> void:
	var set_name = options.name + "_set"
	
	var folder = PARTS_ROOT_DIR.path_join("Sets")
	
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)
	
	if not folder.ends_with("/"): folder += "/"
	
	var image_path = folder + set_name + "_preview.png"
	var resource_path = folder + set_name + ".tres"
	
	_prepare_character_for_set_preview()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img = await _capture_set_preview_image()
	if img:
		img.save_png(image_path)
	
	var set_resource = _create_multipart_resource(character_data)
	ResourceSaver.save(set_resource, resource_path)


func _save_ingame_costume_process(options: RPGCharacterCreationOptions, character_data: RPGLPCCharacter) -> void:
	var set_name = options.name + "_costume"
	
	var folder = PARTS_ROOT_DIR.path_join("Costumes")
	
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)
		
	if not folder.ends_with("/"): folder += "/"
	
	var resource_path = folder + set_name + ".tres"
	var image_path = folder + set_name + "_preview.png"

	var costume = IngameCostume.new()
	costume.body_parts = character_data.body_parts.duplicate(true)
	costume.equipment_parts = character_data.equipment_parts.duplicate(true)
	costume.hidden_items = character_data.hidden_items.duplicate()
	
	ResourceSaver.save(costume, resource_path)
	
	%EditorCharacter.reset_animation(%EditorCharacter.DIRECTIONS.DOWN)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img2: Image = %EditorCharacter.get_full_character()
	var used_rect = img2.get_used_rect()
	if used_rect.size != Vector2i.ZERO:
		var img = Image.create(used_rect.size.x, used_rect.size.y, true, img2.get_format())
		img.blit_rect(img2, used_rect, Vector2.ZERO)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(image_path)


func _prepare_character_for_set_preview() -> void:
	%EditorCharacter.hide_all()
	%EditorCharacter.reset_animation(%EditorCharacter.DIRECTIONS.DOWN)
	
	var gear_keys = ["mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt", "pants", "shoes", "back", "mainhand", "offhand", "ammo"]
	
	for key in gear_keys:
		if current_character.character.get(key, "none") != "none":
			%EditorCharacter.show_parts_with_id(key)


func _capture_set_preview_image() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img2: Image = %EditorCharacter.get_full_character()
	var used_rect = img2.get_used_rect()
	
	if used_rect.size == Vector2i.ZERO:
		return null
	
	var img = Image.create(used_rect.size.x, used_rect.size.y, true, img2.get_format())
	img.blit_rect(img2, used_rect, Vector2.ZERO)
	
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	
	return img


func _create_multipart_resource(character_data: RPGLPCCharacter) -> RPGLPCEquipmentData:
	var multipart = RPGLPCEquipmentData.new()
	var gear_keys = ["mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt", "pants", "shoes", "back", "mainhand", "offhand", "ammo"]
	
	for key in gear_keys:
		var item_id = current_character.character.get(key, "none")
		
		if item_id == "none" or item_id == "":
			continue
			
		var part_resource = _create_equipment_part_for_saving(key, character_data)
		
		multipart.set(key, part_resource)
		
	return multipart


func _set_equipment_part_palettes(equipment_part: RPGLPCEquipmentPart, texture_front_data: CharacterPart, texture_back_data: CharacterPart) -> void:
	var d = texture_front_data if texture_front_data else texture_back_data if texture_back_data else null
	if d:
		for palette in ["palette1", "palette2", "palette3"]:
			equipment_part[palette].lightness = d[palette].lightness
			equipment_part[palette].colors = d[palette].colors.duplicate()


func _capture_equipment_part_image(key: String) -> Image:
	var img2: Image
	var used_rect: Rect2
	
	if key != "ammo":
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		img2 = %EditorCharacter.get_full_character()
		used_rect = img2.get_used_rect()
	else:
		return await _capture_ammo_image(key)
	
	if !used_rect:
		return null
	
	var img = Image.create(used_rect.size.x, used_rect.size.y, true, img2.get_format())
	img.blit_rect(img2, used_rect, Vector2.ZERO)
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	
	return img


func _capture_ammo_image(key: String) -> Image:
	var ammo_rects = {
		"arrow": Rect2(5, 0, 31, 5),
		"bolt": Rect2(0, 0, 5, 24),
		"rock": Rect2(0, 0, 7, 6),
		"boomerang": Rect2(192, 0, 64, 64),
		"arcane1": Rect2(64, 0, 32, 32),
		"whip": Rect2(0, 0, 64, 31)
	}
	var ammo_image_name = key # key = current_character.character[key]
	var ammo_folder_path = "res://addons/rpg_character_creator/textures/projectiles/"
	var ammo_path = ammo_folder_path + ammo_image_name + ".png"
	
	if !FileAccess.file_exists(ammo_path):
		return null
	
	%EditorCharacter.set_ammo_preview_texture(load(ammo_path), ammo_rects.get(ammo_image_name, Rect2()))
	await RenderingServer.frame_post_draw
	
	var img2 = %EditorCharacter.get_ammo_preview_texture().get_image()
	var used_rect = img2.get_used_rect()
	
	if !used_rect:
		return null
	
	var img = Image.create(used_rect.size.x, used_rect.size.y, true, img2.get_format())
	img.blit_rect(img2, used_rect, Vector2.ZERO)
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	
	return img


func _save_equipment_part_files_hashed(key: String, equipment_part: RPGLPCEquipmentPart, img: Image) -> void:
	# 1. Setup specific part folder (e.g., res://Assets/Parts/helmet/)
	var part_folder = PARTS_ROOT_DIR.path_join(key)
	if !DirAccess.dir_exists_absolute(part_folder):
		DirAccess.make_dir_recursive_absolute(part_folder)

	# 2. Generate Hash based on colors
	var color_hash = _generate_equipment_hash(equipment_part)

	# 3. Manage Manifest
	var manifest = _load_and_clean_manifest()
	var final_file_path = ""
	var final_image_path = ""

	if manifest.has(color_hash):
		# Hash exists: Overwrite existing file
		final_file_path = manifest[color_hash]
		final_image_path = final_file_path.replace(".tres", "_preview.png")
	else:
		# Hash is new: Generate sequential name
		var equipment_name = _clean_equipment_name(equipment_part.name)
		var paths = _generate_sequential_paths(part_folder, equipment_name)
		final_file_path = paths.file_path
		final_image_path = paths.image_path
		
		# Update Manifest
		manifest[color_hash] = final_file_path
		_save_manifest(manifest)

	# 4. Save Files
	img.save_png(final_image_path)
	equipment_part.equipment_preview = final_image_path
	ResourceSaver.save(equipment_part, final_file_path)


func _generate_equipment_hash(part: RPGLPCEquipmentPart) -> String:
	# Create a unique string based on the part name and all color arrays
	var raw_data = part.name + part.part_id
	
	raw_data += str(part.palette1.colors)
	raw_data += str(part.palette2.colors)
	raw_data += str(part.palette3.colors)
	
	return raw_data.md5_text()


func _load_and_clean_manifest() -> Dictionary:
	var manifest = {}
	
	if FileAccess.file_exists(PARTS_MANIFEST_PATH):
		var file = FileAccess.open(PARTS_MANIFEST_PATH, FileAccess.READ)
		var text = file.get_as_text()
		manifest = JSON.parse_string(text)
		if manifest == null:
			manifest = {}
		file.close()

	# Auto-clean: Remove entries where files no longer exist
	var keys_to_remove = []
	for hash_key in manifest.keys():
		var path = manifest[hash_key]
		if !FileAccess.file_exists(path):
			keys_to_remove.append(hash_key)
	
	if not keys_to_remove.is_empty():
		for k in keys_to_remove:
			manifest.erase(k)
		_save_manifest(manifest)
		
	return manifest


func _save_manifest(manifest: Dictionary) -> void:
	var file = FileAccess.open(PARTS_MANIFEST_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(manifest, "\t")
		file.store_string(json_string)


func _clean_equipment_name(name: String) -> String:
	var equipment_name = clean_numbers(name.to_lower().replace(" ", "_")).trim_suffix("_")
	return equipment_name.replace("(", "").replace(")", "").replace("/", "").replace("\\", "")


func _generate_sequential_paths(folder: String, base_name: String) -> Dictionary:
	var id = 1
	var file_path = ""
	var image_path = ""
	
	while true:
		var suffix = "_" + str(id)
		image_path = folder.path_join(base_name + suffix + "_preview.png")
		file_path = folder.path_join(base_name + suffix + ".tres")
		
		if !FileAccess.file_exists(file_path):
			break
		id += 1
	
	return {"image_path": image_path, "file_path": file_path}


# Utility Methods
func update_controls() -> void:
	var nodes = [
		%Gender, %Body, %Eyes, %Wings, %Tail, %Horns, %Hair, %HairAddon, %Ears,
		%Nose, %FacialHair, %BodyAddon1, %BodyAddon2, %BodyAddon3,
		%Mask, %Hat, %GearFacial, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants,
		%Shoes, %Back, %MainHand, %Ammo, %Offhand
	]
	
	for node in nodes:
		node.reselect()


func _update_progress(value: float) -> void:
	if saving_container:
		var progressbar = saving_container.get_node("%ProgressBar")
		progressbar.value += value


func _cleanup_saving() -> void:
	if saving_container:
		var progressbar = saving_container.get_node("%ProgressBar")
		progressbar.value = 100
	
	for i in 3:
		await RenderingServer.frame_post_draw
	
	%EditorCharacter.restore_texture_visibility(backup_visibility)
	await RenderingServer.frame_post_draw
	
	busy = false
	%EditorCharacter.busy = false
	
	if saving_container:
		_cleanup_ui_elements()
		saving_container.visible = false


func _cleanup_ui_elements() -> void:
	var children_to_remove = []
	for child in saving_container.get_children():
		if child is TextureRect:
			children_to_remove.append(child)
	
	for child in children_to_remove:
		child.queue_free()


# Usado por call_deferred para gestionar la generación asíncrona.
func _generate_and_set_preview(task: Dictionary) -> void:
	if not preview_character: return
	
	is_generating_previews = true
	var node = task.node
	var part_id = task.part_id
	var item_id = task.item_id
	var cache_key = "%s_%s_%s" % [node, part_id, item_id]

	var preview_texture: Texture2D = await _generate_preview_texture_with_clon(task)

	var target_node: CharacterEditorPaletteButton = task.node
	if preview_texture:
		target_node.set_item_icon_at_index(task.index, preview_texture)
		if preview_cache.has(cache_key):
			preview_cache.erase(cache_key)
		preview_cache[cache_key] = preview_texture
	else:
		if part_id == "mainhand" and item_id == "whip":
			target_node.set_item_icon_to_null_at_index(task.index)
		else:
			target_node.set_item_icon_at_index(task.index, null)

	is_generating_previews = false


func _get_clon_current_texture_data(item_data: Dictionary) -> Dictionary:
	var current_texture_data = {}
	var body_type = current_character.character["body_type"]
	var head_type = current_character.character["head_type"]
	var textures = item_data.get("textures", [])
	for t in textures:
		var texture_back = t.get("back", "none")
		var texture_front = t.get("front", "none")
		if texture_back != "none" or texture_front != "none":
			var texture_body = t.get("body", body_type)
			var texture_head = t.get("head", head_type)
			if (texture_body == body_type and texture_head == head_type) or texture_body == texture_head:
				current_texture_data.texture = t
				current_texture_data.alt_id = item_data.get("alt", "")
				current_texture_data.primarycolors = item_data.get("primarycolors", [])
				current_texture_data.secondarycolors = item_data.get("secondarycolors", [])
				current_texture_data.fixedcolors = item_data.get("fixedcolors", [])
				break
	
	return current_texture_data


func _on_clon_body_part_item_changed(part_id: String, item_id: String) -> void:
	preview_character.current_data = current_character.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	preview_character.fix_data()
	
	var character_data = preview_character.current_data
	character_data.character[part_id] = item_id

	if not item_id in data.characters[part_id]:
		return
	var current_data: Dictionary = data.characters[part_id][item_id]
	var current_texture_data: Dictionary = get_current_texture_data(current_data)

	current_texture_data.part_id = part_id
	current_texture_data.item_id = item_id
	
	if not "palette" in character_data.character:
		return
	
	var texture1 = character_data.textures.get(part_id + "_texture", null)
	if texture1:
		texture1.set_texture_data(current_texture_data, data.colormaps[character_data.character.palette].items, enable_pick_random_color)
	var texture2 = character_data.textures.get(part_id + "_texture_back", null)
	if texture2:
		texture2.set_texture_data(current_texture_data, data.colormaps[character_data.character.palette].items, enable_pick_random_color)
	var texture3 = character_data.textures.get(part_id + "_texture_front", null)
	if texture3:
		texture3.set_texture_data(current_texture_data, data.colormaps[character_data.character.palette].items, enable_pick_random_color)
	
	for texture_data in [texture1, texture2, texture3]:
		if texture_data:
			preview_character.update_texture(texture_data)


func _on_clon_gear_part_item_changed(part_id: String, item_id: String) -> void:
	if not item_id in data.gear[part_id]:
		return
		
	preview_character.current_data = current_character.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	preview_character.fix_data()
		
	var character_data = preview_character.current_data
	var current_data = data.gear[part_id][item_id]
	var current_texture_data = get_current_texture_data(current_data)

	current_texture_data.part_id = part_id
	current_texture_data.item_id = item_id
	
	if not "palette" in character_data.character:
		return
	
	var texture1 = character_data.textures.get(part_id + "_texture", null)
	if texture1:
		texture1.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
	var texture2 = character_data.textures.get(part_id + "_texture_back", null)
	if texture2:
		texture2.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
	var texture3 = character_data.textures.get(part_id + "_texture_front", null)
	if texture3:
		texture3.set_texture_data(current_texture_data, data.colormaps[current_character.character.palette].items, enable_pick_random_color)
	
	for texture_data in [texture1, texture2, texture3]:
		if texture_data:
			preview_character.update_texture(texture_data)


# Realiza el renderizado y captura usando el clon
func _generate_preview_texture_with_clon(task: Dictionary) -> Texture2D:
	if !preview_character:
		return null # No puede generar si no hay clon.

	var node = task.node
	var part_id = task.part_id
	var item_id = task.item_id
	var index = task.index
	var texture_to_return: Texture2D = null
	
	var gear_keys = ["ammo", "back", "belt", "glasses", "gloves", "hat", "jacket", "mainhand", "mask", "offhand", "pants", "shirt", "shoes", "suit"]

	if not part_id in gear_keys:
		_on_clon_body_part_item_changed(part_id, item_id)
	else:
		_on_clon_gear_part_item_changed(part_id, item_id)
		
	#preview_character.update_textures()
	preview_character.hide_all()
	preview_character.show_parts_with_id(part_id)
	preview_character.reset_animation(preview_character.DIRECTIONS.DOWN)
	
	if part_id == "ammo":
		await _capture_ammo_image(item_id)

	# 2. Capturar
	# Esperar un ciclo de renderizado para asegurar que los cambios se apliquen
	await get_tree().process_frame 
	await RenderingServer.frame_post_draw
	
	# Capturar el clon
	var full_img: Image
	if part_id == "ammo":
		full_img = %EditorCharacter.get_ammo_preview_texture().get_image()
	else:
		full_img = preview_character.get_full_character()
	var used_rect = full_img.get_used_rect()

	if !used_rect.size.x == 0 and !used_rect.size.y == 0:
		var cropped_img = Image.create(used_rect.size.x, used_rect.size.y, true, full_img.get_format())
		cropped_img.blit_rect(full_img, used_rect, Vector2.ZERO)
		cropped_img = _resize_maintaining_aspect_ratio_centered(cropped_img, PREVIEW_SIZE.x, PREVIEW_SIZE.y)
		texture_to_return = ImageTexture.create_from_image(cropped_img)
	
	return texture_to_return


func _resize_maintaining_aspect_ratio_centered(image: Image, max_width: int, max_height: int) -> Image:
	var original_width = image.get_width()
	var original_height = image.get_height()
	
	# Calcular la relación de aspecto
	var aspect_ratio = float(original_width) / float(original_height)
	
	var new_width = max_width
	var new_height = max_height
	
	# Si la imagen es más ancha, ajustar por ancho
	if aspect_ratio > float(max_width) / float(max_height):
		new_height = int(max_width / aspect_ratio)
	else:
		# Si la imagen es más alta, ajustar por alto
		new_width = int(max_height * aspect_ratio)
	
	image.resize(new_width, new_height, Image.INTERPOLATE_NEAREST)
	
	# Crear imagen final con el tamaño completo PREVIEW_SIZE
	var final_image = Image.create(max_width, max_height, true, image.get_format())
	
	# Calcular posición para centrar
	var offset_x = (max_width - new_width) / 2
	var offset_y = (max_height - new_height) / 2
	
	# Copiar imagen redimensionada en el centro
	final_image.blit_rect(image, Rect2i(Vector2i.ZERO, Vector2i(new_width, new_height)), Vector2i(offset_x, offset_y))
	
	return final_image


## Auxiliar para capturar imágenes de munición directamente del recurso
func _capture_ammo_image_for_preview(ammo_id: String) -> Image:
	var ammo_rects = {
		"arrow": Rect2(5, 0, 31, 5),
		"bolt": Rect2(0, 0, 5, 24),
		"rock": Rect2(0, 0, 7, 6),
		"boomerang": Rect2(192, 0, 64, 64),
		"arcane1": Rect2(64, 0, 32, 32)
	}
	var ammo_folder_path = "res://addons/rpg_character_creator/textures/projectiles/"
	var ammo_path = ammo_folder_path + ammo_id + ".png"
	
	if !FileAccess.file_exists(ammo_path):
		return null
	
	var texture: Texture2D = load(ammo_path)
	var rect = ammo_rects.get(ammo_id, Rect2())
	
	var full_img = texture.get_image()
	var img = Image.create(rect.size.x, rect.size.y, true, full_img.get_format())
	img.blit_rect(full_img, rect, Vector2.ZERO)
	
	return img

#endregion
