class_name CharacterClassData
extends GameData
## A D&D-style class as data: body, stats, starting gear and abilities.
## New classes (Paladin, Druid...) are new .tres files, no code.

@export var model: PackedScene
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
