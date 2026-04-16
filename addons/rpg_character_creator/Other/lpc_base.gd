class_name LPCBase
extends CharacterBase


func get_class() -> String: return "LPCBase"
func get_custom_class() -> String: return "LPCBase"


var force_disable_breathing: bool

## Preview Sprite Direction in the editor
@export_enum("Up", "Down", "Left", "Right") var preview_direction = 1 :
	set(value):
		preview_direction = value
		if is_node_ready():
			match value:
				2: current_direction = DIRECTIONS.LEFT
				3: current_direction = DIRECTIONS.RIGHT
				0: current_direction = DIRECTIONS.UP
				_: current_direction = DIRECTIONS.DOWN
			run_animation()


@onready var animations = {
	"player": RPGSYSTEM.player_animations_data.animations,
	"weapon": RPGSYSTEM.weapon_animations_data.animations
}
@onready var full_body: Marker2D = %FullBody
@onready var wings_back: Sprite2D = %WingsBack
@onready var offhand_back: Sprite2D = %OffhandBack
@onready var mainhand_back: Sprite2D = %MainHandBack
@onready var body: Sprite2D = %Body
@onready var offhand_front: Sprite2D = %OffhandFront
@onready var mainhand_front: Sprite2D = %MainHandFront

var ammo_node_back: Sprite2D
var ammo_node_front: Sprite2D


const PROJECTILES = {
	"arrow": preload("res://addons/rpg_character_creator/textures/projectiles/arrow.tscn"),
	"bolt": preload("res://addons/rpg_character_creator/textures/projectiles/bolt.tscn"),
	"rock": preload("res://addons/rpg_character_creator/textures/projectiles/rock.tscn"),
	"arcane1": preload("res://addons/rpg_character_creator/textures/projectiles/arcane1.tscn"),
	"boomerang": preload("res://addons/rpg_character_creator/textures/projectiles/boomerang.tscn")
}

var active_boomerang: Node2D = null
var projectile_scene: PackedScene = preload("uid://dvj1a75ikakfy")

var idle_tween: Tween

var current_data: Variant = null
var current_weapon_images: Dictionary = {}

var current_combat_action: Area2D = null

signal shoot_ammo(ammo_id: String, direction: String, ammo_position: Vector2)


# call only when character creator editor create it
func _build() -> void:
	if get_node_or_null("%FullBody") == null:
		var node = Marker2D.new()
		node.name = "FullBody"
		node.z_index = 1
		node.y_sort_enabled = true
		node.set_unique_name_in_owner(true)
		add_child(node)
		full_body = node
	
	var parent_node = get_node_or_null("%FullBody")
	var mat = CanvasItemMaterial.new()
	var sprites = ["%WingsBack", "%OffhandBack", "%MainHandBack", "%Body", "%OffhandFront", "%MainHandFront"]
	var parts = ["wings_back", "offhand_back", "mainhand_back", "body", "offhand_front", "mainhand_front"]
	for i in sprites.size():
		var node_sprite = get_node_or_null(sprites[i])
		if node_sprite == null:
			var sp = Sprite2D.new()
			sp.name = sprites[i].replace("%", "")
			sp.centered = true
			sp.region_enabled = true
			if i in [0, 2]:
				sp.material = mat
			sp.set_unique_name_in_owner(true)
			parent_node.add_child(sp)
			sp.position = Vector2(0, -32)
			set(parts[i], sp)
		else:
			set(parts[i], node_sprite)
	
	if get_node_or_null("%CollisionShape") == null:
		var node = CollisionShape2D.new()
		node.name = "CollisionShape"
		var shape = CapsuleShape2D.new()
		shape.radius = 5.0
		shape.height = 10.0
		node.shape = shape
		node.set_unique_name_in_owner(true)
		add_child(node)
		node.position = Vector2(0, -7)
	
	if get_node_or_null("%Bounds") == null:
		var node = Node2D.new()
		node.set_unique_name_in_owner(true)
		add_child(node)
	
	var marker_parent = get_node_or_null("%Bounds")
	var markers = ["%Down", "%Up", "%Left", "%Right"]
	var positions = [Vector2(0, 32), Vector2(0, 40), Vector2(0, 32), Vector2(16, 32)]
	for i in markers.size():
		var marker = markers[i]
		var p = positions[i]
		var node_marker = get_node_or_null(marker)
		if node_marker == null:
			var node = Marker2D.new()
			node.name = marker.replace("%", "")
			node.set_unique_name_in_owner(true)
			marker_parent.add_child(node)
			node.texture = ViewportTexture.new()
			node.texture.viewport_path = %ViewportTextures.get_path_to(self)
			node.position = p
		else:
			node_marker.position = p
	
	if get_node_or_null("%ContactArea") == null:
		var node = Area2D.new()
		node.name = "ContactArea"
		node.collision_layer = 7
		node.collision_mask = 7
		node.set_unique_name_in_owner(true)
		add_child(node)
	
	if get_node_or_null("%AreaShape") == null:
		var area_parent = get_node_or_null("%ContactArea")
		var node = CollisionShape2D.new()
		node.name = "AreaShape"
		node.debug_color = Color("#c172356b")
		var shape = RectangleShape2D.new()
		shape.size = Vector2(26, 26)
		node.shape = shape
		area_parent.add_child(node)
		node.position = Vector2(0, -13)


