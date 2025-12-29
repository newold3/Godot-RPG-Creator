@tool
extends RichTextEffectTransitionBase
# Syntax: [glitch intensity=0.5 color=#ff0000][/glitch]
var bbcode = "glitch"

func _process_custom_fx(char_fx):
	var tween_data = get_tween_data()
	if not tween_data: return
	
	if tween_data.time == 1.0:
		return true
	
	var intensity = char_fx.env.get("intensity", 0.5)
	var glitch_color = get_color(char_fx.env.get("color", "#ff0000"))
	if !glitch_color is Color:
		glitch_color = Color(glitch_color)
		
	var t = get_t(char_fx)
	
	if t >= 1.0:
		char_fx.color.a = 0.0
		return true
	
	var rand_time = get_rand_time(char_fx, 10.0)
	var glitch_chance = fmod(rand_time * 10.0, 1.0)
	
	if glitch_chance < intensity * (1.0 - t):
		var offset_x = (get_rand(char_fx) * 2.0 - 1.0) * 10.0 * intensity
		char_fx.offset.x = offset_x
		char_fx.color = glitch_color
		char_fx.color.a = 1.0 - t
		
		if glitch_chance < intensity * 0.3:
			var ascii_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?"
			var rand_char = ascii_chars[int(rand_time * ascii_chars.length()) % ascii_chars.length()]
			char_fx.glyph_index = GlyphConverter.ord(rand_char)
	else:
		char_fx.color.a = 1.0 - t
	
	return true
