@tool
@icon("res://addons/AnimateTexture/spriteset_animation_texture.gd")
class_name SpritesetAnimationTexture
extends Texture2D


## SpritesetAnimationTexture
##
## A Godot addon that converts SpriteFrames animations into usable Texture2D resources.
## This allows animated sprites to be used anywhere textures are accepted: UI elements, materials, 
## shader parameters, draw calls, and nested within other SpritesetAnimationTextures.
##
## The addon is completely plug-and-play. Simply drop it in your addons folder and it becomes
## available as an export option in any texture property across your project.
##
## Key Features:
## - Universal texture compatibility (works with any Texture2D export)
## - Nested animation support (animated texture as frames of another animated texture)
## - Seamless editor and runtime functionality
## - Automatic frame synchronization and caching
## - Zero configuration required
##
## Example Usage:
##     var animated = SpritesetAnimationTexture.new()
##     animated.sprite_frames = preload("res://animations.tres")
##     animated.animation = "idle"
##     $Sprite2D.texture = animated
##
## INTERNAL ARCHITECTURE NOTES:
## This implementation is highly optimized and has strict ordering requirements:
## - All variable positions and function call sequences are critical to functionality
## - The sync between editor and runtime states depends on precise state management
## - Removing seemingly "redundant" calls will break the texture synchronization
## - The stack depth checks and connection logic prevent race conditions
## Do not modify internal implementation without thorough testing.



## === STATIC CACHE MANAGEMENT ===
## Global caching system for RID-to-CanvasItem mappings in the editor.
## Prevents redundant node lookups when drawing.
static var _rid_to_canvas_cache: Dictionary = {}

## Static refresh timer and state for batching editor updates.
static var _static_refresh_timer: float = 0.0
static var _static_refresh_pending: bool = false
static var _static_last_processed_frame: int = 0
const _REFRESH_COOLDOWN: float = 0.2

## Common texture property names searched when registering canvas items in the editor.
const _COMMON_TEXTURE_PROPERTIES = [
	"texture", "icon", 
	"texture_normal", "texture_pressed", "texture_hover", "texture_disabled", "texture_focused",
	"bg_texture", "under_texture", "progress_texture"
]


## === PUBLIC EXPORTS ===
## The SpriteFrames resource containing animation data
@export var sprite_frames: SpriteFrames : set = _set_sprite_frames, get = _get_sprite_frames

## Animation playback speed multiplier (clamped to minimum 0.1)
@export var speed_scale: float = 1.0 : set = _set_speed_scale

## Automatically start playing when this texture is first used
@export var autoplay: bool = true

## Current playback state
@export var playing: bool = true


## === ANIMATION STATE ===
## Currently selected animation name
var animation: String : set = _set_animation

## Backup data for recovering broken texture references (editor only)
var _frame_backup_data: Dictionary = {}

## Current frame index in the animation sequence
var current_frame: int = 0

## Current playback progress in seconds
var animation_progress: float = 0.0

## Prevents concurrent updates to avoid state corruption
var busy: bool = false

## Current texture being displayed (either from sprite_frames or nested SpritesetAnimationTexture)
var current_texture: Texture

## Last known animation speed to detect changes
var last_animation_speed: float = 0.0

## Last animation progress to detect playback changes
var last_progress: float = 0.0


## === REGISTRATION & OWNERSHIP ===
## Weak references to canvas items using this texture, for invalidation tracking
var _registered_canvas_items: Array[WeakRef] = []

## Animation names last registered in inspector (detects SpriteFrames changes)
var _register_animations: PackedStringArray

## Owner nodes mapping: { instance_id -> { canvas, ref, prop, is_fresh } }
## Tracks which nodes are using this texture and which property
var _owners: Dictionary = {}


## === RENDERING & CACHING ===
## Current recursion depth in nested texture calls
var _stack_depth: int = 0

## Maximum allowed recursion depth to prevent infinite loops
var _max_stack_depth: int = 8

