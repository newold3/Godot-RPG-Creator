@tool
class_name MapGenerator
extends Node

#region SIGNALS
## Emitted when the math thread begins
signal generation_started

## Emitted when the painting is completely done
signal generation_finished
#endregion

#region ENUMS
enum TargetLayerMode { ALL, BASE, WALLS, DETAIL, ENVIRONMENT }
#endregion

#region EXPORTS
@export_group("Map Layers")
## Target TileMapLayer for water (World Map) or base floor (Rooms/Labyrinth)
@export var layer_ground_base: TileMapLayer:
	set(value):
		layer_ground_base = value
		if Engine.is_editor_hint(): 
			notify_property_list_changed()
			update_configuration_warnings()

## Target TileMapLayer exclusively for walls to allow Y-Sorting with the player
@export var layer_walls: TileMapLayer:
	set(value):
		layer_walls = value
		if Engine.is_editor_hint(): 
			notify_property_list_changed()
			update_configuration_warnings()

## Target TileMapLayer for top-level ground like continents (World Map)
@export var layer_ground_detail: TileMapLayer:
	set(value):
		layer_ground_detail = value
		if Engine.is_editor_hint(): 
			notify_property_list_changed()
			update_configuration_warnings()

## Target TileMapLayer for wall shadows (placed between floor and walls)
@export var layer_shadows: TileMapLayer:
	set(value):
		layer_shadows = value
		if Engine.is_editor_hint(): 
			notify_property_list_changed()
			update_configuration_warnings()

## Target TileMapLayer for future decorations and scattered items
@export var layer_environment: TileMapLayer:
	set(value):
		layer_environment = value
		if Engine.is_editor_hint(): 
			notify_property_list_changed()
			update_configuration_warnings()


@export_group("Core Settings")
## Array of dictionaries storing the events currently placed on the map
@export var current_map_events: Array[MapPlacedEvent] = []

## Defines which layers will be cleared and repainted during generation
@export var target_layer_mode: TargetLayerMode = TargetLayerMode.ALL:
	set(value):
		target_layer_mode = value
		if Engine.is_editor_hint(): notify_property_list_changed()

## Select the algorithm used to shape the map
@export var generation_mode: int = 0:
	set(value):
		generation_mode = value
		if Engine.is_editor_hint(): notify_property_list_changed()

## Width of the generated map in tiles
@export_range(30, 500) var map_width: int = 150

## Height of the generated map in tiles
@export_range(30, 500) var map_height: int = 150

## If true, forces the generator to use a specific seed for exact reproducibility
@export var use_fixed_seed: bool = false:
	set(value):
		use_fixed_seed = value
		if Engine.is_editor_hint(): notify_property_list_changed()

## The specific seed value used for math and noise generation
@export var map_seed: int = 0


@export_group("Common Terrains")
## If true, paints a specific single tile for the floor instead of resolving autotiles
@export var use_single_floor: bool = false

## ID of the terrain used for the floors/land
@export var terrain_floor: int = -1

## Dictionary storing the specific tile data for the floor
@export var single_floor_tile: Dictionary = {"atlas_id": -1, "tile_id": Vector2i(-1, -1)}

## If true, paints a specific single tile for the walls instead of resolving autotiles
@export var use_single_wall: bool = false

## ID of the terrain used for the walls (Hidden in World Map mode)
@export var terrain_wall: int = -1

## Dictionary storing the specific tile data for the walls
@export var single_wall_tile: Dictionary = {"atlas_id": -1, "tile_id": Vector2i(-1, -1)}

## If true, paints a specific single tile for the roofs instead of resolving autotiles
@export var use_single_roof: bool = false

## ID of the terrain used for the flat roofs of the walls (Hidden in World Map mode)
@export var terrain_roof: int = -1

## Dictionary storing the specific tile data for the roofs
@export var single_roof_tile: Dictionary = {"atlas_id": -1, "tile_id": Vector2i(-1, -1)}

## If true, generates vertical shadows to the right of walls
@export var draw_shadows: bool = false

## Dictionary storing the tile data for full height shadows
@export var large_tile_shadow: Dictionary = {"atlas_id": -1, "tile_id": Vector2i(-1, -1)}

## Dictionary storing the tile data for single-tile height shadows (Small shadows)
@export var small_tile_shadow: Dictionary = {"atlas_id": -1, "tile_id": Vector2i(-1, -1)}


@export_group("Mode Specific Settings")
## ID of the terrain used for the base land/grass of the continents
@export var terrain_land: int = -1

## ID of the terrain used for the oceans/water
@export var terrain_water: int = -1

## ID of the terrain used for snow biomes
@export var terrain_snow: int = -1

## ID of the terrain used for desert biomes
@export var terrain_desert: int = -1

## ID of the terrain used for volcanic/wasteland biomes
@export var terrain_volcano: int = -1

## ID of the terrain used for swamp biomes
@export var terrain_swamp: int = -1

## ID of the terrain used for mountains
@export var terrain_mountain: int = -1

## ID of the terrain used for trees/forests
@export var terrain_tree: int = -1

## Maximum number of different biomes to use in a single world map
@export_range(1, 5) var world_max_biomes: int = 3

## If checked, a new random noise will be generated each time
@export var use_random_noise: bool = false:
	set(value):
		use_random_noise = value
		if Engine.is_editor_hint(): notify_property_list_changed()

## Noise texture used for generating the organic world map shape
@export var world_noise: FastNoiseLite

## Minimum dimension of a room
@export var min_room_size: int = 6

## Maximum dimension of a room
@export var max_room_size: int = 14

## Desired number of rooms to attempt placing
@export var target_room_count: int = 25

## Minimum width of the connecting corridors
@export var min_corridor_width: int = 1

## Maximum width of the connecting corridors
@export var max_corridor_width: int = 2

## Thickness of the labyrinth paths in tiles
@export_range(1, 10) var labyrinth_path_thickness: int = 1

## Initial percentage of floor tiles (0-100)
@export_range(30, 60) var cave_fill_ratio: int = 48

## How many smoothing passes to apply
@export_range(1, 10) var cave_smoothing_iterations: int = 5

## Total steps to carve per walker
@export var drunkard_steps: int = 2500

