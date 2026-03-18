@tool
class_name RaceNameGenerator
extends RefCounted


## Chance (0.0 to 1.0) to pick a pre-made "Legendary" name instead of generating one.
## With 100 names per list, we can safely increase this chance to 20-25% for better quality feeling.
const HANDCRAFTED_CHANCE: float = 0.20


# --- 1. HUMAN / STANDARD (100 Pre-made names) ---
const HUMAN_PRE: Array[String] = ["Ald", "Bar", "Ced", "Dar", "Ed", "Fen", "Gar", "Hal", "Jar", "Ken", "Len", "Mar", "Nor", "Ord", "Pat", "Quin", "Rad", "Sten", "Tan", "Val", "Wil", "Xan", "Ys", "Zan", "Alb", "Ber", "Cor", "Del", "Ever", "Fal", "Garr", "Hol", "Is", "Jor", "Kal", "Lam", "Mor", "Ned", "Olf", "Per", "Quar", "Red", "Sil", "Tor", "Ul", "Vin", "War", "Xer", "Yar", "Zor"]
const HUMAN_MID: Array[String] = ["al", "an", "ar", "el", "en", "ir", "in", "or", "ur", "is", "os", "er", "on", "il", "ul", "am", "em", "im", "um", "yr", "as", "es", "us", "ath", "eth", "ith", "oth", "uth", "and", "end", "ind", "ond", "und"]
const HUMAN_SUF: Array[String] = ["win", "ard", "ric", "don", "mon", "ren", "ley", "man", "son", "mund", "ford", "ton", "mer", "wark", "lan", "bert", "brand", "crest", "dall", "den", "field", "gard", "hart", "ius", "land", "mar", "nan", "ney", "old", "rad", "red", "send", "stad", "th", "ver", "well", "wood", "year"]

const HUMAN_FULL: Array[String] = [
	"Adalbert", "Alaric", "Aldous", "Alistair", "Amadeus", "Anders", "Anson", "Aris", "Arthur", "Atticus",
	"Baldwin", "Barnaby", "Bastian", "Benedict", "Bertram", "Berrick", "Caelum", "Cassian", "Cedric", "Cillian",
	"Conrad", "Cornelius", "Cyprian", "Darius", "Desmond", "Dorian", "Drogo", "Duncan", "Eamon", "Edmund",
	"Edwin", "Elias", "Emeric", "Evander", "Fabian", "Felix", "Ferdinand", "Finnian", "Florian", "Frederick",
	"Gareth", "Gawain", "Gerald", "Gideon", "Godfrey", "Hadrian", "Hamish", "Harold", "Henrik", "Horatio",
	"Ignatius", "Inigo", "Isidore", "Jasper", "Jareth", "Julian", "Justus", "Kaelen", "Kieran", "Killian",
	"Lachlan", "Lambert", "Leander", "Leopold", "Lorcan", "Lucian", "Lucius", "Lysander", "Magnus", "Malachi",
	"Marcellus", "Marcus", "Marius", "Maximilian", "Nathaniel", "Neville", "Octavius", "Orion", "Orson", "Osmund",
	"Percival", "Peregrine", "Phineas", "Quentin", "Rafferty", "Reginald", "Remus", "Reuben", "Rhodri", "Richard",
	"Roderick", "Roland", "Rufus", "Rupert", "Sebastian", "Silas", "Soren", "Stellan", "Thaddeus", "Theodore",
	"Tobias", "Tristan", "Ulrich", "Valerius", "Victor", "William", "Wolfgang", "Xavier", "Yves", "Zachary"
]


