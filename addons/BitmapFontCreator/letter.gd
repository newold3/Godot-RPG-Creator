@tool
extends PanelContainer

var current_character: String = ""
var is_selected: bool = false
var atlas_texture: AtlasTexture
var glyph_offset: Vector2 = Vector2.ZERO
var glyph_advance: float = 0.0
var kernings: Dictionary = {}

@onready var letter_texture: TextureRect = %LetterTexture
@onready var select_char: LineEdit = %SelectChar


signal char_changed(index: int, char: String)
signal click(panel: PanelContainer)
signal kerning_dialog_request(character: String, letter_node: PanelContainer)



## Inicializa el nodo y conecta la señal de click
func _ready() -> void:
	click.connect(select.unbind(1), CONNECT_DEFERRED)
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(self)



## Cambia el color del panel según su estado de selección y da el foco
func select() -> void:
	var panel = get_theme_stylebox("panel")
	panel.bg_color = Color("#b579cd") if is_selected else Color("959595")
	if select_char:
		select_char.grab_focus.call_deferred()



## Establece el estado de selección directamente desde código
func set_selected(state: bool) -> void:
	is_selected = state
	var panel = get_theme_stylebox("panel")
	panel.bg_color = Color("#b579cd") if is_selected else Color("959595")



## Sets the character visually without emitting signals to avoid loops in bulk operations
func set_character_silent(char_str: String) -> void:
	current_character = char_str
	
	if select_char:
		select_char.text = char_str



## Cambia el color del borde al entrar el ratón
func _on_mouse_entered() -> void:
	var panel = get_theme_stylebox("panel")
	panel.border_color = Color.ORANGE



## Restaura el color del borde al salir el ratón
func _on_mouse_exited() -> void:
	var panel = get_theme_stylebox("panel")
	panel.border_color = Color("#141414")



## Procesa el click izquierdo para alternar la selección y el doble click para el kerning
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if event.double_click:
			if not current_character.is_empty():
				kerning_dialog_request.emit(current_character, self)
		else:
			is_selected = !is_selected
			click.emit(self)



## Emite la señal cuando el caracter asignado cambia
func _on_select_char_text_changed(char: String) -> void:
	current_character = char
	char_changed.emit(get_index(), char)



## Recibe la imagen recortada desde el diálogo principal y la asigna al nodo
func set_image(atlas: AtlasTexture) -> void:
	atlas_texture = atlas
	
	if not is_node_ready():
		await ready
	
	if letter_texture != null:
		letter_texture.texture = atlas
	else:
		push_error("BitmapFontCreator: No se encontró el nodo %letter_texture en la escena de la letra.")


func _on_select_char_focus_entered() -> void:
	if select_char: 
		select_char.modulate = Color.GREEN


func _on_select_char_focus_exited() -> void:
	if select_char: 
		select_char.modulate = Color.WHITE
