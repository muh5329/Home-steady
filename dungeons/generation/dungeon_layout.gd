class_name DungeonLayout
extends Resource
## A hand-authored dungeon as a character grid (semi-procedural: the
## layout is authored, the geometry, walls, torches and dressing are
## generated). One character per cell:
##   '#' or ' '  solid rock (walls are raised where rock meets floor)
##   '.'         floor
##   any key of `props`    floor + that scene (chest, trap, exit, pillar…)
##   any key of `enemies`  floor + an EnemySpawn of that definition
## Rows run along +Z, columns along +X; cell (0, 0) is the builder origin.

@export var rows: PackedStringArray = []
## Size of one cell in metres (KayKit dungeon tiles are 4 m at scale 1).
@export var cell_size := 4.0
## Scale applied to the kit pieces (0.75 matches our 0.75-scale characters).
@export var piece_scale := 1.0
## Character -> scene placed in that cell (faces the room, back to a wall).
@export var props: Dictionary[String, PackedScene] = {}
## Character -> monster spawned in that cell.
@export var enemies: Dictionary[String, EnemyDefinition] = {}
## Prop symbols whose scene brings its own floor tile (traps, grates).
@export var floor_supplied_by := ""
## A torch on roughly every Nth wall segment.
@export var torch_spacing := 3


func size() -> Vector2i:
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	return Vector2i(w, rows.size())


func at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[cell.y].length():
		return "#"
	return rows[cell.y][cell.x]


func is_floor(cell: Vector2i) -> bool:
	var c := at(cell)
	return c != "#" and c != " "


## Cells marked with `symbol`.
func find(symbol: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == symbol:
				out.append(Vector2i(x, y))
	return out
