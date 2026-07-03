@tool
class_name PageFlip2D
extends Node2D

## Main controller for the Book system. Handles animations, volume logic, and interactive scenes.

## Defines how textures are stretched within the page boundaries.
enum PageStretchOption {
	## Scales the texture to fit the page rect, potentially distorting aspect ratio.
	SCALE = TextureRect.STRETCH_SCALE,
	## Keeps the aspect ratio and centers the texture, leaving blank space if necessary.
	KEEP_ASPECT_CENTERED = TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
	## Keeps the aspect ratio but covers the entire page, potentially cropping the image.
	KEEP_ASPECT_COVERED = TextureRect.STRETCH_KEEP_ASPECT_COVERED
}

## Defines the condition required to trigger the book closing sequence.
enum CloseCondition {
	## The book will never close automatically.
	NEVER,
	## The book closes only when finishing the animation that shuts the back cover (Right to Left).
	CLOSE_FROM_BACK,
	## The book closes only when finishing the animation that shuts the front cover (Left to Right).
	CLOSE_FROM_FRONT,
	## The book closes when shutting either the front or the back cover.
	ANY_CLOSE,
	## The book closes immediately when the 'ui_cancel' action (e.g., ESC) is pressed.
	ON_CANCEL_INPUT,
	## The book closing logic is handled manually by an interactive scene (calling force_close_book).
	DELEGATED
}

## Defines what happens to the Book node after it closes.
enum CloseBehavior {
	## The Book node is deleted from the scene tree (queue_free).
	DESTROY_BOOK,
	## The game changes to a specific scene defined in 'target_scene_on_close'.
	CHANGE_SCENE
}

## Defines the initial state of the book when the scene loads.
enum StartOption {
	## The book starts fully closed showing the front cover.
	CLOSED_FROM_FRONT,
	## The book starts fully closed showing the back cover.
	CLOSED_FROM_BACK,
	## The book starts open at a specific page number defined in 'start_page'.
	OPEN_AT_PAGE
}

## Defines the target destination for the go_to_page function.
enum JumpTarget {
	## Jumps to a specific content page number (using the 'page_num' parameter).
	CONTENT_PAGE,
	## Jumps to the closed state showing the Front Cover.
	FRONT_COVER,
	## Jumps to the closed state showing the Back Cover.
	BACK_COVER
}

@export_category("Newold Config")
## Apply the custom configuration defined by Newold (Size, Physics, Layers).
## Clicking this will overwrite current physics and sizing settings with a beauty starting preset.
@export var apply_newold_preset: bool = false: set = _apply_newold_config

## Button to preview the book visually inside the editor.
@export_tool_button("Preview in editor") var preview_in_editor = _on_preview_in_editor_pressed

@export_category("Structure References")
## Container for all book visuals (Pages, Covers, Spine).
@export var visuals_container: Node
## Static polygon representing the left inner cover background.
@export var cover_left_poly: Polygon2D
## Static polygon representing the right inner cover background.
@export var cover_right_poly: Polygon2D
## Static polygon representing the left page (Slot 1).
@export var static_left: Polygon2D
## Static polygon representing the right page (Slot 2).
@export var static_right: Polygon2D
## Dynamic polygon used for the turning page animation (Slot 3 & 4).
@export var dynamic_poly: Polygon2D
## Animation player handling the page flip sequences.
@export var anim_player: AnimationPlayer

@export_category("Perspective Deformation")
## The perspective shader to apply to all book pieces.
@export var perspective_shader: Shader

## Top-left offset when the book is fully closed.
@export var closed_top_left: Vector2 = Vector2.ZERO
## Top-right offset when the book is fully closed.
@export var closed_top_right: Vector2 = Vector2.ZERO
## Bottom-left offset when the book is fully closed.
@export var closed_bottom_left: Vector2 = Vector2.ZERO
## Bottom-right offset when the book is fully closed.
@export var closed_bottom_right: Vector2 = Vector2.ZERO

## Top-left offset when the book is fully open.
@export var open_top_left: Vector2 = Vector2.ZERO
## Top-right offset when the book is fully open.
@export var open_top_right: Vector2 = Vector2.ZERO
## Bottom-left offset when the book is fully open.
@export var open_bottom_left: Vector2 = Vector2.ZERO
## Bottom-right offset when the book is fully open.
@export var open_bottom_right: Vector2 = Vector2.ZERO

@export_category("Book Logic & Closing")
## Determines the initial state of the book (closed or open at specific page).
@export var start_option: StartOption = StartOption.CLOSED_FROM_FRONT: set = _set_start_option
## The page number to open at startup.
## If any of the pages that remain open are interactive scenes,
## the script will automatically transfer control to them.[br][br]
## Note: Since an even page (Left) and the next odd page (Right) share the same spread,
## selecting either of them will result in the book opening to the same visual state.
@export var start_page: int = 1
## Determines when the book should perform the close action (e.g., destroy or change scene).
@export var close_condition: CloseCondition = CloseCondition.NEVER
## Determines what happens when the book closes (Destroy or Change Scene).
@export var close_behavior: CloseBehavior = CloseBehavior.DESTROY_BOOK: set = _set_close_behavior
## The file path to the scene to load if 'Change Scene' is selected as behavior.
@export_file("*.tscn") var target_scene_on_close: String
## If true, pages with transparency will be composited over the 'Blank Page' texture/color.
## Useful for PNG notes or decals that need a paper background.
@export var enable_composite_pages: bool = false
## If greater than 0, limits the maximum page the user can turn to manually.
## If -1, allows all pages but prevents closing to the back cover.
@export var limit_max_pages: int = 0
## When opening the book from the front cover, it will sequentially auto-turn to this page number instead of just page 1.
@export var front_cover_opens_to_page: int = 1
## Speed multiplier for the initial cover animation when jumping to a target page.
@export var cover_anim_speed: float = 1.5
## Speed multiplier for the page turning animations when jumping to a target page.
@export var pages_anim_speed: float = 2.0

