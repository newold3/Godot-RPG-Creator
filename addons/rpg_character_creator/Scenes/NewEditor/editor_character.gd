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

const HELP_LABEL = preload("uid://bei8c08qswgxh")
var help_label_tween: Tween
var help_label: Label

var data: Dictionary
var _thread: Thread = null
var starting: bool = false
var current_part: String = ""
var editor_hidden_layers: Array[String] = []
var tasks: Array = []
var load_time_budget_ms: int = 10
var auto_select_merge: bool = true

var importing: bool = false

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

const ACTOR_BASE_SCENE = preload("res://addons/rpg_character_creator/Other/actor_base_scene.tscn")
const GENERIC_LPC_BASE_SCENE = preload("res://addons/rpg_character_creator/Other/generic_lpc_base_scene.tscn")
const PARTS_ROOT_DIR = "res://Assets/Parts"
const SET_FOLDER_NAME = "sets"
const COSTUME_FOLDER_NAME = "costume"

var race_name_generator = preload("uid://b5lb470bx8ej2").new()

signal data_loaded()


#region Initialization

func _ready() -> void:
	%SaveTabContainer.get_tab_bar().mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	
	update_tab_indicators()


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
	var c1 = current_character.equipment_parts if source_layer in gear_layers else current_character.body_parts
	var c2 = current_character.equipment_parts if target_layer in gear_layers else current_character.body_parts
	var source = c1.get(source_layer)
	var target = c2.get(target_layer)
	
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
	%Character.weapon_data = data.gear["mainhand"]
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
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if layer in editor_hidden_layers:
					editor_hidden_layers.erase(layer)
					button.modulate.a = 1.0
					button.accept_event()
				else:
					editor_hidden_layers.append(layer)
					button.modulate.a = 0.4
					button.accept_event()
			elif event.button_index == MOUSE_BUTTON_MIDDLE:
				install_part(layer, "none")
				_on_part_button_pressed("", "", {})
				request_visibility_update()
				if layer == current_part:
					parts_container.get_child(0).select()
				button.accept_event()
			
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
				"body_id": body.get("body_id", race_id),
				"head_id": body.get("head_id", race_id),
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
	
	if not %UnrestrictedMode.is_pressed():
		var race_id = current_character.race
		if race_id in data.characters.race and "configs" in data.characters.race[race_id]:
			var configs = data.characters.race[race_id].configs
			var body_cfg = configs.get(current_character.body_id, {})
			parts = body_cfg.get(layer, [])
	
	if %UnrestrictedMode.is_pressed():
		if data.characters.has(layer):
			for item_id in data.characters[layer].keys():
				if not parts.has(item_id):
					parts.append(item_id)
	
	parts.sort()
	return parts


func _get_gear_parts(layer: String) -> Array:
	if not data or not "gear" in data: return []
	
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

		b.tooltip_text = "[title]%s[/title]\n\"%s\"" % [layer.capitalize(), item_data.get("name", part_id)]
		
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
	
	#_update_shaders()


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
		button.select()


func get_button(part_id: String, item_id: String) -> HeroEditorPartButton:
	for button: HeroEditorPartButton in parts_container.get_children():
		if button.part_id == part_id and button.item_id == item_id:
			return button
	
	return null


func update_tab_indicators() -> void:
	for button in tabs_container.get_children():
		if not button.has_method("enable_part_installed"):
			continue

		# Buttons are named with uppercase layer names (e.g., "JACKET")
		var layer = button.name.to_lower()
		
		# Determine if it is a body part or gear to access the correct dictionary
		var is_body_part = layer in body_layers or layer == "body" or layer == "head"
		var collection = current_character.body_parts if is_body_part else current_character.equipment_parts
		
		if not collection:
			continue

		var part_resource = collection.get(layer)
		
		# Valid if the resource exists, has an ID, and is not "none"
		var is_installed = part_resource and part_resource.part_id != "" and part_resource.part_id != "none"

		button.enable_part_installed(is_installed)


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
	if "slotsset" in file_data: item["slotshidden"] = item.get("slotshidden", []) + file_data["slotsset"]
	
	var parent_layer = ""
	if file_data.get("parent") == "body" or layer in ["head", "ears", "nose"]:
		parent_layer = "body"
	elif layer in ["hairadd", "facial"]:
		parent_layer = "hair"
	
	if parent_layer != "" and parent_layer != layer:
		var lists_to_check = ["primarycolors", "secondarycolors", "fixedcolors"]
		for list_name in lists_to_check:
			if item[list_name].is_empty():
				var parent_part_id = ""
				var parent_res = current_character.body_parts.get(parent_layer)
				if parent_res: parent_part_id = parent_res.part_id
				
				if parent_part_id == "" or parent_part_id == "none":
					if parent_layer == "body": parent_part_id = "human"
					elif parent_layer == "hair": parent_part_id = "afro"
				
				var parent_data = _get_raw_item_data_for_inheritance(parent_layer, parent_part_id)
				if not parent_data.is_empty():
					item[list_name] = parent_data.get(list_name, []).duplicate()

	return item


func _get_raw_item_data_for_inheritance(layer: String, item_id: String) -> Dictionary:
	var current_data: Dictionary = data.characters
	
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
		part_resource.layer_id = layer
		part_resource.config_path = _fix_path(item_data.get("config_path", ""))
		if layer == "mainhand":
			var current_ammo = current_character.equipment_parts.get("ammo")
			if current_ammo and current_ammo.part_id != "none" and not current_ammo.part_id.is_empty():
				install_part("ammo", "none")
		_recalculate_global_interactions()
		update_tab_indicators()
		return
	
	if not item_data.is_empty():
		part_resource.part_id = part_id
		part_resource.layer_id = layer
		_update_part_resource(part_resource, item_data)
		_configure_part_colors_from_cache(layer, part_resource, item_data)
	else:
		part_resource.clear()
		part_resource.part_id = "none"
		part_resource.layer_id = layer
	
	if layer == "mainhand":
		if part_id == "boomerang":
			_copy_part_colors("ammo", "mainhand")
		else:
			if current_part == "mainhand":
				_sync_cache_from_character("mainhand")
			
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
	elif layer == "ammo":
		if current_character.equipment_parts.mainhand.part_id == "boomerang":
			_copy_part_colors("ammo", "mainhand")
	
	if layer == current_part:
		_fill_edit_colors()
		_refresh_active_keys()
		
	_recalculate_global_interactions()
	update_tab_indicators()


