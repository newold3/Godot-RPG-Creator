@tool
class_name RPGCharacterCreatorEditor
extends MarginContainer

## Material used for the character parts.
@export var main_material: ShaderMaterial

var body_layers: PackedStringArray = [
	"eyes", "wings", "tail", "horns", "hair", "hairadd",
	"ears", "nose", "facial", "add1", "add2", "add3",
]

var gear_layers: PackedStringArray = [
	"mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt",
	"pants", "shoes", "back", "mainhand", "offhand", "ammo"
]

var data: Dictionary
var _thread: Thread = null
var starting: bool = false
var current_part: String = ""
var tasks: Array = []

@onready var current_character: RPGLPCCharacter = RPGLPCCharacter.new()
@onready var parts_container: HFlowContainer = %PartsContainer
@onready var tabs_container: HFlowContainer = %TabsContainer

const TAB_BUTTON = preload("uid://yq58jhw5uhf1")
const PART_BUTTON = preload("uid://cce7oe3b1jm21")
const DEFAULT_TEXTURE = preload("uid://c2k4jiswpdy88")
const PLUGIN_PATH = "res://addons/rpg_character_creator/"
const PALETTE_BUTTON = preload("uid://mbnqbs4rwy66")

signal data_loaded()


#region Initialization

func _ready() -> void:
	start()


func start() -> void:
	data_loaded.connect(_on_data_loaded)
	_create_tabs()
	_load_initial_data_in_thread()


func _initialize_character() -> void:
	current_character = RPGLPCCharacter.new()
	current_character.palette = "default"


func _on_data_loaded() -> void:
	starting = true
	_set_data_colors()
	set_animations_data()
	fill_palettes()
	fill_races()
	
	_configure_initial_loadout()
	
	starting = false
	
	if not current_part.is_empty():
		select(current_part)


func _configure_initial_loadout() -> void:
	# 1. Base Configuration
	current_character.race = "01human"
	current_character.gender = "male"
	
	var race_data = data.characters.race.get("01human")
	if race_data and race_data.configs.has("regular"):
		var config = race_data.configs["regular"]
		current_character.body_id = "regular"
		current_character.body_type = config.get("body-type", "hm1")
		current_character.head_type = config.get("head-type", "hm1")
	
	# 2. Install Body Parts (Explicit List)
	install_part("body", "human")
	install_part("head", "human")
	install_part("eyes", "human")
	install_part("hair", "afro")
	install_part("ears", "base")
	install_part("nose", "base")
	
	for part in ["wings", "tail", "horns", "hairadd", "facial", "add1", "add2", "add3"]:
		install_part(part, "none")
	
	# 3. Install Gear Parts
	install_part("shirt", "shirt1")
	install_part("pants", "pants")
	
	for part in ["mask", "hat", "glasses", "suit", "jacket", "gloves", "belt", "shoes", "back", "mainhand", "offhand", "ammo"]:
		install_part(part, "none")


func clear_all() -> void:
	data.clear()
	tasks.clear()
	_initialize_character()
	_clear_parts()

#endregion


#region Process & Texture Loading

func _process(_delta: float) -> void:
	if not tasks.is_empty():
		var task = tasks.pop_front()
		_load_button_texture(task)


## Determines the cropping rectangle for a button icon based on the animation data.
## It attempts to find the first frame of the specified animation (e.g., 'idle' or 'slash').
func _get_animation_rect(anim_name: String, is_weapon: bool) -> Rect2:
	# Default fallback (Standard LPC Idle Down frame 0)
	var rect = Rect2(0, 640, 64, 64)
	
	var db = data.weapon_animations.animations if is_weapon else data.player_animations.animations
	var anim_data: Dictionary
	
	for anim in db:
		if anim.id == anim_name:
			anim_data = anim
			break
	
	if "frames" in anim_data and anim_data.frames.size() > 0:
		var frame = anim_data.frames[0]
		var w = 64
		var h = 64
		if "frame_size" in anim_data:
			w = anim_data.frame_size[0]
			h = anim_data.frame_size[1]
			
		if frame is Array and frame.size() >= 2:
			rect = Rect2(frame[0], frame[1], w, h)
			
	return rect


