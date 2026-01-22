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

# Group definitions for synchronization
const GROUP_SKIN = ["body", "head", "ears", "nose"]
const GROUP_HAIR = ["hair", "hairadd", "facial"]

var data: Dictionary
var _thread: Thread = null
var starting: bool = false
var current_part: String = ""
var editor_hidden_layers: Array[String] = []
var tasks: Array = []
var load_time_budget_ms: int = 10
var auto_select_merge: bool = true

# Stores the current color state for each layer to persist custom choices.
# Keys: p_id, s_id, f_id (indices), p_raw, s_raw (numeric arrays), p_src (source key), p_grad (visual gradient)
var _layer_color_cache: Dictionary = {}

var active_preset_keys: Dictionary = {
	0: "", # Primary Key
	1: "", # Secondary Key
	2: ""  # Tertiary Key
}

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
	if %SynchronizePalettes:
		%SynchronizePalettes.set_pressed_no_signal(auto_select_merge)
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
	
	# 2. Install Body Parts
	install_part("body", "human")
	
	# Install parts that must match the body skin tone
	install_part("head", "human")
	install_part("ears", "base")
	install_part("nose", "base")
	
	# Force color synchronization from Body
	_copy_part_colors("body", "head")
	_copy_part_colors("body", "ears")
	_copy_part_colors("body", "nose")
	
	# Install remaining body parts
	install_part("eyes", "human")
	install_part("hair", "afro")
	
	for part in ["wings", "tail", "horns", "hairadd", "facial", "add1", "add2", "add3"]:
		install_part(part, "none")
	
	# 3. Install Gear Parts
	install_part("shirt", "shirt1")
	install_part("pants", "pants")
	
	for part in ["mask", "hat", "glasses", "suit", "jacket", "gloves", "belt", "shoes", "back", "mainhand", "offhand", "ammo"]:
		install_part(part, "none")


## Helper function to copy color configuration from one part to another.
func _copy_part_colors(source_layer: String, target_layer: String) -> void:
	var source = current_character.body_parts.get(source_layer)
	var target = current_character.body_parts.get(target_layer)
	
	if not source or not target:
		return
	
	# Copy Primary Colors (Palette 1)
	target.palette1.colors = source.palette1.colors.duplicate()
	target.palette1.blend_color = source.palette1.blend_color
	target.gradient1 = source.gradient1.duplicate()
	target.current_primary_color_id = source.current_primary_color_id
	
	# Copy Secondary Colors (Palette 2)
	target.palette2.colors = source.palette2.colors.duplicate()
	target.palette2.blend_color = source.palette2.blend_color
	target.gradient2 = source.gradient2.duplicate()
	target.current_secondary_color_id = source.current_secondary_color_id
	
	# Copy Fixed/Tertiary Colors (Palette 3)
	target.palette3.colors = source.palette3.colors.duplicate()
	target.palette3.blend_color = source.palette3.blend_color
	target.gradient3 = source.gradient3.duplicate()
	target.current_fixed_color_id = source.current_fixed_color_id


func clear_all() -> void:
	data.clear()
	tasks.clear()
	_initialize_character()
	_clear_parts()

#endregion


#region Process & Texture Loading

func _process(_delta: float) -> void:
	if tasks.is_empty():
		return

	var start_time = Time.get_ticks_msec()
	
	while not tasks.is_empty():
		var task = tasks.pop_front()

		if is_instance_valid(task.button) and not task.button.is_queued_for_deletion():
			_load_button_texture(task)

		var current_duration = Time.get_ticks_msec() - start_time

		if current_duration >= load_time_budget_ms:
			break


func _get_animation_rect(anim_name: String, is_weapon: bool) -> Rect2:
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


func _load_button_texture(task: Dictionary) -> void:
	if not is_instance_valid(task.button) or task.button.is_queued_for_deletion(): return
	
	var textures: Array[Texture] = []
	var item_data = task.item_data
	var layer = task.layer
	
	var anim_name = "idle_right"
	var is_weapon = false
	var default_size = Vector2(832, 1344)
	var default_rect = Rect2(0, 640, 64, 64)
	
	if layer == "mainhand":
		var action = item_data.get("action", "slash")
		anim_name = action + "_right"
		is_weapon = true
	
	var rect = _get_animation_rect(anim_name, is_weapon)
	
	if layer == "mainhand" and item_data.item_id in ["boomerang", "whip", "bow4"]:
		if item_data.item_id == "boomerang":
			var path = "uid://bgowkpplctj0k"
			if ResourceLoader.exists(path): textures.append(load(path))
			rect = Rect2(192, 0, 64, 64)
		elif item_data.item_id == "whip":
			var path = "uid://bkhvhv7qoc086"
			if ResourceLoader.exists(path): textures.append(load(path))
			rect = Rect2(0, 0, 26, 43)
		elif item_data.item_id == "bow4":
			rect = Rect2(192, 320, 64, 64) 
			if textures.is_empty():
				for key in item_data.textures:
					var path = _fix_path(item_data.textures[key])
					if ResourceLoader.exists(path): textures.append(load(path))
	elif layer == "ammo":
		match item_data.item_id:
			"arcane1":
				var path = "uid://br3jlxws1cuuy"
				if ResourceLoader.exists(path): textures.append(load(path))
				rect = Rect2(32, 0, 32, 32)
			"arrow":
				var path = "uid://by5msssxinwb4"
				if ResourceLoader.exists(path): textures.append(load(path))
				rect = Rect2(0, 0, 5, 26)
			"bolt":
				var path = "uid://bucs86b4hjn7e"
				if ResourceLoader.exists(path): textures.append(load(path))
				rect = Rect2(0, 0, 5, 23)
			"boomerang":
				var path = "uid://bgowkpplctj0k"
				if ResourceLoader.exists(path): textures.append(load(path))
				rect = Rect2(192, 0, 64, 64)
			"rock":
				var path = "uid://d15fcw4y6o1fe"
				if ResourceLoader.exists(path): textures.append(load(path))
				rect = Rect2(0, 0, 7, 6)
			"whip":
				var path = "uid://bkhvhv7qoc086"
				if ResourceLoader.exists(path): textures.append(load(path))
				rect = Rect2(0, 0, 26, 43)
	else:
		for key in item_data.textures:
			if key == "back":
				var path = _fix_path(item_data.textures[key])
				if ResourceLoader.exists(path): textures.append(load(path))
			if key == "front":
				var path = _fix_path(item_data.textures[key])
				if ResourceLoader.exists(path): textures.append(load(path))
	
		if not textures.is_empty():
			var t = textures[0]
			if t.get_height() == 256:
				rect = Rect2(0, 192, 64, 64)
			elif t.get_width() == 64 or t.get_height() == 64:
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
	%Character.set_character(current_character, editor_hidden_layers)
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
	%Character.set_animation_data(data.player_animations, data.weapon_animations)
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
		b.gui_input.connect(_on_tab_gui_input.bind(b, layer))
		node.add_child(b)