func _ready() -> void:
	if not Engine.is_editor_hint() and full_body and body:
		var s: Sprite2D = body.duplicate()
		s.name = "AmmoBack"
		s.region_enabled = true
		s.unique_name_in_owner = true
		full_body.add_child(s)
		
		ammo_node_back = s
		ammo_node_back.visible = false
		s = body.duplicate()
		s.name = "AmmoFront"
		s.region_enabled = true
		s.unique_name_in_owner = true
		full_body.add_child(s)
		ammo_node_front = s
		ammo_node_front.visible = false
	_setup_contact_shape()
	tree_entered.connect(_on_tree_entered)
	get_tree().create_timer(0.05).timeout.connect(set.bind("can_show_shadows", true))
	install_parts()
	adjust_bounds()
	if Engine.is_editor_hint():
		set_process(false)
		set_process_input(false)
	else:
		if movement_current_mode == MOVEMENTMODE.GRID:
			var current_maps = get_tree().get_nodes_in_group("rpgmap")
			if current_maps:
				var map: RPGMap = GameManager.current_map
				current_map_tile_size = map.tile_size

		animation_finished.connect(_on_animation_finished)
		attack.connect(_on_attack)
		calculate_grid_move_duration()
		set_process(true)
		set_process_input(true)
	
	super()


func _process(_delta: float) -> void:
	super(_delta)


func _setup_contact_shape() -> void:
	var node = get_node_or_null("%ContactArea")
	if node and GameManager.current_map:
		var tile_size: Vector2 = GameManager.get_map_tile_size()
		var collision_shape = node.get_child(0)
		var shape = collision_shape.shape
		shape.size = tile_size * 0.8
		collision_shape.position = Vector2(0, -shape.size.y / 2)
		if not node.area_entered.is_connected(_on_main_area_entered):
			node.area_entered.connect(_on_main_area_entered)
		node.set_meta("entity", self)
		collision_shape.set_meta("original_data", {"position": collision_shape.position, "shape_size": shape.size})


func _expand_contact_shape(direction: Vector2) -> void:
	var node = get_node_or_null("%ContactArea")
	if not node or not GameManager.current_map:
		return

	var tile_size: Vector2 = GameManager.get_map_tile_size()
	var collision_shape: CollisionShape2D = node.get_child(0)
	var shape: RectangleShape2D = collision_shape.shape

	var original_data = collision_shape.get_meta("original_data", null)
	if not original_data:
		return

	var original_size: Vector2 = original_data["shape_size"]
	var original_pos: Vector2 = original_data["position"]

	var expansion: Vector2 = tile_size * 0.4

	var new_size: Vector2 = original_size
	var new_pos: Vector2 = original_pos

	# --- HORIZONTAL ---
	if direction.x > 0:
		new_size.x += expansion.x
		new_pos.x += expansion.x / 2
	elif direction.x < 0:
		new_size.x += expansion.x
		new_pos.x -= expansion.x / 2

	# --- VERTICAL ---
	if direction.y > 0:
		new_size.y += expansion.y
		new_pos.y += expansion.y / 2
	elif direction.y < 0:
		new_size.y += expansion.y
		new_pos.y -= expansion.y / 2

	# Apply
	shape.size = new_size
	collision_shape.position = new_pos


