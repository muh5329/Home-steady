extends Node
## Global event hub for cross-system notifications.
##
## Rule: only add a signal here when two systems that should not know about
## each other need to communicate. Local parent/child communication uses
## ordinary node signals instead.

## A DamageEvent was applied to something (after mitigation).
signal damage_applied(event: DamageEvent)

## A combatant reached zero health.
signal combatant_died(combatant: Node)

## A storage's contents changed (HUD totals, production systems).
signal storage_changed(storage: Node)

## A construction site finished and became a Building.
signal building_completed(building: Node)

## Static world geometry changed (building placed/finished): navigation
## should be rebaked.
signal world_geometry_changed

## The player started talking to a character (UI opens the talk panel).
signal talk_requested(speaker: Node)

## Save / load lifecycle.
signal game_saved(slot: String)
signal game_loaded(slot: String)
