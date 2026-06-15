@tool
class_name PageFlip2D
extends Node2D

## Main controller for the Book system. Handles animations, volume logic, and interactive scenes.
##
## [b]ADVANCED FEATURE: INTERACTIVE PAGE SCENES (INPUT HANDSHAKE)[/b][br]
## This script supports fully interactive scenes (UI, puzzles, maps) embedded as pages.[br]
## It automatically manages an "Input Handshake" to prevent conflicts between[br]
## the Book (turning pages) and the Scene (interaction).[br]
## [br]
## [b]LOGIC FLOW:[/b][br]
## - Uses 4 internal Viewport Slots.[br]
## - Slot 1: Static Left Page.[br]
## - Slot 2: Static Right Page.[br]
## - Slot 3: Dynamic Page Face A (Front).[br]
## - Slot 4: Dynamic Page Face B (Back).[br]
## - The Shader handles the visibility of Face A vs Face B automatically.

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
@export var apply_newold_preset: bool = false : set = _apply_newold_config

## Button to preview the book visually inside the editor.
@export_tool_button("Preview in editor") var preview_in_editor =  _on_preview_in_editor_pressed


@export_category("Structure References")
## Container for all book visuals (Pages, Covers, Spine).
@export var visuals_container: Node
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
@export var start_option: StartOption = StartOption.CLOSED_FROM_FRONT : set = _set_start_option
## The page number to open at startup.
## If any of the pages that remain open are interactive scenes,
## the script will automatically transfer control to them.[br][br]
## Note: Since an even page (Left) and the next odd page (Right) share the same spread,
## selecting either of them will result in the book opening to the same visual state.
@export var start_page: int = 1
## Determines when the book should perform the close action (e.g., destroy or change scene).
@export var close_condition: CloseCondition = CloseCondition.NEVER
## Determines what happens when the book closes (Destroy or Change Scene).
@export var close_behavior: CloseBehavior = CloseBehavior.DESTROY_BOOK : set = _set_close_behavior
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
@export var spine_color: Color = Color(1, 1, 1) : set = _set_spine_color
## Texture for the central spine of the book.
@export var spine_texture: Texture2D : set = _set_spine_texture
## Width of the central spine in pixels.
@export var spine_width: float = 40.0 : set = _set_spine_value
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
## Custom visual position offset when the book is fully closed.
@export var closed_offset: Vector2 = Vector2.ZERO


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
## Button to apply size changes in the editor.
@export var apply_size_change: bool = false : set = _on_apply_size_pressed


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

var _is_jumping: bool = false
var _jump_target_spread: int = 0
var _auto_turn_target_spread: int = -999

var _active_viewports_state: Dictionary = {}

var _dynamic_auto_speed: float = 1.0

var volume_spine: Polygon2D

var disabled = false

signal started_page_flip_animation()
signal ended_page_flip_animation()
signal book_opened()
signal book_closed()



#region Initialization and Configuration Block
## Validates properties in the editor.
func _validate_property(property: Dictionary) -> void:
	if property.name == "target_scene_on_close":
		if close_behavior != CloseBehavior.CHANGE_SCENE:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	
	if property.name == "start_page":
		if start_option != StartOption.OPEN_AT_PAGE:
			property.usage = PROPERTY_USAGE_NO_EDITOR


## Sets the behavior executed upon closing the book.
func _set_close_behavior(value):
	close_behavior = value
	notify_property_list_changed()


## Sets the start option for the book.
func _set_start_option(value):
	start_option = value
	notify_property_list_changed()


## Set Book Speed Scale
func set_speed_scale(_speed: float) -> void:
	if anim_player:
		anim_player.speed_scale = _speed


## Applies the custom Newold configuration preset.
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
	sfx_book_impact = preload("uid://bhitebdghyhua")
	sfx_page_flip = preload("uid://bylfc3b5pmbij")
	impact_sync_offset = 0.15
	target_page_size = Vector2(512, 820)
	page_stretch_mode = PageStretchOption.SCALE
	tex_cover_front_out = preload("uid://dbdwbowx32d3v")
	tex_cover_front_in = preload("uid://dt1tiecgw5rip")
	tex_cover_back_in = preload("uid://dt1tiecgw5rip")
	tex_cover_back_out = preload("uid://bjowpx1ap4uxt")
	_apply_new_size()
	dynamic_poly.animation_preset = DynamicPage.PagePreset.LIGHT_MAGAZINE
	notify_property_list_changed()


## Triggered when the preview in editor button is pressed.
func _on_preview_in_editor_pressed(value: bool) -> void:
	if not value:
		return
		
	preview_in_editor = false
	
	if Engine.is_editor_hint():
		_force_editor_preview()


## Forces an editor preview of the book.
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
			
	_prepare_book_content()
	
	match start_option:
		StartOption.CLOSED_FROM_FRONT:
			current_spread = -1
		StartOption.CLOSED_FROM_BACK:
			current_spread = total_spreads
		StartOption.OPEN_AT_PAGE:
			var spread_idx = int(floor((start_page - 1) / 2.0))
			current_spread = clampi(spread_idx, 0, total_spreads - 1)
			
	_init_perspective_material()
	_initial_config()
	_set_flying_slots_active(false)


## Initializes the node structure and viewports.
func __init():
	var viewports_cont = __ensure_node("Viewports", Node, self)
	var slots_cont = __ensure_node("Slots", Node, viewports_cont)
	var visual_cont = __ensure_node("Visual", Node2D, self)

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

	var s_left = __ensure_node("StaticPageLeft", Polygon2D, visual_cont)
	s_left.z_index = 1
	var s_right = __ensure_node("StaticPageRight", Polygon2D, visual_cont)
	s_right.z_index = 1
	var d_poly = __ensure_node("DynamicFlipPoly", Polygon2D, visual_cont)
	d_poly.z_index = 10
	d_poly.clip_children = Control.ClipChildrenMode.CLIP_CHILDREN_AND_DRAW
	
	if d_poly.get_script() == null:
		d_poly.set_script(load("res://addons/PageFlip/page_rigger.gd"))

	var anim = __ensure_node("AnimationPlayer", AnimationPlayer, self)
	__ensure_node("Camera2D", Camera2D, self)
	var stream_player = __ensure_node("AudioStreamPlayer", AudioStreamPlayer, self)

	if not visuals_container: visuals_container = visual_cont
	if not static_left: static_left = s_left
	if not static_right: static_right = s_right
	if not dynamic_poly: dynamic_poly = d_poly
	if not anim_player: anim_player = anim
	if not audio_player: audio_player = stream_player
	
	if dynamic_poly and anim_player:
		if dynamic_poly.get("anim_player") == null:
			dynamic_poly.set("anim_player", anim_player)
	
	__ensure_node("RuntimeSpine", Polygon2D, visual_cont)
	
	if Vector2(_slot_1.size) != target_page_size:
		_apply_new_size()


## Ensures a child node exists by finding it or creating it.
func __ensure_node(target_name: String, type: Variant, parent_node: Node) -> Node:
	var node = parent_node.get_node_or_null(target_name)
	if node: return node
	node = type.new()
	node.name = target_name
	if node is SubViewport: node.transparent_bg = true
	parent_node.add_child(node)
	if Engine.is_editor_hint(): node.owner = parent_node.owner if parent_node.owner else self
	return node


## Called when the node enters the scene tree.
func _enter_tree() -> void:
	if not is_in_group("FlipBook2D"):
		add_to_group("FlipBook2D")
	BookAPI.set_current_book(self)


## Called when the node leaves the scene tree.
func _exit_tree() -> void:
	if BookAPI.get_current_book() == self:
		BookAPI.set_current_book(null)


