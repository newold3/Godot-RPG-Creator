@tool
class_name EditorCharacter
extends Control

enum DIRECTIONS {LEFT, RIGHT, UP, DOWN}

var update_texture_timer: float = 0.0
var current_data: EditorCharacterData
var current_frame: int = -1
var animations: Dictionary
var current_animation: String = "idle"
var current_direction: DIRECTIONS = DIRECTIONS.DOWN
var frame_delay: float = 0.0
var frame_delay_max: float = 0.04
var is_attacking: bool = false
var zoom_tween: Tween
var busy: bool = false

const PROJECTILES = {
	"arrow": preload("res://addons/rpg_character_creator/textures/projectiles/arrow.tscn"),
	"bolt": preload("res://addons/rpg_character_creator/textures/projectiles/bolt.tscn"),
	"rock": preload("res://addons/rpg_character_creator/textures/projectiles/rock.tscn"),
	"arcane1": preload("res://addons/rpg_character_creator/textures/projectiles/arcane1.tscn"),
	"boomerang": preload("res://addons/rpg_character_creator/textures/projectiles/boomerang.tscn")
}
const COLORIZE = preload("res://Assets/Shaders/colorize.gdshader")
const PART_TEXTURE = preload("res://addons/rpg_character_creator/Scenes/part_texture.tscn")

signal attack(animation_id: String)
signal animation_finished()
signal shoot_ammo(ammo_id: String, direction: String, ammo_position: Vector2)


func _ready() -> void:
	%FinalTexture.texture = %ViewportTextures.get_texture()
	%FinalTexture.scale = Vector2(3, 3)
	shoot_ammo.connect(perform_shoot)
	animation_finished.connect(_on_animation_finished)
	create_viewport_textures()


func _on_animation_finished() -> void:
	current_animation = "idle"
	current_frame = -1
	is_attacking = false


func run_animation() -> void:
	if !visible or !is_inside_tree(): return
	var _current_animation = get_current_animation()
	var current_weapon_animation = get_current_weapon_animation()

	%FinalTexture.get_material().set_shader_parameter("enable_breathing", "idle" in _current_animation.get("id", "idle"))

	if !_current_animation and !current_weapon_animation:
		return
	
	if !_current_animation:
		_current_animation = current_weapon_animation
	
	if !current_weapon_animation:
		current_weapon_animation = _current_animation
	
	current_frame += 1
	
	if current_frame >= _current_animation.frames.size():
		if _current_animation.get("loop", false):
			current_frame = 0
		else:
			animation_finished.emit()
			run_animation()
			current_frame = 0
			return
	
	if current_weapon_animation.get("action_frame", -1) == current_frame:
		if current_data.weapon_data.get("ammo", null):
			var ammo_id = current_data.weapon_data.ammo[randi() % current_data.weapon_data.ammo.size()]
			var emiter = current_weapon_animation.get("emiter", [0, 0])
			shoot_ammo.emit(ammo_id, str(DIRECTIONS.find_key(current_direction)).to_lower(), Vector2(emiter[0], emiter[1]))
	
	if current_frame != -1:
		var player_frame: Array = _current_animation.frames[current_frame]
		var weapon_frame: Array = current_weapon_animation.frames[current_frame]
		var body_layers = [
			"TailBack", "TailFront", "WingsBack", "WingsFront",
			"Body", "Add2", "Add3", "Head", "Eyes", "Ears",
			"Nose", "Add1", "Hair", "HairAdd", "Horns"
		]
		var gear_layers = [
			"MainHandBack", "OffHandBack", "AmmoBack", "BackBack", "Suit",
			"Pants", "Shoes", "Gloves", "Shirt", "Belt", "Jacket", "Facial",
			"Mask", "Glasses", "Hat", "BackFront", "OffHandFront",
			"MainHandFront", "AmmoFront"
		]
		
		for texture in %ViewportTextures.get_children():
			if texture.texture.region.size.x == 192 or current_weapon_animation.id.begins_with("small"):
				texture.texture.region.position = Vector2(weapon_frame[0], weapon_frame[1])
			else:
				texture.texture.region.position = Vector2(player_frame[0], player_frame[1])