## Cached size of the current texture (fallback when texture is temporarily unavailable)
var _cache_size: Vector2 = Vector2(32, 32)

## Cache for healed textures that were previously broken (editor recovery)
var _cache_heal: Dictionary = {}


## === LIFECYCLE & STATE ===
## Last observed SpriteFrames resource (detects reassignment)
var _last_observed_sprite_frames: SpriteFrames = null

## Last engine frame number when rendering occurred
var _last_render_frame: int = 0

## Timer for periodic orphan cleanup checks (editor only)
var _orphan_check_timer: float = 0.0

## If true, the texture is inactive and not updating (for performance)
var _hibernating: bool = false

## If true, initialization has completed and update signals are connected
var _started: bool = false

## Tracks if this texture was the main selected object in the editor
var _was_main_selected: bool = false


## === SIGNALS ===
## Emitted when a non-looping animation completes playback
signal animation_finished(animation_name: String)

## Emitted when current_frame changes (for external synchronization)
signal frame_changed()


## === INITIALIZATION ===
func _init() -> void:
	## Ensure sprite_frames always exists to prevent null errors
	if not sprite_frames:
		sprite_frames = SpriteFrames.new()
	
	## Set default animation if none exists
	if not animation: animation = "default"
	
	## Connect update signals to rendering pipeline
	_check_connection()
	_started = true


## === PROPERTY LIST ===
## Dynamically generate animation enum in inspector based on sprite_frames
func _get_property_list() -> Array:
	var properties = []
	if sprite_frames:
		var anim_names = sprite_frames.get_animation_names()
		var hint_string = ",".join(anim_names)
		properties.append({ 
			"name": "animation", 
			"type": TYPE_STRING, 
			"hint": PROPERTY_HINT_ENUM, 
			"hint_string": hint_string, 
			"usage": PROPERTY_USAGE_DEFAULT 
		})
	
	## Storage for editor recovery system
	properties.append({ 
		"name": "_frame_backup_data", 
		"type": TYPE_DICTIONARY, 
		"usage": PROPERTY_USAGE_STORAGE 
	})
	return properties


## === ANIMATION CONTROL ===
## Set animation and reset to first frame
func _set_animation(value: String) -> void:
	animation = value
	current_frame = -1
	animation_progress = 0.0
	last_animation_speed = 0.0
	frame_changed.emit()
	emit_changed()


## Reset animation to initial state
func reset() -> void: 
	_set_animation(animation)


## Set speed scale with minimum boundary
func _set_speed_scale(value: float) -> void: 
	speed_scale = maxf(value, 0.1)


## === RESOURCE CLEANUP ===
## Internal reset - clears all connections and state
func _reset() -> void:
	current_frame = -1
	animation = ""
	current_texture = null
	if sprite_frames and sprite_frames.changed.is_connected(_on_sprite_frames_changed):
		sprite_frames.changed.disconnect(_on_sprite_frames_changed)


## Set new sprite_frames resource with proper cleanup and reinitialization
func _set_sprite_frames(value: SpriteFrames) -> void:
	if sprite_frames == value: return
	_reset()
	
	sprite_frames = value
	if value:
		if not value.changed.is_connected(_on_sprite_frames_changed):
			## Deferred connection prevents signal during construction
			value.changed.connect(_on_sprite_frames_changed, CONNECT_DEFERRED)
	else:
		playing = false
	
	_validate_current_animation()
	_check_connection()
	notify_property_list_changed()
	emit_changed()


## Handle sprite_frames resource changes (animation added/removed/modified)
func _on_sprite_frames_changed() -> void:
	last_animation_speed = 0.0
	current_frame = -1
	_validate_current_animation()
	_update_backup_data()
	notify_property_list_changed()
	emit_changed()


## Verify current animation exists in sprite_frames, fallback to "default" or first
func _validate_current_animation() -> void:
	if not sprite_frames: return
	var anims = sprite_frames.get_animation_names()
	if not animation in anims:
		if "default" in anims: animation = "default"
		elif anims.size() > 0: animation = anims[0]


