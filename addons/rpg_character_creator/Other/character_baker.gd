class_name CharacterBaker
extends Node2D

## Emitted when the full character update is finished.
signal character_baked(id: String)

## Emitted when the weapon batch process is finished.
signal weapon_baked(id: String, result: Dictionary)


#region Database Cache
# database: { "hair": { "afro": "res://.../afro.hair", ... }, "body": { ... } }
var _part_database: Dictionary = {}
var _is_database_loaded: bool = false
#endregion


@onready var vp_wings: SubViewport = %WingsBack
@onready var vp_offhand_back: SubViewport = $OffhandBack
@onready var vp_weapon_back: SubViewport = %WeaponBack
@onready var vp_body: SubViewport = %Body
@onready var vp_offhand_front: SubViewport = $OffHandFront
@onready var vp_weapon_front: SubViewport = %WeaponFront


const BODY_KEYS = [
	"body", "head", "eyes", "wings", "tail", "horns",
	"hair", "hairadd", "ears", "nose", "facial",
	"add1", "add2", "add3"
]

const CLOTHING_KEYS = [
	"back", "shoes", "pants", "shirt", "gloves", "belt", 
	"suit", "jacket", "glasses", "mask", "hat", "ammo"
]

const MAINHAND_KEYS = ["mainhand"]
const OFFHAND_KEYS = ["offhand"]


var _queue: Array[Dictionary] = []
var _is_baking: bool = false


func _ready() -> void:
	_ensure_database_loaded()


## Queues a request to bake the character and update specific Sprite2D nodes.
func request_bake_character(id: String, data: RPGLPCCharacter, weapon_anim: String, 
		target_wings: Sprite2D, 
		target_off_back: Sprite2D,
		target_wb: Sprite2D, 
		target_body: Sprite2D, 
		target_off_front: Sprite2D,
		target_wf: Sprite2D,
		actor_id: int = -1) -> void:

	_queue.append({
		"type": "character",
		"id": id,
		"data": data,
		"anim": weapon_anim,
		"target_wings": target_wings,
		"target_off_back": target_off_back,
		"target_wb": target_wb,
		"target_body": target_body,
		"target_off_front": target_off_front,
		"target_wf": target_wf,
		"actor_id": actor_id
	})
	_process_queue()


## Queues a request to bake a list of weapon animations.
func request_bake_weapon(id: String, data: RPGLPCCharacter, animations: Array, result_map: Dictionary, actor_id: int = -1) -> void:
	_queue.append({
		"type": "weapon_batch",
		"id": id,
		"data": data,
		"anims": animations,
		"target": result_map,
		"actor_id": actor_id
	})
	_process_queue()


func _process_queue() -> void:
	if _is_baking or _queue.is_empty():
		return
	
	_is_baking = true
	var task = _queue.pop_front()
	match task.type:
		"character":
			await _bake_character_internal(task)
		"weapon_batch":
			await _bake_weapon_batch_internal(task)
	
	await RenderingServer.frame_post_draw
	
	_is_baking = false
	
	if not _queue.is_empty():
		_process_queue()


func _bake_character_internal(task: Dictionary) -> void:
	var data: RPGLPCCharacter = _get_updated_character_data(task.data, task.actor_id)
	
	_clear_viewport(vp_wings)
	_clear_viewport(vp_offhand_back)
	_clear_viewport(vp_weapon_back)
	_clear_viewport(vp_body)
	_clear_viewport(vp_offhand_front)
	_clear_viewport(vp_weapon_front)
	
	_setup_wings_viewport(data)
	_setup_body_viewport(data)
	
	_setup_specific_weapon_viewports(data, task.anim, OFFHAND_KEYS, vp_offhand_back, vp_offhand_front)
	_setup_specific_weapon_viewports(data, task.anim, MAINHAND_KEYS, vp_weapon_back, vp_weapon_front)
	
	_apply_visibility_rules(data)
	
	vp_wings.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_offhand_back.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_body.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_offhand_front.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_weapon_front.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	await RenderingServer.frame_post_draw
	
	_update_sprite(task.target_wings, _get_img(vp_wings))
	_update_sprite(task.target_off_back, _get_img(vp_offhand_back))
	_update_sprite(task.target_wb, _get_img(vp_weapon_back))
	_update_sprite(task.target_body, _get_img(vp_body))
	_update_sprite(task.target_off_front, _get_img(vp_offhand_front))
	_update_sprite(task.target_wf, _get_img(vp_weapon_front))
	
	character_baked.emit(task.id)


