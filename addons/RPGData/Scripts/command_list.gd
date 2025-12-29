class_name CommandList

var commands: Dictionary = {
	# Text Command
	"insert_command": {
		"name": "",
		"description": "",
		"open_code": 0,
		"child_codes": [],
		"close_code": -1,
		"title_color": Color.WHITE,
		"config_color": Color.WHITE,
		"contents_color": Color.WHITE
	},
	"text": {
		"name": "Show text",
		"description": "Show a dialog window with text",
		"open_code": 1,
		"child_codes": [2],
		"close_code": -1,
		"title_color": Color(0.7628173828125, 0.546875, 1),
		"config_color": Color(0.69635939598083, 0.69375610351563, 0.69921875),
		"contents_color": Color(0.87668943405151, 0.60223388671875, 0.98828125)
	}
}
