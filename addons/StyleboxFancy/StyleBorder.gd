@tool
@icon("uid://bvvu8c56q60gy")
extends Resource
class_name StyleBorder

## Sets the border color. Modulates [param texture] if it is set.
@export var color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(v):
		color = v
		emit_changed()

## If [code]true[/code], the border will fade into the background color.
@export var blend: bool:
	set(v):
		blend = v
		emit_changed()

enum TextureMode {
	## The texture maps across the whole stylebox rectangle.
	STYLEBOX,
	## The texture maps across each border's thickness (from outer edge to inner edge, ideal for gradients).
	PER_BORDER,
}

enum TextureAxis {
	## Automatically maps to both U and V (works for 1D gradients, horizontal and vertical 2D gradients).
	AUTO,
	## Maps gradient strictly to U (horizontal axis).
	HORIZONTAL,
	## Maps gradient strictly to V (vertical axis).
	VERTICAL,
}

#region Texture
@export_group("Texture", "texture_")
## Sets the border texture.
@export var texture: Texture2D:
	set(v):
		texture = v
		emit_changed()

## Controls how the border texture UVs are mapped.
## If set to [constant PER_BORDER], the texture is mapped across each border individually (perpendicular to the border).
@export var texture_mode: TextureMode = TextureMode.STYLEBOX:
	set(v):
		texture_mode = v
		emit_changed()

## If [code]true[/code] and [member texture_mode] is [constant PER_BORDER], inverts the gradient direction (from inner edge to outer edge).
@export var texture_reverse: bool = false:
	set(v):
		texture_reverse = v
		emit_changed()

## The texture axis used for [constant PER_BORDER] texture mode.
## [constant AUTO]: Samples diagonally (works for 1D gradients, horizontal and vertical 2D gradients).
## [constant HORIZONTAL]: Samples along X/U axis.
## [constant VERTICAL]: Samples along Y/V axis.
@export var texture_axis: TextureAxis = TextureAxis.AUTO:
	set(v):
		texture_axis = v
		emit_changed()
#endregion

## If [code]true[/code], the border will ignore the entire border stack and
## draw as if it was on top of it.
@export var ignore_stack: bool = false:
	set(v):
		ignore_stack = v
		emit_changed()

## If [code]true[/code], anti-aliasing is applied to this border.
## Set to [code]false[/code] to keep the border crisp, solid and pixel-perfect without smoothing halos (ideal for thin 1px/2px borders).
@export var anti_aliasing: bool = true:
	set(v):
		anti_aliasing = v
		emit_changed()

#region Border width
@export_group("Border width", "width")
## Border width for the left edge.
@export_range(0, 1, 1, "or_greater", "suffix:px") var width_left: int:
	set(v):
		width_left = v
		emit_changed()

## Border width for the top edge.
@export_range(0, 1, 1, "or_greater", "suffix:px") var width_top: int:
	set(v):
		width_top = v
		emit_changed()

## Border width for the right edge.
@export_range(0, 1, 1, "or_greater", "suffix:px") var width_right: int:
	set(v):
		width_right = v
		emit_changed()

## Border width for the bottom edge.
@export_range(0, 1, 1, "or_greater", "suffix:px") var width_bottom: int:
	set(v):
		width_bottom = v
		emit_changed()
#endregion

#region Border inset
@export_group("Inset", "inset")

## Moves the left edge inwards leaving an empty area behind, or outwards if it is set with
## a negative value.
@export_custom(PROPERTY_HINT_NONE,"suffix:px") var inset_left: int:
	set(v):
		inset_left = v
		emit_changed()

## Moves the top edge inwards leaving an empty area behind, or outwards if it is set with
## a negative value.
@export_custom(PROPERTY_HINT_NONE,"suffix:px") var inset_top: int:
	set(v):
		inset_top = v
		emit_changed()

## Moves the right edge inwards leaving an empty area behind, or outwards if it is set with
## a negative value.
@export_custom(PROPERTY_HINT_NONE,"suffix:px") var inset_right: int:
	set(v):
		inset_right = v
		emit_changed()

## Moves the bottom edge inwards leaving an empty area behind, or outwards if it is set with
## a negative value.
@export_custom(PROPERTY_HINT_NONE,"suffix:px") var inset_bottom: int:
	set(v):
		inset_bottom = v
		emit_changed()
#endregion

func get_width(side: Side) -> int:
	match side:
		SIDE_LEFT: return width_left
		SIDE_TOP: return width_top
		SIDE_RIGHT: return width_right
		SIDE_BOTTOM: return width_bottom
	return 0

func get_width_min() -> int:
	return min(width_left, width_top, width_right, width_bottom)

func set_width(side: Side, width: int) -> void:
	match side:
		SIDE_LEFT: width_left = width
		SIDE_TOP: width_top = width
		SIDE_RIGHT: width_right = width
		SIDE_BOTTOM: width_bottom = width

func set_width_all(width: int) -> void:
	width_left = width
	width_top = width
	width_right = width
	width_bottom = width
