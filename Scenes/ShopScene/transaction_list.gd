extends ItemList

@export var scroll_container: ScrollContainer

# Structure to store item data
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

# Array to store item data
var item_data_array: Array[ItemData] = []

# Rendering configuration
var icon_size = Vector2.ZERO
var name_margin = 10
var price_margin = 10

func _ready():
	# Connect custom draw signal
	clear_all_items()
	item_selected.connect(_on_item_selected)

func _draw():
	# Get theme font
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	var font_color = get_theme_color("font_color")
	
	# Gold currency:
	#var gold_currency = RPGSYSTEM.database.system.currency_info.name
	
	# precalculate icon_size
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
		
	
	# Draw each custom item
	var scroll_offset = Vector2(get_h_scroll_bar().value, get_v_scroll_bar().value)
	for i in range(item_data_array.size()):
		var current_rect = get_item_rect(i)
		var item_data = item_data_array[i]

		var y_pos = current_rect.position.y - scroll_offset.y
		var x_pos = current_rect.position.x - scroll_offset.x
		
		# Draw centered icon
		if item_data.icon != null:
			var real_icon_size = sizes[i]
			# Calculate offset to center real icon within max area
			var center_offset_x = (icon_size.x - real_icon_size.x) / 2.0
			var center_offset_y = (icon_size.y - real_icon_size.y) / 2.0
			
			# Centered icon position
			var icon_x = current_rect.position.x + center_offset_x - scroll_offset.x + int(name_margin / 2.0)
			var icon_y = current_rect.position.y + 1 + center_offset_y - scroll_offset.y
			
			var icon_rect = Rect2(icon_x, icon_y, real_icon_size.x, real_icon_size.y)
			draw_texture_rect(item_data.icon, icon_rect, false)
		
		# Text position (after icon)
		var text_x = x_pos + icon_size.x + 8
		var text_height = font.get_height(font_size)
		var text_y = y_pos + (current_rect.size.y / 2) + (text_height / 2) - font.get_descent(font_size)
		var preffix = "+" if item_data.price > 0 else ""
		var price_text = GameManager.get_number_formatted(item_data.price, 2, preffix)
		var price_width = font.get_string_size(price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var price_x = size.x - price_width - price_margin
		
		# Determine price color (red if negative, green if positive)
		var price_color = Color.GREEN if item_data.price > 0 else Color.RED if item_data.price < 0 else Color.WHITE
		
		# Determine item name color
		var name_color = item_data.color
		
		# Format text components separately
		var quantity_text = str(item_data.quantity) + " x "
		var name_text = item_data.name
		
		# Calculate widths for partial drawing
		var quantity_width = font.get_string_size(quantity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		#var name_width = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var total_text_width = size.x - name_margin - icon_size.x - 8 - price_width - price_margin - 8
		
		# Draw quantity in default color
		draw_string(font, Vector2(text_x, text_y), quantity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_color)
		
		# Draw name in specific color
		var name_x = text_x + quantity_width
		var available_name_width = total_text_width - quantity_width
		draw_string(font, Vector2(name_x, text_y), name_text, HORIZONTAL_ALIGNMENT_LEFT, available_name_width, font_size, name_color, TextServer.JUSTIFICATION_CONSTRAIN_ELLIPSIS)
		
		# Draw price in specific color (red/green/white)
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

# Function to add an item to ItemList
func add_formatted_item(icon: Texture2D, item_name: String, quantity: int, price: float, text_color: Color):
	# Create ItemData object
	var item_data = ItemData.new(icon, item_name, quantity, price, text_color)
	item_data_array.append(item_data)
	
	# Add empty item (just a space) to ItemList
	add_item(" ")
	
	# Force redraw
	queue_redraw()

# Function to get specific item data
func get_item_data(index: int) -> ItemData:
	if index >= 0 and index < item_data_array.size():
		return item_data_array[index]
	return null

# Function to get total price of an item
func get_item_total_price(index: int) -> float:
	var data = get_item_data(index)
	if data:
		return data.quantity * data.unit_price
	return 0.0

# Function to get total price of all items
func get_total_price() -> float:
	var total = 0.0
	for data in item_data_array:
		total += data.quantity * data.unit_price
	return total

# Function to clear all items
func clear_all_items():
	clear()
	item_data_array.clear()
	queue_redraw()

# Function to remove specific item
func remove_item_at(index: int):
	if index >= 0 and index < item_data_array.size():
		remove_item(index)
		item_data_array.remove_at(index)
		queue_redraw()

# Function to update existing item
func update_item(index: int, new_quantity: int = -1, new_price: float = -1.0):
	if index >= 0 and index < item_data_array.size():
		var data = item_data_array[index]
		
		if new_quantity >= 0:
			data.quantity = new_quantity
		if new_price >= 0:
			data.unit_price = new_price
		
		queue_redraw()

# Callback to handle item selection
func _on_item_selected(_index: int):
	queue_redraw()

# Configure icon size
func set_icon_size(new_size: Vector2):
	icon_size = new_size
	queue_redraw()
