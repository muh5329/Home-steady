class_name CombatSfx
extends Node3D
## Plays a combatant's sounds in response to its CombatController and
## DamageReceiver signals. Pure listener: combat code never calls audio.

@export var combat: CombatController
@export var sounds: CombatSounds
@export var volume_db := -4.0

var _players: Array[AudioStreamPlayer3D] = []
var _next := 0


func _ready() -> void:
	for i in 3:
		var p := AudioStreamPlayer3D.new()
		p.volume_db = volume_db
		p.unit_size = 6.0
		p.max_distance = 45.0
		p.bus = &"Master"
		add_child(p)
		_players.append(p)
	if combat == null or sounds == null:
		return
	combat.attack_started.connect(_on_attack_started)
	combat.state_changed.connect(_on_state_changed)
	combat.receiver.damage_taken.connect(_on_damage_taken)


func play(stream: AudioStream, pitch_jitter := 0.08) -> void:
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _on_attack_started(attack: AttackData) -> void:
	# Whoosh just before the blade connects.
	var delay := maxf(attack.scaled(attack.active_start) - 0.08, 0.0)
	var heavy := attack.tags.has("heavy")
	await get_tree().create_timer(delay, false, true).timeout
	if combat.state == CombatController.CombatState.ATTACKING:
		play(sounds.heavy_swing if heavy and sounds.heavy_swing else _pick(sounds.swings))


func _on_state_changed(state: CombatController.CombatState) -> void:
	if state == CombatController.CombatState.DODGING:
		play(sounds.dodge)


func _on_damage_taken(event: DamageEvent) -> void:
	if event.has_tag("blocked"):
		play(sounds.block, 0.05)
	else:
		play(_pick(sounds.hits_taken))


static func _pick(list: Array[AudioStream]) -> AudioStream:
	return list.pick_random() if not list.is_empty() else null
