class_name PageFlipSetupManager extends RefCounted

## Reference to the main book node.
var book: Node2D


## Initializes the setup manager.
func _init(book_node: Node2D) -> void:
	book = book_node


#region Node Construction
## Builds the internal viewport structure required for rendering interactive pages.
func build_viewports() -> void:
	book._slot_1 = SubViewport.new()
	book._slot_1.name = "Slot_1_Static_Left"
	book._slot_1.transparent_bg = true
	book._slot_1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	book._slot_2 = SubViewport.new()
	book._slot_2.name = "Slot_2_Static_Right"
	book._slot_2.transparent_bg = true
	book._slot_2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	book._slot_3 = SubViewport.new()
	book._slot_3.name = "Slot_3_Dynamic_Front"
	book._slot_3.transparent_bg = true
	book._slot_3.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	book._slot_4 = SubViewport.new()
	book._slot_4.name = "Slot_4_Dynamic_Back"
	book._slot_4.transparent_bg = true
	book._slot_4.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	book.add_child(book._slot_1)
	book.add_child(book._slot_2)
	book.add_child(book._slot_3)
	book.add_child(book._slot_4)


## Constructs the main visual container and base polygon geometry nodes.
func build_visual_nodes() -> void:
	if not book.visuals_container:
		book.visuals_container = Node2D.new()
		book.visuals_container.name = "VisualsContainer"
		book.add_child(book.visuals_container)
		
	if not book.static_left:
		book.static_left = Polygon2D.new()
		book.static_left.name = "StaticLeft"
		book.static_left.z_index = 0
		book.visuals_container.add_child(book.static_left)
		
	if not book.static_right:
		book.static_right = Polygon2D.new()
		book.static_right.name = "StaticRight"
		book.static_right.z_index = 0
		book.visuals_container.add_child(book.static_right)
		
	if not book.cover_left_poly:
		book.cover_left_poly = Polygon2D.new()
		book.cover_left_poly.name = "CoverLeft"
		book.cover_left_poly.z_index = -2
		book.visuals_container.add_child(book.cover_left_poly)
		
	if not book.cover_right_poly:
		book.cover_right_poly = Polygon2D.new()
		book.cover_right_poly.name = "CoverRight"
		book.cover_right_poly.z_index = -2
		book.visuals_container.add_child(book.cover_right_poly)
		
	if not book.dynamic_poly:
		book.dynamic_poly = Polygon2D.new()
		book.dynamic_poly.name = "DynamicPage"
		book.dynamic_poly.z_index = 10
		book.visuals_container.add_child(book.dynamic_poly)


## Constructs all the shadow overlays and depth effect nodes automatically.
func build_shadow_nodes() -> void:
	var names = ["CoverStackShadowLeft", "CoverStackShadowRight", "StackDropShadowLeft", "StackDropShadowRight"]
	var z_indices = [-1, -1, -3, -3]
	
	for i in range(names.size()):
		var n = names[i]
		var node = book.visuals_container.get_node_or_null(n)
		
		if not node:
			node = Polygon2D.new()
			node.name = n
			node.z_index = z_indices[i]
			book.visuals_container.add_child(node)
			
	var drop_shadow = book.visuals_container.get_node_or_null("DropShadowPoly")
	
	if not drop_shadow:
		drop_shadow = Polygon2D.new()
		drop_shadow.name = "DropShadowPoly"
		drop_shadow.z_index = 1
		drop_shadow.color = Color(0, 0, 0, 0.3)
		book.visuals_container.add_child(drop_shadow)
		
	var auto_shadow = book.dynamic_poly.get_node_or_null("AutoShadow")
	
	if not auto_shadow:
		auto_shadow = Polygon2D.new()
		auto_shadow.name = "AutoShadow"
		auto_shadow.z_index = -1
		auto_shadow.color = Color(0, 0, 0, 1.0)
		book.dynamic_poly.add_child(auto_shadow)
#endregion


#region Viewport Sizing
## Recursively updates the physical size of all active subviewports in the hierarchy.
func update_viewports_recursive(node: Node, size: Vector2) -> void:
	if node is SubViewport:
		node.size = size
		node.size_2d_override = size
		node.size_2d_override_stretch = true
		
	for child in node.get_children():
		update_viewports_recursive(child, size)
#endregion
