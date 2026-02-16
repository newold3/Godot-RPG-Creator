@tool
extends Control

var current_character: RPGLPCCharacter

var frame_delay: float = 0.0
var frame_delay_max: float = 0.1
var frame_delay_attack_max: float = 0.06
var force_animation: bool = false
var is_attacking: bool = false
var current_animation: String = "idle"
var current_frame: int = 0
var current_weapon_images: Dictionary = {}
var current_actions: Array = []
var weapon_animations: Dictionary = {}
var body_animations: Dictionary = {}
var current_direction: CharacterBase.DIRECTIONS = CharacterBase.DIRECTIONS.DOWN
var extra_hidden_layers: Array = []
var current_weapon_id: String = ""
var busy: bool = false
var saving: bool =  false
var weapon_data: Dictionary

const BASE_DIR: String = "res://addons/rpg_character_creator/"
const MAX_ZOOM: float = 10.0
const MIN_ZOOM: float = 2.5
const PROJECTILES = {
	"arrow": preload("uid://6erjlil1ucrr"),
	"bolt": preload("uid://byw14gtmykqan"),
	"rock": preload("uid://bo3rpy0db4jj6"),
	"arcane1": preload("uid://77343buoiumk"),
	"boomerang": preload("uid://dfdutq6byju5s")
}

var current_zoom: float = 4.0

@onready var offhand_back: Sprite2D = %OffhandBack
@onready var mainhand_back: Sprite2D = %MainHandBack
@onready var offhand_front: Sprite2D = %OffhandFront
@onready var mainhand_front: Sprite2D = %MainHandFront
@onready var wings_back: Sprite2D = $FullBody/FullBody/WingsBack
@onready var body: Sprite2D = $FullBody/FullBody/Body

@onready var ammo_node: Sprite2D = %AmmoNode
@onready var animations = {
	"player": RPGSYSTEM.player_animations_data.animations,
	"weapon": RPGSYSTEM.weapon_animations_data.animations
}

var body_layers: PackedStringArray = [
	"body", "head", "eyes", "wings", "tail", "horns", "hair", "hairadd",
	"ears", "nose", "facial", "add1", "add2", "add3",
]

var gear_layers: PackedStringArray = [
	"mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt",
	"pants", "shoes", "back", "mainhand", "offhand", "ammo"
]


signal animation_finished()


func _ready() -> void:
	scale = Vector2(current_zoom, current_zoom)


func set_character(_character: RPGLPCCharacter, _hidden_layers: Array) -> void:
	current_character = _character
	extra_hidden_layers = _hidden_layers
	if not current_character.changed.is_connected(_refresh_character):
		current_character.changed.connect(_refresh_character)
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)
	update_part("mainhand")
	_refresh_character()


func _on_animation_finished() -> void:
	is_attacking = false
	current_animation = "idle"
	set_deferred("busy", false)


func set_animation_data(_body_animations: Dictionary, _weapon_animations: Dictionary) -> void:
	weapon_animations = _weapon_animations
	body_animations = _body_animations


func set_extra_data(weapon_id: String, images: Dictionary, actions: Array) -> void:
	current_weapon_id = weapon_id
	current_weapon_images = images
	current_actions = actions


func _process(delta: float) -> void:
	if not RPGDialogFunctions.there_are_any_dialog_open(): return
	
	%OffhandBack.z_index = -1
	%MainHandBack.z_index = -1
	%OffhandFront.z_index = 1
	%MainHandFront.z_index = 1
			
	if saving: return
	if current_character:
		if frame_delay <= 0.0:
			run_animation()
			
			var current_anim_data = get_current_animation()
			
			var target_fps = current_anim_data.get("fps", 0)
			
			if target_fps > 0:
				frame_delay = 1.0 / float(target_fps)
			else:
				frame_delay = frame_delay_max if not is_attacking else frame_delay_attack_max
		else:
			frame_delay = max(0.0, frame_delay - delta)
	
	if busy: return
	
	if Input.is_action_pressed("ui_left"):
			current_direction = CharacterBase.DIRECTIONS.LEFT
			current_animation = "walk"
			accept_event()
	elif Input.is_action_pressed("ui_right"):
		current_direction = CharacterBase.DIRECTIONS.RIGHT
		current_animation = "walk"
		accept_event()
	elif Input.is_action_pressed("ui_up"):
		current_direction = CharacterBase.DIRECTIONS.UP
		current_animation = "walk"
		accept_event()
	elif Input.is_action_pressed("ui_down"):
		current_direction = CharacterBase.DIRECTIONS.DOWN
		current_animation = "walk"
		accept_event()
	elif Input.is_action_pressed("ui_select"):
		if not current_actions.is_empty():
			var action = current_actions[randi() % current_actions.size()]
			current_animation = action
			busy = true
			is_attacking = true
			_play_fx()
	else:
		if get_parent() is Control and get_parent().get_global_rect().has_point(get_global_mouse_position()):
			if Input.is_action_just_pressed("mouse_wheel_up"):
				current_zoom = clamp(current_zoom + 0.1, MIN_ZOOM, MAX_ZOOM)
				scale = Vector2(current_zoom, current_zoom)
			elif Input.is_action_just_pressed("mouse_wheel_down"):
				current_zoom = clamp(current_zoom - 0.1, MIN_ZOOM, MAX_ZOOM)
				scale = Vector2(current_zoom, current_zoom)

		current_animation = "idle"
	
	_refresh_visibility_parts()


