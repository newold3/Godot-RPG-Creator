@tool
extends Control

const EMPTY_RECT := Rect2i(0,0,0,0)
const FRAME_0 := 0

const BACK_PANEL_MARGIN := 12

const DEFAULT_TERRAIN_OPACITY := 0.75

const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")


var tbt : TBTPlugin

var preview_bit_data : TBTPlugin.EditorBitData

var tile_rects : Dictionary

var base_image : Image

var image_crop_rect : Rect2i

var initial_height : float

var expanded := true


@onready var back_panel: Panel = %BackPanel
@onready var v_split_container: VSplitContainer = %VSplitContainer
@onready var front_container: Container = %FrontContainer


@onready var collapsed_controls: Control = %CollapsedControls
@onready var expanded_controls: Control = %ExpandedControls


@onready var preview_container: Container = %PreviewContainer

@onready var current_tiles_view: Container = %CurrentTilesView
@onready var preview_tiles_view: Container = %PreviewTilesView
@onready var terrain_opacity_slider: HSlider = %TerrainOpacitySlider

@onready var placeholder_label: RichTextLabel = %PlaceholderLabel

@onready var reset_button: Button = %ResetButton
@onready var apply_button: Button = %ApplyButton

var ready_complete := false



func _ready() -> void:
	ready_complete = true
	var _err := front_container.resized.connect(_on_front_container_resized)
	_connect_opacity_slider()
	_toggle_expanded_state(true)


func _tbt_ready() -> void:
	var _err := tbt.tiles_inspector_added.connect(_on_tiles_inspector_added)
	_err = tbt.tiles_inspector_removed.connect(_on_tiles_inspector_removed)
	_err = tbt.preview_updated.connect(_on_preview_updated)
	_err = tbt.tiles_preview_expand_requested.connect(_on_tiles_preview_expand_requested)
	_err = tbt.tiles_preview_collapse_requested.connect(_on_tiles_preview_collapse_requested)



# returns control to determine if mouse click is
# in panel
func get_mouse_input_rect() -> Rect2:
	var rect := back_panel.get_global_rect()
	rect.position = rect.position - Vector2(0, 6)
	rect.size = rect.size + Vector2(0, 6)
	return rect


func _setup_textures() -> void:
	_update_base_texture()
	_update_current_terrain()
	_update_preview_terrain()


func _clear_data() -> void:
	base_image = null
	preview_bit_data = null
	tile_rects.clear()
	image_crop_rect = EMPTY_RECT
	_update_preview_terrain()


func _update_base_texture() -> void:
	_update_image_crop_rect()
	_create_base_image()
	var texture := ImageTexture.create_from_image(base_image)
	current_tiles_view.setup_base_tiles(texture, image_crop_rect.size)
	preview_tiles_view.setup_base_tiles(texture, image_crop_rect.size)


func _connect_opacity_slider() -> void:
	var _err := terrain_opacity_slider.value_changed.connect(current_tiles_view.set_terrain_overlay_opacity)
	_err = terrain_opacity_slider.value_changed.connect(preview_tiles_view.set_terrain_overlay_opacity)
	terrain_opacity_slider.value = DEFAULT_TERRAIN_OPACITY
	terrain_opacity_slider.value_changed.emit(DEFAULT_TERRAIN_OPACITY)


func _update_current_terrain() -> void:
	current_tiles_view.set_bit_data(tbt.context.bit_data)



func _update_preview_terrain() -> void:
	if preview_bit_data:
		placeholder_label.hide()
		reset_button.show()
		preview_tiles_view.show()
		preview_tiles_view.set_bit_data(preview_bit_data)
		reset_button.disabled = false
		apply_button.disabled = false

	else:
		placeholder_label.show()
		reset_button.hide()
		preview_tiles_view.hide()
		preview_tiles_view.set_bit_data(null)
		reset_button.disabled = true
		apply_button.disabled = true




func _create_base_image() -> void:
	var texture := tbt.context.source.texture
	base_image = texture.get_image().get_region(image_crop_rect)


func _update_image_crop_rect() -> void:
	image_crop_rect = EMPTY_RECT

	for coords in tbt.context.tiles.keys():
		var rect := tbt.context.source.get_tile_texture_region(coords, FRAME_0)
		if image_crop_rect == EMPTY_RECT:
			image_crop_rect = rect
		else:
			image_crop_rect = image_crop_rect.merge(rect)


func _on_preview_updated(bit_data : TBTPlugin.EditorBitData) -> void:
	preview_bit_data = bit_data
	_update_preview_terrain()


func _on_front_container_resized() -> void:
	var front_height := front_container.size.y
	back_panel.custom_minimum_size.y = front_height + BACK_PANEL_MARGIN


func _toggle_expanded_state(p_expanded : bool) -> void:
	if expanded == p_expanded:
		return
	expanded = p_expanded
	expanded_controls.visible = expanded
	collapsed_controls.visible = !expanded


func _on_reset_button_pressed() -> void:
	tbt.reset_requested.emit()


func _on_apply_button_pressed() -> void:
	tbt.apply_changes_requested.emit()


func _on_expand_button_pressed() -> void:
	_toggle_expanded_state(true)


func _on_collapse_button_pressed() -> void:
	_toggle_expanded_state(false)


func _on_tiles_inspector_added() -> void:
	show()
	_setup_textures()


func _on_tiles_inspector_removed() -> void:
	hide()
	_clear_data()


func _on_tiles_preview_expand_requested() -> void:
	_toggle_expanded_state(true)


func _on_tiles_preview_collapse_requested() -> void:
	_toggle_expanded_state(false)


func _on_front_panel_collapsed_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or !event.is_pressed():
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	_toggle_expanded_state(true)

