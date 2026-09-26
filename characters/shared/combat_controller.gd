class_name CombatController
extends Node
## Combat action state machine shared by the player, enemies and (later)
## companions. Brains issue *requests* (light/heavy/block/dodge); this node
## decides whether they are allowed, runs attack timing from AttackData,
## opens/closes the hitbox, and reacts to incoming damage (block, poise,
## stagger, death).

signal state_changed(state: CombatState)
signal attack_started(attack: AttackData)
signal attack_hit(event: DamageEvent)
signal staggered
signal died

enum CombatState { READY, ATTACKING, BLOCKING, DODGING, STAGGERED, BUSY, DEAD }

const GROUP := &"combatants"
const BUFFER_SECONDS := 0.35
const BLOCK_TRACK_RANGE := 6.0

@export var body: CharacterBody3D
@export var motor: CharacterMotor
@export var animator: CharacterAnimator
@export var health: HealthComponent
@export var receiver: DamageReceiver
@export var hitbox: Hitbox
@export var moveset: MovesetData
@export var faction: StringName = &"neutral"
@export var damage_multiplier := 1.0
## How many enemies may be mid-attack on this combatant at once.
@export var max_attackers := 2

@export_group("Poise & reactions")
@export var max_poise := 30.0
@export var poise_regen_delay := 2.0
@export var stagger_duration := 0.75
@export var flinch_duration := 0.3
## After a full stagger, poise can't break again for this long (no stunlock).
@export var stagger_immunity := 1.2
@export var hit_reactions: Array[StringName] = [&"Hit_A", &"Hit_B"]
@export var death_animation: StringName = &"Death_A"

@export_group("Dodge")
@export var dodge_animation: StringName = &"Dodge_Forward"
@export var dodge_speed := 8.5
@export var dodge_duration := 0.42
@export var dodge_iframes := 0.32
@export var dodge_cooldown := 0.25

## Optional: returns a world direction to aim attacks at (auto-aim / AI).
var aim_provider: Callable
## Optional: returns a world point projectiles should fly at (or null).
var aim_point_provider: Callable

var state: CombatState = CombatState.READY
var poise := 0.0
## Increments whenever a new action/state starts; async callers compare it
## to make sure "their" action is still the one playing.
var action_serial := 0

var _t := 0.0  # time in current state
var _attack: AttackData
var _combo_index := 0
var _lunged := false
var _buffered: StringName = &""
var _buffer_time := 0.0
var _block_held := false
var _dodge_dir := Vector3.ZERO
var _dodge_cooldown := 0.0
var _state_duration := 0.0
var _since_hit := 99.0
var _hitstop := 0.0
var _immunity := 0.0
var _attackers: Array[CombatController] = []
var _special: AttackData


func _ready() -> void:
	add_to_group(GROUP)
	poise = max_poise
	if receiver:
		receiver.faction = faction
		receiver.about_to_take_damage.connect(_on_about_to_take_damage)
		receiver.damage_taken.connect(_on_damage_taken)
	if hitbox:
		hitbox.faction = faction
		if receiver:
			hitbox.ignore.append(receiver)
		hitbox.hit.connect(_on_hitbox_hit)
	if health:
		health.died.connect(_on_died)


# --- queries ----------------------------------------------------------------

func is_alive() -> bool:
	return state != CombatState.DEAD


func can_move() -> bool:
	return state in [CombatState.READY, CombatState.BLOCKING]


## True while a buffered light/heavy request would chain right now.
func can_chain() -> bool:
	return state == CombatState.ATTACKING and _attack != null \
		and _t >= _attack.scaled(_attack.combo_window)


func is_hostile_to(other: CombatController) -> bool:
	return other.faction != faction and other.faction != &"neutral" and faction != &"neutral"


func global_position() -> Vector3:
	return body.global_position


func find_nearest_hostile(max_distance: float, facing := Vector3.ZERO, min_dot := -1.0) -> CombatController:
	return Targeting.nearest_hostile(self, max_distance, facing, min_dot)


# --- attack slots (lets enemies take turns instead of dog-piling) ------------

func claim_attack_slot(attacker: CombatController) -> bool:
	_attackers = _attackers.filter(func(a): return is_instance_valid(a) and a.is_alive())
	if attacker in _attackers:
		return true
	if _attackers.size() >= max_attackers:
		return false
	_attackers.append(attacker)
	return true