func _on_tab_gui_input(event: InputEvent, button: Button, layer: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if layer in editor_hidden_layers:
			editor_hidden_layers.erase(layer)
			button.modulate.a = 1.0
		else:
			editor_hidden_layers.append(layer)
			button.modulate.a = 0.4
			
		request_visibility_update()


func _on_disable_body_visibility_toggled(toggled_on: bool) -> void:
	var layers = ["body", "head"]
	for layer in layers:
		if toggled_on and layer in editor_hidden_layers:
			editor_hidden_layers.erase(layer)
		elif not toggled_on and not layer in editor_hidden_layers:
			editor_hidden_layers.append(layer)
			
		request_visibility_update()


func _reset_editor_visibility() -> void:
	editor_hidden_layers.clear()
	for button in tabs_container.get_children():
		if button is Button:
			button.modulate.a = 1.0
	request_visibility_update()


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
	
	if layer == "ammo":
		var mainhand = current_character.equipment_parts.get("mainhand")
		if not mainhand or mainhand.part_id == "none" or mainhand.part_id.is_empty():
			return parts
		var weapon_data = _get_item_data("mainhand", mainhand.part_id)
		var allowed_ammo = weapon_data.get("ammo", [])
		if layer in data.gear:
			for id in allowed_ammo:
				if data.gear[layer].has(id):
					parts.append(id)
		return parts
	
	if layer in data.gear:
		parts = data.gear[layer].keys()
		parts.sort()
		
	return parts


func _fill_parts(layer: String, parts: Array) -> void:
	_clear_parts()
	
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
		b.save.connect(_on_part_save_requested)
		
		parts_container.add_child(b)
		b.set_main_material(main_material.duplicate())
		if is_body_part and not layer in ["hair", "facial", "hairadd"]:
			b.hide_save_button()
		
		if part_id == current_equipped_id:
			call_deferred("_select_button", b)
	
	if not none_found:
		var b = PART_BUTTON.instantiate()
		b.name = "NONE"
		b.hide_save_button()
		parts_container.add_child(b)
		parts_container.move_child(b, 0)
		var textures: Array[Texture] = [DEFAULT_TEXTURE]
		b.set_textures(textures)
		
		b.pressed.connect(install_part.bind(layer, "none"))
		b.pressed.connect(_on_part_button_pressed.bind(layer, "none", {}))
		b.pressed.connect(request_visibility_update)
		
		if current_equipped_id == "none":
			call_deferred("_select_button", b)
	
	_update_shaders()


func _clear_parts() -> void:
	var node = parts_container
	for child in node.get_children():
		child.queue_free()
		parts_container.remove_child(child)
	for task in tasks:
		task.button.queue_free()
	tasks.clear()


func _select_button(button: Control) -> void:
	if not is_inside_tree(): return
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
		"is_large": file_data.get("tags", []).find("large") != -1,
		"ammo": file_data.get("ammo", [])
	}
	
	if "alt" in file_data: item["alt"] = file_data["alt"]
	if "slotsalt" in file_data: item["slotsalt"] = file_data["slotsalt"]
	if "slotshidden" in file_data: item["slotshidden"] = file_data["slotshidden"]
	
	var parent_layer = ""
	if layer in ["head", "ears", "nose"]:
		parent_layer = "body"
	elif layer in ["hairadd", "facial"]:
		parent_layer = "hair"
	
	if parent_layer != "":
		var lists_to_check = ["primarycolors", "secondarycolors", "fixedcolors"]
		var needs_inheritance = false
		for list_name in lists_to_check:
			if item[list_name].is_empty():
				needs_inheritance = true
				break
		
		if needs_inheritance:
			var parent_part_id = ""
			
			if parent_layer in ["body", "head"] or parent_layer in body_layers:
				var parent_res = current_character.body_parts.get(parent_layer)
				if parent_res: parent_part_id = parent_res.part_id
			
			if parent_part_id == "" or parent_part_id == "none":
				if parent_layer == "body": parent_part_id = "human"
				elif parent_layer == "hair": parent_part_id = "afro"
			
			var parent_data = _get_raw_item_data_for_inheritance(parent_layer, parent_part_id)
			
			if not parent_data.is_empty():
				for list_name in lists_to_check:
					if item[list_name].is_empty():
						item[list_name] = parent_data.get(list_name, []).duplicate()

	return item


func _get_raw_item_data_for_inheritance(layer: String, item_id: String) -> Dictionary:
	var current_data: Dictionary = data.characters # Asumimos que los padres (body/hair) siempre son characters
	
	if not layer in current_data or not item_id in current_data[layer]:
		return {}
		
	var file_data = current_data[layer][item_id]
	
	return {
		"primarycolors": file_data.get("primarycolors", []),
		"secondarycolors": file_data.get("secondarycolors", []),
		"fixedcolors": file_data.get("fixedcolors", [])
	}


