# Home Steady

A 3D medieval-fantasy settlement-building action RPG in Godot 4.7, inspired by Romestead's loop
(explore → gather → haul → build → recruit → automate → equip → quest → dungeon → expand)
and reskinned with D&D archetypes.

Development follows the **Gauntlet Loop** in `docs/GAUNTLET.md`: one coherent improvement per round,
verified through play (scripted and visual), reviewed by a critic, and logged in `PROGRESS.md`.

## Running

1. Install **Godot 4.7.2** (standard build, not .NET): https://godotengine.org/download
2. Open `project.godot` in the editor (first import takes ~40 s: it imports the KayKit art).
3. Press **F5** (Play). Pick a class (Fighter / Ranger / Wizard) or **C** to continue a save.
   The start scene is `main.tscn` → `world/regions/test_arena.tscn`.
4. Vesna, a ranger, waits west of the camp. Talk to her (E): the camp has a free bed, so she can move
   in; then ask her (or any settler) to join your party.
5. North along the road, past the skeletons, stands the **Abandoned Crypt** (E at its door): rooms of
   rising skeletons, archers, a treasure chest, a spike hall (watch the rhythm, then sprint) and a
   Skeleton Champion.

## Controls

| Action | Keyboard / Mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Look | Mouse | Right stick |
| Sprint / Walk | Shift / Alt | L3 |
| Jump | Space | A |
| Dodge roll | Ctrl or C | B |
| Light attack (3-hit combo) | LMB | RB |
| Heavy attack | F | RT |
| Block (melee) / Aim (ranged) | RMB (hold) | LB |
| Class ability | Q | R3 |
| Build mode / rotate / cancel site | B / R / X | D-pad |
| Interact / pick up / put down / talk / revive | E | X |
| Party: hold ⇄ follow | T | D-pad left |
| Drop | G | Y |
| Throw (while carrying) | LMB | RB |
| Quick save / load | F5 / F9 | |
| Debug overlay | F3 | |
| Hide controls help | H | |
| Pause / free mouse | Esc | Start |

## Tests

Headless gameplay tests drive the real scenes through the input actions:

```sh
GODOT=/path/to/godot tools/run_tests.sh            # all tests
GODOT=/path/to/godot tools/run_tests.sh phase1     # filter by file name
VERBOSE_TESTS=1 tools/run_tests.sh                 # print every measured value
GODOT=/path/to/godot tools/capture.sh phase1       # render screenshots to tests/output/
```

On macOS `GODOT` is typically `/Applications/Godot.app/Contents/MacOS/Godot`.

## Layout

Follows the folder structure from the design spec: `core/` (events, save, state machine, data registry,
utilities), `data/` (all content as `.tres` resources), `characters/` (shared components, player, npc),
`combat/`, `ai/`, `world/`, `settlement/`, `items/`, `ui/`, `art/`, `audio/`, `tests/`.
See `docs/ARCHITECTURE.md`.

## Credits

Characters, props, buildings and dungeon kit: **KayKit** by Kay Lousberg (CC0) — www.kaylousberg.com.
Placeholder sound effects are synthesized by `tools/synth_sfx.py`.