func release_attack_slot(attacker: CombatController) -> void:
	_attackers.erase(attacker)


# --- requests from brains ---------------------------------------------------

func request_light() -> void:
	_buffer(&"light")


func request_heavy() -> void:
	_buffer(&"heavy")


## Queues a specific attack (abilities). Starts like a heavy attack would.
func request_special(attack: AttackData) -> void:
	_special = attack
	_buffer(&"special")


func request_dodge(direction: Vector3) -> void:
	_dodge_dir = direction
	_buffer(&"dodge")


func set_block(held: bool) -> void:
	_block_held = held and moveset != null and moveset.can_block


## Plays a non-combat action (pickup, throw, chop...) that occupies the
## character. Duration defaults to the clip length at `speed`.
## Returns false if currently unable.
func perform(clip: StringName, speed := 1.0, move_multiplier := 0.0, duration := -1.0) -> bool:
	if state not in [CombatState.READY, CombatState.BLOCKING]:
		return false
	_enter(CombatState.BUSY)
	_state_duration = duration if duration > 0.0 else animator.clip_length(clip) / speed
	motor.set_speed_modifier(&"combat", move_multiplier)
	animator.play_action(clip, speed)
	return true


## Brings a dead combatant back (player respawn, downed companions).
func revive(health_value := -1.0) -> void:
	health.set_current(health.max_health if health_value <= 0.0 else health_value)
	receiver.set_deferred(&"monitorable", true)
	receiver.invulnerable = false
	poise = max_poise
	animator.stop_action()
	animator.set_base_override(&"")
	state = CombatState.DEAD  # force _enter to run its READY bookkeeping
	_enter(CombatState.READY)


## Cancels whatever is happening (used by scripted events and loading).
func interrupt() -> void:
	if state == CombatState.DEAD:
		return
	_end_attack()
	animator.stop_action()
	_enter(CombatState.READY)


func _buffer(action: StringName) -> void:
	if state == CombatState.DEAD:
		return
	_buffered = action
	_buffer_time = BUFFER_SECONDS


# --- update -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == CombatState.DEAD:
		return
	if _hitstop > 0.0:
		# Impact pause: timers, movement and animation all hold.
		_hitstop -= delta
		return
	_t += delta
	_buffer_time -= delta
	if _buffer_time <= 0.0:
		_buffered = &""
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_immunity = maxf(_immunity - delta, 0.0)
	_since_hit += delta
	if _since_hit > poise_regen_delay:
		poise = minf(poise + max_poise * delta, max_poise)

	match state:
		CombatState.READY, CombatState.BLOCKING:
			_update_ready()
		CombatState.ATTACKING:
			_update_attack()
		CombatState.DODGING:
			if _t >= dodge_iframes:
				receiver.invulnerable = false
			if _t >= dodge_duration:
				_enter(CombatState.READY)
		CombatState.STAGGERED, CombatState.BUSY:
			if _t >= _state_duration:
				_enter(CombatState.READY)


func _update_ready() -> void:
	if _consume(&"dodge"):
		return
	if _consume(&"light") or _consume(&"heavy") or _consume(&"special"):
		return
	var want_block := _block_held and motor.is_grounded()
	if want_block and state == CombatState.READY:
		_enter(CombatState.BLOCKING)
		animator.play_action(moveset.block_start_animation, 1.5)
		animator.set_base_override(moveset.block_loop_animation)
		motor.set_speed_modifier(&"combat", 0.4)
		motor.set_facing_lock(&"block", true)  # back off without turning your shield away
	elif not want_block and state == CombatState.BLOCKING:
		_enter(CombatState.READY)
	if state == CombatState.BLOCKING:
		# Keep the shield toward the nearest threat (never toward movement).
		var threat := find_nearest_hostile(BLOCK_TRACK_RANGE)
		if threat:
			motor.face(threat.global_position() - body.global_position)