func _play_fx() -> void:
	if current_animation == "shoot":
		var fx = ResourceLoader.load("res://addons/rpg_character_creator/sounds/bow_draw.ogg")
		var audio_stream_player = AudioStreamPlayer.new()
		audio_stream_player.stream = fx
		audio_stream_player.finished.connect(func(): audio_stream_player.queue_free())
		add_child(audio_stream_player)
		audio_stream_player.play()
		
	elif weapon_data:
		var part_id = current_character.equipment_parts.mainhand.part_id
		
		if part_id in weapon_data:
			var _weapon_data = weapon_data[part_id]
			if _weapon_data.get("sounds", null):
				var sound_path = _weapon_data.sounds[randi() % _weapon_data.sounds.size()]
				var plugin_path = "res://addons/rpg_character_creator/"
				sound_path = plugin_path.path_join(sound_path)
				if ResourceLoader.exists(sound_path):
					var fx = ResourceLoader.load(sound_path)
					var audio_stream_player = AudioStreamPlayer.new()
					audio_stream_player.stream = fx
					audio_stream_player.finished.connect(func(): audio_stream_player.queue_free())
					add_child(audio_stream_player)
					audio_stream_player.play()


func stop() -> void:
	busy = false
	current_animation = "idle"
	current_frame = 0
	run_animation()


func _refresh_visibility_parts() -> void:
	#extra_hidden_layers
	
	var textures = [$WingsBack/WingsBack, $OffhandBack/OffHandBack, $WeaponBack/MainHandBack, $Body/BackBack, $Body/TailBack, $Body/Body, $Body/Add2, $Body/Suit, $Body/Pants, $Body/Shoes, $Body/Gloves, $Body/Shirt, $Body/Belt, $Body/Add3, $Body/Jacket, $Body/Head, $Body/Eyes, $Body/Facial, $Body/Ears, $Body/Nose, $Body/Add1, $Body/Mask, $Body/Glasses, $Body/Hair, $Body/HairAdd, $Body/Hat, $Body/TailFront, $Body/BackFront, $Body/WingsFront, $Body/Horns, $OffHandFront/OffHandFront, $WeaponFront/MainHandFront, $Ammo/AmmoBack, $Ammo/AmmoFront]
	
	for t in textures:
		var part_name: String = t.name.to_lower()
		if part_name.ends_with("back"): part_name = part_name.left(part_name.length() - "back".length())
		if part_name.ends_with("front"): part_name = part_name.left(part_name.length() - "front".length())
		if current_character:
			var is_hidden_manually = part_name in extra_hidden_layers
			var is_hidden_by_gear = part_name in current_character.hidden_items
			
			t.visible = not (is_hidden_manually or is_hidden_by_gear)
		else:
			t.visible = true


