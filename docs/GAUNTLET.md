GAUNTLET LOOP — MEDIEVAL 3D D&D SETTLEMENT RPG

OBJECTIVE

Build a polished vertical slice of a high-fidelity 3D medieval fantasy
settlement-building action RPG in Godot.

The game should take inspiration from Romestead's gameplay loop:

EXPLORE → GATHER → HAUL → BUILD → RECRUIT → AUTOMATE → EQUIP →
QUEST → DUNGEON → BOSS → UNLOCK NEW REGION → EXPAND SETTLEMENT

However, transform the setting into a Dungeons & Dragons-inspired
medieval fantasy world with recognizable fantasy archetypes, classes,
monsters, towns, dungeons, professions, and adventuring parties.

The player begins with a tiny medieval camp and gradually grows it into
a thriving fantasy town containing farms, workshops, guilds, defenses,
shops, taverns, magical buildings, roads, and production chains.

The player is simultaneously:

- an action RPG character
- an explorer
- a settlement founder
- an adventurer
- a recruiter
- a production manager

The world and gameplay must be fully 3D.

GRAPHICAL TARGET

Graphics should preserve the readable, colorful, slightly stylized feel
of Romestead while translating it into high-quality 3D.

Target visual qualities:

- high-fidelity stylized 3D environments
- physically based materials
- strong silhouettes
- slightly exaggerated medieval architecture
- colorful natural environments
- dense foliage
- volumetric fog
- dynamic sunlight
- believable interiors
- detailed props
- physically present resources
- high-quality character animation
- cinematic lighting without sacrificing gameplay readability

Think:

Romestead
+
high-quality stylized medieval fantasy
+
modern 3D action RPG presentation.

Do NOT attempt photorealism.

Prefer a cohesive art direction over raw polygon count.

====================================================================
CORE PLAYER LOOP
====================================================================

The fundamental gameplay loop is:

1. Leave the settlement.
2. Explore the wilderness.
3. Discover resources, ruins, encounters, NPCs, caves, and dungeons.
4. Gather resources.
5. Physically transport valuable/heavy resources.
6. Fight monsters and hostile factions.
7. Rescue or recruit characters.
8. Return to the settlement.
9. Construct buildings.
10. Assign workers.
11. Craft equipment.
12. Upgrade characters.
13. Improve settlement production.
14. Accept quests.
15. Form adventuring parties.
16. Enter increasingly dangerous regions.
17. Defeat dungeon bosses.
18. Unlock resources, recipes, classes, spells, buildings, and biomes.
19. Establish additional settlements/outposts.
20. Connect settlements through trade and logistics.

Every system implemented must reinforce this loop.

====================================================================
PLAYER CHARACTER
====================================================================

Use a third-person 3D controller.

Required movement:

- walk
- run
- sprint
- jump
- dodge
- interact
- pickup
- carry
- throw
- light attack
- heavy attack
- block
- ranged attack
- ability usage

Movement must feel responsive before expanding the game.

Use a CharacterBody3D-based controller.

Separate:

PlayerController
CharacterMotor
CombatController
InteractionController
EquipmentController
AbilityController

Do not create one giant Player.gd script.

====================================================================
D&D-INSPIRED CLASSES
====================================================================

Create a data-driven fantasy class system.

Initial vertical slice classes:

FIGHTER
- sword + shield
- heavy armor
- defensive abilities
- taunt
- shield bash

RANGER
- bow
- tracking bonuses
- traps
- wilderness gathering bonuses

ROGUE
- daggers
- stealth
- critical attacks
- lockpicking
- trap disarming

CLERIC
- mace
- healing
- blessings
- undead bonuses

WIZARD
- staff
- ranged spells
- elemental magic
- utility magic

BARBARIAN
- two-handed weapons
- rage
- high health
- resource gathering bonuses

Later architecture should permit:

Paladin
Druid
Bard
Warlock
Monk
Sorcerer

without modifying core systems.

Classes MUST be Resources/data definitions rather than giant switch
statements.

Example architecture:

CharacterClassData
 ├── starting_stats
 ├── starting_equipment
 ├── skill_tree
 ├── abilities
 ├── proficiencies
 └── passive_modifiers

====================================================================
CHARACTER / PARTY SYSTEM
====================================================================

The world contains recruitable fantasy characters.

Characters have:

- name
- race
- class
- level
- attributes
- equipment
- personality traits
- profession
- combat abilities
- preferred jobs
- relationships
- morale
- needs

Initial fantasy races:

- Human
- Elf
- Dwarf
- Halfling
- Half-Orc

Do not create dozens of races initially.

YAGNI.

