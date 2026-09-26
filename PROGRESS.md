# Gauntlet Progress

Current phase: **Phase 9 — Settlement economy** (next)
Engine: Godot 4.7.2 · Tests: `tools/run_tests.sh` (134 passing)

## Scoreboard

| Round | Gameplay | Settlement | RPG | World | Architecture | Visuals | Performance |
|---|---|---|---|---|---|---|---|
| 1 (Phase 0–1) | 6 | – | 2 | 1 | 7 | 5 | 6 |
| 2 (Phase 2) | 6 | 3 | 2 | 2 | 6 | 5 | 6 |
| 3 (Phase 3) | 6 | 5 | 2 | 2 | 6 | 5 | 7 |
| 4 (Phases 4–5) | 6 | 6 | 2 | 3 | 7 | 5 | 6 |
| 5 (Phase 6) | 6 | 6 | 5 | 3 | 7 | 5 | 7 |
| 6 (Phase 7) | 7 | 6 | 6 | 3 | 7 | 5 | 7 |
| 7 (Phase 8a) | 7 | 6 | 6 | 5 | 7 | 6 | 7 |
| 8 (Phase 8b) | 7 | 7 | 7 | 5 | 7 | 6 | 7 |

Scores are 0–10 against the *final* target, so early rounds are low by design.

---

## Visual gauntlet — pass 1 (Fabledom art target)

The user asked for a full graphics overhaul toward **Fabledom** (reference shots in `docs/art_target/`).
Phase 9 (smithing chain) is paused mid-way (work parked outside the repo) and resumes after this.
Passes follow the spec order (lighting → terrain → buildings → foliage → characters → props → VFX),
each captured with `tests/capture/test_capture_visual.gd` (`VISUAL_TAG=… tools/capture.sh
capture_visual`). Before/after: `docs/rounds/visual_01/` (`v0_before_*` vs `v5_polish_*`).

| Pass | Change |
|---|---|
| Lighting | Golden-hour sun (warm, lower, side-lit), saturated sky gradient, cool sky ambient, filmic tonemap, stronger SSAO, soft bloom, aerial haze; far depth of field; `PostFx` lens finish (vignette, subtle chromatic fringe, warm-highlight/cool-shadow split toning); higher, wider default camera |
| Terrain | Painterly ground shader (broad colour sweeps, brush streaks); `TerrainPainter` bakes `PaintStroke` paths into a mask → dirt roads with ruts, cobbled plazas, tilled soil; terraced red-clay `TerraceHills` (strata, grass lips) ringing the land and on the horizon; far ground to the horizon; border colliders |
| Foliage | `FoliageScatter`: windblown grass tufts (world-noise coloured to melt into the ground) in streamed chunks with visibility fade, wildflower drifts (yellow/white/blue/pink), a dense pine belt with colliders and a forest to the horizon; layered procedural pines (`FoliageMeshes`) now also used by the choppable trees |
| Buildings/props | Red-roofed building variants, chimney smoke plumes (`SmokePlume`), campfire smoke column, camp dressing (lumber, sacks, barrels, crates, wheelbarrow, rack, banner) |
| UI | Storybook theme (`ui/theme/fable_theme.tres`): Fredoka font (OFL, `art/fonts/`), navy panels with gold trim, rounded buttons/bars |
| Fix | Black "holes" at bright spots: NaN pixels from foliage normals spread by DOF/glow — foliage shader made NaN-proof |

### Visual gauntlet — passes 2–5 (after a visual-critic review scoring v0 2/10, pass 1 4.5/10)

| Pass | Largest discrepancy fixed |
|---|---|
| 2 | Neon greens → olive/yellow palette; rust roads → pale tan with worn centres and grassy, flowery edges; visible rounded cobbles; clustered grass (sparse lawn, thick drifts) kept off roads; mossy procedural boulders (were blown-out white hex rocks); dirt aprons worn around new buildings; building dressing (barrels, crates, sacks, lumber, wheelbarrow); fenced farms on tilled soil; clouds; fixed-size nameplates; help text in a themed panel; halved chromatic fringe; DOF pushed out |
| 3 | Buildings were created at the origin before being moved, so their ground wear landed at the camp — now placed before `_ready` (also fixes construction sites); warmer tents |
| 4–5 | The terraced hills read as dark purple slabs: their triangles were wound backwards, so Godot lit the inside of the walls. Fixed winding → sunlit red-orange strata with grass lips and summit pines. Same root cause darkened half of all grass blades and pine needles (two-sided shading flips normals on back faces) → foliage keeps its authored normals on both sides, grass is lit like the ground: the lawn now reads as one soft carpet |

Latest captures: `docs/rounds/visual_02/`.

### Visual gauntlet — pass 6 (visual critic re-score: v9 = 6.5/10)

