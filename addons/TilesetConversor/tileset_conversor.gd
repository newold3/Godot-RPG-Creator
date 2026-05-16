@tool
class_name TilesetConversor
extends Node

#region CONSTANTS_EXTENDED_FORMAT

## 11-State mapped coordinates for the Top-Left quadrant of an Extended autotile
const EXTENDED_TL_STATES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 2), Vector2i(2, 2), Vector2i(4, 2),
	Vector2i(0, 4), Vector2i(2, 4), Vector2i(4, 4),
	Vector2i(0, 6), Vector2i(2, 6), Vector2i(4, 6), Vector2i(4, 0)
]

## 11-State mapped coordinates for the Top-Right quadrant of an Extended autotile
const EXTENDED_TR_STATES: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 2), Vector2i(3, 2), Vector2i(5, 2),
	Vector2i(1, 4), Vector2i(3, 4), Vector2i(5, 4),
	Vector2i(1, 6), Vector2i(3, 6), Vector2i(5, 6), Vector2i(5, 0)
]

## 11-State mapped coordinates for the Bottom-Left quadrant of an Extended autotile
const EXTENDED_BL_STATES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, 3), Vector2i(2, 3), Vector2i(4, 3),
	Vector2i(0, 5), Vector2i(2, 5), Vector2i(4, 5),
	Vector2i(0, 7), Vector2i(2, 7), Vector2i(4, 7), Vector2i(4, 1)
]

## 11-State mapped coordinates for the Bottom-Right quadrant of an Extended autotile
const EXTENDED_BR_STATES: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, 3), Vector2i(3, 3), Vector2i(5, 3),
	Vector2i(1, 5), Vector2i(3, 5), Vector2i(5, 5),
	Vector2i(1, 7), Vector2i(3, 7), Vector2i(5, 7), Vector2i(5, 1)
]

#endregion



#region CONSTANTS_COMPACT_FORMAT

## 11-State mapped coordinates for the Top-Left quadrant of a Compact autotile
const COMPACT_TL_STATES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 2),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(1, 3),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(1, 3), Vector2i(2, 0)
]

## 11-State mapped coordinates for the Top-Right quadrant of a Compact autotile
const COMPACT_TR_STATES: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(2, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(2, 3), Vector2i(2, 3), Vector2i(3, 3),
	Vector2i(2, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 0)
]

## 11-State mapped coordinates for the Bottom-Left quadrant of a Compact autotile
const COMPACT_BL_STATES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, 4), Vector2i(1, 4), Vector2i(1, 4),
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(1, 4),
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(1, 5), Vector2i(2, 1)
]

## 11-State mapped coordinates for the Bottom-Right quadrant of a Compact autotile
const COMPACT_BR_STATES: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(2, 4), Vector2i(2, 4), Vector2i(3, 4),
	Vector2i(2, 4), Vector2i(2, 4), Vector2i(3, 4),
	Vector2i(2, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(3, 1)
]

#endregion



#region CONSTANTS_WALLS

## Native 16-State mapped coordinates for the Top-Left quadrant of a 2x2 autotile
const WALL_TL_STATES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]

## Native 16-State mapped coordinates for the Top-Right quadrant of a 2x2 autotile
const WALL_TR_STATES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 0), Vector2i(1, 0), Vector2i(3, 2), Vector2i(1, 2)]

## Native 16-State mapped coordinates for the Bottom-Left quadrant of a 2x2 autotile
const WALL_BL_STATES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 3), Vector2i(2, 3), Vector2i(0, 1), Vector2i(2, 1)]

## Native 16-State mapped coordinates for the Bottom-Right quadrant of a 2x2 autotile
const WALL_BR_STATES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 3), Vector2i(1, 3), Vector2i(3, 1), Vector2i(1, 1)]

#endregion



#region EXTRACTION_FUNCTIONS

## Generates an image with 47 extracted tiles from an extended format autotile and extracts the alt center
func extract_extended_autotile(source_texture: Texture2D) -> Image:
	var source_image: Image = source_texture.get_image()
	var tile_size: int = source_image.get_width() / 3
	var sub_tile_size: int = tile_size / 2
	var final_width: int = tile_size * 8
	var final_height: int = tile_size * 6
	var final_image: Image = Image.create(final_width, final_height, false, source_image.get_format())
	var unique_hashes: Array[String] = []
	var current_tile_index: int = 0
	
	for mask in 256:
		var tl: int = _get_tl_state_47(mask)
		var tr: int = _get_tr_state_47(mask)
		var bl: int = _get_bl_state_47(mask)
		var br: int = _get_br_state_47(mask)
		var tile_hash: String = str(tl) + str(tr) + str(bl) + str(br)
		
		if not unique_hashes.has(tile_hash):
			unique_hashes.append(tile_hash)
			_blit_tile_to_image(source_image, final_image, current_tile_index, tl, tr, bl, br, tile_size, sub_tile_size, EXTENDED_TL_STATES, EXTENDED_TR_STATES, EXTENDED_BL_STATES, EXTENDED_BR_STATES, 8)
			current_tile_index += 1
			
	if not _is_image_rect_empty(source_image, Rect2i(tile_size, 0, tile_size, tile_size)):
		final_image.blit_rect(source_image, Rect2i(tile_size, 0, tile_size, tile_size), Vector2i(7 * tile_size, 5 * tile_size))
		
	return final_image



