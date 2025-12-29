@tool
class_name RPGSkill
extends  Resource


func get_class(): return "RPGSkill"


@export var id: int = 0
@export var name: String = ""
@export var icon: RPGIcon = RPGIcon.new()
@export var description: String = ""
@export var skill_type: int = 1
@export var mp_cost: int = 0
@export var tp_cost: int = 0
@export var scope: RPGScope = RPGScope.new()
@export var occasion: int = 0
@export var invocation: RPGInvocation = RPGInvocation.new()
@export var battle_message: String = ""
@export var required_weapons: Array[RPGSkillRequiredWeapon] = []
@export var damage: RPGDamage = RPGDamage.new()
@export var effects: Array[RPGEffect] = []
@export var notes: String = ""


func clear() -> void:
	for v in ["name", "description", "battle_message", "notes"]: set(v, "")
	for v in [scope, invocation, required_weapons, damage, effects]: v.clear()
	skill_type = 1
	mp_cost = 0
	tp_cost = 0
	occasion = 0
	icon.clear()


func clone(value: bool = true) -> RPGSkill:
	var new_skill = duplicate(value)
	
	for i in new_skill.effects.size():
		new_skill.effects[i] = new_skill.effects[i].clone(value)
	for i in new_skill.required_weapons.size():
		new_skill.required_weapons[i] = new_skill.required_weapons[i].clone(value)
		
	new_skill.damage = new_skill.damage.clone(value)
	
	new_skill.scope = new_skill.scope.clone(value)
	
	new_skill.invocation = new_skill.invocation.clone(value)
	
	new_skill.icon = icon.clone(value)
	
	return new_skill
