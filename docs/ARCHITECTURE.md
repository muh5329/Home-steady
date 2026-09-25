# Architecture

Principles from the design spec: YAGNI, composition over inheritance, data-driven content, single
responsibility, signals over direct references. Abstractions are introduced only once a second or
third concrete use exists.

## Autoloads (core/)

| Autoload | Responsibility |
|---|---|
| `EventBus` | Cross-system signals only (e.g. `damage_applied`, `combatant_died`). Local wiring uses node signals. |
| `DataRegistry` | Indexes every `GameData` resource under `res://data` by stable `id`. Saves reference ids, never paths. |
| `SaveManager` | Collects `save_state()` from nodes in the `persistent` group into JSON; `can_save()` can veto. |
| `DebugOverlay` | F3 performance panel, `watch(key, value)`, `notify(text)` toasts. |
| `GameManager` | Session state (world seed, play time), pause, quick save/load keys. |

## Characters: shared components

Player and monsters are built from the same components; only the "brain" differs.

```
CharacterBody3D (Player / Enemy root: wiring + persistence only)
├─ CharacterMotor        velocity, gravity, jump, turning, bursts (dodge/lunge), knockback, hitstop hold
├─ CharacterAnimator     AnimationPlayer: locomotion by speed (incl. strafe), one-shot actions, flash, freeze
├─ HealthComponent       hit points → health_changed / died
├─ Hurtbox (DamageReceiver)  single entry point for damage; listeners may mitigate
├─ WeaponHitbox (Hitbox)     live only during an attack's active window; shape per AttackData
├─ CombatController      action state machine: attack combos, heavy, block, dodge, stagger, death, BUSY actions
├─ CombatSfx             plays CombatSounds in response to combat signals
└─ Brain: PlayerController (input)  |  EnemyController + StateMachine (ai/states/)
```

- Brains issue **requests** (`request_light`, `set_block`, `request_dodge`, `perform(clip)`), never
  animation or velocity changes.
- All damage is a `DamageEvent {source, source_combatant, target, damage_type, amount, poise_damage,
  knockback, tags}` → `DamageReceiver.receive()`. Types (fire, holy, necrotic…) and resistances are data.
- Attack timing comes from `AttackData` resources (animation, active window, combo window, recovery,
  damage, poise, knockback, lunge, hitbox shape). Windows were measured from the clips' arm-speed peaks.
- Monsters: one `enemy.tscn` + an `EnemyDefinition` resource (model, hand items, stats, moveset, sounds,
  aggro/leash/cooldowns). New monster = new `.tres`.
- AI thinks at a distance-dependent rate (0.1 s near the player, 0.35 s mid, 1 s far). Attackers
  claim slots on their target (`max_attackers`), so crowds take turns instead of dog-piling.

## Interaction & carrying

`Interactable` (Area3D on layer 4) is the one thing the player's `InteractionController` looks for.
What "use" means is decided by the owner connecting `interacted` — `Carryable` (a RigidBody3D) picks
itself up; later doors, chests, resource nodes and NPCs do their own thing. Carrying applies a named
speed modifier on the motor, a `CarryPoseModifier` (SkeletonModifier3D) for the arms, and stows weapons.

## Settlement

- `Settlement` (one per region): logistics service — storage lookup (`find_receiver_for`), loose items,
  work targets, construction demand, totals, beds. Workers, stockpiles and the HUD query it.
- `BuildingRegistry` / `Population`: containers for runtime-spawned buildings, construction sites and
  settlers. They give each a stable `uid` and persist them as data (definition id + transform + state).
- `Building` scenes get behaviour from feature nodes (storage, housing, crop plots) that persist via the
  building; `ConstructionSite` consumes delivered items, then labour.
- `Footprint` (physics layer 6) reserves ground for placement, including things without solid colliders.

## Workers and jobs

```
Settler (CharacterBody3D) — same components as player/monsters + CarryComponent, NavSteering
└─ WorkerController + StateMachine: Idle → GoToWork → Work → Collect → Deliver (+ Flee)
```

- A `JobDefinition` (woodcutter, miner, farmer) is data: produce it gathers, radius, work animation,
  impact frame, amount, tags, tool. The states contain no job-specific code (a test enforces this).
- A **WorkTarget** is anything in the `work_targets` group implementing `has_work_for(job)`,
  `claim/release`, `work_position(from)`, `apply_work(amount, worker, tags) -> {produced_at?}`.
  `ResourceNode` (trees, rocks, ore, crops) and `ConstructionSite` implement it.
- `ResourceNode` lifecycle: ripe → (worked) depleted → [tend: labour to replant] → growing → ripe.
  Crops need tending; trees and rocks regrow by themselves.
- Robustness: claims are released on every state exit (including death via `StateMachine.stop()`);
  progress-based stuck detection blacklists unreachable targets; recent threats are avoided; downed
  settlers recover at home; swings are chained continuously (only decisions are distance-throttled);
  async swings/pickups check `CombatController.action_serial` / state generations before acting.

## Physics layers

1 world · 2 characters · 3 hurtboxes · 4 interactables · 5 props · 6 footprints

## Testing

`tests/test_runner.tscn` runs `tests/unit` and `tests/scenarios`. Scenario tests spawn real scenes
(`tests/fixtures/sandbox.tscn`) and drive them with `InputEventAction`s. `tests/capture` renders
screenshots for the visual review (`tools/capture.sh`).
