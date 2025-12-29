@tool
extends Window

@export var main_texture: AtlasTexture

var real_data: RPGIcon 
var data: RPGIcon

var editor_interface
var last_resource_edited: Object
var region_found: bool = false

var  extra_files: Array = []


signal icon_changed()


func _ready() -> void:
	main_texture = AtlasTexture.new()
	main_texture.changed.connect(_update_all)
	close_requested.connect(queue_free)
	tree_exiting.connect(_on_tree_exiting)
	data = RPGIcon.new()


func set_data(_data: RPGIcon) -> void:
	real_data = _data
	data = _data.clone(true)
	if ResourceLoader.exists(data.path):
		main_texture.region = data.region
		main_texture.atlas = load(data.path)
	draw_icon()
	fill_region()


func _on_ok_button_pressed() -> void:
	real_data.path = data.path
	real_data.region = data.region
	icon_changed.emit()
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_icon_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = update_icon
	dialog.set_dialog_mode(0)
	if data:
		dialog.set_file_selected(data.path)
	
	if extra_files.is_empty():
		dialog.fill_files("images")
	else:
		var files = extra_files + ["images"]
		dialog.fill_mix_files(files)


func update_icon(path: String) -> void:
	data.path = path
	%ImageRegion.set_disabled(false)
	draw_icon()
	fill_region()
	main_texture.atlas = %IconPicker.get_main_texture()


func draw_icon() -> void:
	%IconPicker.set_icon(data.path, data.region)


func fill_region() -> void:
	%ImageRegion.text = "Region: " + str(data.region)


func _on_icon_picker_remove_requested() -> void:
	data.path = ""
	%ImageRegion.set_disabled(true)
	%IconPicker.set_icon("")
	fill_region()


func _on_image_region_middle_click_pressed() -> void:
	data.region = Rect2()
	main_texture.region = Rect2()
	fill_region()


func _on_image_region_pressed() -> void:
	if data.path and ResourceLoader.exists(data.path):
		var tex = load(data.path)
		var region = data.region
		var path = "res://addons/CustomControls/Dialogs/custom_edit_texture_region_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.edit(tex, region)
		dialog.region_changed.connect(
			func(new_region: Rect2):
				main_texture.region = new_region
				_update_all()
		)


func _update_all() -> void:
	data.region = main_texture.region
	fill_region()
	draw_icon()


func _on_tree_exiting() -> void:
	if editor_interface:
		if last_resource_edited is Node:
			editor_interface.edit_node(last_resource_edited)
		elif last_resource_edited is Resource:
			editor_interface.edit_resource(last_resource_edited)
		else:
			editor_interface.edit_node(null)