## === EDITOR RECOVERY SYSTEM ===
## Create backup of texture paths for broken reference recovery
func _update_backup_data() -> void:
	if not Engine.is_editor_hint() or not sprite_frames: return
	var new_backup = {}
	for anim in sprite_frames.get_animation_names():
		new_backup[anim] = {}
		var count = sprite_frames.get_frame_count(anim)
		for i in range(count):
			var tex = sprite_frames.get_frame_texture(anim, i)
			if tex:
				var data = {}
				if tex is AtlasTexture:
					if tex.atlas:
						data["path"] = tex.atlas.resource_path
						data["region"] = tex.region
						data["type"] = "atlas"
				elif tex is CompressedTexture2D or tex is Texture2D:
					data["path"] = tex.resource_path
					data["type"] = "simple"
				if data.has("path") and not data["path"].is_empty() and not "::" in data["path"]:
					new_backup[anim][i] = data
	_frame_backup_data = new_backup


## Attempt to recover a broken texture reference from backup data
func _try_heal_broken_texture() -> Texture2D:
	if not _frame_backup_data: return null
	if not _frame_backup_data.has(animation) or not _frame_backup_data[animation].has(current_frame): 
		return null
	
	var data = _frame_backup_data[animation][current_frame]
	var path = data.get("path", "")
	if path == "" or not ResourceLoader.exists(path): return null
	
	if not path in _cache_heal:
		var source_tex = load(path)
		if not source_tex: return null
		
		if data.get("type") == "atlas":
			var new_atlas_tex = AtlasTexture.new()
			new_atlas_tex.atlas = source_tex
			new_atlas_tex.region = data.get("region", Rect2(0,0,0,0))
			if sprite_frames.has_animation(animation) and sprite_frames.get_frame_count(animation) > current_frame:
				sprite_frames.set_frame(animation, current_frame, new_atlas_tex)
			_cache_heal[path] = new_atlas_tex
			return new_atlas_tex
		else:
			_cache_heal[path] = source_tex
			return source_tex
	else:
		var source_tex = _cache_heal[path]
		if source_tex is AtlasTexture and data.get("type") == "atlas":
			source_tex.region = data.get("region", Rect2(0,0,0,0))
		return source_tex


## === CANVAS ITEM REGISTRATION ===
## Register a canvas item as an owner of this texture
func _register_canvas_item(canvas_item: CanvasItem) -> void:
	var id = canvas_item.get_instance_id()
	
	## Already registered
	if _owners.has(id): return
	
	var prop_name = ""
	
	## In editor, find which property holds this texture
	if Engine.is_editor_hint():
		for prop in _COMMON_TEXTURE_PROPERTIES:
			if canvas_item.get(prop) == self:
				prop_name = prop
				break

		if prop_name == "":
			var props = canvas_item.get_property_list()
			for p in props:
				if p.type == TYPE_OBJECT:
					if canvas_item.get(p.name) == self:
						prop_name = p.name
						break
	
	## Store ownership data with weak reference for auto-cleanup
	_owners[id] = {
		"canvas": canvas_item,
		"ref": weakref(canvas_item),
		"prop": prop_name,
		"is_fresh": true 
	}
	
	_hibernating = false


