class_name NavRebake
## Debounced asynchronous navmesh rebakes. Anything that changes static
## geometry (a finished building, an opened door) queues its region; a
## request made while a bake is running is re-queued, never dropped.

static var _pending: Dictionary = {}  # region instance id -> true


static func queue(region: NavigationRegion3D, delay := 0.2) -> void:
	if region == null or not region.is_inside_tree():
		return
	var id := region.get_instance_id()
	if _pending.has(id):
		return
	_pending[id] = true
	await region.get_tree().create_timer(delay).timeout
	_pending.erase(id)
	if not is_instance_valid(region) or not region.is_inside_tree():
		return
	if region.is_baking():
		region.bake_finished.connect(func(): NavRebake.queue(region, delay), CONNECT_ONE_SHOT)
	else:
		region.bake_navigation_mesh(true)


## The NavigationRegion3D that owns `node`'s geometry, if any.
static func region_of(node: Node) -> NavigationRegion3D:
	var n := node.get_parent()
	while n and not n is NavigationRegion3D:
		n = n.get_parent()
	return n as NavigationRegion3D