func _update_attack() -> void:
	var a := _attack
	# Windup: allow turning toward aim; afterwards facing is committed.
	if _t < a.scaled(a.active_start):
		if a.turn_during_windup:
			_aim(false)
			motor.turn_multiplier = 0.6
	else:
		motor.turn_multiplier = 0.0
	if not _lunged and _t >= a.scaled(a.active_start):
		_lunged = true
		if a.lunge_distance > 0.0:
			motor.burst(motor.get_facing() * a.lunge_distance / a.lunge_duration, a.lunge_duration)
		if a.projectile:
			_fire_projectiles(a)
		else:
			hitbox.activate(_make_event_factory(a), a.hitbox_size, a.hitbox_offset, a.hitbox_radius)
		if a.burst_color.a > 0.0:
			var center := body.global_transform * Vector3(a.hitbox_offset.x, 0.0, a.hitbox_offset.z)
			var r := a.hitbox_radius if a.hitbox_radius > 0.0 else maxf(a.hitbox_size.x, a.hitbox_size.z) * 0.5
			CombatVfx.burst(body.get_parent(), center, r, a.burst_color)
	if hitbox.is_active() and _t >= a.scaled(a.active_end):
		hitbox.deactivate()
	# Follow-ups.
	if can_chain() and (_buffered == &"light" or _buffered == &"heavy" or _buffered == &"special"):
		_consume(_buffered)
		return
	if _t >= a.scaled(a.active_end) and _buffered == &"dodge":
		_consume(&"dodge")
		return
	if _t >= a.scaled(a.recovery_end):
		_end_attack()
		_combo_index = 0
		_enter(CombatState.READY)


## Starts the buffered action if possible. Returns true if it started.
func _consume(action: StringName) -> bool:
	if _buffered != action:
		return false
	match action:
		&"light":
			if moveset == null or moveset.light_combo.is_empty():
				return false
			var chaining: bool = state == CombatState.ATTACKING
			var index := (_combo_index + 1) % moveset.light_combo.size() if chaining else 0
			_start_attack(moveset.light_combo[index], index)
		&"heavy":
			if moveset == null or moveset.heavy_attack == null:
				return false
			_start_attack(moveset.heavy_attack, 0)
		&"special":
			if _special == null:
				return false
			_start_attack(_special, 0)
			_special = null
		&"dodge":
			if _dodge_cooldown > 0.0 or not motor.is_grounded():
				return false
			_start_dodge()
	_buffered = &""
	return true


func _start_attack(attack: AttackData, combo_index: int) -> void:
	_end_attack()
	_enter(CombatState.ATTACKING)
	_attack = attack
	_combo_index = combo_index
	_lunged = false
	motor.set_speed_modifier(&"combat", 0.0)
	motor.cancel_burst()
	_aim(true)
	animator.play_action(attack.animation, attack.speed, 0.06)
	attack_started.emit(attack)


func _end_attack() -> void:
	if hitbox and hitbox.is_active():
		hitbox.deactivate()
	motor.turn_multiplier = 1.0
	_attack = null


func _start_dodge() -> void:
	_end_attack()
	var dir := _dodge_dir
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = motor.get_facing()
	dir = dir.normalized()
	_enter(CombatState.DODGING)
	motor.face(dir, true)
	motor.burst(dir * dodge_speed, dodge_duration)
	receiver.invulnerable = true
	_dodge_cooldown = dodge_duration + dodge_cooldown
	animator.play_action(dodge_animation, animator.clip_length(dodge_animation) / dodge_duration * 0.9, 0.05)


func _aim(instant: bool) -> void:
	if not aim_provider.is_valid():
		return
	var dir: Vector3 = aim_provider.call()
	if dir != Vector3.ZERO:
		motor.face(dir, instant)


func _fire_projectiles(a: AttackData) -> void:
	var facing := motor.get_facing()
	# Launch from inside the chest (just ahead of the spine) at muzzle
	# height: rays hit from inside, so walls you hug and enemies at point
	# blank are handled instead of being skipped.
	var origin := body.global_position + Vector3.UP * a.muzzle_offset.y + facing * 0.25
	var target = aim_point_provider.call() if aim_point_provider.is_valid() else null
	var dir: Vector3 = (target - origin).normalized() if target is Vector3 else facing
	var ignore: Array[RID] = [receiver.get_rid()]
	var parent := body.get_parent()
	for i in a.projectile_count:
		var angle := 0.0
		if a.projectile_count > 1:
			angle = deg_to_rad(lerpf(-a.spread_degrees, a.spread_degrees, float(i) / (a.projectile_count - 1)))
		Projectile.fire(parent, a.projectile, origin, dir.rotated(Vector3.UP, angle), faction,
			a.tags, _make_event_factory(a), ignore)


