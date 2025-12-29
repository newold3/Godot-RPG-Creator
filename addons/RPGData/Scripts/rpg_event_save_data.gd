@tool
class_name RPGEventSaveData
extends Resource

## ID real del evento (RPGEvent.id).
@export var event_id: int = -1

## Posición en coordenadas de celda (Tile Position) del evento.
@export var position: Vector2i = Vector2i.ZERO

## Dirección actual del evento (Enum LPCCharacter.DIRECTIONS).
@export var direction: int = 0

## ID de la página de evento (RPGEventPage.page_id) que está activa actualmente.
@export var active_page_id: int = 1


func clone(value: bool = true) -> RPGEventSaveData:
	return duplicate(value)


func _to_string() -> String:
	return "<RPGEventSaveData event_id=%s, position=%s, direction=%s, active_page_id=%s" % [
		event_id,
		position,
		direction,
		active_page_id
	]