@export_category("Styling & Spine")
## Base color for pages without texture content or the background of composite pages.
@export var blank_page_color: Color = Color.WHITE
## Texture used when a left page path is invalid, empty, or for the background of composite pages.
@export var left_blank_page_texture: Texture2D
## Texture used when a right page path is invalid, empty, or for the background of composite pages.
@export var right_blank_page_texture: Texture2D
## Color tint for the central spine of the book.
@export var spine_color: Color = Color(1, 1, 1): set = _set_spine_color
## Texture for the central spine of the book.
@export var spine_texture: Texture2D: set = _set_spine_texture
## Width of the central spine in pixels.
@export var spine_width: float = 40.0: set = _set_spine_value
## Determines if the front and back covers behave as rigid bodies (hard cover) or flexible (soft cover).
@export var covers_are_rigid: bool = true

@export_group("Flight Feel")
## How high the book lifts (in pixels) during the open/close animation.
@export var flight_lift_height: float = 60.0
## Extra scale multiplier at the peak of the flight to simulate 3D depth.
@export var flight_zoom_factor: float = 1.05

@export_category("Fake 3D (Transform)")
@export_group("Closed State")
## Scale of the book container when fully closed.
@export var closed_scale: Vector2 = Vector2(1.0, 0.85)
## Skew (shear) applied when closed to simulate perspective or isometric view.
@export_range(-1.0, 1.0) var closed_skew: float = 0.0
## Rotation (degrees) of the book when closed.
@export_range(-360.0, 360.0) var closed_rotation: float = 0.0
## Custom visual position offset when the book is fully closed showing the front cover.
@export var closed_offset: Vector2 = Vector2.ZERO
## Custom visual position offset when the book is fully closed showing the back cover.
@export var closed_back_offset: Vector2 = Vector2.ZERO

@export_group("Open State")
## Scale of the book container when fully open.
@export var open_scale: Vector2 = Vector2(1.0, 1.0)
## Skew (shear) applied when open.
@export var open_skew: float = 0.0
## Rotation (degrees) of the book when open.
@export var open_rotation: float = 0.0
## Custom visual position offset when the book is fully open.
@export var open_offset: Vector2 = Vector2.ZERO

@export_category("Fake 3D Volume (Pages)")
## Minimum number of layers to generate for the page stack (visual thickness floor).
@export_range(1, 20) var min_layers: int = 3
## Maximum number of layers to generate for the page stack (visual thickness ceiling).
@export_range(1, 100) var max_layers: int = 15
## If true, the stack grows upwards (negative Y). If false, downwards (positive Y).
@export var invert_stack_direction: bool = false
## Offset between layers when the book is closed (max compression).
@export var layer_offset_closed: Vector2 = Vector2(0, 1.5)
## Offset between layers when the book is open (relaxed compression).
@export var layer_offset_open: Vector2 = Vector2(0, 0.2)
## Base color tint for the volume layers (paper edges).
@export var volume_color: Color = Color(0.8, 0.75, 0.6)
## Darkening factor for alternating layers to create a paper texture effect.
@export_range(0.0, 1.0) var stripe_darken_ratio: float = 0.85
## Global positional offset for the entire volume stack.
@export var volume_stack_offset: Vector2 = Vector2.ZERO
## Time in seconds before the animation ends to "land" the page on the stack visually.
@export var landing_overlap: float = 0.15
## Custom offset for the drop shadow under the page stacks.
@export var stack_shadow_offset: Vector2 = Vector2(8.0, 8.0)

@export_group("Paper Curvature")
## How many pixels the paper curves inwards at the spine to simulate binding tension.
@export var spine_curl_intensity: float = 12.0: set = _set_curl_intensity
## How far the curve extends from the spine (0.0 to 1.0).
@export var spine_curl_width: float = 0.25: set = _set_curl_width
## How many pixels the paper drops at the outer edge due to gravity.
@export var outer_droop_intensity: float = 10.0: set = _set_outer_droop_intensity
## How far the droop curve extends from the outer edge inwards (0.0 to 1.0).
@export var outer_droop_width: float = 0.3: set = _set_outer_droop_width
## How dark the inner spine curve shadow is (0.0 = no shadow, 1.0 = pitch black).
@export_range(0.0, 1.0) var spine_shadow_darkness: float = 0.4: set = _set_spine_shadow_val
## Vertical offset applied to inner pages to simulate stack depth.
@export var inner_page_vertical_offset: float = 0.0: set = _set_inner_vertical_offset

@export_group("Protruding Cover")
## Custom offset to make the hardcover protrude beyond the pages.
@export var cover_protrude_offset: Vector2 = Vector2(3.0, 3.0)
## Base scale for the protruding cover layer.
@export var cover_protrude_scale: Vector2 = Vector2(1.01, 1.02)
## Specific tint color for the protruding cover layer.
@export var cover_protrude_color: Color = Color(0.15, 0.1, 0.05)

@export_category("Audio")
## Sound played when a rigid cover slams shut.
@export var sfx_book_impact: AudioStream
## Sound played when open a book.
@export var sfx_book_opened: AudioStream
## Sound played when a flexible page turns.
@export var sfx_page_flip: AudioStream
## Flip pitch variance between min and max
@export_range(0.5, 1.5) var min_fpage_flip_fx_pitch: float = 0.89
## Flip pitch variance between min and max
@export_range(0.5, 1.5) var max_fpage_flip_fx_pitch: float = 1.12
## Time offset to sync the impact sound with the visual contact frame.
@export var impact_sync_offset: float = 0.15
## AudioStreamPlayer node used for feedback.
@export var audio_player: AudioStreamPlayer