Each recruited character can operate in TWO contexts:

SETTLEMENT ROLE
or
ADVENTURING ROLE.

Example:

A dwarf Fighter may:

Settlement:
→ work as a blacksmith

Adventure:
→ serve as party tank

A Ranger may:

Settlement:
→ hunt animals

Adventure:
→ scout wilderness

A Cleric may:

Settlement:
→ operate a chapel

Adventure:
→ heal party members.

This dual-purpose design should connect settlement simulation with the
RPG systems.

====================================================================
PARTY SYSTEM
====================================================================

Allow the player to eventually form a party of approximately:

Player + 3 companions

Companion AI states:

FOLLOW
HOLD
ATTACK
DEFEND
RETREAT
USE_ABILITY
INTERACT
DOWNED

Keep companion controls simple.

Do NOT build tactical Baldur's Gate-style combat unless required later.

====================================================================
PHYSICAL RESOURCE SYSTEM
====================================================================

Take inspiration from Romestead's physical resources.

Important resources should physically exist in the world rather than
instantly becoming abstract inventory numbers.

Examples:

- logs
- stone blocks
- ore
- grain sacks
- animal carcasses
- treasure chests
- barrels
- crates
- magical artifacts

The player can:

pickup
carry
drop
throw
load
unload

Heavy resources require:

- carts
- pack animals
- workers
- wagons
- magical transport later

This creates gameplay around logistics rather than only menus.

====================================================================
SETTLEMENT BUILDING
====================================================================

Start from:

Campfire + tents

Progress toward:

Village
Town
Fortified Town
Fantasy Stronghold

Buildings should use modular construction.

Initial buildings:

House
Farm
Warehouse
Lumber Yard
Stone Mason
Blacksmith
Carpenter
Hunter Lodge
Tavern
Marketplace
Barracks
Watchtower

Fantasy progression buildings:

Adventurers Guild
Alchemy Workshop
Wizard Tower
Temple
Enchanting Workshop
Stable
Guild Hall

Buildings provide:

- worker slots
- storage
- crafting
- production
- services
- settlement bonuses

Building definitions should be Resources.

BuildingDefinition
 ├── scene
 ├── cost
 ├── requirements
 ├── worker_slots
 ├── production_rules
 ├── storage_capacity
 └── unlock_conditions

====================================================================
WORKER / PROFESSION SYSTEM
====================================================================

Settlers automatically perform assigned professions.

Initial jobs:

Farmer
Woodcutter
Miner
Hunter
Blacksmith
Carpenter
Cook
Merchant
Guard

Workers use a reusable state-machine architecture.

Example:

IDLE
→ FIND_JOB
→ MOVE_TO_JOB
→ PERFORM_JOB
→ COLLECT_OUTPUT
→ DELIVER_OUTPUT
→ SATISFY_NEEDS
→ REPEAT

Avoid profession-specific AI scripts wherever possible.

A Farmer and Miner should share most worker infrastructure.

Behavior should be determined through JobDefinition data.

====================================================================
PRODUCTION / AUTOMATION
====================================================================

Settlement production eventually becomes increasingly automated.

Example chain:

Forest
↓
Woodcutter
↓
Logs
↓
Stockpile
↓
Carpenter
↓
Planks
↓
Builder
↓
Building

Mining:

Iron Deposit
↓
Miner
↓
Iron Ore
↓
Cart
↓
Warehouse
↓
Blacksmith
↓
Iron Ingots
↓
Weapons

Food:

Farm
↓
Wheat
↓
Mill
↓
Flour
↓
Bakery
↓
Bread
↓
Tavern / Houses

Do NOT start with complicated conveyor belts.

Medieval logistics should primarily use:

- workers
- carts
- wagons
- animals
- storage buildings
- roads

Magical automation can appear in late progression.

====================================================================
CRAFTING
====================================================================

Crafting categories:

Weapons
Armor
Tools
Food
Potions
Building Materials
Magic Items

Crafting recipes must be data-driven.

RecipeData:
- ingredients
- station
- duration
- profession requirement
- output
- quality modifiers

Do not hardcode recipes into crafting stations.

====================================================================
COMBAT
====================================================================

Combat should feel like a responsive third-person action RPG.

Initial melee requirements:

- light combo
- heavy attack
- blocking
- stagger
- dodge
- damage reactions
- hit detection
- death

Use animation-driven attacks with dedicated Hitbox/Hurtbox components.

Combat architecture:

Combatant
DamageReceiver
Hitbox
StatsComponent
StatusEffectComponent
AbilityComponent

Avoid:

Enemy.take_sword_damage()

Prefer:

DamageEvent {
    source
    target
    damage_type
    amount
    tags
}

