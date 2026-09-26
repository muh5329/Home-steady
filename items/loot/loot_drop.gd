class_name LootDrop
## Spills physical items (chests, fallen monsters, bosses): each unit is a
## Carryable popped out in a small fan in front of `origin`.


static func spill(tree: SceneTree, loot: Dictionary, origin: Vector3, forward := Vector3.BACK) -> Array[Carryable]:
	var out: Array[Carryable] = []
	var parent := tree.get_first_node_in_group(WorldItems.GROUP)
	if parent == null:
		return out
	var fwd := NavSteering.flat(forward).normalized()
	if fwd == Vector3.ZERO:
		fwd = Vector3.BACK
	var space := (parent as Node3D).get_world_3d().direct_space_state
	var centre := origin + Vector3.UP * 0.9
	var i := 0
	for id in loot:
		var data := DataRegistry.get_data(id) as ItemData
		if data == null or data.carry_scene == null:
			push_warning("LootDrop: no carryable for '%s'" % id)
			continue
		for n in int(loot[id]):
			var body: Carryable = data.carry_scene.instantiate()
			parent.add_child(body)
			var side := fwd.cross(Vector3.UP) * (float(i % 3) - 1.0) * 0.8
			var want := origin + fwd * 1.4 + side + Vector3.UP * (0.9 + 0.3 * (i / 3))
			# Never inside a wall or pillar: stop short of whatever is in the way.
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(centre, want, 1))
			if not hit.is_empty():
				want = hit["position"] + (centre - want).normalized() * 0.35
			body.global_position = want
			body.rotation.y = randf() * TAU
			body.apply_central_impulse((fwd * 1.5 + Vector3.UP * 2.0) * body.mass * 0.5)
			out.append(body)
			i += 1
	return out