| Largest discrepancies | Fix |
|---|---|
| Hills read as stacked cakes / a uniform wall | Terraces now vary in height, drift off-centre, rims rise and dip, walls slope in, lips drape further, strata are broader and noise-broken |
| Nothing between grass and trees; village on an empty lawn | Procedural shrubs (some flowering) along roads, in dense drifts, hugging buildings and at the forest edge; `FenceRun` fences along the roads |
| Pines between camera and hero | Foliage dissolves (dithered) near the camera→player line via a global `player_position` shader uniform |
| Label clutter | Health bars only while hurt; nameplates drawn on top, fixed size, and show activity only within 9 m |

Captures: `docs/rounds/visual_03/`.

### Visual gauntlet — pass 7 (visual critic re-score: v10 = 7/10)

| Largest discrepancies | Fix |
|---|---|
| Buildings toy-sized next to the hero; primary red/blue kit colours | Buildings ×1.4 (footprints, colliders, dressing scaled); `StorybookPalette` shader regrades the KayKit texture: red → terracotta, pale blue plaster → warm ochre, deep blue → slate teal, white → cream |
| Blue-tinted shadows made plaster read blue | Ambient light warmed (lavender-neutral, less sky contribution) |
| Flat prism tents | Procedural striped bell tents (`art/props/bell_tent_model.gd`): sagging canvas cone, scalloped valance, doorway, pennant |
| Farm = sticks in a dark pit | Procedural wheat beds (dense golden tufts with ears, wind-swayed) on raised soil furrows (`FoliageMeshes.wheat_bed`/`furrows`) |
| Faceted "shard" bushes | Soft radial normals, no blossom shards: round painterly shrubs |
| Grass uniform height; pines filling the lens | Tall meadow tufts with seed heads along roads/fences and in lush drifts; foliage dithers out within ~2.5 m of the camera; nameplates show activity within 6 m |

Captures: `docs/rounds/visual_04/`.

### Visual gauntlet — pass 8 (visual critic re-score: pass 7 = 7.5/10)

| Largest discrepancies | Fix |
|---|---|
| Regrade left the village monochrome; grey stone lumps | Pale plaster → bright ochre (#EACB8A), shutters/doors → muted teal, neutral/cool greys lightened and sun-warmed; flower planters (pink/yellow/white) against houses, the forge and the store |
| Village thin, bare placement pads | Aprons are smaller with ragged, trodden edges; farms paint a crisp rotated square field; a village well by the camp; the village capture shows a grown village (7 buildings) framed so roofs fill the frame |
| Placeholder assets clash | Ore veins are mossy boulders with ore shards; the crypt entrance is weathered into mossy ruin stone (`StorybookPalette.apply(root, weathered)`), its torches dimmed in daylight; bell-tent doorway follows the canvas curve (no black shards) |
| Hills: flame-like stripes | Cliff noise sampled in metres at a slow rate: broad wavy strata, soft rain-wash, softer grass lips |
| Milky haze | Fog −30%, contrast 1.18, less SSAO light-affect |
| Pines hiding the hero; stipple on flowers | Occlusion dissolve widened (1.8–3.4 m from the view line) but only for foliage above chest height or in the near half of the view; near-lens fade 0.8–1.8 m; nameplate activity within 4 m |

Captures: `docs/rounds/visual_05/` (`pass6_vs_pass8.jpg` is a before/after).

The visual capture test takes `VISUAL_VIEWS` (e.g. `56`) to render a subset, and adds a sixth
view close on the farm.

---

## Round 8 — Phase 8 (part 2): spiders, the Necromancer, and a reward that builds the settlement

**What changed**
- **Crypt Spider**: a procedural model (`SpiderModel`: primitive body, 8 legs, keyed gait/bite/leap/
  death/drop clips under the standard names) on the shared enemy scene; drops from the ceiling, poison
  bite (new damage-over-time on `StatusEffectData`), pounce. Body/hurtbox size is now per definition.
- **Key and door**: the Skeleton Champion drops a physical Crypt Key; carry it to the locked door and
  press E (the door accepts it like storage accepts items); navigation rebakes through the doorway.
- **Morvath the Necromancer** (boss) is data on the generic Shoot state: bone-orb bolts, **Necrotic
  Volley**, **Raise Dead** (armored cast; minions climb out), **Grave Nova** below 60% (ground
  telegraph) and **Raise the Fallen** below 50%. HUD boss bar via `BossPresence` + EventBus.
- **Reward feeds the settlement**: the boss drops the **Forge Rune** (special crafting resource) and
  unlocks the **Blacksmith** (`Progression` autoload, persisted); the Blacksmith now needs the rune,
  so it must be carried home. Build menu refreshes on unlock; banner announces it.
- Generic pieces: `EnemyDefinition.abilities/loot/unlocks/is_boss`, `LootDrop`, health-gated abilities,
  `Summoner`, `NavRebake`, `Enemy.raise`.

**Test performed** 11 new tests (134 total): spider clips + poison ticking out of reach, key → door →
navigation through, boss summons/nova/phase gating at 100/55/45%, boss death → minions crumble, rune
drops, Blacksmith unlocked and offered, unlock saved/loaded, rune delivered to a Blacksmith site; plus
the regression set below. Visual run: `docs/rounds/round_08/`.

**Critic findings and resolution** (critic score 7/10)
| # | Finding | Status |
|---|---|---|
| 1 | Any hit cancelled a summon (cooldown lost) | Fixed: armored casts (only poise breaks interrupt), refund on cancel; test |
| 2 | Loading mid-fight orphaned summons | Fixed: `Summoner` removes its summons when the caster leaves/resets; test |
| 3 | Single-source key/rune could lock progress (old saves, lost items, loot in walls) | Fixed: door re-issues a missing key; items below the world return to the player; loot spawn ray-checked; tests |
| 4 | Boss never reset; boss bar showed while the player was away | Fixed: leashing heals + dismisses summons; monsters lose track after 5 s without sight (the boss was stuck at the locked door forever); bar only while the player is there; test |
| 5 | Gate closing on load didn't rebake; rebakes dropped while baking | Fixed: shared debounced `NavRebake` (Region uses it too); test |
| 6 | AbilityController depended on Enemy; boss logic in the controller | Fixed: `Summoner` and `BossPresence` components |
| 7 | Spider used a humanoid capsule; per-instance asset rebuilds | Fixed: body/hurtbox size per definition; spider materials and clips cached |
| 8 | Nova had no telegraph | Fixed: `AttackData.telegraph` ground circle filling until the hit |
| 9 | Build menu lost its status text on refresh; vacuous tests | Fixed |
| – | Poison permanently kept up by fast bites; no dungeon-cleared event | Documented; the boss-defeated event covers the loop today |

Also: when a wall pulls the camera in, the player's body now fades instead of filling the screen;
companion nameplates fade out closer than 5 m.

**Known problems** The spider's hurtbox is a capsule, not its leg span; Progression is global (one
save slot today); nothing yet uses the Blacksmith (Phase 9); narrow crypt corridors still give awkward
camera angles (p8b_01).

