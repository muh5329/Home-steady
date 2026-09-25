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

## Save / load lifecycle.
signal game_saved(slot: String)
signal game_loaded(slot: String)
