@tool
extends Node


signal tiles_inspector_added
signal tiles_inspector_removed

signal templates_updated
signal templates_update_requested

signal save_template_requested
signal edit_template_requested(template_bit_data)
signal message_box_requested(msg)

signal preview_updated(preview_bit_data)
signal reset_requested
signal apply_changes_requested

signal tiles_preview_collapse_requested
signal tiles_preview_expand_requested

signal theme_update_requested(node)

const TBT_PROPERTY_NAME := "tbt"
const TBT_READY_METHOD := "_tbt_ready"
const TILES_INSPECTOR_ADDED_METHOD := "_tiles_inspector_added"
const TILES_INSPECTOR_REMOVED_METHOD := "_tiles_inspector_removed"

const G := preload("res://addons/tile_bit_tools/core/globals.gd")
const Texts := preload("res://addons/tile_bit_tools/core/texts.gd")
const Icons := preload("res://addons/tile_bit_tools/core/icons.gd")
const Output := preload("res://addons/tile_bit_tools/core/output.gd")

const BitData := preload("res://addons/tile_bit_tools/core/bit_data.gd")
const EditorBitData := preload("res://addons/tile_bit_tools/core/editor_bit_data.gd")
const TemplateBitData := preload("res://addons/tile_bit_tools/core/template_bit_data.gd")

const TemplateManager := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/template_manager.gd")
const TilesManager := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tiles_manager.gd")
const ThemeUpdater := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/theme_updater.gd")
const Context := preload("res://addons/tile_bit_tools/core/context.gd")

var output : Output = Output.new()
var texts : Texts = Texts.new()
var icons : Icons

var interface : EditorInterface
var atlas_source_editor : Node
var base_control : Control

var template_manager : TemplateManager
var tiles_manager : TilesManager
var theme_updater : ThemeUpdater
var dialog_windows := []

var context : Context :
	get:
		if !_is_reference_valid(context):
			return null
		return context


var tiles_inspector : Control :
	get:
		if !_is_reference_valid(tiles_inspector):
			return null
		return tiles_inspector


var tiles_preview : Control :
	get:
		if !_is_reference_valid(tiles_preview):
			return null
		return tiles_preview


func _ready() -> void:
	set_process_input(false)
	var _err := child_entered_tree.connect(_assign_child_by_class)
	_setup_debug_signals()
	_setup_children()


func setup(p_interface : EditorInterface, p_atlas_source_editor : Node, p_tiles_preview : Control) -> void:
	interface = p_interface
	base_control = interface.get_base_control()
	atlas_source_editor = p_atlas_source_editor

	icons = Icons.new(base_control)

	# here instead of _ready() so base_control is not null
	_inject_tbt_reference(self)

	tiles_preview = p_tiles_preview
	_inject_tbt_reference(tiles_preview, true)


func notify_tiles_inspector_added(p_tiles_inspector : Control) -> void:
	tiles_inspector = p_tiles_inspector
	_inject_tbt_reference(tiles_inspector, true)
	_call_subtree(self, TILES_INSPECTOR_ADDED_METHOD)
	tiles_inspector_added.emit()
	var _err := tiles_inspector.visibility_changed.connect(_on_tiles_inspector_visibility_changed)
	_setup_dynamic_containers()
	set_process_input(true)
	tiles_preview_expand_requested.emit()


func notify_tiles_inspector_removed() -> void:
	set_process_input(false)
	_call_subtree(self, TILES_INSPECTOR_REMOVED_METHOD)
	tiles_inspector_removed.emit()

func is_dialog_popped_up() -> bool:
	for dialog in dialog_windows:
		if dialog.visible:
			return true
	return false


func _setup_dynamic_containers() -> void:
	for node in get_tree().get_nodes_in_group(G.GROUP_DYNAMIC_CONTAINER):
		if !node.child_entered_tree.is_connected(_on_dynamic_container_child_added):
			var _err := node.child_entered_tree.connect(_on_dynamic_container_child_added)


func _on_dynamic_container_child_added(node : Node) -> void:
	_inject_tbt_reference(node, true)
	theme_update_requested.emit(node)


func _on_tiles_inspector_visibility_changed() -> void:
	if !is_instance_valid(tiles_inspector) or !tiles_inspector.is_visible_in_tree():
		tiles_preview.hide()
		set_process_input(false)
	else:
		tiles_preview.show()
		set_process_input(true)


# while tiles inspector is visible, watch for mouse clicks and
# collapse preview panel for clicks outside of this plugin
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		return

	if is_dialog_popped_up():
		return

	var mouse_position = base_control.get_global_mouse_position()

	if tiles_inspector.get_parent_control().get_global_rect().has_point(mouse_position):
		if tiles_inspector.get_global_rect().has_point(mouse_position):
			if !tiles_preview.expanded:
				tiles_preview_expand_requested.emit()
		else:
			tiles_preview_collapse_requested.emit()
		return

	if !tiles_preview.expanded:
		return

	if tiles_preview.get_parent_control().get_global_rect().has_point(mouse_position):
		if !tiles_preview.get_mouse_input_rect().has_point(mouse_position):
			tiles_preview_collapse_requested.emit()


func _setup_children() -> void:
	for child in _get_children_recursive(self):
		_assign_child_by_class(child)


func _assign_child_by_class(child : Node) -> void:
	match child.get_script():
		TemplateManager:
			template_manager = child
		TilesManager:
			tiles_manager = child
		ThemeUpdater:
			theme_updater = child
		Context:
			context = child
		_:
			if child is Window:
				dialog_windows.append(child)



func _inject_tbt_reference(node : Node, include_parent := false) -> void:
	_set_subtree(node, TBT_PROPERTY_NAME, self, include_parent)
	_call_subtree(node, TBT_READY_METHOD, include_parent)


func _set_subtree(parent : Node, property_name : String, value : Variant, include_parent := false) -> void:
	var nodes_to_set := _get_children_recursive(parent)
	if include_parent:
		nodes_to_set.append(parent)

	for node in nodes_to_set:
		node.set(property_name, value)


func _call_subtree(parent : Node, method_name : String, include_parent := false) -> void:
	var nodes_to_call := _get_children_recursive(parent)
	if include_parent:
		nodes_to_call.append(parent)

	for node in nodes_to_call:
		if node.has_method(method_name):
			node.call(method_name)


func _get_children_recursive(node : Node) -> Array:
	return node.find_children("*", "", true, false)


func _is_reference_valid(node) -> bool:
	if !is_instance_valid(node):
		return false
	if !node.is_inside_tree():
		output.warning("%s is not inside tree" % node)
		return false
	if node.is_queued_for_deletion():
		output.warning("%s is queued for deletion" % node)
		return false
	return true
#	return is_instance_valid(node) && node.is_inside_tree() && !node.is_queued_for_deletion()


func _setup_debug_signals() -> void:
	for signal_data in get_signal_list():
		if signal_data.args.size() == 0:
			var _err := connect(signal_data.name, _on_signal_emitted.bind(signal_data.name))
		else:
			var _err := connect(signal_data.name, _on_signal_emitted_with_arg.bind(signal_data.name))


func _on_signal_emitted(signal_name := "") -> void:
	output.debug("[TBTPlugin] Signal emitted: %s" % signal_name)


func _on_signal_emitted_with_arg(arg = null, signal_name := "") -> void:
	output.debug("[TBTPlugin] Signal emitted: %s (%s)" % [signal_name, arg])