func _process(delta: float) -> void:
	if busy or !visible:
		return
		
	# Update timer for textures
	if update_texture_timer > 0.0:
		update_texture_timer -= delta
		if update_texture_timer <= 0.0:
			update_texture_timer = 0.0
			update_textures()
	
	if frame_delay <= 0.0:
		run_animation()
		frame_delay = frame_delay_max
	else:
		frame_delay = max(0.0, frame_delay - delta)
	
	if is_attacking: return

	if current_animation == "idle" and (
		Input.is_action_pressed("ui_left") or
		Input.is_action_pressed("ui_right") or
		Input.is_action_pressed("ui_up") or
		Input.is_action_pressed("ui_down")
	):
		current_animation = "walk"
	elif current_animation == "walk" and (
		!Input.is_action_pressed("ui_left") and
		!Input.is_action_pressed("ui_right") and
		!Input.is_action_pressed("ui_up") and
		!Input.is_action_pressed("ui_down")
	):
		current_animation = "idle"


func _input(event: InputEvent) -> void:
	if is_attacking or busy:
		return
		
	if event is InputEventMouseButton:
		if event.is_pressed():
			var target_scale = %FinalTexture.scale
			var is_cursor_over_hot_area = get_parent().get_global_rect().has_point(event.global_position)
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if is_cursor_over_hot_area:
					target_scale = (%FinalTexture.scale * 1.15).clamp(Vector2.ONE, Vector2(5.5, 5.5))
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if is_cursor_over_hot_area:
					target_scale = (%FinalTexture.scale * 0.85).clamp(Vector2.ONE, Vector2(5.5, 5.5))
			
			if target_scale != %FinalTexture.scale:
				if zoom_tween:
					zoom_tween.kill()
				zoom_tween = create_tween()
				zoom_tween.tween_property(%FinalTexture, "scale", target_scale, 0.075)
	elif event.is_action_pressed("ui_left"):
		current_direction = DIRECTIONS.LEFT
	elif event.is_action_pressed("ui_right"):
		current_direction = DIRECTIONS.RIGHT
	elif event.is_action_pressed("ui_up"):
		current_direction = DIRECTIONS.UP
	elif event.is_action_pressed("ui_down"):
		current_direction = DIRECTIONS.DOWN
	elif event.is_action_pressed("ui_select"):
		if current_data.weapon_data.actions:
			var action = current_data.weapon_data.actions[randi() % current_data.weapon_data.actions.size()]
			attack_with_weapon(action)
	else:
		var keys = {
			KEY_1: "cast", KEY_2: "slash", KEY_3: "islash", KEY_4: "thrust", KEY_5: "smash", KEY_6: "shoot"
		}
		for key in keys:
			if Input.is_key_pressed(key):
				if current_data.weapon_data.actions:
					if current_data.weapon_data.actions.has(keys[key]):
						attack_with_weapon(keys[key])
				else:
					current_animation = keys[key]
					current_frame = -1
					is_attacking = true
					attack.emit(current_animation)


func attack_with_weapon(action: String, start_in_frame: int = -1, play_sound: bool = true) -> void:
	current_animation = action

	if current_animation == "fish_throw":
		current_animation = "fish_full_animation"
	elif play_sound and current_animation == "shoot":
		var fx = ResourceLoader.load("res://addons/rpg_character_creator/sounds/bow_draw.ogg")
		var audio_stream_player = AudioStreamPlayer.new()
		audio_stream_player.stream = fx
		audio_stream_player.finished.connect(func(): audio_stream_player.queue_free())
		add_child(audio_stream_player)
		audio_stream_player.play()

	if play_sound and current_data.weapon_data.get("sounds", null):
		var sound_path = current_data.weapon_data.sounds[randi() % current_data.weapon_data.sounds.size()]
		sound_path = "res://addons/rpg_character_creator/" + sound_path
		if ResourceLoader.exists(sound_path):
			var fx = ResourceLoader.load(sound_path)
			var audio_stream_player = AudioStreamPlayer.new()
			audio_stream_player.stream = fx
			audio_stream_player.finished.connect(func(): audio_stream_player.queue_free())
			add_child(audio_stream_player)
			audio_stream_player.play()
			
	current_frame = start_in_frame
	is_attacking = true
	if current_animation != "fish_full_animation":
		attack.emit(current_animation)
	else:
		attack.emit("fish")