func _validate_and_update_all_parts() -> void:
	var allowed_configs = _get_current_race_config()
	var core = ["body", "head"]
	var unrestricted = %UnrestrictedMode.is_pressed()

	var all_layers = ["body", "head"] + Array(body_layers) + Array(gear_layers)
	
	for layer in all_layers:
		var is_body_part = layer in body_layers or layer == "body" or layer == "head"
		var collection = current_character.body_parts if is_body_part else current_character.equipment_parts
		if not collection: continue
		
		var part_resource = collection.get(layer)
		var current_id = part_resource.part_id
		
		# Validation logic for Restricted Mode
		if not unrestricted:
			# We only restrict BODY parts based on race. Gear is ignored here.
			if is_body_part:
				if allowed_configs.has(layer):
					# The race has this layer defined (e.g., specific ears).
					# Check if the currently selected item is allowed.
					var allowed_ids = allowed_configs[layer]
					if current_id != "" and current_id != "none" and not allowed_ids.has(current_id):
						install_part(layer, "none")
						continue
				elif not layer in core:
					# The race does NOT define this layer (e.g., wings on a human).
					# Since it's not a core part (body/head), we must clear it.
					install_part(layer, "none")
					continue
		
		# Re-install current part to ensure visuals are up to date
		if part_resource.part_id != "" and part_resource.part_id != "none":
			install_part(layer, part_resource.part_id)
		
		# Safety check: Core parts (Body/Head) must never be "none".
		# If they are "none" (or were cleared above), pick the default from config.
		if part_resource.part_id == "none" and (layer == "body" or layer == "head"):
			if allowed_configs.has(layer) and not allowed_configs[layer].is_empty():
				install_part(layer, allowed_configs[layer][0])
	
	_recalculate_global_interactions()


func _get_current_race_config() -> Dictionary:
	var race_id = current_character.race
	if not data.characters.race.has(race_id): return {}
	
	var configs = data.characters.race[race_id].get("configs", {})
	if configs.has(current_character.body_id):
		return configs[current_character.body_id]
		
	return {}


