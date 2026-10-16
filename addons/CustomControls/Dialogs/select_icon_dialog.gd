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


func _get_texture_from_path(p_path: String) -> Texture2D:
	if not p_path or not ResourceLoader.exists(p_path):
		return null
	var res = load(p_path)
	if res is Texture2D:
		return res
	elif res is PackedScene:
		var ins = res.instantiate()
		var found_tex: Texture2D = null
		if ins is Sprite2D or ins is TextureRect:
			found_tex = ins.texture
		else:
			var spr = ins.find_child("*", true, false)
			if spr is Sprite2D or spr is TextureRect:
				found_tex = spr.texture
		ins.queue_free()
		if found_tex:
			return found_tex
		var preview_path = p_path.get_basename() + "_preview.png"
		if ResourceLoader.exists(preview_path):
			var p_res = load(preview_path)
			if p_res is Texture2D:
				return p_res
	return null


func set_data(_data: RPGIcon) -> void:
	real_data = _data
	data = _data.clone(true)
	var tex = _get_texture_from_path(data.path)
	if tex:
		main_texture.region = data.region
		main_texture.atlas = tex
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
	draw_icon()
	fill_region()
	var tex = _get_texture_from_path(data.path)
	if tex:
		main_texture.atlas = tex


func draw_icon() -> void:
	%IconPicker.set_icon(data.path, data.region)


func fill_region() -> void:
	var tex = _get_texture_from_path(data.path)
	if tex != null:
		%ImageRegion.set_disabled(false)
		if data.region.has_area():
			%ImageRegion.text = "Region: " + str(data.region)
		else:
			%ImageRegion.text = "Region: None"
	else:
		%ImageRegion.set_disabled(true)
		%ImageRegion.text = "-"


func _on_icon_picker_remove_requested() -> void:
	data.path = ""
	data.region = Rect2()
	main_texture.region = Rect2()
	%ImageRegion.set_disabled(true)
	%IconPicker.set_icon("")
	fill_region()


func _on_image_region_middle_click_pressed() -> void:
	data.region = Rect2()
	main_texture.region = Rect2()
	fill_region()
	draw_icon()


func _on_image_region_pressed() -> void:
	var tex = _get_texture_from_path(data.path)
	if tex:
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
