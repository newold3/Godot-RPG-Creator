@tool
extends Control



const BitData := preload("res://addons/tile_bit_tools/core/bit_data.gd")

var upscale_by_max_size := {
	250 : 8,
	500 : 4,
	1000 : 2,
}



@onready var base_tiles_rect: TextureRect = %BaseTilesRect
@onready var terrain_viewport: SubViewport = %TerrainViewport
@onready var bit_data_draw: Control = %BitDataDraw
@onready var terrain_overlay_rect: TextureRect = %TerrainOverlayRect


func _ready() -> void:
	terrain_overlay_rect.texture = terrain_viewport.get_texture()


func setup_base_tiles(texture : Texture2D, base_size : Vector2i) -> void:
	base_tiles_rect.texture = texture
	var upscale_factor := _get_upscale_factor(base_size)
	terrain_viewport.size = base_size * upscale_factor
	bit_data_draw.draw_size = base_size * upscale_factor


func set_terrain_overlay_opacity(value : float) -> void:
	terrain_overlay_rect.modulate.a = value


func set_bit_data(bit_data : BitData) -> void:
	bit_data_draw.bit_data = bit_data
	terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _get_upscale_factor(base_size : Vector2i) -> int:
	for max_size in upscale_by_max_size.keys():
		if base_size.x <= max_size && base_size.y <= max_size:
			return upscale_by_max_size[max_size]
	return 1










