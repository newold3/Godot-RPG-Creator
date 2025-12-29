class_name GameData
extends Resource


@export var actors: Array[GameActor] = []
@export var party_members: Array = []
@export var items: Array[GameItem] = []
@export var weapons: Array[GameWeapon] = []
@export var armors: Array[GameArmor] = []
@export var variables: Array = []
@export var switches: Array = []
@export var self_switches: Dictionary = {}
@export var current_gold: int = 0
@export var current_missions: Array[GameMission] = []
@export var statistics: GameStatistics = GameStatistics.new()


func _init() -> void:
	# Initialize Variables
	variables.resize(RPGSYSTEM.system.variables.size())
	for i in variables.size():
		variables[i] = 0
	# Initialize Switches:
	switches.resize(RPGSYSTEM.system.switches.size())
	for i in switches.size():
		switches[i] = false
