@tool
extends Container


var need_sort_children: float = 0.0

signal children_orderer()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		need_sort_children = 0.04


func _process(delta: float) -> void:
	if need_sort_children > 0:
		need_sort_children -= delta
		if need_sort_children <= 0:
			need_sort_children = 0
			sort()


func sort() -> void:
	var minx = INF
	var maxx = -INF
	var miny = INF
	var maxy = -INF
	for c in get_children():
		if c is Control:
			if c.size_flags_horizontal == SIZE_SHRINK_BEGIN:
				c.position = Vector2(-c.size.x * 0.5, size.y - c.size.y)
			elif c.size_flags_horizontal == SIZE_SHRINK_CENTER:
				c.position = Vector2(size.x * 0.5 - c.size.x * 0.5, size.y - c.size.y)
			elif c.size_flags_horizontal == SIZE_SHRINK_END:
				c.position = Vector2(size.x - c.size.x * 0.5, size.y - c.size.y)
			c.set_meta("start_position", c.position)
			minx = min(minx, c.position.x)
			maxx = max(maxx, c.position.x + c.size.x)
			miny = min(miny, c.position.y)
			maxy = max(maxy, c.position.y + c.size.y)
	custom_minimum_size = Vector2(maxx - minx, maxy - miny)
	
	children_orderer.emit()


func _draw() -> void:
	draw_rect(get_rect(), Color(1, 0, 0, 0.3647058904171))