func install_part(layer: String, part_id: String) -> void:
	var is_body_part = layer in body_layers or layer == "body" or layer == "head"
	var collection = current_character.body_parts if is_body_part else current_character.equipment_parts
	
	if not collection: return
	
	var part_resource = collection.get(layer)
	if not part_resource: return
	
	var item_data = _get_item_data(layer, part_id)
	
	if part_id == "none":
		part_resource.clear()
		part_resource.part_id = part_id
		part_resource.config_path = _fix_path(item_data.get("config_path", ""))
		if layer == "mainhand":
			var current_ammo = current_character.equipment_parts.get("ammo")
			if current_ammo and current_ammo.part_id != "none" and not current_ammo.part_id.is_empty():
				install_part("ammo", "none")
		_recalculate_global_interactions()
		return
	
	if not item_data.is_empty():
		part_resource.part_id = part_id
		_update_part_resource(part_resource, item_data)
		_configure_part_colors_from_cache(layer, part_resource, item_data)
	else:
		part_resource.clear()
		part_resource.part_id = "none"
	
	if layer == "mainhand":
		var allowed_ammo: Array = item_data.get("ammo", [])
		var current_ammo_part = current_character.equipment_parts.get("ammo")
		var current_ammo_id = current_ammo_part.part_id if current_ammo_part else "none"
		if allowed_ammo.is_empty():
			if current_ammo_id != "none" and not current_ammo_id.is_empty():
				install_part("ammo", "none")
		else:
			if not current_ammo_id in allowed_ammo:
				var default_ammo = allowed_ammo[0]
				if data.gear.has("ammo") and data.gear.ammo.has(default_ammo):
					install_part("ammo", default_ammo)
				else:
					install_part("ammo", "none")
	
	if layer == current_part:
		_refresh_active_keys()
		
	_recalculate_global_interactions()


func _validate_and_update_all_parts() -> void:
	var all_layers = ["body", "head"] + Array(body_layers) + Array(gear_layers)
	
	for layer in all_layers:
		var is_body_part = layer in body_layers or layer == "body" or layer == "head"
		var collection = current_character.body_parts if is_body_part else current_character.equipment_parts
		
		if not collection: continue
		
		var part_resource = collection.get(layer)
		
		if part_resource.part_id != "" and part_resource.part_id != "none":
			install_part(layer, part_resource.part_id)
		
		if part_resource.part_id == "none" and is_body_part:
			var candidates = _get_body_parts(layer)
			for candidate_id in candidates:
				var item_data = _get_item_data(layer, candidate_id)
				if not item_data.is_empty():
					install_part(layer, candidate_id)
					break
	
	_recalculate_global_interactions()


func _update_part_resource(resource: Resource, item_data: Dictionary) -> void:
	if "textures" in item_data:
		var tex_data = item_data.textures
		if "front_texture" in resource: resource.front_texture = _fix_path(tex_data.get("front", ""))
		if "back_texture" in resource: resource.back_texture = _fix_path(tex_data.get("back", ""))
		if "equipment_preview" in resource: resource.equipment_preview = _fix_path(tex_data.get("preview", ""))

	if "name" in resource: resource.name = item_data.get("name", "")
	if "body_type" in resource: resource.body_type = current_character.body_type
	if "head_type" in resource: resource.head_type = current_character.head_type
	
	if "is_large_texture" in resource: resource.is_large_texture = item_data.get("is_large", false)
	
	if "config_path" in resource: resource.config_path = _fix_path(item_data.get("config_path", ""))
		
	if "alt_config_path" in resource:
		if "alt" in item_data:
			var alt_id = item_data.alt
			var alt_data = _get_item_data(item_data.layer, alt_id)
			resource.alt_config_path = _fix_path(alt_data.get("config_path", ""))
		else:
			resource.alt_config_path = ""


func _recalculate_global_interactions() -> void:
	current_character.hidden_items.clear()
	
	var all_body_layers = ["body", "head"] + Array(body_layers)
	for layer in all_body_layers:
		var part = current_character.body_parts.get(layer)
		if part and "is_alt" in part:
			part.is_alt = false

	for layer in gear_layers:
		var gear_part = current_character.equipment_parts.get(layer)
		if not gear_part or gear_part.part_id == "" or gear_part.part_id == "none":
			continue
			
		var item_data = _get_item_data(layer, gear_part.part_id)
		if item_data.is_empty(): continue
		
		if "slotsalt" in item_data:
			var targets = item_data.slotsalt
			if targets is Array:
				for target_layer in targets:
					var target_part = current_character.body_parts.get(target_layer)
					if target_part and "is_alt" in target_part:
						target_part.is_alt = true
		
		if "slotshidden" in item_data:
			var targets = item_data.slotshidden
			if targets is Array:
				for target_id in targets:
					if not target_id in current_character.hidden_items:
						current_character.hidden_items.append(target_id)
	
	_refresh_weapon_images()
	current_character.changed.emit()


func _refresh_weapon_images() -> void:
	if not current_character: return
	
	if current_character.equipment_parts.mainhand.part_id in data.gear.mainhand:
		var part_id = current_character.equipment_parts.mainhand.part_id
		var current_data = data.gear.mainhand[part_id]
		var actions: Array = current_data.get("actions", [])
		var images := {}
		
		for t in current_data.textures:
			if not "body" in t or t.body != current_character.body_type:
				continue
			if "spritesheet" in t:
				if t.spritesheet.ends_with("walk"):
					images.idle = {
						"back": t.back,
						"front": t.front
					}
					images.walk = {
						"back": t.back,
						"front": t.front
					}
				else:
					var action_name = t.spritesheet.get_slice("/", t.spritesheet.get_slice_count("/") - 1)
					action_name = action_name.get_slice("_", action_name.get_slice_count("_") - 1)
					var action = actions.find(action_name)
					if action != -1:
						images[action_name] = {
						"back": t.back,
						"front": t.front
					}
			else:
				images.idle = {
					"back": t.back,
					"front": t.front
				}
				images.walk = {
					"back": t.back,
					"front": t.front
				}
		
		if part_id == "fishingpole": # add texture fisihing:
			images.fish_full_animation = {
				"back": "res://addons/rpg_character_creator/textures/gear/mainhand/farm/fishingpole_fish_back.png",
				"front": "res://addons/rpg_character_creator/textures/gear/mainhand/farm/fishingpole_fish_front.png"
			}
	
		%Character.set_extra_data(part_id, images, actions)


func _fix_path(path: String) -> String:
	if path.is_empty() or path.to_lower() == "none":
		return ""
	if path.begins_with("res://"):
		return path
	return PLUGIN_PATH.path_join(path)

#endregion


#region Color & Gradient Logic

## Returns the list of layers to be affected: [current_part] or the whole group if "Merge" is selected.
func _get_edit_targets() -> Array:
	var node = %PartsGroup
	var selected_idx = node.get_selected_id()
	
	if selected_idx == -1:
		return [current_part]

	var meta = node.get_item_metadata(selected_idx)
	
	if meta == "merge":
		if current_part in GROUP_SKIN: return GROUP_SKIN
		if current_part in GROUP_HAIR: return GROUP_HAIR
		return [current_part]
	
	return [meta]