## Generates an image with 47 extracted tiles from a compact format autotile.
func extract_compact_autotile(source_texture: Texture2D) -> Image:
	var source_image: Image = source_texture.get_image()
	var tile_size: int = source_image.get_width() / 2
	var sub_tile_size: int = tile_size / 2
	var final_width: int = tile_size * 8
	var final_height: int = tile_size * 6
	var final_image: Image = Image.create(final_width, final_height, false, source_image.get_format())
	var unique_hashes: Array[String] = []
	var current_tile_index: int = 0
	
	for mask in 256:
		var tl: int = _get_tl_state_47(mask)
		var tr: int = _get_tr_state_47(mask)
		var bl: int = _get_bl_state_47(mask)
		var br: int = _get_br_state_47(mask)
		var tile_hash: String = str(tl) + str(tr) + str(bl) + str(br)
		
		if not unique_hashes.has(tile_hash):
			unique_hashes.append(tile_hash)
			_blit_tile_to_image(source_image, final_image, current_tile_index, tl, tr, bl, br, tile_size, sub_tile_size, COMPACT_TL_STATES, COMPACT_TR_STATES, COMPACT_BL_STATES, COMPACT_BR_STATES, 8)
			current_tile_index += 1
			
	return final_image



## Generates an image with 16 extracted tiles from a standard wall autotile.
func extract_wall_autotile(source_texture: Texture2D) -> Image:
	var source_image: Image = source_texture.get_image()
	var tile_size: int = source_image.get_width() / 2
	var sub_tile_size: int = tile_size / 2
	var final_width: int = tile_size * 4
	var final_height: int = tile_size * 4
	var final_image: Image = Image.create(final_width, final_height, false, source_image.get_format())
	var current_tile_index: int = 0
	
	for mask in 16:
		var tl: int = _get_tl_state_16(mask)
		var tr: int = _get_tr_state_16(mask)
		var bl: int = _get_bl_state_16(mask)
		var br: int = _get_br_state_16(mask)
		
		_blit_tile_to_image(source_image, final_image, current_tile_index, tl, tr, bl, br, tile_size, sub_tile_size, WALL_TL_STATES, WALL_TR_STATES, WALL_BL_STATES, WALL_BR_STATES, 4)
		current_tile_index += 1
		
	return final_image

#endregion



#region LOGIC_47_TILES

## Smart contextual evaluator for Top-Left quadrant maintaining contiguous edge artifacts
func _get_tl_state_47(mask: int) -> int:
	var n: bool = (mask & 1) != 0
	var e: bool = (mask & 4) != 0
	var s: bool = (mask & 16) != 0
	var w: bool = (mask & 64) != 0
	var nw: bool = (mask & 128) != 0
	
	if not n and not s and not w and not e:
		return 0
		
	if n and w and not nw:
		return 10
		
	var col: int = 0
	if not w and e: col = 0
	elif w and e: col = 1
	elif w and not e: col = 2
	else: col = 0
	
	var row: int = 0
	if not n and s: row = 0
	elif n and s: row = 1
	elif n and not s: row = 2
	else: row = 0
	
	return row * 3 + col + 1



## Smart contextual evaluator for Top-Right quadrant maintaining contiguous edge artifacts
func _get_tr_state_47(mask: int) -> int:
	var n: bool = (mask & 1) != 0
	var e: bool = (mask & 4) != 0
	var s: bool = (mask & 16) != 0
	var w: bool = (mask & 64) != 0
	var ne: bool = (mask & 2) != 0
	
	if not n and not s and not w and not e:
		return 0
		
	if n and e and not ne:
		return 10
		
	var col: int = 0
	if not w and e: col = 0
	elif w and e: col = 1
	elif w and not e: col = 2
	else: col = 2
	
	var row: int = 0
	if not n and s: row = 0
	elif n and s: row = 1
	elif n and not s: row = 2
	else: row = 0
	
	return row * 3 + col + 1



