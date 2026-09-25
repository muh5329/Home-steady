class_name GameData
extends Resource
## Base for every data definition (classes, items, buildings, jobs...).
##
## The `id` is the stable key persisted in save files, so it must never
## change once content ships. Save files store ids, never resource paths.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