@export_category("Book Size Control")
## Target size (Resolution) for the book pages. Affects Viewports and Meshes.
@export var target_page_size: Vector2 = Vector2(512, 820)
## Margin to simulate a protruding hardcover by rendering the inner cover behind internal pages.
@export var inner_page_margin: Vector2 = Vector2.ZERO
## Button to apply size changes in the editor.
@export var apply_size_change: bool = false: set = _on_apply_size_pressed

@export_category("Content Source")
## List of paths to textures (*.png, *.jpg) or PackedScenes (*.tscn) for pages.
@export_file("*.png", "*.jpg", "*.jpeg", "*.tscn") var pages_paths: Array[String] = []
## Determines how standard images (textures) are stretched within the page boundaries.
@export var page_stretch_mode: PageStretchOption = PageStretchOption.SCALE
## External front cover texture.
@export var tex_cover_front_out: Texture2D
## Internal front cover texture.
@export var tex_cover_front_in: Texture2D
## Internal back cover texture.
@export var tex_cover_back_in: Texture2D
## External back cover texture.
@export var tex_cover_back_out: Texture2D
## Maximum number of interactive scenes to keep in memory to prevent memory leaks.
@export var max_cached_scenes: int = 6

var current_spread: int = -1
var total_spreads: int = 0
var is_animating: bool = false
var going_forward: bool = true
var page_width: float
var is_book_open: bool = false

var _runtime_pages: Array[String] = []
var _spine_poly: Polygon2D

var _slot_1: SubViewport
var _slot_2: SubViewport
var _slot_3: SubViewport
var _slot_4: SubViewport

var _active_interactive_is_left: bool = false
var _active_interactive_is_right: bool = false
var _scene_cache = {}

var _volume_root: Node2D
var _current_expansion_factor: float = 0.0
var _visual_spread_index: float = -1.0
var _stack_scale_left: float = 1.0
var _stack_scale_right: float = 1.0

var _is_page_flying: bool = false
var _flying_from_right: bool = false
var _force_hide_vol_left: bool = false
var _force_hide_vol_right: bool = false
var _pending_target_spread_idx: int = 0

var _is_force_closing: bool = false
var _is_current_anim_rigid: bool = false

var _is_jumping: bool = false
var _jump_target_spread: int = -1
var _ultimate_jump_target_spread: int = -999
var _auto_turn_target_spread: int = -999

var _active_viewports_state: Dictionary = {}

var _dynamic_auto_speed: float = 1.0
var _pending_opened_signal: bool = false
var _pending_closed_signal: bool = false

var volume_spine: Polygon2D

var disabled = false

var _grid_polys: Array = []
var _grid_uvs: PackedVector2Array = []
var _poly_flat: PackedVector2Array = []
var _poly_curved_l: PackedVector2Array = []
var _poly_curved_r: PackedVector2Array = []
var _colors_flat: PackedColorArray = []
var _colors_curved_l: PackedColorArray = []
var _colors_curved_r: PackedColorArray = []
var _dyn_poly_flat: PackedVector2Array = []
var _dyn_poly_curved: PackedVector2Array = []
var _dyn_colors_flat: PackedColorArray = []
var _dyn_colors_curved: PackedColorArray = []

var _fake_volume_layer0: Node2D

## Emitted at the start of any page transition animation.
signal started_page_flip_animation()

## Emitted at the end of a page transition or jump animation.
signal ended_page_flip_animation()

## [DEPRECATED] Use start_opening instead. Redundantly emitted at the start of opening.
@warning_ignore("unused_signal")
signal book_opened()

## [DEPRECATED] Use start_closing instead. Redundantly emitted at the start of closing.
@warning_ignore("unused_signal")
signal book_closed()

## Emitted when the book transitions from closed to open (at the start of the animation).
signal start_opening()

## Emitted when the book finishes its opening animation and is fully exposed.
signal opened()

## Emitted when the book transitions from open to closed (at the start of the animation).
signal start_closing()

## Emitted when the book finishes its closing animation and rests on its cover.
signal closed()
## Emitted when the book transfers input control to an interactive page or node.
signal transferred_controls(controls_owner: Node)


# Managers References
var setup_manager: PageFlipSetupManager
var mesh_manager: PageFlipMeshManager
var content_manager: PageFlipContentManager
var volume_manager: PageFlipVolumeManager
var input_manager: PageFlipInputManager
var interactive_manager: PageFlipInteractiveManager
var anim_manager: PageFlipAnimManager
var audio_manager: PageFlipAudioManager


func _init() -> void:
	setup_manager = PageFlipSetupManager.new(self)
	mesh_manager = PageFlipMeshManager.new(self)
	content_manager = PageFlipContentManager.new(self)
	volume_manager = PageFlipVolumeManager.new(self)
	input_manager = PageFlipInputManager.new(self)
	interactive_manager = PageFlipInteractiveManager.new(self)
	anim_manager = PageFlipAnimManager.new(self)
	audio_manager = PageFlipAudioManager.new(self)


#region Initialization and Configuration Block
func _validate_property(property: Dictionary) -> void:
	if property.name == "target_scene_on_close":
		if close_behavior != CloseBehavior.CHANGE_SCENE:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	
	if property.name == "start_page":
		if start_option != StartOption.OPEN_AT_PAGE:
			property.usage = PROPERTY_USAGE_NO_EDITOR


func _set_close_behavior(value):
	close_behavior = value
	notify_property_list_changed()


func _set_start_option(value):
	start_option = value
	notify_property_list_changed()


