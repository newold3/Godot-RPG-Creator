class_name BestiaryPage
extends MarginContainer

@export var monster_database: Array
@onready var page_label: Label = %PaginatorLabel # Tu nodo de texto abajo

var _book: PageFlip2D
var _page_idx: int = -1
var _is_left: bool = false
var _is_index: bool = false

var silhouette_shade_levels: float = 1.21
var reveal_shade_levels: float = 14.0


@warning_ignore("unused_signal")
signal manage_pageflip(give_control_to_book: bool)


func _ready() -> void:
	_book = BookAPI.find_book_controller(self)
	_page_idx = get_meta("page_index", -1)
	_is_left = get_meta("is_left", false)
	
	# Configurar el paginador visual (sumamos 1 porque el array empieza en 0)
	if page_label:
		page_label.text = "- %d -" % (_page_idx + 1)
	
	if _page_idx == 0: # Asumiendo que el índice es el primer elemento del array
		#if page_label: 
			#page_label.hide() # Ocultamos el número de página en el índice
		_build_index()
		
	else:
		_build_monster_entry()
	
	#GameManager.force_show_cursor.call_deferred()


func _process(delta: float) -> void:
	if _is_index:
		GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())


func _build_index() -> void:
	_is_index = true
	%IndexContainer.visible = true
	%ContentsLeftContainer.visible = false
	%ContentsRightContainer.visible = false
	%DebugText.text = "SOY EL INDICE"
	%ItemList.item_activated.connect(_on_item_list_item_activated)
	pass


func _build_monster_entry() -> void:
	%IndexContainer.visible = false
	%ContentsLeftContainer.visible = false
	%ContentsRightContainer.visible = false
	# Calculamos el ID del monstruo. 
	# Si _page_idx 1 y 2 son el monstruo 0, _page_idx 3 y 4 son el monstruo 1...
	@warning_ignore("integer_division")
	var monster_id = int((_page_idx - 1) / 2) + 1

	%DebugText.text = "Soy el monstruo: %s" % monster_id + "\n\n" + \
		"Estoy en\nla pagina %s" % ("Izquierda" if _is_left else "Derecha")
	
	var monster: RPGEnemy = RPGSYSTEM.get_data("enemies", monster_id)
	
	if monster:
		if _is_left:
			%MonsterName.text = monster.name.capitalize()
			if AssetManager.file_exists(monster.battler):
				%MonsterImage.texture = load(monster.battler)
			else:
				%MonsterImage.texture = null
		%DebugText.text = "Soy el monstruo %s" % monster.name
	
	if _is_left:
		%ContentsLeftContainer.visible = true
	else:
		%ContentsRightContainer.visible = true


func _on_item_list_item_activated(index: int) -> void:
	var target_page = (index * 2) + 2
	BookAPI.go_to_page(target_page, BookAPI.JumpTarget.CONTENT_PAGE, true, _book)


func _on_return_to_index_pressed() -> void:
	BookAPI.go_to_page(1, BookAPI.JumpTarget.CONTENT_PAGE, true, _book)


func _on_button_pressed() -> void:
	print("click")