## Number of walkers to spawn simultaneously
@export_range(1, 10) var drunkard_walkers: int = 1


@export_group("Perspective Settings")
## How many tiles high the top walls should be to simulate 3D perspective
@export var top_wall_height: int = 3

## How many tiles thick the roofs/top walls should expand horizontally (minimum 1)
@export_range(1, 5) var roof_thickness: int = 2


@export_group("Collision Settings")
## If true, a StaticBody2D with optimized 2D collisions will be added automatically
@export var add_collisions_after_generation: bool = false


@export_group("Debug")
## Node used to select the starting point for the debug path
@export var player: Node2D

## Node used to select the end point for the debug path
@export var goal: Node2D

## If true, the debug path will automatically recalculate when you move the markers
@export var auto_update_path: bool = true

## Color of the debug path line
@export var debug_path_color: Color = Color(1, 0, 0, 0.8) :
	set(value):
		debug_path_color = value
		if debug_path_enabled: _draw_debug_path()

## Width of the debug path line
@export var debug_path_width: float = 4.0 :
	set(value):
		debug_path_width = value
		if debug_path_enabled: _draw_debug_path()

## Internal state to persist the debug path visibility across sessions
@export var debug_path_enabled: bool = false
#endregion

#region VARIABLES
var terrain_set: int = 0
var is_generating: bool = false
var _thread: Thread
var _mutex: Mutex = Mutex.new()
var _progress: float = 0.0
var _status: String = "Idle"
var _thread_results: Dictionary = {}
const DECORATORS_PATH: String = "res://addons/RPGMapGenerator/Resources/environment_decorators.tres"
var decorator_data: Array[Dictionary] = []
var _modes: Array[BaseMapMode] = []

var _cache_floor: Dictionary = {}
var _cache_wall: Dictionary = {}
var _cache_roof: Dictionary = {}
var _cache_water: Dictionary = {}
var _cache_snow: Dictionary = {}
var _cache_desert: Dictionary = {}
var _cache_volcano: Dictionary = {}
var _cache_swamp: Dictionary = {}
var _cache_mountain: Dictionary = {}
var _cache_tree: Dictionary = {}

var _last_start_pos: Vector2 = Vector2.ZERO
var _last_end_pos: Vector2 = Vector2.ZERO
var _path_update_timer: float = 0.0
var _needs_path_update: bool = false

const EVENTS_LIBRARY_PATH: String = "res://addons/RPGMapGenerator/Resources/random_events_library.tres"
var events_library: MapGeneratorEvents

# Helper Classes
var terrain_processor: MapTerrainProcessor
var environment_placer: MapEnvironmentPlacer
var event_placer: MapEventPlacer
var scene_exporter: MapSceneExporter
#endregion

#region INIT & SETUP
## Initializes the generator, its helpers, and loads all modular modes
func _init() -> void:
	terrain_processor = MapTerrainProcessor.new(self)
	environment_placer = MapEnvironmentPlacer.new(self)
	event_placer = MapEventPlacer.new(self)
	scene_exporter = MapSceneExporter.new(self)
	
	_load_modes()
	_load_events_library()


## Loads the events library from disk or creates a fresh instance if it does not exist
func _load_events_library() -> void:
	if ResourceLoader.exists(EVENTS_LIBRARY_PATH):
		events_library = ResourceLoader.load(EVENTS_LIBRARY_PATH)
	else:
		events_library = MapGeneratorEvents.new()


## Enables processing in the editor to monitor the background thread
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_process(true)


func _ready() -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		_clear_debug_path()
	else:
		_load_events_library()
		_load_decorators()
		
		var event_canvas = get_node_or_null("%EventCanvas")
		if event_canvas and event_canvas.has_method("setup"):
			event_canvas.setup(self)


## Loads the decorators configuration from disk or creates an empty array
func _load_decorators() -> void:
	if ResourceLoader.exists(DECORATORS_PATH):
		var res: Resource = ResourceLoader.load(DECORATORS_PATH)
		if res is EnvironmentDecoratorsData:
			decorator_data = res.decorators.duplicate(true)
	else:
		decorator_data = []


## Persists the decorators configuration to disk in JSON format for easy reading
func save_decorators() -> void:
	var dir = DECORATORS_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		
	var res: EnvironmentDecoratorsData = EnvironmentDecoratorsData.new()
	res.decorators = decorator_data.duplicate(true)
	
	ResourceSaver.save(res, DECORATORS_PATH)
	
	EditorInterface.get_resource_filesystem().scan()


## Monitors the background thread and tracks marker movements for auto-pathfinding
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
		
	if is_generating and _thread != null:
		if not _thread.is_alive() and _thread.is_started():
			_thread_results = _thread.wait_to_finish()
			_thread = null
			_apply_generation_results()
			
	if (auto_update_path or debug_path_enabled) and not is_generating and not _is_world_mode():
		if player and goal:
			var s_pos: Vector2 = player.global_position
			var e_pos: Vector2 = goal.global_position
			
			if s_pos != _last_start_pos or e_pos != _last_end_pos:
				_last_start_pos = s_pos
				_last_end_pos = e_pos
				_needs_path_update = true
				_path_update_timer = 0.2
				
		if _needs_path_update:
			_path_update_timer -= delta
			
			if _path_update_timer <= 0.0:
				_needs_path_update = false
				
				if layer_ground_base and layer_ground_base.get_node_or_null("DebugPath"):
					_draw_debug_path()
				elif debug_path_enabled:
					_draw_debug_path()
#endregion

#region EDITOR UI LOGIC
## Scans the assigned TileMapLayers and issues a warning if their tile sizes are mismatched
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var sizes: Array[Vector2i] = []
	var layers: Array[TileMapLayer] = [layer_ground_base, layer_walls, layer_ground_detail, layer_shadows, layer_environment]
	
	for l in layers:
		if l and l.tile_set:
			var ts: Vector2i = l.tile_set.tile_size
			if not sizes.has(ts):
				sizes.append(ts)
				
	if sizes.size() > 1:
		warnings.append("Tile size mismatch! RPGMap requires all layers to use the same tile_size. Currently found sizes: " + str(sizes))
		
	return warnings