func _set_outer_droop_intensity(val: float) -> void:
	outer_droop_intensity = val
	if is_inside_tree() and mesh_manager:
		mesh_manager.apply_new_size()
		if not is_animating:
			mesh_manager.update_static_visuals_immediate()


func _set_outer_droop_width(val: float) -> void:
	outer_droop_width = val
	if is_inside_tree() and mesh_manager:
		mesh_manager.apply_new_size()
		if not is_animating:
			mesh_manager.update_static_visuals_immediate()


func _set_spine_shadow_val(val: float) -> void:
	spine_shadow_darkness = val
	if is_inside_tree() and mesh_manager:
		mesh_manager.apply_new_size()
		if not is_animating:
			mesh_manager.update_static_visuals_immediate()


func _set_curl_intensity(val: float) -> void:
	spine_curl_intensity = val
	if is_inside_tree() and mesh_manager:
		mesh_manager.apply_new_size()
		if not is_animating:
			mesh_manager.update_static_visuals_immediate()


func _set_curl_width(val: float) -> void:
	spine_curl_width = val
	if is_inside_tree() and mesh_manager:
		mesh_manager.apply_new_size()
		if not is_animating:
			mesh_manager.update_static_visuals_immediate()


func _set_inner_vertical_offset(val: float) -> void:
	inner_page_vertical_offset = val
	if is_inside_tree() and mesh_manager:
		mesh_manager.apply_new_size()
		if not is_animating:
			mesh_manager.update_static_visuals_immediate()


func set_speed_scale(_speed: float) -> void:
	if anim_player:
		anim_player.speed_scale = _speed


func _apply_newold_config(val):
	if not val: return
	apply_newold_preset = false
	blank_page_color = Color.WHITE
	left_blank_page_texture = preload("uid://cen51wqc15b14")
	right_blank_page_texture = preload("uid://cen51wqc15b14")
	spine_color = Color.WHITE
	spine_texture = preload("uid://cit41jypw2sy1")
	spine_width = 12.0
	covers_are_rigid = true
	closed_scale = Vector2(0.815, 0.45)
	closed_skew = 0.05
	closed_rotation = 0.1
	closed_offset = Vector2.ZERO
	closed_back_offset = Vector2.ZERO
	open_scale = Vector2(1.0, 0.975)
	open_skew = 0.0
	open_rotation = 0.0
	open_offset = Vector2.ZERO
	min_layers = 1
	max_layers = 15
	invert_stack_direction = false
	layer_offset_closed = Vector2(3.0, 6.5)
	layer_offset_open = Vector2(4.0, 2.0)
	volume_color = Color("#a6978f")
	stripe_darken_ratio = 0.848
	volume_stack_offset = Vector2(0, 0)
	landing_overlap = 0.15
	stack_shadow_offset = Vector2(8.0, 8.0)
	spine_curl_intensity = 12.0
	spine_curl_width = 0.25
	outer_droop_intensity = 15.0
	outer_droop_width = 0.3
	spine_shadow_darkness = 0.4
	sfx_book_impact = preload("uid://bhitebdghyhua")
	sfx_page_flip = preload("uid://bylfc3b5pmbij")
	impact_sync_offset = 0.15
	target_page_size = Vector2(512, 820)
	inner_page_margin = Vector2.ZERO
	page_stretch_mode = PageStretchOption.SCALE
	tex_cover_front_out = preload("uid://dbdwbowx32d3v")
	tex_cover_front_in = preload("uid://dt1tiecgw5rip")
	tex_cover_back_in = preload("uid://dt1tiecgw5rip")
	tex_cover_back_out = preload("uid://bjowpx1ap4uxt")
	inner_page_vertical_offset = 0.0
	
	if mesh_manager:
		mesh_manager.apply_new_size()
	if dynamic_poly:
		dynamic_poly.animation_preset = DynamicPage.PagePreset.LIGHT_MAGAZINE
	notify_property_list_changed()


func _on_preview_in_editor_pressed(value: bool) -> void:
	if not value:
		return
		
	preview_in_editor = false
	
	if Engine.is_editor_hint():
		_force_editor_preview()


func _force_editor_preview() -> void:
	__init()
	
	if dynamic_poly and not dynamic_poly.material:
		dynamic_poly.material = preload("uid://ddw2ie8wnrnre")
		
	if not left_blank_page_texture or not right_blank_page_texture:
		var w = int(target_page_size.x)
		var h = int(target_page_size.y)
		
		if w > 0 and h > 0:
			var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
			img.fill(blank_page_color)
			if not left_blank_page_texture:
				left_blank_page_texture = ImageTexture.create_from_image(img)
			if not right_blank_page_texture:
				right_blank_page_texture = ImageTexture.create_from_image(img)
			
	if content_manager:
		content_manager.prepare_book_content()
	
	match start_option:
		StartOption.CLOSED_FROM_FRONT:
			current_spread = -1
		StartOption.CLOSED_FROM_BACK:
			current_spread = total_spreads
		StartOption.OPEN_AT_PAGE:
			var spread_idx = int(floor((start_page - 1) / 2.0))
			current_spread = clampi(spread_idx, 0, total_spreads - 1)
			
	if mesh_manager:
		mesh_manager.apply_new_size()
		mesh_manager.init_perspective_material()
	_initial_config()
	if anim_manager:
		anim_manager.set_flying_slots_active(false)


func _remove_unexpected_children(parent: Node, expected_names: Array[String]) -> void:
	for child in parent.get_children():
		if not child.name in expected_names:
			child.name = child.name + "_deleted"
			child.queue_free()


