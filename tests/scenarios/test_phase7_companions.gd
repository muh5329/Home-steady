extends TestCase
## Phase 7: recruit a stranger; the same character follows, fights, holds,
## goes home and works. Driven through the talk panel and the party key.

const SANDBOX := "res://tests/fixtures/sandbox.tscn"
const ENEMY := "res://characters/npc/enemy.tscn"
const SKELETON := "res://data/enemies/skeleton_warrior.tres"
const TENT := "res://settlement/props/tent.tscn"

var world: Region
var player: Player
var population: Population
var panel: TalkPanel
var party: Party


func _setup_world() -> void:
	world = spawn(SANDBOX)
	player = world.player
	population = world.get_node("Population")
	panel = world.get_node("TalkPanel")
	party = player.get_node("Party")
	player.camera_rig.yaw = 0.0
	player.controller.input_enabled = false
	await wait_seconds(0.3)


func _class(id: String) -> CharacterClassData:
	return load("res://data/classes/%s.tres" % id)


func _job(id: String) -> JobDefinition:
	return load("res://data/jobs/%s.tres" % id)


func _tent(pos: Vector3) -> Node3D:
	var t: Node3D = load(TENT).instantiate()
	t.position = pos
	world.get_node("NavigationRegion3D").add_child(t)
	return t


func _rebake() -> void:
	world.navigation_region.bake_navigation_mesh(false)
	await wait_physics_frames(2)


func _enemy(pos: Vector3, thinking := true) -> Enemy:
	var e: Enemy = load(ENEMY).instantiate()
	e.definition = load(SKELETON)
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.controller.set_physics_process(thinking)
	return e


## A ready companion: spawned as a settler and put in the party.
func _companion(class_id: String, pos: Vector3, settler_name := "Vesna") -> Settler:
	var s := population.spawn_settler(pos, settler_name, "", null, _class(class_id))
	await wait_physics_frames(2)
	check(s.join_party(), "%s joined the party" % settler_name)
	return s


func _option(label: String) -> int:
	var texts := panel.option_texts()
	for i in texts.size():
		if texts[i].contains(label):
			return i
	return -1


func _talk_to(s: Settler) -> void:
	player.controller.input_enabled = true
	player.motor.face(s.global_position - player.global_position, true)
	await wait_seconds(0.3)
	await tap(&"interact")
	await wait_seconds(0.2)


# --- recruitment ----------------------------------------------------------------------

func test_stranger_needs_a_free_bed_to_join() -> void:
	await _setup_world()
	var s := population.spawn_settler(Vector3(0, 0.05, -1.6), "Vesna", "", null, _class("ranger"), Settler.Mode.STRANGER)
	await wait_seconds(0.2)
	var settlement := Settlement.of(player)
	check(not s.is_member(), "a stranger is not a settler")
	check_eq(settlement.settler_count(), 0, "not counted as a settler")
	check_eq(s.combat.faction, &"neutral", "strangers stay out of fights")
	await _talk_to(s)
	check(panel.is_open() and panel.speaker == s, "talk panel opened")
	var invite := _option("Invite")
	check(invite == 0, "invite offered (%s)" % [panel.option_texts()])
	await tap_key(KEY_1 + invite)
	await wait_seconds(0.2)
	check(not s.is_member(), "no bed: can't move in")
	check(panel.is_open(), "panel stays open")
	# Build somewhere to sleep, then ask again.
	var tent := _tent(Vector3(6, 0, 4))
	await wait_physics_frames(2)
	check_eq(settlement.free_beds(), 2, "a tent sleeps two")
	panel.open(s)  # refresh the options
	await tap_key(KEY_1 + _option("Invite"))
	await wait_seconds(0.2)
	check(s.is_member(), "joined the settlement")
	check_eq(s.combat.faction, &"player", "fights for us now")
	check_eq(settlement.free_beds(), 1, "took a bed")
	check(s.worker.home_position.distance_to(tent.global_position) < 4.0, "lives by the tent")
	check(_option("Join my party") >= 0, "panel now offers worker options (%s)" % [panel.option_texts()])


