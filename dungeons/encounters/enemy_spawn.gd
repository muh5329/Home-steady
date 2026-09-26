class_name EnemySpawn
extends Marker3D
## Raises one monster when the player comes near, and remembers when it
## has been defeated so cleared dungeon rooms stay cleared (saved).
## Unspawned monsters cost nothing: a dungeon only simulates what the
## party has reached.

signal defeated

const GROUP := &"enemy_spawns"
const ENEMY_SCENE := preload("res://characters/npc/enemy.tscn")

@export var definition: EnemyDefinition
@export var activation_radius := 20.0

var enemy: Enemy
var is_defeated := false

var _check := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveManager.GROUP)
	_check = randf() * 0.5


func _physics_process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	if is_defeated or is_instance_valid(enemy):
		return
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Node3D
	if player and player.global_position.distance_to(global_position) <= activation_radius \
			and _visible_from(player):
		spawn()


func spawn() -> Enemy:
	if is_instance_valid(enemy) or is_defeated:
		return enemy
	enemy = ENEMY_SCENE.instantiate()
	enemy.definition = definition
	enemy.transform = transform  # same parent: set before entering the tree
	get_parent().add_child(enemy)
	enemy.combat.died.connect(_on_enemy_died)
	if definition.spawn_animation != &"":
		enemy.combat.perform(definition.spawn_animation, definition.spawn_animation_speed)
	return enemy


## Rises only where the player could see it happen (or right next to it):
## rooms behind rock stay asleep until the party gets there.
func _visible_from(player: Node3D) -> bool:
	var eye := player.global_position + Vector3.UP * 1.4
	var here := global_position + Vector3.UP * 1.0
	if eye.distance_to(here) < 6.0:
		return true
	var q := PhysicsRayQueryParameters3D.create(eye, here, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _on_enemy_died() -> void:
	is_defeated = true
	defeated.emit()


# --- persistence -------------------------------------------------------------------------

func get_save_id() -> String:
	return "spawn:%s" % get_path()


func save_state() -> Dictionary:
	return {"defeated": is_defeated}


func load_state(state: Dictionary) -> void:
	is_defeated = state.get("defeated", false)
	# Living monsters reset: they rise again when the party returns.
	if is_instance_valid(enemy) and enemy.combat.is_alive():
		enemy.combat.died.disconnect(_on_enemy_died)
		enemy.queue_free()
	enemy = null