## === EDITOR LIFECYCLE MANAGEMENT ===
## Periodic editor updates: detect SpriteFrames changes, clean orphans, manage hibernation
func _handle_editor_refresh_logic() -> void:
	if not Engine.is_editor_hint(): return

	var should_refresh = false

	## Detect sprite_frames reassignment
	if sprite_frames != _last_observed_sprite_frames:
		_last_observed_sprite_frames = sprite_frames
		should_refresh = true

	_orphan_check_timer += get_process_delta_time()
	
	if not should_refresh and _orphan_check_timer > 0.5:
		_orphan_check_timer = 0.0
		
		## Clean dead RID cache entries
		var dead_rids = []
		for rid in _rid_to_canvas_cache:
			if not is_instance_valid(_rid_to_canvas_cache[rid]): 
				dead_rids.append(rid)
		for rid in dead_rids: 
			_rid_to_canvas_cache.erase(rid)

		var am_i_alive = false
		var is_currently_main = false
		var ids_to_remove = []
		var owner_ids = _owners.keys()
		var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
		
		## Check each owner for validity and property binding
		for id in owner_ids:
			var data = _owners[id]
			var node = data.ref.get_ref()
			
			if is_instance_valid(node):
				var points_to_me = false
				
				## Verify property still references this texture
				if data.prop != "":
					if node.get(data.prop) == self:
						points_to_me = true
					else:
						## Re-scan if property changed
						for prop in _COMMON_TEXTURE_PROPERTIES:
							if node.get(prop) == self:
								data.prop = prop
								points_to_me = true
								break
				else:
					for prop in _COMMON_TEXTURE_PROPERTIES:
						if node.get(prop) == self:
							data.prop = prop
							points_to_me = true
							break
					if not points_to_me:
						points_to_me = true
				
				if points_to_me:
					am_i_alive = true
					
					## Trigger refresh on first selection
					if data.is_fresh:
						data.is_fresh = false
						if node in selected_nodes:
							should_refresh = true
					
					## Track if this is the main selection
					if node in selected_nodes:
						if data.prop != "" and node.get(data.prop) == self:
							is_currently_main = true
				else:
					## Owner no longer points to this texture
					if node in selected_nodes:
						should_refresh = true
					ids_to_remove.append(id)
			else:
				## Owner node deleted
				ids_to_remove.append(id)
		
		for id in ids_to_remove:
			_owners.erase(id)

		## Check if directly inspected
		if EditorInterface.get_inspector().get_edited_object() == self:
			am_i_alive = true
			is_currently_main = true

		## Detect selection state change
		if is_currently_main and not _was_main_selected:
			should_refresh = true
		
		_was_main_selected = is_currently_main

		## Hibernate if no owners and not selected
		if not am_i_alive:
			if EditorInterface.get_inspector().get_edited_object() == self:
				should_refresh = true
			
			_last_render_frame = Engine.get_frames_drawn()
			playing = false
			animation_progress = 0.0
			current_frame = 0
			_owners.clear()
			_cache_heal.clear()
			current_texture = null
			_last_observed_sprite_frames = null
			
			## Disconnect from nested texture
			if current_texture is SpritesetAnimationTexture:
				if current_texture.frame_changed.is_connected(_on_sub_texture_changed):
					current_texture.frame_changed.disconnect(_on_sub_texture_changed)
			
			## Disconnect from rendering pipeline
			if not Engine.is_editor_hint():
				if RenderingServer.frame_pre_draw.is_connected(_update_texture):
					RenderingServer.frame_pre_draw.disconnect(_update_texture)
			else:
				if EditorInterface.get_base_control().get_tree().process_frame.is_connected(_update_texture):
					EditorInterface.get_base_control().get_tree().process_frame.disconnect(_update_texture)
			
			_hibernating = true
			_started = false
			busy = false

	if should_refresh:
		_refresh_editor_inspector()


## === CONNECTION MANAGEMENT ===
## Ensure update callback is connected to rendering pipeline
func _check_connection() -> void:
	busy = true
	if not Engine.is_editor_hint():
		if not RenderingServer.frame_pre_draw.is_connected(_update_texture):
			RenderingServer.frame_pre_draw.connect(_update_texture)
	else:
		if not EditorInterface.get_base_control().get_tree().process_frame.is_connected(_update_texture):
			EditorInterface.get_base_control().get_tree().process_frame.connect(_update_texture)
	if autoplay: playing = true
	busy = false


## Get delta time from appropriate source (editor or runtime)
func get_process_delta_time() -> float:
	if Engine.is_editor_hint():
		var editor = EditorInterface.get_base_control()
		if editor: return editor.get_process_delta_time()
		return 1.0/60.0
	return Engine.get_main_loop().root.get_process_delta_time()