func test_enemies_ignore_strangers() -> void:
	await _setup_world()
	player.global_position = Vector3(30, 0.05, 30)
	var s := population.spawn_settler(Vector3(0, 0.05, -3), "Vesna", "", null, _class("ranger"), Settler.Mode.STRANGER)
	var e := _enemy(Vector3(0, 0.05, -7))
	await wait_seconds(4.0)
	check(e.controller.target == null or e.controller.target.body != s, "skeleton did not target the stranger")
	check_eq(s.health.current, s.health.max_health, "stranger unharmed")


# --- party --------------------------------------------------------------------------------

func test_join_party_through_talk_and_follow() -> void:
	await _setup_world()
	var s := population.spawn_settler(Vector3(0, 0.05, -1.6), "Bjorn", "", _job("woodcutter"))
	await wait_physics_frames(2)
	await _talk_to(s)
	await tap_key(KEY_1 + _option("Join my party"))
	await wait_seconds(0.3)
	check_eq(s.mode, Settler.Mode.COMPANION, "is a companion")
	check(party.has(s), "in the party")
	check(not panel.is_open(), "panel closed after joining")
	check(_held(s.equipment.model_root, "HandAxe"), "weapon in hand")
	# Walk away; the companion keeps up.
	player.controller.input_enabled = true
	await hold(&"move_forward", 4.0)
	await wait_seconds(1.5)
	var d := s.global_position.distance_to(player.global_position)
	check(d < 6.0, "followed the player (%.1f m away)" % d)
	check(player.global_position.distance_to(Vector3(0, 0, 0)) > 10.0, "player really moved")
	check_eq(s.companion.activity, "Following", "says Following")


func test_party_holds_three_companions() -> void:
	await _setup_world()
	var members: Array[Settler] = []
	for i in 4:
		members.append(population.spawn_settler(Vector3(-4 + i * 2, 0.05, 4), "S%d" % i))
	await wait_physics_frames(2)
	for i in 3:
		check(members[i].join_party(), "companion %d joins" % i)
	check(not members[3].join_party(), "fourth is refused")
	check(members[3].party_blocker().contains("full"), "reason: party full")
	check_eq(party.members().size(), 3, "three in the party")
	members[0].send_home()
	check_eq(party.members().size(), 2, "sending one home frees a slot")
	check(members[3].join_party(), "now the fourth can join")


func test_hold_and_follow_with_party_key() -> void:
	await _setup_world()
	var s := await _companion("villager", Vector3(-2, 0.05, 2))
	await wait_seconds(0.5)
	player.controller.input_enabled = true
	await tap(&"party_order")
	await wait_seconds(0.2)
	check_eq(s.companion.order, CompanionController.Order.HOLD, "T: hold")
	var held_at := s.global_position
	await hold(&"move_forward", 3.0)
	await wait_seconds(1.0)
	check(s.global_position.distance_to(held_at) < 1.5, "stayed put while the player left")
	check_eq(s.companion.activity, "Holding position", "says Holding")
	await tap(&"party_order")
	await wait_seconds(4.0)
	check_eq(s.companion.order, CompanionController.Order.FOLLOW, "T again: follow")
	check(s.global_position.distance_to(player.global_position) < 6.0, "caught up")


# --- combat -------------------------------------------------------------------------------

func test_melee_companion_fights_and_kills() -> void:
	await _setup_world()
	var s := await _companion("fighter", Vector3(0, 0.05, 2), "Hild")
	var e := _enemy(Vector3(0, 0.05, -8))
	var engaged := await wait_until(func(): return s.companion.state_machine.current_name() == &"Attack", 6.0)
	check(engaged, "engaged the skeleton")
	var dead := await wait_until(func(): return not e.combat.is_alive(), 45.0)
	check(dead, "companion killed the skeleton (hp %.0f)" % e.health.current)
	var back := await wait_until(func(): return s.companion.state_machine.current_name() == &"Follow", 5.0)
	check(back, "back to following afterwards")


