@tool
extends RichTextEffect
class_name RichTextColorMod


# Syntax: [colormod color][/colormod]
var bbcode = "colormod"


func get_color(s) -> Color:
	if s is Color: return s
	elif s[0] == '#': return Color(s)
	else: return Color.from_string(s, Color.BLACK)


func _process_custom_fx(char_fx):
	var t = smoothstep(0.3, 0.6, sin(char_fx.elapsed_time * 4.0) * .5 + .5)
	var color: Color = get_color(char_fx.env.get("color", Color.BLUE))
	char_fx.color = lerp(char_fx.color, color, t)
	
#	char_fx.color.a -= RandUtil.noise(char_fx.elapsed_time * 8.0) * .5# sin(char_fx.elapsed_time * 16.0) * .5 + .5
#	var hsv = ColorUtil.color_to_hsv(char_fx.color)
#	hsv[0] += sin(char_fx.elapsed_time * 4.0) * .1
#	hsv[2] = sin(char_fx.elapsed_time * 8.0)
#	char_fx.color = char_fx.color.from_hsv(hsv[0], hsv[1], hsv[2], char_fx.color.a)
	return true