# --- 2. BRUTE / ORC / TROLL (100 Pre-made names) ---
const BRUTE_PRE: Array[String] = ["Grom", "Thrak", "Karg", "Mog", "Zug", "Brak", "Druk", "Grish", "Hruk", "Krum", "Rakh", "Skard", "Uglak", "Vrog", "Zor", "Az", "Bolg", "Crag", "Durg", "Flog", "Ghor", "Hok", "Jag", "Kro", "Lug", "Makh", "Nar", "Org", "Prak", "Rugh", "Slog", "Torg", "Urz", "Vark", "Wroth", "Xar", "Yug", "Zog", "Brug", "Dakk", "Gnar", "Khaz", "Mok", "Nok"]
const BRUTE_MID: Array[String] = ["g", "k", "ar", "uz", "rog", "nak", "ok", "uk", "ag", "at", "oz", "ur", "akh", "ork", "ug", "igg", "ogg", "ukk", "rak", "zak", "mak", "dak", "nar", "gar", "tar", "var", "zar", "ash", "osh", "ush"]
const BRUTE_SUF: Array[String] = ["mash", "zog", "dur", "gar", "nak", "shak", "tar", "gash", "rokk", "kagg", "zur", "bash", "bad", "fang", "gore", "hag", "jaw", "kill", "lurk", "maul", "nash", "ork", "pox", "rot", "scar", "thak", "vok", "warg", "xul", "yag", "zark", "dreg", "fist", "grimm", "husk", "jagg"]

const BRUTE_FULL: Array[String] = [
	"Azog", "Bakh", "Barag", "Bazur", "Blackhand", "Borg", "Bragor", "Broxigar", "Brugor", "Burz",
	"ChoGall", "Crushidge", "Daggfist", "Dentarg", "Drakthul", "Dreg", "Drok", "Duggan", "Durn", "Durotan",
	"Flogg", "Gannik", "Gargan", "Garona", "Garrosh", "Ghazghkull", "Ghor", "Gnarl", "Golgoth", "Gorbaz",
	"Gorgutz", "Gorlag", "Grishnakh", "Grommash", "Grukk", "Grumlock", "Grung", "Guldan", "Harkon", "Hogger",
	"Horgak", "Hruon", "Jaghed", "Kargath", "Kazzak", "Khazra", "Korg", "Kraghuul", "Krogar", "Krom",
	"Krusher", "Lagakh", "Lorgus", "Lugburz", "Magrokk", "Malkor", "Mogor", "Moknathal", "Morglum", "Muggron",
	"Murgul", "Nazgrel", "Nerzhul", "Noggan", "Oglok", "Orgrim", "Rakthul", "Ratbag", "Rend", "Rexxar",
	"Ripfang", "Rokhan", "Rotgut", "Rrug", "Rugba", "Saurfang", "Scargath", "Shagrat", "Skarsnik", "Skullcrusher",
	"Slogg", "Snagga", "Snikrot", "Tarkus", "Tharbek", "Thok", "Thraka", "Thrall", "Throm", "Thrug",
	"Torgall", "Uglutz", "Urzog", "Varok", "Voljin", "Wazdakka", "Worg", "Wurrzag", "Zagstruk", "Zogwort",
	"Zuljin", "Zurgo", "Zzarg", "Dakka", "Stomp", "Bash", "Rakka", "Thump", "Krump", "Grot"
]


# --- 3. MYSTIC / ELF / FAIRY (100 Pre-made names) ---
const MYSTIC_PRE: Array[String] = ["Ael", "Cael", "Erin", "Fael", "Gala", "Ilian", "Luth", "Nym", "Ori", "Syl", "Thela", "Vesper", "Xana", "Yris", "Zef", "Aer", "Bel", "Cel", "Dae", "Eil", "Fae", "Gil", "Hae", "Ith", "Jae", "Kae", "Lia", "Mae", "Nae", "Oph", "Pae", "Qae", "Rae", "Sae", "Tae", "Ula", "Vae", "Wae", "Xae", "Yae", "Zae", "Thal", "Vala", "Mela"]
const MYSTIC_MID: Array[String] = ["la", "na", "th", "el", "ae", "ie", "ian", "in", "ss", "ll", "y", "ra", "da", "ma", "sa", "ta", "va", "wa", "ya", "za", "le", "ne", "the", "ele", "ane", "ine", "sse", "lle", "ye", "re", "de", "me", "se", "te", "ve"]
const MYSTIC_SUF: Array[String] = ["dor", "wyn", "fina", "lae", "mir", "rion", "serai", "thil", "vanna", "zora", "ael", "ian", "a", "e", "i", "o", "u", "y", "ae", "ea", "ia", "oa", "ua", "ya", "belle", "celle", "delle", "felle", "gelle", "helle", "jelle", "kelle", "lelle", "melle", "nelle", "pelle", "relle", "selle", "telle", "velle", "welle"]