func _reset_contact_shape() -> void:
	var node = get_node_or_null("%ContactArea")
	if not node:
		return

	var collision_shape: CollisionShape2D = node.get_child(0)
	var shape: RectangleShape2D = collision_shape.shape

	var original_data = collision_shape.get_meta("original_data", null)
	if not original_data:
		return

	shape.size = original_data["shape_size"]
	collision_shape.position = original_data["position"]


func _activate_event(entity: Node, list: Array[RPGEventCommand], entity_id: String, is_solid_contact: bool) -> void:
	if is_solid_contact:
		_reset(true)
		entity.look_at_event(self)
		
	var ev = {
		"obj": entity,
		"commands": list,
		"id": entity_id
	}
	var automatic_event: Array[Dictionary] = [ev]
	GameInterpreter.auto_start_automatic_events(automatic_event)
	entity._add_to_ignore(self)


func _on_main_area_entered(area: Area2D) -> void:
	var entity = null if not area.has_meta("entity") else area.get_meta("entity")
	
	if entity:
		if entity._has_ignore_entity(self): return
		var entity_page = entity.get("current_event_page")
		var entity_is_player = entity.is_in_group("player")
		var entity_is_solid = _is_solid(entity)
		var my = self
		var my_page = my.get("current_event_page")
		var my_is_player = my.is_in_group("player")
		var my_is_solid = _is_solid(self)
		
		var is_solid_contact = entity_is_solid and my_is_solid
		
		if entity_page:
			var entity_id = str(entity.get_rid()) + "-Page#" + str(entity_page._uniq_id)
			if my_is_player and not entity_is_player:
				var entity_page_launcher = entity_page.launcher
				if entity_page_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION]:
					_activate_event(entity, entity_page.list, entity_id, is_solid_contact)
			elif not entity_is_player and not my_is_player:
				var entity_page_launcher = entity_page.launcher
				if entity_page_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION]:
					if entity_page_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT:
						_activate_event(entity, entity_page.list, entity_id, is_solid_contact)
					else:
						var entity_page_id = entity_page.get("_uniq_id")
						var my_trigger_list = my_page.get("event_trigger_list")
						if entity_page_id in my_trigger_list:
							_activate_event(entity, entity_page.list, entity_id, is_solid_contact)


func _on_tree_entered() -> void:
	var map: RPGMap = GameManager.current_map
	if map:
		current_map_tile_size = map.tile_size


func install_parts() -> void:
	if not current_data: return
	
	var config_path: String = ""
	var actor_id = get_meta("actor_id") if has_meta("actor_id") else -1
	var weapon_res: Resource = null
	var equipped_ammo = null
	
	if is_in_group("player") and GameManager.game_state and not GameManager.game_state.current_party.is_empty():
		actor_id = GameManager.game_state.current_party[0]
		set_meta("actor_id", actor_id)
		
		var actor = GameManager.get_actor(actor_id)
		if actor:
			for item in actor.current_gear:
				if item and item.type == 1:
					var db_item = RPGSYSTEM.database.weapons.get(item.id)
					if db_item:
						if not db_item.lpc_part.is_empty() and AssetManager.exists(db_item.lpc_part):
							weapon_res = load(db_item.lpc_part)
						else:
							var new_path = "res://addons/rpg_character_creator/Data/gear/mainhand/error_sword.res"
							if AssetManager.exists(new_path):
								weapon_res = load(new_path)
					break
					
	var final_weapon_part = null
	var final_ammo_part = null
	
	if weapon_res:
		final_weapon_part = weapon_res.duplicate()
		final_weapon_part.body_type = current_data.body_type
		final_weapon_part.head_type = current_data.head_type
		
		if "config_path" in final_weapon_part:
			config_path = final_weapon_part.config_path
		if "ammo" in final_weapon_part and final_weapon_part.ammo:
			final_ammo_part = final_weapon_part.ammo.duplicate()
			final_ammo_part.body_type = current_data.body_type
			final_ammo_part.head_type = current_data.head_type
			final_weapon_part.ammo = final_ammo_part 
	else:
		final_weapon_part = current_data.equipment_parts.get("mainhand")
		if final_weapon_part:
			if "config_path" in final_weapon_part:
				config_path = final_weapon_part.config_path
			if "ammo" in final_weapon_part and final_weapon_part.ammo:
				final_ammo_part = final_weapon_part.ammo
				
	set_meta("equipped_ammo", final_ammo_part)
			
	if not config_path.is_empty():
		var file_text = ZipMediaLoader.get_text_content(config_path)
		if not file_text.is_empty():
			current_weapon_data = JSON.parse_string(file_text)
		else:
			current_weapon_data = {}
	else:
		current_weapon_data = {}
		
	for img_id in current_weapon_images:
		current_weapon_images = {}
		
	var bake_id = "build_player" if is_in_group("player") else "build_event%s" % str(current_data) if is_in_group("event") else "build_vehicle%s" % get_instance_id()
	var node: CharacterBaker = GameManager.get_character_baker()
	
	if node:
		node.request_bake_character(
			bake_id,
			current_data,
			"",
			wings_back,
			offhand_back,
			mainhand_back,
			body,
			offhand_front,
			mainhand_front,
			actor_id
		)
		
		if current_weapon_data:
			var actions: Array = current_weapon_data.get("actions", [])
			var actions_to_bake = actions + ["idle", "walk"] 
			
			node.request_bake_weapon(
				bake_id + "_weapons",
				current_data,
				final_weapon_part,
				actions_to_bake,
				current_weapon_images
			)


