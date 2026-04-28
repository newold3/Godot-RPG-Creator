@tool
class_name QuestIntegrityValidator
extends RefCounted


## Generates a list of warnings crossing the MapInfos cache and the Quest Database.
static func run_integrity_check(quest_db: Array) -> Array[String]:
	var warnings: Array[String] = []
	
	var map_infos: MapInfos = RPGSYSTEM.map_infos.map_infos
	
	for map_path in map_infos.map_events:
		var events = map_infos.map_events[map_path]
		var map_name = map_infos.map_names.get(map_path, "Unknown Map")
		
		for event_data in events:
			var event_name = event_data.get("name", "Unnamed")
			
			for quest_id in event_data.get("quest_ids", []):
				if not _quest_exists_in_db(quest_id, quest_db):
					var msg = "Missing Quest: Event '%s' in map '%s' gives Quest ID %d, but it was deleted from the Database." % [event_name, map_name, quest_id]
					warnings.append(msg)
					
	for quest in quest_db:
		if quest and quest.target_event and quest.target_event.event_id != -1:
			var target_uid = quest.target_event.event_id
			if not map_infos.uniq_id_exists_globally(target_uid):
				var msg = "Missing Target: Database Quest ID %d requires delivery to Event UID %d, but that event no longer exists in any map." % [quest.id, target_uid]
				warnings.append(msg)
				
	return warnings


## Helper to safely check if a quest ID exists in the provided database array.
static func _quest_exists_in_db(quest_id: int, quest_db: Array) -> bool:
	for q in quest_db:
		if q and q.id == quest_id:
			return true
			
	return false