## Helper function to strictly identify if the currently selected mode is a World Map
func _is_world_mode() -> bool:
	if _modes.size() > generation_mode:
		return _modes[generation_mode] is ModeWorldMap
	return false


## Dynamically hides or shows exports based on the selected modular algorithm
func _validate_property(property: Dictionary) -> void:
	var floating_ui_props: Array[String] = [
		"generation_mode", "map_width", "map_height", 
		"add_collisions_after_generation", "target_layer_mode", 
		"debug_path_enabled", "current_map_events",
		"use_fixed_seed", "map_seed"
	]
	
	if property.name in floating_ui_props:
		property.usage &= ~PROPERTY_USAGE_EDITOR
		return
		
	if _modes.size() > generation_mode:
		var active_mode: BaseMapMode = _modes[generation_mode]
		var used_props: Array[String] = active_mode.get_used_properties()
		
		var specific_props: Array[String] = [
			"terrain_land", "terrain_water", "terrain_snow", "terrain_desert", 
			"terrain_volcano", "terrain_swamp", "terrain_mountain", "terrain_tree",
			"world_max_biomes", "use_random_noise", "world_noise", "min_room_size", 
			"max_room_size", "target_room_count", "min_corridor_width", "max_corridor_width",
			"labyrinth_path_thickness", "cave_fill_ratio", "cave_smoothing_iterations",
			"drunkard_steps", "drunkard_walkers"
		]
		
		if property.name in specific_props and not property.name in used_props:
			property.usage &= ~PROPERTY_USAGE_EDITOR
			
	if _is_world_mode():
		var hide_for_world: Array[String] = [
			"terrain_floor", "use_single_floor", "single_floor_tile",
			"use_single_wall", "terrain_wall", "single_wall_tile",
			"use_single_roof", "terrain_roof", "single_roof_tile",
			"top_wall_height", "roof_thickness", "add_collisions_after_generation",
			"layer_shadows", "draw_shadows", "large_tile_shadow", "small_tile_shadow"
		]
		
		if property.name in hide_for_world:
			property.usage &= ~PROPERTY_USAGE_EDITOR


## Scans the project folder and instantiates scripts inheriting from BaseMapMode
func _load_modes() -> void:
	_modes.clear()
	var path: String = "res://addons/RPGMapGenerator/Modes/"
	var dir: DirAccess = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".gd") and file_name != "base_map_mode.gd":
				var script: Script = load(path + file_name)
				if script:
					var inst: Object = script.new()
					if inst is BaseMapMode:
						_modes.append(inst)
			file_name = dir.get_next()
			
	_modes.sort_custom(func(a, b): return a.get_mode_name() < b.get_mode_name())


## Returns the dynamically formatted name of a mode including its zero-padded ID
func get_formatted_mode_name(index: int) -> String:
	if index < 0 or index >= _modes.size():
		return "Unknown"
	var pad_length: int = str(_modes.size()).length()
	var id_str: String = str(index + 1).pad_zeros(pad_length)
	return id_str + " - " + _modes[index].get_mode_name()


## Returns a list of formatted display names for all loaded modular generation modes
func get_mode_names() -> Array[String]:
	var names: Array[String] = []
	for i in range(_modes.size()):
		names.append(get_formatted_mode_name(i))
	return names


## Safely updates the generation progress variables using a Mutex
func _set_progress(value: float, text: String) -> void:
	_mutex.lock()
	_progress = value
	_status = text
	_mutex.unlock()


## Safely reads the current generation progress and status for the UI
func get_progress_data() -> Dictionary:
	_mutex.lock()
	var p: float = _progress
	var s: String = _status
	_mutex.unlock()
	return {"progress": p, "status": s}
#endregion

#region GRID & LAYER MANAGEMENT
## Purges all nodes completely, disregarding layer selection mode
func clear_all_maps() -> void:
	if layer_ground_base:
		layer_ground_base.clear()
		for child in layer_ground_base.get_children():
			if child is Line2D or child is Label:
				child.free()
				
	if layer_walls:
		layer_walls.clear()
		for child in layer_walls.get_children():
			if child is StaticBody2D:
				child.free()
				
	if layer_ground_detail:
		layer_ground_detail.clear()
		
	if layer_shadows:
		layer_shadows.clear()
		
	if layer_environment:
		layer_environment.clear()
		
	current_map_events.clear()
	
	if event_placer:
		event_placer._update_event_canvas()


## Selective clearing of layers ensuring non-targeted layers remain untouched
func _clear_all_layers() -> void:
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.BASE:
		if layer_ground_base:
			layer_ground_base.clear()
			for child in layer_ground_base.get_children():
				if child is Line2D or child is Label:
					child.free()
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.WALLS:
		if layer_walls:
			layer_walls.clear()
			for child in layer_walls.get_children():
				if child is StaticBody2D:
					child.free()
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.DETAIL:
		if layer_ground_detail:
			layer_ground_detail.clear()
		if layer_shadows:
			layer_shadows.clear()
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.ENVIRONMENT:
		if layer_environment:
			layer_environment.clear()
	if target_layer_mode == TargetLayerMode.ALL:
		current_map_events.clear()


## Scans the scene to pre-populate the grid with existing layer data
func _read_initial_grid() -> Dictionary:
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(map_width * map_height)
	grid.fill(0)
	
	# Mapa auxiliar para que el hilo sepa dónde hay decoraciones sin tocar nodos
	var env_grid: PackedByteArray = PackedByteArray()
	env_grid.resize(map_width * map_height)
	env_grid.fill(0)
	
	var has_f: bool = false
	var has_w: bool = false
	var f_cells: Array[Vector2i] = []
	var w_cells: Array[Vector2i] = []
	var is_world: bool = _is_world_mode()
	
	if layer_ground_base:
		for cell in layer_ground_base.get_used_cells():
			if cell.x >= 0 and cell.x < map_width and cell.y >= 0 and cell.y < map_height:
				var tile_data: TileData = layer_ground_base.get_cell_tile_data(cell)
				if is_world and tile_data and tile_data.terrain == terrain_water:
					grid[cell.y * map_width + cell.x] = 3
				else:
					grid[cell.y * map_width + cell.x] = 1
					f_cells.append(cell)
					has_f = true
					
	if layer_walls:
		for cell in layer_walls.get_used_cells():
			if cell.x >= 0 and cell.x < map_width and cell.y >= 0 and cell.y < map_height:
				grid[cell.y * map_width + cell.x] = 2 # Simplificado para el hilo
				w_cells.append(cell)
				has_w = true

	if layer_environment:
		for cell in layer_environment.get_used_cells():
			if cell.x >= 0 and cell.x < map_width and cell.y >= 0 and cell.y < map_height:
				env_grid[cell.y * map_width + cell.x] = 1

	return {
		"grid": grid, 
		"env_grid": env_grid, 
		"has_floor": has_f, 
		"has_walls": has_w, 
		"floor_cells": f_cells, 
		"wall_cells": w_cells
	}