func adjust_bounds() -> void:
	var node = get_node_or_null("%Down")
	if not node: return
	
	%Down.position = Vector2(0, 0)
	%Up.position = Vector2(0, -49)
	%Left.position = Vector2(-15, -24)
	%Right.position = Vector2(15, -24)
	%Feet.position = Vector2(0, 0)
	var mouth = get_node_or_null("%Mouth")
	if mouth:
		match current_direction:
			DIRECTIONS.LEFT: mouth.position = Vector2(-6, -30)
			DIRECTIONS.RIGHT: mouth.position = Vector2(5, -30)
			DIRECTIONS.DOWN: mouth.position = Vector2(0, -29)
			DIRECTIONS.UP: mouth.position = Vector2(0, -35)
		if not Engine.is_editor_hint():
			get_tree().create_timer(0.05).timeout.connect(adjust_bounds)


func get_bounds() -> Dictionary:
	return {
		"left": %Left.position,
		"right": %Right.position,
		"up": %Up.position,
		"down": %Down.position
	}


func _manage_animator() -> void:
	var node = get_node_or_null("%MainAnimator")
	if node and node is AnimationPlayer and node.has_animation("Breathing"):
		if node.is_playing():
			node.stop()
		var restart_time: float = randf_range(0.1, 1.2)
		var t = create_tween()
		t.tween_interval(restart_time)
		t.tween_callback(
			func():
				node.speed_scale = randf_range(0.6, 0.7)
				node.play("Breathing")
		)