func __ensure_node(target_name: String, type: Variant, parent_node: Node) -> Node:
	var node = parent_node.get_node_or_null(target_name)
	if node: return node
	node = type.new()
	node.name = target_name
	if node is SubViewport: node.transparent_bg = true
	parent_node.add_child(node)
	if Engine.is_editor_hint(): node.owner = parent_node.owner if parent_node.owner else self
	return node


func __init():
	var expected_root_nodes: Array[String] = ["Viewports", "Visual", "AnimationPlayer", "Camera2D", "AudioStreamPlayer"]
	_remove_unexpected_children(self, expected_root_nodes)

	var viewports_cont = __ensure_node("Viewports", Node, self)
	var expected_viewports_nodes: Array[String] = ["Slots"]
	_remove_unexpected_children(viewports_cont, expected_viewports_nodes)

	var slots_cont = __ensure_node("Slots", Node, viewports_cont)
	var expected_slots_nodes: Array[String] = ["Slot1", "Slot2", "Slot3", "Slot4"]
	_remove_unexpected_children(slots_cont, expected_slots_nodes)

	var visual_cont = __ensure_node("Visual", Node2D, self)
	var expected_visual_nodes: Array[String] = [
		"CoverPageLeft", "CoverPageRight", "CoverStackShadowLeft",
		"CoverStackShadowRight", "StackDropShadowLeft", "StackDropShadowRight",
		"StaticPageLeft", "StaticPageRight", "DropShadowPoly", "DynamicFlipPoly",
		"RuntimeSpine", "VolumeStackPages"
	]
	_remove_unexpected_children(visual_cont, expected_visual_nodes)

	_slot_1 = __ensure_node("Slot1", SubViewport, slots_cont)
	_slot_2 = __ensure_node("Slot2", SubViewport, slots_cont)
	_slot_3 = __ensure_node("Slot3", SubViewport, slots_cont)
	_slot_4 = __ensure_node("Slot4", SubViewport, slots_cont)
	
	for slot in [_slot_1, _slot_2, _slot_3, _slot_4]:
		slot.transparent_bg = true
		slot.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		slot.size = target_page_size
		if slot in [_slot_1, _slot_2]:
			slot.physics_object_picking = true

	var c_left = __ensure_node("CoverPageLeft", Polygon2D, visual_cont)
	c_left.z_index = 0
	var c_right = __ensure_node("CoverPageRight", Polygon2D, visual_cont)
	c_right.z_index = 0

	var cv_sh_l = __ensure_node("CoverStackShadowLeft", Polygon2D, visual_cont)
	cv_sh_l.z_index = 1
	var cv_sh_r = __ensure_node("CoverStackShadowRight", Polygon2D, visual_cont)
	cv_sh_r.z_index = 1

	var st_sh_l = __ensure_node("StackDropShadowLeft", Polygon2D, visual_cont)
	st_sh_l.z_index = 1
	var st_sh_r = __ensure_node("StackDropShadowRight", Polygon2D, visual_cont)
	st_sh_r.z_index = 1

	var s_left = __ensure_node("StaticPageLeft", Polygon2D, visual_cont)
	s_left.z_index = 2
	var s_right = __ensure_node("StaticPageRight", Polygon2D, visual_cont)
	s_right.z_index = 2

	var drop_shadow = __ensure_node("DropShadowPoly", Polygon2D, visual_cont)
	drop_shadow.z_index = 4
	
	var d_poly = __ensure_node("DynamicFlipPoly", Polygon2D, visual_cont)
	d_poly.z_index = 10
	d_poly.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	
	if d_poly.get_script() == null:
		d_poly.set_script(load("res://addons/PageFlip/page_rigger.gd"))

	# InnerDynamicShadow is obsolete and cleaned up by _remove_unexpected_children

	var anim = __ensure_node("AnimationPlayer", AnimationPlayer, self)
	__ensure_node("Camera2D", Camera2D, self)
	var stream_player = __ensure_node("AudioStreamPlayer", AudioStreamPlayer, self)

	if not visuals_container: visuals_container = visual_cont
	if not cover_left_poly: cover_left_poly = c_left
	if not cover_right_poly: cover_right_poly = c_right
	if not static_left: static_left = s_left
	if not static_right: static_right = s_right
	if not dynamic_poly: dynamic_poly = d_poly
	if not anim_player: anim_player = anim
	if not audio_player: audio_player = stream_player
	
	if dynamic_poly and anim_player:
		if dynamic_poly.get("anim_player") == null:
			dynamic_poly.set("anim_player", anim_player)
	
	__ensure_node("RuntimeSpine", Polygon2D, visual_cont)
	
	if Vector2(_slot_1.size) != target_page_size and mesh_manager:
		mesh_manager.apply_new_size()


func _enter_tree() -> void:
	if not is_in_group("FlipBook2D"):
		add_to_group("FlipBook2D")
	BookAPI.set_current_book(self)


func _exit_tree() -> void:
	if BookAPI.get_current_book() == self:
		BookAPI.set_current_book(null)