func _bake_weapon_batch_internal(task: Dictionary) -> void:
	var data: RPGLPCCharacter = _get_updated_character_data(task.data, task.actor_id)
	var animations: Array = task.anims
	var results: Dictionary = task.target
	
	for anim in animations:
		_clear_viewport(vp_weapon_back)
		_clear_viewport(vp_weapon_front)
		
		_setup_specific_weapon_viewports(data, anim, MAINHAND_KEYS, vp_weapon_back, vp_weapon_front)
		
		_apply_visibility_rules(data, true)
		
		vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp_weapon_front.render_target_update_mode = SubViewport.UPDATE_ONCE
		
		await RenderingServer.frame_post_draw
		
		results[anim] = {
			"back": _get_img(vp_weapon_back),
			"front": _get_img(vp_weapon_front)
		}

	var ammo_part = data.equipment_parts.get("ammo")
	if ammo_part:
		_clear_viewport(vp_weapon_back)
		_clear_viewport(vp_weapon_front)
		
		var ammo_paths = _get_weapon_paths_for_animation(ammo_part, "walk")
		
		_apply_single_weapon_layer(vp_weapon_back, "mainhandBack", ammo_part, ammo_paths.back)
		_apply_single_weapon_layer(vp_weapon_front, "mainhandFront", ammo_part, ammo_paths.front)
		
		_apply_visibility_rules(data, true)
		
		vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp_weapon_front.render_target_update_mode = SubViewport.UPDATE_ONCE
		
		await RenderingServer.frame_post_draw
		
		results["ammo"] = {
			"back": _get_img(vp_weapon_back),
			"front": _get_img(vp_weapon_front)
		}
		
		var projectile_id = _get_projectile_id_from_part(ammo_part)
		
		if projectile_id != "":
			_clear_viewport(vp_weapon_back)
			var proj_path = "res://addons/rpg_character_creator/textures/projectiles/" + projectile_id + ".png"
			_apply_single_weapon_layer(vp_weapon_back, "mainhandBack", ammo_part, proj_path)
			_apply_visibility_rules(data, true)
			
			vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			
			var tex_proj = _get_img(vp_weapon_back)
			results["projectile"] = {
				"back": tex_proj,
				"front": tex_proj 
			}
	
	weapon_baked.emit(task.id, results)


#region Database Logic
func _ensure_database_loaded() -> void:
	if _is_database_loaded:
		return
		
	var character_parts = BODY_KEYS
	for key in character_parts:
		var path = "res://addons/rpg_character_creator/Data/character/%s/" % key
		_part_database[key] = _scan_folder_for_ids(path)
		
	var gear_parts = CLOTHING_KEYS + MAINHAND_KEYS + OFFHAND_KEYS
	for key in gear_parts:
		var path = "res://addons/rpg_character_creator/Data/gear/%s/" % key
		_part_database[key] = _scan_folder_for_ids(path)

	_is_database_loaded = true


