class_name Projectile
extends Node3D
## A flying DamageEvent. Sweeps a ray each physics frame (no tunnelling),
## damages the first hostile hurtbox that accepts its tags, stops at world
## geometry, and can burst for area damage.

const HIT_MASK := 1 | DamageReceiver.LAYER

var data: ProjectileData
var velocity := Vector3.ZERO
var faction: StringName
## Tags of the attack that fired it (receivers may require certain tags).
var tags: PackedStringArray = []
var ignore: Array[RID] = []
## Builds the DamageEvent for each victim (same factory melee hitboxes use).
var event_factory: Callable

var _travelled := 0.0
var _done := false

## Materials/meshes shared per ProjectileData (no per-shot allocations).
static var _visual_cache: Dictionary = {}


## Spawns a projectile at `origin` flying along `direction`. `origin` should
## be inside the shooter (chest): rays hit from inside, so point-blank
## targets and walls right in front are handled correctly.
static func fire(parent: Node, projectile_data: ProjectileData, origin: Vector3, direction: Vector3,
		shooter_faction: StringName, attack_tags: PackedStringArray, factory: Callable,
		ignore_rids: Array[RID]) -> Projectile:
	var p := Projectile.new()
	p.data = projectile_data
	p.faction = shooter_faction
	p.tags = attack_tags
	p.event_factory = factory
	p.ignore = ignore_rids
	p.velocity = direction.normalized() * projectile_data.speed
	parent.add_child(p)
	p.global_position = origin
	p.look_at(origin + p.velocity, Vector3.UP)
	p._build_visual()
	return p


func _physics_process(delta: float) -> void:
	if _done:
		return
	velocity.y -= data.gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, ignore)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := space.intersect_ray(query)
	while not hit.is_empty():
		var receiver := hit["collider"] as DamageReceiver
		if receiver == null:
			_impact(hit["position"], null)  # world geometry
			return
		if receiver.can_be_hit_by(faction) and receiver.accepts_tags(tags):
			_impact(hit["position"], receiver)
			return
		# Friendly, invulnerable or not affected by this attack: fly on.
		ignore.append(hit["rid"])
		query.exclude = ignore
		hit = space.intersect_ray(query)
	global_position = to
	if velocity.length_squared() > 0.01:
		look_at(to + velocity, Vector3.UP)
	_travelled += velocity.length() * delta
	if _travelled > data.max_range:
		if data.explosion_radius > 0.0:
			_impact(global_position, null)
		else:
			queue_free()


func _impact(point: Vector3, receiver: DamageReceiver) -> void:
	_done = true
	global_position = point
	if data.explosion_radius > 0.0:
		for r in _receivers_in_radius(point, data.explosion_radius):
			_hit(r, point)
		CombatVfx.burst(get_parent(), point, data.explosion_radius, data.orb_color)
	elif receiver:
		_hit(receiver, point)
	if data.impact_sound:
		var audio := AudioStreamPlayer3D.new()
		audio.stream = data.impact_sound
		add_child(audio)
		audio.play()
	for c in get_children():
		if c is GeometryInstance3D or c is OmniLight3D:
			c.visible = false
	get_tree().create_timer(1.0, false).timeout.connect(queue_free)


func _hit(receiver: DamageReceiver, point: Vector3) -> void:
	if not event_factory.is_valid():
		return  # shooter no longer exists
	var event: DamageEvent = event_factory.call(receiver)
	event.hit_position = point
	# Push away from the blast centre / along the flight path, not from the
	# shooter's position.
	var strength := event.knockback.length()
	var push := receiver.global_position - point if data.explosion_radius > 0.0 else velocity
	push.y = 0.0
	event.knockback = push.normalized() * strength if push.length_squared() > 0.0001 else Vector3.ZERO
	receiver.receive(event)


func _receivers_in_radius(point: Vector3, radius: float) -> Array[DamageReceiver]:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), point)
	q.collision_mask = DamageReceiver.LAYER
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var out: Array[DamageReceiver] = []
	for h in get_world_3d().direct_space_state.intersect_shape(q, 32):
		var r := h["collider"] as DamageReceiver
		if r and r.can_be_hit_by(faction) and r.accepts_tags(tags) and not ignore.has(r.get_rid()):
			out.append(r)
	return out


func _build_visual() -> void:
	var cached: Dictionary = _visual_cache.get(data, {})
	if cached.is_empty():
		cached = _make_visual_resources()
		_visual_cache[data] = cached
	if data.visual:
		var v: Node3D = data.visual.instantiate()
		v.scale = Vector3.ONE * data.visual_scale
		add_child(v)
		# Pale streak behind the arrow so fast shots read at distance.
		var streak := MeshInstance3D.new()
		streak.mesh = cached["streak"]
		streak.position.z = 0.8  # behind (projectile faces -Z)
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(streak)
	else:
		var orb := MeshInstance3D.new()
		orb.mesh = cached["orb"]
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(orb)
	if data.light_energy > 0.0:
		var light := OmniLight3D.new()
		light.light_color = data.orb_color
		light.light_energy = data.light_energy
		light.omni_range = 5.0
		add_child(light)


func _make_visual_resources() -> Dictionary:
	var out := {}
	var streak_mat := StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	streak_mat.albedo_color = Color(1.0, 0.95, 0.75, 0.55)
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 1.4)
	box.material = streak_mat
	out["streak"] = box
	var orb_mat := StandardMaterial3D.new()
	orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_mat.albedo_color = data.orb_color * 2.2
	var sphere := SphereMesh.new()
	sphere.radius = data.orb_size
	sphere.height = data.orb_size * 2.0
	sphere.material = orb_mat
	out["orb"] = sphere
	return out