## Called when the node is ready. Sets up visuals, logic, and internal references.
func _ready():
	BookAPI.set_current_book(self)
	if not _slot_1: _slot_1 = find_child("Slot1", true, false)
	if not _slot_2: _slot_2 = find_child("Slot2", true, false)
	if not _slot_3: _slot_3 = find_child("Slot3", true, false)
	if not _slot_4: _slot_4 = find_child("Slot4", true, false)

	if Engine.is_editor_hint():
		__init()
		if dynamic_poly: dynamic_poly.rebuild(target_page_size)
		return
	elif Vector2(_slot_1.size) != target_page_size:
		_apply_new_size()
	
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

	_prepare_book_content()
	
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
	
	_init_perspective_material()
	_initial_config()
	
	get_tree().process_frame.connect(_force_initial_transform.bind(), CONNECT_ONE_SHOT)


## Forces the initial transform after the AnimationPlayer's automatic RESET phase.
func _force_initial_transform():
	var is_closed = (current_spread == -1 or current_spread == total_spreads)
	var is_back = (current_spread == total_spreads)
	
	_current_expansion_factor = 1.0 if is_closed else 0.0
	_visual_spread_index = float(total_spreads) if is_back else ( -1.0 if is_closed else float(current_spread) )
	
	_stack_scale_left = 0.0 if current_spread <= 1 else 1.0
	_stack_scale_right = 0.0 if current_spread >= total_spreads - 1 else 1.0
	
	var cam = get_viewport().get_camera_2d()
	var screen_center = cam.get_screen_center_position() if cam else (get_viewport().get_visible_rect().size / 2.0)
	
	if is_closed:
		var offset = _get_compensation_offset(true, is_back)
		visuals_container.global_position = screen_center + offset - Vector2(target_page_size.x / 2, 0.0) + closed_offset
		_animate_container_transform(true, is_back, 0.0)
	else:
		var offset = _get_compensation_offset(false, false)
		visuals_container.global_position = screen_center + offset - Vector2(target_page_size.x / 2, 0.0) + open_offset
		_animate_container_transform(false, false, 0.0)
		
	if dynamic_poly and dynamic_poly.has_method("reset_bones_to_rest"):
		dynamic_poly.reset_bones_to_rest()
		
	_update_stack_direct(_current_expansion_factor, _visual_spread_index)
	_update_volume_visuals()


## Applies initial state configurations for visuals and positions.
func _initial_config():
	page_width = target_page_size.x
	var screen_center = get_viewport().get_camera_2d().get_screen_center_position()

	_set_page_visible(dynamic_poly, false)

	_build_spine()
	_generate_volume_layers()
	_visual_spread_index = float(current_spread)

	_stack_scale_left = 0.0 if current_spread <= 1 else 1.0
	_stack_scale_right = 0.0 if current_spread >= total_spreads - 1 else 1.0

	var is_closed = (current_spread == -1 or current_spread == total_spreads)
	is_book_open = not is_closed
	var is_back = (current_spread == total_spreads)

	if is_closed:
		var offset = _get_compensation_offset(true, is_back)
		visuals_container.global_position = screen_center + offset - Vector2(target_page_size.x / 2, 0.0) + closed_offset
		_animate_container_transform(true, is_back, 0.0)
		if is_back: _update_stack_direct(1.0, float(total_spreads))
		else: _update_stack_direct(1.0, -1.0)
	else:
		var offset = _get_compensation_offset(false, false)
		visuals_container.global_position = screen_center + offset - Vector2(target_page_size.x / 2, 0.0) + open_offset
		_animate_container_transform(false, false, 0.0)
		_update_stack_direct(0.0, float(current_spread))

	_update_static_visuals_immediate()
	_update_volume_visuals()
	_check_scene_activation.call_deferred()


## Fills the internal arrays based on the requested images or scenes.
func _prepare_book_content():
	_runtime_pages = pages_paths.duplicate()
	if _runtime_pages.size() > 0 and _runtime_pages.size() % 2 != 0:
		_runtime_pages.append("internal://blank_page")
	var num = _runtime_pages.size()
	if num == 0: total_spreads = 1
	else: total_spreads = (num / 2) + 1
#endregion


#region Visual and Volume Management Block
## Initializes the shared perspective material for the static pages.
func _init_perspective_material() -> void:
	if not perspective_shader:
		return
		
	if static_left and not static_left.material:
		static_left.material = ShaderMaterial.new()
		static_left.material.shader = perspective_shader
		
	if static_right and not static_right.material:
		static_right.material = ShaderMaterial.new()
		static_right.material.shader = perspective_shader


## Sets the spine color and updates its visual.
func _set_spine_color(color: Color) -> void:
	spine_color = color
	var node = find_child("RuntimeSpine")
	if node: node.color = spine_color
	if volume_spine: volume_spine.color = spine_color.darkened(0.8)
	
	if visuals_container:
		_build_spine()


## Sets the spine texture and updates its visual.
func _set_spine_texture(texture: Texture2D) -> void:
	spine_texture = texture
	var node = find_child("RuntimeSpine")
	if node: node.texture = spine_texture
	if volume_spine: volume_spine.texture = spine_texture


## Sets the spine width and rebuilds it.
func _set_spine_value(value: float) -> void:
	spine_width = value
	if visuals_container:
		_build_spine()


## Triggers size rebuild from the editor inspector.
func _on_apply_size_pressed(val):
	if not val: return
	apply_size_change = false
	_apply_new_size()


## Rebuilds the visual meshes, viewports, and arrays for a new page size.
func _apply_new_size():
	page_width = target_page_size.x
	_update_viewports_recursive(self, target_page_size)
	var w = target_page_size.x
	var h = target_page_size.y
	
	var sub_x = 8
	var sub_y = 5
	if dynamic_poly and dynamic_poly.get("subdivision_x") != null:
		sub_x = dynamic_poly.get("subdivision_x")
		sub_y = dynamic_poly.get("subdivision_y")
		
	var step_x = w / float(sub_x)
	var step_y = h / float(sub_y)
	
	var grid_points = PackedVector2Array()
	var grid_uvs = PackedVector2Array()
	var grid_polys = []
	
	var rc = sub_x + 1
	for y in range(sub_y + 1):
		for x in range(sub_x + 1):
			grid_points.append(Vector2(x * step_x, (y * step_y) - h / 2.0))
			grid_uvs.append(Vector2(x * step_x, y * step_y))
			
	for y in range(sub_y):
		for x in range(sub_x):
			var i = y * rc + x
			grid_polys.append(PackedInt32Array([i, i + 1, i + rc + 1, i + rc]))

	if static_left:
		static_left.polygon = grid_points
		static_left.uv = grid_uvs
		static_left.polygons = grid_polys
		static_left.position = Vector2(-w, 0)
		static_left.visible = false
	if static_right:
		static_right.polygon = grid_points
		static_right.uv = grid_uvs
		static_right.polygons = grid_polys
		static_right.position = Vector2(0, 0)
		static_right.visible = true
		
	if dynamic_poly:
		dynamic_poly.position = Vector2(0.0, -h / 2.0)
		dynamic_poly.visible = false
		if dynamic_poly.has_method("rebuild"): dynamic_poly.rebuild(target_page_size)

	_build_spine()
	_generate_volume_layers()
	_fit_camera_to_book()


## Recursively updates the size of all subviewports inside a given node.
func _update_viewports_recursive(node: Node, new_size: Vector2):
	for child in node.get_children():
		if child is SubViewport:
			child.size = new_size; child.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if child.get_child_count() > 0: _update_viewports_recursive(child, new_size)


## Fits the editor camera precisely to the size of the book.
func _fit_camera_to_book():
	var cam = get_node_or_null("Camera2D")
	if not cam: return
	var total_book_width = target_page_size.x * 2.0
	var total_book_height = target_page_size.y * 2.0
	var margin = 1.0
	var required_width = total_book_width * margin
	var required_height = total_book_height * margin
	var screen_size = get_viewport_rect().size
	if screen_size == Vector2.ZERO: return
	var zoom_x = screen_size.x / required_width
	var zoom_y = screen_size.y / required_height
	var final_zoom = min(zoom_x, zoom_y)
	cam.zoom = Vector2(final_zoom, final_zoom)


