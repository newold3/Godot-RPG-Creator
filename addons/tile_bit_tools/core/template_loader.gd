extends RefCounted



const TAG_NOT_FOUND := null

const G := preload("res://addons/tile_bit_tools/core/globals.gd")

const TemplateBitData := preload("res://addons/tile_bit_tools/core/template_bit_data.gd")
const TemplateTagData := preload("res://addons/tile_bit_tools/core/template_tag_data.gd")
const TemplateTag := TemplateTagData.TemplateTag

var _template_tag_data := TemplateTagData.new()



var output := preload("res://addons/tile_bit_tools/core/output.gd").new()

var _templates := []
var _tags := []

# {tag_id : [template_id, ...]}
var _tags_to_templates := {}
# {template_id : [tag_id, ...]}
var _templates_to_tags := {}

# {text : tag_id}
var _custom_tags := {}

var _display_tag_ids := []



func _init(template_folder_paths : Array) -> void:
	_load_auto_tags()
	_load_templates(template_folder_paths)
	_setup_sorted_tag_ids()


func _load_templates(template_folder_paths : Array) -> void:
	var paths_parsed := []

	for folder_path in template_folder_paths:
		# don't load from duplicate folders
		if folder_path in paths_parsed:
			continue
		paths_parsed.append(folder_path)

		_load_templates_in_directory(
			folder_path.path,
			folder_path.type == G.TemplateTypes.BUILT_IN
		)


#func print_templates_by_tag() -> void:
#	for tag_id in _tags_to_templates.keys():
#		var tag : TemplateTag = _tags[tag_id]
#		print()
#		print(tag.text)
#		for template_id in _tags_to_templates[tag_id]:
#			var template : TemplateBitData = _templates[template_id]
#			print(template.template_name)



# takes the auto tags in specified order (skipping any not in list),
# then adds custom tags alphabetically
func _setup_sorted_tag_ids() -> void:
	for tag_enum_id in _template_tag_data.tag_display:
		var tag_id := get_tag_id(_template_tag_data.tags[tag_enum_id])
		if tag_id == -1:
			output.error("Unable to find auto tag %s" % tag_enum_id)
			continue
		_display_tag_ids.append(tag_id)

	var sorted_custom_tag_texts := _custom_tags.keys().duplicate()
	sorted_custom_tag_texts.sort_custom(func(a,b): return a.to_lower() < b.to_lower())

	for tag_text in sorted_custom_tag_texts:
		_display_tag_ids.append(_custom_tags[tag_text])


func get_tag(tag_id : int) -> TemplateTag:
	return _tags[tag_id]


func get_tag_id(tag : TemplateTag) -> int:
	return _tags.find(tag)


func get_tags_item_list(use_display_list := false, exclude_unused := false, filtered_tags := []) -> Array:
	if use_display_list:
		return _get_tags_item_list(_display_tag_ids, exclude_unused, false, filtered_tags)
	else:
		return _get_tags_item_list(range(_tags.size()), exclude_unused, true, filtered_tags)


func get_template(template_id : int) -> TemplateBitData:
	if template_id in range(0, _templates.size()):
		return _templates[template_id]
	return null

func get_templates() -> Array:
	return _templates

func _get_tags_item_list(tag_ids : Array, exclude_unused := false, sort_alphabetically := false, filtered_tags := []) -> Array:
	var item_list := []
	for tag_id in tag_ids:
		if tag_id in filtered_tags:
			continue

		var item := _get_tag_as_item(tag_id, exclude_unused, filtered_tags)
		if item.is_empty():
			continue
		item_list.append(item)

	if sort_alphabetically:
		item_list.sort_custom(func(a,b): return a["text"].to_lower() < b["text"].to_lower())

	return item_list


func _get_tag_as_item(tag_id : int, skip_if_unused := false, filtered_tags := []) -> Dictionary:
	var tags := filtered_tags.duplicate()
	tags.append(tag_id)
	var count : int = _get_filtered_templates_list(tags).size()
	if skip_if_unused && count == 0:
		return {}

	var tag : TemplateTag = _tags[tag_id]

	return({
		"id": tag_id,
		"text": tag.text,
		"count": count,
		"tag": tag,
#		"color": tag.color, # TODO: implement in future?
	})


