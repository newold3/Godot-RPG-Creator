class_name ModeDrunkard
extends BaseMapMode


#region INTERFACE


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "Drunkard Walk"



## Returns an array of core property names that this specific mode uses
func get_used_properties() -> Array[String]:
	return ["drunkard_steps", "drunkard_walkers"]



## Executes the core math logic to generate tunnel-like galleries using the random walker algorithm
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var drunkard_steps: int = config.get("drunkard_steps", 2500)
	var drunkard_walkers: int = config.get("drunkard_walkers", 1)
	var top_wall_height: int = config.get("top_wall_height", 3)
	
	for walker in range(drunkard_walkers):
		var cx: int = width / 2
		var cy: int = height / 2
		
		for step in range(drunkard_steps):
			grid[cy * width + cx] = 1
			var dir: int = randi() % 4
			
			match dir:
				0: cy -= 1
				1: cy += 1
				2: cx -= 1
				3: cx += 1
				
			cx = clampi(cx, 2, width - 3)
			cy = clampi(cy, 2 + top_wall_height, height - 3)
			
	return []
#endregion