## Rebuilds the geometry of the central spine to match sizes and offsets.
func _build_spine():
	if _spine_poly and is_instance_valid(_spine_poly): _spine_poly.queue_free()
	elif visuals_container.has_node("RuntimeSpine"):
		var node = visuals_container.get_node("RuntimeSpine")
		node.queue_free()
		visuals_container.remove_child(node)
		
	if spine_width <= 0: return
	
	_spine_poly = Polygon2D.new()
	_spine_poly.name = "RuntimeSpine"
	_spine_poly.z_index = 15
	_spine_poly.texture = spine_texture
	
	var hw = spine_width / 2.0 + 4
	var h = target_page_size.y
	_spine_poly.polygon = PackedVector2Array([Vector2(-hw, -h/2.0), Vector2(hw, -h/2.0), Vector2(hw, h/2.0), Vector2(-hw, h/2.0)])
	
	if spine_texture:
		var tw = spine_texture.get_width()
		var th = spine_texture.get_height()
		_spine_poly.uv = PackedVector2Array([Vector2(0, 0), Vector2(tw, 0), Vector2(tw, th), Vector2(0, th)])
	else: _spine_poly.color = spine_color
	
	if perspective_shader:
		_spine_poly.material = ShaderMaterial.new()
		_spine_poly.material.shader = perspective_shader
		
	visuals_container.add_child(_spine_poly)
	_spine_poly.position = Vector2.ZERO
	
	if Engine.is_editor_hint(): _spine_poly.owner = get_tree().edited_scene_root
	
	_update_perspective(_current_expansion_factor)


## Safely sets visibility on a node.
func _set_page_visible(node: Node2D, show: bool):
	if node: node.visible = show


## Renders visuals out instantly bypassing natural timing delays.
func _update_static_visuals_immediate():
	var idx_l = _get_page_index_for_spread(current_spread, true)
	var idx_r = _get_page_index_for_spread(current_spread, false)
	_update_slot_content(_slot_1, idx_l, true)
	_update_slot_content(_slot_2, idx_r, false)
	static_left.texture = _slot_1.get_texture()
	static_right.texture = _slot_2.get_texture()
	var valid_l = (idx_l != -999)
	var valid_r = (idx_r != -999)
	_set_page_visible(static_left, valid_l)
	_set_page_visible(static_right, valid_r)


## Refreshes the book's visual state and spine parameters immediately.
func refresh() -> void:
	_update_static_visuals_immediate()
	_set_spine_texture(spine_texture)
	_set_spine_color(spine_color)


## Generates the simulated 3D volume layers under the book.
func _generate_volume_layers() -> void:
	if _volume_root and is_instance_valid(_volume_root):
		_volume_root.queue_free()
		
	var final_layer_count = 0
	
	if total_spreads > 0:
		final_layer_count = clampi(total_spreads, min_layers, max_layers)
		
	if final_layer_count <= 0:
		return
		
	_volume_root = Node2D.new()
	_volume_root.name = "VolumeStackPages"
	visuals_container.add_child(_volume_root)
	visuals_container.move_child(_volume_root, 0)
	
	var vol_spine = Polygon2D.new()
	vol_spine.name = "VolumeSpine"
	vol_spine.color = spine_color.darkened(0.8)
	vol_spine.z_index = -1
	
	volume_spine = vol_spine
	
	if spine_texture:
		vol_spine.texture = spine_texture
		
	if perspective_shader:
		vol_spine.material = ShaderMaterial.new()
		vol_spine.material.shader = perspective_shader
		
	_volume_root.add_child(vol_spine)
	
	for i in range(final_layer_count):
		var layer_node = Node2D.new()
		layer_node.name = "Layer_%d" % i
		
		var s_left = static_left.duplicate()
		var s_right = static_right.duplicate()
		
		if i == 0 and covers_are_rigid:
			s_left.modulate = cover_protrude_color
			s_right.modulate = cover_protrude_color
			s_left.scale = cover_protrude_scale
			s_right.scale = cover_protrude_scale
		else:
			var layer_col = volume_color
			if i % 2 != 0:
				layer_col.r *= stripe_darken_ratio
				layer_col.g *= stripe_darken_ratio
				layer_col.b *= stripe_darken_ratio
			s_left.modulate = layer_col
			s_right.modulate = layer_col
			
		s_left.position = Vector2.ZERO
		s_right.position = Vector2.ZERO
		
		s_left.set_script(null)
		s_right.set_script(null)
		
		s_left.texture = left_blank_page_texture if left_blank_page_texture else null
		s_right.texture = right_blank_page_texture if right_blank_page_texture else null
		
		if perspective_shader:
			s_left.material = ShaderMaterial.new()
			s_left.material.shader = perspective_shader
			s_right.material = ShaderMaterial.new()
			s_right.material.shader = perspective_shader
			
		layer_node.add_child(s_left)
		layer_node.add_child(s_right)
		
		_volume_root.add_child(layer_node)


## Calculates floating-point fractional layer count for smooth spine tweening.
func _get_layer_count_for_spread_float(spread_idx: float, total_layers: int) -> float:
	if total_spreads <= 2: return 0.0
	var effective_total = float(total_spreads - 2)
	var adjusted_idx = spread_idx - 1.0
	var real_max = max(1.0, effective_total)
	var safe_spread = clamp(adjusted_idx, 0.0, real_max)
	var ratio = safe_spread / real_max
	return ratio * float(total_layers)


