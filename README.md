<br><br>

<h1 align = "center">Photon Shaders — Reimagined</h1>

<p align = "center">A gameplay-focused shader pack for Minecraft — extended with Physics Mod and Colorwheel support</p>

> **This is a custom fork of [Photon Shaders](https://github.com/sixthsurge/photon) by sixthsurge.**
> Extended with full [Physics Mod](https://minecraftphysicsmod.com/) compatibility and native [Colorwheel](https://github.com/djefrey/Colorwheel) support for Flywheel-based mods (e.g. Create).
> Colorwheel is **optional** — the shader works normally without it.
>
> See [CHANGELOG.md](CHANGELOG.md) for a full list of changes from the original.

![Screenshot](docs/images/oceanphysics.png)

## Acknowledgments

* Menu translations: 
  * [NakiriRuri](https://github.com/NakiriRuri) and [OrzMiku](https://github.com/Orzmiku) - Chinese Simplified (China; Mandarin)
  * [ChunghwaMC](https://github.com/ChunghwaMC) - Chinese Traditional (Taiwan; Mandarin)
  * [Jmayk](https://github.com/Jmayk-dev) - Italian
  * [Timtaran](https://github.com/Timtaran) - Russian
  * [shihyeon](https://github.com/shihyeon) - Korean
  * [DVRKHz](https://github.com/DVRKHz) - Spanish
  * [Patatagod69](https://github.com/PatataNL) - Dutch
  * sincerity - Estonian
* [Emin](https://github.com/EminGT) - Shadow bias method from [Complementary Reimagined](https://www.complementary.dev/shaders/) (fully fixes peter panning and light leaking underground!)
* [DrDesten](https://github.com/DrDesten) - Depth tolerance calculation for SSR (helps to prevent false reflections)
* [Essentuan](https://github.com/Essentuan) - Photonics mod support
* [Jessie](https://github.com/Jessie-LC) - f0 and f82 values for labPBR hardcoded metals
* [Sledgehammer Games](https://www.sledgehammergames.com/) - Bloom downsampling method used in Call of Duty Advanced Warfare (described [here](http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare))
* http://momentsingrapics.de/ - Blue noise texture
* [NASA Scientific Visualization Studio](https://svs.gsfc.nasa.gov/4851) - Galaxy image

## Installation

* Place the downloaded zip file in your `.minecraft/shaderpacks` folder
* Requires [Iris](https://irisshaders.dev/download) 1.5+ (recommended) or [Oculus](https://www.curseforge.com/minecraft/mc-mods/oculus) on Forge
* OptiFine is also supported on Minecraft 1.16.5 and above

### Optional: Physics Mod
* Install [Physics Mod](https://minecraftphysicsmod.com/) — ocean waves and object physics will render correctly with Photon's pipeline automatically

### Optional: Colorwheel (Create mod support)
* Install [Colorwheel](https://github.com/djefrey/Colorwheel) to enable proper shading for Flywheel-based mods (e.g. [Create](https://modrinth.com/mod/create/))
* No Colorwheel Patcher needed — native `clrwl_*` programs are built in
* Forge 1.20.1: `colorwheel-forge-1.2.4+mc1.20.1.jar`
* NeoForge 1.21.1: `colorwheel-neoforge-1.2.4+mc1.21.1.jar`

## Building

```bash
# Clone the repo
git clone https://github.com/realBritakee/photon.git
cd photon
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
* Native [Colorwheel](https://github.com/djefrey/Colorwheel) support — Flywheel-based mods (e.g. [Create](https://modrinth.com/mod/create/)) render correctly with full Photon shading and shadows
* Full [Physics Mod](https://minecraftphysicsmod.com/) ocean support — realistic wave physics rendered correctly in the deferred pipeline
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
* **_NOT_** Apple Metal — may work with _SH Skylight_ and _Colored Shadows_ disabled

### Shader loaders
* Iris 1.5+ (recommended)
* Oculus (Forge)
* OptiFine — Minecraft 1.16.5 and above

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
