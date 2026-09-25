class_name DamageEvent
extends RefCounted
## One application of damage. Combat code never calls type-specific methods
## like `take_sword_damage()`; everything flows through this object so new
## damage types (fire, holy, necrotic...) need no new code paths.

enum Type { PHYSICAL, FIRE, ICE, POISON, HOLY, NECROTIC }

var source: Node  # the attacker (may be null for environmental damage)
## The attacker's CombatController, when the source is a combatant.
var source_combatant: CombatController
var target: Node  # the entity receiving it (set by the DamageReceiver)
var damage_type: Type = Type.PHYSICAL
var amount: float = 0.0
## Stagger build-up; when a target's poise breaks it is staggered.
var poise_damage: float = 0.0
## World-space push applied to the target.
var knockback: Vector3 = Vector3.ZERO
var tags: PackedStringArray = []  # e.g. "heavy", "melee", "blocked"
## World-space hit position (for VFX).
var hit_position: Vector3 = Vector3.ZERO


static func create(from: Node, dmg: float, type: Type = Type.PHYSICAL) -> DamageEvent:
	var e := DamageEvent.new()
	e.source = from
	e.amount = dmg
	e.damage_type = type
	return e


func has_tag(tag: String) -> bool:
	return tags.has(tag)