## Loads the icon texture for a UI part button in the background process.
## It handles figuring out if the item is a weapon (requiring attack animation preview)
## or a standard item (using idle preview).
func _load_button_texture(task: Dictionary) -> void:
	if not is_instance_valid(task.button) or task.button.is_queued_for_deletion(): return
	
	var textures: Array[Texture] = []
	var item_data = task.item_data
	var layer = task.layer
	
	var anim_name = "idle_right"
	var is_weapon = false
	var default_size = Vector2(832, 1344)
	var default_rect = Rect2(0, 640, 64, 64)
	
	# Weapons usually look better if we show their action frame (e.g., slash)
	if layer == "mainhand":
		var action = item_data.get("action", "slash")
		anim_name = action + "_right"
		is_weapon = true
	
	var rect = _get_animation_rect(anim_name, is_weapon)

	for t in item_data.textures:
		if "back" in t:
			var path = _fix_path(item_data.textures.back)
			if ResourceLoader.exists(path):
				textures.append(load(path))
		if "front" in t:
			var path = _fix_path(item_data.textures.front)
			if ResourceLoader.exists(path):
				textures.append(load(path))
			
	if not textures.is_empty():
		var t = textures[0]
		# Handle single icon textures vs full spritesheets
		if t.get_width() == 64 or t.get_height() == 64:
			rect = Rect2(0, 0, 64, 64)
		elif t.get_size() == default_size:
			rect = default_rect
	
	if textures.is_empty():
		textures.append(DEFAULT_TEXTURE)
		
	task.button.set_textures(textures, rect)
	_update_colors_for_button(task.button)

#endregion


#region Data Loading & Threading

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
	clear_all()
	_thread = Thread.new()
	_thread.start(set_data.bind("_end_thread"))


func _end_thread() -> void:
	_thread.wait_to_finish()


func set_data(_thread_callable: String = "") -> void:
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
			obj.file = file.get_file().trim_suffix("." + file.get_extension())
			
			# Race data requires special handling for gender/body config splitting
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

#endregion


#region UI Population (Tabs & Lists)

func _create_tabs() -> void:
	var bg = ButtonGroup.new()
	var node = tabs_container
	for child in node.get_child_count():
		node.queue_free()
	var layers = body_layers + gear_layers
	for layer in layers:
		var b = TAB_BUTTON.instantiate()
		b.custom_minimum_size.x = 120
		b.name = layer.to_upper()
		b.text = b.name
		b.button_group = bg
		b.toggled.connect(_select_tab.bind(layer))
		node.add_child(b)


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


func fill_genders(genders: Dictionary, id_selected: String = "") -> void:
	var node = %Gender
	node.clear()
	var current_id: int = 0
	for id in genders:
		var data_name = id.capitalize()
		node.add_item(data_name)
		node.set_item_metadata(-1, id)
		if id == id_selected:
			current_id = node.get_item_count() - 1
	
	node.select(current_id)
	node.item_selected.emit(current_id)


func fill_bodies(id_selected: String) -> void:
	var gender_id = current_character.gender
	if !gender_id:
		return
	var race_id = current_character.race
	if !race_id:
		return
		
	var race = data.characters.race[race_id]

	var bodies = {}
	for key in race.configs.keys():
		var body = race.configs[key]
		if body.gender == gender_id:
			bodies[body.name] = {
				"id": key,
				"name": body.name,
				"head_type": body["head-type"],
				"body_type": body["body-type"]
			}
	
	var node = %Body
	node.clear()
	var current_id: int = 0
	for body in bodies.values():
		var data_name = body.name.capitalize()
		node.add_item(data_name)
		node.set_item_metadata(-1, body)
		if body.id == id_selected:
			current_id = node.get_item_count() - 1
	
	node.select(current_id)
	node.item_selected.emit(current_id)


func _get_body_parts(layer: String) -> Array:
	var parts: Array = []
	var race_id = %Races.get_item_metadata(%Races.get_selected_id())
	
	if race_id in data.characters.race and "configs" in data.characters.race[race_id]:
		var configs: Dictionary = data.characters.race[race_id].configs
		var current_head = current_character.head_type
		var current_gender = current_character.gender
		var current_body = current_character.body_type
		
		for config in configs.values():
			if not layer in config: continue
			
			if (config.gender == current_gender and
				config["body-type"] == current_body and
				config["head-type"] == current_head):
				parts = config[layer]
				break
				
	return parts


