@tool
extends MarginContainer

@export var debug_draw: bool = true

var files

var data: Dictionary

var current_character: Dictionary = {
	"palette": null,
	"race": null,
	"gender": null,
	"body": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"head": {"item" : null, "selected_index" : 0},
	"wings": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"tail": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"horns": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"hair": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0, "alt_item" : null},
	"hairadd": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"eyes": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"ears": {"item" : null, "selected_index" : 0},
	"nose": {"item" : null, "selected_index" : 0},
	"facial": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"add1": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"add2": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"add3": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"mask": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"hat": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"glasses": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"suit": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"jacket": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"shirt": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"gloves": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"belt": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"pants": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"shoes": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"back": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"mainhand": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0, "textures": []},
	"offhand": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0},
	"ammo": {"palettes" : get_palette_struct(), "item" : null, "selected_index" : 0, "textures": []}
}

var ide_animation_tween: Tween

var player_animations_data: Dictionary
var weapon_animations_data: Dictionary
var current_animation: String
var current_animation_frame = 0
var frame_duration: float = 0.07
var next_frame_delay: float = 0.0
var can_action: bool = true
var current_direction: String = "down"
var weapon_large_shown: bool = false
var weapon_walking_mode: bool = false
var alt_parts: Array = []
var sealed_slots: Array = []
var can_refresh_visibility: bool = true

var debug_draw_timer: float = 0.0
var refresh_visibility_timer: float = 0.0

var current_node_editting_colors: String = ""

var paletted_dialog_first_opened: bool = false

var palette_dialog_need_refresh = null

var plugin_enabled = false

var busy: bool

var debug: bool = false

const ACTOR_BASE_SCENE = preload("res://addons/rpg_character_creator/Other/actor_base_scene.tscn")

signal animation_finished()
signal next_frame()
signal palette_dialog_refresh()


func _ready() -> void:
	clear_all()
	set_option_button_connections(self)


func set_option_button_connections(node: Node) -> void:
	if node is OptionButton:
		node.get_popup().visibility_changed.connect(_on_option_popup_visibility_changed.bind(node))
	
	if node == %PaletteDialog:
		return
	
	for child in node.get_children():
		set_option_button_connections(child)



func _on_option_popup_visibility_changed(node: OptionButton) -> void:
	var popup = node.get_popup()
	var palette = %PaletteDialog
	if popup.visible:
		if palette.visible:
			palette.set_meta("is_visible", palette.position)
			palette.position = -Vector2.INF
	else:
		if palette.has_meta("is_visible"):
			palette.position = palette.get_meta("is_visible")
			palette.remove_meta("is_visible")


func set_viewport_textures() -> void:
	# Set viewports here to void error when select this file in database editor
	%BodyFirstPassTexture.texture = %BodyFirstPassViewport.get_texture()
	%CurrentCharacter.texture.atlas = %BodySecondPassViewport.get_texture()
	%WeaponBack.texture.atlas = $MainhandBackViewport.get_texture()
	%WeaponFront.texture.atlas = $MainhandFrontViewport.get_texture()
	%OffhandBack.texture.atlas = $OffhandBackViewport.get_texture()
	%OffhandFront.texture.atlas = $OffhandFrontViewport.get_texture()
	%AmmoBack.texture.atlas = $AmmoBackViewport.get_texture()
	%AmmoFront.texture.atlas = $AmmoFrontViewport.get_texture()
	%FinalCharacter.texture = $FinalMixViewport.get_texture()
	%FaceTexture.texture.atlas = %BodySecondPassViewport.get_texture()


func set_plugin_enabled(value: bool) -> void:
	plugin_enabled = value
	if value:
		set_viewport_textures()
		set_options_and_palette_buttons_connection(self)
		set_animations()
		set_colormap_data()
		set_credits_data()
		set_characters_data()
		set_gear_data()
		fill_races_and_paletes()
		update_all_palettes()
		
		%CharacterContainer.gui_input.connect(_on_character_container_gui_input)
		%PaletteDialog.update_palette_requested.connect(_on_update_palette_requested)
		%PaletteDialog.size = Vector2(size.x / 2, size.y - 200)
		
		animation_finished.connect(set.bind("can_action", true))
		
		var ammo_folder_path = "res://addons/rpg_character_creator/textures/projectiles/"
		var ammo_texture = %AmmoTexture.texture
		var ammo_viewport = %AmmoFinalMix
		var ammo_path = ammo_folder_path + "arrow.png"
		ammo_texture.atlas = load(ammo_path)
		ammo_texture.region = Rect2(0, 0, 5, 26)
		ammo_viewport.size = ammo_texture.region.size


func _process(delta: float) -> void:
	
	if !visible or (plugin_enabled and !get_parent().visible) or busy: return
	
	if refresh_visibility_timer > 0:
		refresh_visibility_timer -= delta
		if refresh_visibility_timer <= 0.0:
			refresh_visibility_timer = 0.0
			fix_item_visibility()
	
	if (Engine.is_editor_hint() and !plugin_enabled) and !debug_draw: return
	
	if Engine.is_editor_hint():
		if debug_draw_timer <= 0.0:
			if debug_draw:
				%Races.item_selected.emit(%Races.get_selected())
			debug_draw_timer = 0.1
		elif debug_draw_timer > 0.0:
			debug_draw_timer -= delta
			
	if can_action and !debug:
		if Input.is_key_pressed(KEY_UP):
			current_direction = "up"
			if current_animation != "walk": set_current_animation("walk")
			get_viewport().set_input_as_handled()
		elif Input.is_key_pressed(KEY_DOWN):
			current_direction = "down"
			if current_animation != "walk": set_current_animation("walk")
			get_viewport().set_input_as_handled()
		elif Input.is_key_pressed(KEY_LEFT):
			current_direction = "left"
			if current_animation != "walk": set_current_animation("walk")
			get_viewport().set_input_as_handled()
		elif Input.is_key_pressed(KEY_RIGHT):
			current_direction = "right"
			if current_animation != "walk": set_current_animation("walk")
			get_viewport().set_input_as_handled()
		elif Input.is_key_pressed(KEY_5):
			play_animation("cast")
		elif Input.is_key_pressed(KEY_1):
			play_animation("slash")
		elif Input.is_key_pressed(KEY_2):
			play_animation("islash")
		elif Input.is_key_pressed(KEY_3):
			play_animation("thrust")
		elif Input.is_key_pressed(KEY_4):
			play_animation("smash")
		elif Input.is_key_pressed(KEY_5):
			play_animation("shoot")
		elif Input.is_key_pressed(KEY_SPACE):
			var ani: String
			if current_character.mainhand.item and "actions" in current_character.mainhand.item:
				var id = randi() % current_character.mainhand.item.actions.size()
				ani = current_character.mainhand.item.actions[id]
			else:
				ani = ["slash", "islash"][randi() % 2]
			play_animation(ani)
		else:
			if current_animation != "idle": set_current_animation("idle")
	
	if Input.is_key_pressed(KEY_N):
		next_frame.emit()

	update_animation(delta)
	
	if palette_dialog_need_refresh != null:
		if %PaletteDialog.visible:
			palette_dialog_need_refresh.get_parent().get_child(2).pressed.emit()
		palette_dialog_need_refresh = null
		palette_dialog_refresh.emit()


func play_animation(ani: String) -> void:
	%FinalCharacter.set_shader_parameter("enable_breathing", self.current_animation == "idle")
	can_action = false
	set_current_animation(ani)
	current_animation_frame = 0
	next_frame_delay = 0
	
	if current_character.mainhand.item and "sounds" in current_character.mainhand.item:
		var id = randi() % current_character.mainhand.item.sounds.size()
		var fx = current_character.mainhand.item.sounds[id]
		var default_path = "res://addons/rpg_character_creator/"
		var sound_path = default_path.path_join(fx)
		%FXPlayer.stream = load(sound_path)
		%FXPlayer.play()
	
	if current_character.ammo.item:
		%AmmoBack.visible = true
		%AmmoFront.visible = true
	else:
		%AmmoBack.visible = false
		%AmmoFront.visible = false

	get_viewport().set_input_as_handled()


func set_current_animation(animation_id: String) -> void:
	current_animation = animation_id
	
	var id1: String
	var id2: String = "char_walk"
	if animation_id != "idle":
		id1 = "char_large_" + animation_id
	else:
		id1 = "char_large_walk"
	var base: Dictionary = {}
	var large: Dictionary = {}

	weapon_walking_mode = false

	if animation_id == "fish_throw":
		for obj in current_character.mainhand.textures:
			if obj.id == "char_large_fish":
				large = {"front": obj.front, "back": obj.back}
				break
	else:
		for obj in current_character.mainhand.textures:
			if obj.id == "char_base" or obj.id == "":
				base = {"front": obj.front, "back": obj.back}
			elif obj.id == id1:
				large = {"front": obj.front, "back": obj.back}
				break
			elif obj.id == id2:
				weapon_walking_mode = true
				base = {"front": obj.front, "back": obj.back}
			

	if large and (large.front or large.back):
		%MainhandBackTexture.texture = large.back
		%MainhandFrontTexture.texture = large.front
		%WeaponBack.texture.region.size = Vector2(192, 192)
		%WeaponFront.texture.region.size = Vector2(192, 192)
		%AmmoBack.texture.region.size = Vector2(64, 64)
		%AmmoFront.texture.region.size = Vector2(64, 64)
		weapon_large_shown = true
	elif base and (base.front or base.back):
		%MainhandBackTexture.texture = base.back
		%MainhandFrontTexture.texture = base.front
		%WeaponBack.texture.region.size = Vector2(64, 64)
		%WeaponFront.texture.region.size = Vector2(64, 64)
		%AmmoBack.texture.region.size = Vector2(64, 64)
		%AmmoFront.texture.region.size = Vector2(64, 64)
		weapon_large_shown = false
	else:
		%MainhandBackTexture.texture = null
		%MainhandFrontTexture.texture = null
		%WeaponBack.texture.region.size = Vector2(64, 64)
		%WeaponFront.texture.region.size = Vector2(64, 64)
		%AmmoBack.texture.region.size = Vector2(64, 64)
		%AmmoFront.texture.region.size = Vector2(64, 64)
		weapon_large_shown = false
	
	if %MainhandBackTexture.texture:
		%MainhandBackTexture.get_parent().size = %MainhandBackTexture.texture.get_size()
		%MainhandBackTexture.size = %MainhandBackTexture.get_parent().size
		%AmmoBack.size = %MainhandBackTexture.get_parent().size
	if %MainhandFrontTexture.texture:
		%MainhandFrontTexture.get_parent().size = %MainhandFrontTexture.texture.get_size()
		%MainhandFrontTexture.size = %MainhandFrontTexture.get_parent().size
		%AmmoFront.size = %MainhandBackTexture.get_parent().size
	
	for item in [%WeaponBack, %WeaponFront, %AmmoBack, %AmmoFront]:
		var s = item.texture.region.size.x
		if s == 192:
			pass
		var p = 0 if s == 64 else -64
		item.position.x = p
		item.position.y = p
		item.position.x = p
		item.position.y = p # Double check, there are any bug here
		item.custom_minimum_size = Vector2(s, s)
		item.size = item.custom_minimum_size
		item.pivot_offset = Vector2(s/2, s/2)


