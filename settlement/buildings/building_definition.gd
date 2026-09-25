class_name BuildingDefinition
extends GameData
## A constructible building. Placing one creates a ConstructionSite that
## needs `cost` delivered (physically) and `build_work` of labour; when
## done, `scene` (a Building) replaces the site.

@export var scene: PackedScene
## Footprint in metres (x = width, y = depth) used for placement checks.
@export var footprint := Vector2(5, 5)
## Footprint centre relative to the building origin (x, z), e.g. to
## include a storehouse's front deposit apron.
@export var footprint_offset := Vector2.ZERO
## item id -> amount, e.g. {&"item.log": 6, &"item.stone": 2}
@export var cost: Dictionary[StringName, int] = {}
## Labour after materials arrive (hit points of work; a sword swing ~12).
@export var build_work := 40.0
## Shown in the build menu; locked buildings are hidden until unlocked.
@export var unlocked := true
@export var menu_order := 0


func cost_text() -> String:
	var parts: PackedStringArray = []
	for id in cost:
		var item := DataRegistry.get_data(id) as ItemData
		parts.append("%d %s" % [cost[id], item.display_name if item else String(id)])
	return ", ".join(parts)