## Updates the visual stack volume rendering and positions.
func _update_stack_direct(expansion_factor: float, visual_spread: float):
	_current_expansion_factor = expansion_factor
	_visual_spread_index = visual_spread
	
	_update_perspective(expansion_factor)
	
	if not _volume_root: return
	
	var current_step = layer_offset_open.lerp(layer_offset_closed, expansion_factor)
	var total_layers = 0
	
	for child in _volume_root.get_children():
		if child.name.begins_with("Layer_"):
			total_layers += 1
			
	var y_dir = -1.0 if invert_stack_direction else 1.0
	var count_left = 0
	var count_right = 0
	
	if is_animating:
		var layers_at_start = int(round(_get_layer_count_for_spread_float(float(current_spread), total_layers)))
		var layers_at_target = int(round(_get_layer_count_for_spread_float(float(_pending_target_spread_idx), total_layers)))
		if going_forward:
			count_left = layers_at_start
			count_right = total_layers - layers_at_target
		else:
			count_left = layers_at_target
			count_right = total_layers - layers_at_start
			
		var L_start_is_thin = (layers_at_start == 0)
		var L_target_is_thin = (layers_at_target == 0)
		if L_start_is_thin != L_target_is_thin: count_left = max(layers_at_start, layers_at_target)

		var R_start_vol = total_layers - layers_at_start
		var R_target_vol = total_layers - layers_at_target
		var R_start_is_thin = (R_start_vol == 0)
		var R_target_is_thin = (R_target_vol == 0)
		if R_start_is_thin != R_target_is_thin: count_right = max(R_start_vol, R_target_vol)
	else:
		count_left = int(round(_get_layer_count_for_spread_float(visual_spread, total_layers)))
		count_right = total_layers - count_left

	var force_hide_left = false
	var force_hide_right = false
	if _stack_scale_left <= 0.001: force_hide_left = true
	if _stack_scale_right <= 0.001: force_hide_right = true
	if _force_hide_vol_left: force_hide_left = true
	if _force_hide_vol_right: force_hide_right = true
	
	var vol_spine = _volume_root.get_node_or_null("VolumeSpine")
	
	if vol_spine and total_layers > 0:
		var left_depth_float = _get_layer_count_for_spread_float(_visual_spread_index, total_layers)
		var right_depth_float = float(total_layers) - left_depth_float
		
		var left_base_off_x = current_step.x * left_depth_float
		var left_base_off_y = current_step.y * left_depth_float * y_dir
		var bot_off_left = Vector2(-left_base_off_x, left_base_off_y) * _stack_scale_left
		
		var right_base_off_x = current_step.x * right_depth_float
		var right_base_off_y = current_step.y * right_depth_float * y_dir
		var bot_off_right = Vector2(right_base_off_x, right_base_off_y) * _stack_scale_right
		
		var effective_left_depth = left_depth_float if not force_hide_left else 0.0
		var effective_right_depth = right_depth_float if not force_hide_right else 0.0
		var mid_depth_float = max(effective_left_depth, effective_right_depth)
		
		var mid_depth_scale = (_stack_scale_left + _stack_scale_right) / 2.0
		var mid_base_off_y = current_step.y * mid_depth_float * y_dir
		var bot_off_mid = Vector2(0, mid_base_off_y) * mid_depth_scale
		
		if covers_are_rigid:
			bot_off_left += Vector2(-cover_protrude_offset.x, cover_protrude_offset.y) * _stack_scale_left
			bot_off_right += Vector2(cover_protrude_offset.x, cover_protrude_offset.y) * _stack_scale_right
			bot_off_mid += Vector2(0, cover_protrude_offset.y) * mid_depth_scale
				
		var margin_y = 2.0 * y_dir
		if left_depth_float > 0.01: bot_off_left.y += margin_y * _stack_scale_left
		if right_depth_float > 0.01: bot_off_right.y += margin_y * _stack_scale_right
		if mid_depth_scale > 0.01: bot_off_mid.y += margin_y * mid_depth_scale
		
		var margin = 2.0
		var hw = (spine_width / 2.0) + margin
		var h = target_page_size.y + (margin * 2.0)
		
		var p0 = Vector2(-hw, -h / 2.0)
		var p_top_mid = Vector2(0, -h / 2.0)
		var p1 = Vector2(hw, -h / 2.0)
		
		var p3 = Vector2(-hw, h / 2.0)
		var p_bot_mid = Vector2(0, h / 2.0)
		var p2 = Vector2(hw, h / 2.0)
		
		var p4 = p0 + bot_off_left
		var p_deep_top_mid = p_top_mid + bot_off_mid
		var p5 = p1 + bot_off_right
		
		var p7 = p3 + bot_off_left
		var p_deep_bot_mid = p_bot_mid + bot_off_mid
		var p6 = p2 + bot_off_right
		
		var pts = PackedVector2Array()
		var uvs = PackedVector2Array()
		var faces = []
		var face_idx = 0
		
		var tw = 1.0
		var th = 1.0
		if spine_texture:
			tw = float(spine_texture.get_width())
			th = float(spine_texture.get_height())
			
		var slice = 1.0
		var mid_u = tw / 2.0
		
		# 1. TOP LEFT THICKNESS
		pts.append_array([p4, p_deep_top_mid, p_top_mid, p0])
		uvs.append_array([Vector2(0, slice), Vector2(mid_u, slice), Vector2(mid_u, 0), Vector2(0, 0)])
		faces.append(PackedInt32Array([face_idx*4, face_idx*4+1, face_idx*4+2, face_idx*4+3]))
		face_idx += 1
		
		# 2. TOP RIGHT THICKNESS
		pts.append_array([p_deep_top_mid, p5, p1, p_top_mid])
		uvs.append_array([Vector2(mid_u, slice), Vector2(tw, slice), Vector2(tw, 0), Vector2(mid_u, 0)])
		faces.append(PackedInt32Array([face_idx*4, face_idx*4+1, face_idx*4+2, face_idx*4+3]))
		face_idx += 1
		
		# 3. BOTTOM LEFT THICKNESS
		pts.append_array([p3, p_bot_mid, p_deep_bot_mid, p7])
		uvs.append_array([Vector2(0, th), Vector2(mid_u, th), Vector2(mid_u, th - slice), Vector2(0, th - slice)])
		faces.append(PackedInt32Array([face_idx*4, face_idx*4+1, face_idx*4+2, face_idx*4+3]))
		face_idx += 1
		
		# 4. BOTTOM RIGHT THICKNESS
		pts.append_array([p_bot_mid, p2, p6, p_deep_bot_mid])
		uvs.append_array([Vector2(mid_u, th), Vector2(tw, th), Vector2(tw, th - slice), Vector2(mid_u, th - slice)])
		faces.append(PackedInt32Array([face_idx*4, face_idx*4+1, face_idx*4+2, face_idx*4+3]))
		face_idx += 1
		
		# 5. LEFT THICKNESS
		pts.append_array([p4, p0, p3, p7])
		uvs.append_array([Vector2(slice, 0), Vector2(0, 0), Vector2(0, th), Vector2(slice, th)])
		faces.append(PackedInt32Array([face_idx*4, face_idx*4+1, face_idx*4+2, face_idx*4+3]))
		face_idx += 1
		
		# 6. RIGHT THICKNESS
		pts.append_array([p1, p5, p6, p2])
		uvs.append_array([Vector2(tw, 0), Vector2(tw - slice, 0), Vector2(tw - slice, th), Vector2(tw, th)])
		faces.append(PackedInt32Array([face_idx*4, face_idx*4+1, face_idx*4+2, face_idx*4+3]))
		face_idx += 1
		
		# 7. BACK LEFT
		pts.append_array([p_deep_top_mid, p4, p7, p_deep_bot_mid])
		uvs.append_array([Vector2(mid_u, 0), Vector2(0, 0), Vector2(0, th), Vector2(mid_u, th)])
		faces.append(PackedInt32Array([face_idx*4, face_idx*4+1, face_idx*4+2, face_idx*4+3]))
		face_idx += 1
		
		# 8. BACK RIGHT
		pts.append_array([p5, p_deep_top_mid, p_deep_bot_mid, p6])
		uvs.append_array([Vector2(tw, 0), Vector2(mid_u, 0), Vector2(mid_u, th), Vector2(tw, th)])
		faces.append(PackedInt32Array([face_idx*4, face_idx*4+1, face_idx*4+2, face_idx*4+3]))
		face_idx += 1
		
		vol_spine.polygon = pts
		vol_spine.uv = uvs
		vol_spine.polygons = faces

	var left_threshold_idx = total_layers - count_left
	var right_threshold_idx = total_layers - count_right

	var current_layer_index = 0
	
	for child in _volume_root.get_children():
		if not child.name.begins_with("Layer_"):
			continue
			
		var depth_multiplier = float(total_layers - current_layer_index)
		
		var base_off_x = current_step.x * depth_multiplier
		var base_off_y = (current_step.y * depth_multiplier) * y_dir
		
		child.position = Vector2.ZERO
		
		var l_node = child.get_child(0)
		var r_node = child.get_child(1)
		
		var final_off_left = Vector2(-base_off_x, base_off_y) * _stack_scale_left
		var final_off_right = Vector2(base_off_x, base_off_y) * _stack_scale_right
		
		if current_layer_index == 0 and covers_are_rigid:
			final_off_left += Vector2(-cover_protrude_offset.x, cover_protrude_offset.y)
			final_off_right += Vector2(cover_protrude_offset.x, cover_protrude_offset.y)
		
		var show_l = (current_layer_index >= left_threshold_idx)
		var show_r = (current_layer_index >= right_threshold_idx)
		
		if force_hide_left: show_l = false
		if force_hide_right: show_r = false
		
		if static_left:
			l_node.position = static_left.position + final_off_left
			l_node.visible = show_l
		if static_right:
			r_node.position = static_right.position + final_off_right
			r_node.visible = show_r
			
		current_layer_index += 1


## Helper wrapper for tweening the volume expansion factor.
func _tween_expansion_only(factor: float):
	_update_stack_direct(factor, _visual_spread_index)


## Updates the position of the volume root visually.
func _update_volume_visuals():
	if not _volume_root: return
	_volume_root.position = volume_stack_offset


## Calculates how many volume layers should be drawn for a specific spread.
func _get_layer_count_for_spread(spread_idx: float, total_layers: int) -> int:
	return int(round(_get_layer_count_for_spread_float(spread_idx, total_layers)))