func get_current_weapon_animation(animation_id: String) -> Dictionary:
	var animation = {}
	
	if !weapon_large_shown and !weapon_walking_mode: return animation
	
	if !weapon_walking_mode or weapon_large_shown:
		for ani in weapon_animations_data.animations:
			if ani.id == animation_id:
				return ani
	else:
		var is_idle = animation_id.find("idle") != -1
		var is_walking = animation_id.find("walk") != -1
		for ani in weapon_animations_data.animations:
			if is_walking:
				if ani.id == "small_walk_" + current_direction:
					return ani
			elif is_idle:
				if ani.id == "small_idle_" + current_direction:
					return ani
			
	return animation


func update_animation(delta: float) -> void:
	if debug: return
	if next_frame_delay > 0.0:
		next_frame_delay -= delta
	elif player_animations_data:
		var animation_id = current_animation + "_" + current_direction
		if animation_id.begins_with("fish_throw_"):
			animation_id = "fish_full_animation_" + current_direction

		var ani = {}
		for animation in player_animations_data.animations:
			if animation.id == animation_id:
				ani = animation
				break
		if ani:
			var max_frames = ani.frames.size()
			if current_animation_frame >= max_frames:
				if !ani.loop:
					set_current_animation("idle")
					animation_finished.emit()
					update_animation(delta)
					return
					
				current_animation_frame = 0

			var node = %CurrentCharacter
			node.texture.region.position.x = ani.frames[current_animation_frame][0]
			node.texture.region.position.y = ani.frames[current_animation_frame][1]
			node = %OffhandBack
			node.texture.region.position.x = ani.frames[current_animation_frame][0]
			node.texture.region.position.y = ani.frames[current_animation_frame][1]
			node = %OffhandFront
			node.texture.region.position.x = ani.frames[current_animation_frame][0]
			node.texture.region.position.y = ani.frames[current_animation_frame][1]
			node = %AmmoBack
			node.texture.region.position.x = ani.frames[current_animation_frame][0]
			node.texture.region.position.y = ani.frames[current_animation_frame][1]
			node = %AmmoFront
			node.texture.region.position.x = ani.frames[current_animation_frame][0]
			node.texture.region.position.y = ani.frames[current_animation_frame][1]
			
			var weapon_animation = get_current_weapon_animation(animation_id)
			#if weapon_animation: prints(animation_id, weapon_animation)
			if weapon_animation:
				if weapon_animation.frames.size() > current_animation_frame:
					var ani2 = weapon_animation.frames[current_animation_frame]
					%WeaponBack.texture.region.position.x = ani2[0]
					%WeaponBack.texture.region.position.y = ani2[1]
					%WeaponFront.texture.region.position.x = ani2[0]
					%WeaponFront.texture.region.position.y = ani2[1]
				#debug = true
				#await next_frame
				#debug = false
			else:
				#prints(animation_id)
				%WeaponBack.texture.region.position.x = ani.frames[current_animation_frame][0]
				%WeaponBack.texture.region.position.y = ani.frames[current_animation_frame][1]
				%WeaponFront.texture.region.position.x = ani.frames[current_animation_frame][0]
				%WeaponFront.texture.region.position.y = ani.frames[current_animation_frame][1]
			
			
			next_frame_delay = frame_duration
			
			if "action_frame" in ani and ani.action_frame == current_animation_frame:
				play_proyectil_animation()
				
			current_animation_frame += 1
	
	%CurrentCharacter.get_material().set_shader_parameter("enabled", current_animation == "idle")


func play_proyectil_animation() -> void:
	var current_ammo = current_character.ammo.item
	
	if !"projectile" in current_ammo: return
	
	%AmmoBack.visible = false
	%AmmoFront.visible = false
	
	var path = "res://addons/rpg_character_creator/textures/projectiles/%s.tscn" % current_ammo.projectile
	if !ResourceLoader.exists(path): return
	
	var scn = load(path).instantiate()
	scn.set_material(%AmmoBackTexture.get_material().duplicate())
	scn.scale = %FinalCharacter.scale
	if current_direction == "up":
		%ProyectilesBack.add_child(scn)
	else:
		%Proyectiles.add_child(scn)
	
	scn.global_position = %ProyectileTop.global_position

	var x = 32 * %FinalCharacter.scale.x
	var y = 32 * %FinalCharacter.scale.y
	if current_ammo.name == "Bolt":
		if current_direction == "down":
			x += -6 * %FinalCharacter.scale.x
		elif current_direction == "left" or current_direction == "right":
			y += 12 * %FinalCharacter.scale.x
		elif current_direction == "up":
			x += 6 * %FinalCharacter.scale.x
	scn.global_position += Vector2(x, y)
	
	scn.set_direction(current_direction)
	
	if "sounds" in current_ammo:
		var id = randi() % current_ammo.sounds.size()
		var fx = current_ammo.sounds[id]
		var default_path = "res://addons/rpg_character_creator/"
		var sound_path = default_path.path_join(fx)
		%FXPlayer.stream = load(sound_path)
		%FXPlayer.play()


#region set data
func set_options_and_palette_buttons_connection(node: Node) -> void:
	if node.name == "PaletteButton":
		node.pressed.connect(_on_palette_button_pressed.bind(node))
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif node is OptionButton:
		if node.gui_input.is_connected(_on_option_buttons_gui_input):
			node.gui_input.disconnect(_on_option_buttons_gui_input)
		node.gui_input.connect(_on_option_buttons_gui_input.bind(node))
	
	for child in node.get_children():
		set_options_and_palette_buttons_connection(child)