func _get_all_template_ids() -> Array:
	return range(_templates.size())


func _get_filtered_templates_list(filter_by_tags := []) -> Array:
	var filtered_templates := _get_all_template_ids()

	for tag_id in filter_by_tags:
		var templates_by_tag : Array = _tags_to_templates[tag_id].duplicate()
		filtered_templates = filtered_templates.filter(func(id): return templates_by_tag.has(id))
		if filtered_templates.is_empty():
			return []

	return filtered_templates



func get_templates_item_list(filter_by_tags := []) -> Array:
	var item_list := []

	for template_id in _get_filtered_templates_list(filter_by_tags):
		var template : TemplateBitData = _templates[template_id]
		var text := template.template_name
		item_list.append({"id": template_id, "text": text})

	# sort alphabetically
	item_list.sort_custom(func(a, b): return a["text"].to_lower() < b["text"].to_lower())

	return item_list



func _load_auto_tags() -> void:
	for tag in _template_tag_data.tags.values():
		var _id := _add_tag(tag)


func _load_templates_in_directory(path : String, mark_as_built_in := false) -> void:
	var dir := DirAccess.open(path)
	if !dir:
		output.user("No directory found at %s" % path)
		return
	for file in dir.get_files():
		if !file.ends_with("tres"):
			continue

		# use get_current_dir() instead of path + file to normalize slashes
		var file_path := dir.get_current_dir() + "/" + file

		var template := load(file_path)
		if !template or template.get_script() != TemplateBitData:
			output.user("Error loading template at %s" % file_path)
			continue


		if mark_as_built_in:
			template.built_in = true

		var _id := _add_template(template)


func _get_or_add_custom_tag(tag_text : String) -> int:
#	output.debug("_get_or_add_custom_tag(): %s" % tag_text)

	var custom_tag_id = _custom_tags.get(tag_text, null)
#	output.debug("custom_tag_id=%s" % custom_tag_id)
	if custom_tag_id != TAG_NOT_FOUND:
		return custom_tag_id

	var tag := TemplateTag.new(tag_text)
	tag.custom_tag = true
	var tag_id := _add_tag(tag)
	_custom_tags[tag_text] = tag_id
	return tag_id


# adds tag, returns id
func _add_tag(tag : TemplateTag) -> int:
	_tags.append(tag)
	var tag_id := _tags.size() - 1
	_tags_to_templates[tag_id] = []
	return tag_id


# adds template, assigns its _tags, returns id
func _add_template(template : TemplateBitData) -> int:
	_templates.append(template)
	var template_id := _templates.size() - 1
	_templates_to_tags[template_id] = []
	_assign_template_auto_tags(template_id, template)
	_assign_template_custom_tags(template_id, template)
	return template_id


func _assign_template_auto_tags(template_id : int, template : TemplateBitData) -> void:
	for tag_id in range(_tags.size()):
		var tag : TemplateTag = _tags[tag_id]
		if !tag.has_test():
			continue
		if tag.get_test_result(template):
			_assign_template_to_tag(template_id, tag_id)


func _assign_template_custom_tags(template_id : int, template : TemplateBitData) -> void:
	for tag_text in template.get_custom_tags():
#		output.debug("Evaluating custom tag [%s] for template %s" % [tag_text, template.template_name])
		var tag_id := _get_or_add_custom_tag(tag_text)
#		output.debug("tag_id=%s" % tag_id)
		_assign_template_to_tag(template_id, tag_id)


func _assign_template_to_tag(template_id : int, tag_id : int) -> void:
	if !_tags_to_templates[tag_id].has(template_id):
		_tags_to_templates[tag_id].append(template_id)
	if !_templates_to_tags[template_id].has(tag_id):
		_templates_to_tags[template_id].append(tag_id)