func test_ranged_companion_shoots_and_uses_ability() -> void:
	await _setup_world()
	var s := await _companion("ranger", Vector3(0, 0.05, 2))
	var used := [false]
	s.abilities.ability_used.connect(func(_i, _a): used[0] = true)
	var e := _enemy(Vector3(0, 0.05, -10), false)
	var hurt := await wait_until(func(): return e.health.current < e.health.max_health, 8.0)
	check(hurt, "bolts hit the skeleton")
	check(s.global_position.distance_to(e.global_position) > 4.0, "kept her distance")
	var volley := await wait_until(func(): return used[0], 10.0)
	check(volley, "used Volley")


func test_companion_defends_the_player() -> void:
	await _setup_world()
	var s := await _companion("villager", Vector3(0, 0.05, 3))
	var near := _enemy(Vector3(-3, 0.05, -3), false)
	var attacker := _enemy(Vector3(8, 0.05, -8), false)
	var engaged := await wait_until(func(): return s.companion.target == near.combat, 3.0)
	check(engaged, "first goes for the nearest skeleton")
	# The further skeleton hits the player: the companion switches to it.
	var ev := DamageEvent.create(attacker, 5.0, DamageEvent.Type.PHYSICAL)
	ev.source_combatant = attacker.combat
	player.combat.receiver.receive(ev)
	await wait_seconds(0.5)
	check(s.companion.target == attacker.combat, "switched to the player's attacker")


func test_retreats_when_badly_hurt_then_recovers() -> void:
	await _setup_world()
	var s := await _companion("villager", Vector3(0, 0.05, 3))
	var e := _enemy(Vector3(0, 0.05, -4), false)
	await wait_until(func(): return s.companion.state_machine.current_name() == &"Attack", 5.0)
	s.health.set_current(s.health.max_health * 0.2)
	var fled := await wait_until(func(): return s.companion.state_machine.current_name() == &"Retreat", 2.0)
	check(fled, "retreats at low health")
	e.queue_free()
	var healed := await wait_until(func(): return s.health.ratio() >= CompanionController.RECOVERED_HEALTH, 30.0)
	check(healed, "rested back to health out of combat (%.0f%%)" % (s.health.ratio() * 100))
	var rejoined := await wait_until(func(): return s.companion.state_machine.current_name() == &"Follow", 3.0)
	check(rejoined, "rejoined the player")


func test_player_revives_downed_companion() -> void:
	await _setup_world()
	var s := await _companion("villager", Vector3(0, 0.05, -1.6))
	await wait_seconds(0.3)
	s.companion.set_order(CompanionController.Order.HOLD)
	s.health.take(9999)
	await wait_seconds(0.3)
	check(s.is_downed(), "downed")
	check(s.interactable.prompt.begins_with("Revive"), "prompt: %s" % s.interactable.prompt)
	check(party.has(s), "still in the party while downed")
	await _talk_to(s)
	check(not panel.is_open(), "reviving doesn't open the talk panel")
	var up := await wait_until(func(): return not s.is_downed(), 3.0)
	check(up, "revived by the player")
	check_near(s.health.ratio(), Settler.REVIVE_HEALTH, 0.1, "half health after revive")
	check_eq(s.companion.state_machine.current_name(), &"Hold", "back to their order")


# --- the same character back at work ------------------------------------------------------

func test_sent_home_goes_back_to_work() -> void:
	await _setup_world()
	var pile: Stockpile = load("res://settlement/storage/stockpile.tscn").instantiate()
	pile.position = Vector3(-6, 0, 8)
	world.get_node("NavigationRegion3D").add_child(pile)
	var tree := ResourceNode.new()
	tree.definition = load("res://data/resource_nodes/pine_tree.tres")
	tree.position = Vector3(-10, 0, 4)
	world.get_node("NavigationRegion3D").add_child(tree)
	await _rebake()
	var s := population.spawn_settler(Vector3(-6, 0.05, 5), "Vesna", "", _job("woodcutter"), _class("ranger"))
	await wait_physics_frames(2)
	var home := s.worker.home_position
	check(s.join_party(), "joins the party")
	player.global_position = Vector3(12, 0.05, -10)
	await wait_seconds(4.0)
	check(s.global_position.distance_to(home) > 8.0, "went adventuring with the player")
	check(not s.worker.is_running(), "worker brain paused")
	await _talk_to(s)
	player.global_position = s.global_position + Vector3(0, 0, 1.4)
	panel.open(s)
	await tap_key(KEY_1 + _option("Go home"))
	await wait_seconds(0.3)
	check_eq(s.mode, Settler.Mode.WORKER, "is a worker again")
	check(not party.has(s), "left the party")
	check(not _held(s.equipment.model_root, "Crossbow"), "crossbow put away")
	var delivered := await wait_until(func(): return pile.inventory.count(&"item.log") >= 1, 90.0)
	check(delivered, "walked home, chopped and hauled a log")


