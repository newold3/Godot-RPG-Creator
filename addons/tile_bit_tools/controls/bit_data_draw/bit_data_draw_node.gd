@tool
extends SubViewport

const DEFAULT_TILE_SIZE := 16

const BitData := preload("res://addons/tile_bit_tools/core/bit_data.gd")

var drawing_size := Vector2i.ZERO
var tile_size := 0
var tile_spacing := 0

@onready var bit_data_draw: Control = %BitDataDraw


func get_bit_texture(bit_data : BitData) -> Texture2D:
	var tex_size := get_drawing_size(bit_data)
	size = tex_size
	bit_data_draw.draw_size = tex_size
	bit_data_draw.spacing = tile_spacing
	bit_data_draw.bit_data = bit_data
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := get_texture().get_image()
	return ImageTexture.create_from_image(image)


func get_drawing_size(bit_data : BitData) -> Vector2i:
	if drawing_size != Vector2i.ZERO:
		return drawing_size
	var calc_tile_size : int = tile_size if tile_size > 0 else DEFAULT_TILE_SIZE
	return bit_data.get_atlas_rect().size * calc_tile_size