func _on_unrestricted_mode_toggled(_toggled_on: bool) -> void:
	var found_active_tab = false
	for btn in tabs_container.get_children():
		if btn.button_pressed:
			current_part = btn.name.to_lower()
			found_active_tab = true
			break
	
	if not found_active_tab:
		current_part = "body"
		
	_validate_and_update_all_parts()
	_select_tab(true, current_part)
	update_tab_indicators()


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
	
	var previous_alt_states = {}
	var all_body_layers = ["body", "head"] + Array(body_layers)
	
	for layer in all_body_layers:
		var part = current_character.body_parts.get(layer)
		if part and "is_alt" in part:
			previous_alt_states[layer] = part.is_alt
			part.is_alt = false

	for layer in gear_layers:
		var gear_part = current_character.equipment_parts.get(layer)
		if not gear_part or gear_part.part_id == "" or gear_part.part_id == "none":
			continue
			
		var item_data = _get_item_data(layer, gear_part.part_id)
		if item_data.is_empty(): continue
		
		var alt_targets = item_data.get("alt", []) if item_data.has("alt") else item_data.get("slotsalt", [])
		if alt_targets is Array:
			for target_layer in alt_targets:
				var target_part = current_character.body_parts.get(target_layer)
				if target_part and "is_alt" in target_part:
					target_part.is_alt = true
		
		if "slotshidden" in item_data:
			var targets = item_data["slotshidden"]
			if targets is Array:
				for target_id in targets:
					if not target_id in current_character.hidden_items:
						current_character.hidden_items.append(target_id)

	for layer in all_body_layers:
		var part = current_character.body_parts.get(layer)
		if part and "is_alt" in part:
			if previous_alt_states.get(layer, false) != part.is_alt:
				%Character.update_part(layer)
	
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
				if t.spritesheet.ends_with("walk") or t.spritesheet == "char_base":
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
		if part_id == "boomerang": # add boomerang idle and walk:
			var gender = "m" if current_character.gender == "male" else "f"
			images.idle = {
				"back": "res://addons/rpg_character_creator/textures/gear/ammo/boomerang/boomerang_walk_%sb.png" % gender,
				"front": "res://addons/rpg_character_creator/textures/gear/ammo/boomerang/boomerang_walk_%sf.png" % gender
			}
			images.walk = {
				"back": images.idle.back,
				"front": images.idle.front
			}
			images.islash = {
				"back": "res://addons/rpg_character_creator/textures/gear/ammo/boomerang/boomerang_islash_%sb.png" % gender,
				"front": "res://addons/rpg_character_creator/textures/gear/ammo/boomerang/boomerang_islash_%sf.png" % gender
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
	
	var target_part = current_part
	if current_part == "mainhand":
		var weapon = current_character.equipment_parts.get("mainhand")
		if weapon and weapon.part_id == "boomerang":
			target_part = "ammo"

	if selected_idx == -1:
		return [target_part]

	var meta = node.get_item_metadata(selected_idx)
	
	if meta == "merge":
		if target_part in GROUP_SKIN: return GROUP_SKIN
		if target_part in GROUP_HAIR: return GROUP_HAIR
		return [target_part]
	
	if meta == "mainhand":
		var weapon = current_character.equipment_parts.get("mainhand")
		if weapon and weapon.part_id == "boomerang":
			return ["ammo"]
	
	return [meta]


## Persists the current character state into the color cache.
## This is called when switching tabs so new buttons know if they should use custom colors.
func _sync_cache_from_character(layer: String, modified_palette_idx: int = -1, new_src_key: String = "") -> void:
	var is_body_layer = layer in body_layers or layer == "body" or layer == "head"
	var collection = current_character.body_parts if is_body_layer else current_character.equipment_parts
	var part = collection.get(layer)
	
	if not part: return
	
	var item_data = _get_item_data(layer, part.part_id)

	if layer in GROUP_SKIN and layer != "body":
		var has_any_presets = not item_data.get("primarycolors", []).is_empty() or \
							  not item_data.get("secondarycolors", []).is_empty() or \
							  not item_data.get("fixedcolors", []).is_empty()
		
		if not has_any_presets:
			var body_res = current_character.body_parts.get("body")
			if body_res:
				item_data = _get_item_data("body", body_res.part_id)

	if item_data.is_empty() or part.part_id == "none":
		var potential_parts = _get_body_parts(layer) if is_body_layer else _get_gear_parts(layer)
		for part_candidate in potential_parts:
			if part_candidate != "none":
				var candidate_data = _get_item_data(layer, part_candidate)
				if not candidate_data.get("primarycolors", []).is_empty():
					item_data = candidate_data
					break
	
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


func _rebuild_color_cache() -> void:
	_layer_color_cache.clear()
	var all_layers = ["body", "head"] + Array(body_layers) + Array(gear_layers)
	
	for layer in all_layers:
		_sync_cache_from_character(layer)


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
	var targets = _get_edit_targets()
	
	if palette_id == 0:
		for target in targets:
			%Character.set_highlight_color(target, false, 0, 0)
		return

	for target in targets:
		var highlight_layer = target
		
		if target == "ammo":
			var weapon = current_character.equipment_parts.get("mainhand")
			if weapon and weapon.part_id == "boomerang":
				highlight_layer = "mainhand"
		
		%Character.set_highlight_color(highlight_layer, true, palette_id, color_index)


func _update_colors_for_button(button: HeroEditorPartButton) -> void:
	if not is_instance_valid(button): return
	
	var layer_to_check = button.part_id
	if button.part_id == "mainhand" and button.item_id == "boomerang":
		layer_to_check = "ammo"
	
	var cache = _layer_color_cache.get(layer_to_check)
	var btn_item_data = _get_item_data(button.part_id, button.item_id)
	
	var resolve_button_gradient = func(channel_char: String, list_name: String, src_prop: String) -> PackedColorArray:
		if cache and cache.get(channel_char + "_id") == -1:
			var source_key = cache.get(src_prop, "")
			var presets = btn_item_data.get(list_name, [])
			
			if source_key == "" or presets.has(source_key):
				var grad_data = cache.get(channel_char + "_grad", [])
				if not grad_data.is_empty(): return grad_data
				var raw_data = cache.get(channel_char + "_raw", [])
				if not raw_data.is_empty(): return get_gradient(raw_data)
		
		var target_id = 0
		if cache: target_id = cache.get(channel_char + "_id", 0)
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
	
	var is_boomerang = current_part == "mainhand" and current_character.equipment_parts.mainhand.part_id == "boomerang"
	
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
	if not active_layer is String or active_layer.is_empty(): return

	var current_data
	var is_body_layer = active_layer in body_layers or active_layer == "body" or active_layer == "head"
	if is_body_layer:
		current_data = current_character.body_parts.get(active_layer)
	else:
		current_data = current_character.equipment_parts.get(active_layer)
	
	if not current_data: return
	
	var item_data = _get_item_data(active_layer, current_data.part_id)
	var palette_id = %PaletteSelector.get_selected_id()
	var palette_key = ["primarycolors", "secondarycolors", "fixedcolors"][palette_id]
	var color_list = item_data.get(palette_key, [])
	
	var node = %PalettePresets
	node.clear()
	
	var gradient_label = %GradientLabel
	
	if color_list.is_empty():
		node.add_item("There are no presets.")
	else:
		var labels = ["Primary", "Secondary", "Tertiary"]
		node.add_item("%s Color Presets - Select..." % labels[palette_id])
		gradient_label.text = "%s Gradient" % labels[palette_id]
			
		for key in color_list:
			if data.colormaps[current_character.palette].items.has(key):
				var color = data.colormaps[current_character.palette].items[key]
				var img = Image.create(20, 20, true, Image.FORMAT_RGB8)
				img.fill(Color(int(color.color)))
				var tex = ImageTexture.create_from_image(img)
				node.add_icon_item(tex, color.name)
				node.set_item_metadata(node.get_item_count() - 1, key)

	var has_primary = not item_data.get("primarycolors", []).is_empty()
	var has_secondary = not item_data.get("secondarycolors", []).is_empty()
	var has_tertiary = not item_data.get("fixedcolors", []).is_empty()
	
	%PaletteSelector.set_item_disabled(0, not has_primary)
	%PaletteSelector.set_item_disabled(1, not has_secondary)
	%PaletteSelector.set_item_disabled(2, not has_tertiary)
	
	%GradientFastButton1.set_disabled(item_data.get("primarycolors", []).is_empty())
	%GradientFastButton2.set_disabled(item_data.get("secondarycolors", []).is_empty())
	%GradientFastButton3.set_disabled(item_data.get("fixedcolors", []).is_empty())
	
	_fill_current_colors()


func _fill_current_colors() -> void:
	if not body_layers: return
	
	var targets = _get_edit_targets()
	if !targets or targets.is_empty(): return
	var active_layer = targets[0]
	if !active_layer: return
	
	var palette_id = %PaletteSelector.get_selected_id()
	var node = %CurentColorConatiner
	for child in node.get_children():
		child.queue_free()

	var current_data
	if active_layer in body_layers or active_layer in ["body", "head"]:
		current_data = current_character.body_parts.get(active_layer)
	else:
		current_data = current_character.equipment_parts.get(active_layer)
	
	if not current_data: return
	
	var palette_name = ["palette1", "palette2", "palette3"][palette_id]
	var colors = current_data[palette_name].colors
	
	for i in range(0, colors.size(), 2):
		var gradient_idx = colors[i]
		var color_val = Color(int(colors[i+1]))
		
		var b = PALETTE_BUTTON.instantiate()
		b.can_be_selected = false
		
		b.target = {
			"palette_id": palette_id, 
			"index": i / 2, 
			"color": color_val
		}
		
		b.pressed.connect(_on_palette_button_pressed)
		b.mouse_entered.connect(_hightlight_color.bind(palette_id + 1, gradient_idx))
		b.mouse_exited.connect(_hightlight_color.bind(0, 0))
		node.add_child(b)
		b.color = color_val


func _apply_color_preset(color_key: String, is_specific_list: bool = false) -> void:
	var targets = _get_edit_targets()
	var is_boomerang_equipped = current_character.equipment_parts.mainhand.part_id == "boomerang"
	
	if is_boomerang_equipped:
		if targets.has("ammo") and not targets.has("mainhand"): targets.append("mainhand")
		elif targets.has("mainhand") and not targets.has("ammo"): targets.append("ammo")

	var color_map = data.colormaps.get(current_character.palette)
	if not color_map: return
	var color_data_global = _resolve_colors_from_map(color_map, color_key)
	if color_data_global.is_empty(): return
	
	var palette_idx = %PaletteSelector.get_selected_id()
	var list_name = ["primarycolors", "secondarycolors", "fixedcolors"][palette_idx]
	active_preset_keys[palette_idx] = color_key

	for target_layer in targets:
		var coll = current_character.body_parts if target_layer in body_layers or target_layer in ["body", "head"] else current_character.equipment_parts
		var res = coll.get(target_layer)
		if not res: continue 

		var item_data = _get_item_data(target_layer, res.part_id)
		var local_preset_id = item_data.get(list_name, []).find(color_key)

		var p_res = [res.palette1, res.palette2, res.palette3][palette_idx]
		var g_prop = ["gradient1", "gradient2", "gradient3"][palette_idx]
		var id_prop = ["current_primary_color_id", "current_secondary_color_id", "current_fixed_color_id"][palette_idx]

		p_res.colors = color_data_global.colors.duplicate()
		p_res.blend_color = color_data_global.color
		res.set(g_prop, get_gradient(color_data_global.colors))
		res.set(id_prop, local_preset_id)
		
		_sync_cache_from_character(target_layer, palette_idx, color_key)
		if res.part_id != "none": %Character.update_part(target_layer)

	_update_shaders()
	for button in parts_container.get_children():
		if button is HeroEditorPartButton: _update_colors_for_button(button)
	_fill_current_colors()


func backup() -> void:
	set_meta("_backups", [
		%Palettes.get_selected_id(),
		%Races.get_selected_id(),
		%Gender.get_selected_id(),
		%Body.get_selected_id(),
		%SaveMode.get_selected_id(),
		%CharacterName.text,
		%CharacterFolder.text,
		%ShowWeapon.is_pressed(),
		%MakeInmutable.is_pressed()
	])


func refresh() -> void:
	if has_meta("_backups"):
		var meta = get_meta("_backups")
		%Palettes.select(meta[0])
		%Palettes.text = %Palettes.get_item_text(meta[0])
		%Races.select(meta[1])
		%Races.text = %Races.get_item_text(meta[1])
		%Gender.select(meta[2])
		%Gender.text = %Gender.get_item_text(meta[2])
		%Body.select(meta[3])
		%Body.text = %Body.get_item_text(meta[3])
		%SaveMode.select(meta[4])
		%SaveMode.text = %SaveMode.get_item_text(meta[4])
		%CharacterName.text = meta[5]
		%CharacterFolder.text = meta[6]
		%ShowWeapon.set_pressed_no_signal(meta[7])
		%MakeInmutable.set_pressed_no_signal(meta[8])
		remove_meta("_backups")
		
	var last_tab = current_part
		
	%Character.set_character(current_character, editor_hidden_layers)
	
	if not last_tab.is_empty():
		for btn in tabs_container.get_children():
			if btn.name.to_lower() == last_tab:
				btn.set_pressed_no_signal(true)
		
		var parts = _get_body_parts(last_tab) if last_tab in body_layers else _get_gear_parts(last_tab)
		_fill_parts(last_tab, parts)
		_fill_edit_colors()


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
	if importing: return
	
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
	if importing: return
	
	var race_id = %Races.get_item_metadata(index)
	if !race_id:
		return
	current_character.race = race_id
	var race = data.characters.race[race_id]
	
	fill_genders(race.genders, current_character.gender)


func _on_gender_item_selected(index: int) -> void:
	if importing: return
	
	var gender_id = %Gender.get_item_metadata(index)
	if !gender_id:
		return
	current_character.gender = gender_id
	
	fill_bodies(current_character.body_id)


func _on_body_item_selected(index: int) -> void:
	if importing: return
	
	var body_data = %Body.get_item_metadata(index)
	if !body_data: return

	current_character.body_id = body_data.id
	current_character.body_type = body_data.body_type
	current_character.head_type = body_data.head_type
	
	install_part("body", body_data.body_id)
	install_part("head", body_data.head_id)
	
	_validate_and_update_all_parts()
	
	_apply_default_preset_for_layer("body")
	_apply_default_preset_for_layer("head")
	
	current_part = "body"
	
	_fill_edit_colors()
	_fill_palette_presets()
	
	if starting:
		select("eyes")
	else:
		select(current_part)


func _apply_default_preset_for_layer(layer: String) -> void:
	var res = current_character.body_parts.get(layer)
	if not res: return
	
	var item_data = _get_item_data(layer, res.part_id)
	var presets = item_data.get("primarycolors", [])
	
	if presets.is_empty(): return
	
	if res.current_primary_color_id < 0 or res.current_primary_color_id >= presets.size():
		var target_key = presets[0]
		_apply_color_preset(target_key, true)


func refresh_part_buttons() -> void:
	_select_tab.call_deferred(true, current_part)


func _select_tab(value: bool, layer: String) -> void:
	if value:
		current_part = layer
		
		var effective_layer = layer
		if layer == "mainhand":
			var weapon = current_character.equipment_parts.get("mainhand")
			if weapon and weapon.part_id == "boomerang":
				effective_layer = "ammo"
		
		_sync_cache_from_character(effective_layer)
		_refresh_active_keys()
		
		var parts: Array
		if layer in body_layers:
			parts = _get_body_parts(layer)
		else:
			parts = _get_gear_parts(layer)
			
		_fill_parts(layer, parts)
		_fill_edit_colors()


func _on_part_button_pressed(_layer: String, _part_id: String, _item_data: Dictionary) -> void:
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
	
	var is_boomerang_equipped = current_character.equipment_parts.mainhand.part_id == "boomerang"
	if is_boomerang_equipped and (targets.has("ammo") or targets.has("mainhand")):
		if not targets.has("ammo"): targets.append("ammo")
		if not targets.has("mainhand"): targets.append("mainhand")
	
	for target_layer in targets:
		var is_body = target_layer in body_layers or target_layer == "body" or target_layer == "head"
		var collection = current_character.body_parts if is_body else current_character.equipment_parts
		var current_data = collection.get(target_layer)
		
		if not current_data: continue
		
		var target_index = (item_id * 2) + 3
		if current_data[palette].colors.size() > target_index:
			current_data[palette].colors[target_index] = color.to_rgba32()
			current_data["gradient%s" % palette.right(1)] = get_gradient(current_data[palette].colors)
		
		var palette_num = palette.right(1) # Extract "1", "2" o "3"
		var grad_val = current_data["gradient" + palette_num]
		
		%Character.set_part_shader_parameter(target_layer, "palette" + palette_num, grad_val)


func _on_color_dialog_color_selected(color: Color, palette: String, item_id: int, original_color: Color) -> void:
	var targets = _get_edit_targets()
	
	var is_boomerang_equipped = current_character.equipment_parts.mainhand.part_id == "boomerang"
	if is_boomerang_equipped:
		if (targets.has("ammo") or targets.has("mainhand")):
			if not targets.has("ammo"): targets.append("ammo")
			if not targets.has("mainhand"): targets.append("mainhand")

	var something_changed = false
	for target_layer in targets:
		var is_body = target_layer in body_layers or target_layer == "body" or target_layer == "head"
		var collection = current_character.body_parts if is_body else current_character.equipment_parts
		var current_data = collection.get(target_layer)
		
		if not current_data: continue
		var target_index = (item_id * 2) + 3
		
		if current_data[palette].colors.size() > target_index:
			current_data[palette].colors[target_index] = color.to_rgba32()
			current_data["gradient%s" % palette.right(1)] = get_gradient(current_data[palette].colors)
			
			var cache = _layer_color_cache.get(target_layer, {})
			var p_idx = 0 if palette == "palette1" else 1 if palette == "palette2" else 2
			
			match p_idx:
				0: current_data.current_primary_color_id = -1
				1: current_data.current_secondary_color_id = -1
				2: current_data.current_fixed_color_id = -1
				
			_sync_cache_from_character(target_layer, p_idx, "")
			
			something_changed = true
			if current_data.part_id != "none":
				%Character.update_part(target_layer)
	
	if something_changed:
		_update_ui_after_color_change()


func _update_ui_after_color_change() -> void:
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
	var p_idx = 0 if gradient_id == "gradient1" else 1 if gradient_id == "gradient2" else 2
	
	for target_layer in targets:
		var is_body = target_layer in body_layers or target_layer in ["body", "head"]
		var collection = current_character.body_parts if is_body else current_character.equipment_parts
		var current_data = collection.get(target_layer)
		if not current_data: continue
		
		current_data.set(gradient_id, colors)
		
		var palette_res = [current_data.palette1, current_data.palette2, current_data.palette3][p_idx]
		var current_palette_colors = palette_res.colors
		
		for i in range(0, current_palette_colors.size(), 2):
			var color_index_in_gradient = current_palette_colors[i]
			var new_color = colors[color_index_in_gradient]
			current_palette_colors[i+1] = new_color.to_rgba32()
		
		palette_res.colors = current_palette_colors
		
		var id_props = ["current_primary_color_id", "current_secondary_color_id", "current_fixed_color_id"]
		current_data.set(id_props[p_idx], -1)
		
		var cache = _layer_color_cache.get(target_layer, {})
		var p_char = ["p", "s", "f"][p_idx]
		cache[p_char + "_id"] = -1
		cache[p_char + "_raw"] = current_palette_colors.duplicate()
		cache[p_char + "_grad"] = colors
		_layer_color_cache[target_layer] = cache
		
		something_changed = true
		%Character.update_part(target_layer)
	
	if something_changed:
		_update_ui_after_color_change()
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
	%Character.set_character(current_character, editor_hidden_layers)


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
		"horns": 0.2, "back": 0.15
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


#region Save and Import
func _confirm_overwrite(msg: String) -> bool:
	var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_text(tr("There is already a preset with that name. Do you want to overwrite it?"))
	dialog.title = TranslationManager.tr("Override Preset")
	await dialog.tree_exiting
	return dialog.result


func _on_character_random_name_button_pressed() -> void:
	var race = %Races.get_item_text(%Races.get_selected_id())
	var text = race_name_generator.generate_name_for_race(race)
	%CharacterName.text = text


func get_file_id(folder, base_name) -> int:
	var max_id = 0
	var dir = DirAccess.open(folder)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres"):
					var name_no_ext = file_name.get_basename()

					if name_no_ext.begins_with(base_name):
						var suffix = name_no_ext.trim_prefix(base_name)

						if suffix.is_valid_int():
							var found_id = suffix.to_int()
							if found_id > max_id:
								max_id = found_id
			
			file_name = dir.get_next()
		dir.list_dir_end()
	
	return max_id + 1


func _on_part_save_requested(layer: String, item_id: String, button: HeroEditorPartButton) -> void:
	_show_overlay()
	
	var is_body = layer in body_layers or layer == "body" or layer == "head"
	var collection = current_character.body_parts if is_body else current_character.equipment_parts
	var source_part = collection.get(layer)
	
	if not source_part: return
	
	var new_item_data = _get_item_data(layer, item_id)
	if new_item_data.is_empty(): return

	var part_to_save = source_part.duplicate(true)
	
	_clean_part_gradients(part_to_save, true)
	
	part_to_save.part_id = item_id
	part_to_save.layer_id = layer
	if "name" in part_to_save:
		part_to_save.name = new_item_data.get("name", item_id)
	part_to_save.config_path = _fix_path(new_item_data.get("config_path", ""))
	
	part_to_save.body_type = current_character.body_type
	part_to_save.head_type = current_character.head_type
	
	if "textures" in new_item_data:
		part_to_save.front_texture = _fix_path(new_item_data.textures.get("front", ""))
		part_to_save.back_texture = _fix_path(new_item_data.textures.get("back", ""))
	
	var global_map = data.colormaps.get(current_character.palette)
	
	if global_map:
		_smart_update_color(part_to_save.palette1, "current_primary_color_id", "gradient1", new_item_data.get("primarycolors", []), global_map, part_to_save)
		_smart_update_color(part_to_save.palette2, "current_secondary_color_id", "gradient2", new_item_data.get("secondarycolors", []), global_map, part_to_save)
		_smart_update_color(part_to_save.palette3, "current_fixed_color_id", "gradient3", new_item_data.get("fixedcolors", []), global_map, part_to_save)
	
	var folder = PARTS_ROOT_DIR.path_join(current_part + "/")
	if !DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)
	
	var regex = RegEx.new()
	regex.compile("\\d+$")
	var base_name = regex.sub(item_id, "")
	
	if base_name.is_empty():
		base_name = "custom_part"
	
	var id = get_file_id(folder, base_name)
	var resource_path = folder.path_join(base_name + str(id) + ".tres")
	var image_path = folder.path_join(base_name + str(id) + "_preview.png")
	
	# Save
	if button:
		var tex = button.get_texture_rect()
		if tex:
			var target_size = tex.texture.get_size()
			%PreviewPartViewport.size = target_size
			%PreviewPartTexture.size = target_size
			
			%PreviewPartTexture.texture = tex.texture
			%PreviewPartTexture.material = tex.material
			%PreviewPartTexture.position = Vector2.ZERO
			
			%PreviewPartViewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			
			var img = %PreviewPartViewport.get_texture().get_image()
			if img:
				img.save_png(image_path)
				part_to_save.equipment_preview = image_path
				
	ResourceSaver.save(part_to_save, resource_path)
	
	_clean_part_gradients(part_to_save, false)
	
	_hide_overlay()
	
	var help_text = "Part %s Saved in %s" % [item_id, resource_path]
	_show_save_notification(help_text)
	
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()


