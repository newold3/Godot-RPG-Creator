@tool
extends Window


#region VARIABLES
var presets_data: MapGeneratorPresets
var current_selected_index: int = -1

@onready var preset_list: ItemList = %PresetList
@onready var btn_delete: Button = %DeletePreset
@onready var name_edit: LineEdit = %PresetName
@onready var details_label: RichTextLabel = %PresetDetails
@onready var btn_close: Button = %CloseButton
#endregion



## Conecta las señales de la interfaz
func _ready() -> void:
	close_requested.connect(queue_free)
	preset_list.item_selected.connect(_on_preset_selected)
	preset_list.item_activated.connect(_on_item_activated.unbind(1))
	name_edit.text_changed.connect(_on_name_changed)
	btn_delete.pressed.connect(_on_delete_pressed)
	btn_close.pressed.connect(_on_close_pressed)



## Recibe los datos desde el panel flotante e inicializa la lista
func set_data(data: MapGeneratorPresets) -> void:
	presets_data = data
	_populate_list()



## Limpia la interfaz y rellena el ItemList con los presets actuales
func _populate_list() -> void:
	preset_list.clear()
	current_selected_index = -1
	name_edit.text = ""
	details_label.text = ""
	
	name_edit.set_disabled(true)
	btn_delete.set_disabled(true)
	
	if not presets_data:
		return
		
	for preset in presets_data.presets_list:
		preset_list.add_item(preset.get("preset_name", "Unknown"))
	
	if preset_list.get_item_count() > 0:
		preset_list.select(0)
		preset_list.item_selected.emit(0)



## Actualiza la columna derecha al seleccionar un preset mostrando sus datos formateados
func _on_preset_selected(index: int) -> void:
	current_selected_index = index
	
	name_edit.set_disabled(false)
	btn_delete.set_disabled(false)
	
	var preset: Dictionary = presets_data.presets_list[index]
	name_edit.text = preset.get("preset_name", "Unknown")
	
	var details: String = "[b]Current Preset Config:[/b]\n\n"
	
	for key in preset.keys():
		if key == "preset_name":
			continue
			
		var value: Variant = preset[key]
		var val_str: String = ""
		
		if value is Resource:
			val_str = "[color=cyan]Resource (" + value.get_class() + ")[/color]"
		elif typeof(value) == TYPE_DICTIONARY:
			val_str = "[color=yellow]Custom Data[/color]"
		else:
			val_str = "[color=lightgreen]" + str(value) + "[/color]"
			
		details += "[b]" + key.capitalize() + ":[/b] " + val_str + "\n"
		
	details_label.text = details


func _on_item_activated() -> void:
	name_edit.grab_focus()



## Actualiza el nombre del preset en tiempo real en la lista y guarda el archivo
func _on_name_changed(new_text: String) -> void:
	if presets_data and current_selected_index != -1:
		presets_data.presets_list[current_selected_index]["preset_name"] = new_text
		preset_list.set_item_text(current_selected_index, new_text)
		presets_data.save_presets()



## Elimina el preset seleccionado de la base de datos y refresca la lista visual
func _on_delete_pressed() -> void:
	if presets_data and current_selected_index != -1:
		presets_data.presets_list.remove_at(current_selected_index)
		presets_data.save_presets()
		_populate_list()



## Cierra y destruye la ventana de forma segura
func _on_close_pressed() -> void:
	queue_free()
#endregion
