extends ItemList

@export var scroll_container: ScrollContainer

# Estructura para almacenar datos del item
class ItemData:
	var icon: Texture2D
	var name: String
	var quantity: int
	var price: float
	var color: Color
	
	func _init(p_icon: Texture2D, p_name: String, p_quantity: int, p_price: float, p_color: Color):
		icon = p_icon
		name = p_name
		quantity = p_quantity
		price = p_price
		color = p_color

# Array para almacenar los datos de los items
var item_data_array: Array[ItemData] = []

# Configuración de renderizado
var icon_size = Vector2.ZERO
var name_margin = 10
var price_margin = 10

func _ready():
	# Conectar la señal de dibujo personalizado
	clear_all_items()
	item_selected.connect(_on_item_selected)

func _draw():
	# Obtener el font del tema
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	var font_color = get_theme_color("font_color")
	
	# Gold currency:
	#var gold_currency = RPGSYSTEM.database.system.currency_info.name
	
	# precalcular icon_size
	var sizes = []
	icon_size = Vector2.ZERO
	for i in range(item_data_array.size()):
		var current_rect = get_item_rect(i)
		var item_data = item_data_array[i]
		if item_data.icon != null:
			var w = item_data.icon.get_width()
			var h = item_data.icon.get_height()
			var icon_ratio = (current_rect.size.y - 2) / float(h)
			var real_icon_size = Vector2(w * icon_ratio, current_rect.size.y - 2)
			icon_size.x = max(icon_size.x, real_icon_size.x)
			icon_size.y = max(icon_size.y, real_icon_size.y)
			sizes.append(real_icon_size)
		else:
			sizes.append(null)
		
	
	# Dibujar cada item personalizado
	var scroll_offset = Vector2(get_h_scroll_bar().value, get_v_scroll_bar().value)
	for i in range(item_data_array.size()):
		var current_rect = get_item_rect(i)
		var item_data = item_data_array[i]

		var y_pos = current_rect.position.y - scroll_offset.y
		var x_pos = current_rect.position.x - scroll_offset.x
		
		# Dibujar el ícono centrado
		if item_data.icon != null:
			var real_icon_size = sizes[i]
			# Calcular el offset para centrar el icono real dentro del área máxima
			var center_offset_x = (icon_size.x - real_icon_size.x) / 2.0
			var center_offset_y = (icon_size.y - real_icon_size.y) / 2.0
			
			# Posición centrada del icono
			var icon_x = current_rect.position.x + center_offset_x - scroll_offset.x + int(name_margin / 2.0)
			var icon_y = current_rect.position.y + 1 + center_offset_y - scroll_offset.y
			
			var icon_rect = Rect2(icon_x, icon_y, real_icon_size.x, real_icon_size.y)
			draw_texture_rect(item_data.icon, icon_rect, false)
		
		# Posición del texto (después del ícono)
		var text_x = x_pos + icon_size.x + 8
		var text_height = font.get_height(font_size)
		var text_y = y_pos + (current_rect.size.y / 2) + (text_height / 2) - font.get_descent(font_size)
		var preffix = "+" if item_data.price > 0 else ""
		var price_text = GameManager.get_number_formatted(item_data.price, 2, preffix)
		var price_width = font.get_string_size(price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var price_x = size.x - price_width - price_margin
		
		# Determinar el color del precio (rojo si es negativo, verde si es positivo)
		var price_color = Color.GREEN if item_data.price > 0 else Color.RED if item_data.price < 0 else Color.WHITE
		
		# Determinar el color del nombre del item
		var name_color = item_data.color
		
		# Formatear los componentes del texto por separado
		var quantity_text = str(item_data.quantity) + " x "
		var name_text = item_data.name
		
		# Calcular anchos para el dibujado por partes
		var quantity_width = font.get_string_size(quantity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		#var name_width = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var total_text_width = size.x - name_margin - icon_size.x - 8 - price_width - price_margin - 8
		
		# Dibujar la cantidad en color por defecto
		draw_string(font, Vector2(text_x, text_y), quantity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_color)
		
		# Dibujar el nombre en su color específico
		var name_x = text_x + quantity_width
		var available_name_width = total_text_width - quantity_width
		draw_string(font, Vector2(name_x, text_y), name_text, HORIZONTAL_ALIGNMENT_LEFT, available_name_width, font_size, name_color, TextServer.JUSTIFICATION_CONSTRAIN_ELLIPSIS)
		
		# Dibujar el precio en su color específico (rojo/verde/blanco)
		draw_string(font, Vector2(price_x, text_y), price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, price_color)


func add_items(items: Array) -> void:
	clear_all_items()
	for item: Dictionary in items:
		add_formatted_item(
			item.get("icon", null),
			item.get("name", ""),
			item.get("quantity", 0),
			item.get("unit_price", 0) * item.get("quantity", 0),
			item.get("color", Color.WHITE)
		)

# Función para añadir un item al ItemList
func add_formatted_item(icon: Texture2D, item_name: String, quantity: int, price: float, text_color: Color):
	# Crear el objeto ItemData
	var item_data = ItemData.new(icon, item_name, quantity, price, text_color)
	item_data_array.append(item_data)
	
	# Añadir un item vacío (solo un espacio) al ItemList
	add_item(" ")
	
	# Forzar redibujado
	queue_redraw()

# Función para obtener los datos de un item específico
func get_item_data(index: int) -> ItemData:
	if index >= 0 and index < item_data_array.size():
		return item_data_array[index]
	return null

# Función para obtener el precio total de un item
func get_item_total_price(index: int) -> float:
	var data = get_item_data(index)
	if data:
		return data.quantity * data.unit_price
	return 0.0

# Función para obtener el precio total de todos los items
func get_total_price() -> float:
	var total = 0.0
	for data in item_data_array:
		total += data.quantity * data.unit_price
	return total

# Función para limpiar todos los items
func clear_all_items():
	clear()
	item_data_array.clear()
	queue_redraw()

# Función para eliminar un item específico
func remove_item_at(index: int):
	if index >= 0 and index < item_data_array.size():
		remove_item(index)
		item_data_array.remove_at(index)
		queue_redraw()

# Función para actualizar un item existente
func update_item(index: int, new_quantity: int = -1, new_price: float = -1.0):
	if index >= 0 and index < item_data_array.size():
		var data = item_data_array[index]
		
		if new_quantity >= 0:
			data.quantity = new_quantity
		if new_price >= 0:
			data.unit_price = new_price
		
		queue_redraw()

# Callback para manejar selección de items
func _on_item_selected(_index: int):
	queue_redraw()

# Configurar el tamaño del ícono
func set_icon_size(new_size: Vector2):
	icon_size = new_size
	queue_redraw()
