# Changelog — Photon Shaders: Reimagined

All changes relative to the original [Photon Shaders](https://github.com/sixthsurge/photon) by sixthsurge.

---

## [Unreleased] — 2026-04-26

### Added

#### Physics Mod Support
- Added `world0/physics_ocean.vsh` and `world0/physics_ocean.fsh` — dedicated shader programs for Physics Mod ocean rendering
- Added `world-1/physics_ocean.vsh/.fsh` and `world1/physics_ocean.vsh/.fsh` — Nether and End dimension variants
- Physics Mod ocean waves and water interactions now render correctly inside Photon's deferred pipeline
- Shadow sampling updated to use `get_filtered_shadows()` (aligned with upstream refactor from `calculate_shadows()`)
- DH/Voxy terrain depth check updated to `is_lod_terrain()` (aligned with upstream rename from `is_distant_horizons_terrain()`)

#### Native Colorwheel Support (Flywheel 1.0 / Create mod)
- Added `shaders/colorwheel.properties` — OIT config, colortex1 as RGBA32F gbuffer target, shadowcolor0 as RGB16F
- Added `shaders/program/clrwl_gbuffers.vsh/.fsh` — routes Flywheel-instanced geometry into Photon's gbuffer pipeline (colortex1 / `gbuffer_data_0` pack format)
- Added `shaders/program/clrwl_shadow.vsh/.fsh` — shadow pass for Flywheel instances using Photon's `distort_shadow_space()` and `0.25 * srgb_eotf_inv(color) * rec709_to_rec2020` output format
- Added per-world wrapper files in `world0/`, `world-1/`, `world1/` so Colorwheel's `ProgramSetMixin` can locate the programs at the correct directory level
- Colorwheel is **optional** — without the mod installed, these files are simply ignored
- Compatible with:
  - Forge 1.20.1: `colorwheel-forge-1.2.4+mc1.20.1.jar`
  - NeoForge 1.21.1: `colorwheel-neoforge-1.2.4+mc1.21.1.jar`
- No Colorwheel Patcher required

### Fixed

- **[Bloom] Fix edge bleeding** (upstream `31b57c6a2b`) — added UV clamping (`pad_amount`) in `c14_c18_bloom_upsample.fsh` and `c19_color_grading.fsh` to prevent bloom from bleeding at tile edges
- **Shader fails to load on 1.21.1 with Iris** — removed `flat` interpolation qualifier from `tbn` varying in `gbuffers_all_solid.vsh/.fsh`; upstream Colorwheel PR #566 reintroduced this, causing a GLSL link error across all separate entity draw programs

### Changed

- Renamed fork from "Photon Shaders" to **"Photon Shaders — Reimagined"**
- Merged all custom patches into a single branch (no separate `physicsmod`/`colorwheel` branches)
- Synced with upstream `sixthsurge/photon:main` — 121 upstream commits absorbed (Voxy support, SSRT shadows, cloud improvements, refactoring, bug fixes)
- `shaders.properties`: updated renamed settings from upstream:
  - `WATER_REFRACTION` → `REFRACTION`
  - `WATER_REFRACTION_INTENSITY` → `REFRACTION_INTENSITY`
  - `CLOUDS_CUMULUS_CONGESTUS_PRIMARY_STEPS_H/Z` → `CLOUDS_CUMULUS_CONGESTUS_PRIMARY_STEPS`
  - Removed `CLOUDS_DAILY_WEATHER` (no longer exists in upstream)
- Updated `includes/misc/distant_horizons.glsl` reference → `lod_mod_support.glsl` (upstream rename)

### Upstream changes absorbed (summary)
- **Voxy support** — LoD mod terrain renders correctly alongside Photon (both Distant Horizons and Voxy)
- **SSRT shadows** — screen-space ray-traced shadows as an alternative to shadow maps
- **Cloud improvements** — Cumulus Congestus cloud type, Cirrocumulus, Noctilucent, Blocky clouds, daily weather system
- **Photonics mod support** — integration with the Photonics lighting mod
- **Shadow refactoring** — `calculate_shadows()` replaced with `get_filtered_shadows()` in `pcss.glsl`
- **LPV (Light Propagation Volumes)** improvements
- **Aurora rendering** improvements
- **Numerous bug fixes** — caustics, cloud edge artifacts, light leaking, underwater rendering

---

## Base — Photon Shaders by sixthsurge

The original Photon Shaders project is maintained at [github.com/sixthsurge/photon](https://github.com/sixthsurge/photon).
This fork diverged from commit `4bb8347` ("Fix caustics in older MC versions", 2025-08-11).