func run_animation(force_animation: bool = false) -> void:
	if not is_inside_tree(): return
	if frame_delay > 0.0 and not force_animation: return
	
	var should_show_weapon = false

	if current_data:
		should_show_weapon = current_data.always_show_weapon or is_attacking
	
	if current_animation and "walk" in current_animation and GameInterpreter.is_showing_message():
		current_animation = current_animation.replace("walk", "idle")
	
	if current_animation in current_weapon_images:
		var weapon_imgs = current_weapon_images[current_animation]
		if weapon_imgs:
			mainhand_back.texture = weapon_imgs.back
			mainhand_front.texture = weapon_imgs.front
			
			offhand_back.visible = should_show_weapon
			offhand_front.visible = should_show_weapon
			mainhand_back.visible = should_show_weapon
			mainhand_front.visible = should_show_weapon
			
			# --------- AMMO LOGIC ---------
			if "ammo" in current_weapon_images and current_weapon_images.ammo:
				if ammo_node_back:
					ammo_node_back.texture = current_weapon_images.ammo.back
					ammo_node_back.visible = is_attacking
					
				if ammo_node_front:
					ammo_node_front.texture = current_weapon_images.ammo.front
					ammo_node_front.visible = is_attacking
			else:
				if ammo_node_back: ammo_node_back.visible = false
				if ammo_node_front: ammo_node_front.visible = false
			# ------------------------------------------------
		else:
			mainhand_back.visible = false
			mainhand_front.visible = false
			offhand_back.visible = false
			offhand_front.visible = false
			if ammo_node_back: ammo_node_back.visible = false
			if ammo_node_front: ammo_node_front.visible = false
	else:
		mainhand_back.visible = false
		mainhand_front.visible = false
		offhand_back.visible = false
		offhand_front.visible = false
		if ammo_node_back: ammo_node_back.visible = false
		if ammo_node_front: ammo_node_front.visible = false
	
	if current_animation in current_weapon_images and self == GameManager.current_player:
		var weapon_imgs = current_weapon_images[current_animation]
		if weapon_imgs:
			mainhand_back.texture = weapon_imgs.back
			mainhand_front.texture = weapon_imgs.front
	
	if current_animation == "idle" and "idle" in current_weapon_images:
		mainhand_back.texture = current_weapon_images.idle.back
		mainhand_front.texture = current_weapon_images.idle.front
	elif current_animation == "walk" and "walk" in current_weapon_images:
		mainhand_back.texture = current_weapon_images.walk.back
		mainhand_front.texture = current_weapon_images.walk.front
	
	var current_animation_data = get_current_animation()
	var current_weapon_animation = get_current_weapon_animation()

	if !current_animation_data and !current_weapon_animation:
		return
	
	if !current_animation_data:
		current_animation_data = current_weapon_animation
	
	if !current_weapon_animation:
		current_weapon_animation = current_animation_data
	
	var weapon_current_frame = min(current_frame, current_weapon_animation.frames.size() - 1)
	var normal_animation_current_frame = min(current_frame, current_animation_data.frames.size() - 1)
	
	var player_frame: Array = current_animation_data.frames[normal_animation_current_frame]
	var weapon_frame: Array = current_weapon_animation.frames[weapon_current_frame]
	var player_size = current_animation_data.frame_size
	
	body.region_rect = Rect2(player_frame[0], player_frame[1], player_size[0], player_size[1])
	wings_back.region_rect = body.region_rect
	offhand_back.region_rect = body.region_rect
	offhand_front.region_rect = body.region_rect
	
	if ammo_node_back: ammo_node_back.region_rect = body.region_rect
	if ammo_node_front: ammo_node_front.region_rect = body.region_rect
	
	# ----------------------------------------
	
	var action_frame = current_animation_data.get("action_frame", -1)
	if current_frame == action_frame and not "idle" in current_animation:
		_handle_action_frame(current_animation_data)
	
	if (
		(mainhand_back.texture and mainhand_back.texture.get_size() == body.texture.get_size()) or
		(mainhand_front.texture and mainhand_front.texture.get_size() == body.texture.get_size())
	):
		mainhand_back.region_rect = body.region_rect
	else:
		mainhand_back.region_rect = Rect2(weapon_frame[0], weapon_frame[1], 192, 192)
	mainhand_front.region_rect = mainhand_back.region_rect
	
	current_frame += 1
	
	if current_frame >= current_animation_data.frames.size():
		if current_animation_data.get("loop", false):
			current_frame = 0
		else:
			if not current_animation_data.get("keep_last_frame", false):
				animation_finished.emit()
				current_frame = 0
			else:
				current_frame = current_animation_data.frames.size() - 1


func _get_direction_string() -> String:
	match current_direction:
		DIRECTIONS.UP: return "up"
		DIRECTIONS.DOWN: return "down"
		DIRECTIONS.LEFT: return "left"
		DIRECTIONS.RIGHT: return "right"
	return "down"


func _handle_action_frame(anim_data: Dictionary) -> void:
	if not current_data: 
		return
	
	var anim_id = anim_data.get("id", "")
	if current_weapon_data and current_weapon_data.get("ammo", []).size() > 0:
		anim_id = "shoot"
		
	var is_valid_action_frame = ("shoot" in anim_id or "cast" in anim_id or "slash" in anim_id or "thrust" in anim_id or "oversize" in anim_id)
	if not is_valid_action_frame:
		return
	
	if is_instance_valid(current_combat_action):
		var offset_array = anim_data.get("emiter", [0, 0])
		if "islash" in anim_id:
			match anim_id:
				"islash_left": offset_array = [-16, -16]
				"islash_right": offset_array = [16, -16]
				"islash_up": offset_array = [0, -32]
				"islash_down": offset_array = [0, -16]

		var emission_point = Vector2(offset_array[0], offset_array[1])
		
		var spawn_pos = global_position + emission_point
		current_combat_action.global_position = spawn_pos
		
		current_combat_action.shoot()
		
		if current_combat_action is BoomerangProjectile:
			active_boomerang = current_combat_action
			
		current_combat_action = null