func _scan_folder_for_ids(folder_path: String) -> Dictionary:
	var result = {}
	var dir = DirAccess.open(folder_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Ignore unix navigation
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue
				
			if dir.current_is_dir():
				# RECURSIVE: Go deeper into subfolders
				var sub_path = folder_path.path_join(file_name)
				var sub_result = _scan_folder_for_ids(sub_path)
				result.merge(sub_result)
			else:
				# Ignore .import files, assume everything else might be a readable JSON/data file
				if not file_name.ends_with(".import"):
					var full_path = folder_path.path_join(file_name)
					
					var f = FileAccess.open(full_path, FileAccess.READ)
					if f:
						var json_text = f.get_as_text()
						var data = JSON.parse_string(json_text)
						f.close()
						
						if data and data is Dictionary and "id" in data:
							result[data["id"]] = full_path
							
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	return result
#endregion


## Checks if the actor has specific gear equipped and updates the character data accordingly.
## Respects 'inmutable' flag and supports MultiPart/Outfit items.
func _get_updated_character_data(base_data: RPGLPCCharacter, actor_id: int) -> RPGLPCCharacter:
	_ensure_database_loaded()
	
	if actor_id == -1: return base_data
	var actor = GameManager.get_actor(actor_id)
	if not actor: return base_data
		
	var new_data = base_data.duplicate()
	
	# 1. Equip Gear (Only if mutable)
	if not new_data.inmutable:
		_apply_actor_gear(new_data, actor)

	# 2. Apply Rules (Hidden & Alt) - Always runs to ensure visual consistency
	_apply_special_rules(new_data)

	return new_data


#region Updated Character Data Helpers

# --------------------------------------------------------------------------
# 1. Gear Application Logic
# --------------------------------------------------------------------------
func _apply_actor_gear(character_data: RPGLPCCharacter, actor: Variant) -> void:
	var ammo_context = {
		"explicitly_equipped": false,
		"weapon_embedded": null
	}
	
	for item_obj in actor.current_gear:
		if not item_obj: continue
		
		var db_item = null
		if item_obj.type == 1: db_item = RPGSYSTEM.database.weapons.get(item_obj.id)
		elif item_obj.type == 2: db_item = RPGSYSTEM.database.armors.get(item_obj.id)
		
		if not db_item: continue
		var lpc_path: String = db_item.lpc_part
		if lpc_path.is_empty() or not FileAccess.file_exists(lpc_path): continue
		
		var resource = load(lpc_path)
		_equip_resource(character_data, resource, ammo_context)

	# Apply inferred ammo logic
	if not ammo_context.explicitly_equipped and ammo_context.weapon_embedded:
		character_data.equipment_parts.set("ammo", ammo_context.weapon_embedded)


func _equip_resource(character_data: RPGLPCCharacter, resource: Resource, ammo_context: Dictionary) -> void:
	# CASE A: INGAME COSTUME (Full Aspect / Mode 3)
	if resource is IngameCostume:
		character_data.body_parts = resource.body_parts.duplicate(true)
		
		character_data.equipment_parts = resource.equipment_parts.duplicate(true)
		
		character_data.hidden_items = resource.hidden_items.duplicate()
		
		var mainhand = character_data.equipment_parts.get("mainhand")
		var ammo = character_data.equipment_parts.get("ammo")
		
		ammo_context.explicitly_equipped = (ammo != null)
		if mainhand and mainhand.ammo:
			ammo_context.weapon_embedded = mainhand.ammo
		else:
			ammo_context.weapon_embedded = null
			
		return
		
	# CASE B: MULTIPART / OUTFIT
	elif resource is RPGLPCEquipmentData:
		var mode = resource.get("application_mode")
		if mode == null: mode = 0
		
		var slots = CLOTHING_KEYS + MAINHAND_KEYS + OFFHAND_KEYS
		var weapon_slots = ["mainhand", "offhand", "ammo"]
		
		for slot_key in slots:
			var part = resource.get(slot_key)
			var has_valid_part = part and part is RPGLPCEquipmentPart and not part.config_path.is_empty()
			
			match mode:
				0: # FULL_STRICT
					if has_valid_part:
						_try_equip_single_part(character_data, part, ammo_context)
					else:
						character_data.equipment_parts.set(slot_key, null)
				
				1: # FULL_HYBRID
					if has_valid_part:
						_try_equip_single_part(character_data, part, ammo_context)
					else:
						if slot_key in weapon_slots:
							pass 
						else:
							character_data.equipment_parts.set(slot_key, null)
				
				2: # PARTIAL
					if has_valid_part:
						_try_equip_single_part(character_data, part, ammo_context)
					else:
						pass

	# CASE C: SINGLE PART
	elif resource is RPGLPCEquipmentPart:
		_try_equip_single_part(character_data, resource, ammo_context)


func _try_equip_single_part(character_data: RPGLPCCharacter, part: RPGLPCEquipmentPart, ammo_context: Dictionary) -> void:
	if not part or part.config_path.is_empty(): return
	
	var target_part_id = part.part_id
	var final_part = part
	
	# Check Compatibility
	if part.body_type != character_data.body_type or part.head_type != character_data.head_type:
		var json_data = _get_json_data(part.config_path)
		var best_match = _find_best_texture_match(json_data, character_data.body_type, character_data.head_type)
		
		if best_match:
			final_part = part.duplicate()
			final_part.body_type = character_data.body_type
			final_part.head_type = character_data.head_type
			final_part.front_texture = _resolve_path(best_match.get("front", ""))
			final_part.back_texture = _resolve_path(best_match.get("back", ""))

	# Assign to character
	character_data.equipment_parts.set(target_part_id, final_part)
	
	# Update Ammo Context
	if target_part_id == "ammo":
		ammo_context.explicitly_equipped = true
	elif target_part_id == "mainhand" and part.ammo:
		ammo_context.weapon_embedded = part.ammo


# --------------------------------------------------------------------------
# 2. Rules Application Logic (Hidden & Alt)
# --------------------------------------------------------------------------
func _apply_special_rules(character_data: RPGLPCCharacter) -> void:
	var active_hidden_slots = []
	var active_alt_slots = []
	var all_equipment_keys = CLOTHING_KEYS + MAINHAND_KEYS + OFFHAND_KEYS
	
	# Collect rules from current equipment
	for key in all_equipment_keys:
		var part = character_data.equipment_parts.get(key)
		if not part or not (part is RPGLPCEquipmentPart): continue
		if part.config_path.is_empty() or not FileAccess.file_exists(part.config_path): continue
		
		var json_data = _get_json_data(part.config_path)
		if not json_data: continue
		
		if json_data.has("slotshidden"): active_hidden_slots.append_array(json_data.slotshidden)
		if json_data.has("slotsalt"): active_alt_slots.append_array(json_data.slotsalt)

	# Apply Hidden
	character_data.hidden_items.append_array(active_hidden_slots)
	
	# Apply Alt
	for target_id in active_alt_slots:
		_apply_alt_modification(character_data, target_id)


func _apply_alt_modification(character_data: RPGLPCCharacter, target_part_id: String) -> void:
	# Find target resource (Body vs Equipment)
	var target_resource = null
	var is_body_part = false
	
	var body_check = character_data.body_parts.get(target_part_id)
	if body_check and (body_check is RPGLPCBodyPart):
		target_resource = body_check
		is_body_part = true
	else:
		var equip_check = character_data.equipment_parts.get(target_part_id)
		if equip_check and (equip_check is RPGLPCEquipmentPart):
			target_resource = equip_check
			is_body_part = false
			
	if not target_resource or target_resource.config_path.is_empty(): return

	# Get Alt ID from current config
	var current_json = _get_json_data(target_resource.config_path)
	if not current_json or not current_json.has("alt"): return
	
	var alt_id = current_json.alt
	
	# Find Alt File in DB
	var alt_path = ""
	if _part_database.has(target_part_id) and _part_database[target_part_id].has(alt_id):
		alt_path = _part_database[target_part_id][alt_id]
	
	if alt_path == "" or not FileAccess.file_exists(alt_path): return
	
	# Load Alt Config and Match Textures
	var alt_json = _get_json_data(alt_path)
	var best_match = _find_best_texture_match(alt_json, character_data.body_type, character_data.head_type)
	
	if best_match:
		var modified_part = target_resource.duplicate()
		modified_part.front_texture = _resolve_path(best_match.get("front", ""))
		modified_part.back_texture = _resolve_path(best_match.get("back", ""))
		modified_part.config_path = alt_path
		
		if is_body_part:
			character_data.body_parts.set(target_part_id, modified_part)
		else:
			character_data.equipment_parts.set(target_part_id, modified_part)


# --------------------------------------------------------------------------
# 3. Shared Utilities
# --------------------------------------------------------------------------
func _find_best_texture_match(json_data: Dictionary, body_type: String, head_type: String) -> Dictionary:
	if not json_data or not "textures" in json_data: return {}
	
	for t in json_data.textures:
		# If "body" key is missing, default to current char body (for files like .hair)
		var t_body = t.get("body", body_type)
		var t_head = t.get("head", head_type)
		
		# Match logic: Exact match OR Body matches Head (special cases)
		if (t_body == body_type and t_head == head_type) or t_body == t_head:
			return t
	return {}


func _resolve_path(p: String) -> String:
	if p.is_empty(): return ""
	if p.begins_with("res://"): return p
	return "res://addons/rpg_character_creator/" + p

#endregion


func _get_json_data(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return {}
	var text = f.get_as_text()
	f.close()
	var result = JSON.parse_string(text)
	return result if result else {}


func _get_projectile_id_from_part(part: RPGLPCEquipmentPart) -> String:
	var json_data = _get_json_data(part.config_path)
	if json_data and "projectile" in json_data:
		return json_data["projectile"]
	return ""


func _update_sprite(node: Sprite2D, texture: Texture2D) -> void:
	if is_instance_valid(node):
		node.texture = texture


func _get_img(vp: SubViewport) -> ImageTexture:
	return ImageTexture.create_from_image(vp.get_texture().get_image())


func _setup_wings_viewport(data: RPGLPCCharacter) -> void:
	if data.body_parts.get("wings"):
		_apply_texture_data(vp_wings, "wings", data.body_parts["wings"])


func _setup_body_viewport(data: RPGLPCCharacter) -> void:
	for key in BODY_KEYS:
		if data.body_parts.get(key):
			_apply_texture_data(vp_body, key, data.body_parts[key])
			
	for key in CLOTHING_KEYS:
		if data.equipment_parts.get(key):
			_apply_texture_data(vp_body, key, data.equipment_parts[key])


func _setup_specific_weapon_viewports(data: RPGLPCCharacter, animation_id: String, keys: Array, vp_back: SubViewport, vp_front: SubViewport) -> void:
	for key in keys:
		var part = data.equipment_parts.get(key)
		if part:
			var specific_textures = _get_weapon_paths_for_animation(part, animation_id)
			_apply_single_weapon_layer(vp_back, key + "Back", part, specific_textures.back)
			_apply_single_weapon_layer(vp_front, key + "Front", part, specific_textures.front)


func _apply_texture_data(viewport: SubViewport, part_id: String, part_data: Resource) -> void:
	var container = viewport.get_node_or_null("Container")
	if not container: container = viewport
	
	var found = false
	var node_back = _find_node_insensitive(container, part_id + "Back")
	if node_back:
		_setup_node(node_back, part_data, true, part_data.back_texture)
		found = true
		
	var node_front = _find_node_insensitive(container, part_id + "Front")
	if node_front:
		_setup_node(node_front, part_data, false, part_data.front_texture)
		found = true
		
	if not found:
		var node_single = _find_node_insensitive(container, part_id)
		if node_single:
			_setup_node(node_single, part_data, false, part_data.front_texture)
			found = true


func _apply_single_weapon_layer(viewport: SubViewport, node_name: String, part_data: Resource, texture_path: String) -> void:
	var container = viewport.get_node_or_null("Container")
	if not container: container = viewport
	
	var node = _find_node_insensitive(container, node_name)
	if node:
		if not ResourceLoader.exists(texture_path):
			_setup_node(node, part_data, false, texture_path)
			return
			
		var tex = load(texture_path)
		if tex:
			viewport.size = tex.get_size()
			
		_setup_node(node, part_data, false, texture_path)


func _setup_node(node: TextureRect, data: Variant, _is_back: bool, texture_path: String) -> void:
	if texture_path == "" or not ResourceLoader.exists(texture_path):
		node.visible = false
		return

	node.texture = load(texture_path)
	node.size = node.texture.get_size()
	node.position = Vector2.ZERO
	node.visible = true
	
	if node.material is ShaderMaterial:
		var mat = node.material as ShaderMaterial
		mat.set_shader_parameter("palette1", get_gradient(data.palette1.colors))
		mat.set_shader_parameter("palette2", get_gradient(data.palette2.colors))
		mat.set_shader_parameter("palette3", get_gradient(data.palette3.colors))
		mat.set_shader_parameter("lightness1", data.palette1.lightness)
		mat.set_shader_parameter("lightness2", data.palette2.lightness)
		mat.set_shader_parameter("lightness3", data.palette3.lightness)


func _get_weapon_paths_for_animation(part: RPGLPCEquipmentPart, animation_id: String) -> Dictionary:
	var paths = {"front": "", "back": ""}
	
	var json_data = _get_json_data(part.config_path)
	if not json_data:
		paths.front = part.front_texture
		paths.back = part.back_texture
		return paths
		
	var body_type = part.body_type
	var head_type = part.head_type
	
	var fix_path = func(p: String) -> String:
		if p.is_empty(): return ""
		if p.begins_with("res://"): return p
		return "res://addons/rpg_character_creator/" + p

	var generic_candidate = {"front": "", "back": ""}
	var found_specific = false

	for texture in json_data.get("textures", []):
		var t_body = texture.get("body", body_type)
		var t_head = texture.get("head", head_type)
		
		if t_body != body_type or t_head != head_type:
			continue
			
		var t_spriteset = texture.get("spritesheet", "")
		
		if t_spriteset != "" and t_spriteset.find(animation_id) != -1:
			paths.front = fix_path.call(texture.get("front", ""))
			paths.back = fix_path.call(texture.get("back", ""))
			found_specific = true
			break 
		
		if t_spriteset == "" or t_spriteset == "char_base":
			generic_candidate.front = fix_path.call(texture.get("front", ""))
			generic_candidate.back = fix_path.call(texture.get("back", ""))
	
	if not found_specific:
		if generic_candidate.front != "":
			paths.front = generic_candidate.front
		if generic_candidate.back != "":
			paths.back = generic_candidate.back
	
	return paths


func get_gradient(color_array: PackedInt64Array) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray([])
	colors.resize(256)
	if color_array.size() > 0:
		for i in range(0, color_array.size(), 2):
			var index = int(color_array[i])
			var color = Color(int(color_array[i+1]))
			colors[index] = color
	return colors


func _find_node_insensitive(parent: Node, partial_name: String) -> Node:
	for child in parent.get_children():
		if child.name.to_lower() == partial_name.to_lower():
			return child
	return null


func _clear_viewport(vp: SubViewport) -> void:
	if vp in [vp_offhand_back, vp_weapon_back, vp_offhand_front, vp_weapon_front]:
		vp.size = Vector2i(1, 1)
		
	var container = vp.get_node_or_null("Container")
	if not container: container = vp
	for child in container.get_children():
		if child is TextureRect:
			child.visible = false
			child.position = Vector2.ZERO


func _apply_visibility_rules(data: RPGLPCCharacter, force_weapon_visible: bool = false) -> void:
	if not data.always_show_weapon and not force_weapon_visible:
		var weapon_keys = ["mainhand", "ammo"]
		for key in weapon_keys:
			_set_nodes_visibility(key, false)
	
	for key in data.hidden_items:
		_set_nodes_visibility(key, false)


func _set_nodes_visibility(part_id: String, visible_state: bool) -> void:
	var viewports = [vp_wings, vp_offhand_back, vp_weapon_back, vp_body, vp_offhand_front, vp_weapon_front]
	var suffixes = ["", "Back", "Front"]
	
	for vp in viewports:
		var container = vp.get_node_or_null("Container")
		if not container:
			container = vp
		
		for suffix in suffixes:
			var target_name = part_id + suffix
			var node = _find_node_insensitive(container, target_name)
			if node:
				node.visible = visible_state