This allows:

fire
ice
poison
physical
holy
necrotic

without rewriting combat.

====================================================================
MONSTERS
====================================================================

Start with only a small representative roster.

Tier 1:

Goblin
Wolf
Bandit
Skeleton
Giant Spider

Tier 2:

Orc
Ogre
Wraith
Troll
Cultist

Boss prototype:

Goblin Chieftain
or
Necromancer

Each enemy uses:

EnemyDefinition
+
shared EnemyController
+
StateMachine
+
Ability definitions

Do NOT create bespoke monolithic AI for every monster.

====================================================================
DUNGEONS
====================================================================

World exploration should contain procedural or semi-procedural
dungeons.

Initial dungeon:

Abandoned Crypt

Structure:

Entrance
↓
Exploration Rooms
↓
Enemy Encounter
↓
Treasure
↓
Puzzle / Hazard
↓
Elite Encounter
↓
Boss
↓
Rare Reward

Dungeon rewards may unlock:

- recipes
- crafting materials
- equipment
- spells
- recruitable characters
- buildings
- settlement upgrades

Dungeon progression MUST feed settlement progression.

====================================================================
QUEST SYSTEM
====================================================================

Quests should use reusable objective components.

Example objectives:

KillTarget
CollectItem
DeliverItem
ExploreLocation
RescueNPC
ConstructBuilding
DefendSettlement
TalkToNPC

QuestDefinition should contain objectives rather than custom quest code.

Example:

Quest:
"The Missing Blacksmith"

Objectives:

Explore Goblin Camp
↓
Defeat Goblins
↓
Rescue Blacksmith
↓
Escort Blacksmith Home

Reward:

Blacksmith NPC
+
Blacksmith building unlocked.

====================================================================
WORLD STRUCTURE
====================================================================

Use a region-based open world.

Do NOT immediately build one enormous seamless map.

Initial vertical slice:

1–2 km² region.

Contains:

Starter Settlement Area
Forest
River
Farmland
Ruined Village
Goblin Camp
Crypt Dungeon
Mountain / Mining Area

Later regions:

Grasslands
Ancient Forest
Swamp
Highlands
Snow Mountains
Desert
Cursed Lands

Each region introduces:

new resources
new enemies
new building materials
new classes/NPCs
new dungeons
new production opportunities.

====================================================================
WORLD GENERATION
====================================================================

Use procedural generation carefully.

Procedural:

- terrain variation
- foliage
- resource deposits
- small encounters
- minor ruins
- wilderness props

Hand-authored:

- towns
- major landmarks
- dungeon entrances
- quest locations
- boss arenas

Prefer hybrid generation over fully procedural everything.

====================================================================
ARCHITECTURE PRINCIPLES
====================================================================

The project MUST follow:

SMART PROGRAMMING PRINCIPLES
YAGNI
OBJECT-ORIENTED DESIGN
ABSTRACTION
COMPOSITION OVER INHERITANCE
DATA-DRIVEN DESIGN
SINGLE RESPONSIBILITY PRINCIPLE

====================================================================
YAGNI RULE
====================================================================

Never build infrastructure because it "might be useful later."

Every abstraction must solve an existing problem.

DO NOT prematurely implement:

- networking
- 50 character classes
- massive skill trees
- hundreds of recipes
- infinite procedural worlds
- complex faction diplomacy
- advanced economies
- genetic systems
- realistic weather simulation
- MMO architecture

until gameplay proves it is necessary.

====================================================================
ABSTRACTION RULE
====================================================================

Use abstraction where multiple concrete implementations already exist.

GOOD:

Interactable
 ├── Door
 ├── Chest
 ├── ResourceNode
 └── NPC

GOOD:

Job
 ├── Gather
 ├── Craft
 ├── Haul
 └── Guard

BAD:

Creating twenty abstract interfaces before any implementations exist.

Follow the Rule of Three:

Do not generalize aggressively until similar logic appears approximately
three times.

====================================================================
OBJECT-ORIENTED DESIGN
====================================================================

Prefer small components.

Character
 ├── StatsComponent
 ├── HealthComponent
 ├── EquipmentComponent
 ├── InventoryComponent
 ├── CombatComponent
 ├── AbilityComponent
 └── InteractionComponent

NPC
 ├── Character
 ├── WorkerComponent
 ├── NeedsComponent
 └── AIController

Avoid:

Character.gd
with 5,000 lines.

====================================================================
GODOT PROJECT ORGANIZATION
====================================================================

res://

core/
    events/
    state_machine/
    save/
    utilities/

