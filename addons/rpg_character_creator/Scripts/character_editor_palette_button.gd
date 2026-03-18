@tool
class_name CharacterEditorPaletteButton
extends HBoxContainer


@export var button_name: String :
	set(value):
		button_name = value
		var node = get_node_or_null("%Name")
		if node:
			node.text = button_name

@export var part_id: String = ""

@export var palette_button_disabled: bool = false :
	set(value):
		palette_button_disabled = value
		var node = get_node_or_null("%PaletteButton")
		if node:
			node.set_disabled(value)


@export var loading_icon: Texture
@export var none_icon: Texture
@export var use_icons: bool = true


enum ButtonType { PALETTE, LOCK }

var is_locked: bool = false


signal item_selected(part_id: String, item_id: String)
signal palette_button_pressed(part_id: String)
signal locked_button_pressed(part_id: String)


func _ready() -> void:
	%Name.text = button_name
	item_selected.connect(_on_item_selected)


func pick_random() -> void:
	var node = %Options
	node.select(randi() % node.get_item_count())
	node.item_selected.emit(node.get_selected_id())
	
	%PaletteButton.set_disabled(node.get_item_metadata(node.get_selected_id()) == "none" or part_id == "gender")


func reset() -> void:
	var node = %Options
	node.select(0)
	node.item_selected.emit(0)


func call_item_selected_signal() -> void:
	var node = %Options
	node.item_selected.emit(node.get_selected_id())


func fill(data: Dictionary, selected_id: String = "") -> void:
	var node: OptionButton = %Options
	var selected_item := node.get_selected_id()
	node.clear()
	
	var items := []
	var item_none_found: bool = false
	for key in data.keys():
		if data[key].get("chargen", false):
			if key == "none":
				items.insert(0, [key, data[key]])
				item_none_found = true
			else:
				items.append([key, data[key]])
	
	fix_item_names(items)

	for item in items:
		node.add_item(item[1].name)
		if use_icons:
			if item == items[0] and item[0] == "none":
				node.set_item_icon(-1,  none_icon)
			elif item != items[0] or item[0] != "none":
				node.set_item_icon(-1, loading_icon)
		node.set_item_metadata(-1, item[0])
		if selected_item == -1:
			if item[1].get("default", false):
				selected_item = node.get_item_count() - 1
		elif selected_item >= 0 and selected_id and item[0] == selected_id:
			selected_item = node.get_item_count() - 1

	if node.get_item_count() == 0:
		node.add_item("none")
		node.set_item_metadata(-1, "none")
	
	if (selected_item == -1 or selected_item == 0) and selected_id:
		for i in items.size():
			var item = items[i]
			if item[0] == selected_id:
				selected_item = i
				break
	
	selected_item = 0 if selected_item < 0 else selected_item

	if node.get_item_count() > selected_item:
		node.select(selected_item)
		node.item_selected.emit(selected_item)
	else:
		node.select(0)
		node.item_selected.emit(0)
	
	if node.get_item_count() <= 1:
		if node.get_item_count() == 1 and node.get_item_metadata(0) != "none":
			unlock()
			soft_lock()
			%PaletteButton.set_disabled(false)
		else:
			lock()
	else:
		unlock()
	
	%PaletteButton.set_disabled(node.get_item_metadata(node.get_selected_id()) == "none" or part_id == "gender")


func fix_item_names(items: Array) -> void:
	var name_count := {}
	
	for item in items:
		var base_name = remove_numbers_from_name(item[1].name).strip_edges()
		item[1].name = base_name
		
		if name_count.has(base_name):
			name_count[base_name] += 1
		else:
			name_count[base_name] = 1
	
	var name_used := {}
	for item in items:
		var base_name = item[1].name
		
		if name_count[base_name] > 1:
			if not name_used.has(base_name):
				name_used[base_name] = 1
			
			var new_name = base_name + " " + str(name_used[base_name])
			item[1].name = new_name
			name_used[base_name] += 1


func remove_numbers_from_name(name: String) -> String:
	var regex := RegEx.new()
	regex.compile(" \\d+$")
	return regex.sub(name, "")


func _on_options_item_selected(index: int) -> void:
	var real_id = %Options.get_item_metadata(index)
	if real_id:
		item_selected.emit(part_id, real_id)


func has_none() -> bool:
	var real_id = %Options.get_item_metadata(0)
	return real_id == "none"


func _on_palette_button_pressed() -> void:
	palette_button_pressed.emit(part_id)


func _on_lock_button_pressed() -> void:
	locked_button_pressed.emit(part_id)
	is_locked = %LockButton.is_pressed()


func disable_button(button_type: ButtonType, value: bool = true) -> void:
	match button_type:
		ButtonType.PALETTE:
			%PaletteButton.set_disabled(value)
		ButtonType.LOCK:
			%LockButton.set_disabled(value)


func perform_update() -> void:
	var id = get_selected_id()
	var meta = %Options.get_item_metadata(id) if id != -1 else ""
	if meta:
		item_selected.emit(part_id, meta)


func lock() -> void:
	soft_lock()
	%Options.text = TranslationManager.tr("none")


func soft_lock() -> void:
	%Options.set_disabled(true)
	%PaletteButton.set_disabled(true)
	%LockButton.set_disabled(true)


func unlock() -> void:
	%Options.set_disabled(false)
	%PaletteButton.set_disabled(false)
	%LockButton.set_disabled(false)
	%Options.text = %Options.get_item_text(%Options.get_selected_id())


func select(item_id: String) -> void:
	%Options.select(0)
	for i in %Options.get_item_count():
		if item_id == %Options.get_item_metadata(i):
			%Options.select(i)
			break
	
	item_selected.emit(part_id, %Options.get_item_metadata(%Options.get_selected()))


func get_popup() -> PopupMenu:
	return %Options.get_popup()


func get_items() -> Array:
	var items = []
	for i in %Options.get_item_count():
		items.append(%Options.get_item_metadata(i))
	return items


func get_selected_id() -> int:
	return %Options.get_selected_id()


func get_real_id() -> String:
	var index = get_selected_id()
	if index != -1:
		var real_id = %Options.get_item_metadata(index)
		if real_id == null: real_id = ""
		return real_id
	
	return ""


func reselect() -> void:
	var id = %Options.get_selected_id()
	if id != -1:
		%Options.set_text(%Options.get_item_text(id))
		%Options.set_item_icon(id, %Options.get_item_icon(id))


func _on_item_selected(part_id: String, item_id: String) -> void:
	%PaletteButton.set_disabled(item_id == "none" or part_id == "gender")


func set_item_icon_at_index(index: int, texture: Texture) -> void:
	index = clamp(index, 0, %Options.get_item_count() - 1)
	if texture:
		%Options.set_item_icon(index, texture)
	elif use_icons:
		%Options.set_item_icon(index, none_icon)


func set_item_icon_to_null_at_index(index: int) -> void:
	%Options.set_item_icon(index, null)


func _on_options_middle_click() -> void:
	var node = %Options
	node.select(0)
	node.item_selected.emit(node.get_selected_id())
	
	%PaletteButton.set_disabled(node.get_item_metadata(node.get_selected_id()) == "none" or part_id == "gender")