## Applies the perspective material parameters to a node.
func _apply_perspective_to_node(node: Node2D, tl: Vector2, tr: Vector2, bl: Vector2, br: Vector2, bw: float, bh: float) -> void:
	if not node:
		return
		
	if node.material is ShaderMaterial:
		node.material.set_shader_parameter("top_left", tl)
		node.material.set_shader_parameter("top_right", tr)
		node.material.set_shader_parameter("bottom_left", bl)
		node.material.set_shader_parameter("bottom_right", br)
		node.material.set_shader_parameter("book_width", bw)
		node.material.set_shader_parameter("book_height", bh)
		node.material.set_shader_parameter("node_x_offset", node.position.x)
		node.material.set_shader_parameter("node_y_offset", node.position.y)
		node.material.set_shader_parameter("node_scale", node.scale)
		node.material.set_shader_parameter("dynamic_scale_corr", 1.0)


## Updates the perspective parameters based on the current expansion factor.
func _update_perspective(factor: float) -> void:
	var tl = open_top_left.lerp(closed_top_left, factor)
	var tr = open_top_right.lerp(closed_top_right, factor)
	var bl = open_bottom_left.lerp(closed_bottom_left, factor)
	var br = open_bottom_right.lerp(closed_bottom_right, factor)
	var bw = target_page_size.x * 2.0
	var bh = target_page_size.y

	_apply_perspective_to_node(static_left, tl, tr, bl, br, bw, bh)
	_apply_perspective_to_node(static_right, tl, tr, bl, br, bw, bh)
	_apply_perspective_to_node(dynamic_poly, tl, tr, bl, br, bw, bh)
	
	if _spine_poly:
		_apply_perspective_to_node(_spine_poly, tl, tr, bl, br, bw, bh)

	if _volume_root:
		var vol_spine = _volume_root.get_node_or_null("VolumeSpine")
		if vol_spine:
			_apply_perspective_to_node(vol_spine, tl, tr, bl, br, bw, bh)
			
		for i in range(_volume_root.get_child_count()):
			var layer = _volume_root.get_child(i)
			if layer.name.begins_with("Layer_") and layer.get_child_count() >= 2:
				var l_node = layer.get_child(0)
				var r_node = layer.get_child(1)
				_apply_perspective_to_node(l_node, tl, tr, bl, br, bw, bh)
				_apply_perspective_to_node(r_node, tl, tr, bl, br, bw, bh)


## Retrieves alignment offsets relative to the book structure parameters and center points.
func _get_compensation_offset(is_closed: bool, is_back: bool) -> Vector2:
	var target_local_x = 0.0
	if is_closed:
		if is_back: target_local_x = -page_width
		else: target_local_x = 0.0
	else: target_local_x = -page_width * 0.5
	var target_vec = Vector2(target_local_x, 0)
	var t_scale = closed_scale if is_closed else open_scale
	var t_rot = closed_rotation if is_closed else open_rotation
	if is_closed and is_back: t_rot *= -1.0
	target_vec *= t_scale
	target_vec = target_vec.rotated(deg_to_rad(t_rot))
	return -target_vec


## Manages container tween values natively supporting book orientations.
func _animate_container_transform(target_is_closed: bool, is_back: bool, duration: float):
	if not visuals_container: return
	var t_scale = closed_scale if target_is_closed else open_scale
	var t_skew = closed_skew if target_is_closed else open_skew
	var t_rot = closed_rotation if target_is_closed else open_rotation
	if target_is_closed and is_back: t_skew *= -1.0; t_rot *= -1.0
	if duration <= 0.0:
		visuals_container.scale = t_scale; visuals_container.skew = t_skew; visuals_container.rotation = deg_to_rad(t_rot)
	else:
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(visuals_container, "scale", t_scale, duration)
		tween.tween_property(visuals_container, "skew", t_skew, duration)
		tween.tween_property(visuals_container, "rotation", deg_to_rad(t_rot), duration)
#endregion


#region Input and Interaction Block
## Translates global inputs into localized inputs pushed directly to a specific viewport.
func _inject_event_to_viewport(viewport: SubViewport, polygon: Polygon2D, event: InputEvent) -> void:
	var mouse_pos = get_global_mouse_position()
	var new_mouse_pos = polygon.to_local(mouse_pos)
	new_mouse_pos.y += target_page_size.y / 2

	var ev = event.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	ev.position = new_mouse_pos
	ev.global_position = new_mouse_pos
	
	var node = viewport.gui_get_hovered_control()

	if not _active_viewports_state.get(viewport, false):
		viewport.notify_mouse_entered()
		_active_viewports_state[viewport] = true

	viewport.push_input(ev, true)

	if node is Control:
		var cursor_shape = node.get_default_cursor_shape()
		DisplayServer.cursor_set_shape.call_deferred(cursor_shape)
	else:
		DisplayServer.cursor_set_shape.call_deferred(DisplayServer.CursorShape.CURSOR_ARROW)


## Clears the viewport input state. Call this when interaction stops.
func _reset_viewport_input_state() -> void:
	for viewport in _active_viewports_state:
		if is_instance_valid(viewport):
			viewport.notify_mouse_exited()
	
	_active_viewports_state.clear()


## Handles standard inputs passed directly down the tree.
func _input(event):
	if disabled: return
	
	if not _active_interactive_is_left and not _active_interactive_is_right:
		if not _active_viewports_state.is_empty():
			_reset_viewport_input_state()
		return

	if event is InputEventMouse or event is InputEventMouseMotion:
		if _active_interactive_is_left:
			_slot_1.physics_object_picking = true
			_inject_event_to_viewport(_slot_1, static_left, event)
		elif _active_viewports_state.has(_slot_1):
			_slot_1.physics_object_picking = false
			_slot_1.notify_mouse_exited()
			_active_viewports_state.erase(_slot_1)
			
		if _active_interactive_is_right:
			_slot_2.physics_object_picking = true
			_inject_event_to_viewport(_slot_2, static_right, event)
		elif _active_viewports_state.has(_slot_2):
			_slot_2.physics_object_picking = false
			_slot_2.notify_mouse_exited()
			_active_viewports_state.erase(_slot_2)

	elif event is InputEventKey:
		if _active_interactive_is_left: _slot_1.push_input(event.duplicate(true))
		if _active_interactive_is_right: _slot_2.push_input(event.duplicate(true))


## Triggers unhandled inputs such as navigation keys.
func _unhandled_input(event):
	if Engine.is_editor_hint(): return
	if not visible or is_animating or disabled: return
	
	if event.is_action_pressed("ui_cancel") and close_condition == CloseCondition.ON_CANCEL_INPUT:
		_perform_close_action()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_right"): next_page(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"): prev_page(); get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = visuals_container.get_local_mouse_position()
		local_pos.y /= visuals_container.scale.y
		if local_pos.x > -page_width/2.0: next_page(); get_viewport().set_input_as_handled()
		else: prev_page(); get_viewport().set_input_as_handled()


## Manages transferring input controls from scenes to the book frame.
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


## Traverses active scenes dynamically mapped in viewports to restore behaviors.
func _check_scene_activation() -> void:
	var scene_found = false
	if _slot_1.get_child_count() > 0:
		var node = _slot_1.get_child(-1)
		if node.has_meta("_pageflip_node") and node.has_signal("manage_pageflip"):
			node.emit_signal("manage_pageflip", false)
			node.set_process_input(true); node.set_process_unhandled_input(true); scene_found = true
	if _slot_2.get_child_count() > 0:
		var node = _slot_2.get_child(-1)
		if node.has_meta("_pageflip_node") and node.has_signal("manage_pageflip"):
			node.emit_signal("manage_pageflip", false)
			node.set_process_input(true); node.set_process_unhandled_input(true); scene_found = true
	if not scene_found: _pageflip_set_input_enabled(true)
#endregion