func _show_save_notification(message: String) -> void:
	if not help_label:
		help_label = HELP_LABEL.instantiate()
		get_window().add_child(help_label)
	help_label.text = message
	
	if help_label_tween: help_label_tween.kill()
	
	help_label_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	help_label_tween.tween_callback(help_label.show)
	help_label_tween.tween_property(help_label, "modulate", Color.WHITE, 0.3).from(Color.TRANSPARENT)
	help_label_tween.tween_interval(1.0)
	help_label_tween.tween_property(help_label, "modulate", Color.TRANSPARENT, 0.5)
	help_label_tween.tween_callback(help_label.hide)


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
			%CharacterName.placeholder_text = tr("Character Name")
			%CharacterRandomNameButton.visible = true
		1:
			%SaveOptions1.visible = true
			%SaveOptions2.visible = false
			%CustomeLabel.visible = false
			%FolderContainer.visible = true
			%CharacterName.placeholder_text = tr("Event Name")
			%CharacterRandomNameButton.visible = true
		2:
			%SaveOptions1.visible = true
			%SaveOptions2.visible = false
			%CustomeLabel.visible = false
			%FolderContainer.visible = false
			%CharacterName.placeholder_text = tr("Set Name")
			%CharacterRandomNameButton.visible = false
		3:
			%SaveOptions1.visible = true
			%SaveOptions2.visible = false
			%CustomeLabel.visible = true
			%FolderContainer.visible = false
			%CharacterName.placeholder_text = tr("Costume Name")
			%CharacterRandomNameButton.visible = false