func test_companion_survives_save_load() -> void:
	await _setup_world()
	var s := await _companion("ranger", Vector3(-2, 0.05, 2))
	s.worker.set_job(_job("miner"))
	s.order_hold(Vector3(-3, 0, 1))
	var stranger := population.spawn_settler(Vector3(5, 0.05, 5), "Ilse", "", null, _class("wizard"), Settler.Mode.STRANGER)
	stranger.greeting = "Hello there."
	await wait_seconds(0.3)
	SaveManager.save_game("test_p7")
	SaveManager.load_game("test_p7")
	await wait_seconds(0.5)
	var all := population.settlers()
	check_eq(all.size(), 2, "two people restored")
	var v: Settler = null
	var i: Settler = null
	for x in all:
		if x.settler_name == "Vesna":
			v = x
		elif x.settler_name == "Ilse":
			i = x
	check(v != null and i != null, "both by name")
	if v:
		check_eq(v.mode, Settler.Mode.COMPANION, "still a companion")
		check_eq(v.character_class.id, &"class.ranger", "still a ranger")
		check_eq(String(v.model_root.name), "Ranger", "ranger body")
		check_eq(v.worker.job.id, &"job.miner", "still a miner at heart")
		check_eq(v.companion.order, CompanionController.Order.HOLD, "still holding")
		check(party.has(v), "party rebuilt from the save")
		check_eq(party.members().size(), 1, "no stale party members")
	if i:
		check_eq(i.mode, Settler.Mode.STRANGER, "stranger stays a stranger")
		check_eq(i.greeting, "Hello there.", "greeting kept")
	SaveManager.delete_save("test_p7")


func test_hud_shows_party_frames() -> void:
	world = spawn("res://world/regions/test_arena.tscn")
	player = world.player
	party = player.get_node("Party")
	await wait_seconds(0.5)
	var vesna: Settler = world.get_node("Population/Vesna")
	check_eq(vesna.mode, Settler.Mode.STRANGER, "Vesna waits in the arena as a stranger")
	check(vesna.worker.job == null, "she arrives without a job (you pick one)")
	check_eq(Settlement.of(player).free_beds(), 1, "the camp has a bed for her")
	check(vesna.recruit(), "recruited")
	check(vesna.join_party(), "joined")
	await wait_seconds(0.2)
	var hud: HUD = world.get_node("HUD")
	check_eq(hud._party_rows.size(), 1, "one party frame")
	vesna.health.take(9999)
	await wait_seconds(0.2)
	hud._update_party()
	check(hud._party_rows[0].status.text.contains("DOWNED"), "frame shows downed")


# --- critic regressions (round 6) -------------------------------------------------------

func after_each() -> void:
	GameManager.selected_class = null


func test_loading_with_talk_panel_open_closes_it() -> void:
	await _setup_world()
	var s := population.spawn_settler(Vector3(0, 0.05, -1.6), "Bjorn")
	await wait_seconds(0.2)
	SaveManager.save_game("test_p7_panel")
	await _talk_to(s)
	check(panel.is_open(), "talking")
	SaveManager.load_game("test_p7_panel")  # frees the speaker
	await wait_seconds(0.4)
	check(not panel.is_open(), "panel closed on load")
	check(player.controller.input_enabled, "controls restored")
	check(not panel._blocker.visible, "no invisible click-blocker left behind")
	SaveManager.delete_save("test_p7_panel")


