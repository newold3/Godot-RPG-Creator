extends RefCounted
class_name EnglishWordAbbreviator

## The default maximum length for an abbreviated word.
const DEFAULT_MAX_LENGTH: int = 4

## Standard RPG terminology exceptions for abbreviations.
const RPG_EXCEPTIONS: Dictionary = {
	"hit": "H",
	"points": "P",
	"health": "H",
	"magic": "M",
	"magical": "M",
	"mana": "M",
	"attack": "Atk",
	"defense": "Def",
	"experience": "Exp",
	"level": "Lv",
	"speed": "Spd",
	"agility": "Agi",
	"strength": "Str",
	"dexterity": "Dex",
	"intelligence": "Int",
	"vitality": "Vit",
	"luck": "Luk",
	"damage": "Dmg",
	"physical": "P",
	"critical": "Crit",
	"maximum": "Max",
	"minimum": "Min",
	"evasion": "Eva",
	"accuracy": "Acc",
	"resistance": "Res"
}



#region Abbreviation Logic
## Abbreviates an English word or phrase based on RPG rules, handling spaces and capitalization.
static func abbreviate_english_word(text: String, max_length: int = DEFAULT_MAX_LENGTH) -> String:
	if text.is_empty():
		return ""
		
	var words: PackedStringArray = text.split(" ", false)
	
	if words.size() > 1:
		return _abbreviate_multi_word(words, max_length)
		
	var result: String = _abbreviate_single_word(text, max_length)
	
	if result.length() <= 2:
		return result.to_upper()
		
	return result



## Handles the abbreviation logic for strings containing multiple words.
static func _abbreviate_multi_word(words: PackedStringArray, max_length: int) -> String:
	var result: String = ""
	
	for i in range(words.size() - 1):
		var word_lower: String = words[i].to_lower()
		
		if RPG_EXCEPTIONS.has(word_lower):
			var exc: String = RPG_EXCEPTIONS[word_lower]
			result += exc.substr(0, 1)
		else:
			result += words[i].substr(0, 1)
			
	var remaining_length: int = max_length - result.length()
	
	if remaining_length > 0:
		result += _abbreviate_single_word(words[words.size() - 1], remaining_length)
		
	if result.length() <= 2:
		return result.to_upper()
		
	var final_result: String = result.substr(0, 1).to_upper() + result.substr(1).to_lower()
	return final_result



## Abbreviates a single English word by keeping first and last letters, removing vowels, and dropping double consonants.
static func _abbreviate_single_word(word: String, max_length: int) -> String:
	var word_lower: String = word.to_lower()
	
	if RPG_EXCEPTIONS.has(word_lower):
		var exc: String = RPG_EXCEPTIONS[word_lower]
		if exc.length() <= max_length:
			return exc
		return exc.substr(0, max_length)
		
	if word.length() <= max_length:
		return word
		
	var first_char: String = word.substr(0, 1)
	var last_char: String = word.substr(word.length() - 1, 1)
	var middle_part: String = word.substr(1, word.length() - 2)
	
	var processed_middle: String = ""
	var vowels: Array[String] = ["a", "e", "i", "o", "u", "A", "E", "I", "O", "U"]
	var last_added_char: String = ""
	
	for i in range(middle_part.length()):
		var char_at: String = middle_part.substr(i, 1)
		
		if char_at in vowels:
			continue
			
		if char_at.to_lower() == last_added_char.to_lower():
			continue
			
		processed_middle += char_at
		last_added_char = char_at
		
	var result: String = first_char + processed_middle + last_char
	
	if result.length() > max_length:
		var chars_to_keep: int = max_length - 2
		
		if chars_to_keep > 0:
			result = first_char + processed_middle.substr(0, chars_to_keep) + last_char
		else:
			result = (first_char + processed_middle + last_char).substr(0, max_length)
			
	return result
#endregion