func _clean_part_gradients(part: Resource, active: bool) -> void:
	if not part: return
	if "is_cleaning_for_save" in part:
		part.is_cleaning_for_save = active


func _clean_collection_gradients(obj: Variant, is_body_parts: bool = false, active: bool = true) -> void:
	var collection = PackedStringArray(["body", "head"]) + body_layers if is_body_parts else gear_layers
	for key in collection:
		var part = obj.get(key)
		if part:
			_clean_part_gradients(part, active)


func _on_save_data_pressed() -> void:
	var folder = %CharacterFolder.text
	var file_name = %CharacterName.text.to_lower()

	if %CreateSubFolder.is_pressed():
		folder = folder.path_join(file_name)
	
	_show_overlay()
	
	match %SaveMode.get_selected_id():
		0: # Save Character
			await _save_character(folder, file_name)
			_show_save_notification("Character “%s” Saved" % file_name)
		1: # Save Event
			await _save_event(folder, file_name)
			_show_save_notification("Event “%s” Saved" % file_name)
		2: # Save Set (manually hidden layers = discarded)
			await _save_set(file_name)
			_show_save_notification("Set “%s” Saved" % file_name)
		3: # Save Costume (manually hidden layers = ignored and save all)
			await _save_costume(file_name)
			_show_save_notification("Costume “%s” Saved" % file_name)
	
	_hide_overlay()


