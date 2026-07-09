@tool
class_name RPGEnums
extends RefCounted

## Enum for base parameters.
enum BaseParamType {
	HP = 0,                 ## Hit Points
	HIT_POINTS = 0,         ## Hit Points
	MP = 1,                 ## Magic Points
	MAGIC_POINTS = 1,       ## Magic Points
	ATK = 2,                ## Attack
	ATTACK = 2,             ## Attack
	DEF = 3,                ## Defense
	DEFENSE = 3,            ## Defense
	MAT = 4,                ## Magic Attack
	MATK = 4,               ## Magic Attack
	MAGIC_ATTACK = 4,       ## Magic Attack
	MDF = 5,                ## Magic Defense
	MDEF = 5,               ## Magic Defense
	MAGIC_DEFENSE = 5,      ## Magic Defense
	AGI = 6,                ## Agility
	AGILITY = 6,            ## Agility
	LUK = 7,                ## Luck
	LUCK = 7                ## Luck
}

## Enum for extra parameters.
enum ExtraParamType {
	HIT = 0,                        ## Hit Rate
	HIT_RATE = 0,                   ## Hit Rate
	EVA = 1,                        ## Evasion Rate
	EVASION = 1,                    ## Evasion Rate
	EVASION_RATE = 1,               ## Evasion Rate
	CRI = 2,                        ## Critical Rate
	CRITICAL = 2,                   ## Critical Rate
	CRITICAL_RATE = 2,              ## Critical Rate
	CEV = 3,                        ## Critical Evasion
	CRITICAL_EVASION = 3,           ## Critical Evasion
	CRITICAL_EVASION_RATE = 3,      ## Critical Evasion
	MEV = 4,                        ## Magic Evasion
	MAGIC_EVASION = 4,              ## Magic Evasion
	MAGIC_EVASION_RATE = 4,         ## Magic Evasion
	MRF = 5,                        ## Magic Reflection
	MAGIC_REFLECTION = 5,           ## Magic Reflection
	CNT = 6,                        ## Counter Attack
	COUNTER_ATTACK = 6,             ## Counter Attack
	HRG = 7,                        ## HP Regeneration
	HP_REGENERATION = 7,            ## HP Regeneration
	MRG = 8,                        ## MP Regeneration
	MP_REGENERATION = 8,            ## MP Regeneration
	TRG = 9,                        ## TP Regeneration
	TP_REGENERATION = 9             ## TP Regeneration
}

## Enum for special parameters.
enum SpecialParamType {
	TGR = 0,                        ## Target Rate
	TARGET_RATE = 0,                ## Target Rate
	GRD = 1,                        ## Guard Effect
	GUARD_EFFECT = 1,               ## Guard Effect
	REC = 2,                        ## Recovery Effect
	RECOVERY_EFFECT = 2,            ## Recovery Effect
	HM = 3,                         ## Healing Mastery
	HEALING_MASTERY = 3,            ## Healing Mastery
	MCR = 4,                        ## MP Cost Rate
	MP_COST_RATE = 4,               ## MP Cost Rate
	TCR = 5,                        ## TP Charge Rate
	TP_CHARGE_RATE = 5,             ## TP Charge Rate
	PDR = 6,                        ## Physical Damage Rate
	PHYSICAL_DAMAGE_RATE = 6,       ## Physical Damage Rate
	MDR = 7,                        ## Magic Damage Rate
	MAGIC_DAMAGE_RATE = 7,          ## Magic Damage Rate
	FDR = 8,                        ## Floor Damage Rate
	FLOOR_DAMAGE_RATE = 8,          ## Floor Damage Rate
	EXR = 9,                        ## Experience Rate
	EXPERIENCE_RATE = 9,            ## Experience Rate
	GDR = 10,                       ## Gold Rate
	GOLD_RATE = 10                  ## Gold Rate
}

