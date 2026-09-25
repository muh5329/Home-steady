class_name CombatSounds
extends Resource
## The sounds a combatant makes. Swapped per character/monster as data.

@export var swings: Array[AudioStream] = []
@export var heavy_swing: AudioStream
@export var hits_taken: Array[AudioStream] = []
@export var block: AudioStream
@export var dodge: AudioStream