## Persists the current character state into the color cache.
## This is called when switching tabs so new buttons know if they should use custom colors.
func _sync_cache_from_character(layer: String, modified_palette_idx: int = -1, new_src_key: String = "") -> void:
	var is_body = layer in body_layers or layer == "body" or layer == "head"
	var collection = current_character.body_parts if is_body else current_character.equipment_parts
	var part = collection.get(layer)
	
	if not part: return
	
	var item_data = _get_item_data(layer, part.part_id)
	
	var get_src_key = func(list_name: String, id_prop: String, old_src_prop: String, check_idx: int) -> String:
		if check_idx == modified_palette_idx and new_src_key != "":
			return new_src_key
			
		var idx = part.get(id_prop)
		var presets = item_data.get(list_name, [])
		if idx >= 0 and idx < presets.size():
			return presets[idx]
		
		var old_cache = _layer_color_cache.get(layer, {})
		var saved_key = old_cache.get(old_src_prop, "")
		if saved_key != "": return saved_key
			
		return ""

	var p_src = get_src_key.call("primarycolors", "current_primary_color_id", "p_src", 0)
	var s_src = get_src_key.call("secondarycolors", "current_secondary_color_id", "s_src", 1)
	var f_src = get_src_key.call("fixedcolors", "current_fixed_color_id", "f_src", 2)

	var cache_entry = {
		"p_id": part.current_primary_color_id,
		"s_id": part.current_secondary_color_id,
		"f_id": part.current_fixed_color_id,
		"p_raw": part.palette1.colors.duplicate(),
		"s_raw": part.palette2.colors.duplicate(),
		"f_raw": part.palette3.colors.duplicate(),
		"p_src": p_src,
		"s_src": s_src,
		"f_src": f_src
	}
	
	var old = _layer_color_cache.get(layer, {})
	if old.has("p_grad"): cache_entry["p_grad"] = old.p_grad
	if old.has("s_grad"): cache_entry["s_grad"] = old.s_grad
	if old.has("f_grad"): cache_entry["f_grad"] = old.f_grad
	
	_layer_color_cache[layer] = cache_entry


## Configures the colors of a new part based on the layer cache.
## If the cache has custom colors (ID -1), it imposes the raw array from cache.
func _configure_part_colors_from_cache(layer: String, resource: Resource, item_data: Dictionary) -> void:
	var cache = _layer_color_cache.get(layer)
	var color_map = data.colormaps.get(current_character.palette)
	
	if not color_map: return

	var apply_logic = func(id_key: String, raw_key: String, grad_key: String, src_key_prop: String, res_palette: String, res_grad: String, res_id_prop: String, list_name: String):
		var target_id = 0 
		var apply_custom = false
		
		if cache:
			var cached_id = cache.get(id_key, 0)
			
			if cached_id == -1:
				var source_key = cache.get(src_key_prop, "")
				var item_presets = item_data.get(list_name, [])
				
				# WILDCARD LOGIC:
				# 1. If source_key is "" (Legacy) -> Apply to ALL.
				# 2. If source_key matches item presets -> Apply.
				if source_key == "" or item_presets.has(source_key):
					apply_custom = true
				else:
					# If it has a defined key and doesn't match, return to default preset
					target_id = 0
			else:
				target_id = cached_id
		
		if apply_custom:
			var cached_gradient = cache.get(grad_key, [])
			if not cached_gradient.is_empty():
				resource[res_palette].colors = cache.get(raw_key, []).duplicate()
				resource.set(res_grad, cached_gradient)
				resource.set(res_id_prop, -1)
			else:
				var saved_raw_colors = cache.get(raw_key, [])
				if not saved_raw_colors.is_empty():
					resource[res_palette].colors = saved_raw_colors.duplicate()
					resource.set(res_grad, get_gradient(saved_raw_colors))
					resource.set(res_id_prop, -1)
		else:
			var presets = item_data.get(list_name, [])
			if target_id >= presets.size(): target_id = 0
			
			if not presets.is_empty():
				var color_key = presets[target_id]
				var map_data = _resolve_colors_from_map(color_map, color_key)
				if not map_data.is_empty():
					resource[res_palette].colors = map_data.colors
					resource[res_palette].blend_color = map_data.color
					resource.set(res_grad, get_gradient(map_data.colors))
					resource.set(res_id_prop, target_id)
	
	apply_logic.call("p_id", "p_raw", "p_grad", "p_src", "palette1", "gradient1", "current_primary_color_id", "primarycolors")
	apply_logic.call("s_id", "s_raw", "s_grad", "s_src", "palette2", "gradient2", "current_secondary_color_id", "secondarycolors")
	apply_logic.call("f_id", "f_raw", "f_grad", "f_src", "palette3", "gradient3", "current_fixed_color_id", "fixedcolors")


## Robust Helper: Gets the gradient for an ID. Accepts item_data directly to avoid lookup errors.
func _get_gradient_for_color(target_id: int, item_data: Dictionary, palette_name: String) -> PackedColorArray:
	var presets = item_data.get(palette_name, [])
	if presets.is_empty():
		return get_gradient([]) 
	
	var safe_id = target_id
	if safe_id < 0 or safe_id >= presets.size():
		safe_id = 0
		
	var color_key = presets[safe_id]
	
	var global_map = data.colormaps.get(current_character.palette)
	if global_map and global_map.items.has(color_key):
		return get_gradient(global_map.items[color_key].colors)
		
	return get_gradient([])


func _resolve_colors_from_map(color_map: Dictionary, color_id: String) -> Dictionary:
	if color_map.items.has(color_id):
		var entry = color_map.items[color_id]
		if entry.has("colors"):
			return {"colors": entry.colors, "color": entry.color}
	return {}


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

	if not current_data: return
	
	if not current_data.part_id == "none" and not current_data.part_id.is_empty():
		main_material.set_shader_parameter("palette1", current_data.gradient1)
		main_material.set_shader_parameter("palette2", current_data.gradient2)
		main_material.set_shader_parameter("palette3", current_data.gradient3)
	
	current_character.changed.emit()


func _hightlight_color(palette_id: int, color_index: int) -> void:
	%Character.set_highlight_color(current_part, true, palette_id, color_index)