## Enum for character passive traits.
enum TraitCode {
	ELEMENT_ATTACK = 1,      ## Alters elemental effectiveness of basic attacks.
	DEBUFF_RATE = 2,         ## Modifies the success rate of receiving debuffs.
	STATE_RATE = 3,          ## Modifies the success rate of receiving states.
	STATE_RESIST = 4,        ## Grants complete immunity to specific states.
	PARAM_BASE = 5,          ## Modifies base parameter multipliers (HP, MP, ATK, etc.).
	EX_PARAMETER = 6,        ## Modifies extra parameter values (Hit Rate, Evasion, etc.).
	SP_PARAMETER = 7,        ## Modifies special parameter values (Target Rate, EXP, etc.).
	ATTACK_ELEMENT = 8,      ## Adds elemental properties to basic attacks.
	ATTACK_STATE = 9,        ## Adds status effect infliction to basic attacks.
	ATTACK_SPEED = 10,       ## Modifies combat speed modifiers during basic attacks.
	ATTACK_TIMES_PLUS = 11,  ## Increases the number of additional attacks performed.
	ATTACK_SKILL = 12,       ## Replaces the basic attack with a specific skill.
	ADD_SKILL_TYPE = 13,     ## Unlocks a class/category of skills.
	SEAL_SKILL_TYPE = 14,    ## Locks a class/category of skills.
	ADD_SKILL = 15,          ## Unlocks a specific skill.
	SEAL_SKILL = 16,         ## Locks a specific skill.
	EQUIP_WEAPON = 17,       ## Allows equipping of specific weapon types.
	EQUIP_ARMOR = 18,        ## Allows equipping of specific armor types.
	LOCK_EQUIP = 19,         ## Prevents removing items from specific equipment slots.
	SEAL_EQUIP = 20,         ## Disables specific equipment slots entirely.
	SLOT_TYPE = 21,          ## Modifies equipment slots behavior (e.g. dual wield).
	ACTION_TIMES_PLUS = 22,  ## Modifies probability of acting multiple times in a turn.
	SPECIAL_FLAG = 23,       ## Unlocks special flags (e.g., auto-battle, guard).
	COLLAPSE_EFFECT = 24,    ## Customizes the defeat animation of the battler.
	PARTY_ABILITY = 25,      ## Unlocks party-wide bonuses (e.g. half encounter rate).
	SKILL_SPECIAL_FLAG = 26, ## Customizes specific skill modifiers.
	ELEMENT_DEFENSE = 27,    ## Alters elemental resistance multipliers.
	ADD_STATE = 28,          ## Grants permanent status effects while trait is active.
	USER_PARAMETER = 101     ## Custom parameters defined by the game developer.
}

## Enum for active item and skill usage effects.
enum EffectCode {
	RECOVER_HP = 1,     ## Restores HP to the target.
	RECOVER_MP = 2,     ## Restores MP to the target.
	GAIN_TP = 3,        ## Adds TP (Technical Points) to the target.
	ADD_STATE = 4,      ## Applies a status effect (state) to the target.
	REMOVE_STATE = 5,   ## Cures / removes a status effect from the target.
	ADD_BUFF = 6,       ## Adds temporary buff to a specific parameter.
	ADD_DEBUFF = 7,     ## Adds temporary debuff to a specific parameter.
	REMOVE_BUFF = 8,    ## Removes temporary buffs from a specific parameter.
	REMOVE_DEBUFF = 9,  ## Removes temporary debuffs from a specific parameter.
	SPECIAL_EFFECT = 10,## Triggers special actions (e.g., escape).
	GROW = 11,          ## Permanently increases a parameter.
	LEARN_SKILL = 12,   ## Teaches a specific skill to the target.
	COMMON_EVENT = 13   ## Triggers execution of a database common event.
}

## Enum for the current status of an active game quest.
enum QuestStatus {
	ACTIVE,                      ## Quest is currently active and in progress.
	COMPLETED_PENDING_DELIVERY,  ## Quest objectives are met, awaiting hand-in.
	FAILED_PENDING_DELIVERY      ## Quest objectives failed, awaiting resolution.
}