func _ready():
	BookAPI.set_current_book(self)
	
	__init()
	
	if not _slot_1: _slot_1 = find_child("Slot1", true, false)
	if not _slot_2: _slot_2 = find_child("Slot2", true, false)
	if not _slot_3: _slot_3 = find_child("Slot3", true, false)
	if not _slot_4: _slot_4 = find_child("Slot4", true, false)
	
	if not Engine.is_editor_hint():
		book_opened.connect(_on_book_opened)
		book_closed.connect(_on_book_closed)
		ended_page_flip_animation.connect(_on_ended_page_flip_animation)

	if Engine.is_editor_hint():
		if dynamic_poly: dynamic_poly.rebuild(target_page_size)
		if mesh_manager:
			mesh_manager.apply_new_size()
		return
	
	if dynamic_poly and not dynamic_poly.material:
		dynamic_poly.material = preload("uid://ddw2ie8wnrnre")
	
	if dynamic_poly: dynamic_poly.rebuild(target_page_size)
	
	if not left_blank_page_texture or not right_blank_page_texture:
		var w = int(target_page_size.x)
		var h = int(target_page_size.y)
		
		if w > 0 and h > 0:
			var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
			img.fill(blank_page_color)
			
			if not left_blank_page_texture:
				left_blank_page_texture = ImageTexture.create_from_image(img)
				
			if not right_blank_page_texture:
				right_blank_page_texture = ImageTexture.create_from_image(img)

	if content_manager:
		content_manager.prepare_book_content()
	
	if not Engine.is_editor_hint():
		match start_option:
			StartOption.CLOSED_FROM_FRONT:
				current_spread = -1
			StartOption.CLOSED_FROM_BACK:
				current_spread = total_spreads
			StartOption.OPEN_AT_PAGE:
				var spread_idx = int(floor((start_page - 1) / 2.0))
				current_spread = clampi(spread_idx, 0, total_spreads - 1)
	
	if dynamic_poly and not dynamic_poly.is_connected("change_page_requested", _on_midpoint_signal):
		dynamic_poly.connect("change_page_requested", _on_midpoint_signal)
	
	if anim_player and not anim_player.is_connected("animation_finished", _on_animation_finished):
		anim_player.animation_finished.connect(_on_animation_finished)

	await get_tree().process_frame
	
	if _slot_3 and dynamic_poly:
		dynamic_poly.texture = _slot_3.get_texture()
	
	if mesh_manager:
		mesh_manager.apply_new_size()
		mesh_manager.init_perspective_material()
	_initial_config()
	
	get_tree().process_frame.connect(_force_initial_transform.bind(), CONNECT_ONE_SHOT)


func _on_book_opened() -> void:
	if _fake_volume_layer0:
		var t = create_tween()
		t.tween_property(_fake_volume_layer0, "modulate:a", 0.0, 0.3)
	
	if not _pending_opened_signal:
		_pending_opened_signal = true
		start_opening.emit()
		_check_instant_open.call_deferred()


func _on_book_closed() -> void:
	if _fake_volume_layer0:
		var t = create_tween()
		t.tween_property(_fake_volume_layer0, "modulate:a", 1.0, 0.3)
	
	if not _pending_closed_signal:
		_pending_closed_signal = true
		start_closing.emit()
		_check_instant_close.call_deferred()


func emit_start_opening() -> void:
	if not _pending_opened_signal:
		_pending_opened_signal = true
		book_opened.emit()
		start_opening.emit()
		_check_instant_open.call_deferred()


func emit_start_closing() -> void:
	if not _pending_closed_signal:
		_pending_closed_signal = true
		book_closed.emit()
		start_closing.emit()
		_check_instant_close.call_deferred()


func _check_instant_open() -> void:
	if _pending_opened_signal and not is_animating:
		_pending_opened_signal = false
		opened.emit()


func _check_instant_close() -> void:
	if _pending_closed_signal and not is_animating:
		_pending_closed_signal = false
		closed.emit()


func _on_ended_page_flip_animation() -> void:
	if _pending_opened_signal:
		_pending_opened_signal = false
		opened.emit()
	if _pending_closed_signal:
		_pending_closed_signal = false
		closed.emit()


func _force_initial_transform():
	if anim_player and anim_player.has_animation("RESET"):
		anim_player.play("RESET")
		anim_player.advance(0)
		anim_player.stop()
		
	_snap_book_to_exact_state()


func set_new_pages(pages: Array[String]) -> void:
	pages_paths = pages
	current_spread = -1
	if content_manager:
		content_manager.prepare_book_content()
	_initial_config()


func _initial_config():
	page_width = target_page_size.x
	
	_set_page_visible(dynamic_poly, false)
	if mesh_manager:
		mesh_manager.build_spine()
	if volume_manager:
		volume_manager.generate_volume_layers()
	_snap_book_to_exact_state()
	if mesh_manager:
		mesh_manager.update_static_visuals_immediate()
	if volume_manager:
		volume_manager.update_volume_visuals()
	_check_scene_activation.call_deferred()


func _snap_book_to_exact_state() -> void:
	var is_closed_now = (current_spread == -1 or current_spread == total_spreads)
	var is_back_now = (current_spread == total_spreads)
	
	is_book_open = not is_closed_now
	
	var compensation_offset = Vector2.ZERO
	if anim_manager:
		compensation_offset = anim_manager.get_compensation_offset(is_closed_now, is_back_now)
	var camera = get_viewport().get_camera_2d()
	var screen_center = camera.get_screen_center_position() if camera else get_viewport().size * 0.5
	
	var extra_offset = open_offset
	
	if is_closed_now:
		if is_back_now:
			extra_offset = closed_back_offset
		else:
			extra_offset = closed_offset
			
	var final_pos = screen_center + compensation_offset - Vector2(target_page_size.x / 2.0, 0.0) + extra_offset
	
	visuals_container.global_position = final_pos
	
	if anim_manager:
		anim_manager.animate_container_transform(is_closed_now, is_back_now, 0.0)
	
	_current_expansion_factor = 1.0 if is_closed_now else 0.0
	_visual_spread_index = float(total_spreads) if is_back_now else (-1.0 if is_closed_now else float(current_spread))
	_stack_scale_left = 0.0 if current_spread <= 0 else 1.0
	_stack_scale_right = 0.0 if current_spread >= total_spreads - 1 else 1.0
	
	if dynamic_poly and dynamic_poly.has_method("reset_bones_to_rest"):
		dynamic_poly.reset_bones_to_rest()
		
	if volume_manager:
		volume_manager.update_stack_direct(_current_expansion_factor, _visual_spread_index)
		volume_manager.update_volume_visuals()
	update_slot_render_modes()
