extends TestCase
## Phase 8 (part 1): the Abandoned Crypt — generated from a layout,
## entered through a passage with the party, torch-lit, with spawns that
## stay cleared, ranged skeletons, a treasure chest and a spike hall.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const CRYPT := "res://dungeons/crypt/crypt.tscn"
const ENTRANCE := "res://dungeons/crypt/crypt_entrance.tscn"
const ENEMY := "res://characters/npc/enemy.tscn"

var world: Region
var player: Player
var crypt: Node3D
var builder: DungeonBuilder
var population: Population


func _setup(with_entrance := false) -> void:
	world = spawn(SANDBOX)
	player = world.player
	population = world.get_node("Population")
	player.controller.input_enabled = false
	if with_entrance:
		var e: Node3D = load(ENTRANCE).instantiate()
		e.position = Vector3(0, 0, -10)
		world.get_node("NavigationRegion3D").add_child(e)
	crypt = load(CRYPT).instantiate()
	crypt.position = Vector3(400, 0, 0)
	world.add_child(crypt)
	builder = crypt.get_node("NavigationRegion3D/Builder")
	await wait_seconds(0.3)


func _cell(symbol: String, index := 0) -> Vector3:
	return builder.cell_global(builder.layout.find(symbol)[index])


func _place_player(at: Vector3) -> void:
	player.global_position = at + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	await wait_physics_frames(3)


func _enemy(def_path: String, pos: Vector3) -> Enemy:
	var e: Enemy = load(ENEMY).instantiate()
	e.definition = load(def_path)
	e.position = pos
	world.get_node("Enemies").add_child(e)
	return e


# --- the space --------------------------------------------------------------------------------

func test_crypt_is_built_walkable_and_walled() -> void:
	await _setup()
	check(builder.is_built(), "builder ran")
	var map := world.get_world_3d().navigation_map
	await wait_until(func(): return NavigationServer3D.map_get_iteration_id(map) > 0, 2.0)
	var from := _cell("E")
	var to := _cell("M")
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	check(path.size() > 2, "a navigable route leads from the exit to the elite room (%d points)" % path.size())
	if path.size() > 0:
		check(path[path.size() - 1].distance_to(to) < 1.5, "the route reaches it")
	# Solid floor and walls where the layout says.
	var space := world.get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * 3, from + Vector3.DOWN * 3, 1))
	check(not down.is_empty(), "floor under the exit")
	var e_cell: Vector2i = builder.layout.find("E")[0]
	var north := builder.cell_global(e_cell + Vector2i(0, -1))
	var across := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP, north + Vector3.UP, 1))
	check(not across.is_empty(), "a wall between the exit and the rock behind it")
	check(builder.find_children("*", "MultiMeshInstance3D", false, false).size() >= 3, "floors, walls, pillars drawn as multimeshes")
	check(builder.find_children("*", "OmniLight3D", true, false).size() >= 8, "torch-lit")


func test_passage_takes_the_party_down_and_back() -> void:
	await _setup(true)
	var s := population.spawn_settler(Vector3(1.5, 0.05, 2), "Hild", "", null, load("res://data/classes/fighter.tres"))
	await wait_physics_frames(2)
	s.join_party()
	var entrance: Passage = world.get_node("NavigationRegion3D/CryptEntrance/Passage")
	await _place_player(entrance.global_position + Vector3(0, 0, 1.6))
	player.motor.face(Vector3.FORWARD, true)
	player.controller.input_enabled = true
	await wait_seconds(0.3)
	check(player.interaction.focused == entrance.interactable, "the crypt door is focused")
	await tap(&"interact")
	var inside := await wait_until(func(): return player.global_position.x > 300.0 and player.controller.input_enabled, 3.0)
	check(inside, "travelled into the crypt")
	var zone: AmbienceZone = crypt.get_node("Ambience")
	check(zone.is_active(), "crypt ambience on")
	check(not world.get_node("Sun").visible, "no sunlight underground")
	check(s.global_position.distance_to(player.global_position) < 6.0, "companion came along (%.1f m)" % s.global_position.distance_to(player.global_position))
	# And back out.
	var exit_passage := _exit_passage()
	await _place_player(exit_passage.arrival.global_position)
	player.motor.face(exit_passage.global_position - player.global_position, true)
	await wait_seconds(0.3)
	exit_passage.travel(player)
	var out := await wait_until(func(): return player.global_position.x < 100.0 and player.controller.input_enabled, 3.0)
	check(out, "climbed back out")
	await wait_physics_frames(3)
	check(not zone.is_active(), "outdoor ambience restored")
	check(world.get_node("Sun").visible, "sun back")


func _exit_passage() -> Passage:
	for p in get_tree().get_nodes_in_group(Passage.GROUP):
		if p.global_position.x > 300.0:
			return p
	return null


# --- monsters ---------------------------------------------------------------------------------