#region Navigation and Animation Block
## Attempts to transition to the next page.
func next_page():
	if is_animating or current_spread >= total_spreads: return
	
	if limit_max_pages == -1 and current_spread >= total_spreads - 1:
		return
		
	var max_allowed_spread = total_spreads
	if limit_max_pages > 0:
		max_allowed_spread = (limit_max_pages - 1) / 2
		if max_allowed_spread > total_spreads:
			max_allowed_spread = total_spreads
			
	if limit_max_pages > 0 and current_spread >= max_allowed_spread: return
	
	if current_spread == -1 and front_cover_opens_to_page > 1:
		_try_emit_book_signals("right")
		var safe_page = front_cover_opens_to_page
		if limit_max_pages > 0 and safe_page > limit_max_pages:
			safe_page = limit_max_pages
		_auto_turn_target_spread = (safe_page - 1) / 2
		_auto_turn_target_spread = clampi(_auto_turn_target_spread, 0, total_spreads - 1)
		if anim_player: anim_player.speed_scale = 1.0
		_start_animation(true)
		return

	_try_emit_book_signals("right")
	_start_animation(true)


## Attempts to transition to the previous page.
func prev_page():
	if is_animating or current_spread <= -1: return
	
	var target_open_spread = (front_cover_opens_to_page - 1) / 2
	if front_cover_opens_to_page > 1 and current_spread == target_open_spread:
		_try_emit_book_signals("left")
		_auto_turn_target_spread = -1
		if current_spread == 0:
			if anim_player: anim_player.speed_scale = 1.0
		else:
			if anim_player: anim_player.speed_scale = 3.0
		_start_animation(false)
		return
		
	_try_emit_book_signals("left")
	_start_animation(false)


## Emits events for specific structural transitions.
func _try_emit_book_signals(_direction: String) -> void:
	if _direction == "right" and current_spread == -1:
		book_opened.emit()
	elif _direction == "left" and current_spread == total_spreads:
		book_opened.emit()
	elif _direction == "left" and current_spread == 0:
		book_closed.emit()
	elif _direction == "right" and current_spread == total_spreads - 1:
		book_closed.emit()


## Internal function that handles the actual jump logic using specific spread indices.
func _go_to_page(target_spread_idx: int, total_time: float = 0.5) -> void:
	if is_animating: return
	
	if target_spread_idx == current_spread:
		return
		
	var spreads_to_cross = abs(current_spread - target_spread_idx)
	var anim_length = 0.7
	
	if anim_player and anim_player.has_animation("turn_flexible_page"):
		anim_length = anim_player.get_animation("turn_flexible_page").length
		
	var calculated_speed = (spreads_to_cross * anim_length) / total_time
	_dynamic_auto_speed = clampf(calculated_speed, 1.0, 15.0)
	
	_pageflip_set_input_enabled(true)
	_auto_turn_target_spread = target_spread_idx
	
	if anim_player: anim_player.speed_scale = _dynamic_auto_speed
	
	var forward = target_spread_idx > current_spread
	_start_animation(forward)


## API to jump to a specific page or cover.
func go_to_page(page_num: int = 1, target: JumpTarget = JumpTarget.CONTENT_PAGE, total_time: float = 0.5) -> void:
	if is_animating: return
	
	var target_spread_idx: int = 0
	
	match target:
		JumpTarget.FRONT_COVER:
			target_spread_idx = -1
		JumpTarget.BACK_COVER:
			if limit_max_pages == -1:
				target_spread_idx = total_spreads - 1
			else:
				target_spread_idx = total_spreads
		JumpTarget.CONTENT_PAGE:
			var safe_page = page_num
			if safe_page < 1: safe_page = 1
			if limit_max_pages > 0 and safe_page > limit_max_pages:
				safe_page = limit_max_pages
			target_spread_idx = (safe_page - 1) / 2
			if target_spread_idx < 0: target_spread_idx = 0
			if target_spread_idx > total_spreads - 1: target_spread_idx = total_spreads - 1
	
	print(total_time)
	_go_to_page(target_spread_idx, total_time)


## start from the current visual state and end at the cover.
func force_close_book(to_front_cover: bool):
	if is_animating: return
	_pageflip_set_input_enabled(true)
	
	_is_force_closing = true
	_auto_turn_target_spread = -999
	if anim_player: anim_player.speed_scale = 1.0
	
	if to_front_cover:
		_start_animation(false)
	else:
		_start_animation(true)


## Toggles rendering bounds manually depending on the flipping status.
func _set_flying_slots_active(is_active: bool) -> void:
	var mode = SubViewport.UPDATE_ALWAYS if is_active else SubViewport.UPDATE_DISABLED
	
	if _slot_3: _slot_3.render_target_update_mode = mode
	if _slot_4: _slot_4.render_target_update_mode = mode


