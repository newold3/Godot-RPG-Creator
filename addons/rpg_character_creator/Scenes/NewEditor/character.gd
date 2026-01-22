@tool
extends Control

var current_character: RPGLPCCharacter

var frame_delay: float = 0.0
var frame_delay_max: float = 0.1
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

const BASE_DIR: String = "res://addons/rpg_character_creator/"

@onready var offhand_back: Sprite2D = %OffhandBack
@onready var mainhand_back: Sprite2D = %MainHandBack
@onready var offhand_front: Sprite2D = %OffhandFront
@onready var mainhand_front: Sprite2D = %MainHandFront
@onready var wings_back: Sprite2D = $FullBody/WingsBack
@onready var body: Sprite2D = $FullBody/Body

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


func set_character(_character: RPGLPCCharacter, _hidden_layers: Array) -> void:
	current_character = _character
	extra_hidden_layers = _hidden_layers
	current_character.changed.connect(_refresh_character)
	animation_finished.connect(func(): busy = false)
	_refresh_character()


func set_animation_data(_body_animations: Dictionary, _weapon_animations: Dictionary) -> void:
	weapon_animations = _weapon_animations
	body_animations = _body_animations


func set_extra_data(weapon_id: String, images: Dictionary, actions: Array) -> void:
	current_weapon_id = weapon_id
	current_weapon_images = images
	current_actions = actions


func _process(delta: float) -> void:
	if current_character:
		if frame_delay <= 0.0:
			run_animation()
			
			var current_anim_data = get_current_animation()
			
			var target_fps = current_anim_data.get("fps", 0)
			
			if target_fps > 0:
				frame_delay = 1.0 / float(target_fps)
			else:
				frame_delay = frame_delay_max
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
	else:
		current_animation = "idle"
	
	_refresh_visibility_parts()


func stop() -> void:
	busy = false
	current_animation = "idle"
	current_frame = 0
	run_animation()


func _refresh_visibility_parts() -> void:
	#extra_hidden_layers
	
	var textures = [$WingsBack/WingsBack, $OffhandBack/OffHandBack, $WeaponBack/MainHandBack, $Body/BackBack, $Body/TailBack, $Body/Body, $Body/Add2, $Body/Suit, $Body/Pants, $Body/Shoes, $Body/Gloves, $Body/Shirt, $Body/Belt, $Body/Add3, $Body/Jacket, $Body/Head, $Body/Eyes, $Body/Facial, $Body/Ears, $Body/Nose, $Body/Add1, $Body/Mask, $Body/Glasses, $Body/Hair, $Body/HairAdd, $Body/Hat, $Body/TailFront, $Body/BackFront, $Body/WingsFront, $Body/Horns, $OffHandFront/OffHandFront, $WeaponFront/MainHandFront]
	
	for t in textures:
		var part_name: String = t.name.to_lower()
		if part_name.ends_with("back"): part_name = part_name.left(part_name.length() - "back".length())
		if part_name.ends_with("front"): part_name = part_name.left(part_name.length() - "front".length())
		if part_name in "mainhand" or part_name in "offhand" and not part_name in extra_hidden_layers:
			t.visible = true
		else:
			if current_character:
				t.visible = not (part_name in extra_hidden_layers or part_name in current_character.hidden_items)
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
		if "front" in alt_texture_data:
			final_front_path = alt_texture_data.front

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
			
			# Apply Shader Parameters
			var mat: ShaderMaterial = target_node.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("palette1", data.get("gradient1"))
				mat.set_shader_parameter("palette2", data.get("gradient2"))
				mat.set_shader_parameter("palette3", data.get("gradient3"))
		else:
			target_node.texture = null


func _refresh_character() -> void:
	if not current_character: return
	var textures = [$WingsBack/WingsBack, $OffhandBack/OffHandBack, $WeaponBack/MainHandBack, $Body/BackBack, $Body/TailBack, $Body/Body, $Body/Add2, $Body/Suit, $Body/Pants, $Body/Shoes, $Body/Gloves, $Body/Shirt, $Body/Belt, $Body/Add3, $Body/Jacket, $Body/Head, $Body/Eyes, $Body/Facial, $Body/Ears, $Body/Nose, $Body/Add1, $Body/Mask, $Body/Glasses, $Body/Hair, $Body/HairAdd, $Body/Hat, $Body/TailFront, $Body/BackFront, $Body/WingsFront, $Body/Horns, $OffHandFront/OffHandFront, $WeaponFront/MainHandFront]
	
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

	var textures = [$WingsBack/WingsBack, $OffhandBack/OffHandBack, $WeaponBack/MainHandBack, $Body/BackBack, $Body/TailBack, $Body/Body, $Body/Add2, $Body/Suit, $Body/Pants, $Body/Shoes, $Body/Gloves, $Body/Shirt, $Body/Belt, $Body/Add3, $Body/Jacket, $Body/Head, $Body/Eyes, $Body/Facial, $Body/Ears, $Body/Nose, $Body/Add1, $Body/Mask, $Body/Glasses, $Body/Hair, $Body/HairAdd, $Body/Hat, $Body/TailFront, $Body/BackFront, $Body/WingsFront, $Body/Horns, $OffHandFront/OffHandFront, $WeaponFront/MainHandFront]
	
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
		var tex_front = str(data.get("front_texture"))
		_load_part(tex_back, tex_front, nodes, data)
	else:
		for key in nodes:
			if nodes[key]: nodes[key].texture = null
	
	_refresh_visibility_parts()