func test_spawns_rise_near_the_player_and_stay_defeated() -> void:
	await _setup()
	var spawn: EnemySpawn = null
	for sp in get_tree().get_nodes_in_group(EnemySpawn.GROUP):
		if sp.definition.id == &"enemy.skeleton_warrior":
			spawn = sp
			break
	check(spawn != null, "a warrior spawn exists")
	check(spawn.enemy == null, "nothing spawned while the party is far away")
	await _place_player(spawn.global_position + Vector3(0, 0, 8))
	var up := await wait_until(func(): return is_instance_valid(spawn.enemy), 2.0)
	check(up, "the skeleton rose as the player came near")
	SaveManager.save_game("test_p8")
	spawn.enemy.health.take(9999)
	await wait_physics_frames(2)
	check(spawn.is_defeated, "defeated")
	SaveManager.save_game("test_p8_dead")
	# Loading the earlier save resets it; loading the later one keeps it dead.
	SaveManager.load_game("test_p8")
	await wait_seconds(1.2)
	check(not spawn.is_defeated, "earlier save: not yet defeated")
	check(is_instance_valid(spawn.enemy) and spawn.enemy.combat.is_alive(), "rises again")
	SaveManager.load_game("test_p8_dead")
	await wait_seconds(1.2)
	check(spawn.is_defeated and (spawn.enemy == null or not spawn.enemy.combat.is_alive()), "later save: stays dead")
	SaveManager.delete_save("test_p8")
	SaveManager.delete_save("test_p8_dead")


func test_monsters_do_not_see_through_walls() -> void:
	await _setup()
	_silence_spawns()
	# An archer (15 m aggro) at the back of the entrance hall; the player
	# 11 m away in the room below, with solid rock in between.
	var e := _enemy("res://data/enemies/skeleton_archer.tres", builder.cell_global(Vector2i(9, 4)))
	e.controller.set_physics_process(true)
	await _place_player(builder.cell_global(Vector2i(11, 7)))
	await wait_seconds(0.6)
	check(e.controller.target == null, "no aggro through solid rock")
	await _place_player(builder.cell_global(Vector2i(9, 2)))
	var seen := await wait_until(func(): return e.controller.target != null, 2.0)
	check(seen, "notices the player in the same hall")


func test_archer_shoots_from_range() -> void:
	await _setup()
	_silence_spawns()
	var room := builder.cell_global(Vector2i(7, 7))  # a row without pillars
	var a := _enemy("res://data/enemies/skeleton_archer.tres", room + Vector3(-9, 0, 0))
	await _place_player(room + Vector3(3, 0, 0))
	var hurt := await wait_until(func(): return player.health.current < player.health.max_health, 8.0)
	check(hurt, "bone bolts hit the player")
	check(a.global_position.distance_to(player.global_position) > 6.0, "kept its distance")
	check_eq(a.controller.state_machine.current_name(), &"Shoot", "uses the ranged state")


## Keeps the layout's own monsters in the ground (isolated tests).
func _silence_spawns() -> void:
	for sp in get_tree().get_nodes_in_group(EnemySpawn.GROUP):
		sp.is_defeated = true


# --- treasure and hazard ----------------------------------------------------------------------

func test_chest_spills_loot_once() -> void:
	await _setup()
	_silence_spawns()
	var chest := _find_chest()
	check(chest != null, "a chest in the treasure room")
	await _place_player(chest.global_position + chest.global_basis.z * 1.6)
	player.motor.face(chest.global_position - player.global_position, true)
	player.controller.input_enabled = true
	await wait_seconds(0.3)
	await tap(&"interact")
	await wait_seconds(1.0)
	check(chest.is_open, "opened")
	var ore := _loose(&"item.iron_ore")
	check_eq(ore, 3, "three iron ore spilled out")
	SaveManager.save_game("test_p8_chest")
	SaveManager.load_game("test_p8_chest")
	await wait_seconds(0.3)
	check(chest.is_open and not chest.interactable.enabled, "stays open after loading")
	check_eq(_loose(&"item.iron_ore"), 3, "no extra loot")
	SaveManager.delete_save("test_p8_chest")


func _find_chest() -> Chest:
	for n in builder.get_children():
		if n is Chest:
			return n
	return null


func _loose(id: StringName) -> int:
	var n := 0
	for c in world.get_node("Props").get_children():
		if c is Carryable and c.item_id == id:
			n += 1
	return n


func test_spike_hall_hurts_the_player_but_not_companions() -> void:
	await _setup()
	_silence_spawns()
	var cell := _cell("S", 5)
	var s := population.spawn_settler(cell + Vector3(0.6, 0.05, 0), "Hild", "", null, load("res://data/classes/fighter.tres"))
	await wait_physics_frames(2)
	s.join_party()
	s.order_hold()
	await _place_player(cell)
	var hurt := await wait_until(func(): return player.health.current < player.health.max_health, 4.0)
	check(hurt, "spikes hurt the player")
	check_eq(s.health.current, s.health.max_health, "companion unharmed")
	var trap: SpikeTrap = null
	for n in builder.get_children():
		if n is SpikeTrap:
			trap = n
			break
	var saw_down := false
	var saw_up := false
	for i in 40:
		await wait_seconds(0.1)
		saw_down = saw_down or trap.stage() == 0
		saw_up = saw_up or trap.stage() == 2
	check(saw_down and saw_up, "spikes cycle down and up")