const MYSTIC_FULL: Array[String] = [
	"Adalind", "Aegnor", "Aerendil", "Aeron", "Alatar", "Amras", "Amrod", "Anarion", "Angrod", "Aredhel",
	"Arwen", "Aurelia", "Beleg", "Beren", "Caelen", "Calenard", "Caradhras", "Caranthir", "Celeborn", "Celebrimbor",
	"Celegorm", "Cirdan", "Curufin", "Daeron", "Earendil", "Ecthelion", "Edrahil", "Elbereth", "Eldarion", "Elenwë",
	"Elrohir", "Elrond", "Elros", "Elwing", "Eol", "Erestor", "Erlan", "Faelivrin", "Faenor", "Feanor",
	"Felarof", "Finarfin", "Finduilas", "Fingolfin", "Fingon", "Finrod", "Galadriel", "Galdor", "Galion", "Gelmir",
	"Gil-Galad", "Gildor", "Glorfindel", "Gwindor", "Haldir", "Idril", "Ilmare", "Indis", "Ingwe", "Irimë",
	"Isil", "Legolas", "Lindir", "Luthien", "Maedhros", "Maeglin", "Maglor", "Mahtan", "Maldor", "Melian",
	"Mirthran", "Mithrellas", "Nerdanel", "Nimloth", "Nimrodel", "Olwë", "Orodreth", "Oropher", "Orophin", "Penlod",
	"Rumil", "Saeros", "Saelbeth", "Salmar", "Tauriel", "Thranduil", "Turgon", "Valandil", "Varda", "Voronwe",
	"Yavanna", "Aelin", "Rowan", "Silvan", "Oberon", "Titania", "Puck", "Ariel", "Lysandra", "Zephyr",
	"Elowen", "Thalis", "Ithil", "Sylvanas", "Alleria", "Vereesa", "Kaelthas", "Lorthermar", "Tyrande", "Malfurion"
]


# --- 4. DARK / DEMON / UNDEAD (100 Pre-made names) ---
const DARK_PRE: Array[String] = ["Mal", "Vok", "Xal", "Zor", "Kain", "Mor", "Nek", "Riven", "Sarak", "Thal", "Vor", "Xer", "Zek", "Az", "Bal", "Cul", "Dra", "Ex", "Ful", "Gorg", "Hade", "In", "Jez", "Kaz", "Luc", "Mef", "Noc", "Obs", "Pyr", "Qal", "Raz", "Styx", "Tene", "Umb", "Vex", "Wyt", "Xyl", "Yug", "Zul", "Krz", "Vrz"]
const DARK_MID: Array[String] = ["oz", "ul", "ax", "ir", "un", "az", "or", "ex", "ar", "ox", "ix", "ux", "org", "urg", "arg", "erg", "irg", "morg", "norg", "vorg", "zorg", "thorg", "korg", "lorg", "rorg", "sorg", "torg", "xorg", "yorg"]
const DARK_SUF: Array[String] = ["akar", "ial", "oz", "rik", "ul", "gor", "mord", "zar", "us", "ath", "imon", "a", "o", "u", "y", "ax", "ex", "ix", "ox", "ux", "az", "ez", "iz", "oz", "uz", "ak", "ek", "ik", "ok", "uk", "al", "el", "il", "ol", "ul", "am", "em", "im", "om", "um", "an", "en", "in", "on", "un"]