## Checks if any of the target files already exist and returns a list of their names.
func _get_existing_files(paths: Array[String]) -> Array[String]:
	var existing: Array[String] = []
	for path in paths:
		if FileAccess.file_exists(path):
			existing.append(path.get_file())
	return existing


func _save_character(folder: String, file_name: String) -> void:
	_show_overlay()
	
	# Paths
	var data_path = folder.path_join(file_name + "_data.tres")
	var scene_path = folder.path_join(file_name + ".tscn")
	var scene_script_path = folder.path_join(file_name + ".gd")
	var face_preview = folder.path_join(file_name + "_face.png")
	var character_preview = folder.path_join(file_name + "_character.png")
	var battler_preview = folder.path_join(file_name + "_battler.png")
	var minimalist_charset = folder.path_join(file_name + "_character_minimalist.png")
	
	var all_paths: Array[String] = [
		data_path, scene_path, scene_script_path, 
		face_preview, character_preview, battler_preview, minimalist_charset
	]
	
	var existing = _get_existing_files(all_paths)
	
	if not existing.is_empty():
		var msg = "The following files already exist:\n- %s\n\nDo you want to overwrite them?" % "\n- ".join(existing)
		if not await _confirm_overwrite(msg):
			return
	
	DirAccess.make_dir_recursive_absolute(folder)
	
	# Images
	var charset: Image = await %Character.get_minimalist_spriteset()
	charset.save_png(minimalist_charset)
	
	var char: Image = await %Character.get_character_preview()
	char.save_png(character_preview)
	
	var battler: Image = await %Character.get_battler_preview()
	battler.save_png(battler_preview)
	
	var face: Image = await %Character.get_face_preview()
	face.save_png(face_preview)
	
	# Resource
	var res = current_character.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	res.face_preview = face_preview
	res.character_preview = character_preview
	res.battler_preview = battler_preview
	res.scene_path = scene_path
	res.always_show_weapon = %ShowWeapon.is_pressed()
	res.inmutable = %MakeInmutable.is_pressed()
	
	_clean_collection_gradients(res.body_parts, true)
	_clean_collection_gradients(res.equipment_parts)
	
	ResourceSaver.save(res, data_path)
	
	_clean_collection_gradients(res.body_parts, true, false)
	_clean_collection_gradients(res.equipment_parts, false, false)
	
	# Scene And Script
	_create_character_script(scene_script_path)
	_create_character_scene_file(scene_script_path, scene_path, current_character, file_name)
	
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
		
	_hide_overlay()


func _create_character_script(script_file_path: String) -> void:
	var script = GDScript.new()
	script.source_code = "@tool\nextends LPCCharacter\n\n"
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


func _save_event(folder: String, file_name: String) -> void:
	_show_overlay()
	
	# Paths
	var data_path = folder.path_join(file_name + "_data.tres")
	var scene_path = folder.path_join(file_name + "_event.tscn")
	var scene_script_path = folder.path_join(file_name + "_event.gd")
	var character_preview = folder.path_join(file_name + "_event.png")
	var minimalist_charset = folder.path_join(file_name + "_character_minimalist.png")
	
	var all_paths: Array[String] = [
		data_path, scene_path, scene_script_path, character_preview, minimalist_charset
	]
	
	var existing = _get_existing_files(all_paths)
	
	if not existing.is_empty():
		var msg = "The following files already exist:\n- %s\n\nDo you want to overwrite them?" % "\n- ".join(existing)
		if not await _confirm_overwrite(msg):
			return
	
	DirAccess.make_dir_recursive_absolute(folder)
	
	# Images
	var charset: Image = await %Character.get_minimalist_spriteset()
	charset.save_png(minimalist_charset)
	
	var character: Image = await %Character.get_battler_preview()
	character.save_png(character_preview)
	
	# Resource
	var res = current_character.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	res.event_preview = character_preview
	res.scene_path = scene_path
	res.inmutable = true
	res.always_show_weapon = true
	
	_clean_collection_gradients(res.body_parts, true)
	_clean_collection_gradients(res.equipment_parts)
	
	ResourceSaver.save(res, data_path)
	
	_clean_collection_gradients(res.body_parts, true, false)
	_clean_collection_gradients(res.equipment_parts, false, false)
	
	# Scene And Script
	_create_event_script(scene_script_path)
	_create_event_scene_file(scene_script_path, scene_path, current_character, file_name)
	
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
		
	_hide_overlay()


func _create_event_script(script_file_path: String) -> void:
	var script = GDScript.new()
	script.source_code = "@tool\nextends GenericLPCEvent\n\n"
	ResourceSaver.save(script, script_file_path)


func _create_event_scene_file(script_file_path: String, scene_file_path: String, event_data: RPGLPCCharacter, name: String) -> void:
	var scn = GENERIC_LPC_BASE_SCENE.instantiate()
	var script = load(script_file_path)
	scn.set_script(script)
	scn.event_data = event_data
	scn.name = name.to_pascal_case()
	scn.add_to_group("event")
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(scn)
	ResourceSaver.save(packed_scene, scene_file_path)
	
	scn.free()


func _save_set(file_name: String) -> void:
	_show_overlay()
	
	var folder = PARTS_ROOT_DIR.path_join(SET_FOLDER_NAME).path_join(file_name) 
	var data_path = folder.path_join(file_name + "_data.tres")
	var set_preview = folder.path_join(file_name + "_preview.png")
	
	var all_paths: Array[String] = [
		data_path, set_preview
	]
	
	var existing = _get_existing_files(all_paths)
	
	if not existing.is_empty():
		var msg = "The following files already exist:\n- %s\n\nDo you want to overwrite them?" % "\n- ".join(existing)
		if not await _confirm_overwrite(msg):
			return
	
	DirAccess.make_dir_recursive_absolute(folder)
	
	var set_image: Image = await %Character.get_set_preview()
	set_image.save_png(set_preview)
	
	var res = IngameGearSet.create_from_parts(current_character.equipment_parts) 
	res.set_preview = set_preview
	
	_clean_collection_gradients(res.equipment_parts)
	
	ResourceSaver.save(res, data_path)
	
	_clean_collection_gradients(res.equipment_parts, false, false)
	
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
		
	_hide_overlay()