func _update_colors_for_button(button: HeroEditorPartButton) -> void:
	var cache = _layer_color_cache.get(button.part_id)
	var btn_item_data = _get_item_data(button.part_id, button.item_id)
	
	var resolve_button_gradient = func(channel_char: String, list_name: String, src_prop: String) -> PackedColorArray:
		# 1. Custom Color Check with Family Validation
		if cache and cache.get(channel_char + "_id") == -1:
			var source_key = cache.get(src_prop, "")
			var presets = btn_item_data.get(list_name, [])
			
			# WILDCARD VISUAL LOGIC:
			# If it's Legacy ("") OR if family matches -> PAINT CUSTOM
			if source_key == "" or presets.has(source_key):
				# A. Use Cached Gradient (Visual / Fine Tune)
				var grad_data = cache.get(channel_char + "_grad", [])
				if not grad_data.is_empty(): return grad_data
				
				# B. Fallback: Use RAW Data
				var raw_data = cache.get(channel_char + "_raw", [])
				if not raw_data.is_empty(): return get_gradient(raw_data)
		
		# 2. Preset Logic
		var target_id = 0
		if cache: target_id = cache.get(channel_char + "_id", 0)
		
		# If cache says -1 (Custom) but family DID NOT match above,
		# force target_id to 0 (Default) so this button looks normal.
		if target_id == -1: target_id = 0 
		
		return _get_gradient_for_color(target_id, btn_item_data, list_name)

	var g1 = resolve_button_gradient.call("p", "primarycolors", "p_src")
	var g2 = resolve_button_gradient.call("s", "secondarycolors", "s_src")
	var g3 = resolve_button_gradient.call("f", "fixedcolors", "f_src")

	button.set_shader_colors(g1, g2, g3)


func _set_data_colors() -> void:
	var colors_data = data.colormaps[current_character.palette].items
	var node = %AllPresets
	
	node.clear()
	node.add_item(tr("All colors in palette..."))
	
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
	
	var node = %PartsGroup
	node.clear()
	
	var group = []
	var group_name = ""
	
	if current_part in GROUP_SKIN:
		group = GROUP_SKIN
		group_name = "Skin"
	elif current_part in GROUP_HAIR:
		group = GROUP_HAIR
		group_name = "Hair"
	
	if group.is_empty():
		node.add_item(current_part.capitalize())
		node.set_item_metadata(0, current_part)
		node.select(0)
		
		if %SynchronizePalettes: %SynchronizePalettes.disabled = true
	else:
		node.add_item("Sync %s Layers" % group_name)
		node.set_item_metadata(0, "merge")
		
		for layer in group:
			node.add_item(" - " + layer.capitalize())
			node.set_item_metadata(node.get_item_count() - 1, layer)
		
		if %SynchronizePalettes: %SynchronizePalettes.disabled = false
		
		if auto_select_merge:
			node.select(0) 
		else:
			var found = false
			for i in range(node.get_item_count()):
				if node.get_item_metadata(i) == current_part:
					node.select(i)
					found = true
					break
			if not found: node.select(0)
	
	node.set_disabled(node.get_item_count() <= 1)
	
	_fill_palette_presets()


func _fill_palette_presets() -> void:
	var targets = _get_edit_targets()
	if targets.is_empty(): return
	var active_layer = targets[0]

	if not active_layer is String or active_layer.is_empty():
		return

	var current_data
	var is_body = active_layer in body_layers or active_layer == "body" or active_layer == "head"
	
	if is_body:
		current_data = current_character.body_parts.get(active_layer)
	else:
		current_data = current_character.equipment_parts.get(active_layer)
	
	if not current_data: return
	
	var item_data = _get_item_data(active_layer, current_data.part_id)
	var palette_id = %PaletteSelector.get_selected_id()
	
	var palette = "primarycolors" 
	if palette_id == 1: palette = "secondarycolors"
	elif palette_id == 2: palette = "fixedcolors"
	
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
			if data.colormaps[current_character.palette].items.has(key):
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
		var btn = get_node_or_null("%%GradientFastButton%s" % (index + 1))
		if btn: btn.set_pressed_no_signal(true)
		%PaletteSelector.select(index)
	
	_fill_current_colors()


func _fill_current_colors() -> void:
	var targets = _get_edit_targets()
	if targets.is_empty(): return
	var active_layer = targets[0]
	
	if not active_layer is String or active_layer.is_empty():
		return
	
	var palette_id = %PaletteSelector.get_selected_id()
	var node = %CurentColorConatiner
	for child in node.get_children():
		child.queue_free()
		node.remove_child(child)
	
	var current_data
	var is_body = active_layer in body_layers or active_layer == "body" or active_layer == "head"
	
	if is_body:
		current_data = current_character.body_parts.get(active_layer)
	else:
		current_data = current_character.equipment_parts.get(active_layer)
	
	if not current_data: return
	
	var palette: String
	if palette_id == 0: palette = "palette1"
	elif palette_id == 1: palette = "palette2"
	else: palette = "palette3"

	var colors = current_data[palette].colors
	for i in range(2, colors.size(), 2):
		var color = Color(int(colors[i+1]))

		var b = PALETTE_BUTTON.instantiate()
		b.can_be_selected = false
		b.target = {"palette_id": palette_id, "index": node.get_child_count(), "color": color}
		b.pressed.connect(_on_palette_button_pressed)
		b.mouse_entered.connect(_hightlight_color.bind(palette_id + 1, colors[i]))
		b.mouse_exited.connect(_hightlight_color.bind(0, 0))
		node.add_child(b)
		b.color = color