## Smart contextual evaluator for Bottom-Left quadrant maintaining contiguous edge artifacts
func _get_bl_state_47(mask: int) -> int:
	var n: bool = (mask & 1) != 0
	var e: bool = (mask & 4) != 0
	var s: bool = (mask & 16) != 0
	var w: bool = (mask & 64) != 0
	var sw: bool = (mask & 32) != 0
	
	if not n and not s and not w and not e:
		return 0
		
	if s and w and not sw:
		return 10
		
	var col: int = 0
	if not w and e: col = 0
	elif w and e: col = 1
	elif w and not e: col = 2
	else: col = 0
	
	var row: int = 0
	if not n and s: row = 0
	elif n and s: row = 1
	elif n and not s: row = 2
	else: row = 2
	
	return row * 3 + col + 1



## Smart contextual evaluator for Bottom-Right quadrant maintaining contiguous edge artifacts
func _get_br_state_47(mask: int) -> int:
	var n: bool = (mask & 1) != 0
	var e: bool = (mask & 4) != 0
	var s: bool = (mask & 16) != 0
	var w: bool = (mask & 64) != 0
	var se: bool = (mask & 8) != 0
	
	if not n and not s and not w and not e:
		return 0
		
	if s and e and not se:
		return 10
		
	var col: int = 0
	if not w and e: col = 0
	elif w and e: col = 1
	elif w and not e: col = 2
	else: col = 2
	
	var row: int = 0
	if not n and s: row = 0
	elif n and s: row = 1
	elif n and not s: row = 2
	else: row = 2
	
	return row * 3 + col + 1

#endregion



#region LOGIC_16_TILES

## Evaluates the 4-bit mask for Walls Top-Left.
func _get_tl_state_16(mask: int) -> int:
	var n: bool = (mask & 1) != 0
	var w: bool = (mask & 8) != 0
	
	if n and w:
		return 4
		
	if n:
		return 3
		
	if w:
		return 2
		
	return 1



## Evaluates the 4-bit mask for Walls Top-Right.
func _get_tr_state_16(mask: int) -> int:
	var n: bool = (mask & 1) != 0
	var e: bool = (mask & 2) != 0
	
	if n and e:
		return 4
		
	if n:
		return 3
		
	if e:
		return 2
		
	return 1



## Evaluates the 4-bit mask for Walls Bottom-Left.
func _get_bl_state_16(mask: int) -> int:
	var s: bool = (mask & 4) != 0
	var w: bool = (mask & 8) != 0
	
	if s and w:
		return 4
		
	if s:
		return 3
		
	if w:
		return 2
		
	return 1



## Evaluates the 4-bit mask for Walls Bottom-Right.
func _get_br_state_16(mask: int) -> int:
	var s: bool = (mask & 4) != 0
	var e: bool = (mask & 2) != 0
	
	if s and e:
		return 4
		
	if s:
		return 3
		
	if e:
		return 2
		
	return 1

#endregion



#region DRAWING

## Blits the 4 mapped quadrants dynamically using the provided topological arrays and column limit.
func _blit_tile_to_image(source: Image, dest: Image, index: int, tl: int, tr: int, bl: int, br: int, tile_size: int, sub_tile_size: int, tl_states: Array[Vector2i], tr_states: Array[Vector2i], bl_states: Array[Vector2i], br_states: Array[Vector2i], columns: int) -> void:
	var dest_x: int = (index % columns) * tile_size
	var dest_y: int = (index / columns) * tile_size
	
	var tl_rect: Rect2i = Rect2i(tl_states[tl] * sub_tile_size, Vector2i(sub_tile_size, sub_tile_size))
	dest.blit_rect(source, tl_rect, Vector2i(dest_x, dest_y))
	
	var tr_rect: Rect2i = Rect2i(tr_states[tr] * sub_tile_size, Vector2i(sub_tile_size, sub_tile_size))
	dest.blit_rect(source, tr_rect, Vector2i(dest_x + sub_tile_size, dest_y))
	
	var bl_rect: Rect2i = Rect2i(bl_states[bl] * sub_tile_size, Vector2i(sub_tile_size, sub_tile_size))
	dest.blit_rect(source, bl_rect, Vector2i(dest_x, dest_y + sub_tile_size))
	
	var br_rect: Rect2i = Rect2i(br_states[br] * sub_tile_size, Vector2i(sub_tile_size, sub_tile_size))
	dest.blit_rect(source, br_rect, Vector2i(dest_x + sub_tile_size, dest_y + sub_tile_size))



## Evaluates if a given image region contains exclusively fully transparent pixels
func _is_image_rect_empty(img: Image, rect: Rect2i) -> bool:
	if not img or img.is_empty():
		return true
		
	var max_x: int = mini(img.get_width(), rect.position.x + rect.size.x)
	var max_y: int = mini(img.get_height(), rect.position.y + rect.size.y)
	
	for x in range(rect.position.x, max_x):
		for y in range(rect.position.y, max_y):
			if img.get_pixel(x, y).a > 0.0:
				return false
				
	return true

#endregion
