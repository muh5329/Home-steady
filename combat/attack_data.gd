class_name AttackData
extends Resource
## One attack: which animation plays, when the hitbox is live, and what the
## hit does. All times are in seconds of *animation* time; `speed` scales
## the whole attack.

@export var animation: StringName
@export var speed: float = 1.0

@export_group("Timing")
## Hitbox live window.
@export var active_start: float = 0.3
@export var active_end: float = 0.5
## From this time a buffered follow-up (combo) may start.
@export var combo_window: float = 0.55
## The attack is over (control returns) at this time.
@export var recovery_end: float = 0.9
## Until active_start the attacker may still turn toward its input/target.
@export var turn_during_windup := true

@export_group("Effect")
@export var damage: float = 10.0
@export var damage_type: DamageEvent.Type = DamageEvent.Type.PHYSICAL
@export var poise_damage: float = 10.0
@export var knockback: float = 1.5
@export var tags: PackedStringArray = ["melee"]
## Hitbox box for this attack (local to the character, -Z forward).
## Zero size = the character's default weapon box.
@export var hitbox_size := Vector3.ZERO
@export var hitbox_offset := Vector3.ZERO
## > 0: use a sphere of this radius instead of the box (radial bursts).
@export var hitbox_radius := 0.0

@export var status_effects: Array[StatusEffectData] = []
## Area burst drawn at the active frame (alpha 0 = none), sized to the hitbox.
@export var burst_color := Color(0, 0, 0, 0)
## Area attacks: draw the danger zone on the ground during the wind-up.
@export var telegraph := false

@export_group("Projectile")
## If set, the active frame fires projectile(s) instead of opening the
## melee hitbox.
@export var projectile: ProjectileData
@export var projectile_count := 1
@export var spread_degrees := 0.0
## Launch point relative to the attacker (x right, y up, -z forward).
@export var muzzle_offset := Vector3(0.25, 1.35, -0.7)

@export_group("Movement")
## Forward step taken at the start of the active window.
@export var lunge_distance: float = 0.6
@export var lunge_duration: float = 0.12


func scaled(t: float) -> float:
	return t / speed
