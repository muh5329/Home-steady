class_name Passage
extends Node3D
## A way between two places (crypt door ⇄ crypt stairs, later cave mouths
## and region borders). Passages with the same `link` are partners: using
## one fades out, moves the player and every following companion to the
## partner's Arrival marker, and fades back in.

signal traveled(player: Player)

const GROUP := &"passages"
const FADE_SECONDS := 0.3

@export var link: StringName
@export var prompt := "Enter"

@onready var interactable: Interactable = $Interactable
@onready var arrival: Marker3D = $Arrival

var _travelling := false
## Bumped by a load: a trip in progress must not teleport the loaded player.
var _trip := 0


func _ready() -> void:
	add_to_group(GROUP)
	EventBus.game_loaded.connect(func(_slot): _trip += 1)
	interactable.prompt = prompt
	interactable.interacted.connect(_on_interacted)


## Never leave the screen black if the world goes away mid-trip.
func _exit_tree() -> void:
	if _travelling and is_inside_tree():
		ScreenFade.fade(get_tree(), 0.0, 0.01)


func partner() -> Passage:
	for p in get_tree().get_nodes_in_group(GROUP):
		if p != self and p.link == link:
			return p
	return null


func _on_interacted(by: InteractionController) -> void:
	var player := by.body as Player
	if player:
		travel(player)


func travel(player: Player) -> void:
	var to := partner()
	if to == null or _travelling or not player.combat.is_alive():
		return
	_travelling = true
	var trip := _trip
	player.controller.input_enabled = false
	await ScreenFade.fade(get_tree(), 1.0, FADE_SECONDS)
	if is_instance_valid(player) and player.combat.is_alive() and trip == _trip:
		_move_party(player, to.arrival.global_transform)
		# Let physics (ambience zones, focus) catch up before revealing.
		await get_tree().physics_frame
		await get_tree().physics_frame
	await ScreenFade.fade(get_tree(), 0.0, FADE_SECONDS)
	_travelling = false
	if is_instance_valid(player):
		player.controller.input_enabled = true
		traveled.emit(player)


func _move_party(player: Player, to: Transform3D) -> void:
	var facing := -to.basis.z
	player.global_position = to.origin
	player.velocity = Vector3.ZERO
	player.motor.face(facing, true)
	player.camera_rig.yaw = rad_to_deg(atan2(-facing.x, -facing.z))
	player.camera_rig.snap()
	var party := Party.of(player)
	if party == null:
		return
	for m in party.members():
		if m.is_downed() or m.companion.order != CompanionController.Order.FOLLOW:
			continue  # holding or down: they stay where they are
		m.companion.teleport_to_leader()