const DARK_FULL: Array[String] = [
	"Abaddon", "Abigor", "Abraxas", "Agares", "Ahriman", "Alastor", "Alucard", "Amon", "Andariel", "Andras",
	"AnubArak", "Apophis", "Archimonde", "Arthas", "Asmodeus", "Astaroth", "Azazel", "Azgalor", "Azmodan", "Baal",
	"Balam", "Balnazzar", "Balthazar", "Barbatos", "Beelzebub", "Belial", "Belphegor", "Bifrons", "Botis", "Buer",
	"Caim", "Cain", "Charon", "Cimeries", "Crowley", "Dantalion", "Demogorgon", "Detheroc", "Diablo", "Dracula",
	"Duriel", "Eligos", "Erebus", "Fenriz", "Foras", "Forneus", "Furcas", "Furfur", "Gaap", "Gamigin",
	"Geryon", "Glasya", "Gorgon", "Gremory", "Gusion", "Haagenti", "Halphas", "Haures", "Iblis", "Incubus",
	"Ipos", "Kain", "Kasdeya", "Kazrogal", "KelThuzad", "Kozilek", "Lilith", "Lucifer", "Malacoda", "Malphas",
	"Malsumis", "Malthael", "Mammon", "Mannoroth", "Marbas", "Marchosias", "Mastema", "Mephisto", "Merihim", "Moloch",
	"Morax", "Mordred", "Morgoth", "Murmur", "Naberius", "Nergal", "Nosferatu", "Orias", "Orobas", "Ose",
	"Paimon", "Phenex", "Pithos", "Purson", "Raum", "Rimon", "Ronove", "Samael", "Satan", "Seere",
	"Shax", "Sitri", "Stolas", "Succubus", "Surgat", "Thanatos", "Tichondrius", "Tyrael", "Valac", "Valefor",
	"Vapula", "Varimathras", "Vassago", "Vepar", "Vine", "Volac", "Vual", "Xaphan", "Zagan", "Zepar"
]


# --- 5. ANIMAL / SHORT / CUTE (100 Pre-made names) ---
const ANIMAL_PRE: Array[String] = ["Bip", "Miko", "Riko", "Snif", "Tip", "Jib", "Kik", "Nip", "Pik", "Tik", "Wik", "Zik", "Chip", "Dip", "Flip", "Hip", "Kip", "Lip", "Pip", "Rip", "Sip", "Zip", "Bop", "Cop", "Hop", "Lop", "Mop", "Pop", "Sop", "Top", "Bub", "Cub", "Dub", "Gub", "Hub", "Nub", "Pub", "Rub", "Sub", "Tub"]
const ANIMAL_MID: Array[String] = ["a", "i", "o", "u", "ip", "op", "up", "ep", "ap", "it", "ot", "ut", "et", "at", "ik", "ok", "uk", "ek", "ak"]
const ANIMAL_SUF: Array[String] = ["it", "ko", "la", "ni", "pa", "ra", "sa", "ta", "za", "bo", "do", "go", "ba", "ca", "da", "fa", "ga", "ha", "ja", "ka", "ma", "na", "qa", "va", "wa", "xa", "ya", "be", "ce", "de", "fe", "ge", "he", "je", "ke", "me", "ne", "pe", "qe", "re", "se", "te", "ve", "we", "xe", "ye", "ze"]