func _on_option_buttons_gui_input(event: InputEvent, button: OptionButton) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var index: int = -1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			index = wrapi(button.get_selected_id() + 1, 0, button.get_item_count() - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			index = wrapi(button.get_selected_id() - 1, 0, button.get_item_count() - 1)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if button.get_item_count() > 0:
				index = 0
		if index != -1:
			button.select(index)
			button.item_selected.emit(index)


func clear_all():
	# Options
	var options = [%Races, %Palettes, %Gender, %Body, %Wings, %Tail, %Horns, %Hair, %Hairadd, %Eyes, %Ears, %Nose, %Facial, %Add1, %Add2, %Add3, %Mask, %Hat, %Glasses, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants, %Shoes, %Back, %Mainhand, %Ammo, %Offhand]
	for option in options:
		option.clear()
	# textures
	var textures = [%BodyTexture, %HairTexture, %HeadTexture, %EyesTexture]
	for texture in textures:
		texture.texture = null


func clear_body_parts() -> void:
	var options = [%Wings, %Tail, %Horns, %Hair, %Hairadd, %Eyes, %Ears, %Nose, %Facial, %Add1, %Add2, %Add3]
	var bak_current_node_editting_colors = current_node_editting_colors
	for option in options:
		option.select(0)
		option.item_selected.emit(0)
	current_node_editting_colors = bak_current_node_editting_colors
	clear_palette_dialog(options)


func clear_gear_parts() -> void:
	var options = [%Mask, %Hat, %Glasses, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants, %Shoes, %Back, %Mainhand, %Ammo, %Offhand]
	var bak_current_node_editting_colors = current_node_editting_colors
	for option in options:
		option.select(0)
		option.item_selected.emit(0)
	
	current_node_editting_colors = bak_current_node_editting_colors
	clear_palette_dialog(options)


func clear_palette_dialog(options: Array) -> void:
	var current_item = current_node_editting_colors
	await palette_dialog_refresh
	var palette_dialog_is_valid = true
	var current_palette_button = null
	for option in options:
		var parent = option.get_parent()
		if parent.get_child_count() >= 3:
			var item_name = parent.get_child(0).text.rstrip(":")
			if current_item == item_name:
				var node = parent.get_child(2)
				if node.name == "PaletteButton":
					palette_dialog_is_valid = !node.is_disabled()
					current_palette_button = node
					break

	if !palette_dialog_is_valid:
		%PaletteDialog.clear()
		%PaletteDialog.title = TranslationManager.tr("Select a gear part to edit its colors")
	elif current_palette_button:
		_on_palette_button_pressed(current_palette_button)


func get_palette_struct() -> Dictionary:
	var obj = {
		"palette1" : {
			"item_selected": 0,
			"lightness": 0.0,
			"current_gradient": [],
			"custom_colors": {}
		},
		"palette2" : {
			"item_selected": 0,
			"lightness": 0.0,
			"current_gradient": [],
			"custom_colors": {}
		},
		"palette3" : {
			"item_selected": 0,
			"lightness": 0.0,
			"current_gradient": [],
			"custom_colors": {}
		},
	}
	
	return obj


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


func set_animations() -> void:
	player_animations_data = RPGSYSTEM.player_animations_data
	weapon_animations_data = RPGSYSTEM.weapon_animations_data


func set_characters_data() -> void:
	data.characters = {}
	var keys = ["add1", "add2", "add3", "body", "ears", "eyes", "facial", "horns", "hair", "hairadd", "head", "nose", "race", "shadow", "shadow", "tail", "wings"]
	for key in keys:
		var path = "res://addons/rpg_character_creator/Data/character/%s" % key + "/"
		var files = get_files(path, [])
		data.characters[key] = []
		for file in files:
			var f = FileAccess.open(file, FileAccess.READ)
			var json = f.get_as_text()
			f.close()
			data.characters[key].append(JSON.parse_string(json))


func set_gear_data() -> void:
	data.gear = {}
	var keys = ["ammo", "back", "belt", "glasses", "gloves", "hat", "jacket", "mainhand", "mask", "offhand", "pants", "shirt", "shoes", "suit"]
	for key in keys:
		var path = "res://addons/rpg_character_creator/Data/gear/%s" % key
		var files = get_files(path, [])
		data.gear[key] = []
		for file in files:
			var f = FileAccess.open(file, FileAccess.READ)
			var json = f.get_as_text()
			f.close()
			var data_id = file.get_basename().get_file()
			var gear = JSON.parse_string(json)
			gear.config_path = file
			data.gear[key].append(gear)


func set_colormap_data() -> void:
	data.colormaps = {}
	var path = "res://addons/rpg_character_creator/Data/ColorMaps/"
	var files = get_files(path, ["cm"])
	for file in files:
		var f = FileAccess.open(file, FileAccess.READ)
		var json = f.get_as_text()
		f.close()
		json = JSON.parse_string(json)
		var data_id = json.name
		data.colormaps[data_id] = json


func set_credits_data() -> void:
	data.credits = {}
	var path = "res://addons/rpg_character_creator/Data/credits/"
	var files = get_files(path, ["credits"])
	for file in files:
		var f = FileAccess.open(file, FileAccess.READ)
		var json = f.get_as_text()
		f.close()
		var data_id = file.get_basename().get_file()
		data.credits[data_id] = JSON.parse_string(json)


func set_character_item(id: String) -> void:
	var current_body = get_current_config()
	current_character[id].item = null
	for obj in data.characters[id]:
		if obj.id.to_lower() == str(current_character[id].selected_index).to_lower():
			current_character[id].item = obj
			break
		elif obj.id.to_lower() == "none" and current_character[id].item == null:
			current_character[id].item = obj

#endregion


#region fill data
func sort_by_name(a: Dictionary, b: Dictionary) -> bool:
	if a and b and "name" in a and "name" in b:
		return a.name < b.name
	else:
		return false


func get_current_config() -> Dictionary:
	var current_config: Dictionary
	if current_character.race and current_character.gender and current_character.body.selected_index:
		for config in current_character.race.configs:
			if current_character.gender == config.gender and config.name == current_character.body.selected_index:
				current_config = config
				break
	
	return current_config


func get_color(color_id: String) -> Dictionary:
	var current_colors: Dictionary
	var colormap_id = current_character.palette
	
	for item in data.colormaps[colormap_id].items:
		if item.id == color_id:
			current_colors = item
			break
	
	return current_colors.duplicate()


func get_gradient(current_data_color: Dictionary) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray([])
	colors.resize(256)
	
	if current_data_color.colors.size() > 0:
		for i in range(0, current_data_color.colors.size(), 2):
			var index = int(current_data_color.colors[i])
			var color = Color(int(current_data_color.colors[i+1]))
			colors[index] = color
		
	return colors


func update_all_palettes() -> void:
	var objs = [
		[current_character.body, %BodyTexture],
		[current_character.eyes, %EyesTexture],
		[current_character.wings, %WingsTextureFront],
		[current_character.tail, %TailTexture],
		[current_character.horns, %HornsTexture],
		[current_character.hair, %HairTexture],
		[current_character.hairadd, %HairAddTexture],
		[current_character.facial, %FacialTexture],
		[current_character.add1, %Add1Texture],
		[current_character.add2, %Add2Texture],
		[current_character.add3, %Add3Texture],
		[current_character.mask, %MaskTexture],
		[current_character.hat, %HatTexture],
		[current_character.glasses, %GlassesTexture],
		[current_character.suit, %SuitTexture],
		[current_character.shirt, %ShirtTexture],
		[current_character.jacket, %JacketTexture],
		[current_character.gloves, %GlovesTexture],
		[current_character.belt, %BeltTexture],
		[current_character.pants, %PantsTexture],
		[current_character.shoes, %ShoesTexture],
		[current_character.back, %BackTexture1],
		[current_character.mainhand, %MainhandBackTexture],
		[current_character.ammo, %AmmoBackTexture],
		[current_character.offhand, %OffhandBackTexture]
	]
	for obj in objs:
		update_palettes(obj[0], obj[1], null)
	

func update_palettes(current_item: Dictionary, target: TextureRect, caller = null, real_item = null) -> void:
	var item = current_item.item
	if real_item:
		current_item = real_item
	if !item: return
	var palettes_found = 0
	
	var data1: bool = false
	var data2: bool = false
	var data3: bool = false
	
	if item.has("primarycolors"):
		palettes_found += 1
		var index = min(item["primarycolors"].size() - 1, current_item.palettes.palette1.item_selected)
		current_item.palettes.palette1.item_selected = index
		var current_colors = get_color(item["primarycolors"][index])
		current_item.palettes.palette1.custom_colors = current_colors
		data1 = true
		if caller and caller.get_parent().get_child_count() >= 3:
			var color_node = caller.get_parent().get_child(2)
			if color_node.name == "PaletteButton":
				var colors = []
				for color in item["primarycolors"]:
					colors.append(get_color(color))
				color_node.set_meta("primarycolors", {"data": colors, "palette": current_item.palettes.palette1, "target": target})
				var gradient_index = current_item.palettes.palette1.item_selected
				if colors.size() <= gradient_index:
					gradient_index = 0
				var current_gradient = get_gradient(colors[gradient_index])
				current_item.palettes.palette1.current_gradient = current_gradient
	else:
		current_item.palettes.palette1.item_selected = 0
		if caller and caller.get_parent().get_child_count() >= 3:
			var color_node = caller.get_parent().get_child(2)
			if color_node.name == "PaletteButton":
				color_node.set_meta("primarycolors", -1)
		
	if item.has("secondarycolors"):
		palettes_found += 1
		var index = min(item["secondarycolors"].size() - 1, current_item.palettes.palette2.item_selected)
		current_item.palettes.palette2.item_selected = index
		var current_colors = get_color(item["secondarycolors"][index])
		current_item.palettes.palette2.custom_colors = current_colors
		data2 = true
		if caller and caller.get_parent().get_child_count() >= 3:
			var color_node = caller.get_parent().get_child(2)
			if color_node.name == "PaletteButton":
				var colors = []
				for color in item["secondarycolors"]:
					colors.append(get_color(color))
				color_node.set_meta("secondarycolors", {"data": colors, "palette": current_item.palettes.palette2, "target": target})
				var gradient_index = current_item.palettes.palette2.item_selected
				if colors.size() <= gradient_index:
					gradient_index = 0
				var current_gradient = get_gradient(colors[gradient_index])
				current_item.palettes.palette2.current_gradient = current_gradient
				
	else:
		current_item.palettes.palette2.item_selected = 0
		if caller and caller.get_parent().get_child_count() >= 3:
			var color_node = caller.get_parent().get_child(2)
			if color_node.name == "PaletteButton":
				color_node.set_meta("secondarycolors", -1)
	
	if item.has("fixedcolors"):
		palettes_found += 1
		var index = min(item["fixedcolors"].size() - 1, current_item.palettes.palette3.item_selected)
		current_item.palettes.palette3.item_selected = index
		var current_colors = get_color(item["fixedcolors"][index])
		current_item.palettes.palette3.custom_colors = current_colors
		data3 = true
		if caller and caller.get_parent().get_child_count() >= 3:
			var color_node = caller.get_parent().get_child(2)
			if color_node.name == "PaletteButton":
				var colors = []
				for color in item["fixedcolors"]:
					colors.append(get_color(color))
				color_node.set_meta("fixedcolors", {"data": colors, "palette": current_item.palettes.palette3, "target": target})
				var gradient_index = current_item.palettes.palette3.item_selected
				if colors.size() <= gradient_index:
					gradient_index = 0
				var current_gradient = get_gradient(colors[gradient_index])
				current_item.palettes.palette3.current_gradient = current_gradient
				
	else:
		current_item.palettes.palette3.item_selected = 0
		if caller and caller.get_parent().get_child_count() >= 3:
			var color_node = caller.get_parent().get_child(2)
			if color_node.name == "PaletteButton":
				color_node.set_meta("fixedcolors", -1)
	
	if palettes_found == 0:
		for i in range(1, 4):
			var palette_id = "palette%s" % i
			current_item.palettes.palette3.current_gradient = []

	for i in range(1, 4):
		var id = "palette%s" % i
		_on_update_palette_requested(i, target, current_item.palettes[id])
	
	if !data1 and !data2 and !data3:
		current_item.palettes.palette1.custom_colors = {}
		current_item.palettes.palette2.custom_colors = {}
		current_item.palettes.palette3.custom_colors = {}
		if caller:
			var node1 = caller.get_parent().get_child(2)
			if node1.name == "PaletteButton":
				node1.set_disabled(true)
				node1.mouse_filter = Control.MOUSE_FILTER_IGNORE
				node1.modulate.a = 0.4
		
		if %PaletteDialog.visible:
			%PaletteDialog.clear()
			%PaletteDialog.title = TranslationManager.tr("Select a gear part to edit its colors")
	else:
		if caller:
			var node1 = caller.get_parent().get_child(2)
			if node1.name == "PaletteButton":
				node1.set_disabled(false)
				node1.mouse_filter = Control.MOUSE_FILTER_STOP
				node1.modulate.a = 1.0


func _on_update_palette_requested(index: int, target: TextureRect, palette: Dictionary) -> void:
	if target:
		var id = "palette%s" % index
		var param_name = "palette%s_main_color" % index
		param_name = "palette%s" % index
		target.material.set_shader_parameter(param_name, palette.current_gradient)
		param_name = "lightness%s" % index
		target.material.set_shader_parameter(param_name, palette.lightness)


func fill_races_and_paletes() -> void:
	var node = %Palettes
	node.clear()
	for item in data.colormaps.values():
		node.add_item(item.name)
		node.set_item_metadata(-1, item)
	if data.colormaps.values().size() > 0:
		node.select(0)
		node.item_selected.emit(0)
		
	node = %Races
	node.clear()
	for item in data.characters.race:
		
		node.add_item(item.name)
		node.set_item_metadata(-1, item)
		if item.name == "Human":
			var index = node.get_item_count() - 1
			node.select(index)
			node.item_selected.emit(index)


func fill_genders() -> void:
	var current_item_name: String = ""
	var node = %Gender
	var current_selected_id = node.get_selected_id()
	if current_selected_id != -1:
		current_item_name = node.get_item_text(current_selected_id)
	else:
		current_item_name = "male"
	node.clear()
	
	if current_character.race:
		var obj = current_character.race
		var genders: Array = []
		for config in obj.configs:
			if !genders.has(config.gender):
				genders.append(config.gender)
		
		if genders.size() > 0:
			genders.sort()
			var selected_id = 0
			for gender in genders:
				node.add_item(gender)
				if gender == current_item_name:
					selected_id = node.get_item_count() - 1
					
			node.select(selected_id)
			node.item_selected.emit(selected_id)
			node.set_disabled(node.get_item_count() <= 1 and node.get_item_text(0).to_lower() != "none")


func fill_bodies() -> void:
	var current_item_name: String = ""
	var node = %Body
	var current_selected_id = node.get_selected_id()
	if current_selected_id != -1:
		current_item_name = node.get_item_text(current_selected_id)
	else:
		current_item_name = "Regular"
	node.clear()
	
	if current_character.race and current_character.gender:
		var configs: Array = []
		for config in current_character.race.configs:
			if config.gender == current_character.gender:
				configs.append(config)
		
		if configs.size() > 0:
			var selected_id = 0
			
			var names: Array = []
			for config in configs:
				names.append(config.name)
			names.sort()
			
			for i in names.size():
				var item = names[i]
				node.add_item(item)
				if item == current_item_name:
					selected_id = i

			node.select(selected_id)
			node.item_selected.emit(selected_id)
			node.set_disabled(node.get_item_count() <= 1 and node.get_item_text(0).to_lower() != "none")


func fill_eyes() -> void:
	var current_item_id: Dictionary = {}
	var node = %Eyes
	var current_selected_id = node.get_selected_id()
	if current_selected_id != -1:
		current_item_id = node.get_item_metadata(current_selected_id)
	node.clear()
	
	var current_body = get_current_config()
	
	var eyes = current_body.eyes.duplicate()
	#eyes.sort()
	
	var selected_id = 0
	for i in eyes.size():
		var item = eyes[i]
		for file in data.characters.eyes:
			if file.id == item:
				node.add_item(file.name)
				if file == current_item_id:
					selected_id = i
				node.set_item_metadata(node.get_item_count() - 1, file)
				break
	
	node.select(selected_id)
	node.item_selected.emit(selected_id)
	node.set_disabled(eyes.size() <= 1 and node.get_item_text(0).to_lower() != "none")


func update_skin_color() -> void:
	# Set skin color:
	var palette_selected_name: String = str(current_character.palette)
	var current_data_color: Dictionary
	for item in data.colormaps.values():
		if item.name == palette_selected_name:
			current_data_color = item
			break


func fill_body_parts(ids: Array = ["wings", "tail", "horns", "hair", "hairadd", "ears", "nose", "facial", "add1", "add2", "add3"]) -> void:
	var parts = []
	for id in ids:
		var node_path = "%" + id.to_pascal_case()
		var node = get_node(node_path)
		var current_selected_id = node.get_selected_id()
		if current_selected_id != -1:
			parts.append(node.get_item_metadata(current_selected_id))
		else:
			parts.append({})
		node.clear()
	
	var current_config: Dictionary = get_current_config()
	
	if current_config:
		for i in ids.size():
			var id = ids[i]
			var node_path = "%" + id.to_pascal_case()
			var node = get_node(node_path)
			node.clear()
			
			if id == "hair":
				current_character.hair.alt_item = null
			
			if current_config.has(id):
				var selected_id = 0
				for item in current_config[id]:
					for file in data.characters[id]:
						if file.id == item:
							node.add_item(file.name)
							if parts[i] == file:
								selected_id = node.get_item_count() - 1
							node.set_item_metadata(node.get_item_count() - 1, file)
							if id == "hair":
								if "alt" in file and file.alt != "none":
									for other_file in data.characters[id]:
										if other_file.id == file.alt:
											current_character.hair.alt_item = other_file
											break
							break
				
					node.select(selected_id)
					node.item_selected.emit(selected_id)
					node.set_disabled(current_config[id].size() <= 1 and node.get_item_text(0).to_lower() != "none")
			else:
				node.add_item("none")
				node.set_item_metadata(node.get_item_count() - 1, {"textures": []})
				node.item_selected.emit(0)
				node.set_disabled(true)


func fill_gear_parts() -> void:
	var ids = ["back", "belt", "glasses", "gloves", "hat", "jacket", "mask", "pants", "shirt", "shoes", "suit"]
	var parts = []
	for id in ids:
		var node_path = "%" + id.to_pascal_case()
		var node = get_node(node_path)
		var current_selected_id = node.get_selected_id()
		if current_selected_id != -1:
			parts.append(node.get_item_metadata(current_selected_id))
		else:
			parts.append({})
			
		node.clear()
		node.add_item("none")
		node.set_item_metadata(node.get_item_count() - 1, {"textures": []})

	var current_config: Dictionary = get_current_config()
	
	if current_config:
		for i in ids.size():
			var id = ids[i]
			var node_path = "%" + id.to_pascal_case()
			var node = get_node(node_path)
			
			var selected_id = 0
			
			if data.gear.has(id):
				for j in data.gear[id].size():
					var item = data.gear[id][j]
					for texture in item.textures:
						if (
							(("body" in texture and texture.body == current_config["body-type"]) or
							("head" in texture and texture.head == current_config["head-type"])) and
							(current_config["gender"] in item.tags or "generic" in item.tags or "armor" in item.tags or "medieval" in item.tags or "pirate" in item.tags or "victorian" in item.tags or "magic" in item.tags)
						):
							node.add_item(item.name)
							if parts[i] == item or ("default" in item and item.default and selected_id == 0):
								selected_id = node.get_item_count() - 1
							node.set_item_metadata(node.get_item_count() - 1, item)
							break

				node.select(selected_id)
				node.item_selected.emit(selected_id)
			else:
				node.item_selected.emit(0)
				node.set_disabled(true)
			
			node.set_disabled(node.get_item_count() <= 1 and node.get_item_text(0).to_lower() != "none")


func fill_mainhand() -> void:
	var id = "mainhand"
	var node_path = "%" + id.to_pascal_case()
	var node = get_node(node_path)
	var current_selected_id
	var index = node.get_selected_id()
	if index != -1:
		current_selected_id = node.get_item_metadata(index)
	else:
		current_selected_id = {}
	
	node.clear()
	node.add_item("none")
	node.select(0)
	node.set_item_metadata(node.get_item_count() - 1, {"textures": []})
	
	var current_config: Dictionary = get_current_config()
	
	if current_config:
		var selected_id = 0
		for i in data.gear.mainhand.size():
			var item = data.gear.mainhand[i]
			for texture in item.textures:
				if (
					("body" in texture and texture.body == current_config["body-type"]) or
					("head" in texture and texture.head == current_config["head-type"])
				):
					node.add_item(item.name)
					if current_selected_id == item:
						selected_id = node.get_item_count() - 1
					node.set_item_metadata(node.get_item_count() - 1, item)
					break
		
		node.select(selected_id)
		node.item_selected.emit(selected_id)
	
	node.set_disabled(node.get_item_count() <= 1 and node.get_item_text(0).to_lower() != "none")


func fill_ammo() -> void:
	var id = "ammo"
	var node_path = "%" + id.to_pascal_case()
	var node = get_node(node_path)
	
	var current_selected_id
	var index = node.get_selected_id()
	if index != -1:
		current_selected_id = node.get_item_metadata(index)
	else:
		current_selected_id = {}
	
	node.clear()
	
	var selected_id = 0
	if current_character.mainhand.item and "ammo" in current_character.mainhand.item:
		var current_config: Dictionary = get_current_config()
		if current_config:
			for i in data.gear.ammo.size():
				var item = data.gear.ammo[i]
				if "projectile" in item and item.projectile in current_character.mainhand.item.ammo:
					for texture in item.textures:
						if (
							("body" in texture and texture.body == current_config["body-type"]) or
							("head" in texture and texture.head == current_config["head-type"])
						):
							node.add_item(item.name)
							if current_selected_id == item:
								selected_id = node.get_item_count() - 1
							node.set_item_metadata(node.get_item_count() - 1, item)
							break
	
	if node.get_item_count() == 0:
		node.add_item("none")
		node.set_item_metadata(node.get_item_count() - 1, {"textures": []})
	
	node.select(selected_id)
	node.item_selected.emit(selected_id)
	
	node.set_disabled(node.get_item_count() <= 1 and node.get_item_text(0).to_lower() != "none")


func fill_offhand() -> void:
	var id = "offhand"
	var node_path = "%" + id.to_pascal_case()
	var node = get_node(node_path)
	
	var current_selected_id
	var index = node.get_selected_id()
	if index != -1:
		current_selected_id = node.get_item_metadata(index)
	else:
		current_selected_id = {}
	
	node.clear()
	node.add_item("none")
	node.select(0)
	node.set_item_metadata(node.get_item_count() - 1, {"textures": []})
	
	var current_config: Dictionary = get_current_config()
	
	if current_config:
		var selected_id = 0
		for i in data.gear.offhand.size():
			var item = data.gear.offhand[i]
			for texture in item.textures:
				if (
					("body" in texture and texture.body == current_config["body-type"]) or
					("head" in texture and texture.head == current_config["head-type"])
				):
					node.add_item(item.name)
					if current_selected_id == item:
						selected_id = node.get_item_count() - 1
					node.set_item_metadata(node.get_item_count() - 1, item)
					break
		
		node.select(selected_id)
		node.item_selected.emit(selected_id)
	
	node.set_disabled(node.get_item_count() <= 1 and node.get_item_text(0).to_lower() != "none")


#endregion


func _on_palette_button_pressed(node: Node) -> void:
	var data1 = node.get_meta("primarycolors")
	var data2 = node.get_meta("secondarycolors")
	var data3 = node.get_meta("fixedcolors")
	
	if !data1 is Dictionary and !data2 is Dictionary and !data3 is Dictionary:
		return

	var node1 = node.get_parent().get_child(0)
	var node2 = node.get_parent().get_child(1)
	current_node_editting_colors = node1.text.rstrip(":")
	var title = TranslationManager.tr("Set Colors For ") + node1.text + " " + node2.get_item_text(node2.get_selected_id())
	%PaletteDialog.title = title
	%PaletteDialog.set_data(data1, data2, data3)
	if !paletted_dialog_first_opened:
		var p = Vector2i(get_parent().position)
		var s = get_parent().size
		var s2 = %PaletteDialog.size
		%PaletteDialog.position = p + Vector2i(s.x / 2, s.y) - Vector2i(s2.x / 2, -40)
		#Vector2(s.x / 2, s.y) - Vector2(%PaletteDialog.size.x / 2, %PaletteDialog.size.y + 80)
		paletted_dialog_first_opened = true
	%PaletteDialog.visible = true
	DisplayServer.window_move_to_foreground(%PaletteDialog.get_window_id())
	#%PaletteDialog.grab_focus()


func _on_character_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				var z: float = min(%FinalCharacter.scale.x + 0.2, 7)
				%FinalCharacter.scale = Vector2(z, z)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var z: float = max(%FinalCharacter.scale.x - 0.2, 1)
				%FinalCharacter.scale = Vector2(z, z)


#region on selected items
func _on_palettes_item_selected(index: int) -> void:
	current_character.palette = %Palettes.get_item_text(index)
	var current_body = get_current_config()
	if current_body:
		%Body.item_selected.emit(%Body.get_selected_id())
		
	%PaletteDialog.fill_colors(data.colormaps[current_character.palette].items)


func _on_races_item_selected(index: int) -> void:
	var race = %Races.get_item_metadata(index)
	current_character.race = race
	

	# set current body
	for body in data.characters.body:
		if body.id.to_lower() == race.name.to_lower():
			current_character.body.item = body
			break
		elif body.name.to_lower() == "human" and current_character.body.item == null:
			current_character.body.item = body
	
	reset_body_palettes()
	update_palettes(current_character.body, %BodyTexture, %Body)
	
	
	# set current head
	var current_config = race.configs[0]
	current_character.head.item = null
	for head in data.characters.head:
		if head.id == current_config.head[0]:
		#if head.name.to_lower() == race.name.to_lower():
			current_character.head.item = head
			break
		elif head.name.to_lower() == "human" and current_character.head.item == null:
			current_character.head.item = head

	fill_genders()


# ------------------------------------------------------------------------------
# BODY
# ------------------------------------------------------------------------------


func reset_body_palettes() -> void:
	var parts = ["body", "wings", "tail", "horns", "hair", "hairadd", "facial", "add1", "add2", "add3"]
	for id in parts:
		current_character[id].palettes.palette1.item_selected = 0
		current_character[id].palettes.palette2.item_selected = 0
		current_character[id].palettes.palette3.item_selected = 0


func _on_gender_item_selected(index: int) -> void:
	current_character.gender = %Gender.get_item_text(index)
	fill_bodies()


func _on_body_item_selected(index: int) -> void:
	var caller = %Body
	current_character.body.selected_index = caller.get_item_text(index)
	fill_eyes()
	fill_body_parts()
	fill_gear_parts()
	fill_mainhand()
	palette_dialog_need_refresh = caller


func _on_eyes_item_selected(index: int) -> void:
	var caller = %Eyes
	current_character.eyes.item = caller.get_item_metadata(index)
	
	update_palettes(current_character.eyes, %EyesTexture, caller)
	draw_head_and_body_and_eyes()
	palette_dialog_need_refresh = caller


func _on_horns_item_selected(index: int) -> void:
	var caller = %Horns
	current_character.horns.item = caller.get_item_metadata(index)
	
	update_palettes(current_character.horns, %HornsTexture, caller)
	draw_body_part("horns", %HornsTexture, null, "horns")
	palette_dialog_need_refresh = caller


func _on_hair_item_selected(index: int) -> void:
	var caller = %Hair
	current_character.hair.item = caller.get_item_metadata(index)
	
	update_palettes(current_character.hair, %HairTexture, caller)
	draw_body_part("hair", %HairTexture, null, "hair")
	palette_dialog_need_refresh = caller


func _on_hair_addon_item_selected(index: int) -> void:
	var caller = %Hairadd
	current_character.hairadd.item = caller.get_item_metadata(index)
	
	update_palettes(current_character.hairadd, %HairAddTexture, caller)
	draw_body_part("hairadd", %HairAddTexture, null, "hairadd")
	palette_dialog_need_refresh = caller


func _on_wings_item_selected(index: int) -> void:
	var caller = %Wings
	current_character.wings.item = caller.get_item_metadata(index)

	if !current_character.wings.has("primarycolors") and !current_character.wings.has("secondarycolors") and !current_character.wings.has("fixedcolors"):
		update_palettes(current_character.body, %WingsTextureFront, caller, current_character.wings)
	else:
		update_palettes(current_character.wings, %WingsTextureFront, caller)
	draw_body_part("wings", %WingsTextureFront, %WingsTextureBack, "wings")
	palette_dialog_need_refresh = caller


func _on_tail_item_selected(index: int) -> void:
	var caller = %Tail
	current_character.tail.item = caller.get_item_metadata(index)

	if !current_character.tail.has("primarycolors") and !current_character.tail.has("secondarycolors") and !current_character.tail.has("fixedcolors"):
		update_palettes(current_character.body, %TailTexture, caller, current_character.tail)
	else:
		update_palettes(current_character.tail, %TailTexture, caller)
	draw_body_part("tail", %TailTexture, %TailTextureBack, "tail")
	palette_dialog_need_refresh = caller


func _on_ears_item_selected(index: int) -> void:
	var caller = %Ears
	current_character.ears.item = caller.get_item_metadata(index)

	draw_body_part("ears", %EarsTexture, null, "ears")


func _on_nose_item_selected(index: int) -> void:
	var caller = %Nose
	current_character.nose.item = caller.get_item_metadata(index)

	draw_body_part("nose", %NoseTexture, null, "nose")


func _on_facial_item_selected(index: int) -> void:
	var caller = %Facial
	current_character.facial.item = caller.get_item_metadata(index)

	update_palettes(current_character.facial, %FacialTexture, caller)
	draw_body_part("facial", %FacialTexture, null, "facial")
	palette_dialog_need_refresh = caller


func _on_add_1_item_selected(index: int) -> void:
	var caller = %Add1
	current_character.add1.item = caller.get_item_metadata(index)

	update_palettes(current_character.add1, %Add1Texture, caller)
	draw_body_part("add1", %Add1Texture, null, "add1")
	palette_dialog_need_refresh = caller


func _on_add_2_item_selected(index: int) -> void:
	var caller = %Add2
	current_character.add2.item = caller.get_item_metadata(index)

	update_palettes(current_character.add2, %Add2Texture, caller)
	draw_body_part("add2", %Add2Texture, null, "add2")
	palette_dialog_need_refresh = caller


func _on_add_3_item_selected(index: int) -> void:
	var caller = %Add3
	current_character.add3.item = caller.get_item_metadata(index)

	if current_character.add3.item and current_character.add3.item.has("id") and current_character.add3.item.id == "hooves":
		update_palettes(current_character.body, %Add3Texture, caller, current_character.add3)
	else:
		update_palettes(current_character.add3, %Add3Texture, caller)
		
	draw_body_part("add3", %Add3Texture, null, "add3")
	palette_dialog_need_refresh = caller

# ------------------------------------------------------------------------------
# GEAR
# ------------------------------------------------------------------------------

func _on_mask_item_selected(index: int) -> void:
	var caller = %Mask
	current_character.mask.item = caller.get_item_metadata(index)
	
	update_palettes(current_character.mask, %MaskTexture, caller)
	draw_gear_part("mask", %MaskTexture, null, "mask")
	palette_dialog_need_refresh = caller


func _on_hat_item_selected(index: int) -> void:
	var caller = %Hat
	current_character.hat.item = caller.get_item_metadata(index)

	update_palettes(current_character.hat, %HatTexture, caller)
	draw_gear_part("hat", %HatTexture, null, "hat")
	palette_dialog_need_refresh = caller


func _on_glasses_item_selected(index: int) -> void:
	var caller = %Glasses
	current_character.glasses.item = caller.get_item_metadata(index)

	update_palettes(current_character.glasses, %GlassesTexture, caller)
	draw_gear_part("glasses", %GlassesTexture, null, "glasses")
	palette_dialog_need_refresh = caller


func _on_suit_item_selected(index: int) -> void:
	var caller = %Suit
	current_character.suit.item = caller.get_item_metadata(index)

	update_palettes(current_character.suit, %SuitTexture, caller)
	draw_gear_part("suit", %SuitTexture, null, "suit")
	palette_dialog_need_refresh = caller


func _on_shirt_item_selected(index: int) -> void:
	var caller = %Shirt
	current_character.shirt.item = caller.get_item_metadata(index)

	update_palettes(current_character.shirt, %ShirtTexture, caller)
	draw_gear_part("shirt", %ShirtTexture, null, "shirt")
	palette_dialog_need_refresh = caller


func _on_pants_item_selected(index: int) -> void:
	var caller = %Pants
	current_character.pants.item = caller.get_item_metadata(index)

	update_palettes(current_character.pants, %PantsTexture, caller)
	draw_gear_part("pants", %PantsTexture, null, "pants")
	palette_dialog_need_refresh = caller


func _on_jacket_item_selected(index: int) -> void:
	var caller = %Jacket
	current_character.jacket.item = caller.get_item_metadata(index)

	update_palettes(current_character.jacket, %JacketTexture, caller)
	draw_gear_part("jacket", %JacketTexture, null, "jacket")
	palette_dialog_need_refresh = caller


func _on_gloves_item_selected(index: int) -> void:
	var caller = %Gloves
	current_character.gloves.item = caller.get_item_metadata(index)

	update_palettes(current_character.gloves, %GlovesTexture, caller)
	draw_gear_part("gloves", %GlovesTexture, null, "gloves")
	palette_dialog_need_refresh = caller


func _on_belt_item_selected(index: int) -> void:
	var caller = %Belt
	current_character.belt.item = caller.get_item_metadata(index)

	update_palettes(current_character.belt, %BeltTexture, caller)
	draw_gear_part("belt", %BeltTexture, null, "belt")
	palette_dialog_need_refresh = caller


func _on_shoes_item_selected(index: int) -> void:
	var caller = %Shoes
	current_character.shoes.item = caller.get_item_metadata(index)

	update_palettes(current_character.shoes, %ShoesTexture, caller)
	draw_gear_part("shoes", %ShoesTexture, null, "shoes")
	palette_dialog_need_refresh = caller


func _on_back_item_selected(index: int) -> void:
	var caller = %Back
	current_character.back.item = caller.get_item_metadata(index)

	update_palettes(current_character.back, %BackTexture1, caller)
	draw_gear_part("back", %BackTexture1, %BackTexture2, "back")
	palette_dialog_need_refresh = caller


func _on_mainhand_item_selected(index: int) -> void:
	var caller = %Mainhand
	current_character.mainhand.item = caller.get_item_metadata(index)

	update_palettes(current_character.mainhand, %MainhandBackTexture, caller)
	draw_mainhand()
	palette_dialog_need_refresh = caller
	
	fill_ammo()
	fill_offhand()


func _on_offhand_item_selected(index: int) -> void:
	var caller = %Offhand
	current_character.offhand.item = caller.get_item_metadata(index)
	
	update_palettes(current_character.offhand, %OffhandBackTexture, caller)
	draw_offhand()
	palette_dialog_need_refresh = caller


func _on_ammo_item_selected(index: int) -> void:
	var caller = %Ammo
	current_character.ammo.item = caller.get_item_metadata(index)
	
	update_palettes(current_character.ammo, %AmmoBackTexture, caller)
	draw_ammo()
	palette_dialog_need_refresh = caller


#region Draw Textures:
func load_texture(path: String) -> Variant:
	var tex
	
	if ResourceLoader.exists(path):
		tex = ResourceLoader.load(path)
	
	return tex


func fix_item_visibility():
	can_refresh_visibility = false
	
	var parts = [
		{"id": "body", "textures": [%BodyTexture]},
		{"id": "head", "textures": [%HeadTexture]},
		{"id": "wings", "textures": [%WingsTextureBack, %WingsTextureFront]},
		{"id": "tail", "textures": [%TailTexture]},
		{"id": "horns", "textures": [%HornsTexture]},
		{"id": "hair", "textures": [%HairTexture]},
		{"id": "hairadd", "textures": [%HairAddTexture]},
		{"id": "eyes", "textures": [%EyesTexture]},
		{"id": "ears", "textures": [%EarsTexture]},
		{"id": "nose", "textures": [%NoseTexture]},
		{"id": "facial", "textures": [%FacialTexture]},
		{"id": "add1", "textures": [%Add1Texture]},
		{"id": "add2", "textures": [%Add2Texture]},
		{"id": "add3", "textures": [%Add3Texture]},
		{"id": "mask", "textures": [%MaskTexture]},
		{"id": "hat", "textures": [%HatTexture]},
		{"id": "glasses", "textures": [%GlassesTexture]},
		{"id": "suit", "textures": [%SuitTexture]},
		{"id": "jacket", "textures": [%JacketTexture]},
		{"id": "shirt", "textures": [%ShirtTexture]},
		{"id": "gloves", "textures": [%GlovesTexture]},
		{"id": "belt", "textures": [%BeltTexture]},
		{"id": "pants", "textures": [%PantsTexture]},
		{"id": "shoes", "textures": [%ShoesTexture]},
		{"id": "back", "textures": [%BackTexture1]},
		{"id": "mainhand", "textures": [%MainhandBackTexture, %MainhandFrontTexture]},
		{"id": "offhand", "textures": []},
		{"id": "ammo", "textures": [%AmmoBackTexture, %AmmoFrontTexture]}
	]
	
	if alt_parts.size() > 0:
		var bak_alt_parts = alt_parts.duplicate()
		alt_parts.clear()
		for obj in parts:
			var part_id = obj.id
			if part_id in bak_alt_parts:
				var target1 = null if obj.textures.size() == 0 else obj.textures[0]
				var target2 = null if obj.textures.size() < 2 else obj.textures[1]
				draw_body_part(part_id, target1, target2, part_id)
	
	sealed_slots.clear()
	
	for obj in parts:
		var part_id = obj.id
		var texture_is_visible = true
		for part in current_character.values():
			if part and part is Dictionary and "item" in part and part.item:
				if "slotshidden" in part.item:
					if part.item.slotshidden.has(part_id):
						texture_is_visible = false
						break
				if "slotsalt" in part.item:
					for slot in part.item.slotsalt:
						alt_parts.append(slot)
				if "slotsset" in part.item:
					for slot in part.item.slotsset:
						sealed_slots.append(slot)
		
		var textures = obj.textures
		for texture in textures:
			if texture:
				texture.visible = texture_is_visible

	if alt_parts.size() > 0:
		for obj in parts:
			var part_id = obj.id
			if part_id in alt_parts:
				var target1 = null if obj.textures.size() == 0 else obj.textures[0]
				var target2 = null if obj.textures.size() < 2 else obj.textures[1]
				draw_body_part(part_id, target1, target2, part_id)
	
	if sealed_slots.size() > 0:
		for obj in parts:
			var key = obj.id.to_pascal_case()
			var node = get_node_or_null("%" + key)
			if node:
				if obj.id in sealed_slots:
					node.set_disabled(true)
					node.select(0)
					node.item_selected.emit(0)
				else:
					node.set_disabled(node.get_item_count() <= 1 and node.get_item_text(0).to_lower() != "none")
	
	can_refresh_visibility = true


func draw_current_texture(current_texture, target1, target2, part_id) -> void:
	if target1: target1.visible = false
	if target2: target2.visible = false
	if current_texture:
		var default_path = "res://addons/rpg_character_creator/"
		
		if target1:
			if "front" in current_texture:
				var texture_path = default_path.path_join(current_texture.front)
				var tex = load_texture(texture_path)
				target1.texture = tex
				if tex:
					target1.visible = true
					target1.size = target1.texture.get_size()
			else:
				target1.visible = false
				target1.texture = null

		if target2:
			if "back" in current_texture:
				var texture_path = default_path.path_join(current_texture.back)
				var tex = load_texture(texture_path)
				target2.texture = tex
				if tex:
					target2.visible = true
					target2.size = target2.texture.get_size()
			else:
				target2.visible = false
				target2.texture = null
	else:
		if target1:
			target1.visible = false
			target1.texture = null
		if target2:
			target2.visible = false
			target2.texture = null

	if target1 == %Add3Texture:
		%BodyFirstPassTexture.material.set_shader_parameter("mask1", target1.texture)
	elif target2 == %Add3Texture:
		%BodyFirstPassTexture.material.set_shader_parameter("mask1", target2.texture)
	
	if can_refresh_visibility:
		refresh_visibility_timer = 0.1


func get_texture(current_texture) -> Dictionary:
	var texture = {"id": "", "front": null, "back": null}
	
	if current_texture:
		var default_path = "res://addons/rpg_character_creator/"
		
		if "front" in current_texture:
			var texture_path = default_path.path_join(current_texture.front)
			var tex = load_texture(texture_path)
			texture.front = tex
		
		if "back" in current_texture:
			var texture_path = default_path.path_join(current_texture.back)
			var tex = load_texture(texture_path)
			texture.back = tex
		
		if "spritesheet" in current_texture:
			texture.id = current_texture.spritesheet
	
	return texture


func draw_head_and_body_and_eyes() -> void:
	var ids = [
		["body", %BodyTexture],
		["head", %HeadTexture]
	]
	
	update_palettes(current_character.body, %BodyTexture, null)
	# Draw Body and head
	for obj in ids:
		var id = obj[0]
		var target = obj[1]
		var current_body = get_current_config()
		var current_texture

		for texture in current_character[id].item.textures:
			if texture[id] == current_body["%s-type" % id]:
				current_texture = texture
				break
		
		draw_current_texture(current_texture, target, null, "body")
	
	# Draw eyes
	var target = %EyesTexture
	var current_body = get_current_config()
	var current_texture
	

	for texture in current_character.eyes.item.textures:
		if "head" in texture and texture.head == current_body["head-type"]:
			current_texture = texture
			break
	
	draw_current_texture(current_texture, target, null, "head")


func draw_body_part(id1: String, target: TextureRect, target2 = null, body_part: String = "") -> void:
	var current_body = get_current_config()
	var current_texture

	if !alt_parts.has(id1):
		for texture in current_character[id1].item.textures:
			var id2 = "head" if "head" in texture else "body"
			if id2 in texture and texture[id2] == current_body["%s-type" % id2]:
				current_texture = texture
				break
	elif current_character[id1].item.id != "none" and "alt_item" in current_character[id1] and current_character[id1].alt_item:
		for texture in current_character[id1].alt_item.textures:
			var id2 = "head" if "head" in texture else "body"
			if id2 in texture and texture[id2] == current_body["%s-type" % id2]:
				current_texture = texture
				break

	draw_current_texture(current_texture, target, target2, body_part)


func draw_gear_part(id1: String, target: TextureRect, target2 = null, gear_part: String = "") -> void:
	draw_body_part(id1, target, target2, gear_part)


func draw_mainhand() -> void:
	var current_body = get_current_config()
	var current_texture: Array = []
	
	current_character.mainhand.textures.clear()

	for texture in current_character.mainhand.item.textures:
		var id2 = "head" if "head" in texture else "body"
		if id2 in texture and texture[id2] == current_body["%s-type" % id2]:
			current_character.mainhand.textures.append(get_texture(texture))
	
	set_current_animation(current_animation)


func draw_ammo() -> void:
	var current_body = get_current_config()
	var current_texture: Array = []
	
	current_character.ammo.textures.clear()

	for texture in current_character.ammo.item.textures:
		var id2 = "head" if "head" in texture else "body"
		if id2 in texture and texture[id2] == current_body["%s-type" % id2]:
			current_character.ammo.textures.append(get_texture(texture))
	draw_body_part("ammo", %AmmoFrontTexture, %AmmoBackTexture, "ammo")


func draw_offhand() -> void:
	draw_body_part("offhand", %OffhandFrontTexture, %OffhandBackTexture, "offhand")


#func draw_hair() -> void:
	#draw_body_part("hair", %HairTexture, null, "hair")
#
#
#func draw_wings() -> void:
	#draw_body_part("wings", %WingsTexture, null, "wings")
#
#
#func draw_tail() -> void:
	#draw_body_part("tail", %TailTexture, null, "tail")


#endregion


func select_random_item(obj) -> void:
	var item_name = obj.name.to_lower()
	if current_character[item_name] is Dictionary and current_character[item_name].item is Dictionary:
		if "primarycolors" in current_character[item_name].item:
			var selected_color = randi() % current_character[item_name].item.primarycolors.size()
			var current_color = current_character[item_name].item.primarycolors[selected_color]
			var gradient = get_gradient(get_color(current_color))
			current_character[item_name].palettes.palette1.current_gradient = gradient
			current_character[item_name].palettes.palette1.item_selected = selected_color
		if "secondarycolors" in current_character[item_name].item:
			var selected_color = randi() % current_character[item_name].item.secondarycolors.size()
			var current_color = current_character[item_name].item.secondarycolors[selected_color]
			var gradient = get_gradient(get_color(current_color))
			current_character[item_name].palettes.palette2.current_gradient = gradient
			current_character[item_name].palettes.palette2.item_selected = selected_color
		if "tertiarycolors" in current_character[item_name].item:
			var selected_color = randi() % current_character[item_name].item.tertiarycolors.size()
			var current_color = current_character[item_name].item.tertiarycolors[selected_color]
			var gradient = get_gradient(get_color(current_color))
			current_character[item_name].palettes.palette3.current_gradient = gradient
			current_character[item_name].palettes.palette3.item_selected = selected_color
	
	var index = randi() % obj.get_item_count()
	obj.select(index)
	obj.item_selected.emit(index)


func _on_random_body_pressed() -> void:
	var options = [%Gender, %Body, %Wings, %Tail, %Hair, %Eyes, %Ears, %Nose, %Facial, %Add1, %Add2, %Add3, %Horns, %Hairadd]
	var randomizer = [0.5, 0.5, 0.5, 0.5, 0.95, 0.5, 0.85, 0.85, 0.8, 0.05, 0.05, 0.3, 0.3, 0.05]
	for i in options.size():
		if randf() <= randomizer[i]:
			var obj = options[i]
			if obj.get_item_count() > 0 and !obj.get_parent().get_child(-1).is_pressed():
				select_random_item(obj)
	
	await get_tree().process_frame
	fix_item_visibility()


func _on_random_gear_pressed() -> void:
	var options = [%Mask, %Hat, %Glasses, %Suit, %Jacket, %Shirt, %Gloves, %Belt, %Pants, %Shoes, %Back, %Mainhand, %Offhand]
	var randomizer = [0.1, 0.4, 0.4, 0.1, 0.4, 0.05, 0.7, 0.7, 0.65, 0.6, 0.4, 0.8, 0.8]
	for i in options.size():
		if randf() <= randomizer[i]:
			var obj = options[i]
			if obj.get_item_count() > 0 and !obj.get_parent().get_child(-1).is_pressed():
				select_random_item(obj)
	
	await get_tree().process_frame
	fix_item_visibility()


func close_palette_dialog() -> void:
	if %PaletteDialog.visible: %PaletteDialog.hide()


func show_palette_dialog() -> void:
	if %PaletteDialog.visible:
		DisplayServer.window_move_to_foreground(%PaletteDialog.get_window_id())
		#%PaletteDialog.always_on_top = true
		#%PaletteDialog.always_on_top = false


func update_palette_dialog_visibility() -> void:
	show_palette_dialog()
	#if %PaletteDialog.visible:
		#%PaletteDialog.grab_focus()
		#await get_tree().process_frame


func _on_create_character_and_equipment_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/confirm_create_character_dialog.tscn"
	var parent = RPGDialogFunctions.get_current_dialog()
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	if "confirm_dialog_options" in parent and parent.confirm_dialog_options is RPGCharacterCreationOptions:
		dialog.set_options(parent.confirm_dialog_options)
	dialog.ok_pressed.connect(_on_save)


func _on_save(options: RPGCharacterCreationOptions) -> void:
	get_parent().grab_focus()
	var character_folder = options.character_folder if !options.create_sub_folder else options.character_folder.path_join(options.name)
	if !character_folder.ends_with("/"):
		character_folder += "/"
	var equipment_folder = options.equipment_folder if options.create_equipment_parts else ""
	if options.create_character or options.create_battler_preview or options.create_character_preview or options.create_face_preview:
		var absolute_path = ProjectSettings.globalize_path(character_folder)
		if !DirAccess.dir_exists_absolute(absolute_path):
			DirAccess.make_dir_recursive_absolute(absolute_path)
	if equipment_folder:
		var absolute_path = ProjectSettings.globalize_path(equipment_folder)
		if !DirAccess.dir_exists_absolute(absolute_path):
			DirAccess.make_dir_recursive_absolute(absolute_path)
			
	# Set character data
	var current_config = get_current_config()
	var character_data = RPGLPCCharacter.new()
	character_data.body_type = current_config["body-type"]
	character_data.head_type = current_config["head-type"]
	character_data.inmutable = options.inmutable
	character_data.always_show_weapon = options.always_show_weapon
	var skip_keys = ["palette", "race", "gender"]
	var item
	for key in current_character:
		if key in skip_keys:
			if key == "race":
				character_data.set(key, current_character.race.name)
			else:
				character_data.set(key, current_character[key])
			continue
		if !"item" in current_character[key]: continue
		if key in character_data.body_parts:
			item = character_data.body_parts.get(key)
		elif key in character_data.equipment_parts:
			item = character_data.equipment_parts.get(key)
		# Set textures
		if "textures" in current_character[key].item:
			var character_item = current_character[key].item
			for tex in character_item.textures:
				if (
					("head" in tex and tex.head == character_data.head_type) or
					("body" in tex and tex.body == character_data.body_type) or
					(!"head" in tex and !"body" in tex)
				):
					# Set head or body for this part
					if item is RPGLPCEquipmentPart:
						if "head" in tex: item.head_type = tex.head
						elif "body" in tex: item.body_type = tex.body
						item.name = character_item.name
						item.config_path = character_item.config_path
					# Set textures for this part
					if "back" in tex: item.back_texture = tex.back
					if "front" in tex: item.front_texture = tex.front
					break
		# Set colors for this part
		if "palettes" in current_character[key]:
			for i in range(1, 4, 1):
				var palette_id = "palette%s" % i
				var palette = current_character[key].palettes[palette_id]
				var palette_data: RPGLPCPalette = item.get(palette_id)
				palette_data.lightness = palette.lightness
				if palette.custom_colors:
					var colors = palette.custom_colors.colors
					palette_data.colors = colors
	
	# SAVE DATA
	busy = true
	
	# Foreground texture shown while saving is processig
	var img: Image = get_viewport().get_texture().get_image()
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var t = TextureRect.new()
	t.texture = tex
	var black_back: Image = Image.create(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8)
	black_back.fill(Color(0, 0, 0, 0.65))
	var tex_black_back = ImageTexture.create_from_image(black_back)
	var t2 = TextureRect.new()
	t2.texture = tex_black_back
	var saving_container = get_parent().get_node_or_null("%SavingContainer")
	var progressbar
	if saving_container:
		saving_container.add_child(t2)
		saving_container.move_child(t2, 0)
		saving_container.add_child(t)
		saving_container.move_child(t, 0)
		saving_container.visible = true
		progressbar = saving_container.get_node("%ProgressBar")
		progressbar.value = 0
	
	var backup_visibility : Array = []
	var textures: Array = [%MainhandBackTexture, %OffhandBackTexture, %AmmoBackTexture]
	textures.append_array(%BodyFirstPassViewport.get_children())
	textures.append_array(%BodySecondPassViewport.get_children())
	textures.append_array([%MainhandFrontTexture, %AmmoFrontTexture, %OffhandFrontTexture])
	textures.append_array([%WeaponBack, %WeaponFront, %OffhandBack, %OffhandFront])
	textures.erase(%BodyFirstPassTexture)
	for obj in textures:
		backup_visibility.append(obj.visible)
	
	
	var bak_current_direction = current_direction
	var bak_next_frame_delay = next_frame_delay
	var bak_current_animation = current_animation
	var bak_current_animation_frame = current_animation_frame
	var bak_shader_strength = %CurrentCharacter.get_material().get_shader_parameter("strength")
	%CurrentCharacter.get_material().set_shader_parameter("strength", 0)
	
	current_direction = "down"
	next_frame_delay = 0.0
	current_animation = "idle"
	current_animation_frame = 0
	update_animation(0)
	
	# Save face preview
	if options.create_face_preview:
		%WeaponBack.visible = false
		%WeaponFront.visible = false
		%OffhandBack.visible = false
		%OffhandFront.visible = false
		await RenderingServer.frame_post_draw
		var img2: Image = %FaceTexture.texture.get_image()
		var used_rect = img2.get_used_rect()
		var img3 = Image.create(used_rect.size.x, used_rect.size.y, true, img2.get_format())
		img3.blit_rect(img2, used_rect, Vector2.ZERO)
		var sc = min(64 / img3.get_width(), 64 / img3.get_height())
		img3.resize(img3.get_width() * sc, img3.get_height() * sc, Image.INTERPOLATE_NEAREST)
		img = Image.create(64, 64, true, img3.get_format())
		var p = Vector2(32, 64) - Vector2(img3.get_width() * 0.5, img3.get_height())
		var image_path = character_folder + options.name + "_face.png"
		img.blit_rect(img3, Rect2(0, 0, img3.get_width(), img3.get_height()), p)
		img.save_png(image_path)
		character_data.face_preview = image_path
		if progressbar: progressbar.value += 10

	# Save character preview:
	if options.create_character_preview:
		if options.always_show_weapon:
			%WeaponBack.visible = true
			%WeaponFront.visible = true
			%OffhandBack.visible = true
			%OffhandFront.visible = true
			await RenderingServer.frame_post_draw
		var img2: Image = $FinalMixViewport.get_texture().get_image()
		var used_rect = img2.get_used_rect()
		img = Image.create(used_rect.size.x, used_rect.size.y, true, img2.get_format())
		img.blit_rect(img2, used_rect, Vector2.ZERO)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var image_path = character_folder + options.name + "_character.png"
		img.save_png(image_path)
		character_data.character_preview = image_path
		if progressbar: progressbar.value += 10

	# Save battler preview:
	if options.create_battler_preview:
		%WeaponBack.visible = true
		%WeaponFront.visible = true
		%OffhandBack.visible = true
		%OffhandFront.visible = true
		await RenderingServer.frame_post_draw
		var img2: Image = $FinalMixViewport.get_texture().get_image()
		var used_rect = img2.get_used_rect()
		img = Image.create(used_rect.size.x, used_rect.size.y, true, img2.get_format())
		img.blit_rect(img2, used_rect, Vector2.ZERO)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var image_path = character_folder + options.name + "_battler.png"
		img.save_png(image_path)
		character_data.battler_preview = image_path
		if progressbar: progressbar.value += 10
	
	# Save Character
	if options.create_character:
		# Save resource
		var file_path = character_folder + options.name + "_data.tres"
		var scene_file_path = character_folder + options.name + ".tscn"
		character_data.scene_path = scene_file_path
		ResourceSaver.save(character_data, file_path)
		# Save Scene
		var scn: CharacterBody2D = ACTOR_BASE_SCENE.instantiate()
		scn.actor_data = character_data
		scn.name = options.name.to_pascal_case()

		var p = PackedScene.new()
		p.pack(scn)
		ResourceSaver.save(p, scene_file_path)

	# Save equipment parts
	if options.create_equipment_parts:
		for obj in textures:
			obj.visible = false
		var keys = ["mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt", "pants", "shoes", "back", "mainhand", "offhand", "ammo"]
		var perc = 70 / keys.size()
		var nodes = []
		for key in keys:
			if progressbar: progressbar.value += perc
			if options.save_parts[key] == false: continue
			nodes.clear()
			if key == "back":
				nodes.append_array([%BackTexture2, %BackTexture1])
			elif key == "mainhand":
				nodes.append_array([%MainhandBackTexture, %AmmoBackTexture, %MainhandFrontTexture, %AmmoFrontTexture])
				nodes.append_array([%WeaponBack, %WeaponFront, %OffhandBack, %OffhandFront])
			elif key == "offhand":
				nodes.append_array([%OffhandBackTexture, %OffhandFrontTexture])
				nodes.append_array([%OffhandBack, %OffhandFront])
			elif key == "ammo":
				nodes.append_array([%AmmoBackTexture, %AmmoFrontTexture])
			else:
				var node_path = "%" + (key + "_texture").to_pascal_case()
				nodes.append(get_node(node_path))

			for node in nodes:
				node.visible = true
			
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			if key == "mainhand":
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
			
			if (["back", "offhand"].has(key)) and current_direction != "up":
				current_direction = "up"
				update_animation(0)
				await RenderingServer.frame_post_draw
			elif current_direction != "down":
				current_direction = "down"
				update_animation(0)
				await RenderingServer.frame_post_draw

			var equipment: RPGLPCEquipmentPart = character_data.equipment_parts[key]
			if (
				(!equipment.back_texture.is_empty() and equipment.back_texture != "none") or
				(!equipment.front_texture.is_empty() and equipment.front_texture != "none")
			):
				var file_path: String
				var id = 1
				while true:
					var equipment_name = equipment.name.to_lower().replace(" ", "_")
					file_path = equipment_folder + key + "_" + equipment_name + "_" + str(id) + ".tres"
					if FileAccess.file_exists(file_path):
						id += 1
					else:
						var used_rect
						var image_name = equipment.name.to_lower() + "_" + str(id) + "_preview"
						var image_path = equipment_folder + key + "_" + image_name + ".png"
						var img2: Image
						if key == "ammo":
							var ammo_folder_path = "res://addons/rpg_character_creator/textures/projectiles/"
							var ammo_texture = %AmmoTexture.texture
							var ammo_viewport = %AmmoFinalMix
							if equipment.name == "Arrow":
								var ammo_path = ammo_folder_path + "arrow.png"
								ammo_texture.atlas = load(ammo_path)
								ammo_texture.region = Rect2(0, 0, 5, 26)
								ammo_viewport.size = ammo_texture.region.size
								%AmmoTexture.size = ammo_viewport.size
								await RenderingServer.frame_post_draw
								img2 = ammo_viewport.get_texture().get_image()
								used_rect = img2.get_used_rect()
							elif equipment.name == "Bolt":
								var ammo_path = ammo_folder_path + "bolt.png"
								ammo_texture.atlas = load(ammo_path)
								ammo_texture.region = Rect2(0, 0, 5, 24)
								ammo_viewport.size = ammo_texture.region.size
								%AmmoTexture.size = ammo_viewport.size
								await RenderingServer.frame_post_draw
								img2 = ammo_viewport.get_texture().get_image()
								used_rect = img2.get_used_rect()
							elif equipment.name == "Rock":
								var ammo_path = ammo_folder_path + "rock.png"
								ammo_texture.atlas = load(ammo_path)
								ammo_texture.region = Rect2(0, 0, 7, 6)
								ammo_viewport.size = ammo_texture.region.size
								%AmmoTexture.size = ammo_viewport.size
								await RenderingServer.frame_post_draw
								img2 = ammo_viewport.get_texture().get_image()
								used_rect = img2.get_used_rect()
							elif equipment.name == "Boomerang":
								var ammo_path = ammo_folder_path + "boomerang.png"
								ammo_texture.atlas = load(ammo_path)
								ammo_texture.region = Rect2(192, 0, 64, 64)
								ammo_viewport.size = ammo_texture.region.size
								%AmmoTexture.size = ammo_viewport.size
								await RenderingServer.frame_post_draw
								img2 = ammo_viewport.get_texture().get_image()
								used_rect = img2.get_used_rect()
							elif equipment.name == "Arcane":
								var ammo_path = ammo_folder_path + "arcane1.png"
								ammo_texture.atlas = load(ammo_path)
								ammo_texture.region = Rect2(64, 0, 32, 32)
								ammo_viewport.size = ammo_texture.region.size
								%AmmoTexture.size = ammo_viewport.size
								await RenderingServer.frame_post_draw
								img2 = ammo_viewport.get_texture().get_image()
								used_rect = img2.get_used_rect()
							else:
								img2 = $FinalMixViewport.get_texture().get_image()
								used_rect = img2.get_used_rect()
						else:
							img2 = $FinalMixViewport.get_texture().get_image()
							used_rect = img2.get_used_rect()
						if used_rect:
							img = Image.create(used_rect.size.x, used_rect.size.y, true, img2.get_format())
							img.blit_rect(img2, used_rect, Vector2.ZERO)
							img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
							img.save_png(image_path)
							equipment.equipment_preview = image_path
						ResourceSaver.save(equipment, file_path)
						break
			
			for node in nodes:
				node.visible = false
	
	current_direction = bak_current_direction
	next_frame_delay = bak_next_frame_delay
	current_animation = bak_current_animation
	current_animation_frame = bak_current_animation_frame
	
	for i in range(textures.size() - 1, -1, -1):
		var obj = textures[i]
		obj.visible = backup_visibility[i]
	
	%CurrentCharacter.get_material().set_shader_parameter("strength", bak_shader_strength)
	update_animation(0)
	
	if progressbar: progressbar.value = 100
	
	await RenderingServer.frame_post_draw
	busy = false
	t.queue_free()
	t2.queue_free()
	
	if saving_container:
		saving_container.visible = false


func _on_h_slider_value_changed(value: float) -> void:
	%FinalCharacter.get_material().set_shader_parameter("pivot", Vector2(0.5, value))