func _on_animation_finished() -> void:
	call_deferred("_animation_to_idle")
	if is_attacking:
		attack.emit(current_animation)
		is_attacking = false


func get_baking_nodes() -> Dictionary:
	return {
		"wings": wings_back,
		"offhandback": offhand_back,
		"mainhandback": mainhand_back,
		"body": body,
		"offhandfront": offhand_front,
		"mainhandfront": mainhand_front
	}


func update_player_appearance(char_data: RPGLPCCharacter) -> void:
	if not char_data or not GameManager.main_scene:
		return
		
	var baker = GameManager.get_character_baker()
	if baker:
		baker.request_bake_character(
			str(get_instance_id()),
			char_data,
			"walk",
			wings_back,
			offhand_back,
			mainhand_back,
			body,
			offhand_front,
			mainhand_front,
			get_meta("actor_id") if has_meta("actor_id") else -1
		)


func get_current_animation() -> Dictionary:
	if !animations:
		return {}
		
	var animation_id = current_animation.to_lower() + "_" + str(DIRECTIONS.find_key(current_direction)).to_lower()

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
	if ["dagger2"].has(current_weapon_data.get("id", "")) and ["idle", "walk"].has(current_animation.to_lower()):
		animation_id = "small_" + animation_id

	var current_animation = {}

	for animation in animations.weapon:
		if animation.id == animation_id:
			current_animation = animation
			break

	return current_animation


func _debug_show_weapon_textures() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	canvas.add_child(margin)
	
	var vbox_main = VBoxContainer.new()
	margin.add_child(vbox_main)
	
	var lbl = Label.new()
	lbl.text = "DEBUG: Weapon Textures applied (Closing in 5s...)"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_main.add_child(lbl)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox_main.add_child(hbox)
	
	# Back Texture Setup
	var vbox_back = VBoxContainer.new()
	vbox_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var tex_back_size = Vector2.ZERO
	if mainhand_back.texture: 
		tex_back_size = mainhand_back.texture.get_size()
		
	var lbl_back = Label.new()
	lbl_back.text = "mainhand_back\nSize: " + str(tex_back_size)
	lbl_back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_back.add_theme_constant_override("outline_size", 4)
	lbl_back.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox_back.add_child(lbl_back)
	
	var tex_back_rect = TextureRect.new()
	tex_back_rect.texture = mainhand_back.texture
	tex_back_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_back_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_back_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_back.add_child(tex_back_rect)
	hbox.add_child(vbox_back)
	
	# Front Texture Setup
	var vbox_front = VBoxContainer.new()
	vbox_front.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var tex_front_size = Vector2.ZERO
	if mainhand_front.texture: 
		tex_front_size = mainhand_front.texture.get_size()
		
	var lbl_front = Label.new()
	lbl_front.text = "mainhand_front\nSize: " + str(tex_front_size)
	lbl_front.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_front.add_theme_constant_override("outline_size", 4)
	lbl_front.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox_front.add_child(lbl_front)
	
	var tex_front_rect = TextureRect.new()
	tex_front_rect.texture = mainhand_front.texture
	tex_front_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_front_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_front_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_front.add_child(tex_front_rect)
	hbox.add_child(vbox_front)
	
	add_child(canvas)
	
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(canvas):
		canvas.queue_free()


func _on_attack(animation_id: String) -> void:
	pass


func attack_with_weapon() -> void:
	var actions = current_weapon_data.get("actions", [])
	
	if actions.is_empty():
		attack_without_weapon()
		return
		
	current_animation = actions[randi() % actions.size()]

	if current_animation in current_weapon_images:
		mainhand_back.texture = current_weapon_images[current_animation].back
		mainhand_front.texture = current_weapon_images[current_animation].front
		
	if current_animation == "fish_throw":
		current_animation = "fish_full_animation"
		
	_prepare_combat_action()

	current_frame = 0
	is_attacking = true
	
	if current_animation != "fish_full_animation":
		attack.emit(current_animation)
	else:
		attack.emit("fish")