## === NESTED TEXTURE HANDLING ===
## Called when a nested SpritesetAnimationTexture's frame changes
func _on_sub_texture_changed() -> void:
	emit_changed()
	frame_changed.emit()
	var ids = _owners.keys()
	for id in ids:
		var node = _owners[id].ref.get_ref()
		if is_instance_valid(node): 
			node.queue_redraw()
		else: 
			_owners.erase(id)


## === STATIC REFRESH COORDINATION ===
## Request deferred editor inspector refresh (batched for performance)
static func _request_static_refresh() -> void:
	return
	#_static_refresh_pending = true
	#_static_refresh_timer = _REFRESH_COOLDOWN


## Execute batched refresh of selected nodes
static func _execute_static_refresh() -> void:
	return
	#if not Engine.is_editor_hint(): return
	#var selection = EditorInterface.get_selection()
	#var selected_nodes = selection.get_selected_nodes()
	#if selected_nodes.is_empty(): return
	#selection.clear()
	#await Engine.get_main_loop().create_timer(0.01).timeout
	#for node in selected_nodes: selection.add_node(node)


## === MAIN UPDATE LOOP ===
## Core animation frame advancement and synchronization (called every frame)
func _update_texture() -> void:
	_handle_editor_refresh_logic()
	
	## Process static refresh cooldown
	if Engine.is_editor_hint() and _static_refresh_pending:
		var current_engine_frame = Engine.get_frames_drawn()

		if _static_last_processed_frame != current_engine_frame:
			_static_last_processed_frame = current_engine_frame
			
			_static_refresh_timer -= get_process_delta_time()
			
			if _static_refresh_timer <= 0.0:
				_static_refresh_pending = false
				_execute_static_refresh()
	
	## Early exit if not ready to play
	if not sprite_frames or not animation or not playing: return
	
	## Detect animation list changes in editor
	if Engine.is_editor_hint():
		var current_animations = sprite_frames.get_animation_names()
		if current_animations != _register_animations:
			_register_animations = current_animations.duplicate()
			sprite_frames.emit_changed()
	
	## Validate animation exists
	if not sprite_frames.has_animation(animation):
		current_texture = null
		return
	
	var frame_count = sprite_frames.get_frame_count(animation)
	if frame_count == 0:
		current_texture = null
		return
	
	## Get animation speed and calculate total duration
	var fps = sprite_frames.get_animation_speed(animation)
	if fps <= 0: return
	
	var total_duration = 0.0
	for i in range(frame_count):
		var relative_duration = sprite_frames.get_frame_duration(animation, i)
		total_duration += relative_duration / fps
	
	## Advance animation progress
	var delta = get_process_delta_time()
	animation_progress += delta * speed_scale
	
	## Handle looping/non-looping animations
	if sprite_frames.get_animation_loop(animation):
		animation_progress = fposmod(animation_progress, total_duration)
	else:
		if animation_progress >= total_duration:
			animation_progress = total_duration
			if playing:
				playing = false
				animation_finished.emit(animation)
	
	## Determine current frame from progress
	var new_frame = 0
	var time_accumulator = 0.0
	for i in range(frame_count):
		var frame_dur = sprite_frames.get_frame_duration(animation, i) / fps
		if animation_progress < (time_accumulator + frame_dur):
			new_frame = i
			break
		time_accumulator += frame_dur
		if i == frame_count - 1: new_frame = i

	## Update frame if changed
	if new_frame != current_frame:
		## Disconnect from previous nested texture
		if current_texture is SpritesetAnimationTexture:
			if current_texture.frame_changed.is_connected(_on_sub_texture_changed):
				current_texture.frame_changed.disconnect(_on_sub_texture_changed)
		
		current_frame = new_frame
		current_texture = sprite_frames.get_frame_texture(animation, current_frame)
		
		## Connect to new nested texture if applicable
		if current_texture is SpritesetAnimationTexture:
			if current_texture != self:
				if not current_texture.frame_changed.is_connected(_on_sub_texture_changed):
					current_texture.frame_changed.connect(_on_sub_texture_changed)
		
		frame_changed.emit()
		emit_changed()
		
		## Notify all owners to redraw
		var ids = _owners.keys()
		for id in ids:
			var node = _owners[id].ref.get_ref()
			if is_instance_valid(node): 
				node.queue_redraw()
			else: 
				_owners.erase(id)