func test_talk_panel_closes_when_player_is_hurt() -> void:
	await _setup_world()
	var s := population.spawn_settler(Vector3(0, 0.05, -1.6), "Bjorn")
	await wait_seconds(0.2)
	await _talk_to(s)
	check(panel.is_open(), "talking")
	var e := _enemy(Vector3(5, 0.05, 5), false)
	var ev := DamageEvent.create(e, 5.0, DamageEvent.Type.PHYSICAL)
	ev.source_combatant = e.combat
	player.combat.receiver.receive(ev)
	await wait_seconds(0.3)
	check(not panel.is_open(), "a hit ends the conversation")
	check(player.controller.input_enabled, "player can defend themselves")


func test_bolts_and_blasts_pass_through_strangers() -> void:
	GameManager.selected_class = _class("ranger")
	await _setup_world()
	var s := population.spawn_settler(Vector3(0, 0.05, -5), "Vesna", "", null, _class("ranger"), Settler.Mode.STRANGER)
	var e := _enemy(Vector3(0, 0.05, -12), false)
	await wait_seconds(0.3)
	player.controller.input_enabled = true
	await tap(&"attack_light")
	await wait_seconds(1.2)
	check_eq(s.health.current, s.health.max_health, "stranger unharmed by the bolt")
	check(e.health.current < e.health.max_health, "the bolt flew on and hit the skeleton")
	# Area damage ignores them too.
	var blast := DamageEvent.create(e, 50.0, DamageEvent.Type.FIRE)
	blast.source_combatant = e.combat
	s.combat.receiver.receive(blast)
	check_eq(s.health.current, s.health.max_health, "direct damage ignored")
	check(not s.combat.receiver.can_be_hit_by(&"enemy"), "not hittable by anyone")


func test_hurt_companion_retreats_instead_of_standing_there() -> void:
	await _setup_world()
	var s := await _companion("villager", Vector3(0, 0.05, 3))
	await wait_seconds(0.5)
	s.health.set_current(s.health.max_health * 0.2)
	_enemy(Vector3(3, 0.05, -1), true)
	var fled := await wait_until(func(): return s.companion.state_machine.current_name() == &"Retreat", 3.0)
	check(fled, "falls back when hurt and threatened (state %s)" % s.companion.state_machine.current_name())


func test_companion_gets_up_by_themselves_able_to_fight() -> void:
	await _setup_world()
	var s := await _companion("villager", Vector3(0, 0.05, 3))
	await wait_seconds(0.3)
	s.health.take(9999)
	var up := await wait_until(func(): return not s.is_downed(), CompanionController.DOWNED_SECONDS + 2.0)
	check(up, "recovered unaided")
	check(s.health.ratio() > CompanionController.RETREAT_HEALTH, "recovers above the retreat threshold (%.2f)" % s.health.ratio())


func test_downed_state_survives_save_load() -> void:
	await _setup_world()
	var s := await _companion("villager", Vector3(0, 0.05, 3))
	await wait_seconds(0.3)
	s.health.take(9999)
	await wait_seconds(0.2)
	SaveManager.save_game("test_p7_down")
	SaveManager.load_game("test_p7_down")
	await wait_seconds(0.4)
	var all := population.settlers()
	check_eq(all.size(), 1, "one settler")
	if all.size() == 1:
		check(all[0].is_downed(), "still downed after loading")
		check(party.has(all[0]), "still in the party")
		check(all[0].interactable.prompt.begins_with("Revive"), "can be revived")
	SaveManager.delete_save("test_p7_down")


func test_companions_do_not_block_the_player() -> void:
	await _setup_world()
	var s := await _companion("villager", Vector3(0, 0.05, -2))
	s.order_hold()
	await wait_seconds(0.5)
	player.controller.input_enabled = true
	await hold(&"move_forward", 1.5)
	check(player.global_position.z < -3.0, "walked straight through the companion (z %.1f)" % player.global_position.z)


## A hand-held item (attached scene) is in the hand and showing.
func _held(model: Node, item_name: String) -> bool:
	var item := model.find_child(item_name, true, false) as Node3D
	return item != null and not item.is_queued_for_deletion() and not item.get_parent().is_queued_for_deletion() and item.is_visible_in_tree()