**Highest-priority next task** Phase 9: Iron Ore → Miner → Warehouse → Blacksmith → Iron Sword, fully
autonomous, with crafted weapons the player and companions can equip.

---

## Round 7 — Phase 8 (part 1): the Abandoned Crypt

**What changed**
- **Dungeon generation from layouts**: `DungeonLayout` (ASCII grid + legend of prop scenes and monsters)
  → `DungeonBuilder` (MultiMesh floors/walls/pillars from the KayKit dungeon kit at character scale, box
  collision, flickering wall torches, props, spawns, own navmesh bake ~0.1 s).
- **The crypt** follows the spec's structure: entrance hall → a room of skeletons clawing out of the
  floor → a treasure room (chest spills 3 iron ore, guarded by an archer) → a spike hall (all spikes
  share one rhythm: watch, then sprint) → the elite room (**Skeleton Champion** + two archers). The boss
  chamber comes next round.
- **Passages**: a mausoleum north of camp and the crypt stairs are a linked pair; travel fades out,
  moves the player and following companions, snaps the camera and fades in.
- **AmbienceZone**: dark torch-lit environment, no sun, camera pitched down to clear walls (not while
  aiming).
- New monsters as data: **Skeleton Archer** (new data-selected `Shoot` state: hold range, need a
  line, back off along the navmesh) and **Skeleton Champion** (3-hit combo, 260 HP, poise 70).
- `EnemySpawn`: rises when the player can see the spot; defeated monsters stay dead in saves.
- Monsters and companions only target what they can see.

**Test performed** 14 new tests (123 total, clean repeated runs): crypt geometry/collision/navmesh route
from the stairs to the elite room, travel down and back with a companion (ambience, sun, camera snap),
spawns rising near the player and persisting defeat across two saves, no aggro through rock, archers
shooting from range and backing off on the floor, chest loot once across save/load, spikes hurting the
player but not companions or monsters, stable cell-based prop names; plus the regression set below.
Visual run: `docs/rounds/round_07/`.