data/
    classes/
    characters/
    enemies/
    items/
    recipes/
    buildings/
    jobs/
    quests/
    abilities/

characters/
    shared/
    player/
    npc/
    companions/

combat/
    abilities/
    damage/
    hitboxes/
    status_effects/

ai/
    behaviors/
    states/
    jobs/
    navigation/

world/
    terrain/
    generation/
    biomes/
    regions/
    encounters/

settlement/
    buildings/
    construction/
    production/
    logistics/
    storage/

items/
    equipment/
    resources/
    loot/

dungeons/
    generation/
    encounters/
    bosses/

ui/
    hud/
    inventory/
    crafting/
    building/
    character/
    settlement/

audio/

art/
    characters/
    environments/
    props/
    buildings/
    VFX/

tests/

====================================================================
SYSTEM COMMUNICATION
====================================================================

Avoid excessive direct references between systems.

Use:

signals
events
Resources
interfaces/components

Example:

Resource delivered
↓
Storage emits inventory_changed
↓
Production system evaluates recipes
↓
Workshop starts job
↓
Worker AI receives job
↓
Crafting completes
↓
Settlement inventory updates

Do NOT have:

Farm.gd directly manipulate
Blacksmith.gd
which directly manipulates
TownManager.gd
which manipulates UI.gd.

====================================================================
PERFORMANCE
====================================================================

Design for settlements containing many workers.

Do not run expensive logic every frame.

AI:

High-frequency:
near player / combat

Medium-frequency:
active workers

Low-frequency:
distant simulation

Use:

NavigationAgent3D
object pooling
visibility ranges
LOD
MultiMeshInstance3D
chunked terrain
distance-based AI ticking

====================================================================
SAVE SYSTEM
====================================================================

Persist IDs and data, not entire scene trees.

Save:

world seed
player state
character IDs
settlement state
building transforms
inventories
worker assignments
quest progression
world changes

Avoid serializing arbitrary live nodes.

====================================================================
GRAPHICS PIPELINE
====================================================================

Create assets progressively.

PASS 1:
Primitive/blockout assets.

PASS 2:
Stylized modular medieval kit.

PASS 3:
High-quality materials.

PASS 4:
Character models.

PASS 5:
Animation polish.

PASS 6:
Foliage and environmental dressing.

PASS 7:
Lighting/VFX polish.

Gameplay must remain playable during every art pass.

====================================================================
GAUNTLET METRIC / VERIFIER
====================================================================

Every iteration receives a 0–10 score in:

GAMEPLAY
- Player controls responsive
- Combat readable
- Exploration rewarding

SETTLEMENT
- Building intuitive
- Workers function independently
- Production chains function

RPG
- Classes meaningfully different
- Equipment works
- Character progression matters

WORLD
- Region encourages exploration
- Dungeon works
- Resources support progression

ARCHITECTURE
- Components have clear responsibilities
- No unnecessary coupling
- Data is not hardcoded unnecessarily
- YAGNI followed
- Abstractions justified

VISUALS
- Cohesive medieval fantasy style
- Strong silhouettes
- High-quality lighting
- Environment feels populated
- Visual hierarchy remains readable

PERFORMANCE
- Stable frame time
- AI scales acceptably
- No major memory leaks

A round may not be declared complete merely because the feature compiles.

It must be PLAYABLE.

====================================================================
GAUNTLET PROCESS
====================================================================

For every round:

1. Inspect the complete current project.

2. Read the current progress document.

3. Run the game.

4. Identify the highest-impact deficiency preventing the target game
   from becoming fun and complete.

5. Select ONE coherent improvement.

6. Write a small implementation plan.

7. Check the plan against:

   - Is this required now?
   - Is there already a simpler solution?
   - Am I creating an abstraction prematurely?
   - Can this system reuse existing components?
   - Does this directly improve the core gameplay loop?

8. Implement the change.

9. Run the project.

10. Verify the feature through actual gameplay.

11. Check console output for:

   errors
   warnings
   navigation failures
   invalid references
   performance problems.

12. Have a CRITIC AGENT inspect:

   gameplay quality
   architecture
   unnecessary complexity
   visual quality
   regressions.

13. Fix the most significant criticism.

14. Run the game again.

15. Compare against the previous iteration.

16. Record:

   What changed
   Why it changed
   Files changed
   Test performed
   Screenshot/video evidence
   Architecture impact
   Performance impact
   Known problems
   Failed approaches
   Score
   Highest-priority next task

17. Repeat.

====================================================================
IMPLEMENTATION ORDER
====================================================================

Do NOT develop systems randomly.

PHASE 0 — PROJECT FOUNDATION

Create:

Godot project structure
GameManager
event system
basic data Resources
save architecture
debug tools