func show_preview_attack_pose() -> void:
	if current_data.weapon_data.actions:
		var action = current_data.weapon_data.actions[randi() % current_data.weapon_data.actions.size()]
		attack_with_weapon(action, 1, false)
		run_animation()
		show_weapon()


func create_viewport_textures() -> void:
	for child in %ViewportTextures.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
		
	var layers = [
		"WingsBack", "MainHandBack", "OffHandBack", "AmmoBack", "BackBack", "TailBack", "Body",
		"Add2", "Suit", "Pants", "Shoes", "Gloves", "Shirt", "Belt", "Add3", "Jacket", "Head",
		"Eyes", "Facial", "Ears", "Nose", "Add1", "Mask", "Glasses", "Hair", "HairAdd", "Hat",
		"TailFront", "BackFront", "WingsFront", "Horns", "OffHandFront", "MainHandFront", "AmmoFront"
	]
	for key in layers:
		var t = PART_TEXTURE.instantiate()
		var atlas = AtlasTexture.new()
		atlas.region = Rect2(0, 0, 64, 64)
		var mat = ShaderMaterial.new()
		mat.shader = COLORIZE
		t.texture = atlas
		t.material = mat
		t.name = key
		if key == "AmmoBack":
			%AmmoPreviewSavePartTexture.material = mat
		%ViewportTextures.add_child(t)


func fix_data() -> void:
	var parts = ["ammo", "back", "mainhand", "offhand", "wings"]
	
	for part in parts:
		var textures = get_textures_with_id(part)
		for i in range(1, textures.size(), 1):
			textures[i].material = textures[0].material
		var real_parts = get_character_parts_for(part)
		for i in range(1, real_parts.size(), 1):
			real_parts[i].palette1 = real_parts[0].palette1
			real_parts[i].palette2 = real_parts[0].palette2
			real_parts[i].palette3 = real_parts[0].palette3


func apply_ammo_palette(pal1: Dictionary, pal2: Dictionary, pal3: Dictionary) -> void:
	var texture_rect = %AmmoPreviewSavePartTexture
	
	if !texture_rect: return
	
	var mat: ShaderMaterial = texture_rect.get_material()
	
	if !mat or !mat.shader: return
	
	mat.set_shader_parameter("palette1", get_gradient(pal1.colors))
	mat.set_shader_parameter("palette2", get_gradient(pal2.colors))
	mat.set_shader_parameter("palette3", get_gradient(pal3.colors))
	mat.set_shader_parameter("lightness1", pal1.lightness)
	mat.set_shader_parameter("lightness2", pal2.lightness)
	mat.set_shader_parameter("lightness3", pal3.lightness)


func set_items_visibility(items_hiddens: Array, items_setted: Array) -> void:
	for texture: TextureRect in %ViewportTextures.get_children():
		if texture.name.to_lower().find("mainhand") != -1:
			var texture_data = current_data.textures["mainhand_texture_front"]
			if texture_data.item_id == "boomerang":
				texture.visible = false
				continue
			
		var is_visible = true
		var texture_name = texture.name.to_lower()
		for item_id in items_hiddens:
			if texture_name.begins_with(item_id):
				is_visible = false
				break
		if is_visible:
			for item_id in items_setted:
				if texture_name.begins_with(item_id):
					is_visible = false
					break
			
		texture.visible = is_visible


func refresh() -> void:
	update_texture_timer = 0.15


func get_current_animation() -> Dictionary:
	if !animations:
		return {}
	
	var id = current_animation
	var animation_id = id.to_lower() + "_" + str(DIRECTIONS.find_key(current_direction)).to_lower()
	var current_animation = {}
	for animation in animations.player:
		if animation.id == animation_id:
			current_animation = animation
			break
		
	return current_animation