# --- critic regressions (round 7) -------------------------------------------------------

func test_camera_arrives_with_the_player() -> void:
	await _setup(true)
	var entrance: Passage = world.get_node("NavigationRegion3D/CryptEntrance/Passage")
	entrance.travel(player)
	await wait_until(func(): return ScreenFade.is_black(get_tree()), 2.0)
	await wait_until(func(): return player.global_position.x > 300.0, 1.0)
	await wait_physics_frames(1)
	var cam := player.camera_rig.global_position
	check(cam.distance_to(player.global_position) < 3.0, "camera already at the player before the fade-in (%.1f m)" % cam.distance_to(player.global_position))
	await wait_until(func(): return player.controller.input_enabled, 2.0)


func test_loading_inside_and_dying_inside_keep_ambience_right() -> void:
	await _setup()
	_silence_spawns()
	var zone: AmbienceZone = crypt.get_node("Ambience")
	await _place_player(_cell("E") + Vector3(0, 0, 4))
	await wait_physics_frames(3)
	check(zone.is_active(), "inside: crypt ambience")
	SaveManager.save_game("test_p8_inside")
	await _place_player(Vector3(0, 0.05, 0))
	await wait_physics_frames(3)
	check(not zone.is_active(), "outside: normal ambience")
	SaveManager.load_game("test_p8_inside")
	await wait_physics_frames(4)
	check(zone.is_active(), "loading a save made in the crypt puts the ambience back")
	check(not world.get_node("Sun").visible, "sun off")
	player.health.take(9999)
	var back := await wait_until(func(): return player.combat.is_alive(), world.respawn_delay + 2.0)
	check(back, "respawned")
	await wait_physics_frames(4)
	check(not zone.is_active() and world.get_node("Sun").visible, "respawning at camp restores the outdoors")
	check_eq(player.camera_rig.max_pitch_override, INF, "camera pitch unlocked outdoors")
	SaveManager.delete_save("test_p8_inside")


func test_companions_ignore_monsters_behind_rock() -> void:
	await _setup()
	_silence_spawns()
	await _place_player(builder.cell_global(Vector2i(9, 2)))
	var s := population.spawn_settler(builder.cell_global(Vector2i(8, 3)) + Vector3.UP * 0.05, "Hild", "", null, load("res://data/classes/fighter.tres"))
	await wait_physics_frames(2)
	s.join_party()
	# A skeleton in the room below, within 13 m of the player but behind rock.
	var e := _enemy("res://data/enemies/skeleton_warrior.tres", builder.cell_global(Vector2i(11, 7)))
	e.controller.set_physics_process(false)
	await wait_seconds(1.0)
	check(s.companion.target == null, "no fighting through the wall")
	check_eq(s.companion.state_machine.current_name(), &"Follow", "keeps following")


func test_hidden_nearest_does_not_mask_a_visible_target() -> void:
	await _setup()
	# Overworld: a wall hides a settler right next to the skeleton; the
	# player stands in the open further away.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.5)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1.5, -6)
	world.add_child(wall)
	var e := _enemy("res://data/enemies/skeleton_warrior.tres", Vector3(0, 0.05, -8))
	population.spawn_settler(Vector3(0, 0.05, -4.5), "Hidden").worker.set_physics_process(false)
	await _place_player(Vector3(6, 0.05, -8))
	var seen := await wait_until(func(): return e.controller.target != null, 2.0)
	check(seen and e.controller.target == player.combat, "targets the visible player")


func test_monsters_are_immune_to_their_traps() -> void:
	await _setup()
	_silence_spawns()
	var e := _enemy("res://data/enemies/skeleton_warrior.tres", _cell("S", 5))
	e.controller.set_physics_process(false)
	await wait_seconds(3.5)
	check_eq(e.health.current, e.health.max_health, "skeleton walks the spike hall unharmed")


func test_props_have_stable_cell_names() -> void:
	await _setup()
	var chest := _find_chest()
	var cell: Vector2i = builder.layout.find("C")[0]
	check(chest.name.ends_with("_%d_%d" % [cell.x, cell.y]), "chest named by its cell (%s)" % chest.name)


func test_rushed_archer_backs_off_along_the_floor() -> void:
	await _setup()
	_silence_spawns()
	var room := builder.cell_global(Vector2i(7, 7))
	var a := _enemy("res://data/enemies/skeleton_archer.tres", room)
	await _place_player(room + Vector3(2.5, 0, 0))
	var start := a.global_position.distance_to(player.global_position)
	var backed := await wait_until(func(): return a.global_position.distance_to(player.global_position) > start + 1.5, 6.0)
	check(backed, "backed away from a player at point-blank (%.1f m -> %.1f m)" % [start, a.global_position.distance_to(player.global_position)])
	var space := world.get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(a.global_position + Vector3.UP, a.global_position + Vector3.DOWN, 1))
	check(not down.is_empty(), "still standing on the crypt floor")