#endregion

#region GENERATION LOGIC
## Initiates the background thread for heavy math logic evaluating the context first
func _start_generation_thread() -> void:
	if not use_fixed_seed:
		randomize()
		map_seed = randi()
		
	seed(map_seed)
	
	var is_world: bool = _is_world_mode()
	
	if use_random_noise:
		if not world_noise: world_noise = FastNoiseLite.new()
		world_noise.seed = map_seed
		
	if not layer_ground_base: return
	if not is_world and terrain_floor == -1 and not use_single_floor: return
	
	var init_data: Dictionary = _read_initial_grid()
	
	init_data["map_seed"] = map_seed
	init_data["events"] = current_map_events.duplicate(true)
	
	if has_meta("preset_events_data"):
		init_data["preset_events"] = get_meta("preset_events_data")
		init_data["used_preset"] = true
		
	is_generating = true
	_set_progress(0.0, "Cleaning...")
	_clear_all_layers()
	_set_progress(5.0, "Caching...")
	
	if is_world:
		_cache_water = terrain_processor.build_terrain_cache(layer_ground_base, terrain_water)
		_cache_floor = terrain_processor.build_terrain_cache(layer_ground_detail, terrain_land)
		_cache_snow = terrain_processor.build_terrain_cache(layer_ground_detail, terrain_snow)
		_cache_desert = terrain_processor.build_terrain_cache(layer_ground_detail, terrain_desert)
		_cache_volcano = terrain_processor.build_terrain_cache(layer_ground_detail, terrain_volcano)
		_cache_swamp = terrain_processor.build_terrain_cache(layer_ground_detail, terrain_swamp)
		_cache_mountain = terrain_processor.build_terrain_cache(layer_ground_detail, terrain_mountain)
		_cache_tree = terrain_processor.build_terrain_cache(layer_ground_detail, terrain_tree)
	else:
		var f_terrain: int = terrain_floor
		if use_single_floor and layer_ground_base.tile_set:
			for tid in range(layer_ground_base.tile_set.get_terrains_count(0)):
				if layer_ground_base.tile_set.get_terrain_name(0, tid) == "Grass 1":
					f_terrain = tid
					break
		_cache_floor = terrain_processor.build_terrain_cache(layer_ground_base, f_terrain)
		
		if use_single_wall:
			_cache_wall = {}
		elif terrain_wall != -1:
			_cache_wall = terrain_processor.build_terrain_cache(layer_walls, terrain_wall)
			
		if use_single_roof:
			_cache_roof = {}
		elif terrain_roof != -1:
			_cache_roof = terrain_processor.build_terrain_cache(layer_walls, terrain_roof)
			
	_thread = Thread.new()
	_thread.start(_thread_math_task.bind(init_data))
	generation_started.emit()


## Builds a dictionary containing all exported variables to pass to the active mode
func _build_config_dict() -> Dictionary:
	return {
		"min_room_size": min_room_size, "max_room_size": max_room_size,
		"target_room_count": target_room_count, "min_corridor_width": min_corridor_width,
		"max_corridor_width": max_corridor_width, "labyrinth_path_thickness": labyrinth_path_thickness,
		"cave_fill_ratio": cave_fill_ratio, "cave_smoothing_iterations": cave_smoothing_iterations,
		"drunkard_steps": drunkard_steps, "drunkard_walkers": drunkard_walkers,
		"world_noise": world_noise, "use_random_noise": use_random_noise,
		"top_wall_height": top_wall_height, "roof_thickness": roof_thickness,
		"terrain_land": terrain_land, "terrain_water": terrain_water,
		"terrain_snow": terrain_snow, "terrain_desert": terrain_desert,
		"terrain_volcano": terrain_volcano, "terrain_swamp": terrain_swamp,
		"terrain_mountain": terrain_mountain, "terrain_tree": terrain_tree,
		"world_max_biomes": world_max_biomes
	}


## Performs a flood fill to find the interior space of existing walls and fill it with floors
func _derive_floor_from_walls(grid: PackedByteArray) -> void:
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(map_width * map_height)
	visited.fill(0)
	var stack: Array[Vector2i] = []
	
	for x in range(map_width):
		if grid[x] != 2: stack.append(Vector2i(x, 0))
		if grid[(map_height - 1) * map_width + x] != 2: stack.append(Vector2i(x, map_height - 1))
			
	for y in range(map_height):
		if grid[y * map_width] != 2: stack.append(Vector2i(0, y))
		if grid[y * map_width + map_width - 1] != 2: stack.append(Vector2i(map_width - 1, y))
			
	while stack.size() > 0:
		var curr: Vector2i = stack.pop_back()
		var idx: int = curr.y * map_width + curr.x
		if visited[idx] == 1: continue
		visited[idx] = 1
		
		if curr.y > 0 and grid[idx - map_width] != 2 and visited[idx - map_width] == 0:
			stack.append(Vector2i(curr.x, curr.y - 1))
		if curr.y < map_height - 1 and grid[idx + map_width] != 2 and visited[idx + map_width] == 0:
			stack.append(Vector2i(curr.x, curr.y + 1))
		if curr.x > 0 and grid[idx - 1] != 2 and visited[idx - 1] == 0:
			stack.append(Vector2i(curr.x - 1, curr.y))
		if curr.x < map_width - 1 and grid[idx + 1] != 2 and visited[idx + 1] == 0:
			stack.append(Vector2i(curr.x + 1, curr.y))
			
	for i in range(grid.size()):
		if visited[i] == 0 and grid[i] != 2:
			grid[i] = 1


