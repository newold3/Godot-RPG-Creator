@tool
class_name EventGraphConfigManager
extends RefCounted

## Manages persistent graph layout, node positions, containers/groups, and reminders
## in a dedicated JSON file per map (e.g. res://data/MapEvents/Map_<id>_events_graph.json).
## Keeps map scenes and event resources completely clean of editor graph metadata.

const DEFAULT_EVENTS_DIR = "res://data/MapEvents/"


## Resolves the target JSON path for the given context (event, page, parent dialog)
static func get_config_file_path(event: RPGEvent = null, page: RPGEventPage = null, context_node: Node = null) -> String:
	# 1. Try to get events resource path from parent dialog
	if context_node:
		var curr: Node = context_node
		while curr:
			if "events" in curr and curr.events is Resource and not curr.events.resource_path.is_empty():
				var base = curr.events.resource_path.get_basename()
				return base + "_graph.json"
			curr = curr.get_parent()
			
	# 2. Try to get map id from EditorInterface
	var root: Node = null
	if Engine.is_editor_hint():
		root = EditorInterface.get_edited_scene_root()
	if not root:
		var sys = Engine.get_main_loop().root.get_node_or_null("RPGSYSTEM")
		if sys and "editor_interface" in sys and sys.editor_interface:
			root = sys.editor_interface.get_edited_scene_root()
			
	if root and "internal_id" in root and str(root.internal_id) != "0" and not str(root.internal_id).is_empty():
		return DEFAULT_EVENTS_DIR + "Map_%s_events_graph.json" % str(root.internal_id)
		
	if root and not root.scene_file_path.is_empty():
		var map_name = root.scene_file_path.get_file().get_basename()
		return DEFAULT_EVENTS_DIR + "%s_events_graph.json" % map_name

	# 3. Try from event resource_path
	if event and not event.resource_path.is_empty():
		return event.resource_path.get_basename() + "_graph.json"

	# 4. Fallback
	return DEFAULT_EVENTS_DIR + "Map_default_events_graph.json"


## Loads the complete map graph configuration Dictionary from disk
static func load_map_config(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"version": 1, "events": {}}
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {"version": 1, "events": {}}
		
	var text = file.get_as_text()
	file.close()
	
	if text.strip_edges().is_empty():
		return {"version": 1, "events": {}}
		
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK or not (json.data is Dictionary):
		return {"version": 1, "events": {}}
		
	return json.data


## Saves the complete map graph configuration Dictionary to disk
static func save_map_config(file_path: String, config: Dictionary) -> bool:
	var dir_path = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		printerr("EventGraphConfigManager: Failed to write to ", file_path)
		return false
		
	var text = JSON.stringify(config, "\t")
	file.store_string(text)
	file.close()
	return true


## Retrieves page graph data (nodes, containers, reminders, scroll, zoom)
static func get_page_data(file_path: String, event_id: String, page_id: String) -> Dictionary:
	var config = load_map_config(file_path)
	var evs = config.get("events", {})
	var ev_data = evs.get(event_id, {})
	var pages = ev_data.get("pages", {})
	return pages.get(page_id, {})


## Saves page graph data (nodes, containers, reminders, scroll, zoom)
static func set_page_data(file_path: String, event_id: String, page_id: String, page_data: Dictionary) -> bool:
	var config = load_map_config(file_path)
	if not ("events" in config):
		config["events"] = {}
	if not (event_id in config["events"]):
		config["events"][event_id] = {"pages": {}}
	if not ("pages" in config["events"][event_id]):
		config["events"][event_id]["pages"] = {}
		
	config["events"][event_id]["pages"][page_id] = page_data
	return save_map_config(file_path, config)


## Removes all graph metadata from the page and command resources to keep map scenes clean
static func clean_scene_and_page_metadata(page: Resource, commands: Array[RPGEventCommand]) -> void:
	if page:
		for meta_key in ["graph_start_pos", "graph_scroll", "graph_zoom", "_graph_pos"]:
			if page.has_meta(meta_key):
				page.remove_meta(meta_key)
	for cmd in commands:
		if cmd and cmd.parameters is Dictionary:
			if "_graph_pos" in cmd.parameters:
				cmd.parameters.erase("_graph_pos")