func _prepare_combat_action() -> void:
	if is_instance_valid(current_combat_action):
		current_combat_action.queue_free()
	
	var game_weapon: RPGWeapon
	if has_meta("actor_id"):
		game_weapon = GameManager.get_actor_weapon_db(get_meta("actor_id"))
		
	var script_path = game_weapon.lpc_part_custom_script if game_weapon else ""
	if script_path.is_empty() or not projectile_scene:
		return
		
	var ammo_id = "melee"
	var ammo_part = get_meta("equipped_ammo") if has_meta("equipped_ammo") else current_data.equipment_parts.get("ammo")
	
	if ammo_part:
		ammo_id = "arrow"
		if ammo_part.part_id in PROJECTILES:
			ammo_id = ammo_part.part_id
		elif "config_path" in ammo_part and not ammo_part.config_path.is_empty():
			var text = ZipMediaLoader.get_text_content(ammo_part.config_path)
			if not text.is_empty():
				var j = JSON.parse_string(text)
				if j and typeof(j) == TYPE_DICTIONARY and j.has("projectile"):
					ammo_id = j.projectile
					
	if ammo_id == "boomerang" and is_instance_valid(active_boomerang):
		return
		
	current_combat_action = projectile_scene.instantiate()
	current_combat_action.set_script(load(script_path))
	
	current_combat_action.player = self
	if game_weapon:
		current_combat_action.weapon_database = game_weapon
	
	var tex = current_weapon_images.get("projectile_shooted")
	var proj_color = current_weapon_images.get("projectile_color", Color.WHITE)
	var fxs: Array = current_weapon_data.get("sounds", [])
	var fx: String = ""
	if not fxs.is_empty():
		fx = fxs.pick_random()
		
	var custom_stats = {
		"texture": tex,
		"projectile_color": proj_color,
		"shape_type": "rect",
		"shape_width": current_weapon_data.get("attack_width", 0.8),
		"shape_height": current_weapon_data.get("attack_height", 0.8),
		"initial_sound": fx
	}
	
	if not fx.is_empty():
		var plugin_path = "res://addons/rpg_character_creator/"
		var sound_path = plugin_path.path_join(fx) if not fx.begins_with("res://") else fx
		custom_stats.initial_sound = sound_path
	
	get_parent().add_child(current_combat_action)
	current_combat_action.setup(ammo_id, _get_direction_string(), global_position, custom_stats)


func attack_without_weapon() -> void:
	var actions = ["slash", "islash", "smash"]
	current_animation = actions[randi() % actions.size()]
	current_frame = 0
	is_attacking = true


func can_perform_action() -> bool:
	if Engine.is_editor_hint() or is_on_vehicle: return false
	
	var main_interpreter = GameManager.get_main_interpreter()
	
	if not main_interpreter: return false

	return !busy and !is_attacking and !is_moving and can_attack and can_move and !GameManager.busy and !main_interpreter.is_busy() and !GameInterpreter.is_busy() and !force_locked


func get_icon() -> Variant:
	var tex: Variant
	
	if has_meta("actor_id"):
		var actor_id = get_meta("actor_id")
		if typeof(actor_id) == TYPE_INT and RPGSYSTEM.database.actors.size() > actor_id and actor_id > 0:
			var actor = RPGSYSTEM.database.actors[actor_id]
			tex = actor.icon
	
	return tex


func get_shadow_data() -> Dictionary:
	if is_on_vehicle or is_queued_for_deletion() or has_meta("_disable_shadow"):
		return {}
		
	var parent_body = full_body
	var global_pos = parent_body.global_position
	
	var shadow_dict = {
		"position": global_pos,
		"textures": [],
		"positions": [],
		"regions": [],
		"feet_offsets": [],
		"alpha": parent_body.modulate.a,
		"scale": parent_body.scale,
		"rotation": parent_body.rotation
	}
	
	var sprites_to_check = [wings_back, offhand_back, mainhand_back, body, offhand_front, mainhand_front]
	
	for s in sprites_to_check:
		if s and is_instance_valid(s) and s.visible and s.modulate.a > 0.0 and s.self_modulate.a > 0.0 and s.texture:
			shadow_dict.textures.append(s.texture)
			shadow_dict.positions.append(s.global_position)
			
			if s.region_enabled:
				shadow_dict.regions.append(s.region_rect)
			else:
				shadow_dict.regions.append(Rect2(Vector2.ZERO, s.texture.get_size()))
				
			shadow_dict.feet_offsets.append(16.0)
			
	if shadow_dict.textures.is_empty():
		return {}
		
	return shadow_dict


func shake(shake_offset: Vector2) -> void:
	var node = full_body
	if not node.has_meta("original_position"):
		node.set_meta("original_position", node.position)
	
	node.position = node.get_meta("original_position") + shake_offset