func get_current_weapon_animation() -> Dictionary:
	if !animations:
		return {}
		
	var animation_id = current_animation.to_lower() + "_" + str(DIRECTIONS.find_key(current_direction)).to_lower()
	if ["dagger2"].has(current_data.textures.mainhand_texture_front.item_id) and ["idle", "walk"].has(current_animation.to_lower()):
		animation_id = "small_" + animation_id

	var current_animation = {}

	for animation in animations.weapon:
		if animation.id == animation_id:
			current_animation = animation
			break

	return current_animation


func update_textures() -> void:
	if current_data:
		for texture_data: CharacterPart in current_data.textures.values():
			update_texture(texture_data)


# En el script principal del Editor (donde tienes _on_palette_changed, etc.)

func apply_palettes_to_part(part_id: String, palettes: Dictionary) -> void:
	var ids = ["%s_texture_back" % part_id, "%s_texture" % part_id, "%s_texture_front" % part_id]
	
	if current_data:
		for id in ids:
			var tex: CharacterPart = current_data.textures.get(id)
			if tex:
				tex.palette1.lightness = palettes.get("lightness1", tex.palette1.lightness)
				tex.palette2.lightness = palettes.get("lightness2", tex.palette2.lightness)
				tex.palette3.lightness = palettes.get("lightness3", tex.palette3.lightness)

				if palettes.has("palette1"):
					tex.palette1.colors = palettes.palette1.duplicate()
					tex.palette1.blend_color = palettes.get("blend_color1", tex.palette1.blend_color)
					tex.palette1.item_selected = -2 
				
				if palettes.has("palette2"):
					tex.palette2.colors = palettes.palette2.duplicate()
					tex.palette2.blend_color = palettes.get("blend_color2", tex.palette2.blend_color)
					tex.palette2.item_selected = -2
					
				if palettes.has("palette3"):
					tex.palette3.colors = palettes.palette3.duplicate()
					tex.palette3.blend_color = palettes.get("blend_color3", tex.palette3.blend_color)
					tex.palette3.item_selected = -2
					
				update_texture(tex)



func get_gradient(current_data_color: Array) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray([])
	colors.resize(256)
	
	if current_data_color.size() > 0:
		for i in range(0, current_data_color.size(), 2):
			var index = int(current_data_color[i])
			var color = Color(int(current_data_color[i+1]))
			colors[index] = color
		
	return colors


func get_textures_with_id(part_id: String) -> Array:
	var textures := []
	for child in %ViewportTextures.get_children():
		if [part_id, part_id + "back", part_id + "front"].has(child.name.to_lower()):
			textures.append(child)

	return textures


func get_character_parts_for(part_id: String) -> Array:
	var parts := []
	if current_data:
		for key in current_data.textures.keys():
			if key.begins_with(part_id):
				parts.append(current_data.textures[key])
		
	return parts


