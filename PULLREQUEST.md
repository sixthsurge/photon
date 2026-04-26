# Pull Request Description — Photon Shaders

> This document describes the changes made in this fork for submission to the original [Photon Shaders](https://github.com/sixthsurge/photon) repository.
> It covers two independent features that can be reviewed and merged separately.

---

## Feature 1: Physics Mod Ocean Support

### What it does
Adds proper rendering support for [Physics Mod](https://minecraftphysicsmod.com/) ocean waves inside Photon's deferred pipeline. Without this, Physics Mod's dynamic water surface either renders incorrectly or falls back to vanilla rendering when Photon is active.

### Files added
| File | Purpose |
|------|---------|
| `shaders/world0/physics_ocean.vsh` | Vertex shader for Physics Mod ocean — overworld |
| `shaders/world0/physics_ocean.fsh` | Fragment shader for Physics Mod ocean — overworld |
| `shaders/world-1/physics_ocean.vsh` | Nether variant |
| `shaders/world-1/physics_ocean.fsh` | Nether variant |
| `shaders/world1/physics_ocean.vsh` | End variant |
| `shaders/world1/physics_ocean.fsh` | End variant |

### How it works
- Physics Mod injects a custom `physics_ocean` program into the shaderpack. When present, it uses this program to render the ocean surface with its own vertex displacement for wave physics.
- The vertex shader (`physics_ocean.vsh`) receives Physics Mod's wave data (`physics_localPosition`, `physics_localWaviness`, `physics_ripples`, `physics_waviness`) and outputs the standard Photon varyings (TBN matrix, light levels, positions).
- The fragment shader (`physics_ocean.fsh`) is built on top of Photon's `PROGRAM_GBUFFERS_WATER` logic:
  - Uses `get_filtered_shadows()` from `/include/lighting/shadows/pcss.glsl` for proper shadow sampling
  - Uses `water_absorption_approx_physics()` for physically-based water absorption
  - Writes to `RENDERTARGETS: 3,13` (refraction data + translucent layer) — same as Photon's regular water
  - Fully supports Distant Horizons / Voxy via `is_lod_terrain()` from `lod_mod_support.glsl`

### Compatibility
- Works with all Photon profiles
- No impact when Physics Mod is not installed (programs are simply not loaded)
- Tested on Forge 1.20.1 with Oculus + Embeddium

---

## Feature 2: Native Colorwheel Support (Flywheel 1.0 / Create mod)

### What it does
Adds native shader support for [Colorwheel](https://github.com/djefrey/Colorwheel), which enables Flywheel-based mods (most notably [Create](https://modrinth.com/mod/create/)) to render with Photon's full lighting and shadows instead of falling back to flat unshaded rendering.

Without this, all Create contraptions, cogwheels, flywheels, trains, etc. render without any shader shading — they appear fullbright and unaffected by Photon's lighting pipeline.

### Architecture
Colorwheel works by scanning for `clrwl_gbuffers` and `clrwl_shadow` programs in the active world directory (e.g., `shaders/world0/`) and injecting a `clrwl_computeFragment()` function at runtime that provides the Flywheel instance data (albedo, lightmap coords, AO, overlay color).

We use thin per-world wrapper files that define the correct `WORLD_*` macro and delegate to shared implementation files in `shaders/program/`.

### Files added
| File | Purpose |
|------|---------|
| `shaders/colorwheel.properties` | OIT config, colortex1 = RGBA32F (gbuffer_data_0), shadowcolor0 = RGB16F |
| `shaders/program/clrwl_gbuffers.vsh` | Shared gbuffer vertex shader for Flywheel instances |
| `shaders/program/clrwl_gbuffers.fsh` | Writes to colortex1 in Photon's `gbuffer_data_0` pack format |
| `shaders/program/clrwl_shadow.vsh` | Shadow pass vertex shader using Photon's `distort_shadow_space()` |
| `shaders/program/clrwl_shadow.fsh` | Shadow color output: `0.25 * srgb_eotf_inv(color) * rec709_to_rec2020` |
| `shaders/world0/clrwl_gbuffers.vsh/.fsh` | Overworld wrappers (`#define WORLD_OVERWORLD`) |
| `shaders/world0/clrwl_shadow.vsh/.fsh` | Overworld shadow wrappers |
| `shaders/world-1/clrwl_gbuffers.vsh/.fsh` | Nether wrappers (`#define WORLD_NETHER`) |
| `shaders/world-1/clrwl_shadow.vsh/.fsh` | Nether shadow wrappers |
| `shaders/world1/clrwl_gbuffers.vsh/.fsh` | End wrappers (`#define WORLD_END`) |
| `shaders/world1/clrwl_shadow.vsh/.fsh` | End shadow wrappers |

### gbuffer_data_0 pack format (colortex1)
The `clrwl_gbuffers.fsh` writes colortex1 in Photon's exact pack format:
```glsl
gbuffer_data_0.x = pack_unorm_2x8(albedo.rg);
gbuffer_data_0.y = pack_unorm_2x8(albedo.b, float(material_mask) / 255.0);
gbuffer_data_0.z = pack_unorm_2x8(encode_unit_vector(flat_normal));
gbuffer_data_0.w = pack_unorm_2x8(dither_8bit(light_levels, dither));
```
`material_mask` is set to `0` (generic solid) since Flywheel instances have no `mc_Entity` data.

### colorwheel.properties
```properties
# OIT — use frontmost fragment for gbuffer and shadow targets
colortex1.format = RGBA32F
colortex1.nearest = false
colortex1.oit = frontmost

shadowcolor0.format = RGB16F
shadowcolor0.oit = frontmost
```

### Compatibility
- **Optional** — if Colorwheel is not installed, all `clrwl_*` files and `colorwheel.properties` are completely ignored. Zero impact on normal rendering.
- No Colorwheel Patcher required
- Compatible with:
  - Forge 1.20.1: `colorwheel-forge-1.2.4+mc1.20.1.jar`
  - NeoForge 1.21.1: `colorwheel-neoforge-1.2.4+mc1.21.1.jar`
- Tested with Create mod on Forge 1.20.1 + Oculus + Embeddium

---

## Notes for the reviewer

- Both features are fully independent — they can be merged separately or together
- No existing Photon files were modified for either feature (all additions are new files)
- The only exception: `colorwheel.properties` is a new top-level file in `shaders/`
- Both features have been tested in-game and confirmed working

## Fork / source
- Fork: https://github.com/realBritakee/photon
- Branch: `physicsmod`