## Executes all procedural generation purely in the background evaluating context rules
func _thread_math_task(data: Dictionary) -> Dictionary:
	seed(data.get("map_seed", 0))
	
	var grid: PackedByteArray = data["grid"]
	var env_grid: PackedByteArray = data.get("env_grid", PackedByteArray())
	var has_floor: bool = data["has_floor"]
	var has_walls: bool = data["has_walls"]
	var floor_cells: Array[Vector2i] = data.get("floor_cells", [])
	var wall_cells: Array[Vector2i] = data.get("wall_cells", [])
	var backed_up_events: Array = data.get("events", [])
	var needs_new_shape: bool = false
	var debug_start: Vector2i = Vector2i(-1, -1)
	var debug_end: Vector2i = Vector2i(-1, -1)
	var is_world: bool = _is_world_mode()
	
	if target_layer_mode == TargetLayerMode.ALL:
		needs_new_shape = true
	elif target_layer_mode == TargetLayerMode.BASE and not has_walls:
		needs_new_shape = true
	elif target_layer_mode == TargetLayerMode.WALLS and not has_floor:
		needs_new_shape = true
	elif target_layer_mode == TargetLayerMode.DETAIL and not has_floor:
		needs_new_shape = true
		
	if needs_new_shape:
		if is_world:
			grid.fill(3)
		else:
			grid.fill(0)
			
		var active_mode: BaseMapMode = _modes[generation_mode]
		_set_progress(10.0, "Carving: " + get_formatted_mode_name(generation_mode))
		var config: Dictionary = _build_config_dict()
		var rooms: Array[Rect2i] = active_mode.generate(grid, map_width, map_height, config)
		
		if not rooms.is_empty():
			debug_start = rooms[0].get_center()
			debug_end = rooms.back().get_center()
			
		if not is_world:
			var offset: Vector2i = _align_layout_to_top_left(grid)
			if debug_start != Vector2i(-1, -1):
				debug_start -= offset
				debug_end -= offset
			_remove_impossible_perspective_gaps(grid)
	else:
		if target_layer_mode == TargetLayerMode.WALLS:
			for i in range(grid.size()):
				if grid[i] == 2 or grid[i] == 9:
					grid[i] = 0
		if target_layer_mode == TargetLayerMode.BASE and has_walls:
			_derive_floor_from_walls(grid)
			
	if not is_world:
		if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.WALLS or (not needs_new_shape and target_layer_mode == TargetLayerMode.WALLS):
			_set_progress(50.0, "Walls...")
			if terrain_wall != -1 or use_single_wall:
				for y in range(map_height):
					for x in range(map_width):
						if grid[y * map_width + x] == 1:
							for dy in range(1, top_wall_height + 1):
								var ny: int = y - dy
								if ny >= 0 and grid[ny * map_width + x] == 0:
									grid[ny * map_width + x] = 2
									
			if terrain_roof != -1 or use_single_roof:
				var temp_grid: PackedByteArray = grid.duplicate()
				for iter in range(roof_thickness):
					var next_grid: PackedByteArray = temp_grid.duplicate()
					for y in range(map_height):
						for x in range(map_width):
							if temp_grid[y * map_width + x] == 0:
								var touches: bool = false
								for dy in [-1, 0, 1]:
									for dx in [-1, 0, 1]:
										var ny: int = y + dy
										var nx: int = x + dx
										if ny >= 0 and ny < map_height and nx >= 0 and nx < map_width:
											if temp_grid[ny * map_width + nx] in [1, 2, 9]:
												touches = true
												break
									if touches: break
								if touches:
									next_grid[y * map_width + x] = 9
					temp_grid = next_grid
				grid = temp_grid
				_fill_enclosed_roof_holes(grid)
				
		if debug_start == Vector2i(-1, -1):
			for y in range(map_height):
				for x in range(map_width):
					if grid[y * map_width + x] == 1:
						debug_start = Vector2i(x, y)
						break
				if debug_start != Vector2i(-1, -1): break
			for y in range(map_height - 1, -1, -1):
				for x in range(map_width - 1, -1, -1):
					if grid[y * map_width + x] == 1:
						debug_end = Vector2i(x, y)
						break
				if debug_end != Vector2i(-1, -1): break
				
	randomize()
	
	var rects: Array[Rect2i] = []
	
	if not is_world and add_collisions_after_generation:
		if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.WALLS:
			_set_progress(60.0, "Collisions...")
			rects = _calculate_greedy_meshing(grid)
			
	_set_progress(80.0, "Packaging...")
	var results: Dictionary = {"rects": rects, "debug_cells": [debug_start, debug_end]}
	
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.DETAIL:
		if is_world:
			results["floor"] = terrain_processor.package_terrain_layer(grid, [1], [1, 4, 5, 8, 10, 6, 7], _cache_floor)
			results["snow"] = terrain_processor.package_terrain_layer(grid, [4], [4, 6], _cache_snow)
			results["desert"] = terrain_processor.package_terrain_layer(grid, [5], [5, 6], _cache_desert)
			results["volcano"] = terrain_processor.package_terrain_layer(grid, [8], [8, 6], _cache_volcano)
			results["swamp"] = terrain_processor.package_terrain_layer(grid, [10], [10, 7], _cache_swamp)
			results["mountain"] = terrain_processor.package_terrain_layer(grid, [6], [6], _cache_mountain)
			results["tree"] = terrain_processor.package_terrain_layer(grid, [7], [7], _cache_tree)
		else:
			results["floor"] = terrain_processor.package_terrain_layer(grid, [1, 2, 9], [1, 2, 9], _cache_floor)
			if use_single_floor:
				results["single_floor"] = terrain_processor.package_single_tile_layer(grid, [1, 2, 9], single_floor_tile)
			if draw_shadows:
				results["shadows"] = terrain_processor.package_shadow_layer(grid)
				
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.BASE:
		if is_world:
			results["water"] = terrain_processor.package_terrain_layer(grid, [3], [3, 1, 4, 5, 8, 10, 6, 7], _cache_water)
		else:
			results["floor"] = terrain_processor.package_terrain_layer(grid, [1, 2, 9], [1, 2, 9], _cache_floor)
			
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.WALLS:
		if not is_world:
			if use_single_wall:
				results["wall"] = terrain_processor.package_single_tile_layer(grid, [2], single_wall_tile)
			elif terrain_wall != -1:
				results["wall"] = terrain_processor.package_terrain_layer(grid, [2], [2], _cache_wall)
			if use_single_roof:
				results["roof"] = terrain_processor.package_single_tile_layer(grid, [9], single_roof_tile)
			elif terrain_roof != -1:
				results["roof"] = terrain_processor.package_terrain_layer(grid, [9], [9], _cache_roof)
				
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.ENVIRONMENT:
		var floor_cells_env: Array[Vector2i] = []
		var wall_cells_env: Array[Vector2i] = []
		
		for y in range(map_height):
			for x in range(map_width):
				var c_val: int = grid[y * map_width + x]
				if is_world:
					if c_val in [1, 4, 5, 8, 10, 6, 7]: floor_cells_env.append(Vector2i(x, y))
				else:
					if c_val == 1: floor_cells_env.append(Vector2i(x, y))
					elif c_val == 2 or c_val == 9: wall_cells_env.append(Vector2i(x, y))
					
		results["environment"] = environment_placer.package_environment_layer(floor_cells_env, wall_cells_env, grid)
		
		if results.has("environment") and results["environment"].has("pos"):
			for pos in results["environment"]["pos"]:
				if pos.x >= 0 and pos.x < map_width and pos.y >= 0 and pos.y < map_height:
					env_grid[pos.y * map_width + pos.x] = 1
					
	var used_preset: bool = data.get("used_preset", false)
	var preset_events: Array = data.get("preset_events", [])
	
	if used_preset:
		if preset_events.size() > 0:
			results["events"] = event_placer.package_random_events_filtered(grid, env_grid, preset_events)
		else:
			var empty_events: Array[MapPlacedEvent] = []
			results["events"] = empty_events
	else:
		var survivor_events: Array[MapPlacedEvent] = []
		var occupied_cells: Dictionary = {}
		var available_cells: Array[Vector2i] = []
		
		for y in range(map_height):
			for x in range(map_width):
				available_cells.append(Vector2i(x, y))
				
		available_cells.shuffle()
		
		for ev in backed_up_events:
			var rules: MapGeneratorEvent = event_placer.get_wrapper_from_uid(ev.template_uid)
			if not rules: continue
			
			var is_valid: bool = event_placer.is_tile_valid_for_event_placement(ev.tile, grid, rules, env_grid)
			
			if is_valid and not occupied_cells.has(ev.tile):
				survivor_events.append(ev)
				occupied_cells[ev.tile] = true
			else:
				var found: bool = false
				
				for cell in available_cells:
					if not occupied_cells.has(cell) and event_placer.is_tile_valid_for_event_placement(cell, grid, rules, env_grid):
						ev.tile = cell
						survivor_events.append(ev)
						occupied_cells[cell] = true
						found = true
						break
						
		results["events"] = survivor_events
		
	return results


