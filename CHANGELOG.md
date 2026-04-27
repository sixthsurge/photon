# Changelog - Photon Shaders: Reimagined

All changes relative to the original [Photon Shaders](https://github.com/sixthsurge/photon) by sixthsurge.

---

## [Unreleased] - 2026-04-27

### Added

#### Visual Style System
- Added **Visual Style** dropdown with 3 profiles: Reimagined (default), Apocalyptic, Original
- Added **7 quality presets**: Potato, Very Low, Low, Medium, High, Very High, Ultra with per-option granularity
- Added **Credits buttons**: Reimagined (by Britakee) + Photon Shaders (by sixthsurge) with color cycling
- Quality presets target specific hardware tiers from integrated GPUs (Potato) to high-end RTX 3080+ (Ultra)
- Each quality preset controls 15 individual options: shadow resolution, shadow distance, PCF, colored shadows, VPS, entity shadows, block entity shadows, reflections, GTAO, volumetric lighting, colored light shafts, water caustics, water parallax, colored lights, SSRT

#### Apocalyptic Profile
- 50% reduced brightness for a darker overall feel
- 28% desaturated colors for a washed-out, post-apocalyptic look
- 2.5x fog density for heavier atmospheric haze
- 35% murkier water absorption
- 40% desaturated sky atmosphere
- 20% reduced ambient/skylight brightness
- 15% dimmer sun intensity

#### Physics Mod Support
- Added `world0/physics_ocean.vsh` and `world0/physics_ocean.fsh` for Physics Mod ocean rendering
- Added `world-1/physics_ocean.vsh/.fsh` and `world1/physics_ocean.vsh/.fsh` for Nether and End dimensions
- Physics Mod ocean waves and water interactions render correctly inside Photon's deferred pipeline
- Shadow sampling uses `get_filtered_shadows()` (aligned with upstream refactor)
- DH/Voxy terrain depth check uses `is_lod_terrain()` (aligned with upstream rename)

#### Native Colorwheel Support (Flywheel 1.0 / Create mod)
- Added `shaders/colorwheel.properties` with OIT config, colortex1 as RGBA32F, shadowcolor0 as RGB16F
- Added `shaders/program/clrwl_gbuffers.vsh/.fsh` for Flywheel-instanced geometry in Photon's gbuffer pipeline
- Added `shaders/program/clrwl_shadow.vsh/.fsh` for shadow pass using Photon's `distort_shadow_space()`
- Added per-world wrapper files in `world0/`, `world-1/`, `world1/`
- Colorwheel is optional, without the mod these files are ignored
- Compatible with Forge 1.20.1 and NeoForge 1.21.1
- No Colorwheel Patcher required

### Fixed
- **[Bloom] Fix edge bleeding** (upstream `31b57c6a2b`) - UV clamping in bloom upsample and color grading
- **[Bloom] Bloom upsampling filter setting** (upstream `29ab67fbf4`) - Bilinear/Bicubic option
- **Boost handheld lighting + enable by default** (upstream `a4d96bb0be`) - falloff exponent raised from 1.2 to 3.0
- **Shader fails to load on 1.21.1 with Iris** - removed `flat` qualifier from `tbn` varying in `gbuffers_all_solid` and `gbuffers_all_translucent`

### Changed
- Improved option descriptions with performance impact notes and interaction info
- Synced with upstream `sixthsurge/photon:main` - 121 upstream commits absorbed (Voxy support, SSRT shadows, cloud improvements, refactoring, bug fixes)

### Upstream changes absorbed (summary)
- **Voxy support** - LoD mod terrain renders correctly alongside Photon
- **SSRT shadows** - screen-space ray-traced shadows
- **Cloud improvements** - Cumulus Congestus, Cirrocumulus, Noctilucent, Blocky clouds, daily weather
- **Photonics mod support** - integration with the Photonics lighting mod
- **Shadow refactoring** - `calculate_shadows()` replaced with `get_filtered_shadows()`
- **LPV (Light Propagation Volumes)** improvements
- **Aurora rendering** improvements
- **Numerous bug fixes** - caustics, cloud edge artifacts, light leaking, underwater rendering

---

## Base - Photon Shaders by sixthsurge

The original Photon Shaders project is maintained at [github.com/sixthsurge/photon](https://github.com/sixthsurge/photon).
This fork diverged from commit `4bb8347` ("Fix caustics in older MC versions", 2025-08-11).
