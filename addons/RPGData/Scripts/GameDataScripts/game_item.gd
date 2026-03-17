class_name GameItem
extends GameItemBase


@export var lifetime: float = 0
@export var is_perishable: bool = false

signal lifetime_updated(new_lifetime: float)
signal it_rotted(item: GameItem)


func update_lifetime(delta: float) -> void:
	if not is_perishable or lifetime <= 0:
		return
		
	lifetime -= delta
	lifetime_updated.emit(lifetime)
	
	if lifetime <= 0:
		it_rotted.emit(self)