#endregion


#region Visual and Volume Management Block
func _get_curve_factor_for_spread(spread: float) -> float:
	if mesh_manager:
		return mesh_manager.get_curve_factor_for_spread(spread)
	return 1.0


func _get_blended_arrays(curve_factor: float) -> Dictionary:
	if mesh_manager:
		return mesh_manager.get_blended_arrays(curve_factor)
	return {}


func _get_blended_dynamic_arrays(curve_factor: float) -> Dictionary:
	if mesh_manager:
		return mesh_manager.get_blended_dynamic_arrays(curve_factor)
	return {}


func _sync_skeleton_to_shadow(source: Polygon2D, target: Polygon2D) -> void:
	if mesh_manager:
		mesh_manager.sync_skeleton_to_shadow(source, target)


func _init_perspective_material() -> void:
	if mesh_manager:
		mesh_manager.init_perspective_material()


func _set_spine_color(color: Color) -> void:
	spine_color = color
	var node = find_child("RuntimeSpine")
	if node: node.color = spine_color
	if volume_spine: volume_spine.color = spine_color.darkened(0.8)
	
	if visuals_container and mesh_manager:
		mesh_manager.build_spine()


func _set_spine_texture(texture: Texture2D) -> void:
	spine_texture = texture
	var node = find_child("RuntimeSpine")
	if node: node.texture = spine_texture
	if volume_spine: volume_spine.texture = spine_texture


func _set_spine_value(value: float) -> void:
	spine_width = value
	if visuals_container and mesh_manager:
		mesh_manager.build_spine()


func _on_apply_size_pressed(val):
	if not val: return
	apply_size_change = false
	if is_inside_tree() and mesh_manager:
		mesh_manager.apply_new_size()
		if not is_animating:
			mesh_manager.update_static_visuals_immediate()


func _apply_new_size():
	if mesh_manager:
		mesh_manager.apply_new_size()


func _update_viewports_recursive(node: Node, new_size: Vector2):
	if setup_manager:
		setup_manager.update_viewports_recursive(node, new_size)


func _fit_camera_to_book():
	if mesh_manager:
		mesh_manager.fit_camera_to_book()


func _build_spine():
	if mesh_manager:
		mesh_manager.build_spine()


func _set_page_visible(node: Node2D, show: bool):
	if node: node.visible = show


func _update_static_visuals_immediate():
	if mesh_manager:
		mesh_manager.update_static_visuals_immediate()


func refresh() -> void:
	if mesh_manager:
		mesh_manager.update_static_visuals_immediate()
	_set_spine_texture(spine_texture)
	_set_spine_color(spine_color)


func _generate_volume_layers() -> void:
	if volume_manager:
		volume_manager.generate_volume_layers()


func _get_layer_count_for_spread_float(spread_idx: float, total_layers: int) -> float:
	if volume_manager:
		return volume_manager.get_layer_count_for_spread_float(spread_idx, total_layers)
	return 0.0


func _update_stack_direct(expansion_factor: float, visual_spread: float):
	if volume_manager:
		volume_manager.update_stack_direct(expansion_factor, visual_spread)


func _tween_expansion_only(factor: float):
	if volume_manager:
		volume_manager.tween_expansion_only(factor)


func _update_volume_visuals():
	if volume_manager:
		volume_manager.update_volume_visuals()


func _get_layer_count_for_spread(spread_idx: float, total_layers: int) -> int:
	if volume_manager:
		return volume_manager.get_layer_count_for_spread(spread_idx, total_layers)
	return 0


func _apply_perspective_to_node(node: Node2D, tl: Vector2, tr: Vector2, bl: Vector2, br: Vector2, bw: float, bh: float) -> void:
	if mesh_manager:
		mesh_manager.apply_perspective_to_node(node, tl, tr, bl, br, bw, bh)


func _update_perspective(factor: float) -> void:
	if mesh_manager:
		mesh_manager.update_perspective(factor)


func _get_compensation_offset(is_closed: bool, is_back: bool) -> Vector2:
	if anim_manager:
		return anim_manager.get_compensation_offset(is_closed, is_back)
	return Vector2.ZERO


func _animate_container_transform(target_is_closed: bool, is_back: bool, duration: float):
	if anim_manager:
		anim_manager.animate_container_transform(target_is_closed, is_back, duration)
#endregion


#region Input and Interaction Block
func _calculate_raw_curve_offset(px: float, w: float, is_left: bool) -> float:
	if input_manager:
		return input_manager._calculate_raw_curve_offset(px, w, is_left)
	return 0.0


func _inject_event_to_viewport(viewport: SubViewport, polygon: Polygon2D, event: InputEvent) -> Control.CursorShape:
	if input_manager:
		return input_manager._inject_event_to_viewport(viewport, polygon, event)
	return Control.CURSOR_ARROW


func viewport_to_global_curved(viewport_pos: Vector2, is_left: bool) -> Vector2:
	if input_manager:
		return input_manager.viewport_to_global_curved(viewport_pos, is_left)
	return Vector2.ZERO


func _reset_viewport_input_state() -> void:
	if input_manager:
		input_manager._reset_viewport_input_state()


func _input(event):
	if input_manager:
		input_manager.process_input(event)


func _unhandled_input(event):
	if input_manager:
		input_manager.process_unhandled_input(event)