## Connects variables with the animation timeline elements depending on rigid physics setups.
func _start_animation(forward: bool) -> void:
	started_page_flip_animation.emit()
	is_animating = true
	going_forward = forward
		
	_set_flying_slots_active(true)

	var is_rigid_motion = false
	var use_tween = false
	var closing_to_back = false
	var closing_to_front = false
	var target_is_closed = false

	var target_spread_idx = 0

	if _is_force_closing:
		if forward: 
			target_spread_idx = total_spreads
			is_rigid_motion = covers_are_rigid
			use_tween = true
			is_book_open = false
			closing_to_back = true
			target_is_closed = true
		else: 
			target_spread_idx = -1
			is_rigid_motion = covers_are_rigid
			use_tween = true
			is_book_open = false
			closing_to_front = true
			target_is_closed = true
	elif _is_jumping:
		target_spread_idx = _jump_target_spread
		if target_spread_idx == -1:
			is_rigid_motion = covers_are_rigid
			use_tween = true
			is_book_open = false
			closing_to_front = true
			target_is_closed = true
		elif target_spread_idx == total_spreads:
			is_rigid_motion = covers_are_rigid
			use_tween = true
			is_book_open = false
			closing_to_back = true
			target_is_closed = true
		else:
			if current_spread == -1 or current_spread == total_spreads:
				is_rigid_motion = covers_are_rigid
				use_tween = true
			else:
				is_rigid_motion = false
				use_tween = false
			is_book_open = true
			target_is_closed = false
	else:
		target_spread_idx = current_spread + 1 if forward else current_spread - 1

		if forward:
			if current_spread == -1:
				is_rigid_motion = covers_are_rigid
				use_tween = true
				is_book_open = true
				target_is_closed = false
			elif current_spread == total_spreads - 1:
				is_rigid_motion = covers_are_rigid
				use_tween = true
				is_book_open = false
				closing_to_back = true
				target_is_closed = true
		else:
			if current_spread == total_spreads:
				is_rigid_motion = covers_are_rigid
				use_tween = true
				is_book_open = true
				target_is_closed = false
			elif current_spread == 0:
				is_rigid_motion = covers_are_rigid
				use_tween = true
				is_book_open = false
				closing_to_front = true
				target_is_closed = true

	_pending_target_spread_idx = target_spread_idx

	_force_hide_vol_left = false
	_force_hide_vol_right = false
	if target_is_closed and is_rigid_motion:
		if forward:
			_force_hide_vol_right = true
		else:
			_force_hide_vol_left = true

	_is_page_flying = true
	_flying_from_right = forward
	_visual_spread_index = float(current_spread)

	var idx_static_left = -999
	var idx_static_right = -999
	var idx_anim_a = -999
	var idx_anim_b = -999

	if _is_force_closing:
		if forward:
			idx_static_left = _get_page_index_for_spread(current_spread, true)
			idx_static_right = -999
			idx_anim_a = _get_page_index_for_spread(current_spread, false)
			idx_anim_b = -103
		else:
			idx_static_right = _get_page_index_for_spread(current_spread, false)
			idx_static_left = -999
			idx_anim_a = _get_page_index_for_spread(current_spread, true)
			idx_anim_b = -100
	elif _is_jumping:
		if forward:
			idx_static_left = _get_page_index_for_spread(current_spread, true)
			idx_static_right = _get_page_index_for_spread(target_spread_idx, false)
			idx_anim_a = _get_page_index_for_spread(current_spread, false)
			idx_anim_b = _get_page_index_for_spread(target_spread_idx, true)
		else:
			idx_static_left = _get_page_index_for_spread(target_spread_idx, true)
			idx_static_right = _get_page_index_for_spread(current_spread, false)
			idx_anim_a = _get_page_index_for_spread(current_spread, true)
			idx_anim_b = _get_page_index_for_spread(target_spread_idx, false)
	else:
		if forward:
			idx_static_left = _get_page_index_for_spread(current_spread, true)
			idx_static_right = _get_page_index_for_spread(target_spread_idx, false)
			idx_anim_a = _get_page_index_for_spread(current_spread, false)
			idx_anim_b = _get_page_index_for_spread(target_spread_idx, true)
		else:
			idx_static_left = _get_page_index_for_spread(target_spread_idx, true)
			idx_static_right = _get_page_index_for_spread(current_spread, false)
			idx_anim_a = _get_page_index_for_spread(current_spread, true)
			idx_anim_b = _get_page_index_for_spread(target_spread_idx, false)

	_update_slot_content(_slot_1, idx_static_left, true)
	_update_slot_content(_slot_2, idx_static_right, false)
	_update_slot_content(_slot_3, idx_anim_a, not forward)
	_update_slot_content(_slot_4, idx_anim_b, forward)

	static_left.texture = _slot_1.get_texture()
	static_right.texture = _slot_2.get_texture()

	var tex_front = _slot_3.get_texture()
	var tex_back = _slot_4.get_texture()

	dynamic_poly.texture = tex_back

	if dynamic_poly.material is ShaderMaterial:
		dynamic_poly.material.set_shader_parameter("shadow_intensity", 0.0)
		dynamic_poly.material.set_shader_parameter("max_shadow_spread", 0.0)

		var shadow_tex = dynamic_poly.get("shadow_gradient")
		if shadow_tex:
			dynamic_poly.material.set_shader_parameter("spine_shadow_gradient", shadow_tex)

		if forward:
			dynamic_poly.material.set_shader_parameter("front_texture", tex_front)
			dynamic_poly.material.set_shader_parameter("back_texture", tex_back)
		else:
			dynamic_poly.material.set_shader_parameter("front_texture", tex_back)
			dynamic_poly.material.set_shader_parameter("back_texture", tex_front)

	if closing_to_back:
		_set_page_visible.call_deferred(static_right, false)
	elif closing_to_front:
		_set_page_visible.call_deferred(static_left, false)

	var base_anim_name = "turn_rigid_page" if is_rigid_motion else "turn_flexible_page"
	var final_anim_name = base_anim_name if forward else base_anim_name + "_mirror"

	var anim_len = 1.0
	if anim_player.has_animation(final_anim_name):
		anim_len = anim_player.get_animation(final_anim_name).length
		anim_player.current_animation = final_anim_name
		anim_player.seek(0.0, true)

	_set_page_visible.call_deferred(dynamic_poly, true)
	dynamic_poly.z_index = 10
	_update_stack_direct(_current_expansion_factor, float(current_spread))

	await RenderingServer.frame_post_draw
	
	var is_jumping_start = (current_spread == -1 and front_cover_opens_to_page > 1 and _auto_turn_target_spread != -999)
	
	if is_jumping_start:
		anim_player.speed_scale = cover_anim_speed
	elif _auto_turn_target_spread != -999:
		anim_player.speed_scale = pages_anim_speed

	var motion_duration = anim_len / (anim_player.speed_scale if anim_player.speed_scale > 0 else 1.0)
	var land_time = max(0.0, motion_duration - landing_overlap)
	get_tree().create_timer(land_time).timeout.connect(_on_page_landed_early)

	var start_exp = float(_current_expansion_factor)
	var end_exp = 1.0 if target_is_closed else 0.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	var half_duration = motion_duration * 0.5

	var overlap_factor = 0.8
	var delay_time = half_duration * overlap_factor
	var entry_duration = motion_duration - delay_time

	if dynamic_poly.material is ShaderMaterial and not is_rigid_motion:
		var target_spread = dynamic_poly.get("face_shadow_spread")
		if target_spread == null: target_spread = 0.5

		var shadow_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		shadow_tween.tween_property(dynamic_poly.material, "shader_parameter/shadow_intensity", 0.65, half_duration)
		shadow_tween.parallel().tween_property(dynamic_poly.material, "shader_parameter/max_shadow_spread", target_spread, half_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		var d = half_duration * 0.8
		shadow_tween.set_ease(Tween.EASE_IN)
		shadow_tween.tween_property(dynamic_poly.material, "shader_parameter/shadow_intensity", 0.0, d)
		shadow_tween.parallel().tween_property(dynamic_poly.material, "shader_parameter/max_shadow_spread", 0.0, d).set_trans(Tween.TRANS_SINE)

	var start_thin_L = (current_spread <= 1)
	var end_thin_L = (target_spread_idx <= 1)

	if start_thin_L and not end_thin_L:
		_stack_scale_left = 0.0
		tween.tween_property(self, "_stack_scale_left", 1.0, entry_duration).set_delay(delay_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif not start_thin_L and end_thin_L:
		_stack_scale_left = 1.0
		tween.tween_property(self, "_stack_scale_left", 0.0, half_duration * 0.8)
	elif start_thin_L and end_thin_L:
		_stack_scale_left = 0.0
	else:
		_stack_scale_left = 1.0

	var start_thin_R = (current_spread >= total_spreads - 1)
	var end_thin_R = (target_spread_idx >= total_spreads - 1)

	if start_thin_R and not end_thin_R:
		_stack_scale_right = 0.0
		tween.tween_property(self, "_stack_scale_right", 1.0, entry_duration).set_delay(delay_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif not start_thin_R and end_thin_R:
		_stack_scale_right = 1.0
		tween.tween_property(self, "_stack_scale_right", 0.0, half_duration * 0.8)
	elif start_thin_R and end_thin_R:
		_stack_scale_right = 0.0
	else:
		_stack_scale_right = 1.0

	if use_tween:
		var compensation_offset = _get_compensation_offset(target_is_closed, closing_to_back)
		var screen_center = get_viewport().get_camera_2d().get_screen_center_position()
		var extra_offset = closed_offset if target_is_closed else open_offset
		var final_pos = screen_center + compensation_offset - Vector2(target_page_size.x / 2, 0.0) + extra_offset
		
		var start_pos = visuals_container.global_position
		var start_scale = visuals_container.scale
		var start_skew = visuals_container.skew
		var start_rot = visuals_container.rotation
		
		var target_scale = closed_scale if target_is_closed else open_scale
		var target_skew = closed_skew if target_is_closed else open_skew
		var target_rot = closed_rotation if target_is_closed else open_rotation
		
		if target_is_closed and closing_to_back:
			target_skew *= -1.0
			target_rot *= -1.0
			
		tween.tween_method(
			func(t: float):
				var arc = 4.0 * t * (1.0 - t)
				
				var current_pos = start_pos.lerp(final_pos, t)
				current_pos.y -= flight_lift_height * arc
				visuals_container.global_position = current_pos
				
				var base_scale = start_scale.lerp(target_scale, t)
				visuals_container.scale = base_scale * (1.0 + ((flight_zoom_factor - 1.0) * arc))
				
				visuals_container.skew = lerp(start_skew, target_skew, t)
				visuals_container.rotation = lerp_angle(start_rot, deg_to_rad(target_rot), t)
		,
			0.0, 1.0, float(motion_duration)
		)

	tween.tween_method(Callable(self, "_tween_expansion_only"), float(start_exp), float(end_exp), float(motion_duration))
	tween.tween_property(self, "_visual_spread_index", float(target_spread_idx), float(motion_duration))

	anim_player.play(final_anim_name)

	if is_rigid_motion:
		var trigger_time = max(0.0, motion_duration - impact_sync_offset)
		get_tree().create_timer(trigger_time).timeout.connect(
			func():
				if current_spread == 0 or current_spread == total_spreads - 1:
					_play_sound(sfx_book_impact)
				else:
					_play_sound(sfx_book_opened)
		)
	else:
		_play_sound(sfx_page_flip)


## Marks the landing state explicitly before the actual animation wraps.
func _on_page_landed_early():
	_is_page_flying = false
	_visual_spread_index = float(_pending_target_spread_idx)
	_update_stack_direct(_current_expansion_factor, _visual_spread_index)


## Processes the timeline and visual alignment updates during an active animation.
func _process(_delta):
	if visuals_container and is_animating:
		_update_stack_direct(_current_expansion_factor, _visual_spread_index)
		_update_volume_visuals()


## Handles midpoint signal.
func _on_midpoint_signal():
	pass


## Executed naturally when an animation completely terminates.
func _on_animation_finished(_anim_name: String):
	_set_page_visible(dynamic_poly, false)
	_set_flying_slots_active(false)
	dynamic_poly.z_index = 10
	
	_force_hide_vol_left = false
	_force_hide_vol_right = false
	_is_page_flying = false
	
	if _is_force_closing:
		_is_force_closing = false
		if going_forward: current_spread = total_spreads
		else: current_spread = -1
	elif _is_jumping:
		_is_jumping = false
		current_spread = _jump_target_spread
	else:
		if going_forward and current_spread == -1: current_spread = 0
		elif going_forward and current_spread == total_spreads - 1: current_spread = total_spreads
		elif !going_forward and current_spread == total_spreads: current_spread = total_spreads - 1
		elif !going_forward and current_spread == 0: current_spread = -1
		else:
			if going_forward: current_spread += 1
			else: current_spread -= 1
	
	_update_static_visuals_immediate()
	is_animating = false
	_visual_spread_index = float(current_spread)
	_update_stack_direct(_current_expansion_factor, _visual_spread_index)
	_update_volume_visuals()
	
	var is_closed_now = (current_spread == -1 or current_spread == total_spreads)
	var is_back_now = (current_spread == total_spreads)
	
	var compensation_offset = _get_compensation_offset(is_closed_now, is_back_now)
	var screen_center = get_viewport().get_camera_2d().get_screen_center_position()
	var extra_offset = closed_offset if is_closed_now else open_offset
	visuals_container.global_position = screen_center + compensation_offset - Vector2(target_page_size.x / 2, 0.0) + extra_offset
	
	_animate_container_transform(is_closed_now, is_back_now, 0.0)
	
	if _auto_turn_target_spread != -999:
		if current_spread < _auto_turn_target_spread:
			if anim_player: anim_player.speed_scale = pages_anim_speed
			_start_animation(true)
			return
		elif current_spread > _auto_turn_target_spread:
			if current_spread == 0 and _auto_turn_target_spread == -1:
				if anim_player: anim_player.speed_scale = cover_anim_speed
			else:
				if anim_player: anim_player.speed_scale = pages_anim_speed
			_start_animation(false)
			return
		else:
			_auto_turn_target_spread = -999
			if anim_player: anim_player.speed_scale = 1.0
			
	if current_spread == total_spreads:
		if close_condition == CloseCondition.CLOSE_FROM_BACK or close_condition == CloseCondition.ANY_CLOSE:
			_perform_close_action()
			return
	if current_spread == -1:
		if close_condition == CloseCondition.CLOSE_FROM_FRONT or close_condition == CloseCondition.ANY_CLOSE:
			_perform_close_action()
			return
	_check_scene_activation.call_deferred()
	ended_page_flip_animation.emit()


## Carries out the close directives set natively inside inspector variables.
func _perform_close_action():
	if close_behavior == CloseBehavior.DESTROY_BOOK: queue_free()
	elif close_behavior == CloseBehavior.CHANGE_SCENE:
		if target_scene_on_close != "": get_tree().change_scene_to_file(target_scene_on_close)
#endregion


#region Content Rendering Block
## Calculates page index mathematically directly associated to a spread orientation.
func _get_page_index_for_spread(spread_idx: int, is_left: bool) -> int:
	if spread_idx == -1: return -999 if is_left else -100
	if spread_idx == total_spreads: return -103 if is_left else -999
	if spread_idx == 0:
		if is_left: return -101
		if _runtime_pages.size() == 0: return -102
		return 0
	if is_left: return (spread_idx * 2) - 1
	else:
		var content_idx = spread_idx * 2
		if content_idx >= _runtime_pages.size(): return -102
		return content_idx


## Fills a viewport dynamically rendering content required right in the current spread.
func _update_slot_content(slot: SubViewport, content_index: int, is_left: bool) -> void:
	if not slot: return
	for child in slot.get_children():
		if child is TextureRect: child.queue_free()
		else: slot.remove_child(child)
	var resource_path = ""
	var cover_tex: Texture2D = null
	if content_index == -100: cover_tex = tex_cover_front_out
	elif content_index == -101: cover_tex = tex_cover_front_in
	elif content_index == -102: cover_tex = tex_cover_back_in
	elif content_index == -103: cover_tex = tex_cover_back_out
	elif content_index >= 0 and content_index < _runtime_pages.size(): resource_path = _runtime_pages[content_index]
	
	var default_blank = left_blank_page_texture if is_left else right_blank_page_texture

	if cover_tex:
		if cover_tex != default_blank: _setup_texture_in_slot(slot, cover_tex, is_left)
		else: _setup_texture_in_slot(slot, default_blank, is_left)
	elif resource_path != "":
		if resource_path == "internal://blank_page": _setup_texture_in_slot(slot, default_blank, is_left)
		elif ResourceLoader.exists(resource_path):
			var res = load(resource_path)
			if res is PackedScene: _setup_scene_in_slot(slot, res, content_index, is_left)
			elif res is Texture2D:
				if res != default_blank: _setup_texture_in_slot(slot, res, is_left)
				else: _setup_texture_in_slot(slot, default_blank, is_left)
			else: _setup_texture_in_slot(slot, default_blank, is_left)
	else: _setup_texture_in_slot(slot, default_blank, is_left)


## Sets textures up inside an isolated slot structure securely.
func _setup_texture_in_slot(slot: SubViewport, tex: Texture2D, is_left_page: bool):
	if enable_composite_pages: _add_composite_blank_bg(slot, is_left_page)
	if not tex:
		tex = left_blank_page_texture if is_left_page else right_blank_page_texture
		if not tex: return
	
	var expected_bg = left_blank_page_texture if is_left_page else right_blank_page_texture
	if enable_composite_pages and tex == expected_bg:
		return
		
	var rect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = page_stretch_mode as TextureRect.StretchMode
	rect.size = slot.size
	rect.position = Vector2.ZERO

	slot.add_child(rect)


## Instantiates packed scenes inside subviewports.
func _setup_scene_in_slot(slot: SubViewport, scene_pkg: PackedScene, texture_index: int, is_left_page: bool):
	if enable_composite_pages: _add_composite_blank_bg(slot, is_left_page)
	var cache_key = scene_pkg.get_path() + "#" + str(texture_index)
	var instance
	if not cache_key in _scene_cache:
		instance = scene_pkg.instantiate()
		instance.set_meta("_pageflip_node", self)
		instance.position = Vector2.ZERO
		if instance.has_signal("manage_pageflip"): instance.connect("manage_pageflip", _pageflip_set_input_enabled)
		slot.add_child(instance)
		_scene_cache[cache_key] = instance
	else:
		instance = _scene_cache[cache_key]
		if instance.is_inside_tree(): instance.reparent(slot)
		else: slot.add_child(instance)
	instance.set_process_input(false); instance.set_process_unhandled_input(false)


## Embeds the configured base empty texture under transparent instances safely.
func _add_composite_blank_bg(slot: SubViewport, is_left_page: bool):
	var tex = left_blank_page_texture if is_left_page else right_blank_page_texture
	if not tex: return
	var bg = TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = page_stretch_mode as TextureRect.StretchMode
	bg.size = slot.size
	bg.position = Vector2.ZERO
	slot.add_child(bg)
#endregion


#region Audio Management Block
## Generates simple audio emissions when needed.
func play_sound(stream: AudioStream) -> void:
	_play_sound(stream)


## Internal function to play sound with pitch variance.
func _play_sound(stream: AudioStream):
	if not audio_player or not stream: return
	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(
		min_fpage_flip_fx_pitch,
		max_fpage_flip_fx_pitch)
	audio_player.play()
#endregion