Then stop.

Do not overbuild foundation code.

--------------------------------------------------

PHASE 1 — PLAYER VERTICAL SLICE

Build:

third-person controller
camera
interaction
pickup/drop
basic animation
basic melee combat
one enemy

SUCCESS:

The player can run around an empty test environment and combat feels
reasonably satisfying.

--------------------------------------------------

PHASE 2 — RESOURCE LOOP

Add:

trees
rocks
ore
resource gathering
physical hauling
storage

SUCCESS:

Player can:

cut tree
→ obtain log
→ physically carry log
→ place log into stockpile.

--------------------------------------------------

PHASE 3 — BUILDING

Create:

building preview
placement
construction costs
construction progress

Buildings:

House
Storage
Blacksmith
Farm

SUCCESS:

Resources gathered in the world can create a functioning settlement.

--------------------------------------------------

PHASE 4 — FIRST WORKER

Implement ONE worker.

Profession:

Woodcutter.

Loop:

Find tree
→ walk to tree
→ chop
→ collect log
→ deliver log
→ repeat.

Do not implement nine jobs yet.

--------------------------------------------------

PHASE 5 — GENERIC JOB SYSTEM

Only after Woodcutter works:

Extract reusable worker/job architecture.

Then implement:

Farmer
Miner

If these require extensive special-case logic, the abstraction is wrong.

--------------------------------------------------

PHASE 6 — CHARACTER CLASSES

Implement:

Fighter
Ranger
Wizard

Only three initially.

Classes must demonstrate:

melee
ranged
magic

before adding more.

--------------------------------------------------

PHASE 7 — COMPANIONS

Recruit one NPC.

Allow:

follow
fight
return home
work

The exact same NPC must be capable of participating in settlement and
adventure gameplay.

--------------------------------------------------

PHASE 8 — FIRST DUNGEON

Build:

Crypt

Enemies:

Skeleton
Spider
Necromancer boss

Reward:

special crafting resource
+
new building unlock.

--------------------------------------------------

PHASE 9 — SETTLEMENT ECONOMY

Implement complete chain:

Iron Ore
→ Miner
→ Warehouse
→ Blacksmith
→ Iron Sword.

Verify autonomous completion.

--------------------------------------------------

PHASE 10 — FIRST COMPLETE GAMEPLAY LOOP

The player must be able to:

Explore Forest
↓
Fight Goblins
↓
Gather Resources
↓
Return Home
↓
Build Houses
↓
Recruit Characters
↓
Assign Workers
↓
Craft Equipment
↓
Form Party
↓
Discover Crypt
↓
Clear Dungeon
↓
Defeat Boss
↓
Unlock New Technology
↓
Improve Settlement.

THIS IS THE FIRST MAJOR MILESTONE.

Do not significantly expand scope before this loop works.

====================================================================
VISUAL GAUNTLET
====================================================================

Once the game loop works, run a separate graphics gauntlet.

For each visual pass:

1. Capture gameplay screenshots.

2. Compare them against the established art target.

3. Critique:

composition
lighting
materials
scale
silhouette
terrain
foliage
character readability
architecture
environment density

4. Identify the largest visual discrepancy.

5. Fix ONLY the highest-impact discrepancy.

6. Capture new screenshots.

7. Compare before/after.

8. Repeat.

Prioritize:

Lighting
→ Terrain
→ Buildings
→ Foliage
→ Characters
→ Props
→ VFX
→ Microdetail

Do not polish barrels while the world lighting looks bad.

====================================================================
FINAL ACCEPTANCE TEST
====================================================================

The vertical slice succeeds when a new player can begin with a tiny
camp and, without developer intervention:

- control a polished third-person character
- select a fantasy class
- gather physical resources
- haul materials home
- construct a settlement
- recruit fantasy characters
- assign workers
- automate basic production
- farm
- craft equipment
- fight monsters
- recruit companions
- form an adventuring party
- accept a quest
- discover a dungeon
- defeat a boss
- obtain meaningful loot
- unlock settlement progression
- return home to visibly improve the town

The settlement must visibly transform from a camp into a small living
medieval fantasy village.

The finished experience should make the player feel:

"I built this town, these characters live here because of what I did,
and exploring the dangerous world makes my settlement stronger."

====================================================================
CRITICAL DEVELOPMENT RULE
====================================================================

At every iteration ask:

"What is the smallest feature we can implement that makes the core
Explore → Adventure → Gather → Build → Recruit → Automate → Progress
loop noticeably better?"

Build that.

Verify it.

Then repeat.

Never solve hypothetical future problems at the expense of the
currently playable game.