func _save_costume(file_name: String) -> void:
	_show_overlay()
	
	var folder = PARTS_ROOT_DIR.path_join(COSTUME_FOLDER_NAME).path_join(file_name)
	var data_path = folder.path_join(file_name + "_data.tres")
	var costume_preview = folder.path_join(file_name + "_preview.png") 
	
	var all_paths: Array[String] = [
		data_path, costume_preview
	]
	
	var existing = _get_existing_files(all_paths)
	
	if not existing.is_empty():
		var msg = "The following files already exist:\n- %s\n\nDo you want to overwrite them?" % "\n- ".join(existing)
		if not await _confirm_overwrite(msg):
			return
	
	DirAccess.make_dir_recursive_absolute(folder)
	
	var costume_image: Image = await %Character.get_costume_preview()
	costume_image.save_png(costume_preview)
	
	var res = IngameCostume.create_from_character(current_character) 
	res.character_preview = costume_preview 
	res.inmutable = true 
	res.always_show_weapon = true 
	
	var layers_to_none = current_character.hidden_items.duplicate()
	for layer in editor_hidden_layers:
		if not layer in layers_to_none:
			layers_to_none.append(layer)
	
	for layer in layers_to_none:
		var is_body = layer in body_layers or layer == "body" or layer == "head"
		var collection = res.body_parts if is_body else res.equipment_parts
		
		if layer in collection:
			var part_res = collection.get(layer)
			part_res.clear()
			part_res.part_id = "none"
	
	_clean_collection_gradients(res.body_parts, true)
	_clean_collection_gradients(res.equipment_parts)
	
	ResourceSaver.save(res, data_path)
	
	_clean_collection_gradients(res.body_parts, true, false)
	_clean_collection_gradients(res.equipment_parts, false, false)
	
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
		
	_hide_overlay()


func _show_overlay() -> void:
	var tex = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	%OverlayTexture.texture = tex
	%Overlay.show()


func _hide_overlay() -> void:
	%OverlayTexture.texture = null
	%Overlay.hide()


func _on_character_name_text_changed(new_text: String) -> void:
	var lineedit = %CharacterName
	var caret_pos = lineedit.caret_column
	
	# Convert to lowercase first to satisfy the requirement
	var lower_text = new_text.replace(" ", "_").to_lower()
	
	
	# Updated RegEx to allow lowercase letters, numbers, underscores and 'ñ'
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_ñ]")
	
	var clean_text = regex.sub(lower_text, "", true)
	
	if new_text != clean_text:
		lineedit.text = clean_text
		# Restore caret position. If it was a conversion (Upper to Lower), 
		# we don't subtract 1 to keep the flow
		var diff = new_text.length() - clean_text.length()
		lineedit.caret_column = caret_pos - diff


func _on_character_folder_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.target_callable = _set_save_folder
	dialog.set_dialog_mode(1)
	dialog.hide_directory_extra_controls2()
	dialog.destroy_on_hide = true
	
	var default_path = %CharacterFolder.text
	if not default_path.begins_with("res://"):
		default_path = "res://".path_join(default_path)
	
	dialog.navigate_to_directory.call_deferred(default_path)


func _set_save_folder(path: String) -> void:
	var folder = path.get_basename().replace("res://", "")
	if not folder.ends_with("/"):
		folder += "/"
		
	%CharacterFolder.text = folder


# --- Imports


func _on_import_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.target_callable = _on_import_data
	dialog.destroy_on_hide = true
	
	dialog.fill_mix_files(["characters", "events", "equipment_parts", "sets", "costumes"])


func _on_import_data(path: String) -> void:
	if ResourceLoader.exists(path):
		var res: Variant = load(path).duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		
		importing = true 
		tasks.clear()
		_clear_parts()

		if res is IngameCostume:
			var character = RPGLPCCharacter.create_from_costume(res)
			_import_character(character, path, true)
		elif res is RPGLPCCharacter:
			_import_character(res, path)
		elif res is IngameGearSet:
			_import_gear_set(res)
		elif res is RPGLPCEquipmentPart:
			_import_part(res, true)
		
		if importing:
			importing = false
			_finalize_import_ui()


func _finalize_import_ui() -> void:
	if current_part.is_empty():
		current_part = "body"
	
	%Character.set_character(current_character, editor_hidden_layers)
	
	_select_tab(true, current_part)
	update_tab_indicators()
	
	_fill_palette_presets.call_deferred()
	_update_shaders.call_deferred()
	_recalculate_global_interactions.call_deferred()


# --- CORE IMPORT FUNCTIONS ---

func _import_character(character: RPGLPCCharacter, path: String, is_costume: bool = false) -> void:
	current_character = character
	
	# 1. UI Setup
	var character_name = path.get_file().replace("_data." + path.get_extension(), "")
	%CharacterName.text = character_name
	
	var folder = path.get_base_dir().replace("res://", "")
	if not folder.ends_with("/"): folder += "/"
	%CharacterFolder.text = folder
	
	if is_costume:
		%SaveMode.set_pressed_no_signal(3)
	else:
		%SaveMode.set_pressed_no_signal(0)
		%ShowWeapon.set_pressed_no_signal(character.always_show_weapon)
		%MakeInmutable.set_pressed_no_signal(character.inmutable)
	%CreateSubFolder.set_pressed_no_signal(false)
	
	# 2. Metadata Sync (Palette, Race, Gender)
	var pal_idx = _get_index_by_metadata(%Palettes, character.palette)
	if pal_idx != -1: %Palettes.select(pal_idx)
	
	_sync_race_and_gender_ui(character)
	
	# 3. Body & Geometry Recovery
	_recover_body_configuration(character)
	fill_bodies(character.body_id)
	
	var body_node = %Body
	for i in body_node.get_item_count():
		if body_node.get_item_metadata(i).get("id") == character.body_id:
			body_node.select(i)
			break

	# 4. Unrestricted Mode Check
	_check_and_apply_unrestricted_mode()

	# 5. Data Injection & Sanitization
	var layers_to_check = ["body", "head"] + Array(body_layers) + Array(gear_layers)
	var db_char = data.characters
	var db_gear = data.gear
	
	for layer in layers_to_check:
		var is_body = layer in body_layers or layer == "body" or layer == "head"
		var collection = current_character.body_parts if is_body else current_character.equipment_parts
		if not collection: continue
		var part = collection.get(layer)
		
		# Fix Legacy Data
		if part.gradient1.is_empty() or (part.part_id != "none" and part.config_path != ""):
			_fix_import_data(part, layer)
			var db = db_char if is_body else db_gear
			if layer in db and part.part_id != "none" and not db[layer].has(part.part_id):
				part.part_id = "none"
		
		# Sanitize Colors (Force Custom -1 if needed)
		if part.part_id != "none":
			_sanitize_part_colors(layer, part)

	# 6. Cache & Finish
	_rebuild_color_cache()
	
	var found_active_tab = false
	for btn in tabs_container.get_children():
		if btn.button_pressed:
			current_part = btn.name.to_lower()
			found_active_tab = true
			break
	if not found_active_tab: current_part = "body"
	
	importing = false
	_finalize_import_ui()
	_show_save_notification("Import Complete. Synced Layer: %s" % current_part)


func _import_gear_set(full_set: IngameGearSet) -> void:

	for layer in gear_layers:
		var imported_part = full_set.equipment_parts.get(layer)
		
		if imported_part:
			if imported_part.layer_id.is_empty():
				imported_part.layer_id = layer
			
			_import_part(imported_part, false)
	
	_recalculate_global_interactions()
	_show_save_notification("Gear Set Imported")


