@tool
extends Window


var current_list = 1
var selected_item: int = 0


signal formula_selected(formula: String)


func _ready() -> void:
	close_requested.connect(queue_free)
	fill_list()


func fill_list() -> void:
	var list = %FormulaList
	list.clear()
	var formulas = get_list()
	for formula in formulas:
		var arr = formula.split(": ")
		list.add_column([arr[0].strip_edges(), arr[1].strip_edges()])
	
	list.select(0)
	selected_item = 0


func fill_formulas(list_id: int) -> void:
	current_list = list_id
	fill_list()


func get_list() -> Array:
	var formulas: Array

	match current_list:
		# 1️⃣ HP DAMAGE
		1:
			formulas = [
				"Physical HP Damage: a.atk - b.def",
				"Strong Physical HP Damage: a.atk * 3 - b.def",
				"Weak Physical HP Damage: a.atk * 0.4 - b.def",

				"Magical HP Damage: a.matk - b.mdf",
				"Strong Magical HP Damage: a.matk * 3 - b.mdf",
				"Weak Magical HP Damage: a.matk * 0.4 - b.mdf",

				"HP Damage Based on Agility: a.agi * 2 - b.agi",
				"HP Damage Based on Luck: a.luk * 2 - b.luk",

				"HP Damage Based on Target Max HP: b.mhp * 0.1",
				"HP Damage Based on User Level: a.level * 5"
			]

		# 2️⃣ MP DAMAGE
		2:
			formulas = [
				"Magical MP Damage: a.matk - b.mdf",
				"Strong Magical MP Damage: a.matk * 3 - b.mdf",
				"Weak Magical MP Damage: a.matk * 0.4 - b.mdf",

				"MP Damage Based on Max MP: b.mmp * 0.25",
				"MP Damage Based on Current MP: b.mp * 0.3",

				"MP Damage Based on Luck: a.luk * 1.5 - b.luk",
				"MP Damage Based on User Level: a.level * 4"
			]

		# 3️⃣ HP RECOVER
		3:
			formulas = [
				"Fixed HP Recovery (Small): 50",
				"Fixed HP Recovery (Medium): 150",
				"Fixed HP Recovery (Large): 300",

				"HP Recovery Based on Target Max HP: b.mhp * 0.25",
				"HP Recovery Based on Missing HP: (b.mhp - b.hp) * 0.5",

				"HP Recovery Based on Magic: a.matk * 2",
				"HP Recovery Based on User Level: a.level * 10",

				"HP Recovery with Pharmacology: 50 * a.pha",
				"HP Recovery with Recovery Effect: 100 * a.re"
			]

		# 4️⃣ MP RECOVER
		4:
			formulas = [
				"Fixed MP Recovery (Small): 20",
				"Fixed MP Recovery (Medium): 60",
				"Fixed MP Recovery (Large): 120",

				"MP Recovery Based on Target Max MP: b.mmp * 0.25",
				"MP Recovery Based on Missing MP: (b.mmp - b.mp) * 0.5",

				"MP Recovery Based on Magic: a.matk",
				"MP Recovery Based on User Level: a.level * 5",

				"MP Recovery with Pharmacology: 30 * a.pha",
				"MP Recovery with Recovery Effect: 60 * a.re"
			]

		# 5️⃣ HP DRAIN
		5:
			formulas = [
				"HP Drain (Physical): (a.atk - b.def) * 0.5",
				"HP Drain (Magical): (a.matk - b.mdf) * 0.5",

				"Strong HP Drain: (a.atk * 2 - b.def) * 0.5",
				"Weak HP Drain: (a.atk * 0.5 - b.def) * 0.5",

				"HP Drain Based on Target Max HP: b.mhp * 0.1",
				"HP Drain Based on Missing HP: (b.mhp - b.hp) * 0.3",

				"HP Drain with Recovery Effect: 80 * a.re"
			]

		# 6️⃣ MP DRAIN
		6:
			formulas = [
				"MP Drain (Magical): a.matk * 0.6",
				"Strong MP Drain: a.matk * 1.5",
				"Weak MP Drain: a.matk * 0.3",

				"MP Drain Based on Target MP: b.mp * 0.25",
				"MP Drain Based on Target Max MP: b.mmp * 0.15",

				"MP Drain with Recovery Effect: 40 * a.re"
			]

	return formulas



func _on_formula_list_item_selected(index: int) -> void:
	selected_item = index


func _on_formula_list_item_activated(index: int) -> void:
	selected_item = index
	_on_ok_button_pressed()


func _on_ok_button_pressed() -> void:
	var column = %FormulaList.get_column(selected_item)
	if column:
		formula_selected.emit(column[1])
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
