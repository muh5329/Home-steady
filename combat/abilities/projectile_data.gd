class_name ProjectileData
extends Resource
## How a projectile flies and looks. Damage comes from the AttackData that
## fires it, so the same bolt can be weak or strong.

@export var speed := 30.0
@export var gravity := 0.0
@export var max_range := 40.0
## Area damage radius on impact (0 = single target).
@export var explosion_radius := 0.0
## Mesh scene for the projectile (arrow); otherwise a glowing orb.
@export var visual: PackedScene
@export var visual_scale := 1.0
@export var orb_color := Color(1.0, 0.6, 0.2)
@export var orb_size := 0.25
## Point light travelling with it (0 energy = none).
@export var light_energy := 0.0
@export var impact_sound: AudioStream
