<br><br>

<h1 align = "center">Photon Shaders - Reimagined</h1>

<p align = "center">Clean upstream PR branch - Physics Mod ocean support and native Colorwheel integration only. No Reimagined visual changes. See <a href="https://github.com/realBritakee/photon-reimagined/tree/reimagined">reimagined</a> for the full custom version.</p>

<p align = "center">A custom Minecraft shader pack based on <a href="https://github.com/sixthsurge/photon">Photon</a> by <a href="https://github.com/sixthsurge">sixthsurge</a>, with Physics Mod ocean physics compatibility and advanced Colorwheel support</p>

> See [CHANGELOG.md](CHANGELOG.md) for a full list of changes from the original.


> **Works best with:**
> 🧊 [Voxy - NeoForge Port](https://github.com/realBritakee/voxy-neoforge) - compatible Voxy build for 1.20.1/1.21.1 with Physics Mod ocean support · [other versions](https://modrinth.com/mod/voxy)
> 🌍 [Voxy World Gen V2](https://github.com/realBritakee/voxy_worldgen_v2) - background chunk pre-generation for Voxy · [other versions](https://modrinth.com/mod/voxy-worldgen)

### Reimagined
![Reimagined](docs/images/reimagined.png)

### Apocalyptic
![Apocalyptic](docs/images/apocalyptic.png)

### Original
![Original](docs/images/original.png)

## Visual Styles

Switch between three visual profiles directly in the shader settings:

* **Reimagined** (default) - enhanced cinematic look with full Photon quality
* **Apocalyptic** - darker, desaturated post-apocalyptic atmosphere with heavy fog
* **Original** - vanilla Photon defaults

## Quality Presets

7 quality presets from Potato to Ultra, each targeting specific hardware:

| Preset | Shadow Res | Shadow Dist | Key Features | Target Hardware |
|--------|-----------|-------------|-------------|----------------|
| Potato | 512 | 64 | Bare minimum | Integrated GPUs |
| Very Low | 1024 | 64 | Basic shadows | Weak laptops |
| Low | 1024 | 96 | PCF + VL | Budget GPUs |
| Medium | 2048 | 128 | Colored shadows, GTAO | GTX 1060-class |
| High | 2048 | 192 | Reflections, caustics, SSRT | RTX 2070-class |
| Very High | 2048 | 224 | + Colored lights | RTX 3080-class |
| Ultra | 4096 | 256 | Everything maxed | High-end only |

## Installation

* Place the downloaded zip file in your `.minecraft/shaderpacks` folder
* Requires [Iris](https://irisshaders.dev/download) 1.5+ (recommended) or [Oculus](https://www.curseforge.com/minecraft/mc-mods/oculus) on Forge
* OptiFine is also supported on Minecraft 1.16.5 and above

### Optional: Physics Mod
* Install [Physics Mod](https://minecraftphysicsmod.com/) - ocean waves and object physics will render correctly with Photon's pipeline automatically

### Optional: Colorwheel (Create mod support)
* Install [Colorwheel](https://github.com/djefrey/Colorwheel) to enable proper shading for Flywheel-based mods (e.g. [Create](https://modrinth.com/mod/create/))
* No Colorwheel Patcher needed - native `clrwl_*` programs are built in
* Forge 1.20.1: `colorwheel-forge-1.2.4+mc1.20.1.jar`
* NeoForge 1.21.1: `colorwheel-neoforge-1.2.4+mc1.21.1.jar`

## Building

```bash
# Clone the repo
git clone https://github.com/realBritakee/photon-reimagined.git
cd photon-reimagined
```

**Windows (PowerShell)**
```powershell
tar -a -c -f "Photon Shaders - Reimagined.zip" "shaders" "LICENSE"
```

**Linux / WSL**
```bash
zip -r "Photon Shaders - Reimagined.zip" shaders/ LICENSE
```

## Features
* Native [Colorwheel](https://github.com/djefrey/Colorwheel) support - Flywheel-based mods (e.g. [Create](https://modrinth.com/mod/create/)) render correctly with full Photon shading and shadows
* Full [Physics Mod](https://minecraftphysicsmod.com/) ocean support - realistic wave physics rendered correctly in the deferred pipeline
* Fully revamped sky, lighting and water
* Detailed clouds with many layers and cloud types
* Immersive weather system providing different skies each day
* Voxel-based colored lighting (enabled with Ultra profile, requires Iris)
* Screen-space reflections
* Volumetric fog
* Soft shadows with variable-size penumbras
* Detailed ambient occlusion (GTAO)
* Camera effects: bloom, depth of field, motion blur
* Much improved image quality with TAA, FXAA and CAS
* Advanced temporal upscaling (disabled by default) for low end devices
* Extensive settings menu allowing you to customize every aspect of the shader
* Full labPBR resource pack support

## Compatibility
### GPU vendors
* Nvidia
* AMD
* Intel
* **_NOT_** Apple Metal - may work with _SH Skylight_ and _Colored Shadows_ disabled

### Shader loaders
* Iris 1.5+ (recommended)
* Oculus (Forge)
* OptiFine - Minecraft 1.16.5 and above

### Special mod support
* [Distant Horizons](https://www.curseforge.com/minecraft/mc-mods/distant-horizons)
* [Voxy](https://modrinth.com/mod/voxy)
* [Photonics](https://modrinth.com/mod/photonics)
* [Physics Mod](https://minecraftphysicsmod.com/) ✅
* [Create](https://modrinth.com/mod/create/) via [Colorwheel](https://github.com/djefrey/Colorwheel) ✅

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a full list of changes from the original Photon Shaders.

## Showcase videos

<div align = "center">
	<a href="http://www.youtube.com/watch?feature=player_embedded&v=vxE_CVeU8Rs" target="_blank"><img src="http://img.youtube.com/vi/vxE_CVeU8Rs/0.jpg" border="0"/></a>
	<p> by iambeen
	<br><br>
</div>

<div align = "center">
	<a href="http://www.youtube.com/watch?feature=player_embedded&v=gMLFZMBK-ZQ" target="_blank"><img src="http://img.youtube.com/vi/gMLFZMBK-ZQ/0.jpg" border="0"/></a>
	<p> by CosmicNexus
	<br><br>
</div>

<div align = "center">
	<a href="http://www.youtube.com/watch?feature=player_embedded&v=_aSmM7jg9Nw" target="_blank"><img src="http://img.youtube.com/vi/_aSmM7jg9Nw/0.jpg" border="0"/></a>
	<p> by VIPUL
	<br><br>
</div>

---

## License

Copyright (c) sixthsurge. All rights reserved.

See [LICENSE](LICENSE) for full terms.
