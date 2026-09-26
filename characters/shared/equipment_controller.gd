class_name EquipmentController
extends Node
## What a character wields. Equipping a weapon changes the moveset and
## damage and shows the right meshes; nothing else needs to know.

signal equipment_changed(weapon: WeaponData)

@export var combat: CombatController
@export var model_root: Node3D

var weapon: WeaponData
## Class/base multiplier; the weapon's multiplier stacks on top.
var base_damage_multiplier := 1.0

var _shown_parts: PackedStringArray = []
var _attached: Node3D


func equip(new_weapon: WeaponData) -> void:
	_hide_current()
	weapon = new_weapon
	if weapon:
		combat.moveset = weapon.moveset
		combat.damage_multiplier = base_damage_multiplier * weapon.damage_multiplier
		_shown_parts = weapon.rig_parts
		ModelUtils.set_parts_visible(model_root, _shown_parts, true)
		if weapon.hand_scene:
			_attached = ModelUtils.attach_to_bone(model_root, "handslot.r", weapon.hand_scene)
	equipment_changed.emit(weapon)


## A new body (class change): the old meshes went away with the old model.
func set_model(root: Node3D) -> void:
	model_root = root
	_shown_parts = []
	_attached = null


## Stow/unstow weapon meshes (e.g. while carrying).
func set_weapon_visible(is_visible: bool) -> void:
	ModelUtils.set_parts_visible(model_root, _shown_parts, is_visible)
	if _attached:
		_attached.visible = is_visible


func _hide_current() -> void:
	ModelUtils.set_parts_visible(model_root, _shown_parts, false)
	_shown_parts = []
	if _attached:
		_attached.get_parent().queue_free()
		_attached = null