## === TEXTURE INTERFACE IMPLEMENTATION ===

## Force update of current_texture if it is missing but data is available.
## This fixes issues with immediate drawing nodes like RichTextLabel.
func _ensure_current_texture() -> void:
	if current_texture: return
	
	if sprite_frames and sprite_frames.has_animation(animation):
		var count = sprite_frames.get_frame_count(animation)
		if count > 0:
			# Validate frame index
			if current_frame < 0 or current_frame >= count:
				current_frame = 0
			
			# Force fetch texture immediately
			current_texture = sprite_frames.get_frame_texture(animation, current_frame)
			
			# Update cache size immediately
			if current_texture:
				_cache_size = current_texture.get_size()

## Get texture width with stack depth protection
func _get_width() -> int:
	if _stack_depth > _max_stack_depth: return int(_cache_size.x)
	_stack_depth += 1
	
	_ensure_current_texture()
	
	var w = int(_cache_size.x) 
	
	if current_texture:
		w = current_texture.get_width()
		if w > 0: _cache_size.x = w
		
	_stack_depth -= 1
	return w

## Get texture height with stack depth protection
func _get_height() -> int:
	if _stack_depth > _max_stack_depth: return int(_cache_size.y)
	_stack_depth += 1
	
	_ensure_current_texture()
	
	var h = int(_cache_size.y)
	
	if current_texture:
		h = current_texture.get_height()
		if h > 0: _cache_size.y = h
		
	_stack_depth -= 1
	return h


## === RID LOOKUP ===
## Recursively find node by canvas RID
func _find_target_node(node: Node, target_rid: RID) -> Node:
	if node is CanvasItem and node.get_canvas_item() == target_rid: return node
	for child in node.get_children():
		var node_found = _find_target_node(child, target_rid)
		if node_found: return node_found
	return null


## Register canvas item by RID (with caching)
func _registered_canvas_item_by_rid(target_rid: RID) -> void:
	if target_rid not in _rid_to_canvas_cache:
		var root_node: Node = Engine.get_main_loop().root
		var node = _find_target_node(root_node, target_rid)
		if node:
			_rid_to_canvas_cache[target_rid] = node
			_register_canvas_item(node)
	else:
		var node = _rid_to_canvas_cache[target_rid]
		if is_instance_valid(node): 
			_register_canvas_item(node)
		else: 
			_rid_to_canvas_cache.erase(target_rid)


## === DRAWING INTERFACE ===
## Draw as rect (commonly used for UI)
func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	if current_texture:
		_draw_rect_region(to_canvas_item, rect, Rect2(Vector2.ZERO, current_texture.get_size()), modulate, transpose, false)
	elif not _started:
		_registered_canvas_item_by_rid(to_canvas_item)
		_check_connection()


## Draw at position
func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	if current_texture:
		var rect = Rect2(pos, current_texture.get_size())
		_draw_rect_region(to_canvas_item, rect, rect, modulate, transpose, false)
	elif not _started:
		_registered_canvas_item_by_rid(to_canvas_item)
		_check_connection()


## Get final texture in a [SpritesetAnimationTexture] texture
func _get_final_texture(tex: Texture) -> Texture:
	if tex is SpritesetAnimationTexture and _stack_depth < _max_stack_depth:
		_stack_depth += 1
		var result = _get_final_texture(tex.current_texture)
		_stack_depth -= 1
		return result
	return tex


