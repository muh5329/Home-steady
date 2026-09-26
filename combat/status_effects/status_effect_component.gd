class_name StatusEffectComponent
extends Node
## Applies StatusEffectData carried by incoming DamageEvents: speed
## modifiers, damage over time and a tint. Re-applying refreshes duration.

signal effect_started(effect: StatusEffectData)
signal effect_ended(effect: StatusEffectData)

@export var receiver: DamageReceiver
@export var motor: CharacterMotor
@export var health: HealthComponent
@export var model: Node3D

var _active: Dictionary = {}  # StatusEffectData -> remaining seconds
var _tint_material: StandardMaterial3D


func _ready() -> void:
	receiver.damage_taken.connect(_on_damage_taken)
	if health:
		health.died.connect(clear)


## Removes every effect (death, revive, loading).
func clear() -> void:
	for effect: StatusEffectData in _active.keys():
		effect_ended.emit(effect)
	_active.clear()
	_refresh()


func has_effect(id: StringName) -> bool:
	for e: StatusEffectData in _active:
		if e.id == id:
			return true
	return false


func apply(effect: StatusEffectData) -> void:
	var fresh := not _active.has(effect)
	_active[effect] = effect.duration
	if fresh:
		effect_started.emit(effect)
		_refresh()


func _on_damage_taken(event: DamageEvent) -> void:
	if health and not health.is_alive():
		return
	if event.has_tag("blocked"):
		return  # a raised shield keeps the frost off
	for effect in event.status_effects:
		apply(effect)


func _physics_process(delta: float) -> void:
	if _active.is_empty():
		return
	for effect: StatusEffectData in _active.keys():
		if effect.damage_per_second > 0.0 and health and health.is_alive():
			health.take(effect.damage_per_second * delta)
		_active[effect] -= delta
		if _active[effect] <= 0.0:
			_active.erase(effect)
			effect_ended.emit(effect)
			_refresh()


func _refresh() -> void:
	var speed := 1.0
	var tint := Color(0, 0, 0, 0)
	for effect: StatusEffectData in _active:
		speed *= effect.speed_multiplier
		if effect.tint.a > tint.a:
			tint = effect.tint
	if motor:
		motor.set_speed_modifier(&"status", speed)
	_apply_tint(tint)


func _apply_tint(tint: Color) -> void:
	if model == null:
		return
	if _tint_material == null:
		_tint_material = StandardMaterial3D.new()
		_tint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tint_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_tint_material.albedo_color = tint
	var overlay: Material = _tint_material if tint.a > 0.0 else null
	for mesh: GeometryInstance3D in model.find_children("*", "GeometryInstance3D", true, false):
		# The animator's hit flash restores "base_overlay" when it ends.
		var base: Material = mesh.get_meta(&"base_overlay") if mesh.has_meta(&"base_overlay") else null
		var flashing: bool = mesh.material_overlay != null and mesh.material_overlay != base
		mesh.set_meta(&"base_overlay", overlay)
		if not flashing:
			mesh.material_overlay = overlay
