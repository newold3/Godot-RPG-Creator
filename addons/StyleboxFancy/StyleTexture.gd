@tool
@icon("res://addons/StyleboxFancy/StyleTexture.svg")
extends Resource
class_name StyleTexture

enum StretchMode {
	## Scale to fit the node's bounding rectangle.
	SCALE,
	## The texture keeps its original size and stays in the bounding rectangle's top-left corner.
	KEEP,
	## The texture keeps its original size and stays centered in the node's bounding rectangle.
	KEEP_CENTERED,
	## Scale the texture to fit the node's bounding rectangle, but maintain the texture's aspect ratio.
	KEEP_ASPECT,
	## Scale the texture to fit the node's bounding rectangle, center it, and maintain its aspect ratio.
	KEEP_ASPECT_CENTERED,
	## Scale the texture so that the shorter side fits the bounding rectangle. The other side clips to the node's limits.
	KEEP_ASPECT_COVERED,
}

enum RepeatMode {
	## The CanvasItem will inherit the filter from its parent.
	INHERIT,
	## Texture will not repeat.
	DISABLED,
	## Texture will repeat normally.
	ENABLED,
	## Texture will repeat in a 2×2 tiled mode, where elements at even positions are mirrored.
	MIRROR,
}

enum FilterMode {
	## The CanvasItem will inherit the filter from its parent.
	INHERIT,
	## Nearest-neighbor texture filter (pixel-perfect / crisp scanlines).
	NEAREST,
	## Bilinear texture filter.
	LINEAR,
	## Nearest-neighbor with mipmaps.
	NEAREST_MIPMAPS,
	## Bilinear with mipmaps.
	LINEAR_MIPMAPS,
}

## If [code]true[/code], this texture layer is drawn.
@export var enabled: bool = true:
	set(v):
		enabled = v
		emit_changed()

## The texture to draw in this layer.
@export var texture: Texture2D:
	set(v):
		texture = v
		emit_changed()

## Sets the texture filter mode for this layer. Use [constant NEAREST] for crisp scanlines and pixel art.
@export var filter: FilterMode = FilterMode.INHERIT:
	set(v):
		filter = v
		emit_changed()

## Modulates the texture color and alpha transparency.
@export var modulate: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(v):
		modulate = v
		emit_changed()

## Controls the texture behavior when resizing the stylebox.
@export var stretch_mode: StretchMode = StretchMode.SCALE:
	set(v):
		stretch_mode = v
		emit_changed()

## Sets the repeating mode that this texture layer will use.
@export var repeat: RepeatMode = RepeatMode.INHERIT:
	set(v):
		repeat = v
		emit_changed()

## Scales the texture, its behaviour depends on [member stretch_mode].
@export_range(0.001, 5.0, 0.001, "or_less", "or_greater") var scale: float = 1.0:
	set(v):
		scale = maxf(v, 0.001)
		emit_changed()

## Moves the texture relative to the stylebox rectangle (normalized in texture UV space).
@export var offset: Vector2 = Vector2.ZERO:
	set(v):
		offset = v
		emit_changed()
