extends Node
## Boot scene: class selection, then the starting region.

@export var start_region: PackedScene
@export var class_select: PackedScene

var region: Node


func _ready() -> void:
	if class_select and GameManager.selected_class == null:
		var menu: ClassSelect = class_select.instantiate()
		add_child(menu)
		menu.class_chosen.connect(func(c):
			GameManager.selected_class = c
			menu.queue_free()
			_start())
		menu.continue_requested.connect(func():
			menu.queue_free()
			_start()
			# Everything persistent now exists; restore it (incl. the class).
			await get_tree().process_frame
			SaveManager.load_game())
	else:
		_start()


func _start() -> void:
	if start_region:
		region = start_region.instantiate()
		add_child(region)
