class_name RPGActionManager
extends Node


enum Ocassion {
	ALWAYS,
	BATTLE_SCREEN,
	MENU_SCREEN,
	NEVER
}


enum ActionScope {
	
}

enum EffectCode {
	
}

signal action_success(target: Variant, changes: Dictionary)
signal action_failure(target: Variant)
signal action_canceled(target: Variant)