const ANIMAL_FULL: Array[String] = [
	"Abby", "Abu", "Ace", "Archie", "Bagheera", "Bailey", "Baloo", "Bambi", "Banjo", "Barney",
	"Baxter", "Bear", "Bella", "Benji", "Bingo", "Biscuit", "Blue", "Bolt", "Boots", "Buddy",
	"Bumper", "Buster", "Buttons", "Charlie", "Chester", "Chip", "Chloe", "Coco", "Cooper", "Copper",
	"Daisy", "Dexter", "Dino", "Dixie", "Dobby", "Dodger", "Donald", "Dory", "Dumbo", "Eddie",
	"Ellie", "Emile", "Felix", "Fido", "Figaro", "Flash", "Flicka", "Flipper", "Flower", "Fluffy",
	"Frankie", "Garfield", "George", "Ginger", "Gizmo", "Goofy", "Gus", "Gypsy", "Hank", "Happy",
	"Harley", "Harvey", "Hazel", "Heidi", "Hobbes", "Iago", "Izzy", "Jack", "Jake", "Jasper",
	"Jerry", "Joey", "Kaa", "Lady", "Lassie", "Leo", "Lilo", "Lily", "Loki", "Louie",
	"Lucky", "Luna", "Mac", "Marley", "Marlin", "Max", "Mickey", "Milo", "Minnie", "Mittens",
	"Mocha", "Molly", "Monty", "Murphy", "Nala", "Nemo", "Odie", "Oliver", "Oreo", "Oscar",
	"Otis", "Patch", "Peanut", "Penny", "Pepper", "Percy", "Perry", "Pip", "Pluto", "Pongo",
	"Poppy", "Pumbaa", "Rascal", "Remy", "Rex", "Rhino", "Rocky", "Romeo", "Rosie", "Rover",
	"Roxy", "Ruby", "Rufus", "Rusty", "Sadie", "Sam", "Sammy", "Sandy", "Scooby", "Scout",
	"Shadow", "ShereKhan", "Simba", "Skipper", "Slinky", "Smokey", "Snoopy", "Snowball", "Sparky", "Spike",
	"Spot", "Stella", "Stitch", "Stuart", "Teddy", "Thumper", "Tigger", "Timon", "Toby", "Tod",
	"Toto", "Trixie", "Tucker", "Tyson", "Winnie", "Woody", "Yeller", "Yogi", "Zeus", "Ziggy"
]


# --- MASTER DICTIONARY ---
# Format: "RaceName": [PREFIXES, MIDDLES, SUFFIXES, FULL_NAMES]
# This dictionary maps the specific race strings from the UI OptionButton to the style arrays.
var _race_data: Dictionary = {
	"Human": [HUMAN_PRE, HUMAN_MID, HUMAN_SUF, HUMAN_FULL],
	"Marked": [HUMAN_PRE, HUMAN_MID, HUMAN_SUF, HUMAN_FULL],
	"Half Bird": [HUMAN_PRE, HUMAN_MID, HUMAN_SUF, HUMAN_FULL],
	"Half Cat": [HUMAN_PRE, HUMAN_MID, HUMAN_SUF, HUMAN_FULL],
	"Half Wolf": [HUMAN_PRE, HUMAN_MID, HUMAN_SUF, HUMAN_FULL],
	
	"Orc": [BRUTE_PRE, BRUTE_MID, BRUTE_SUF, BRUTE_FULL],
	"Goblin": [BRUTE_PRE, BRUTE_MID, BRUTE_SUF, BRUTE_FULL],
	"Troll": [BRUTE_PRE, BRUTE_MID, BRUTE_SUF, BRUTE_FULL],
	"Minotaur": [BRUTE_PRE, BRUTE_MID, BRUTE_SUF, BRUTE_FULL],
	"Boarman": [BRUTE_PRE, BRUTE_MID, BRUTE_SUF, BRUTE_FULL],
	"Wartotaur": [BRUTE_PRE, BRUTE_MID, BRUTE_SUF, BRUTE_FULL],
	"Cyclops": [BRUTE_PRE, BRUTE_MID, BRUTE_SUF, BRUTE_FULL],
	
	"Dark Elf": [MYSTIC_PRE, MYSTIC_MID, MYSTIC_SUF, MYSTIC_FULL],
	"Fairy": [MYSTIC_PRE, MYSTIC_MID, MYSTIC_SUF, MYSTIC_FULL],
	"Faun": [MYSTIC_PRE, MYSTIC_MID, MYSTIC_SUF, MYSTIC_FULL],
	"Drake": [MYSTIC_PRE, MYSTIC_MID, MYSTIC_SUF, MYSTIC_FULL],
	
	"Demon": [DARK_PRE, DARK_MID, DARK_SUF, DARK_FULL],
	"Vampire": [DARK_PRE, DARK_MID, DARK_SUF, DARK_FULL],
	"Skeleton": [DARK_PRE, DARK_MID, DARK_SUF, DARK_FULL],
	"Zombie": [DARK_PRE, DARK_MID, DARK_SUF, DARK_FULL],
	"Frankenstein": [DARK_PRE, DARK_MID, DARK_SUF, DARK_FULL],
	"Alien": [DARK_PRE, MYSTIC_MID, DARK_SUF, DARK_FULL],
	
	"Mouse": [ANIMAL_PRE, ANIMAL_MID, ANIMAL_SUF, ANIMAL_FULL],
	"Rat": [ANIMAL_PRE, ANIMAL_MID, ANIMAL_SUF, ANIMAL_FULL],
	"Rabbit": [ANIMAL_PRE, ANIMAL_MID, ANIMAL_SUF, ANIMAL_FULL],
	"Pig": [ANIMAL_PRE, ANIMAL_MID, ANIMAL_SUF, ANIMAL_FULL],
	"Sheep": [ANIMAL_PRE, ANIMAL_MID, ANIMAL_SUF, ANIMAL_FULL],
	"Wolf": [ANIMAL_PRE, ANIMAL_MID, ANIMAL_SUF, ANIMAL_FULL],
	"Lizard": [ANIMAL_PRE, ANIMAL_MID, ANIMAL_SUF, ANIMAL_FULL],
}


