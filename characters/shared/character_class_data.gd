class_name CharacterClassData
extends GameData
## A D&D-style class as data: body, stats, starting gear and abilities.
## New classes (Paladin, Druid...) are new .tres files, no code.

@export var model: PackedScene
## Optional alternative bodies (same rig); each character picks one by its
## CharacterLoadout.appearance_seed so a village isn't all twins.
@export var model_variants: Array[PackedScene] = []
@export var model_scale := 0.75
## Rig attachments hidden at start (weapons not in use, spare shields...).
@export var hidden_parts: PackedStringArray = []

@export_group("Stats")
@export var max_health := 100.0
@export var max_poise := 30.0
@export var move_speed_multiplier := 1.0
@export var damage_multiplier := 1.0
## Multiplies all incoming damage (Fighter's trained toughness).
@export var damage_taken_multiplier := 1.0

@export_group("Gear & abilities")
@export var starting_weapon: WeaponData
@export var abilities: Array[AbilityData] = []

@export_group("Presentation")
## Offered on the class select screen (villagers etc. are NPC-only).
@export var playable := true
@export var role_summary := ""
@export var ui_color := Color.WHITE


## The body for a given appearance seed.
func model_for(seed: int) -> PackedScene:
	if model_variants.is_empty():
		return model
	var all: Array[PackedScene] = [model]
	all.append_array(model_variants)
	return all[posmod(seed, all.size())]