func set_highlight_color(part_id: String, enabled: bool, palette: int, color_id: int) -> void:
	var textures = [$WingsBack/WingsBack, $OffhandBack/OffHandBack, $WeaponBack/MainHandBack, $Body/BackBack, $Body/TailBack, $Body/Body, $Body/Add2, $Body/Suit, $Body/Pants, $Body/Shoes, $Body/Gloves, $Body/Shirt, $Body/Belt, $Body/Add3, $Body/Jacket, $Body/Head, $Body/Eyes, $Body/Facial, $Body/Ears, $Body/Nose, $Body/Add1, $Body/Mask, $Body/Glasses, $Body/Hair, $Body/HairAdd, $Body/Hat, $Body/TailFront, $Body/BackFront, $Body/WingsFront, $Body/Horns, $OffHandFront/OffHandFront, $WeaponFront/MainHandFront]

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
		
	var animation_id = current_animation.to_lower() + "_" + str(CharacterBase.DIRECTIONS.find_key(current_direction)).to_lower()
	if ["dagger2"].has(current_weapon_id) and ["idle", "walk"].has(current_animation.to_lower()):
		animation_id = "small_" + animation_id

	var current_animation = {}

	for animation in animations.weapon:
		if animation.id == animation_id:
			current_animation = animation
			break

	return current_animation


func run_animation(force_animation: bool = false) -> void:
	if not is_inside_tree(): return
	if frame_delay > 0.0 and not force_animation: return
	
	offhand_back.visible = not "offhand" in extra_hidden_layers
	offhand_front.visible = not "offhand" in extra_hidden_layers
	mainhand_back.visible = not "mainhand" in extra_hidden_layers
	mainhand_front.visible = not "mainhand" in extra_hidden_layers
	
	var tex1 = $WeaponBack/MainHandBack
	var tex2 = $WeaponFront/MainHandFront

	if current_animation in current_weapon_images:
		var image_data = current_weapon_images[current_animation]
		if image_data.back:
			var path = image_data.back
			if not path.begins_with("res://"):
				path = BASE_DIR.path_join(path)
			if ResourceLoader.exists(path):
				tex1.texture = load(path)
			else:
				tex1.texture = null
			tex1.size = Vector2.ZERO
		if image_data.front:
			var path = image_data.front
			if not path.begins_with("res://"):
				path = BASE_DIR.path_join(path)
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
			if ResourceLoader.exists(path):
				tex1.texture = load(path)
			else:
				tex1.texture = null
			tex1.size = Vector2.ZERO
		if image_data.front:
			var path = image_data.front
			if not path.begins_with("res://"):
				path = BASE_DIR.path_join(path)
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
	
	
	var weapon_back = $WeaponBack/MainHandBack
	var weapon_front = $WeaponFront/MainHandFront
	%WeaponBack.size = Vector2i(weapon_back.texture.get_size() if weapon_back.texture else weapon_back.size)
	%WeaponFront.size = Vector2i(weapon_front.texture.get_size() if weapon_front.texture else weapon_front.size)
	
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
	mainhand_front.position = Vector2(0, 0)
	mainhand_back.position = Vector2(0, 0)
	
	var action_frame = current_animation.get("action_frame", -1)
	if current_frame == action_frame:
		_handle_action_frame(current_animation)
	
	#if (
		#(mainhand_back.texture and mainhand_back.texture.get_size() == body.texture.get_size()) or
		#(mainhand_front.texture and mainhand_front.texture.get_size() == body.texture.get_size())
	#):
		#mainhand_back.region_rect = body.region_rect
	#else:
		#mainhand_back.region_rect = Rect2(weapon_frame[0], weapon_frame[1], 192, 192)
	#mainhand_front.region_rect = mainhand_back.region_rect
	
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
	
	if not has_meta("actor_id"): return
	
	var actor_id = get_meta("actor_id")
	var actor = GameManager.get_actor(actor_id)
	
	
	var offset_array = anim_data.get("emiter", [0, 0])
	var emission_point = Vector2(offset_array[0], offset_array[1])
	var anim_id = anim_data.get("id", "")
	
	return
	
	if "shoot" in anim_id or "cast" in anim_id:
		var ammo_id = "arrow"
		
		if "shoot" in anim_id:
			ammo_id = current_character.equipment_parts["ammo"].name.to_lower()
		elif "cast" in anim_id:
			ammo_id = "arcane1"
		
		perform_shoot(ammo_id, _get_direction_string(), emission_point)
		
	elif "slash" in anim_id or "thrust" in anim_id or "smash" in anim_id or "whip" in anim_id:
		pass


func _get_direction_string() -> String:
	match current_direction:
		CharacterBase.DIRECTIONS.UP: return "up"
		CharacterBase.DIRECTIONS.DOWN: return "down"
		CharacterBase.DIRECTIONS.LEFT: return "left"
		CharacterBase.DIRECTIONS.RIGHT: return "right"
	return "down"


func perform_shoot(ammo_id: String, direction: String, ammo_position: Vector2) -> void:
	print(["shoot ", ammo_id, direction, ammo_position])