## Draw rect region (main drawing implementation)
func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	## Wake from hibernation if needed
	if _hibernating:
		_hibernating = false
		_check_connection()
	
	_ensure_current_texture()

	## Prevent infinite recursion
	if _stack_depth > _max_stack_depth: return
	_stack_depth += 1
	
	## Initialize if first use
	if not _started:
		_registered_canvas_item_by_rid(to_canvas_item)
		_check_connection()
	
	## Draw current texture
	if current_texture:
		_registered_canvas_item_by_rid(to_canvas_item)
		
		if current_texture is AtlasTexture:
			## AtlasTexture: use atlas with region
			var atlas = current_texture.get_atlas()
			if atlas:
				var atlas_region = current_texture.get_region()
				RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, rect, atlas.get_rid(), atlas_region, modulate, transpose, clip_uv)
			else:
				## Attempt recovery of broken atlas
				var healed_tex = _try_heal_broken_texture()
				if healed_tex and healed_tex is AtlasTexture and healed_tex.get_atlas():
					var atlas_region = healed_tex.get_region()
					RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, rect, healed_tex.get_atlas().get_rid(), atlas_region, modulate, transpose, clip_uv)
					current_texture = healed_tex
				else:
					RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, rect, current_texture.get_rid(), src_rect, modulate, transpose, clip_uv)
		
		elif current_texture is SpritesetAnimationTexture:
			## Nested SpritesetAnimationTexture: ensure it's initialized then draw its texture
			var nested_tex = current_texture
			if not nested_tex._started:
				nested_tex._check_connection()
				nested_tex._registered_canvas_item_by_rid(to_canvas_item)
			
			var tex = nested_tex._get_final_texture(nested_tex)
			if tex:
				if tex is AtlasTexture and tex.get_atlas():
					RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, rect, tex.get_atlas().get_rid(), tex.get_region(), modulate, transpose, clip_uv)
				else:
					RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, rect, tex.get_rid(), src_rect, modulate, transpose, clip_uv)
		
		else:
			## Regular Texture2D
			RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, rect, current_texture.get_rid(), src_rect, modulate, transpose, clip_uv)
	
	_stack_depth -= 1


## === EDITOR INSPECTOR REFRESH ===
## Refresh editor inspector selection (prevents stale property display)
func _refresh_editor_inspector() -> void:
	if not Engine.is_editor_hint(): return
	var selection = EditorInterface.get_selection()
	var selected_nodes = selection.get_selected_nodes()
	if selected_nodes.is_empty(): return
	selection.clear()
	await Engine.get_main_loop().create_timer(0.01).timeout
	if _owners.is_empty(): return
	for node in selected_nodes: selection.add_node(node)


## === PUBLIC API ===
## Get sprite_frames with safety check
func _get_sprite_frames() -> SpriteFrames:
	if not busy and not _hibernating: _check_connection()
	return sprite_frames

## Get current texture being displayed
func _get_texture() -> Texture:
	if not sprite_frames or sprite_frames.get_frame_count(animation) == 0: return null
	return current_texture

## Play an animation (optionally from specific frame)
func play(p_animation: String = "", p_from_frame: int = 0) -> void:
	if p_animation and p_animation != animation: animation = p_animation
	current_frame = clampi(p_from_frame, 0, sprite_frames.get_frame_count(animation) - 1) if sprite_frames else 0
	animation_progress = current_frame * (1.0 / sprite_frames.get_animation_speed(animation)) if sprite_frames and sprite_frames.get_animation_speed(animation) > 0 else 0.0
	last_progress = animation_progress
	playing = true

## Stop animation playback
func stop() -> void: 
	playing = false

## Manually set current frame
func set_frame(frame: int) -> void:
	if not sprite_frames or not animation: return
	var max_frame = sprite_frames.get_frame_count(animation) - 1
	current_frame = clampi(frame, 0, max_frame)
	emit_changed()

## Get current frame index
func get_frame() -> int: 
	return current_frame

## Get total frame count for current animation
func get_frame_count() -> int:
	if sprite_frames and animation: return sprite_frames.get_frame_count(animation)
	return 0

## Get current animation name
func get_animation() -> String: 
	return animation

## Check if animation is currently playing
func is_playing() -> bool: 
	return playing