func _apply_color_preset(color_key: String, is_specific_list: bool = false) -> void:
	var targets = _get_edit_targets()
	var color_map = data.colormaps.get(current_character.palette)
	
	if not color_map: return
	
	var color_data_global = _resolve_colors_from_map(color_map, color_key)
	if color_data_global.is_empty(): return
	
	var global_colors = color_data_global.colors
	var global_blend = color_data_global.color
	var global_gradient = get_gradient(global_colors)
	
	var active_layer = targets[0]
	var palette_idx = %PaletteSelector.get_selected_id()
	var list_name = "primarycolors"
	match palette_idx:
		1: list_name = "secondarycolors"
		2: list_name = "fixedcolors"
	
	var source_index = -1
	if is_specific_list:
		var is_body_active = active_layer in body_layers or active_layer == "body" or active_layer == "head"
		var collection_active = current_character.body_parts if is_body_active else current_character.equipment_parts
		var part_active = collection_active.get(active_layer)
		if part_active and part_active.part_id != "none":
			var active_item_data = _get_item_data(active_layer, part_active.part_id)
			var active_list = active_item_data.get(list_name, [])
			source_index = active_list.find(color_key)

	active_preset_keys[palette_idx] = color_key

	for target_layer in targets:
		var is_body_part = target_layer in body_layers or target_layer == "body" or target_layer == "head"
		var collection = current_character.body_parts if is_body_part else current_character.equipment_parts
		
		var part_resource = collection.get(target_layer)
		if not part_resource: continue 
		
		var is_empty_slot = (part_resource.part_id == "none" or part_resource.part_id.is_empty())
		var final_index = -1
		
		if is_empty_slot:
			final_index = source_index
		else:
			var item_data = _get_item_data(target_layer, part_resource.part_id)
			var list = item_data.get(list_name, [])
			
			final_index = list.find(color_key) 
			
			if final_index == -1 and source_index != -1:
				if source_index < list.size():
					final_index = source_index 
		
		match palette_idx:
			0:
				part_resource.palette1.colors = global_colors
				part_resource.palette1.blend_color = global_blend
				part_resource.gradient1 = global_gradient
				part_resource.current_primary_color_id = final_index
			1:
				part_resource.palette2.colors = global_colors
				part_resource.palette2.blend_color = global_blend
				part_resource.gradient2 = global_gradient
				part_resource.current_secondary_color_id = final_index
			2:
				part_resource.palette3.colors = global_colors
				part_resource.palette3.blend_color = global_blend
				part_resource.gradient3 = global_gradient
				part_resource.current_fixed_color_id = final_index
		
		_sync_cache_from_character(target_layer, palette_idx, color_key)
		
		if not is_empty_slot:
			%Character.update_part(target_layer)

	_update_shaders()
	
	for button in parts_container.get_children():
		if button is HeroEditorPartButton:
			_update_colors_for_button(button)
			
	_fill_current_colors()


func _refresh_active_keys() -> void:
	var is_body = current_part in body_layers or current_part == "body" or current_part == "head"
	var collection = current_character.body_parts if is_body else current_character.equipment_parts
	var part = collection.get(current_part)
	
	if not part or part.part_id == "none":
		active_preset_keys = {0: "", 1: "", 2: ""}
		return

	var item_data = _get_item_data(current_part, part.part_id)
	
	var get_key = func(list_name: String, id_prop: String) -> String:
		var list = item_data.get(list_name, [])
		var idx = part.get(id_prop)
		if idx >= 0 and idx < list.size():
			return list[idx]
		return ""
	
	if part.current_primary_color_id >= 0:
		active_preset_keys[0] = get_key.call("primarycolors", "current_primary_color_id")
	if part.current_secondary_color_id >= 0:
		active_preset_keys[1] = get_key.call("secondarycolors", "current_secondary_color_id")
	if part.current_fixed_color_id >= 0:
		active_preset_keys[2] = get_key.call("fixedcolors", "current_fixed_color_id")

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
	
	if data.colormaps.has(palette_id):
		var new_color_map = data.colormaps[palette_id]
		_refresh_all_parts_colors(new_color_map)
	
	_update_shaders()
	
	for button in parts_container.get_children():
		if button is HeroEditorPartButton:
			_update_colors_for_button(button)
	
	_fill_current_colors()
	_fill_palette_presets()
	
	%Races.item_selected.emit(%Races.get_selected_id())


func _refresh_all_parts_colors(new_color_map: Dictionary) -> void:
	var all_layers = ["body", "head"] + Array(body_layers) + Array(gear_layers)
	
	for layer in all_layers:
		var is_body_part = layer in body_layers or layer == "body" or layer == "head"
		var collection = current_character.body_parts if is_body_part else current_character.equipment_parts
		var part_resource = collection.get(layer)
		
		if not part_resource or part_resource.part_id == "none" or part_resource.part_id.is_empty():
			continue
			
		var item_data = _get_item_data(layer, part_resource.part_id)
		if item_data.is_empty():
			continue
			
		_apply_palette_update_to_part(part_resource, item_data, new_color_map, "primarycolors", "current_primary_color_id", "palette1", "gradient1")
		_apply_palette_update_to_part(part_resource, item_data, new_color_map, "secondarycolors", "current_secondary_color_id", "palette2", "gradient2")
		_apply_palette_update_to_part(part_resource, item_data, new_color_map, "fixedcolors", "current_fixed_color_id", "palette3", "gradient3")


func _apply_palette_update_to_part(resource: Resource, item_data: Dictionary, new_color_map: Dictionary, list_key: String, id_property: String, palette_prop: String, gradient_prop: String) -> void:
	var current_id: int = resource.get(id_property)
	
	if current_id < 0:
		return

	var presets_list: Array = item_data.get(list_key, [])
	if current_id >= presets_list.size():
		return

	var color_key = presets_list[current_id]
	var new_color_data = _resolve_colors_from_map(new_color_map, color_key)
	
	if not new_color_data.is_empty():
		resource[palette_prop].colors = new_color_data.colors
		resource[palette_prop].blend_color = new_color_data.color
		resource.set(gradient_prop, get_gradient(new_color_data.colors))


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
		_sync_cache_from_character(layer)
		
		_refresh_active_keys()
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
	var palette = "palette" + str(button_data.palette_id + 1)
	_open_color_dialog(button_data.index, palette, button_data.color)


func _on_body_palette_button_pressed() -> void:
	current_part = "body"
	_refresh_active_keys()
	_fill_edit_colors()


func _open_color_dialog(item_id: int, palette: String, color: Color) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var color_dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		
	color_dialog.color_selected.connect(_on_color_dialog_color_selected.bind(palette, item_id, color), CONNECT_ONE_SHOT)
	color_dialog.preview_color.connect(_on_color_dialog_preview_color.bind(palette, item_id))
	
	color_dialog.set_color(color)


func _on_color_dialog_preview_color(color: Color, palette: String, item_id: int) -> void:
	var targets = _get_edit_targets()
	
	for target_layer in targets:
		var is_body = target_layer in body_layers or target_layer == "body" or target_layer == "head"
		var collection = current_character.body_parts if is_body else current_character.equipment_parts
		var current_data = collection.get(target_layer)
		
		if not current_data: continue
		
		var target_index = (item_id * 2) + 3
		if current_data[palette].colors.size() > target_index:
			current_data[palette].colors[target_index] = color.to_rgba32()
			current_data["gradient%s" % palette.right(1)] = get_gradient(current_data[palette].colors)
		
		%Character.update_part(target_layer)