## Enum for the type of quest category.
enum QuestMode {
	TALK_TO_NPC,    ## Requires speaking with a specific NPC.
	GATHER_ITEM,    ## Requires gathering specific items.
	BOUNTY_HUNTS,   ## Requires defeating specific enemies.
	FIND_LOCATION,  ## Requires reaching / exploring a map location.
	USER_QUEST      ## Handled manually via common events and scripting.
}

## Enum for item types requested in a quest objective.
enum QuestItemType {
	ITEM,         ## Quest target is a database Item.
	WEAPON,       ## Quest target is a database Weapon.
	ARMOR,        ## Quest target is a database Armor.
	SET_COSTUME,  ## Quest target is a database Set / Costume.
	ENEMY         ## Quest target is a database Enemy (kill counter).
}


## Enum for quest resolution states.
enum QuestResult {
	SUCCESS,   ## Quest completed successfully.
	FAILED,    ## Quest failed.
	CANCELLED  ## Quest was cancelled by player or event.
}

## Bitmask enum for status effect (state) configuration.
enum StateMode {
	STATE_CONTEXT_GLOBAL = 1,       ## State is active in both exploration and battle.
	STATE_CONTEXT_BATTLE_ONLY = 2,  ## State is removed when battle ends.
	STATE_DURATION_TURNS = 4,       ## State duration is counted in battle turns.
	STATE_DURATION_SECONDS = 8,     ## State duration is counted in seconds.
	STATE_DURATION_PERMANENT = 16,  ## State does not wear off over time.
	STATE_TICKS_ENABLED = 32,       ## State triggers periodic tick handlers.
	STATE_TICKS_DAMAGE = 64,        ## State tick handlers do damage instead of healing.
	STATE_REMOVE_BY_WALKING = 128,  ## State wears off after player walks a number of steps.
	STATE_REMOVE_BY_DAMAGE = 256,   ## State wears off when target takes hit damage.
	STATE_REMOVE_BY_RESTRICTION = 512 ## State wears off when restriction changes.
}

## Enum for event page triggers.
enum LauncherMode {
	ACTION_BUTTON,    ## Triggered by pressing interact button next to event.
	PLAYER_COLLISION, ## Triggered when player walks into event.
	EVENT_COLLISION,  ## Triggered when event walks into player.
	AUTOMATIC,        ## Triggered automatically on map load.
	PARALLEL,         ## Executes continuously in background parallel process.
	CALLER,           ## Triggered via custom direct calling events.
	ANY_CONTACT,      ## Triggered by any touch collision.
	TOOL,             ## Triggered by contact with player tools.
	SIGNAL            ## Triggered by custom global signals.
}

## Enum for costume set override behaviors.
enum SetMode {
	FULL_STRICT = 0, ## Disables/Deletes equipment slots not configured in the set.
	FULL_HYBRID = 1, ## Deletes apparel not in the set, but keeps equipped weapons.
	PARTIAL     = 2, ## Merges / overrides only set items, keeping all other clothing.
	CUSTOME     = 3  ## Custom merges / overrides only set items.
}

## Enum for map generator placement constraints.
enum MapPlacement {
	ANYWHERE, ## Event can be placed anywhere on generator path.
	FLOOR,    ## Event must be placed on walkable floor tiles.
	WALL      ## Event must be placed on wall tiles.
}

## Enum for event alignment on generator segments.
enum MapEventPosition {
	ANYWHERE = 0,       ## Placed randomly.
	AT_THE_TOP = 1,     ## Placed at the top segment.
	AT_THE_BOTTOM = 2,  ## Placed at the bottom segment.
	AT_THE_CENTER = 3,  ## Placed in the center.
	ON_THE_LEFT = 4,    ## Placed on the left.
	ON_THE_RIGHT = 5,   ## Placed on the right.
	TOP_LEFT = 6,       ## Placed at top-left.
	TOP_RIGHT = 7,      ## Placed at top-right.
	BOTTOM_LEFT = 8,    ## Placed at bottom-left.
	BOTTOM_RIGHT = 9    ## Placed at bottom-right.
}