## Finds empty spaces fully enclosed by the structure using flood fill from edges and fills them with roof tiles
func _fill_enclosed_roof_holes(grid: PackedByteArray) -> void:
	var temp_grid: PackedByteArray = grid.duplicate()
	var stack: Array[Vector2i] = []
	
	for y in range(map_height):
		if temp_grid[y * map_width + 0] == 0: stack.append(Vector2i(0, y))
		if temp_grid[y * map_width + (map_width - 1)] == 0: stack.append(Vector2i(map_width - 1, y))
		
	for x in range(map_width):
		if temp_grid[0 * map_width + x] == 0: stack.append(Vector2i(x, 0))
		if temp_grid[(map_height - 1) * map_width + x] == 0: stack.append(Vector2i(x, map_height - 1))
		
	while not stack.is_empty():
		var pos: Vector2i = stack.pop_back()
		var idx: int = pos.y * map_width + pos.x
		
		if temp_grid[idx] == 0:
			temp_grid[idx] = 255 
			
			var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
			for d in dirs:
				var nx: int = pos.x + d.x
				var ny: int = pos.y + d.y
				
				if nx >= 0 and nx < map_width and ny >= 0 and ny < map_height:
					if temp_grid[ny * map_width + nx] == 0:
						stack.append(Vector2i(nx, ny))
						
	for i in range(grid.size()):
		if grid[i] == 0 and temp_grid[i] == 0:
			grid[i] = 9


## Scans the generated layout and shifts it to the top-left corner to keep it visible in the editor
func _align_layout_to_top_left(grid: PackedByteArray) -> Vector2i:
	var min_x: int = map_width
	var min_y: int = map_height
	var max_x: int = 0
	var max_y: int = 0
	var has_content: bool = false
	
	for y in range(map_height):
		for x in range(map_width):
			if grid[y * map_width + x] != 0:
				if x < min_x: min_x = x
				if y < min_y: min_y = y
				if x > max_x: max_x = x
				if y > max_y: max_y = y
				has_content = true
				
	if not has_content:
		return Vector2i.ZERO
		
	var target_x: int = 5
	var target_y: int = 5 + top_wall_height
	var offset_x: int = min_x - target_x
	var offset_y: int = min_y - target_y
	
	if max_x - offset_x >= map_width - 4:
		offset_x = max_x - (map_width - 5)
		if offset_x < 0: offset_x = 0
		
	if max_y - offset_y >= map_height - 4:
		offset_y = max_y - (map_height - 5)
		if offset_y < 0: offset_y = 0
		
	if offset_x == 0 and offset_y == 0:
		return Vector2i.ZERO
		
	var temp_grid: PackedByteArray = PackedByteArray()
	temp_grid.resize(map_width * map_height)
	temp_grid.fill(0)
	
	for y in range(map_height):
		for x in range(map_width):
			if grid[y * map_width + x] != 0:
				var new_x: int = x - offset_x
				var new_y: int = y - offset_y
				if new_x >= 0 and new_x < map_width and new_y >= 0 and new_y < map_height:
					temp_grid[new_y * map_width + new_x] = grid[y * map_width + x]
					
	for i in range(grid.size()):
		grid[i] = temp_grid[i]
		
	return Vector2i(offset_x, offset_y)


