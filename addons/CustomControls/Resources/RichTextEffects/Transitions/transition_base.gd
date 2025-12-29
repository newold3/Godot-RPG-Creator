@tool
class_name RichTextEffectTransitionBase
extends RichTextEffect


const HALFPI = PI / 2.0
var SPACE = GlyphConverter.ord(" ")


func get_color(s) -> Color:
	if s is Color: return s
	elif s[0] == '#': return Color(s)
	else: return Color.from_string(s, Color.BLACK)


# Just a way to get a consistent seed value for randomized animations.
func get_rand(char_fx):
	return fmod(get_rand_unclamped(char_fx), 1.0)


func get_rand_unclamped(char_fx: CharFXTransform):
	return char_fx.glyph_index * 33.33 + char_fx.range.x * 4545.5454


func get_rand_time(char_fx, time_scale=1.0):
	return char_fx.glyph_index * 33.33 + char_fx.range.x * 4545.5454 + char_fx.elapsed_time * time_scale


func get_font_size(char_fx: CharFXTransform) -> Vector2i:
	var text_server: TextServer = TextServerManager.get_primary_interface()
	var s = text_server.font_get_size_cache_list(char_fx.font)
	var size: Vector2i = text_server.font_get_glyph_size(char_fx.font, Vector2i(10, 0), char_fx.glyph_index)
	
	return size


func get_tween_data() -> DialogBase:
	if has_meta("dialog"):
		var dialog = get_meta("dialog")
		if is_instance_valid(dialog) and dialog is DialogBase:
			return dialog
	
	# Fallback al singleton
	if is_instance_valid(DialogBase.instance):
		return DialogBase.instance
	
	return null


func get_t(char_fx: CharFXTransform, allow_all_together: bool = true) -> float:
	var instance = get_tween_data()
	if instance:
		return instance.get_t(char_fx.range.x, allow_all_together, char_fx.env.get("length", 8.0))
	return 0.0


func get_visible_characters() -> int:
	var instance = get_tween_data()
	if instance:
		return instance.get_visible_characters()
	return 0


func get_total_characters() -> int:
	var instance = get_tween_data()
	if instance:
		return instance.max_characters
	return 0


func get_characters_delay() -> float:
	var instance = get_tween_data()
	if instance:
		return instance.get_characters_delay()
	return 0.0