func _get_gear_parts(layer: String) -> Array:
	var parts: Array = []
	
	if layer in data.gear:
		parts = data.gear[layer].keys()
		parts.sort()
		
	return parts


func _fill_parts(layer: String, parts: Array) -> void:
	_clear_parts()
	
	# 1. Identify what part is currently installed on the character for this layer
	var current_equipped_id = ""
	var is_body_part = layer in body_layers or layer == "body" or layer == "head"
	var collection = current_character.body_parts if is_body_part else current_character.equipment_parts
	
	if collection:
		var part_res = collection.get(layer)
		if part_res:
			current_equipped_id = part_res.part_id
			
	if current_equipped_id.is_empty():
		current_equipped_id = "none"

	var none_found: bool = false
	
	for part_id in parts:
		var item_data: Dictionary = _get_item_data(layer, part_id)
		
		if not item_data or item_data.item_id == "none": continue

		if item_data.is_empty():
			continue
		var b = PART_BUTTON.instantiate()
		b.name = part_id

		b.tooltip_text = "%s - %s" % [layer.capitalize(), item_data.get("name", part_id)]
		
		b.part_id = layer
		b.item_id = item_data.item_id
		
		tasks.append({"button": b, "item_data": item_data, "layer": layer})

		b.pressed.connect(install_part.bind(layer, part_id))
		b.pressed.connect(_on_part_button_pressed.bind(layer, part_id, item_data))
		b.pressed.connect(request_visibility_update)
		
		parts_container.add_child(b)
		b.set_main_material(main_material.duplicate())
		
		# Focus logic
		if part_id == current_equipped_id:
			call_deferred("_select_button", b)
	
	if not none_found:
		var b = PART_BUTTON.instantiate()
		b.name = "NONE"
		parts_container.add_child(b)
		parts_container.move_child(b, 0)
		var textures: Array[Texture] = [DEFAULT_TEXTURE]
		b.set_textures(textures)
		
		b.pressed.connect(install_part.bind(layer, "none"))
		b.pressed.connect(_on_part_button_pressed.bind(layer, "none", {}))
		b.pressed.connect(request_visibility_update)
		
		if current_equipped_id == "none":
			call_deferred("_select_button", b)
	
	# update items colors
	_update_shaders()


func _clear_parts() -> void:
	var node = parts_container
	for child in node.get_children():
		child.queue_free()
		parts_container.remove_child(child)


