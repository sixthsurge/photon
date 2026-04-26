<br><br>

<h1 align = "center">Photon Shaders</h1>

<p align = "center">A gameplay-focused shader pack for Minecraft</p>

> **This is a patched fork of Photon Shaders with full [Physics Mod](https://minecraftphysicsmod.com/) and [Colorwheel](https://github.com/djefrey/Colorwheel) compatibility.**
> Includes fixes for Physics Mod's custom water and object interactions, and native Colorwheel support for Flywheel-based mods (e.g. Create).
> Based on the original [Photon](https://github.com/sixthsurge/photon) by sixthsurge.

![Screenshot](docs/images/rainbow.png)

## Acknowledgments

* Menu translations: 
  * [NakiriRuri](https://github.com/NakiriRuri) and [OrzMiku](https://github.com/Orzmiku) - Chinese Simplified (China; Mandarin)
  * [ChunghwaMC](https://github.com/ChunghwaMC) - Chinese Traditional (Taiwan; Mandarin)
  * [Jmayk](https://github.com/Jmayk-dev) - Italian
  * [Timtaran](https://github.com/Timtaran) - Russian
  * sincerity - Estonian
  * Patatagod69 - Dutch
* [Emin](https://github.com/EminGT) - Shadow bias method from [Complementary Reimagined](https://www.complementary.dev/shaders/) (fully fixes peter panning and light leaking underground!)
* [DrDesten](https://github.com/DrDesten) - Depth tolerance calculation for SSR (helps to prevent false reflections)
* [Jessie](https://github.com/Jessie-LC) - f0 and f82 values for labPBR hardcoded metals
* [Sledgehammer Games](https://www.sledgehammergames.com/) - Bloom downsampling method used in Call of Duty Advanced Warfare (described [here](http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare))
* http://momentsingrapics.de/ - Blue noise texture
* [NASA Scientific Visualization Studio](https://svs.gsfc.nasa.gov/4851) - Galaxy image

## Installation

* Photon can be used with [Iris](https://irisshaders.dev/download) (recommended) or [OptiFine](https://optifine.net/home)
* Iris is a modern shader loader with far better performance, mod compatibility and developer features than OptiFine. Some features (Colored Lighting) will only work on Iris
* Once you have your preferred shader loader installed, simply place the downloaded zip file in your `.minecraft/shaderpacks` folder

## Building

Requires **JDK 21** and **Gradle** (wrapper included).

```bash
# Open your Terminal
Open it in a Location where you want to clone the repository

# Clone the repo
git clone https://github.com/realBritakee/photon.git

# Pack as Zip
tar -a -c -f "Photon_1.3b x Physicsmod.zip" "shaders" "LICENSE"
```


## Features
* Native [Colorwheel](https://github.com/djefrey/Colorwheel) support — Flywheel-based mods (e.g. [Create](https://modrinth.com/mod/create/)) render correctly with full Photon shading and shadows
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
* Nvidia, AMD and Intel GPUs
* Iris - version 1.5 and above
* OptiFine - on Minecraft 1.16.5 and above
* Photon is also compatible with [Distant Horizons](https://www.curseforge.com/minecraft/mc-mods/distant-horizons)
* Native [Colorwheel](https://github.com/djefrey/Colorwheel) support for Flywheel 1.0 mods — no Colorwheel Patcher needed
  * Forge 1.20.1: use `colorwheel-forge-1.2.4+mc1.20.1.jar`
  * NeoForge 1.21.1: use `colorwheel-neoforge-1.2.4+mc1.21.1.jar`
* Apple Metal: Disable _SH Skylight_ and _Colored Shadows_

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