## Could a new action (ability) start now or chain from the current one?
func can_start_action() -> bool:
	return state in [CombatState.READY, CombatState.BLOCKING] or can_chain()


func _make_event_factory(attack: AttackData) -> Callable:
	return func(target_receiver: DamageReceiver) -> DamageEvent:
		var e := DamageEvent.create(body, attack.damage * damage_multiplier, attack.damage_type)
		e.source_combatant = self
		e.poise_damage = attack.poise_damage
		var push := target_receiver.global_position - body.global_position
		push.y = 0.0
		e.knockback = push.normalized() * attack.knockback
		e.tags = attack.tags.duplicate()
		e.status_effects = attack.status_effects
		return e


# --- state helpers ------------------------------------------------------------

func _enter(new_state: CombatState) -> void:
	var previous := state
	if previous == CombatState.BLOCKING and new_state != CombatState.BLOCKING:
		animator.set_base_override(&"")
		motor.set_facing_lock(&"block", false)
	if previous == CombatState.DODGING:
		receiver.invulnerable = false
	state = new_state
	_t = 0.0
	action_serial += 1
	if new_state == CombatState.READY:
		motor.set_speed_modifier(&"combat", 1.0)
		motor.turn_multiplier = 1.0
		# The tail of an attack/pickup clip may still play; let movement cut it.
		animator.soften_action()
	elif new_state in [CombatState.STAGGERED, CombatState.DEAD]:
		motor.set_speed_modifier(&"combat", 0.0)
	state_changed.emit(new_state)


# --- incoming damage ------------------------------------------------------------

func _on_about_to_take_damage(event: DamageEvent) -> void:
	if state != CombatState.BLOCKING or event.source == null:
		return
	var to_attacker: Vector3 = (event.source as Node3D).global_position - body.global_position
	to_attacker.y = 0.0
	if to_attacker.normalized().dot(motor.get_facing()) > 0.2:
		event.amount *= 1.0 - moveset.block_reduction
		event.poise_damage *= 0.5
		event.knockback *= 0.5
		event.tags.append("blocked")


func _on_damage_taken(event: DamageEvent) -> void:
	if state == CombatState.DEAD:
		return
	_since_hit = 0.0
	if _immunity <= 0.0:
		poise -= event.poise_damage
	motor.add_knockback(event.knockback)
	animator.flash()
	_hitstop = maxf(_hitstop, 0.07)
	motor.hold(0.07)
	animator.freeze(0.07)
	if not health.is_alive():
		return  # _on_died handles it
	if event.has_tag("blocked"):
		if poise <= 0.0:
			_stagger(stagger_duration)  # guard broken
		else:
			animator.play_action(moveset.block_hit_animation, 1.2)
		return
	if poise <= 0.0:
		_stagger(stagger_duration)
	elif _immunity <= 0.0 and state in [CombatState.READY, CombatState.BLOCKING, CombatState.BUSY]:
		# Light flinch; attacks and dodges keep their "armor".
		_stagger(flinch_duration)


func _stagger(duration: float) -> void:
	_end_attack()
	motor.cancel_burst()
	if duration >= stagger_duration:
		poise = max_poise
		_immunity = stagger_immunity + duration
	_enter(CombatState.STAGGERED)
	_state_duration = duration
	var clip: StringName = hit_reactions.pick_random() if not hit_reactions.is_empty() else &""
	if clip != &"":
		# Long staggers slow the clip down; flinches play it at natural speed
		# and get cut short by movement once control returns.
		var speed := clampf(animator.clip_length(clip) / duration, 0.7, 1.3)
		animator.play_action(clip, speed)
	staggered.emit()


func _on_hitbox_hit(_receiver: DamageReceiver, event: DamageEvent) -> void:
	var stop := 0.1 if event.has_tag("heavy") else 0.06
	_hitstop = maxf(_hitstop, stop)
	motor.hold(stop)
	animator.freeze(stop)
	attack_hit.emit(event)


func _on_died() -> void:
	_end_attack()
	motor.cancel_burst()
	_enter(CombatState.DEAD)
	_attackers.clear()
	receiver.set_deferred(&"monitorable", false)
	animator.set_base_override(&"")
	animator.play_action(death_animation, 1.0, 0.1, true)
	died.emit()
	EventBus.combatant_died.emit(body)
