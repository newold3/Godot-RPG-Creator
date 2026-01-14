class_name ProjectileConfig
extends RefCounted

## Configuración de datos de proyectiles.
## Nuevo Formato: 
## "id": { 
##    "fps": int, 
##    "loop": bool, 
##    "up": { 
##       "frames": [Rect2, ...], 
##       "shape": { "type": "circle", "radius": 3.0, "pos": Vector2(0, -10) } 
##    },
##    ... 
## }
const DATA = {
	"arrow": {
		"fps": 0,
		"loop": false,
		"up": {
			"frames": [Rect2(0, 0, 5, 26)],
			"shape": { "type": "circle", "radius": 3.0, "pos": Vector2(0, -11) }
		},
		"down": {
			"frames": [Rect2(31, 5, 5, 26)],
			"shape": { "type": "circle", "radius": 3.0, "pos": Vector2(0, 11) }
		},
		"left": {
			"frames": [Rect2(0, 26, 31, 5)],
			"shape": { "type": "circle", "radius": 3.0, "pos": Vector2(-13, 0) }
		},
		"right": {
			"frames": [Rect2(5, 0, 31, 5)],
			"shape": { "type": "circle", "radius": 3.0, "pos": Vector2(13, 0) }
		}
	},
	"bolt": {
		"fps": 0,
		"loop": false,
		"up": {
			"frames": [Rect2(0, 0, 5, 23)],
			"shape": { "type": "rectangle", "size": Vector2(4, 10), "pos": Vector2(0, -6) }
		},
		"down": {
			"frames": [Rect2(26, 5, 5, 23)],
			"shape": { "type": "rectangle", "size": Vector2(4, 10), "pos": Vector2(0, 6) }
		},
		"left": {
			"frames": [Rect2(0, 23, 26, 5)],
			"shape": { "type": "rectangle", "size": Vector2(10, 4), "pos": Vector2(-6, 0) }
		},
		"right": {
			"frames": [Rect2(5, 0, 26, 5)],
			"shape": { "type": "rectangle", "size": Vector2(10, 4), "pos": Vector2(6, 0) }
		}
	},
	"rock": {
		"fps": 8,
		"loop": true,
		"up": {
			"frames": [Rect2(0, 0, 7, 6)],
			"shape": { "type": "circle", "radius": 3.5, "pos": Vector2(0, 0) }
		},
		"down": {
			"frames": [Rect2(0, 0, 7, 6)],
			"shape": { "type": "circle", "radius": 3.5, "pos": Vector2(0, 0) }
		},
		"left": {
			"frames": [Rect2(0, 0, 7, 6)],
			"shape": { "type": "circle", "radius": 3.5, "pos": Vector2(0, 0) }
		},
		"right": {
			"frames": [Rect2(0, 0, 7, 6)],
			"shape": { "type": "circle", "radius": 3.5, "pos": Vector2(0, 0) }
		}
	},
	"boomerang": {
		"fps": 12,
		"loop": true,
		"up": {
			"frames": [
				Rect2(0, 0, 64, 64), Rect2(64, 0, 64, 64), Rect2(128, 0, 64, 64), Rect2(192, 0, 64, 64), Rect2(256, 0, 64, 64),
				Rect2(0, 64, 64, 64), Rect2(64, 64, 64, 64), Rect2(128, 64, 64, 64), Rect2(192, 64, 64, 64), Rect2(256, 64, 64, 64)
			],
			"shape": { "type": "circle", "radius": 14.0, "pos": Vector2(0, 0) }
		},
		"down": {
			"frames": [
				Rect2(0, 0, 64, 64), Rect2(64, 0, 64, 64), Rect2(128, 0, 64, 64), Rect2(192, 0, 64, 64), Rect2(256, 0, 64, 64),
				Rect2(0, 64, 64, 64), Rect2(64, 64, 64, 64), Rect2(128, 64, 64, 64), Rect2(192, 64, 64, 64), Rect2(256, 64, 64, 64)
			],
			"shape": { "type": "circle", "radius": 14.0, "pos": Vector2(0, 0) }
		},
		"left": {
			"frames": [
				Rect2(0, 0, 64, 64), Rect2(64, 0, 64, 64), Rect2(128, 0, 64, 64), Rect2(192, 0, 64, 64), Rect2(256, 0, 64, 64),
				Rect2(0, 64, 64, 64), Rect2(64, 64, 64, 64), Rect2(128, 64, 64, 64), Rect2(192, 64, 64, 64), Rect2(256, 64, 64, 64)
			],
			"shape": { "type": "circle", "radius": 14.0, "pos": Vector2(0, 0) }
		},
		"right": {
			"frames": [
				Rect2(0, 0, 64, 64), Rect2(64, 0, 64, 64), Rect2(128, 0, 64, 64), Rect2(192, 0, 64, 64), Rect2(256, 0, 64, 64),
				Rect2(0, 64, 64, 64), Rect2(64, 64, 64, 64), Rect2(128, 64, 64, 64), Rect2(192, 64, 64, 64), Rect2(256, 64, 64, 64)
			],
			"shape": { "type": "circle", "radius": 14.0, "pos": Vector2(0, 0) }
		}
	},
	"arcane1": {
		"fps": 10,
		"loop": true,
		"up": {
			"frames": [Rect2(0, 0, 32, 32), Rect2(32, 0, 32, 32), Rect2(64, 0, 32, 32), Rect2(96, 0, 32, 32)],
			"shape": { "type": "circle", "radius": 8.0, "pos": Vector2(0, 0) }
		},
		"down": {
			"frames": [Rect2(0, 0, 32, 32), Rect2(32, 0, 32, 32), Rect2(64, 0, 32, 32), Rect2(96, 0, 32, 32)],
			"shape": { "type": "circle", "radius": 8.0, "pos": Vector2(0, 0) }
		},
		"left": {
			"frames": [Rect2(0, 0, 32, 32), Rect2(32, 0, 32, 32), Rect2(64, 0, 32, 32), Rect2(96, 0, 32, 32)],
			"shape": { "type": "circle", "radius": 8.0, "pos": Vector2(0, 0) }
		},
		"right": {
			"frames": [Rect2(0, 0, 32, 32), Rect2(32, 0, 32, 32), Rect2(64, 0, 32, 32), Rect2(96, 0, 32, 32)],
			"shape": { "type": "circle", "radius": 8.0, "pos": Vector2(0, 0) }
		}
	}
}