## Generates a name based on the race, with a chance to pick a handcrafted name.
func generate_name_for_race(race_name: String) -> String:
	var lists: Array = []
	
	if _race_data.has(race_name):
		lists = _race_data[race_name]
	else:
		# Fallback to Human style if race is missing from dictionary
		lists = [HUMAN_PRE, HUMAN_MID, HUMAN_SUF, HUMAN_FULL]
	
	# 1. Check for Handcrafted Name (The "Legendary" roll)
	# This retrieves the 4th array (index 3) which contains the full names.
	var full_names: Array[String] = lists[3]
	if not full_names.is_empty() and randf() < HANDCRAFTED_CHANCE:
		return full_names.pick_random()
	
	# 2. Proceed with Procedural Generation
	var prefixes: Array[String] = lists[0]
	var middles: Array[String] = lists[1]
	var suffixes: Array[String] = lists[2]
	
	var length_parts: int = _get_weighted_length()
	var final_name: String = ""
	
	if length_parts == 1:
		# Simple 1-part name: 50/50 chance of being a standalone prefix or suffix
		if randf() > 0.5:
			final_name = prefixes.pick_random()
		else:
			final_name = suffixes.pick_random()
	else:
		# Complex name construction
		# Always start with a prefix
		final_name += prefixes.pick_random()
		
		# Add middle parts (Length - 2 because we have Start and End)
		var middle_count: int = length_parts - 2
		for i in range(middle_count):
			final_name += middles.pick_random()
			
		# Always end with a suffix
		final_name += suffixes.pick_random()
	
	return final_name.capitalize()


## Determines the number of parts based on rarity weights.
func _get_weighted_length() -> int:
	var roll: float = randf()
	
	# Adjusted probability curve for naming "feel"
	if roll < 0.05: return 1   # Very Rare (Short, e.g. "Grom")
	elif roll < 0.10: return 5 # Very Rare (Long, e.g. "Mith-ran-dir-ian-or")
	elif roll < 0.25: return 4 # Rare (Long, e.g. "Alex-and-ri-a")
	elif roll < 0.625: return 3 # Common (Standard fantasy length)
	else: return 2              # Common (Standard length)
