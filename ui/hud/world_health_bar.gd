class_name WorldHealthBar
extends Node3D
## Small billboard health bar above a character. Appears when damaged,
## fades after a while, hides on death.

@export var health: HealthComponent
@export var width := 0.9
@export var visible_seconds := 5.0

var _fill: MeshInstance3D
var _back: MeshInstance3D
var _timer := 0.0


func _ready() -> void:
	_back = _make_quad(Color(0.08, 0.05, 0.05, 0.85), Vector2(width + 0.06, 0.13), 0)
	_fill = _make_quad(Color(0.86, 0.18, 0.14), Vector2(width, 0.08), 1)
	visible = false
	if health:
		health.health_changed.connect(_on_health_changed)


func _on_health_changed(current: float, maximum: float) -> void:
	var ratio := current / maximum
	_fill.scale.x = maxf(ratio, 0.001)
	_fill.position.x = -width * (1.0 - ratio) * 0.5
	_timer = visible_seconds
	# Only while hurt: full bars (spawning, healing to full) stay hidden.
	visible = current > 0.0 and current < maximum


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		visible = false


func _make_quad(color: Color, size: Vector2, priority: int) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = priority
	mat.albedo_color = color
	var quad := QuadMesh.new()
	quad.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh
