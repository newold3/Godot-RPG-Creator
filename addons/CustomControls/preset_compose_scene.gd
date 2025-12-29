@tool
class_name PresetCompose
extends HBoxContainer

## Custom UI component for managing configuration presets. It allows users to save, load, and delete presets stored in [member FileCache.options].

@onready var presets_node: OptionButton = %Presets
@onready var apply_preset: TextureButton = %ApplyPreset
@onready var save_preset: TextureButton = %SavePreset
@onready var remove_preset: TextureButton = %RemovePreset

## Key used in the [member FileCache.options] dictionary to store the presets for this category.
@export var presets_key: String
## Cache key used in the [member FileCache.options] dictionary for the preset selected in this category.
@export var selected_key_preset: String

## Emitted when attempting to save a preset. The method sends the correct options key, which is a dictionary, and the name of the preset, so the user can cache whatever they want.
signal save_preset_requested(options: Dictionary, target_key: String)
## Emitted when a preset load is requested. Sends the preset data as a Variant so the user can apply the settings as needed.
signal load_preset_requested(data: Variant)


func _ready() -> void:
	var selected_index = FileCache.options.get(selected_key_preset, 0)
	_update_presets(selected_index)


func _update_presets(selected_index: int = 0) -> void:
	var presets_count = presets_node.get_item_count()
	for i in range(2, presets_count, 1):
		presets_node.remove_item(2)
	
	var presets = FileCache.options.get(presets_key, {})

	for preset: String in presets:
		presets_node.add_item(preset.capitalize())
	
	presets_count = presets_node.get_item_count()
	
	if selected_index > 1 and selected_index < presets_count:
		presets_node.select(selected_index)
	elif presets_count > 2:
		presets_node.select(2)
	else:
		presets_node.select(0)
	
	selected_index = presets_node.get_selected_id()
	FileCache.options[selected_key_preset] = selected_index
	
	apply_preset.set_disabled(selected_index <= 1)
	remove_preset.set_disabled(selected_index <= 1)


func _on_presets_item_selected(index: int) -> void:
	FileCache.options[selected_key_preset] = index
	apply_preset.set_disabled(index <= 1)
	remove_preset.set_disabled(index <= 1)


func _on_save_preset_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = "Set name for this preset"
	dialog.text_selected.connect(
		func(preset_name: String):
			if not FileCache.options.has(presets_key):
				FileCache.options[presets_key] = {}
			save_preset_requested.emit(FileCache.options[presets_key], preset_name.to_lower())
			_update_presets(presets_node.get_item_count())
	)


func _on_remove_preset_pressed() -> void:
	var index = presets_node.get_selected_id()
	if index > 1:
		var preset_name = presets_node.get_item_text(index).to_lower()
		if FileCache.options.has(presets_key):
			FileCache.options[presets_key].erase(preset_name)
			_update_presets(index)


func _on_apply_preset_pressed() -> void:
	var index = presets_node.get_selected_id()
	if index > 1:
		var preset_name = presets_node.get_item_text(index).to_lower()
		if FileCache.options.has(presets_key):
			var current_data = FileCache.options[presets_key].get(preset_name)
			if current_data:
				load_preset_requested.emit(current_data)
