@tool
extends Window

const KERNING = preload("uid://n6v1d3ijka7d")

var current_character: String = ""
var target_letter_node: PanelContainer
var preview_font: FontFile

@onready var current_char: Label = %CurrentChar
@onready var letter_list: OptionButton = %LetterList
@onready var add_pair_button: Button = %AddPairButton
@onready var main_container: VBoxContainer = %MainContainer

signal kerning_updated()



## Inicializa la ventana y conecta la señal del botón
func _ready() -> void:
	close_requested.connect(queue_free)
	add_pair_button.pressed.connect(_on_add_pair_button_pressed)



## Recibe los datos de la letra, la fuente y las opciones de emparejamiento
func set_data(character: String, letter_node: PanelContainer, font: FontFile, all_characters: Array[String]) -> void:
	current_character = character
	target_letter_node = letter_node
	preview_font = font
	
	title = "Kerning: " + character
	current_char.text = character
	current_char.add_theme_font_override("font", preview_font)
	
	letter_list.clear()
	
	for i in range(all_characters.size()):
		var char_str: String = tr("Character → ") + all_characters[i]
		letter_list.add_item(char_str)
		letter_list.set_item_metadata(i, all_characters[i])
		
		if char_str == current_character:
			letter_list.set_item_disabled(i, true)
			
	if letter_list.get_item_count() > 0:
		for i in range(letter_list.get_item_count()):
			if not letter_list.is_item_disabled(i):
				letter_list.select(i)
				break
				
	_load_existing_kernings()



## Carga las parejas de kerning que ya existan guardadas en la letra
func _load_existing_kernings() -> void:
	for child in main_container.get_children():
		child.queue_free()
		
	for next_char_id in target_letter_node.kernings.keys():
		var pair_letter: String = String.chr(next_char_id)
		var kerning_val: int = target_letter_node.kernings[next_char_id]
		_create_kerning_panel(pair_letter, kerning_val)



## Instancia un nuevo panel de kerning y conecta sus señales
func _create_kerning_panel(pair_letter: String, kerning_val: int) -> void:
	var panel = KERNING.instantiate()
	main_container.add_child(panel)
	
	panel.set_meta("pair_letter", pair_letter)
	panel.update_text(current_character, pair_letter, preview_font)
	panel.kerning.set_value_no_signal(kerning_val)
	
	panel.remove_requested.connect(_on_panel_remove_requested)
	panel.kerning_updated.connect(_on_panel_kerning_updated)



## Crea un nuevo par de kerning seleccionando desde el OptionButton
func _on_add_pair_button_pressed() -> void:
	var selected_idx: int = letter_list.selected
	
	if selected_idx < 0 or letter_list.is_item_disabled(selected_idx):
		return
		
	var pair_letter: String = letter_list.get_item_metadata(letter_list.get_selected_id())
	var char_id: int = current_character.unicode_at(0)
	var next_char_id: int = pair_letter.unicode_at(0)
	
	if target_letter_node.kernings.has(next_char_id):
		return
		
	target_letter_node.kernings[next_char_id] = 0
	
	if preview_font != null:
		var size: int = preview_font.fixed_size
		preview_font.set_kerning(0, size, Vector2i(char_id, next_char_id), Vector2.ZERO)
		
	_create_kerning_panel(pair_letter, 0)
	kerning_updated.emit()



## Elimina un panel de kerning y lo borra del diccionario de la letra
func _on_panel_remove_requested(index: int) -> void:
	var panel = main_container.get_child(index)
	
	if panel:
		var pair_letter: String = panel.get_meta("pair_letter")
		target_letter_node.kernings.erase(pair_letter.unicode_at(0))
		
		panel.queue_free()
		kerning_updated.emit()



## Actualiza el valor de kerning de una pareja existente
func _on_panel_kerning_updated(index: int, kerning_val: int) -> void:
	var panel = main_container.get_child(index)
	
	if panel:
		var pair_letter: String = panel.get_meta("pair_letter")
		var char_id: int = current_character.unicode_at(0)
		var next_char_id: int = pair_letter.unicode_at(0)
		
		target_letter_node.kernings[next_char_id] = kerning_val
		
		if preview_font != null:
			var size: int = preview_font.fixed_size
			preview_font.set_kerning(0, size, Vector2i(char_id, next_char_id), Vector2(kerning_val, 0))
			
			panel.preview_label.text = ""
			panel.update_text(current_character, pair_letter, preview_font)
			
		kerning_updated.emit()


func _on_cancel_button_pressed() -> void:
	queue_free()
