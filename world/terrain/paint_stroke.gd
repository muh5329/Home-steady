@tool
class_name PaintStroke
extends Path3D
## A painted band on the ground (dirt road, cobbles, tilled soil) along
## this path, rasterized into the ground's paint mask by TerrainPainter.
## Keeps grass and flowers off it too.

enum Kind { ROAD, COBBLE, TILLED, SAND }

@export var kind := Kind.ROAD
@export var width := 3.0