func _on_color_dialog_color_selected(color: Color, palette: String, item_id: int, original_color: Color) -> void:
	var targets = _get_edit_targets()
	var something_changed = false
	
	for target_layer in targets:
		var is_body = target_layer in body_layers or target_layer == "body" or target_layer == "head"
		var collection = current_character.body_parts if is_body else current_character.equipment_parts
		var current_data = collection.get(target_layer)
		
		if not current_data: continue
		
		var target_index = (item_id * 2) + 3
		
		if current_data[palette].colors.size() <= target_index:
			continue
			
		current_data[palette].colors[target_index] = color.to_rgba32()
		current_data["gradient%s" % palette.right(1)] = get_gradient(current_data[palette].colors)
		
		if color.to_rgba32() != original_color.to_rgba32():
			something_changed = true
			var cache = _layer_color_cache.get(target_layer, {})
			
			var is_empty_slot = (current_data.part_id == "none" or current_data.part_id.is_empty())
			var src_key_val = ""
			
			if not is_empty_slot:
				var item_data = _get_item_data(target_layer, current_data.part_id)
				var resolve_src = func(idx_prop: String, list_name: String, old_src_key: String) -> String:
					var idx = current_data.get(idx_prop)
					var presets = item_data.get(list_name, [])
					if idx >= 0 and idx < presets.size(): return presets[idx]
					var cached_key = cache.get(old_src_key, "")
					if cached_key != "": return cached_key
					if not presets.is_empty(): return presets[0]
					return ""
				
				if palette == "palette1": src_key_val = resolve_src.call("current_primary_color_id", "primarycolors", "p_src")
				elif palette == "palette2": src_key_val = resolve_src.call("current_secondary_color_id", "secondarycolors", "s_src")
				elif palette == "palette3": src_key_val = resolve_src.call("current_fixed_color_id", "fixedcolors", "f_src")
			
			match palette:
				"palette1": 
					cache["p_src"] = src_key_val
					current_data.current_primary_color_id = -1
					cache["p_id"] = -1
					cache["p_raw"] = current_data.palette1.colors.duplicate()
					cache.erase("p_grad")
				"palette2": 
					cache["s_src"] = src_key_val
					current_data.current_secondary_color_id = -1
					cache["s_id"] = -1
					cache["s_raw"] = current_data.palette2.colors.duplicate()
					cache.erase("s_grad")
				"palette3": 
					cache["f_src"] = src_key_val
					current_data.current_fixed_color_id = -1
					cache["f_id"] = -1
					cache["f_raw"] = current_data.palette3.colors.duplicate()
					cache.erase("f_grad")
			
			_layer_color_cache[target_layer] = cache
		
		if current_data.part_id != "none":
			%Character.update_part(target_layer)
	
	if something_changed:
		for button in parts_container.get_children():
			if button is HeroEditorPartButton:
				_update_colors_for_button(button)
		_fill_current_colors()


func _open_fine_tune_dialog() -> void:
	var current_data
	if current_part in body_layers or current_part in ["head", "body"]:
		current_data = current_character.body_parts.get(current_part)
	else:
		current_data = current_character.equipment_parts.get(current_part)
	
	if not current_data: return
		
	var path = "res://addons/CustomControls/Dialogs/fine_tune_palette_colors.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var gradient_id = "gradient1"
	match %PaletteSelector.get_selected_id():
		0: gradient_id = "gradient1"
		1: gradient_id = "gradient2"
		2: gradient_id = "gradient3"
			
	dialog.set_colors(current_data.get(gradient_id))
	dialog.colors_changed.connect(_on_dialog_color_changed.bind(gradient_id))


func _on_dialog_color_changed(colors: Array[Color], gradient_id: String) -> void:
	var targets = _get_edit_targets()
	var something_changed = false
	
	for target_layer in targets:
		var is_body = target_layer in body_layers or target_layer == "body" or target_layer == "head"
		var collection = current_character.body_parts if is_body else current_character.equipment_parts
		var current_data = collection.get(target_layer)
		
		if not current_data: continue
		
		current_data.set(gradient_id, colors)
		
		var cache = _layer_color_cache.get(target_layer, {})
		
		match gradient_id:
			"gradient1":
				current_data.current_primary_color_id = -1
				cache["p_id"] = -1
				cache["p_raw"] = current_data.palette1.colors.duplicate()
				cache["p_grad"] = colors
			"gradient2":
				current_data.current_secondary_color_id = -1
				cache["s_id"] = -1
				cache["s_raw"] = current_data.palette2.colors.duplicate()
				cache["s_grad"] = colors
			"gradient3":
				current_data.current_fixed_color_id = -1
				cache["f_id"] = -1
				cache["f_raw"] = current_data.palette3.colors.duplicate()
				cache["f_grad"] = colors
		
		_layer_color_cache[target_layer] = cache
		something_changed = true
		
		%Character.update_part(target_layer)
	
	if something_changed:
		for button in parts_container.get_children():
			if button is HeroEditorPartButton:
				_update_colors_for_button(button)
		_fill_current_colors()


func _on_part_list_options_item_selected(index: int) -> void:
	_fill_palette_presets()
	_fill_current_colors()


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
	%AllPresets.select(0)


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


#region Randomize Parts

func _on_randomize_pressed() -> void:
	var locked_parts: Array = []
	var layers = body_layers + gear_layers
	
	for i in layers.size():
		var button = tabs_container.get_child(i)
		if button.has_method("is_locked") and button.is_locked():
			locked_parts.append(layers[i])
	
	_randomize_base_character()
	
	var weights: Dictionary = {
		"mask": 0.15, "hat": 0.7, "glasses": 0.3, "suit": 0.1, "jacket": 0.4,
		"add1": 0.1, "add2": 0.1, "add3": 0.1, "wings": 0.2, "tail": 0.3,
		"horns": 0.2, "back": 0.5
	}
	
	for layer in layers:
		if layer in locked_parts:
			continue
		
		var chance = weights.get(layer, 1.0)
		var should_equip = randf() <= chance
		
		if not should_equip:
			install_part(layer, "none")
			continue
			
		var valid_parts: Array = []
		if layer in body_layers:
			valid_parts = _get_body_parts(layer)
		else:
			valid_parts = _get_gear_parts(layer)
		
		if valid_parts.is_empty():
			continue
			
		var random_part_id = valid_parts.pick_random()
		install_part(layer, random_part_id)
		
		_randomize_part_colors(layer, random_part_id)
	
	request_visibility_update()
	
	if not current_part.is_empty():
		_select_tab(true, current_part)