func _import_part(source_part: Resource, refresh_ui: bool = true) -> void:
	var layer = source_part.layer_id
	_fix_import_data(source_part, layer)
	
	if refresh_ui:
		current_part = layer
		if _layer_color_cache.has(layer):
			_layer_color_cache.erase(layer)
		
		for b in tabs_container.get_children():
			b.set_pressed_no_signal(b.text.to_lower() == layer)
	
	# 1. Install (Set IDs, Texture paths)
	install_part(layer, source_part.part_id)
	
	# 2. Inject Data (Colors, Gradients)
	var target_part = _get_character_part(layer)
	if target_part:
		_inject_part_data(target_part, source_part)
		
		# 3. Sanitize (Ensure colors match IDs)
		_sanitize_part_colors(layer, target_part)
		
		# 4. Update Cache
		_sync_cache_from_character(layer)

	if refresh_ui:
		importing = false
		_finalize_import_ui()
		_show_save_notification("Part Imported: %s" % source_part.part_id)


# --- HELPERS ---

# Copy colors, gradients, and IDs from one resource to another
func _inject_part_data(target: Resource, source: Resource) -> void:
	target.gradient1 = source.gradient1
	target.gradient2 = source.gradient2
	target.gradient3 = source.gradient3
	
	if source.palette1:
		target.palette1.colors = source.palette1.colors.duplicate()
		target.palette1.blend_color = source.palette1.blend_color
	if source.palette2:
		target.palette2.colors = source.palette2.colors.duplicate()
		target.palette2.blend_color = source.palette2.blend_color
	if source.palette3:
		target.palette3.colors = source.palette3.colors.duplicate()
		target.palette3.blend_color = source.palette3.blend_color
	
	target.current_primary_color_id = source.get("current_primary_color_id") if "current_primary_color_id" in source else -1
	target.current_secondary_color_id = source.get("current_secondary_color_id") if "current_secondary_color_id" in source else -1
	target.current_fixed_color_id = source.get("current_fixed_color_id") if "current_fixed_color_id" in source else -1


# Check if the colors match the preset. If not, force ID -1 (Custom).
func _sanitize_part_colors(layer: String, part: Resource) -> void:
	var global_map = data.colormaps.get(current_character.palette)
	if not global_map: return
	
	var item_data = _get_item_data(layer, part.part_id)
	if item_data.is_empty(): return
	
	var check_consistency = func(id_prop, colors_prop, list_name):
		var current_idx = part.get(id_prop)
		if current_idx == -1: return

		var current_colors = part.get(colors_prop).colors
		if current_colors.is_empty(): return

		var is_consistent = false
		var presets = item_data.get(list_name, [])
		
		if current_idx >= 0 and current_idx < presets.size():
			var preset_key = presets[current_idx]
			var map_data = _resolve_colors_from_map(global_map, preset_key)
			
			# We use _are_colors_equal to avoid type errors (Packed vs Array).
			if not map_data.is_empty() and _are_colors_equal(current_colors, map_data.colors):
				is_consistent = true
		
		# If the ID says it is a preset (0, 1...) but the colors do not match, we force -1.
		if not is_consistent:
			part.set(id_prop, -1)

	check_consistency.call("current_primary_color_id", "palette1", "primarycolors")
	check_consistency.call("current_secondary_color_id", "palette2", "secondarycolors")
	check_consistency.call("current_fixed_color_id", "palette3", "fixedcolors")


func _check_and_apply_unrestricted_mode() -> void:
	var needs_unrestricted = false
	var config = _get_current_race_config()
	
	if config.is_empty():
		needs_unrestricted = true
	else:
		for layer in body_layers:
			var part = current_character.body_parts.get(layer)
			if part and part.part_id != "none" and part.part_id != "":
				if not config.has(layer) or not part.part_id in config[layer]:
					needs_unrestricted = true
					break
	
	if needs_unrestricted:
		%UnrestrictedMode.set_pressed_no_signal(true)


func _recover_body_configuration(character: RPGLPCCharacter) -> void:
	var race_def = data.characters.race.get(character.race)
	if not race_def or not race_def.has("configs"): return
	
	# 1. Attempt to validate the current ID
	if character.body_id != "" and race_def.configs.has(character.body_id):
		return # Valid ID
	
	# 2. Search by visual match
	for config_id in race_def.configs:
		var config = race_def.configs[config_id]
		if config.gender == character.gender and \
		   config.get("body-type") == character.body_type and \
		   config.get("head-type") == character.head_type:
			character.body_id = config_id
			return
			
	# 3. Force synchronization of visual types if we find ID
	if character.body_id != "" and race_def.configs.has(character.body_id):
		var cfg = race_def.configs[character.body_id]
		if cfg.has("head-type"): character.head_type = cfg["head-type"]
		if cfg.has("body-type"): character.body_type = cfg["body-type"]


func _sync_race_and_gender_ui(character: RPGLPCCharacter) -> void:
	# Sync Race
	var race_idx = _get_index_by_metadata(%Races, character.race)
	if race_idx == -1: # Fallback by name
		for i in %Races.get_item_count():
			if %Races.get_item_text(i).to_lower() == character.race.to_lower().replace("_", " "):
				race_idx = i
				character.race = %Races.get_item_metadata(i)
				break
	if race_idx != -1: 
		%Races.select(race_idx)
		var race_data = data.characters.race[character.race]
		fill_genders(race_data.genders, character.gender)

	# Sync Gender
	var gen_idx = _get_index_by_metadata(%Gender, character.gender)
	if gen_idx != -1: %Gender.select(gen_idx)


func _get_character_part(layer: String) -> Resource:
	if layer in ["body", "head"] + Array(body_layers):
		return current_character.body_parts.get(layer)
	return current_character.equipment_parts.get(layer)


func _fix_import_data(part: Variant, layer: String) -> void:
	part.layer_id = layer
	part.config_path = part.config_path.get_basename() + ".lcc"
	
	# Ensure gradients if missing
	if part.gradient1.is_empty() and part.palette1: part.gradient1 = get_gradient(part.palette1.colors)
	if part.gradient2.is_empty() and part.palette2: part.gradient2 = get_gradient(part.palette2.colors)
	if part.gradient3.is_empty() and part.palette3: part.gradient3 = get_gradient(part.palette3.colors)
	
	if "alt_config_path" in part and not part.alt_config_path.is_empty():
		part.alt_config_path = part.alt_config_path.get_basename() + ".lcc"
		
	# Retrieve actual part_id from the file if it exists
	if FileAccess.file_exists(part.config_path):
		var f = FileAccess.open(part.config_path, FileAccess.READ)
		var json = f.get_as_text()
		f.close()
		var obj: Dictionary = JSON.parse_string(json)
		part.part_id = obj.get("id", "none")


func _are_colors_equal(packed_colors: Variant, json_colors: Array) -> bool:
	if packed_colors.size() != json_colors.size():
		return false
	
	for i in range(packed_colors.size()):
		var c1 = packed_colors[i] if packed_colors[i] is Color else Color(int(packed_colors[i]))
		var c2 = Color(json_colors[i]) if json_colors[i] is String else Color(int(json_colors[i]))
		if c1.to_html() != c2.to_html():
			return false
	return true

#endregion
