# Architecture

Principles from the design spec: YAGNI, composition over inheritance, data-driven content, single
responsibility, signals over direct references. Abstractions are introduced only once a second or
third concrete use exists.

## Autoloads (core/)

| Autoload | Responsibility |
|---|---|
| `EventBus` | Cross-system signals only (e.g. `damage_applied`, `combatant_died`, `talk_requested`). Local wiring uses node signals. |
| `DataRegistry` | Indexes every `GameData` resource under `res://data` by stable `id`. Saves reference ids, never paths. |
| `SaveManager` | Collects `save_state()` from nodes in the `persistent` group into JSON; `can_save()` can veto. |
| `DebugOverlay` | F3 performance panel, `watch(key, value)`, `notify(text)` toasts. |
| `GameManager` | Session state (world seed, play time), pause, quick save/load keys. |
| `Progression` | What the player has unlocked (buildings today); persisted; `EventBus.unlocked` / `unlocks_changed`. |

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

## Settlers: one body, two brains

```
Settler (CharacterBody3D) — same components as player/monsters + CarryComponent, NavSteering,
│                           Equipment, Abilities, CharacterLoadout (class: villager, ranger…)
├─ WorkerController    + StateMachine: Idle → GoToWork → Work → Collect → Deliver (+ Flee)
└─ CompanionController + StateMachine: Follow ⇄ Hold, Attack (abilities inside), Retreat
```

- `Settler.mode`: **STRANGER** (met in the world; neutral, `DamageReceiver.accepts_damage = false`,
  no brain), **WORKER** (worker brain), **COMPANION** (companion brain). Switching deactivates one brain
  (releasing claims, dropping cargo) and activates the other; the body, class, gear and job persist, so
  the same character works the fields and fights in the crypt.
- Recruiting a stranger needs a free bed (`HousingComponent` beds − member settlers); they move next
  to the nearest house.
- `Party` (on the player, max 3) is membership + formation slots; settlers register when they enter
  companion mode, so a loaded save rebuilds the party. **T** toggles hold/follow for everyone.
- Companion AI: engage threats around the player (or the hold point); whoever hurts the player is the
  priority target (spec's DEFEND); melee take turns with attack slots, ranged keep distance and need a
  clear line; abilities are used when ready and in range (`AbilityData.ai_use_range()`); retreat behind
  the player when hurt and threatened; out of combat they recover slowly. Downed = brain stopped until
  the player revives them (E) or they get up after 30 s. Companions don't collide with the player.
  Spec states INTERACT (companions using objects) is deferred until a dungeon needs it.
- `TalkPanel` (UI, opened via `EventBus.talk_requested`): recruit, join/leave party, hold/follow, pick
  a job. Pauses player control; closes on damage, walking away, load, E/Esc.

## Workers and jobs

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

## Dungeons

- A dungeon is a **`DungeonLayout`** (hand-authored character grid + legend: symbol → prop scene or
  `EnemyDefinition`) turned into a space at load by **`DungeonBuilder`**: MultiMesh floors/walls/corner
  pillars from the KayKit kit, box collision, wall torches, props (named by cell for stable save ids),
  `EnemySpawn`s, then a bake of the dungeon's own `NavigationRegion3D`. New dungeon = new layout.
- `EnemySpawn` raises its monster when the player is near *and can see the spot*; `defeated` persists,
  living monsters reset on load. Monster behaviour in range is data (`EnemyDefinition.attack_state`:
  melee "Attack" strings or ranged "Shoot"). Monsters and companions only target what they can see
  (`Targeting.nearest_visible_hostile`).
- **`Passage`** pairs (same `link`) move the player and following companions with a fade and a camera
  snap; a load mid-trip cancels the move. **`AmbienceZone`** swaps the environment, hides the sun and
  caps camera pitch (except while aiming) while the player is inside.
- Props: `Chest` (spills physical loot, persists open), `SpikeTrap` (shared rhythm; hurts only the
  player — the dead ignore their own traps and companions step where you step).
- Monsters are data all the way down: `EnemyDefinition` adds body/hurtbox size, `abilities` (used by
  the generic Attack/Shoot states via `EnemyController.try_ability`), `loot` (physical, via `LootDrop`),
  `unlocks` (→ `Progression`) and `is_boss` (a `BossPresence` component announces engage/disengage/
  defeat for the HUD boss bar). Abilities can be health-gated (`use_below_health` = boss phases) and
  can summon (`Summoner` component: armored cast, cooldown refunded if interrupted, summons crumble
  with their master and vanish if it is reset). Leashing heals and dismisses summons; monsters lose
  track of a target they can't see for 5 s.
- The crypt's spider has no art-kit model: `SpiderModel` builds a primitive body and keys its clips
  procedurally under the standard clip names, so it plugs into the same animator/combat code.
- Progress can't be lost: a locked `CryptGate` re-issues its key if the keeper is dead and the key is
  gone; items falling out of the world return to the player; loot never spawns inside walls.
- Static-geometry changes rebake through `NavRebake.queue` (debounced, never drops a request).
- The crypt lives in the same region scene, far from the overworld (x = 400), so the settlement keeps
  simulating while the party is underground.

## Physics layers

1 world · 2 characters · 3 hurtboxes · 4 interactables · 5 props · 6 footprints

## Testing

`tests/test_runner.tscn` runs `tests/unit` and `tests/scenarios`. Scenario tests spawn real scenes
(`tests/fixtures/sandbox.tscn`) and drive them with `InputEventAction`s. `tests/capture` renders
screenshots for the visual review (`tools/capture.sh`).
