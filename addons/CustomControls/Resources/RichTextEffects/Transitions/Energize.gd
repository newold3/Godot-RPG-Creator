@tool
extends RichTextEffectTransitionBase
# Syntax: [energize rings=3 color=#00ffff][/energize]
var bbcode = "energize"

func _process_custom_fx(char_fx):
	var tween_data = get_tween_data()
	if not tween_data: return
	
	if tween_data.time == 1.0:
		return true
	
	var rings = char_fx.env.get("rings", 3)
	var ring_color = get_color(char_fx.env.get("color", "#00ffff"))
	if !ring_color is Color:
		ring_color = Color(ring_color)
	
	var t = get_t(char_fx)
	
	if t >= 1.0:
		char_fx.color.a = 0.0
		return true
	
	var ring_phase = fmod(t * rings, 1.0)
	var ring_power = 1.0 - abs(ring_phase - 0.5) * 2.0
	
	char_fx.color = ring_color
	char_fx.color.a = ring_power * (1.0 - t)
	
	var y_offset = sin(t * PI) * 20.0
	char_fx.offset = Vector2(0, -y_offset)
	
	return true