## Scans the grid for vertical gaps between floors that are too small for 3D walls and bridges them
func _remove_impossible_perspective_gaps(grid: PackedByteArray) -> void:
	var min_gap: int = top_wall_height + roof_thickness
	for x in range(map_width):
		var gap_start: int = -1
		for y in range(map_height):
			var idx: int = y * map_width + x
			if grid[idx] == 0:
				if gap_start == -1:
					gap_start = y
			elif grid[idx] == 1:
				if gap_start != -1:
					var gap_size: int = y - gap_start
					if gap_start > 0 and grid[(gap_start - 1) * map_width + x] == 1:
						if gap_size < min_gap:
							for gy in range(gap_start, y):
								grid[gy * map_width + x] = 1
				gap_start = -1


## Processes mathematical grouping of collisions sequentially
func _calculate_greedy_meshing(grid: PackedByteArray) -> Array[Rect2i]:
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(map_width * map_height)
	visited.fill(0)
	var rects: Array[Rect2i] = []
	
	for y in range(map_height):
		for x in range(map_width):
			var idx: int = y * map_width + x
			var val: int = grid[idx]
			if val == 1 or val == 0 or visited[idx] == 1: 
				continue
				
			var start_x: int = x
			var start_y: int = y
			var end_x: int = x
			var end_y: int = y
			
			while end_x + 1 < map_width:
				var next_idx: int = start_y * map_width + (end_x + 1)
				var next_val: int = grid[next_idx]
				if (next_val == 2 or next_val == 9) and visited[next_idx] == 0:
					end_x += 1
				else:
					break
					
			var can_expand: bool = true
			while can_expand:
				if end_y + 1 >= map_height: 
					break
				for tx in range(start_x, end_x + 1):
					var chk_idx: int = (end_y + 1) * map_width + tx
					var chk_val: int = grid[chk_idx]
					if (chk_val != 2 and chk_val != 9) or visited[chk_idx] == 1:
						can_expand = false
						break
				if can_expand: 
					end_y += 1
					
			for fy in range(start_y, end_y + 1):
				for fx in range(start_x, end_x + 1): 
					visited[fy * map_width + fx] = 1
					
			rects.append(Rect2i(start_x, start_y, end_x - start_x + 1, end_y - start_y + 1))
			
	return rects
#endregion

#region PAINTING & APPLYING
## Constructs collision nodes into the SceneTree
func _build_collision_nodes(rects: Array[Rect2i], tm: TileMapLayer) -> void:
	for child in tm.get_children():
		if child is StaticBody2D: 
			child.free()
			
	var sb: StaticBody2D = StaticBody2D.new()
	sb.name = "DungeonCollisions"
	sb.collision_layer = 8
	tm.add_child(sb)
	
	var root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else null
	if root: 
		sb.owner = root
		
	for r in rects:
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		var ts: Vector2 = tm.tile_set.tile_size
		rect.size = Vector2(r.size.x * ts.x, r.size.y * ts.y)
		shape.shape = rect
		shape.position = tm.map_to_local(r.position) + Vector2((r.size.x - 1) * ts.x * 0.5, (r.size.y - 1) * ts.y * 0.5)
		sb.add_child(shape)
		if root: 
			shape.owner = root


## Paints a pre-packaged layer array directly into a TileMapLayer including alternate tiles
func _paint_layer(data: Dictionary, target: TileMapLayer) -> void:
	if not target or not target.tile_set: 
		return
		
	var ts: TileSet = target.tile_set
	for i in range(data["pos"].size()):
		var src_id: int = data["src"][i]
		var coords: Vector2i = data["crd"][i]
		if ts.has_source(src_id):
			var source = ts.get_source(src_id)
			if source is TileSetAtlasSource and source.has_tile(coords):
				target.set_cell(data["pos"][i], src_id, coords, 0)


## Applies results based on selective painting mode avoiding erasing untouched layers
func _apply_generation_results() -> void:
	var is_world: bool = _is_world_mode()
	_set_progress(90.0, "Painting...")
	
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.BASE:
		if is_world:
			if layer_ground_base and _thread_results.has("water"): 
				_paint_layer(_thread_results["water"], layer_ground_base)
		else:
			if layer_ground_base and _thread_results.has("floor"): 
				_paint_layer(_thread_results["floor"], layer_ground_base)
				
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.WALLS:
		if not is_world:
			if layer_walls and _thread_results.has("roof"): 
				_paint_layer(_thread_results["roof"], layer_walls)
			if layer_walls and _thread_results.has("wall"): 
				_paint_layer(_thread_results["wall"], layer_walls)
				
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.DETAIL:
		if is_world:
			if layer_ground_detail and _thread_results.has("floor"): 
				_paint_layer(_thread_results["floor"], layer_ground_detail)
			if layer_ground_detail and _thread_results.has("snow"): 
				_paint_layer(_thread_results["snow"], layer_ground_detail)
			if layer_ground_detail and _thread_results.has("desert"): 
				_paint_layer(_thread_results["desert"], layer_ground_detail)
			if layer_ground_detail and _thread_results.has("volcano"): 
				_paint_layer(_thread_results["volcano"], layer_ground_detail)
			if layer_ground_detail and _thread_results.has("swamp"): 
				_paint_layer(_thread_results["swamp"], layer_ground_detail)
			if layer_ground_detail and _thread_results.has("mountain"): 
				_paint_layer(_thread_results["mountain"], layer_ground_detail)
			if layer_ground_detail and _thread_results.has("tree"): 
				_paint_layer(_thread_results["tree"], layer_ground_detail)
		else:
			if layer_ground_detail and _thread_results.has("single_floor"): 
				_paint_layer(_thread_results["single_floor"], layer_ground_detail)
			if layer_shadows and _thread_results.has("shadows"):
				_paint_layer(_thread_results["shadows"], layer_shadows)
				
	if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.ENVIRONMENT:
		if layer_environment and _thread_results.has("environment"):
			_paint_layer(_thread_results["environment"], layer_environment)
			
	if not is_world and add_collisions_after_generation and layer_walls:
		if target_layer_mode == TargetLayerMode.ALL or target_layer_mode == TargetLayerMode.WALLS:
			if _thread_results.has("rects"): 
				_build_collision_nodes(_thread_results["rects"], layer_walls)
				
	if not is_world and _thread_results.has("debug_cells"):
		var cells: Array = _thread_results["debug_cells"]
		if cells[0] != Vector2i(-1, -1) and player:
			player.global_position = layer_ground_base.to_global(layer_ground_base.map_to_local(cells[0]))
		if cells[1] != Vector2i(-1, -1) and goal:
			goal.global_position = layer_ground_base.to_global(layer_ground_base.map_to_local(cells[1]))
		_last_start_pos = player.global_position if player else Vector2.ZERO
		_last_end_pos = goal.global_position if goal else Vector2.ZERO
	
	if _thread_results.has("events"):
		current_map_events.assign(_thread_results["events"])
		if event_placer:
			event_placer._update_event_canvas()
		
	if debug_path_enabled:
		_draw_debug_path()
		
	_set_progress(100.0, "Done!")
	is_generating = false
	generation_finished.emit()