**Critic findings and resolution** (critic score 7/10)
| # | Finding | Status |
|---|---|---|
| 1 | Camera swooped 400 m during the fade-in | Fixed: `CameraRig.snap()` on travel, respawn and load; test |
| 2 | Companions targeted and spawns rose through walls | Fixed: visible-only companion targeting; spawns need sight of their spot (or < 6 m); test |
| 3 | LOS aggro only checked the nearest hostile | Fixed: `Targeting.nearest_visible_hostile` (sorted, first visible); overworld test |
| 4 | Prop save ids from auto names | Fixed: props named by cell; test |
| 5 | Pitch cap broke free aim; travel vs load/scene exit races | Fixed: no cap while aiming; load cancels a trip; fade cleared on exit |
| 6 | Archers backed into walls | Fixed: navmesh-snapped back-off goal; test |
| 7 | Trap double hits via knockback into the next tile | Fixed: shared per-victim cooldown across traps |
| 8 | Spawn transform set after add_child | Fixed |
| – | Single-zone ambience, legend can't parametrise props, no DungeonDefinition/events, elite readability, torch processing | Deferred: DungeonDefinition + clear/boss events land with the boss next round |

**Known problems** Spider, Necromancer boss, reward and building unlock (next round); the champion reads
as elite only by size; the crypt sits at a fixed offset (x = 400) in the region; spike hall timing is
tight for slow classes.

**Highest-priority next task** Phase 8 (part 2): Spider, Necromancer boss chamber, the rare reward
(special crafting resource) and the Blacksmith unlock — the crypt feeding the settlement.

---

## Round 6 — Phase 7 companions (the same NPC works and adventures)

**What changed**
- `Settler` now has a **mode**: STRANGER (met in the world, neutral, can't be hurt), WORKER (the
  existing `WorkerController`), COMPANION (new `CompanionController`). Switching deactivates one brain
  (claims released, cargo dropped) and starts the other; body, class, gear, job and health carry over.
