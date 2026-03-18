class_name IngameExtractionEvent
extends RefCounted


var map: RPGMap
var event: RPGExtractionItem
var scene: Variant
var extraction_event: GameExtractionItem


func _init(p_map: RPGMap, p_event: RPGExtractionItem) -> void:
	map = p_map
	event = p_event


# Separado del _init para evitar cuelgues (deadlocks) en el árbol de nodos
func build() -> void:
	if event.drop_table.is_empty():
		return
	
	if ResourceLoader.exists(event.scene_path):
		scene = load(event.scene_path).instantiate()
		scene.data = event
	
	if scene:
		map.add_child(scene)
		scene.position = map.get_tile_position(Vector2i(event.x, event.y))
		
		var internal_id = map.internal_id
		
		if not internal_id in GameManager.game_state.extraction_items:
			GameManager.game_state.extraction_items[internal_id] = {}
			
		if not event.id in GameManager.game_state.extraction_items[internal_id]:
			GameManager.game_state.extraction_items[internal_id][event.id] = GameExtractionItem.new(event.id)
			
		extraction_event = GameManager.game_state.extraction_items[internal_id][event.id]
		
		if extraction_event.is_depleted():
			var time_elapsed = GameManager.game_state.stats.play_time - extraction_event.depleted_date
			extraction_event.current_respawn_time = max(0, extraction_event.current_respawn_time - time_elapsed)
		
		scene.extraction_data = extraction_event
		
		if extraction_event.is_depleted():
			scene.end(true)
		else:
			scene.start(true)


func is_valid() -> bool:
	return is_instance_valid(scene)


func process_extraction(delta: float) -> void:
	if not is_valid() or not extraction_event:
		return
		
	if extraction_event.is_depleted():
		extraction_event.current_respawn_time -= delta

		if extraction_event.current_respawn_time <= 0:
			extraction_event.current_respawn_time = 0
			extraction_event.current_uses = event.max_uses
			scene.start(false)