func _randomize_base_character() -> void:
	var races = data.characters.race.keys()
	if races.is_empty(): return
	var new_race_id
	if not %RaceLock.is_pressed():
		new_race_id = races.pick_random()
		current_character.race = new_race_id
	else:
		new_race_id = current_character.race
	
	var race_data = data.characters.race[new_race_id]
	if not %GenderLock.is_pressed():
		if "genders" in race_data and not race_data.genders.is_empty():
			current_character.gender = race_data.genders.keys().pick_random()
	
	var bodies: Array = []
	if not %BodyLock.is_pressed():
		for config in race_data.configs.values():
			if config.gender == current_character.gender:
				if not bodies.has(config["body-type"]):
					bodies.append(config["body-type"])
	
	if not bodies.is_empty():
		current_character.body_type = bodies.pick_random()
		for config in race_data.configs.values():
			if config["body-type"] == current_character.body_type and config.gender == current_character.gender:
				current_character.body_id = config.get("id", "regular")
				current_character.head_type = config.get("head-type", "hm1")
				break
	
	var race_idx = _get_index_by_metadata(%Races, current_character.race)
	if race_idx != -1: %Races.select(race_idx)
	
	fill_genders(race_data.genders, current_character.gender)
	fill_bodies(current_character.body_id)


func _randomize_part_colors(layer: String, item_id: String) -> void:
	if item_id == "none" or item_id.is_empty(): return
	
	var is_body_part = layer in body_layers or layer == "body" or layer == "head"
	var collection = current_character.body_parts if is_body_part else current_character.equipment_parts
	var part_resource = collection.get(layer)
	
	if not part_resource: return
	
	var item_data = _get_item_data(layer, item_id)
	var color_map = data.colormaps.get(current_character.palette)
	if not color_map: return
	
	var apply_random_palette = func(list_key: String, palette_prop: String, gradient_prop: String, id_prop: String):
		var presets: Array = item_data.get(list_key, [])
		if presets.is_empty(): return
		
		var random_index = randi() % presets.size()
		var color_key = presets[random_index]
		
		var color_data = _resolve_colors_from_map(color_map, color_key)
		if not color_data.is_empty():
			part_resource[palette_prop].colors = color_data.colors
			part_resource[palette_prop].blend_color = color_data.color
			part_resource.set(gradient_prop, get_gradient(color_data.colors))
			part_resource.set(id_prop, random_index)
	
	apply_random_palette.call("primarycolors", "palette1", "gradient1", "current_primary_color_id")
	apply_random_palette.call("secondarycolors", "palette2", "gradient2", "current_secondary_color_id")
	apply_random_palette.call("fixedcolors", "palette3", "gradient3", "current_fixed_color_id")
	
	_sync_cache_from_character(layer)


func _get_index_by_metadata(node: OptionButton, meta_value: Variant) -> int:
	for i in node.get_item_count():
		if node.get_item_metadata(i) == meta_value:
			return i
	return -1


func _on_synchronize_palettes_toggled(toggled_on: bool) -> void:
	auto_select_merge = toggled_on
	_fill_edit_colors()


#endregion


#region Save

func _on_part_save_requested(layer: String, item_id: String, texture: Texture2D) -> void:
	var is_body = layer in body_layers or layer == "body" or layer == "head"
	var collection = current_character.body_parts if is_body else current_character.equipment_parts
	var source_part = collection.get(layer)
	
	if not source_part: return
	
	var new_item_data = _get_item_data(layer, item_id)
	if new_item_data.is_empty(): return

	var part_to_save = source_part.duplicate(true)
	
	part_to_save.part_id = item_id
	if "name" in part_to_save:
		part_to_save.name = new_item_data.get("name", item_id)
	part_to_save.config_path = _fix_path(new_item_data.get("config_path", ""))
	
	if "textures" in new_item_data:
		part_to_save.front_texture = _fix_path(new_item_data.textures.get("front", ""))
		part_to_save.back_texture = _fix_path(new_item_data.textures.get("back", ""))
	
	var global_map = data.colormaps.get(current_character.palette)
	
	if global_map:
		_smart_update_color(part_to_save.palette1, "current_primary_color_id", "gradient1", new_item_data.get("primarycolors", []), global_map, part_to_save)
		_smart_update_color(part_to_save.palette2, "current_secondary_color_id", "gradient2", new_item_data.get("secondarycolors", []), global_map, part_to_save)
		_smart_update_color(part_to_save.palette3, "current_fixed_color_id", "gradient3", new_item_data.get("fixedcolors", []), global_map, part_to_save)

	var _pending_save_resource = part_to_save
	var _pending_preview_image: Image
	
	if texture:
		_pending_preview_image = texture.get_image()


func _smart_update_color(palette_res: Resource, id_prop: String, grad_prop: String, new_presets: Array, color_map: Dictionary, target_part: Resource) -> void:
	var current_idx = target_part.get(id_prop)
	
	if current_idx < 0:
		return
		
	if new_presets.is_empty():
		target_part.set(id_prop, 0)
		return

	var new_idx = current_idx
	if new_idx >= new_presets.size():
		new_idx = 0
	
	var color_key = new_presets[new_idx]
	
	var color_data = _resolve_colors_from_map(color_map, color_key)
	
	if not color_data.is_empty():
		palette_res.colors = color_data.colors
		palette_res.blend_color = color_data.color
		
		target_part.set(id_prop, new_idx)
		target_part.set(grad_prop, get_gradient(color_data.colors))


func _on_save_mode_item_selected(index: int) -> void:
	match index:
		0:
			%SaveOptions1.visible = true
			%SaveOptions2.visible = true
			%CustomeLabel.visible = false
			%FolderContainer.visible = true
		1:
			%SaveOptions1.visible = true
			%SaveOptions2.visible = false
			%CustomeLabel.visible = false
			%FolderContainer.visible = true
		2:
			%SaveOptions1.visible = true
			%SaveOptions2.visible = false
			%CustomeLabel.visible = true
			%FolderContainer.visible = false

#endregion