func _get_json_data(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return {}
	var text = f.get_as_text()
	f.close()
	var result = JSON.parse_string(text)
	return result if result else {}


func _find_best_texture_match(json_data: Dictionary, body_type: String, head_type: String) -> Dictionary:
	if not json_data or not "textures" in json_data: return {}
	
	for t in json_data.textures:
		var t_body = t.get("body", body_type)
		var t_head = t.get("head", head_type)
		
		if (t_body == body_type and t_head == head_type) or t_body == t_head:
			return t
	return {}


## Loads and applies the specific body part textures and materials to the target nodes.
## Handles logic for alternative texture configurations (Alt) and standard paths.
func _load_part(tex_back_path: String, tex_front_path: String, targets: Dictionary, data: Resource) -> void:
	
	var final_back_path: String = tex_back_path
	var final_front_path: String = tex_front_path

	# Check for Alternative Configuration (Alt)
	if data.get("is_alt") and FileAccess.file_exists(data.get("alt_config_path")):
		var alt_json: Dictionary = _get_json_data(data.get("alt_config_path"))
		var alt_texture_data: Dictionary = _find_best_texture_match(alt_json, current_character.body_type, current_character.head_type)
		if "back" in alt_texture_data:
			final_back_path = alt_texture_data.back
			if not final_back_path.begins_with("res://"):
				final_back_path = BASE_DIR.path_join(final_back_path)
		if "front" in alt_texture_data:
			final_front_path = alt_texture_data.front
			if not final_front_path.begins_with("res://"):
				final_front_path = BASE_DIR.path_join(final_front_path)

	# Load Textures
	var tex_back: Texture2D = load(final_back_path) if ResourceLoader.exists(final_back_path) else null
	var tex_front: Texture2D = load(final_front_path) if ResourceLoader.exists(final_front_path) else null

	# Map target keys to the texture they should receive
	var assignments: Dictionary = {
		"back": tex_back,
		"front": tex_front,
		"normal": tex_front
	}

	# Apply textures and materials to each target node
	for key in assignments:
		var target_node: TextureRect = targets.get(key)
		var texture_to_use: Texture2D = assignments[key]

		if not is_instance_valid(target_node):
			continue

		# Reset
		target_node.position = Vector2.ZERO
		target_node.size = Vector2.ZERO
		
		# Assign Texture
		if texture_to_use:
			if target_node.texture != texture_to_use:
				target_node.texture = texture_to_use
			
			if target_node.name == "MainHandBack" or target_node.name == "MainHandFront":
				_sync_weapon_rect.call_deferred(target_node)
			
			_apply_shader_parameters_deferred(target_node, data)
		else:
			if (target_node.name == "MainHandBack" or target_node.name == "MainHandFront") and \
				current_character.equipment_parts.mainhand.part_id == "boomerang":
					_apply_shader_parameters_deferred(target_node, data)
			target_node.texture = null


func _sync_weapon_rect(node: TextureRect) -> void:
	if not node or not node.texture: 
		return

	var current_weapon_animation = get_current_weapon_animation()
	if not current_weapon_animation: 
		return

	var weapon_current_frame = min(current_frame, current_weapon_animation.frames.size() - 1)
	var weapon_frame: Array = current_weapon_animation.frames[weapon_current_frame]
	var w_size = _get_frame_size_for_texture(node.texture, current_weapon_animation)
	
	mainhand_back.region_rect = Rect2(weapon_frame[0], weapon_frame[1], w_size.x, w_size.y)
	mainhand_front.region_rect = Rect2(weapon_frame[0], weapon_frame[1], w_size.x, w_size.y)


func _apply_shader_parameters_deferred(target_node: TextureRect, data: Resource) -> void:
	if not is_instance_valid(target_node):
		return
	
	if target_node.material == null:
		target_node.material = target_node.get_parent().material.duplicate()

	var mat: ShaderMaterial = target_node.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("palette1", data.get("gradient1"))
		mat.set_shader_parameter("palette2", data.get("gradient2"))
		mat.set_shader_parameter("palette3", data.get("gradient3"))


func _update_shader_masks(node: TextureRect, nodes: Dictionary, is_acc: bool = true) -> void:
	var mat: ShaderMaterial = node.get_material()
	
	var id = 1 if is_acc else 4
	if nodes.normal:
		mat.set_shader_parameter("mask%s" % (id), nodes.normal.texture)
	if nodes.back:
		mat.set_shader_parameter("mask%s" % (id+1), nodes.back.texture)
	if nodes.front:
		mat.set_shader_parameter("mask%s" % (id+2), nodes.front.texture)


func set_part_shader_parameter(part_id: String, param_name: String, value: Variant) -> void:
	var textures = [$WingsBack/WingsBack, $OffhandBack/OffHandBack, $WeaponBack/MainHandBack, $Body/BackBack, $Body/TailBack, $Body/Body, $Body/Add2, $Body/Suit, $Body/Pants, $Body/Shoes, $Body/Gloves, $Body/Shirt, $Body/Belt, $Body/Add3, $Body/Jacket, $Body/Head, $Body/Eyes, $Body/Facial, $Body/Ears, $Body/Nose, $Body/Add1, $Body/Mask, $Body/Glasses, $Body/Hair, $Body/HairAdd, $Body/Hat, $Body/TailFront, $Body/BackFront, $Body/WingsFront, $Body/Horns, $OffHandFront/OffHandFront, $WeaponFront/MainHandFront, $Ammo/AmmoBack, $Ammo/AmmoFront]
	
	for t in textures:
		var part_name: String = t.name.to_lower()
		if part_name.ends_with("back"): part_name = part_name.left(part_name.length() - "back".length())
		if part_name.ends_with("front"): part_name = part_name.left(part_name.length() - "front".length())
		
		if part_name == part_id:
			var mat = t.get_material()
			if mat:
				mat.set_shader_parameter(param_name, value)


func _refresh_character() -> void:
	if not current_character: return
	var textures = [$WingsBack/WingsBack, $OffhandBack/OffHandBack, $WeaponBack/MainHandBack, $Body/BackBack, $Body/TailBack, $Body/Body, $Body/Add2, $Body/Suit, $Body/Pants, $Body/Shoes, $Body/Gloves, $Body/Shirt, $Body/Belt, $Body/Add3, $Body/Jacket, $Body/Head, $Body/Eyes, $Body/Facial, $Body/Ears, $Body/Nose, $Body/Add1, $Body/Mask, $Body/Glasses, $Body/Hair, $Body/HairAdd, $Body/Hat, $Body/TailFront, $Body/BackFront, $Body/WingsFront, $Body/Horns, $OffHandFront/OffHandFront, $WeaponFront/MainHandFront, $Ammo/AmmoBack, $Ammo/AmmoFront]
	
	var layer_targets = [body_layers, gear_layers]
	for i in layer_targets.size():
		var layers = layer_targets[i]
		for key in layers:
			var nodes = {"normal": null, "back": null, "front": null}
			for t in textures:
				if t.name.to_lower().ends_with(key + "back"):
					nodes.back = t
				elif t.name.to_lower().ends_with(key + "front"):
					nodes.front = t
				elif t.name.to_lower().ends_with(key):
					nodes.normal = t

			var data
			if i == 0:
				data = current_character.body_parts.get(key)
			else:
				data = current_character.equipment_parts.get(key)
			
			var tex_back = str(data.get("back_texture"))
			var tex_front = str(data.get("front_texture"))
			
			_load_part(tex_back, tex_front, nodes, data)
			
			if key == "add3":
				_update_shader_masks($Body/Body, nodes, true)
			elif key == "mainhand":
				_update_shader_masks($Body/Body, nodes, false)
				
	
	var current_weapon_animation = get_current_weapon_animation()
	var weapon_current_frame: int
	if current_weapon_animation:
		weapon_current_frame = min(current_frame, current_weapon_animation.frames.size() - 1)
		var weapon_frame: Array = current_weapon_animation.frames[weapon_current_frame]
		if (
			(mainhand_back.texture and mainhand_back.texture.get_size() == body.texture.get_size()) or
			(mainhand_front.texture and mainhand_front.texture.get_size() == body.texture.get_size())
		):
			mainhand_back.region_rect = body.region_rect
		else:
			mainhand_back.region_rect = Rect2(weapon_frame[0], weapon_frame[1], 192, 192)
		if mainhand_back.texture:
			if mainhand_back.texture.get_size() == Vector2(932, 1344) or \
				mainhand_back.texture.get_height() == 256:
				mainhand_back.region_rect.size = Vector2(64, 64)
		mainhand_front.region_rect = mainhand_back.region_rect



func update_part(part_id: String) -> void:
	if not current_character: return

	var data
	if part_id in body_layers:
		data = current_character.body_parts.get(part_id)
	elif part_id in gear_layers:
		data = current_character.equipment_parts.get(part_id)
	else:
		return

	var textures = [$WingsBack/WingsBack, $OffhandBack/OffHandBack, $WeaponBack/MainHandBack, $Body/BackBack, $Body/TailBack, $Body/Body, $Body/Add2, $Body/Suit, $Body/Pants, $Body/Shoes, $Body/Gloves, $Body/Shirt, $Body/Belt, $Body/Add3, $Body/Jacket, $Body/Head, $Body/Eyes, $Body/Facial, $Body/Ears, $Body/Nose, $Body/Add1, $Body/Mask, $Body/Glasses, $Body/Hair, $Body/HairAdd, $Body/Hat, $Body/TailFront, $Body/BackFront, $Body/WingsFront, $Body/Horns, $OffHandFront/OffHandFront, $WeaponFront/MainHandFront, $Ammo/AmmoBack, $Ammo/AmmoFront]
	
	var nodes = {"normal": null, "back": null, "front": null}
	
	for t in textures:
		var t_name = t.name.to_lower()
		
		if t_name == part_id + "back":
			nodes.back = t
		elif t_name == part_id + "front":
			nodes.front = t
		elif t_name == part_id:
			nodes.normal = t
	

	if data:
		var tex_back = str(data.get("back_texture"))
		if not tex_back.is_empty() and not tex_back.begins_with("res://"):
			tex_back = BASE_DIR.path_join(tex_back)
		var tex_front = str(data.get("front_texture"))
		if not tex_front.is_empty() and not tex_front.begins_with("res://"):
			tex_front = BASE_DIR.path_join(tex_front)
		_load_part(tex_back, tex_front, nodes, data)
	else:
		for key in nodes:
			if nodes[key]: nodes[key].texture = null
	
	if part_id == "mainhand":
		var part_item_id = current_character.equipment_parts.mainhand.part_id
		if part_item_id in weapon_data:
			var _weapon_data = weapon_data[part_item_id]
			for tex in _weapon_data.textures:
				var tex_body = tex.get("body", "")
				var tex_spriteset = tex.get("spritesheet", "")

				if tex_body == current_character.body_type and tex_spriteset == "char_base" and (not "idle" in current_weapon_images or not "walk" in current_weapon_images):
					current_weapon_images.idle = {
						"back": tex.back,
						"front": tex.front
					}
					current_weapon_images.walk = current_weapon_images.idle
					break
				
	if part_id == "add3":
		_update_shader_masks($Body/Body, nodes, true)
	elif part_id == "mainhand":
		_update_shader_masks($Body/Body, nodes, false)
				
	_refresh_visibility_parts()


func set_highlight_color(part_id: String, enabled: bool, palette: int, color_id: int) -> void:
	var textures = [$WingsBack/WingsBack, $OffhandBack/OffHandBack, $WeaponBack/MainHandBack, $Body/BackBack, $Body/TailBack, $Body/Body, $Body/Add2, $Body/Suit, $Body/Pants, $Body/Shoes, $Body/Gloves, $Body/Shirt, $Body/Belt, $Body/Add3, $Body/Jacket, $Body/Head, $Body/Eyes, $Body/Facial, $Body/Ears, $Body/Nose, $Body/Add1, $Body/Mask, $Body/Glasses, $Body/Hair, $Body/HairAdd, $Body/Hat, $Body/TailFront, $Body/BackFront, $Body/WingsFront, $Body/Horns, $OffHandFront/OffHandFront, $WeaponFront/MainHandFront, $Ammo/AmmoBack, $Ammo/AmmoFront]

	for t in textures:
		var part_name: String = t.name.to_lower()
		if part_name.ends_with("back"): part_name = part_name.left(part_name.length() - "back".length())
		if part_name.ends_with("front"): part_name = part_name.left(part_name.length() - "front".length())

		if part_name == part_id:
			var mat: ShaderMaterial = t.get_material()
			mat.set_shader_parameter("highlight_color", color_id)
			mat.set_shader_parameter("highlight_palette_id", palette)


func get_current_animation() -> Dictionary:
	if !animations:
		return {}
	
	var ani = current_animation
	if ani == "fish_throw":
		ani = "fish_full_animation"
		
	var animation_id = ani.to_lower() + "_" + str(CharacterBase.DIRECTIONS.find_key(current_direction)).to_lower()

	var current_animation = {}
	for animation in animations.player:
		if animation.id == animation_id:
			current_animation = animation
			break
	return current_animation


func get_current_weapon_animation() -> Dictionary:
	if !animations:
		return {}
		
	var ani = current_animation
	if ani == "fish_throw":
		ani = "fish_full_animation"
	
	var animation_id = ani.to_lower() + "_" + str(CharacterBase.DIRECTIONS.find_key(current_direction)).to_lower()
	
	if ["dagger2"].has(current_weapon_id) and ["idle", "walk"].has(current_animation.to_lower()):
		animation_id = "small_" + animation_id

	var current_animation = {}

	for animation in animations.weapon:
		if animation.id == animation_id:
			current_animation = animation
			break

	return current_animation


func _get_frame_size_for_texture(tex: Texture2D, anim_data: Dictionary) -> Vector2:
	if not tex:
		return Vector2(64, 64)
	
	var tex_size = tex.get_size()
	
	if int(tex_size.y) == 768:
		return Vector2(192, 192)
		
	if body.texture and tex_size == body.texture.get_size():
		return Vector2(64, 64)
	
	if tex.get_height() / 4 == 192:
		return Vector2(192, 192)
		
	return Vector2(64, 64)


func run_animation(force_animation: bool = false) -> void:
	if not is_inside_tree(): return
	if frame_delay > 0.0 and not force_animation: return
	
	offhand_back.visible = not "offhand" in extra_hidden_layers
	offhand_front.visible = not "offhand" in extra_hidden_layers
	mainhand_back.visible = not "mainhand" in extra_hidden_layers
	mainhand_front.visible = not "mainhand" in extra_hidden_layers
	ammo_node.visible = is_attacking
	
	var tex1 = $WeaponBack/MainHandBack
	var tex2 = $WeaponFront/MainHandFront

	if current_animation in current_weapon_images:
		var image_data = current_weapon_images[current_animation]
		if image_data.back:
			var path = image_data.back
			if not path.begins_with("res://"):
				path = BASE_DIR.path_join(path)
			if not tex1.texture or tex1.texture.get_path() != path:
				if ResourceLoader.exists(path):
					tex1.texture = load(path)
				else:
					tex1.texture = null
			tex1.size = Vector2.ZERO
		if image_data.front:
			var path = image_data.front
			if not path.begins_with("res://"):
				path = BASE_DIR.path_join(path)
			if not tex2.texture or tex2.texture.get_path() != path:
				if ResourceLoader.exists(path):
					tex2.texture = load(path)
				else:
					tex2.texture = null
			tex2.size = Vector2.ZERO
	
	if current_animation == "fish_throw" and "fish_full_animation" in current_weapon_images:
		var image_data = current_weapon_images["fish_full_animation"]
		if image_data.back:
			var path = image_data.back
			if not path.begins_with("res://"):
				path = BASE_DIR.path_join(path)
			if not tex1.texture or tex1.texture.get_path() != path:
				if ResourceLoader.exists(path):
					tex1.texture = load(path)
				else:
					tex1.texture = null
			tex1.size = Vector2.ZERO
		if image_data.front:
			var path = image_data.front
			if not path.begins_with("res://"):
				path = BASE_DIR.path_join(path)
			if not tex2.texture or tex2.texture.get_path() != path:
				if ResourceLoader.exists(path):
					tex2.texture = load(path)
				else:
					tex2.texture = null
			tex2.size = Vector2.ZERO
		 
	var current_animation = get_current_animation()
	var current_weapon_animation = get_current_weapon_animation()

	if !current_animation and !current_weapon_animation:
		return
	
	if !current_animation:
		current_animation = current_weapon_animation
	
	if !current_weapon_animation:
		current_weapon_animation = current_animation
	
	# 1. RENDER PHASE
	var weapon_current_frame = min(current_frame, current_weapon_animation.frames.size() - 1)
	var normal_animation_current_frame = min(current_frame, current_animation.frames.size() - 1)
	
	var player_frame: Array = current_animation.frames[normal_animation_current_frame]
	var weapon_frame: Array = current_weapon_animation.frames[weapon_current_frame]
	var player_size = current_animation.frame_size
	var weapon_size = current_weapon_animation.frame_size
	
	body.region_rect = Rect2(player_frame[0], player_frame[1], player_size[0], player_size[1])
	wings_back.region_rect = body.region_rect
	offhand_back.region_rect = body.region_rect
	offhand_front.region_rect = body.region_rect
	ammo_node.region_rect = body.region_rect
	
	var weapon_back = $WeaponBack/MainHandBack
	var weapon_front = $WeaponFront/MainHandFront
	%WeaponBack.size = Vector2i(weapon_back.texture.get_size() if weapon_back.texture else weapon_back.size)
	%WeaponFront.size = Vector2i(weapon_front.texture.get_size() if weapon_front.texture else weapon_front.size)
	
	var w_size_back = _get_frame_size_for_texture(mainhand_back.texture, current_weapon_animation)

	if mainhand_back.texture and body.texture:
		if mainhand_back.texture.get_size() == body.texture.get_size():
			mainhand_back.region_rect = body.region_rect
		else:
			mainhand_back.region_rect = Rect2(weapon_frame[0], weapon_frame[1], w_size_back.x, w_size_back.y)
	else:
		mainhand_back.region_rect = body.region_rect
	mainhand_front.region_rect = mainhand_back.region_rect
	
	mainhand_front.position = Vector2(0, 0)
	mainhand_back.position = Vector2(0, 0)
	
	var action_frame = current_animation.get("action_frame", -1)
	if current_frame == action_frame:
		_handle_action_frame(current_animation)
	
	# 2. UPDATE LOGIC
	current_frame += 1
	
	if current_frame >= current_animation.frames.size():
		if current_animation.get("loop", false):
			current_frame = 0
		else:
			if not current_animation.get("keep_last_frame", false):
				animation_finished.emit()
				current_frame = 0
			else:
				# Clamp to the last frame index
				current_frame = current_animation.frames.size() - 1


func _handle_action_frame(anim_data: Dictionary) -> void:
	if not current_character:
		return
	
	var offset_array = anim_data.get("emiter", [0, 0])
	var emission_point = Vector2(offset_array[0], offset_array[1])
	var anim_id = anim_data.get("id", "")
	
	var ammo_id = current_character.equipment_parts.ammo.part_id
	
	if ammo_id:
		perform_shoot(ammo_id, _get_direction_string(), emission_point)


func _get_direction_string() -> String:
	match current_direction:
		CharacterBase.DIRECTIONS.UP: return "up"
		CharacterBase.DIRECTIONS.DOWN: return "down"
		CharacterBase.DIRECTIONS.LEFT: return "left"
		CharacterBase.DIRECTIONS.RIGHT: return "right"
	return "down"


func perform_shoot(ammo_id: String, direction: String, ammo_position: Vector2) -> void:
	var p = PROJECTILES.get(ammo_id, "")
	if p:
		var blend_color = int(current_character.equipment_parts.ammo.palette1.blend_color)
		var data = current_character.equipment_parts.get("ammo")
		var obj = p.instantiate()
		obj.material = $WeaponBack/MainHandBack.material.duplicate(true)
		obj.material.set_shader_parameter("palette1", data.get("gradient1"))
		obj.material.set_shader_parameter("palette2", data.get("gradient2"))
		obj.material.set_shader_parameter("palette3", data.get("gradient3"))
		if direction == "up":
			obj.show_behind_parent = true
		obj.set_blend_color(blend_color)
		add_child(obj)
		obj.position = ammo_position
		if ammo_id == "bolt":
			var x = 0
			var y = 0
			if direction == "down":
				x += 0
			elif direction == "left" or direction == "right":
				x += 6
				y += 26
			elif direction == "up":
				x += 0
				y += 26
			obj.position += Vector2(x, y)
		elif ammo_id == "arcane1":
			var x = 0
			var y = 0
			if direction == "down":
				x += 0
			elif direction == "left":
				x += 32
				y += 32
			elif direction == "right":
				x += -32
				y += 32
			elif direction == "up":
				x += 0
				y += 26
			obj.position += Vector2(x, y)
		elif ammo_id == "boomerang":
			var x = 0
			var y = 0
			if direction == "left":
				y += 8
				x -= 16
				obj.z_index = 20
			elif direction == "right":
				y += 8
				x += 16
				obj.z_index = 20
			elif direction == "down":
				y += 8
				obj.z_index = 20
			else:
				obj.z_index = 0
			obj.position += Vector2(x, y)
			
		obj.set_direction(direction)
		var audio_path = "uid://bvhi6arqihxca" if ammo_id == "arrow" else \
			"uid://pfvqv1g2ndpt" if ammo_id == "bolt" else \
			"uid://c7o4l38vr588r" if ammo_id == "rock" else \
			"uid://chmajh2ejdbjt" if ammo_id == "arcane1" else \
			""
		if audio_path:
			var fx = ResourceLoader.load(audio_path)
			var audio_stream_player = AudioStreamPlayer.new()
			audio_stream_player.stream = fx
			audio_stream_player.finished.connect(func(): audio_stream_player.queue_free())
			add_child(audio_stream_player)
			audio_stream_player.play()
			
	


# SAVE

func get_layers_visibility_state() -> Array:
	if current_character:
		return current_character.hidden_items + extra_hidden_layers
	else:
		return current_character.hidden_items


func apply_layers_visibility_state(layers: Array) -> void:
	pass


## Prepares the character for a specific pose without playing animations.
func setup_pose(p_anim: String, p_dir: int, p_frame: int) -> void:
	current_animation = p_anim
	current_direction = p_dir
	current_frame = p_frame
	force_animation = true
	_refresh_character()


func get_full_character() -> Image:
	return $FullBody.get_texture().get_image()


func get_character_preview() -> Image:
	saving = true
	
	var backup_ehl = extra_hidden_layers
	if not current_character.always_show_weapon:
		extra_hidden_layers = ["mainhand", "offhand"]
	else:
		extra_hidden_layers = []
	_refresh_visibility_parts()
	
	current_animation = "idle"
	current_frame = 0
	current_direction = CharacterBase.DIRECTIONS.DOWN
	run_animation(true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img = get_full_character()
	
	extra_hidden_layers = backup_ehl
	_refresh_visibility_parts()
	
	saving = false
	
	return get_cropped_image(img)


func get_battler_preview() -> Image:
	saving = true
	
	var backup_ehl = extra_hidden_layers
	extra_hidden_layers = []
	_refresh_visibility_parts()
	
	current_animation = "idle"
	current_frame = 0
	current_direction = CharacterBase.DIRECTIONS.DOWN
	run_animation(true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img = get_full_character()
	
	extra_hidden_layers = backup_ehl
	_refresh_visibility_parts()
	
	saving = false
	
	return get_cropped_image(img)


func get_face_preview() -> Image:
	saving = true
	
	var backup_ehl = extra_hidden_layers
	extra_hidden_layers = ["mainhand", "offhand"]
	_refresh_visibility_parts()
	
	current_animation = "idle"
	current_frame = 0
	current_direction = CharacterBase.DIRECTIONS.DOWN
	run_animation(true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 = get_full_character()
	var img = Image.create(img2.get_width(), 52, false, img2.get_format())
	var rect = Rect2(73, 67, 45, 35)
	img.blit_rect(img2, rect, Vector2.ZERO)
	
	extra_hidden_layers = backup_ehl
	_refresh_visibility_parts()
	
	saving = false
	
	return get_cropped_image(img, 1.5)


func get_set_preview() -> Image:
	saving = true
	
	var backup_ehl = extra_hidden_layers
	extra_hidden_layers = body_layers
	_refresh_visibility_parts()
	
	current_animation = "idle"
	current_frame = 0
	current_direction = CharacterBase.DIRECTIONS.DOWN
	run_animation(true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img = get_full_character()
	extra_hidden_layers = backup_ehl
	_refresh_visibility_parts()
	
	saving = false
	
	return get_cropped_image(img, 1.2)


func get_costume_preview() -> Image:
	saving = true
	
	_refresh_visibility_parts()
	
	current_animation = "idle"
	current_frame = 0
	current_direction = CharacterBase.DIRECTIONS.DOWN
	run_animation(true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img = get_full_character()
	
	saving = false
	
	return get_cropped_image(img, 1.2)


## Captures a 3x4 minimalist spriteset (Idle and Walk) as an Image.
func get_minimalist_spriteset() -> Image:
	saving = true
	
	var backup_ehl = extra_hidden_layers
	extra_hidden_layers = []
	_refresh_visibility_parts()
	
	var img = get_full_character()
	var sheet = Image.create(9 * 192, 4 * 192, true, img.get_format())
	
	var directions = [
		CharacterBase.DIRECTIONS.LEFT,
		CharacterBase.DIRECTIONS.DOWN,
		CharacterBase.DIRECTIONS.RIGHT,
		CharacterBase.DIRECTIONS.UP
	]
	
	var y = 0
	for direction in directions:
		await _create_walking_frames_for_direction(direction, sheet, y)
		y += 192
	
	extra_hidden_layers = backup_ehl
	_refresh_visibility_parts()
	
	saving = false
	
	return sheet


func _create_walking_frames_for_direction(direction: int, img: Image, y: int) -> void:
	var x = 0

	# Idle frame
	current_animation = "idle"
	current_frame = 0
	current_direction = direction
	run_animation(true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 = get_full_character()
	img.blit_rect(img2, Rect2i(0, 0, 192, 192), Vector2i(x, y))
	x += 192
	
	# Walking frames
	for i in 8:
		current_animation = "walk"
		current_frame = i
		run_animation(true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		img2 = get_full_character()
		img.blit_rect(img2, Rect2i(0, 0, 192, 192), Vector2i(x, y))
		x += 192


## Gets the used region of an image and scales it by a ratio if provided.
func get_cropped_image(img: Image, ratio: float = 1.0) -> Image:
	var used_rect: Rect2i = img.get_used_rect() 
	
	if not used_rect.has_area(): 
		return Image.create(1, 1, false, img.get_format()) 

	var region: Image = img.get_region(used_rect) 
	
	if ratio != 1.0: 
		var new_w: int = int(region.get_width() * ratio) 
		var new_h: int = int(region.get_height() * ratio) 
		
		region.resize(new_w, new_h, Image.INTERPOLATE_NEAREST) 
	
	return region
	