func _pageflip_set_input_enabled(give_control_to_book: bool):
	set_process_unhandled_input(give_control_to_book)
	if _slot_1.get_child_count() > 0:
		var node = _slot_1.get_child(-1)
		if node.has_meta("_pageflip_node") and node.has_signal("manage_pageflip"):
			node.set_process_input(not give_control_to_book)
			node.set_process_unhandled_input(not give_control_to_book)
			_active_interactive_is_left = not give_control_to_book
	if _slot_2.get_child_count() > 0:
		var node = _slot_2.get_child(-1)
		if node.has_meta("_pageflip_node") and node.has_signal("manage_pageflip"):
			node.set_process_input(not give_control_to_book)
			node.set_process_unhandled_input(not give_control_to_book)
			_active_interactive_is_right = not give_control_to_book


func update_slot_render_modes() -> void:
	var is_closed_now = (current_spread == -1 or current_spread == total_spreads)
	if _slot_1:
		_slot_1.render_target_update_mode = SubViewport.UPDATE_ONCE if is_closed_now else SubViewport.UPDATE_ALWAYS
	if _slot_2:
		_slot_2.render_target_update_mode = SubViewport.UPDATE_ONCE if is_closed_now else SubViewport.UPDATE_ALWAYS


func _check_scene_activation() -> void:
	update_slot_render_modes()
	var scene_found = false
	var transferred_scene = null
	if _slot_1.get_child_count() > 0:
		var node = _slot_1.get_child(-1)
		if node.has_meta("_pageflip_node") and node.has_signal("manage_pageflip"):
			node.emit_signal("manage_pageflip", false)
			node.set_process_input(true)
			node.set_process_unhandled_input(true)
			scene_found = true
			transferred_scene = node
	if _slot_2.get_child_count() > 0:
		var node = _slot_2.get_child(-1)
		if node.has_meta("_pageflip_node") and node.has_signal("manage_pageflip"):
			node.emit_signal("manage_pageflip", false)
			node.set_process_input(true)
			node.set_process_unhandled_input(true)
			scene_found = true
			transferred_scene = node
	if not scene_found:
		_pageflip_set_input_enabled(true)
		transferred_controls.emit(self)
	elif transferred_scene:
		transferred_controls.emit(transferred_scene)
#endregion


#region Navigation and Animation Block
func next_page():
	if anim_manager:
		anim_manager.next_page()


func prev_page():
	if anim_manager:
		anim_manager.prev_page()


func _try_emit_book_signals(_direction: String) -> void:
	if anim_manager:
		anim_manager.try_emit_book_signals(_direction)


func _go_to_page(target_spread_idx: int, total_time: float = 0.5) -> void:
	if anim_manager:
		anim_manager._go_to_page(target_spread_idx, total_time)


func go_to_page(page_num: int = 1, target: JumpTarget = JumpTarget.CONTENT_PAGE, total_time: float = 0.5) -> void:
	if anim_manager:
		var target_int = 0
		match target:
			JumpTarget.FRONT_COVER: target_int = 1
			JumpTarget.BACK_COVER: target_int = 2
			JumpTarget.CONTENT_PAGE: target_int = 0
		anim_manager.go_to_page(page_num, target_int, total_time)


func force_close_book(to_front_cover: bool):
	if anim_manager:
		anim_manager.force_close_book(to_front_cover)


func _set_flying_slots_active(is_active: bool) -> void:
	if anim_manager:
		anim_manager.set_flying_slots_active(is_active)


func _start_animation(forward: bool) -> void:
	if anim_manager:
		anim_manager.start_animation(forward)


func _on_page_landed_early():
	if anim_manager:
		anim_manager.on_page_landed_early()


func _process(delta):
	if visuals_container and is_animating:
		if volume_manager:
			volume_manager.update_stack_direct(_current_expansion_factor, _visual_spread_index)
			volume_manager.update_volume_visuals()
		if mesh_manager:
			mesh_manager.process_animation_update(delta)


func _on_midpoint_signal():
	pass


func _on_animation_finished(anim_name: String):
	if anim_manager:
		anim_manager.on_animation_finished(anim_name)


func _perform_close_action():
	var was_open = (current_spread != -1 and current_spread != total_spreads)
	if was_open:
		emit_start_closing()
		_pending_closed_signal = false
		closed.emit()
	if close_behavior == CloseBehavior.DESTROY_BOOK: queue_free()
	elif close_behavior == CloseBehavior.CHANGE_SCENE:
		if target_scene_on_close != "": get_tree().change_scene_to_file(target_scene_on_close)
#endregion


#region Content Rendering Block
func _get_page_index_for_spread(spread_idx: int, is_left: bool) -> int:
	if anim_manager:
		return anim_manager.get_page_index_for_spread(spread_idx, is_left)
	return -999


func _update_slot_content(slot: SubViewport, content_index: int, is_left: bool) -> void:
	if content_manager:
		content_manager.update_slot_content(slot, content_index, is_left)


func _setup_texture_in_slot(slot: SubViewport, tex: Texture2D, is_left_page: bool, is_cover: bool):
	if content_manager:
		content_manager.setup_texture_in_slot(slot, tex, is_left_page, is_cover)


func _setup_scene_in_slot(slot: SubViewport, scene_pkg: PackedScene, texture_index: int, is_left_page: bool, is_cover: bool):
	if content_manager:
		content_manager.setup_scene_in_slot(slot, scene_pkg, texture_index, is_left_page, is_cover)


func _add_composite_blank_bg(slot: SubViewport, is_left_page: bool, apply_margin: bool = false) -> void:
	if content_manager:
		content_manager.add_composite_blank_bg(slot, is_left_page, apply_margin)


func _prune_scene_cache() -> void:
	if content_manager:
		content_manager.prune_scene_cache()
#endregion


#region Audio Management Block
func play_sound(stream: AudioStream) -> void:
	if audio_manager:
		audio_manager.play_sound(stream)


func _play_sound(stream: AudioStream):
	if audio_manager:
		audio_manager.play_sound(stream)
#endregion