## Finds and draws a debug line between markers
func _draw_debug_path() -> void:
	if _is_world_mode() or not layer_ground_base or not player or not goal or not Engine.is_editor_hint(): 
		return
	if terrain_floor == -1 and not use_single_floor:
		return
		
	var sc: Vector2i = layer_ground_base.local_to_map(layer_ground_base.to_local(player.global_position))
	var ec: Vector2i = layer_ground_base.local_to_map(layer_ground_base.to_local(goal.global_position))
	
	var valid_region: Rect2i = Rect2i(0, 0, map_width, map_height)
	if not valid_region.has_point(sc) or not valid_region.has_point(ec):
		return
		
	for child in layer_ground_base.get_children():
		if child is Line2D or child is Label: 
			child.free()
			
	var astar: AStarGrid2D = AStarGrid2D.new()
	astar.region = valid_region
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	var f_terrain: int = terrain_floor
	if use_single_floor and layer_ground_base.tile_set:
		for tid in range(layer_ground_base.tile_set.get_terrains_count(0)):
			if layer_ground_base.tile_set.get_terrain_name(0, tid) == "Grass 1":
				f_terrain = tid
				break
				
	for y in range(map_height):
		for x in range(map_width):
			var d: TileData = layer_ground_base.get_cell_tile_data(Vector2i(x, y))
			if not (d and d.terrain == f_terrain): 
				astar.set_point_solid(Vector2i(x, y))
				
	if layer_walls:
		for cell in layer_walls.get_used_cells():
			if valid_region.has_point(cell):
				astar.set_point_solid(cell)
			
	if astar.is_point_solid(sc) or astar.is_point_solid(ec): 
		return
		
	var id_path: Array[Vector2i] = astar.get_id_path(sc, ec)
	if id_path.is_empty(): 
		return
		
	var local_path: PackedVector2Array = PackedVector2Array()
	for cell in id_path:
		local_path.append(layer_ground_base.map_to_local(cell))
		
	var l: Line2D = Line2D.new()
	l.name = "DebugPath"
	l.points = local_path
	l.width = debug_path_width
	l.default_color = debug_path_color
	l.z_index = 100
	
	l.add_child(_create_marker_badge("S", Color(0.2, 0.8, 0.2), Color.BLACK, local_path[0]))
	l.add_child(_create_marker_badge("E", Color(0.8, 0.2, 0.2), Color.WHITE, local_path[local_path.size() - 1]))
	layer_ground_base.add_child(l)
	
	var root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else null
	if root: 
		l.owner = root


func _clear_debug_path() -> void:
	if layer_ground_base:
		for child in layer_ground_base.get_children():
			if child is Line2D or child is Label:
				child.free()


## Creates a circular badge node with a letter
func _create_marker_badge(letter: String, bg: Color, tx: Color, pos: Vector2) -> Label:
	var lbl: Label = Label.new()
	lbl.text = letter
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", tx)
	
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(20)
	lbl.add_theme_stylebox_override("normal", s)
	lbl.custom_minimum_size = Vector2(30, 30)
	lbl.position = pos - Vector2(15, 15)
	
	return lbl


## Provides a manual fallback to generate collisions
func _force_collisions_main_thread() -> void:
	if not layer_walls or terrain_wall == -1: 
		return
		
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(map_width * map_height)
	grid.fill(0)
	
	for cell in layer_walls.get_used_cells():
		var d: TileData = layer_walls.get_cell_tile_data(cell)
		if d and d.terrain == terrain_wall: 
			grid[cell.y * map_width + cell.x] = 2
			
	_build_collision_nodes(_calculate_greedy_meshing(grid), layer_walls)
#endregion

#region EXTERNAL ACTIONS
## Persists the events library resource to the disk to ensure data is not lost on reload
func save_events_library() -> void:
	if not events_library:
		return
		
	var dir = EVENTS_LIBRARY_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		
	var err = ResourceSaver.save(events_library, EVENTS_LIBRARY_PATH)
	
	if err == OK:
		print("MapGenerator: Events library saved to " + EVENTS_LIBRARY_PATH)
		EditorInterface.get_resource_filesystem().update_file(EVENTS_LIBRARY_PATH)
	else:
		push_error("MapGenerator: Failed to save events library. Error: " + str(err))


## Open the sub-dialog box and ensures saving on close
func open_environment_decorator_dialog() -> void:
	if not layer_environment or not layer_environment.tile_set: return
		
	var path: String = "res://addons/CustomControls/Dialogs/select_tile_from_tileset_dialog.tscn"
	var dialog: Window = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	if dialog:
		dialog.set_data(layer_environment.tile_set, decorator_data)
		dialog.tree_exited.connect(save_decorators)


## External access to helpers
func export_to_rpgmap() -> void:
	scene_exporter.export_to_rpgmap()

func open_event_editor_dialog() -> void:
	event_placer.open_event_editor_dialog()

func generate_random_events() -> void:
	event_placer.generate_random_events()

func clear_all_events() -> void:
	event_placer.clear_all_events()

func request_event_deletion(index: int) -> void:
	event_placer.request_event_deletion(index)
#endregion
