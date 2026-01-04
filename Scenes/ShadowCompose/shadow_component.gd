@tool
class_name ShadowComponent
extends Resource


## Controls Shadow Color
@export var shadow_color = Color(0, 0, 0, 0.45):
	set(value):
		shadow_color = value
		shadow_updated.emit()


## Controls Shadow z-index (1 == as environment or player)
@export var shadow_z_index: int = 1:
	set(value):
		shadow_z_index = value
		shadow_updated.emit()


## Controls Shadow z-index (1 == as environment or player)
@export var shadow_blend_type: CanvasItemMaterial.BlendMode = CanvasItemMaterial.BlendMode.BLEND_MODE_PREMULT_ALPHA:
	set(value):
		shadow_blend_type = value
		shadow_updated.emit()


## Controls Blur Size
@export_range(0, 20, 0.01) var blur_size = 2.5:
	set(value):
		blur_size = value
		shadow_updated.emit()


## Controls Horizontal Skew
@export_range(-0.89, 0.89, 0.01) var dynamic_skew: float = -0.84:
	set(value):
		dynamic_skew = value
		shadow_updated.emit()

## Controls the shadow elongation on both axes.
@export var elongation: Vector2 = Vector2(1.0, 0.542):
	set(value):
		elongation = value
		shadow_updated.emit()


## Control the location from where the shadow comes out (by default it "tries" to come out from the feet of the tile, but depending on the skew or elongation you may need to apply an extra offset to correct the position if the shadow is not aligned with the feet of the tile).
@export var offset: Vector2 = Vector2.ZERO:
	set(value):
		offset = value
		shadow_updated.emit()


## Controls skew and enlongation
@export_range(-PI, PI, 0.01) var shadow_transform: float = 0.0:
	set(value):
		shadow_transform = value
		if value != 0:
			update_shadow_parameters()


signal shadow_updated()


func update_shadow_parameters():
	# Calculate transformation angle
	var angle = shadow_transform

	# X elongation is always fixed at 1
	elongation.x = 1.0

	# Y elongation based on sine of angle
	elongation.y = sin(angle)

	# Skew controlled by combination of elongation and angle
	if elongation.y > 0:
		# When Y elongation is positive
		dynamic_skew = cos(angle) # Alternates between positive and negative depending on angle
	else:
		# When Y elongation is negative
		dynamic_skew = - cos(angle) # Invert sign to cover negative case

	# Emit signal to indicate shadow has been updated
	shadow_updated.emit()


func _to_string() -> String:
	return "shadow color #%s, blur size %s, dynamic skew %s elongation %s" % [
		(shadow_color.to_html() if shadow_color else ""),
		blur_size,
		dynamic_skew,
		elongation
	]