func _select_button(button: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(button) and button.is_inside_tree() and not button.is_queued_for_deletion():
		button.grab_focus()

#endregion


#region Part Logic & Management

func _get_item_data(layer: String, item_id: String) -> Dictionary:
	var item: Dictionary = {}
	
	var is_body_part = layer in body_layers or layer == "body" or layer == "head"
	var current_data: Dictionary = data.characters if is_body_part else data.gear
	
	if not layer in current_data or not item_id in current_data[layer]:
		return item
		
	var file_data: Dictionary = current_data[layer][item_id]
	var head_type: String = current_character.head_type
	var body_type: String = current_character.body_type
	var valid_texture: Dictionary = {}
	
	# Find texture matching current body/head configuration
	if "textures" in file_data and file_data.textures is Array:
		for texture_data in file_data.textures:
			var head = texture_data.get("head", head_type)
			var body = texture_data.get("body", body_type)
			
			if head == head_type and body == body_type:
				valid_texture = texture_data
				break
	
	if valid_texture.is_empty():
		return item
		
	item = {
		"layer": layer,
		"item_id": item_id,
		"name": file_data.get("name", item_id),
		"config_path": file_data.get("config_path", ""),
		"textures": valid_texture,
		"action": file_data.get("actions", ["slash"])[0],
		"primarycolors": file_data.get("primarycolors", []),
		"secondarycolors": file_data.get("secondarycolors", []),
		"fixedcolors": file_data.get("fixedcolors", []),
		"is_large": file_data.get("tags", []).find("large") != -1
	}
	
	# Pass through alt data and slot conflicts if present
	if "alt" in file_data:
		item["alt"] = file_data["alt"]
	if "slotsalt" in file_data:
		item["slotsalt"] = file_data["slotsalt"]
	if "slotshidden" in file_data:
		item["slotshidden"] = file_data["slotshidden"]
	
	return item


## Fully installs a part into the current character data.
## Updates the resource with paths, recalculates interactions (hidden slots),
## and configures initial colors if necessary.
func install_part(layer: String, part_id: String) -> void:
	var is_body_part = layer in body_layers or layer == "body" or layer == "head"
	var collection = current_character.body_parts if is_body_part else current_character.equipment_parts
	
	if not collection: return
	
	var part_resource = collection.get(layer)
	if not part_resource: return
	
	var item_data = _get_item_data(layer, part_id)
	var last_part_id = part_resource.part_id
	if last_part_id.is_empty():
		last_part_id = "none"
	
	# Handle uninstallation
	if part_id == "none":
		part_resource.clear()
		part_resource.part_id = part_id
		part_resource.config_path = _fix_path(item_data.get("config_path", ""))
		_recalculate_global_interactions()
		return
	
	# Handle installation
	if not item_data.is_empty():
		part_resource.part_id = part_id
		_update_part_resource(part_resource, item_data)
		if last_part_id == "none" or true:
			_configure_part_colors(part_resource, item_data)
	else:
		part_resource.clear()
		part_resource.part_id = "none"
	
	_recalculate_global_interactions()


func _validate_and_update_all_parts() -> void:
	var all_layers = ["body", "head"] + Array(body_layers) + Array(gear_layers)
	
	for layer in all_layers:
		var is_body_part = layer in body_layers or layer == "body" or layer == "head"
		var collection = current_character.body_parts if is_body_part else current_character.equipment_parts
		
		if not collection: continue
		
		var part_resource = collection.get(layer)
		if not part_resource or part_resource.part_id == "" or part_resource.part_id == "none":
			continue
			
		install_part(layer, part_resource.part_id)
	
	_recalculate_global_interactions()


func _update_part_resource(resource: Resource, item_data: Dictionary) -> void:
	if "textures" in item_data:
		var tex_data = item_data.textures
		if "front_texture" in resource:
			resource.front_texture = _fix_path(tex_data.get("front", ""))
		if "back_texture" in resource:
			resource.back_texture = _fix_path(tex_data.get("back", ""))
		if "equipment_preview" in resource:
			resource.equipment_preview = _fix_path(tex_data.get("preview", ""))

	if "name" in resource:
		resource.name = item_data.get("name", "")
	if "body_type" in resource:
		resource.body_type = current_character.body_type
	if "head_type" in resource:
		resource.head_type = current_character.head_type
	
	if "is_large_texture" in resource:
		resource.is_large_texture = item_data.get("is_large", false)
	
	if "config_path" in resource:
		resource.config_path = _fix_path(item_data.get("config_path", ""))
		
	# Handling Alt Config Path
	if "alt_config_path" in resource:
		if "alt" in item_data:
			var alt_id = item_data.alt
			var alt_data = _get_item_data(item_data.layer, alt_id)
			resource.alt_config_path = _fix_path(alt_data.get("config_path", ""))
		else:
			resource.alt_config_path = ""


## Re-evaluates interactions between gear and body parts across the whole character.
## Checks for 'slotsalt' (items that require body parts to use alternate textures, e.g., gloves squishing sleeves)
## and 'slotshidden' (items that completely hide other slots).
func _recalculate_global_interactions() -> void:
	# 1. Reset Global Flags
	current_character.hidden_items.clear()
	
	var all_body_layers = ["body", "head"] + Array(body_layers)
	for layer in all_body_layers:
		var part = current_character.body_parts.get(layer)
		if part and "is_alt" in part:
			part.is_alt = false

	# 2. Iterate Equipped Gear to Apply Rules
	for layer in gear_layers:
		var gear_part = current_character.equipment_parts.get(layer)
		if not gear_part or gear_part.part_id == "" or gear_part.part_id == "none":
			continue
			
		var item_data = _get_item_data(layer, gear_part.part_id)
		if item_data.is_empty(): continue
		
		# Apply slotsalt: Tells specific body parts to use their 'alt' texture state
		if "slotsalt" in item_data:
			var targets = item_data.slotsalt
			if targets is Array:
				for target_layer in targets:
					var target_part = current_character.body_parts.get(target_layer)
					if target_part and "is_alt" in target_part:
						target_part.is_alt = true
		
		# Apply slotshidden: Tells the renderer to skip these layers entirely
		if "slotshidden" in item_data:
			var targets = item_data.slotshidden
			if targets is Array:
				for target_id in targets:
					if not target_id in current_character.hidden_items:
						current_character.hidden_items.append(target_id)


## Ensures the path is absolute (begins with res://) or prepends the plugin path.
func _fix_path(path: String) -> String:
	if path.is_empty() or path.to_lower() == "none":
		return ""
	if path.begins_with("res://"):
		return path
	return PLUGIN_PATH.path_join(path)

#endregion


#region Color & Gradient Logic

## Configures palettes intelligently when switching parts.
## It decides whether to apply a strict preset (ID >= 0) or merge custom colors (ID -1).
func _configure_part_colors(resource: Resource, item_data: Dictionary) -> void:
	var global_palette_id = current_character.palette
	if not data.colormaps.has(global_palette_id):
		return
	
	var color_map = data.colormaps[global_palette_id]
	
	# Process Primary
	_process_single_palette(resource, item_data, color_map, "primarycolors", "current_primary_color_id", "palette1", "gradient1")
	
	# Process Secondary
	_process_single_palette(resource, item_data, color_map, "secondarycolors", "current_secondary_color_id", "palette2", "gradient2")
	
	# Process Fixed
	_process_single_palette(resource, item_data, color_map, "fixedcolors", "current_fixed_color_id", "palette3", "gradient3")


## Helper function to handle logic for a specific palette type (Primary, Secondary, or Fixed).
func _process_single_palette(resource: Resource, item_data: Dictionary, color_map: Dictionary, list_key: String, id_property: String, palette_prop: String, gradient_prop: String) -> void:
	var presets_list: Array = item_data.get(list_key, [])
	var current_id: int = resource.get(id_property)
	
	# If the new part has no presets for this layer, we can't apply logic.
	if presets_list.is_empty():
		return

	# CASE 1: Standard Preset Selected (ID >= 0)
	if current_id >= 0:
		var new_id = current_id
		
		# Correction: If index is out of bounds for the new part, reset to 0
		if new_id >= presets_list.size():
			new_id = 0
		
		# Apply the color from the valid index
		var color_key = presets_list[new_id]
		var raw_colors = _resolve_colors_from_map(color_map, color_key)
		
		if not raw_colors.is_empty():
			resource[palette_prop].colors = raw_colors.colors
			resource[palette_prop].blend_color = raw_colors.color
			resource.set(gradient_prop, get_gradient(raw_colors.colors))
			resource.set(id_property, new_id)
			
	# CASE 2: Custom Colors (ID == -1)
	# This attempts to keep the user's custom color choices even if the item changes,
	# provided the index keys align.
	else:
		# 1. Get the baseline colors from the FIRST preset of the new part
		var default_key = presets_list[0]
		var default_data = _resolve_colors_from_map(color_map, default_key)
		
		if default_data.is_empty():
			return
			
		var new_colors_array = default_data.colors.duplicate()
		var current_colors_array = resource[palette_prop].colors
		
		# 2. Merge: Overwrite default preset colors with existing player colors where indices match
		var merged_colors = _merge_colors_with_current(new_colors_array, current_colors_array)
		
		# 3. Apply merged colors. Keep ID as -1.
		resource[palette_prop].colors = merged_colors

		resource[palette_prop].blend_color = default_data.color
		resource.set(gradient_prop, get_gradient(merged_colors))


## Merges two color arrays (Array format: [index, color_int, index, color_int...]).
## Uses 'base_colors' structure (indices) and overwrites values using 'source_colors'.
func _merge_colors_with_current(base_colors: Array, source_colors: Array) -> Array:
	var result = base_colors.duplicate()
	
	# Parse source colors into a dictionary for fast lookup: { index_int : color_int }
	var source_map = {}
	for i in range(0, source_colors.size(), 2):
		var idx = int(source_colors[i])
		var col_val = int(source_colors[i+1])
		source_map[idx] = col_val
	
	# Iterate through the base (new part's default) colors
	for i in range(0, result.size(), 2):
		var target_idx = int(result[i])
		
		# If the player already had a color for this index, overwrite it
		if source_map.has(target_idx):
			result[i+1] = source_map[target_idx]
			
	return result


func _get_gradient_for_color(color_id: int, item_id: String, palette_id: String) -> PackedColorArray:
	var item_data: Dictionary
	var current_data
	if current_part in body_layers:
		current_data = data.characters[current_part]
	else:
		current_data = data.gear[current_part]
		
	if current_data and item_id in current_data:
		item_data = current_data[item_id]

	if not item_data:
		return get_gradient([])
	
	var color_key: String
	if palette_id in item_data and item_data[palette_id].size() > color_id:
		color_key = item_data[palette_id][color_id]
	elif palette_id in item_data:
		color_key = item_data[palette_id][0]
	else:
		return get_gradient([])
	
	var item_colors = data.colormaps[current_character.palette].items
	if color_key in item_colors:
		return get_gradient(item_colors[color_key].colors)
		
	return get_gradient([])


## Helper to look up a color definition (e.g. "human_skin_light") inside a specific ColorMap.
func _resolve_colors_from_map(color_map: Dictionary, color_id: String) -> Dictionary:
	if color_map.items.has(color_id):
		var entry = color_map.items[color_id]
		if entry.has("colors"):
			return {"colors": entry.colors, "color": entry.color}
	return {}


## Generates a 256-color gradient from index-color pairs in the input array.
func get_gradient(current_data_color: Array) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray([])
	colors.resize(256)
	
	if current_data_color.size() > 0:
		for i in range(0, current_data_color.size(), 2):
			var index = int(current_data_color[i])
			var color = Color(int(current_data_color[i+1]))
			colors[index] = color
		
	return colors


func _update_shaders() -> void:
	var current_data
	if current_part in body_layers:
		current_data = current_character.body_parts.get(current_part)
	else:
		current_data = current_character.equipment_parts.get(current_part)

	if not current_data.part_id == "none" and not current_data.part_id.is_empty():
		main_material.set_shader_parameter("palette1", current_data.gradient1)
		main_material.set_shader_parameter("palette2", current_data.gradient2)
		main_material.set_shader_parameter("palette3", current_data.gradient3)


func _update_colors_for_button(button: HeroEditorPartButton) -> void:
	var current_data
	if current_part in body_layers:
		current_data = current_character.body_parts.get(current_part)
	else:
		current_data = current_character.equipment_parts.get(current_part)

	var gradient1 = current_data.gradient1 if current_data.current_primary_color_id == -1 and current_data.gradient1 \
		else _get_gradient_for_color(current_data.current_primary_color_id, button.item_id, "primarycolors")
	var gradient2 = current_data.gradient2 if current_data.current_secondary_color_id == -1 and current_data.gradient2 \
		else _get_gradient_for_color(current_data.current_secondary_color_id, button.item_id, "secondarycolors")
	var gradient3 = current_data.gradient3 if current_data.current_fixed_color_id == -1 and current_data.gradient3 \
		else _get_gradient_for_color(current_data.current_primary_color_id, button.item_id, "fixedcolors")
	button.set_shader_colors(gradient1, gradient2, gradient3)


func _set_data_colors() -> void:
	var colors_data = data.colormaps[current_character.palette].items
	var node = %AllPresets
	
	node.clear()
	node.add_item(tr("All colors in palette..."))
	node.set_item_disabled(node.get_item_count() - 1, true)
	
	var f = FileAccess.open("res://addons/rpg_character_creator/Data/ColorMaps/color_list.json", FileAccess.READ)
	var json = f.get_as_text()
	f.close()
	var color_list = JSON.parse_string(json)
	
	for category_id in color_list.keys():
		node.add_separator(category_id.to_upper())
	
		color_list[category_id].sort()
		
		for key in color_list[category_id]:
			var color = colors_data[key]
			var img = Image.create(20, 20, true, Image.FORMAT_RGB8)
			img.fill(Color(int(color.color)))
			var tex = ImageTexture.create_from_image(img)
			node.add_icon_item(tex, color.name)
			node.set_item_metadata(node.get_item_count() - 1, key)
	
	node.select(0)


func _fill_edit_colors() -> void:
	%AllPresets.set_item_text(0, "All colors in palette %s..." % current_character.palette)
	var node = %PartListOptions
	node.clear()
	node.add_item(current_part)
	node.set_disabled(node.get_item_count() == 1)
	
	_fill_palette_presets()


func _fill_palette_presets() -> void:
	var current_data
	if current_part in body_layers:
		current_data = current_character.body_parts.get(current_part)
	else:
		current_data = current_character.equipment_parts.get(current_part)
	
	var item_data = _get_item_data(current_part, current_data.part_id)
	var palette_id = %PaletteSelector.get_selected_id()
	var palette = "primarycolors" if palette_id == 0 else "secondarycolors" if palette_id == 1 else "fixedcolors"
	var color_list = item_data.get(palette, [])
	
	var node = %PalettePresets
	node.clear()
	
	var gradient_label = %GradientLabel
	
	if color_list.is_empty():
		node.add_item("There are no presets.")
	else:
		if palette_id == 0:
			node.add_item("Primary Color Presets - Select...")
			gradient_label.text = "Primary Gradient"
		elif palette_id == 1:
			node.add_item("Secondary Color Presets - Select...")
			gradient_label.text = "Secondary Gradient"
		else:
			node.add_item("Tertiary Color Presets - Select...")
			gradient_label.text = "Tertiary Gradient"
			
		for key in color_list:
			var color = data.colormaps[current_character.palette].items[key]
			var img = Image.create(20, 20, true, Image.FORMAT_RGB8)
			img.fill(Color(int(color.color)))
			var tex = ImageTexture.create_from_image(img)
			node.add_icon_item(tex, color.name)
			node.set_item_metadata(node.get_item_count() - 1, key)
	
	var disabled1 = item_data.get("primarycolors", []).size() == 0
	var disabled2 = item_data.get("secondarycolors", []).size() == 0
	var disabled3 = item_data.get("fixedcolors", []).size() == 0
	%GradientFastButton1.set_disabled(disabled1)
	%GradientFastButton2.set_disabled(disabled2)
	%GradientFastButton3.set_disabled(disabled3)
	%PaletteSelector.set_item_disabled(0, disabled1)
	%PaletteSelector.set_item_disabled(1, disabled2)
	%PaletteSelector.set_item_disabled(2, disabled3)
	
	var index = palette_id
	var current_is_disabled = false
	
	if palette_id == 0 and disabled1: current_is_disabled = true
	elif palette_id == 1 and disabled2: current_is_disabled = true
	elif palette_id == 2 and disabled3: current_is_disabled = true
	
	if current_is_disabled:
		if not disabled1: index = 0
		elif not disabled2: index = 1
		elif not disabled3: index = 2
		else: index = 0
		
	if index != palette_id:
		get_node("%%GradientFastButton%s" % (index + 1)).set_pressed(true)
	
	_fill_current_colors()


func _fill_current_colors() -> void:
	var palette_id = %PaletteSelector.get_selected_id()
	var node = %CurentColorConatiner
	for child in node.get_children():
		child.queue_free()
		node.remove_child(child)
	
	var current_data
	if current_part in body_layers:
		current_data = current_character.body_parts.get(current_part)
	else:
		current_data = current_character.equipment_parts.get(current_part)
	
	var palette: String
	if palette_id == 0:
		palette = "palette1"
	elif palette_id == 1:
		palette = "palette2"
	else:
		palette = "palette3"

	var colors = current_data[palette].colors
	for i in range(2, colors.size(), 2):
		var color = Color(int(colors[i+1]))

		var b = PALETTE_BUTTON.instantiate()
		b.can_be_selected = false
		b.target = {"palette_id": palette_id, "index": node.get_child_count(), "color": color}
		b.pressed.connect(_on_palette_button_pressed)
		node.add_child(b)
		b.color = color


func _apply_color_preset(color_key: String, is_specific_list: bool = false) -> void:
	var is_body_part = current_part in body_layers or current_part == "body" or current_part == "head"
	var collection = current_character.body_parts if is_body_part else current_character.equipment_parts

	var part_resource = collection[current_part]
	if not part_resource or part_resource.part_id == "none":
		return

	var color_map = data.colormaps.get(current_character.palette)
	var color_data = _resolve_colors_from_map(color_map, color_key)
	
	if color_data.is_empty():
		return

	var raw_colors = color_data.colors
	var blend_color = color_data.color
	var gradient = get_gradient(raw_colors)
	
	var palette_idx = %PaletteSelector.get_selected_id()
	
	var new_index_id: int = -1
	if is_specific_list:
		var item_data = _get_item_data(current_part, part_resource.part_id)
		var list_name = "primarycolors"
		match palette_idx:
			1: list_name = "secondarycolors"
			2: list_name = "fixedcolors"
		
		var list = item_data.get(list_name, [])
		new_index_id = list.find(color_key)

	match palette_idx:
		0: # Primary
			part_resource.palette1.colors = raw_colors
			part_resource.palette1.blend_color = blend_color
			part_resource.gradient1 = gradient
			part_resource.current_primary_color_id = new_index_id
		1: # Secondary
			part_resource.palette2.colors = raw_colors
			part_resource.palette2.blend_color = blend_color
			part_resource.gradient2 = gradient
			part_resource.current_secondary_color_id = new_index_id
		2: # Fixed
			part_resource.palette3.colors = raw_colors
			part_resource.palette3.blend_color = blend_color
			part_resource.gradient3 = gradient
			part_resource.current_fixed_color_id = new_index_id

	_update_shaders()
	
	for button in parts_container.get_children():
		if button is HeroEditorPartButton:
			_update_colors_for_button(button)
			
	_fill_current_colors()

#endregion


#region Signal Callbacks

func select(layer: String) -> void:
	var node = tabs_container
	var search_text = layer.to_upper()
	for button in node.get_children():
		if button.text == search_text:
			if button.is_pressed():
				button.set_pressed(false)
			button.set_pressed(true)


func _on_palettes_item_selected(index: int) -> void:
	var palette_id = %Palettes.get_item_metadata(index)
	current_character.palette = palette_id
	%Races.item_selected.emit(%Races.get_selected_id())


func _on_races_item_selected(index: int) -> void:
	var race_id = %Races.get_item_metadata(index)
	if !race_id:
		return
	current_character.race = race_id
	var race = data.characters.race[race_id]
	
	fill_genders(race.genders, current_character.gender)


func _on_gender_item_selected(index: int) -> void:
	var gender_id = %Gender.get_item_metadata(index)
	if !gender_id:
		return
	current_character.gender = gender_id
	
	fill_bodies(current_character.body_id)


func _on_body_item_selected(index: int) -> void:
	var body_data = %Body.get_item_metadata(index)
	if !body_data:
		return

	current_character.body_id = body_data.id
	current_character.body_type = body_data.body_type
	current_character.head_type = body_data.head_type
	
	_validate_and_update_all_parts()
	
	if starting:
		select("eyes")
	else:
		select(current_part)


func _select_tab(value: bool, layer: String) -> void:
	if value:
		current_part = layer
		var parts: Array
		if layer in body_layers:
			parts = _get_body_parts(layer)
		else:
			parts = _get_gear_parts(layer)
		_fill_parts(layer, parts)
		_fill_edit_colors()


func _on_part_button_pressed(layer: String, part_id: String, _item_data: Dictionary) -> void:
	tasks.clear()
	_fill_palette_presets.call_deferred()
	_update_shaders.call_deferred()


func _on_palette_button_pressed(button_data: Dictionary) -> void:
	print(button_data)


func _on_part_list_options_item_selected(index: int) -> void:
	pass # Replace with function body.


func _on_palette_selector_item_selected(index: int) -> void:
	if index == 0:
		%GradientFastButton1.set_pressed(true)
	elif index == 1:
		%GradientFastButton2.set_pressed(true)
	else:
		%GradientFastButton3.set_pressed(true)


func _get_selector_color_data(selector: OptionButton, index: int) -> Dictionary:
	var palette_id = %PaletteSelector.get_selected_id()
	var color_data = {}
	if index > 0:
		selector.select(0)
		color_data = data.colormaps[current_character.palette].items[selector.get_item_metadata(index)]

	return color_data


func _on_all_presets_item_selected(index: int) -> void:
	if index == 0: return
	var color_key = %AllPresets.get_item_metadata(index)
	_apply_color_preset(color_key, false)


func _on_palette_presets_item_selected(index: int) -> void:
	if index == 0: return
	var color_key = %PalettePresets.get_item_metadata(index)
	_apply_color_preset(color_key, true)


func request_visibility_update() -> void:
	pass


func _on_gradient_fast_button_1_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%PaletteSelector.select(0)
		_fill_palette_presets()


func _on_gradient_fast_button_2_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%PaletteSelector.select(1)
		_fill_palette_presets()


func _on_gradient_fast_button_3_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%PaletteSelector.select(2)
		_fill_palette_presets()

#endregion