- Settlers use `CharacterLoadout` like the player: a Villager class (hand axe) by default, any class
  as data. Working shows the job tool (falls back to the job's tool scene when the rig lacks the part);
  adventuring shows the class weapon.
- Companion AI (`ai/companions/`): Follow (formation slots, sprint to catch up, navmesh-snapped
  teleport when hopelessly far), Hold, Attack (melee take turns via attack slots and swing short
  combos; ranged keep distance, need a clear line, back off when rushed; abilities used when ready and
  in range), Retreat (behind the player when hurt and threatened), rest-regen out of combat, Downed
  (revive with E, or they get up after 30 s at 40%). Whoever hurts the player becomes the target.
- Recruitment: strangers join if there's a free bed (tents: 2 beds each). **Vesna** (Ranger) waits
  west of the camp; the camp has one free bed for her.
- `Party` on the player (max 3), **T** toggles hold/follow for all; HUD party frames (HP, activity,
  DOWNED). `TalkPanel` replaces blind job cycling: invite, join party, follow/hold, go home and work,
  pick a job (keys 1–9 or click).
- Mode, class, order, hold point, greeting and downed state persist; the party rebuilds on load.

**Test performed** 20 new tests (109 total, 3 consecutive clean runs): bed-gated recruitment through
the panel, enemies ignore strangers, join via talk and follow a moving player, party limit, T hold /
follow, a fighter companion kills a skeleton, a ranger companion shoots and uses Volley, defending the
player (switches to the player's attacker), retreat + rest, player revive, **send home → walks back,
chops and hauls a log**, save/load of companion + stranger, HUD frames; plus the regression set below.
Visual run: `docs/rounds/round_06/` (meeting Vesna, recruiting, party following, party fight, downed
companion, Vesna back at work).

**Critic findings and resolution** (critic score 7/10)
| # | Finding | Status |
|---|---|---|
| 1 | Loading with the talk panel open soft-locked input (freed speaker compared `== null`) | Fixed: explicit open flag, `is_instance_valid`, close on `game_loaded`; test |
| 2 | Strangers could still be shot/blasted (non-monitorable areas are still ray/shape hits) and stayed dead | Fixed: `DamageReceiver.accepts_damage` (combat never toggles it); projectiles fly through; test |
| 3 | Below 30% HP, Follow/Hold stood still; auto-recover at 25% looped into another downing | Fixed: `should_retreat()` in every state, recover at 40%; tests |
| 4 | Talking froze the player during combat | Fixed: a hit closes the panel; test |
| 5 | Companions body-blocked the player; teleports could land in walls | Fixed: collision exceptions in companion mode; navmesh-snapped teleport; test |
| 6 | Downed state lost on save; coroutines resumed on freed settlers | Fixed: saved `downed`; timers connected with bound callables instead of awaited; test |
| 7 | Ranged companion on Hold chased for a shot | Fixed: holds, only engages what it can hit from the hold point |
| 8 | Panel subtitle stale, overlapped help line; strangers showed a health bar | Fixed |
| 9 | `Party` duck-typed members; literal group name; docs | Fixed: typed `Array[Settler]`, `Settler.GROUP`, ARCHITECTURE updated |
| – | Nearest house chosen even if full | Deferred: beds are a count, not assignments, until houses matter (Phase 10) |

Also found: class changes left stale weapon parts (warning on load) → `EquipmentController.set_model`;
the interaction scan could touch areas just removed on load → skipped; NPC-only classes hidden from the
class select (`playable`); nameplates fade near the camera instead of filling the screen.

**Known problems** Spec states INTERACT (companions using objects) deferred until the crypt needs it;
no companion equipment swapping yet (Phase 9 crafted weapons); separation is still O(N²) per think;
companions cross regions only once regions exist (Phase 8 will decide).

**Highest-priority next task** Phase 8: the Crypt — skeleton, spider, necromancer boss, reward =
special resource + building unlock; the party goes in with you.

---

## Round 5 — Phase 6 classes (melee / ranged / magic)

**What changed**
- `CharacterClassData` (Fighter, Ranger, Wizard): model, stats, damage dealt/taken multipliers, starting
  `WeaponData`, abilities. New classes are `.tres` files. `CharacterLoadout` applies a class to any
  character, at startup or at runtime (loading a save swaps the body back).
- `EquipmentController` (weapon → moveset, damage, visible meshes), `AbilityController` (Q; cooldown
  starts when the attack actually starts), `StatusEffectComponent` (Frost Nova's chill: slow + tint).
- Ranged/magic are data on `AttackData`: projectile(s), spread, area burst. `Projectile` sweeps a ray,
  respects factions and receiver tags, bursts for AoE with blast-centred knockback.
  - Fighter: sword combo, heavy, block, **Shield Bash** (stagger); 130 HP, -15% damage taken, +15% damage.
  - Ranger: crossbow bolts, charged power shot, **Volley** (5-bolt fan); 95 HP, faster.
  - Wizard: arcane missiles, **Fireball** (AoE), **Frost Nova** (radial chill); 85 HP.
- Ranged aiming: reticle (brackets when an enemy is assisted), camera-centre aim point with pitch,
  assist by angle to the reticle with line of sight, **RMB aim mode** (zoomed shoulder cam, strafing).
- Class select screen at start (click or 1–3) with **Continue** when a save exists; HUD shows class,
  ability cooldown and reticle. Shared `CombatVfx` bursts (rings, soft particles, flashes).

**Test performed** 19 new tests (89 total): each class builds its body/gear/stats, shield bash staggers,
bolts hit at 12 m, volley fan hits a group, fireball AoE hits two with fire damage, frost nova chills
and wears off, cooldown gating, walls stop bolts, bolts pass friendly settlers, class screen via keys,
class persistence; plus the regression set below.

**Critic findings and resolution**
| # | Finding | Status |
|---|---|---|
| 1 | Spells/bolts chopped trees, built sites, reaped crops | Fixed: `DamageReceiver.required_any_tags` (gathering/building accept melee + tool work only); test |
| 2 | Loading didn't rebuild the class (wizard body with crossbow moveset) | Fixed: `CharacterLoadout.apply` at runtime, class stored in player save; test |
| 3 | Class setup and aiming player-only | Fixed: shared `CharacterLoadout`; `Targeting.aim_point`; enemy aim-point provider. Crafted-weapon equip in Phase 9 |
| 4 | Ranged out-DPSed melee and was safer | Fixed: refire gated by recovery (crossbow 18.7, staff 18 DPS vs sword ~29 with class bonus), Fighter toughness, volley trimmed |
| 5 | Ranged aiming was guesswork | Fixed: reticle, camera ray, angle+LOS assist, aim mode |
| 6 | Muzzle past walls, point-blank misses, knockback from shooter | Fixed: chest-origin rays hitting from inside, blast/flight-based knockback, freed-shooter guard; tests |
| 7 | Cooldown spent on queue | Fixed: spent on `attack_started`; test |
| 8 | Status effect details, square nova | Fixed: effects cleared on death, no chill through a block, unused DoT removed, sphere hitboxes; test |
| Perf | Per-shot material/mesh/light allocations | Fixed: per-ProjectileData caches, missile light removed |

Also found while fixing: two systems wrote the motor's facing lock (aim vs block) → named facing locks.

**Known problems** No hit numbers; burst VFX still allocate per burst (cheap, not cached); Continue path
loads only the quick-save slot; companions don't use classes yet.

**Highest-priority next task** Phase 7: recruit a settler as a companion who follows, fights, returns
home and works — the same NPC in both roles.

---

## Round 4 — Phase 4 Woodcutter + Phase 5 generic jobs (Farmer, Miner)

**What changed**
- Extracted shared components now that a second user exists: `CarryComponent` (player + settlers),
  `NavSteering` (monsters + settlers), `AiLod` (distance-based think rates).
- `Settlement` logistics service; `WorkTarget` contract (resource nodes, construction sites).
- `Settler` scene (Barbarian rig) + `WorkerController` + states Idle/GoToWork/Work/Collect/Deliver/Flee;
  `Population` registry persists settlers (job, home, health, carried item).
- Phase 4: Woodcutter fells the nearest tree, collects the logs, hauls them to storage, repeats.
- Phase 5: jobs became `JobDefinition` data; Miner (ore + stone, pickaxe) and Farmer (sickle) added with
  **zero** job-specific state code. Farms have 6 wheat plots: reaped (yields a wheat sack), then need
  sowing labour, then grow visibly before they can be reaped again. Players can reap/sow too.
- Talking to a settler (E) cycles their job; nameplates show name, job and what they're doing (incl.
  why they're idle).

**Test performed** 20 new tests (70 total, 3 consecutive clean runs): full autonomous woodcutter loop
with no input (2 trees, 4 logs in ~31 s), two workers reserving different trees, hauling player-felled
logs, no-storage behaviour, flee, persistence mid-haul, miner hauling all ore, farmer reap→sow cycle,
crop tending rules, player sowing, job change by talking, job + farm plot persistence, a static check
that worker states contain no job names or concrete target types, downed workers releasing claims and
recovering, unreachable targets blacklisted, distant workers working at full pace, drop placement.

**Critic findings and resolution**
| # | Finding | Status |
|---|---|---|
| 1 | Job states were a gatherer pipeline typed to ResourceNode/Stockpile | Fixed: WorkTarget contract, receivers with `approach_radius`; states type-free. Task board for storage→workshop hauling deferred to Phase 9 (its first consumer); companion brain to Phase 7 |
| 2 | Dead settlers leak claims; flee has no memory | Fixed: `StateMachine.stop()` on death, downed → recover at home, threat memory used by searches |
| 3 | Time-based stuck detection that never learns | Fixed: progress watchdog per goal + 60 s blacklist, in GoToWork/Collect/Deliver |
| 4 | Intermittent miner failure | Root cause found: stuck check used the previous goal and blacklisted the stockpile. Fixed; drops also spawn clear of rubble and of the worker |
| 5 | Distant workers slower (swings gated by think rate) | Fixed: continuous work loop; test compares near vs 100 m-away worker |
| 6 | Async races in swing/pickup | Fixed: `action_serial` check at impact, captured job values, state generation counters |
| 7 | Scans every think with ~50 workers | Partly: idle search backoff, per-frame navmap readiness cache. Spatial indexing deferred until profiling shows need |
| 8 | No way to get settlers; blind job cycling | Idle reasons added. Recruitment + job UI are Phase 7 |

**Known problems** All settlers share one model (job readable from nameplate + tool). Job assignment is
a cycle on E. Wheat and ore have no consumers yet (Phase 9). Separation is O(N²) over combatants.

**Highest-priority next task** Phase 6: Fighter / Ranger / Wizard as data (melee / ranged / magic),
selectable at start.

---

## Round 3 — Phase 3 building

**What changed**
- `BuildingDefinition` resources (Stockpile, House, Storehouse, Blacksmith, Farm): scene, footprint (+offset),
  cost, labour, menu order. Buildings are scenes whose behaviour comes from feature nodes
  (`HousingComponent`, storage via the Stockpile script) persisted by the `Building` root.
- Build mode (**B**): menu with hotkeys and costs, mesh-copy ghost (green/red with reason), **R** rotate,
  **LMB** place, **X** cancel a site (materials drop back as physical items). Build mode owns the attack
  and block buttons while open and closes on death.
- `ConstructionSite`: dirt foundation → three KayKit construction stages → scaffolding as progress rises;
  accepts only still-needed items via the same `Interactable` deposit path as stockpiles
  (**[E] Deliver Logs**); after materials, labour by swinging (or E). Completion swaps in the Building.
- `BuildingRegistry`: runtime buildings/sites get stable uids and persist as
  {uid, definition, transform, state} — resolving Round 2's save-identity finding for runtime entities.
- `Footprint` physics layer: buildings, sites, trees (incl. stumps), camp reserve ground so placement
  can't overlap fields, stumps, deposit aprons or the campfire. Stumps keep a short collider.
- Navigation rebakes asynchronously (debounced) after geometry changes; navmesh resources are per-scene.
- Starting camp: campfire (flickering light, fire and smoke particles) and two A-frame tents.
- Stockpiles hand out what construction sites still need first. HUD shows beds; a banner announces
  completed buildings.

**Test performed** 12 new scenario tests (50 total, stable over repeated runs): build mode via real keys,
blocked placement (props, fields, stumps), labour needs materials, deliver-by-carrying → labour → House
with housing, Storehouse storage, demand-aware stockpile, navmesh routes around new buildings,
save/load of sites (delivered counts, rotation, uid) and buildings (storage contents), save in the
completion frame, cancel with refund, build mode not throwing a carried log.

**Critic findings and resolution**
| # | Finding | Status |
|---|---|---|
| 1 | Placement ignores fields, campfire, stumps, aprons, canopies | Fixed: Footprint layer + `collide_with_areas`; storehouse apron in its footprint |
| 2 | Build mode leaks input (throws carried log), no close on death | Fixed; regression test |
| 3 | No logistics/reservation service | **First task of Phase 4** (Woodcutter is its first consumer) |
| 4 | Labour routed through combat damage | **First task of Phase 4**: generic `WorkTarget` |
| 5 | Site collider smaller than building; save in completion frame | Fixed: full-footprint site collider; load completes stuck sites; test |
| 6 | No cancel/demolish | Fixed: X cancels with physical refund; throwing onto sites deferred |
| 7 | Ghost via script stripping; camera-snapped yaw | Fixed: mesh-copy ghost, rotation only from R |
| 8 | Full-map rebakes; camp not baked; stumps walkable | Camp/stumps fixed. Chunked baking deferred until regions grow |

**Known problems** Farm and Blacksmith are placeable but inert until Phases 5 and 9. Whole-map navmesh
rebake per change (fine at 160 m). Labour is quick (~5 swings for a house); hauling dominates until workers.

**Highest-priority next task** Phase 4: Settlement logistics service (storage lookup, reservations,
site demand) + WorkTarget, then one Woodcutter who chops, collects and delivers logs autonomously.

---

## Round 2 — Phase 2 resource loop

**What changed**
- `ItemData` (logs, stone, iron ore, crate, barrel): each important resource is a physical `Carryable`
  in the world; weight/carry speed/storability live in data.
- `ResourceNodeDefinition` + `ResourceNode`: pines, firs, boulders, iron veins. Gathering reuses combat —
  any melee DamageEvent wears the node down (tag multipliers ready for axes/picks), only allied factions
  can gather, `E` performs a swing. Trees topple away from the last hit and drop logs along the trunk;
  rocks crumble; nodes regrow after a timer. Progress bar + chip dust on every hit.
- `Stockpile` + `InventoryComponent`: items that come to rest in the zone are absorbed; carrying an item
  near a pile shows **[E] Store Logs**; empty-handed `E` takes one back out. Stored units are shown on the
  pallet as cross-hatched piles. HUD shows settlement totals (via `EventBus.storage_changed`).
- `WorldItems` persists loose items; resource node state, stockpile contents and the item in the player's
  hands survive save/load. `Carryable` claims prevent storage (and later workers) from grabbing items
  someone is picking up.
- `CameraOcclusion` fades tree canopies between the camera and the player; camera pulls back while carrying.
- Iron ore art built from a KayKit rock + procedural rust crystals.

**Test performed** 14 new scenario tests (38 total). Success criterion verified through input:
cut tree (5 sword swings) → 2 physical logs → pick up → carry (heavy, 3.75 m/s) → store → count = 1.
Also: throw into pile, take back out, non-storable rejection, mining yields, regrowth, save/load of loose
items / pile contents / felled trees / carried item, save mid-fall.

**Critic findings and resolution**
| # | Finding | Status |
|---|---|---|
| 1 | Save ids from node paths; runtime-spawned entities not restorable | Deferred to Phase 3 (buildings are the first runtime-spawned persistent entities; a spawn registry will be built there) |
| 2 | No reservation/query layer for workers | Deferred to Phase 4 (first consumer); `Carryable.claim` added now |
| 3 | Delivery depends on physics settling; no store prompt | Fixed: `Interactable.item_filter/item_receiver`, direct deposit with **[E] Store** (same path for workers and construction sites) |
| 4 | Tool tags unused; worker can't chop without combos | Partly: tags ready; tools come with equipment. Worker path in Phase 4 |
| 5 | Tween race on save/load mid-fall | Fixed: yield spawned at depletion (hidden until landing), tweens killed on load; regression test |
| 6 | 8 m stockpile towers | Fixed: footprint grid, 3 layers, cross-hatched |
| 7 | Carry data split between scene and data | Fixed: weight/speed in ItemData. Shared CarryComponent deferred to Phase 4 |
| 8 | Hauling is a slog; carried log blocks view | Fixed: heavy speed 0.62→0.75, pile moved next to the forest, camera pulls back while carrying, progress bars |

**Known problems** Take-from-pile always takes the most plentiful item. Stockpile visuals are one scene
instance per unit (fine at 27 visible units per pile; MultiMesh if piles multiply). Felled trees don't
rebake navigation (stumps remain obstacles, so acceptable).

**Highest-priority next task** Phase 3: building placement + construction sites that consume hauled
materials, with runtime-spawned buildings persisting through a spawn registry.

---

## Round 1 — Phase 0 foundation + Phase 1 player vertical slice

**What changed**
- Project foundation: autoloads (EventBus, DataRegistry, SaveManager, DebugOverlay, GameManager),
  input map/physics layers/render settings generated by `tools/configure_project.gd`, scene-based
  headless test runner with input simulation, screenshot capture harness.
- Imported CC0 KayKit packs (adventurers, skeletons, dungeon, medieval buildings/nature) — fully
  rigged characters with ~76–95 animation clips each.
- Third-person player: `PlayerController` (input only), `CharacterMotor`, `CharacterAnimator`,
  `CombatController`, `InteractionController`, `CameraRig` (orbit, spring arm, zoom, shake, shoulder offset).
- Combat: 3-hit light combo, heavy, block, dodge roll with i-frames, poise/stagger with post-stagger
  immunity, flinch, hitstop (pauses combat timers + motor + animation), knockback, hit flash, hit sparks,
  synthesized placeholder SFX. Attack windows taken from the clips' measured swing peaks.
- `DamageEvent` pipeline: Hitbox → DamageReceiver (mitigation hook) → HealthComponent.
- One monster: Skeleton Warrior = `enemy.tscn` + `skeleton_warrior.tres`. AI states Idle/Chase/Attack/Return,
  distance-throttled thinking, navigation, separation, attack-slot turn taking, provoked-leash.
- Physical props: pick up / carry (arm pose, weapons stowed, speed penalty) / drop / throw; heavy loads
  block sprinting.
- Test arena region with sky, volumetric fog, SSAO, shadows, stylized ground shader; HUD (health,
  interaction prompt, controls, death banner); death → respawn; quick save/load of the player.

**Why** Phase 0 and Phase 1 of the implementation order; movement and combat must feel right before
anything else is built on them.

**Test performed**
- 24 automated tests (`tests/scenarios/test_phase1_player.gd`, `test_phase1_regressions.gd`,
  `tests/unit/test_foundation.gd`) exercising the real input actions. Measured: run 4.6 m/s, sprint 6.8,
  walk 2.1, dodge 4.3 m, 3-hit combo 42 damage, blocked hit 10→2, throw 9.5 m, heavy load 2.95 m/s.
- Visual capture of the arena (`docs/rounds/round_01/`).

**Critic findings (independent agent) and resolution**
| # | Finding | Status |
|---|---|---|
| 1 | Blocking while retreating turned the player around; target hidden behind player | Fixed: facing lock + auto-track nearest threat while blocking; strafe/backpedal animations; 0.6 m shoulder camera |
| 2 | Heavy spam stunlocks; infinite combo loop | Fixed: stagger only via poise, 1.2 s post-stagger immunity; finisher/heavy must fully recover. Stamina deferred |
| 3 | Almost no hit feedback | Fixed: real hitstop, visible knockback, hit sparks, synthesized SFX |
| 4 | Skeleton's 2nd combo swing could never fire | Fixed: `can_chain()`; regression test |
| 5 | Clips outlived gameplay state (sliding) | Fixed: `soften_action()` lets movement cut leftover clip tails |
| 6 | Pickup/throw races with stagger/death | Fixed: state re-checks after awaits, drop on stagger/death, carrier collision exception; tests |
| 7 | Load while dead → immortal player | Fixed: `can_save()` veto, load revives through CombatController; test |
| 8 | CombatController overloaded, tuning hardcoded | Partly: targeting extracted, dodge/pickup/throw tuning exported, monster stagger in EnemyDefinition, `source_combatant` on DamageEvent |
| 9 | Dog-piling, leash exploit, static hitbox | Fixed: attack slots, provoked timer, per-attack hitbox shapes |
| 10 | Per-frame nav allocations, constant repaths | Fixed: nav readiness cached per think, repath only on >1 m goal change |

**Architecture impact** Shared components mean companions (Phase 7) reuse player/enemy parts unchanged.
**Performance impact** AI thinking throttled by distance; per-frame costs are motor + animator only.

**Known problems**
- No stamina: block and dodge are free (deliberately deferred until more enemy types exist).
- Motor/animator still tick every frame for distant characters (fine now; needs LOD once workers exist).
- Placeholder SFX are synthesized; no music or ambience.
- Ground is flat and oversaturated; no foliage (visual gauntlet comes after the loop works).
- "2 resources still in use at exit" warning when the test runner quits.

**Failed approaches** Overhead carry pose: the chibi KayKit arms can't reach above the head, so the
load now sits in front at chest height with a two-handed pose sampled from `2H_Ranged_Aiming`.

**Highest-priority next task** Phase 2: trees/rocks/ore that you chop and mine into *physical* logs and
stone, carried to a stockpile that counts them.
