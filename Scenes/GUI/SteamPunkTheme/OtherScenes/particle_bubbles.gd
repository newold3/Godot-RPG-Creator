extends Control

func _ready() -> void:
	item_rect_changed.connect(_update_particles)
	_update_particles()


func _update_particles() -> void:
	var node = %Particles
	
	var mid = size * 0.5
	node.position = mid
	
	node.process_material.set("emission_box_extents", Vector3(mid.x, mid.y, 1.0))
