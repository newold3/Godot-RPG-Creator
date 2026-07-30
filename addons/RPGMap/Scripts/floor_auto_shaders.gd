extends TileMapLayer


var material_map: Dictionary = {
	"water": preload("uid://us28d63nntdh"),
	"💧": preload("uid://us28d63nntdh"),
	"lava": "res://shaders/lava_material.tres",
	"🔥": "res://shaders/lava_material.tres",
	"wind": preload("uid://bulxm6s15hff0")
}


var materials: Dictionary = {}


func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	var data := get_cell_tile_data(coords)
	if data:
		var mat_id = data.get_custom_data("MaterialId")
		return mat_id != "" and material_map.has(mat_id)

	return false


func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	var mat_id = tile_data.get_custom_data("MaterialId")
	if material_map.has(mat_id):
		tile_data.material = material_map[mat_id]