func update_texture(texture_data: CharacterPart) -> void:
	if update_texture_timer > 0.0:
		return
	
	var target_textures = get_textures_with_id(texture_data.part_id)
	var current_animation = get_current_animation()
	var current_weapon_animation = get_current_weapon_animation()
	if target_textures:
		for texture in target_textures:
			var mat: ShaderMaterial = texture.get_material()
			mat.set_shader_parameter("palette1", get_gradient(texture_data.palette1.colors))
			mat.set_shader_parameter("palette2", get_gradient(texture_data.palette2.colors))
			mat.set_shader_parameter("palette3", get_gradient(texture_data.palette3.colors))
			mat.set_shader_parameter("lightness1", texture_data.palette1.lightness)
			mat.set_shader_parameter("lightness2", texture_data.palette2.lightness)
			mat.set_shader_parameter("lightness3", texture_data.palette3.lightness)
			if "texture" in texture_data and texture_data.texture:
				
				if (
					(texture.name.ends_with("Back") and texture_data.id == "back") or
					(texture.name.ends_with("Front") and texture_data.id == "front") or
					texture_data.id == "normal"
				):
					texture.texture.atlas = texture_data.texture
				
				if texture_data.is_large_texture:
					texture.texture.region.size = Vector2(192, 192)
					var frame = [0, 0]
					if current_weapon_animation and "frames" in current_weapon_animation:
						frame = current_weapon_animation.frames[current_frame if current_weapon_animation.frames.size() > current_frame else 0]
					texture.texture.region.position = Vector2(frame[0], frame[1])
					texture.size = Vector2(192, 192)
					texture.position = Vector2.ZERO
				else:
					texture.texture.region.size = Vector2(64, 64)
					if current_animation:
						var frame: Array = current_animation.frames[current_frame if current_animation.frames.size() > current_frame else 0]
						texture.texture.region.position = Vector2(frame[0], frame[1])
					texture.size = Vector2(64, 64)
					texture.position = Vector2(64, 64)
			else:
				texture.texture.atlas = null
			
			texture.visible = !texture_data.item_id == "boomerang"
			
			if texture.name == "Add3":
				for t in %ViewportTextures.get_children():
					if ["Shoes", "Body", "Suit", "Pants"].has(t.name):
						mat = t.get_material()
						mat.set_shader_parameter("mask1", texture.texture)


func refresh_texture(data_colors: Dictionary) -> void:
	var target_textures = get_textures_with_id(data_colors.part_id)
	if target_textures:
		for texture in target_textures:
			var mat: ShaderMaterial = texture.get_material()
			mat.set_shader_parameter("palette1", get_gradient(data_colors.palette1.colors))
			mat.set_shader_parameter("palette2", get_gradient(data_colors.palette2.colors))
			mat.set_shader_parameter("palette3", get_gradient(data_colors.palette3.colors))
			mat.set_shader_parameter("lightness1", data_colors.palette1.lightness)
			mat.set_shader_parameter("lightness2", data_colors.palette2.lightness)
			mat.set_shader_parameter("lightness3", data_colors.palette3.lightness)


func set_texture(part_id, texture_data: Dictionary) -> void:
	var target_textures = get_textures_with_id(part_id)
	for t in target_textures:
		var texture_path = ""
		if t.name.ends_with("Back"):
			texture_path = texture_data.get("back", "")
		else:
			texture_path = texture_data.get("front", "")
		texture_path = "res://addons/rpg_character_creator/" + texture_path
		if ResourceLoader.exists(texture_path):
			t.texture.atlas = ResourceLoader.load(texture_path)
			if _is_large_texture(t.texture.atlas):
				t.texture.region.size = Vector2(192, 192)
				t.size = Vector2(192, 192)
				t.position = Vector2(0, 0)
			else:
				t.texture.region.size = Vector2(64, 64)
				t.size = Vector2(64, 64)
				t.position = Vector2(64, 64)
			t.texture.region.position = Vector2(0, 0)
		else:
			t.texture.atlas = null


func set_ammo_preview_texture(texture: Texture, region_rect: Rect2) -> void:
	%AmmoPreviewSavePartTexture.texture.atlas = texture
	%AmmoPreviewSavePartTexture.texture.region = region_rect
	%AmmoPreviewSavePartTexture.size = region_rect.size
	%AmmoPreviewSavePart.size = region_rect.size


func get_ammo_preview_texture() -> Texture:
	return %AmmoPreviewSavePart.get_texture()


func _is_large_texture(texture: Texture) -> bool:
	if !texture:
		return false
	
	var texture_size = Vector2i(texture.get_size())
	if texture_size.x % 192 != 0:
		return false
		
	var height = texture_size.y
	
	if height == 192:
		return true
	
	for rows in range(4, height + 1, 4):
		if height % rows == 0:
			var frame_height = height / rows
			if frame_height == 192:
				return true
	
	return false


