# Poly Haven derived assets (CC0)

- `*_diff.jpg` / `*_nor.jpg` — Poly Haven CC0 textures (cobblestone_floor_02, castle_brick_07,
  wood_planks, painted_plaster_wall, clay_roof_tiles, thatch_roof_angled, raked_dirt,
  muddy_tracks, brown_mud_02), 512–1024 px copies vendored by github.com/Xollonox/Game.
- `models/` — Poly Haven CC0 props (wooden_crate_01, jug_01, stone_01, round_wooden_table_01,
  wooden_display_shelves_01), 1k FBX, via github.com/chmajster/WroclawTheGame.
- `vegetation/` — foliage atlases and billboard cards derived from Poly Haven CC0 scans
  (island_tree_01, grass_medium_01/02, shrub_02, fern_02, celandine_01) by the OloEngine
  vegetation importer (github.com/drsnuggles8/OloEngineBase). Per-asset provenance in
  `LICENSE_*.md`; the OloEngine repository licence is kept in `LICENSE_OloEngine_repo.txt`.
- `cloth2_*` — ambientCG Fabric066 (CC0), via the same Xollonox/Game copy.
- `models_opt/` — Poly Haven CC0 models downloaded from polyhaven.com (1k glTF) through
  Blender and reduced there for real-time use (leaf islands thinned and decimated, twigs and
  trunks decimated to ~18k tris, re-exported as GLB with JPEG textures): island_tree_01/02/03,
  tree_small_02, tree_stump_01, dead_tree_trunk, fern_02, shrub_01–04, nettle_plant,
  rock_moss_set_01/02, coast_rocks_01, modular_wooden_pier, ship_pinnace, wine_barrel_01,
  wooden_barrels_01, wooden_crate_02, painted_wooden_bench, planter_box_01, stone_fire_pit,
  wooden_lantern_01. Loaded through `art/props/ph_models.gd` (PHModels).
- `tex/` — Poly Haven CC0 PBR texture sets (1–2k: diff, nor_gl, rough, ao) downloaded from
  polyhaven.com: grassy_cobblestone, stone_pathway, mossy_cobblestone, leafy_grass,
  forest_ground_04, sparse_grass, stony_dirt_path, coast_sand_01, damp_beach_sand,
  clay_roof_tiles_02, red_slate_roof_tiles_01, roof_tiles_14, white_rough_plaster,
  worn_plaster_wall, red_plaster_weathered, weathered_planks, wood_planks_dirt,
  old_stone_wall, mossy_stone_wall, rock_path.

All Poly Haven assets are CC0 (https://polyhaven.com/license).
