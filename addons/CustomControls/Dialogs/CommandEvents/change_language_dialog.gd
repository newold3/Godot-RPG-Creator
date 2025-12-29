@tool
extends CommandBaseDialog

func _ready() -> void:
	super()
	parameter_code = 120
	fill_languages()

func fill_languages() -> void:
	var node: OptionButton = %LanguageOptions
	node.clear()

	var all_languages = TranslationServer.get_all_languages()
	for language in all_languages:
		node.add_item(TranslationServer.get_language_name(language))
		node.set_item_metadata(-1, language)

func set_data() -> void:
	var locale = parameters[0].parameters.get("locale", "")
	var selected: bool = false
	var eng_index: int = -1
	for i in %LanguageOptions.get_item_count():
		var meta = %LanguageOptions.get_item_metadata(i)
		if meta and meta == locale:
			%LanguageOptions.select(i)
			selected = true
			break
		elif meta == "en":
			eng_index = i

	if not selected and eng_index != -1:
		%LanguageOptions.select(eng_index)

func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.locale = %LanguageOptions.get_item_metadata(%LanguageOptions.get_selected_id())
	return commands