func perform_shoot(ammo_id: String, direction: String, ammo_position: Vector2) -> void:
	var p = PROJECTILES.get(ammo_id, "")
	if p:
		var blend_color = int(current_data.textures.ammo_texture_back.palette1.blend_color)
		var obj = p.instantiate()
		var target_textures = get_textures_with_id("ammo")
		obj.material = target_textures[0].material.duplicate(true)
		if direction == "up":
			obj.show_behind_parent = true
		obj.set_blend_color(blend_color)
		%FinalTexture.add_child(obj)
		obj.position = ammo_position + %FinalTexture.size * 0.5
		if ammo_id == "bolt":
			var x = 0
			var y = 0
			if direction == "down":
				x += -6
			elif direction == "left" or direction == "right":
				y += 10
			elif direction == "up":
				x += 6
			obj.position += Vector2(x, y)
		obj.set_direction(direction)
		var audio_path = "res://addons/rpg_character_creator/sounds/swosh-01.ogg" if ammo_id == "arrow" else \
		"res://addons/rpg_character_creator/sounds/swosh-03.ogg" if ammo_id == "bolt" else \
		"res://addons/rpg_character_creator/sounds/swosh-05.ogg" if ammo_id == "rock" else \
		"res://addons/rpg_character_creator/sounds/spell1.ogg" if ammo_id == "arcane1" else \
		""
		if audio_path:
			var fx = ResourceLoader.load(audio_path)
			var audio_stream_player = AudioStreamPlayer.new()
			audio_stream_player.stream = fx
			audio_stream_player.finished.connect(func(): audio_stream_player.queue_free())
			add_child(audio_stream_player)
			audio_stream_player.play()


func set_highlight_color(part_id: String, palette_id: int, color_id: int) -> void:
	var texture_parts = get_textures_with_id(part_id)
	for texture in texture_parts:
		var mat: ShaderMaterial = texture.get_material()
		mat.set_shader_parameter("highlight_color", color_id)
		mat.set_shader_parameter("highlight_palette_id", palette_id)


func get_texture_visibility() -> Array[bool]:
	var visibility_array: Array[bool] = []
	for child in %ViewportTextures.get_children():
		visibility_array.append(child.visible)
	
	return visibility_array


func restore_texture_visibility(visibility_array: Array[bool]) -> void:
	var children = %ViewportTextures.get_children()
	for i in children.size():
		if visibility_array.size() > i:
			children[i].visible = visibility_array[i]
		else:
			children[i].visible = true


func get_current_animation_state() -> Dictionary:
	var state = {
		"current_animation": current_animation,
		"current_frame": current_frame,
		"current_direction": current_direction,
		"frame_delay": frame_delay,
		"is_attacking": is_attacking
	}
	
	return state


func restore_animation_state(state: Dictionary) -> void:
	current_animation = state.get("current_animation", "idle")
	current_frame = state.get("current_frame", -1)
	current_direction = state.get("current_direction", DIRECTIONS.DOWN)
	frame_delay = state.get("frame_delay", 0.0)
	is_attacking = state.get("is_attacking", false)


func hide_weapon() -> void:
	var items = ["MainHandBack", "MainHandFront", "AmmoBack", "AmmoFront", "OffHandBack", "OffHandFront"]
	
	for item in items:
		%ViewportTextures.get_node(item).visible = false


func show_weapon() -> void:
	var items = ["MainHandBack", "MainHandFront", "AmmoBack", "AmmoFront", "OffHandBack", "OffHandFront"]
	
	for item in items:
		%ViewportTextures.get_node(item).visible = true


func hide_all() -> void:
	for child in %ViewportTextures.get_children():
		child.visible = false


func show_parts_with_id(part_id) -> void:
	var textures = get_textures_with_id(part_id)
	for texture in textures:
		texture.visible = true


func get_face() -> Image:
	var img: Image = %FinalTexture.texture.get_image()
	
	return img.get_region(Rect2(0, 0, img.get_width(), img.get_height() * 0.53))


func get_full_character() -> Image:
	var img: Image = %FinalTexture.texture.get_image()
	
	return img


func reset_animation(direction: DIRECTIONS = DIRECTIONS.DOWN) -> void:
	is_attacking = false
	current_direction = direction
	frame_delay = 0.0
	current_animation = "idle"
	current_frame = -1
	run_animation()
	current_frame = -1
