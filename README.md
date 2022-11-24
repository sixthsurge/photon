<br><br>

<h1 align = "center">photon</h1>

<p align = "center">A high performance shader pack for Minecraft: Java Edition with a "natural" visual style</p>

<div align = "center">
	<a href="http://www.youtube.com/watch?feature=player_embedded&v=2yW1ZKGWwJk" target="_blank"><img src="http://img.youtube.com/vi/2yW1ZKGWwJk/0.jpg" width="640" height="256" border="0" /></a>
	<p> Excellent timelapse video by TheFinkie
	<br><br>
	<a href="http://www.youtube.com/watch?feature=player_embedded&v=yy4ucw9wX-8" target="_blank"><img src="http://img.youtube.com/vi/yy4ucw9wX-8/0.jpg" width="640" height="360" border="0" /></a>
	<p> Another awesome showcase video by iambeen
</div>

## Notice

I'm currently working on a new version of Photon with a more stylised visual direction and an emphasis on being comfortable to use for actual survival gameplay. You can try it on the [rework](https://github.com/sixthsurge/photon/tree/rework) branch.

## Compatibility

### GPU vendors

Photon should be compatible with all Nvidia and AMD graphics cards on Windows and Linux supporting OpenGL 4.1. It is also known to be compatible with at least some Intel iGPUs.

### Minecraft versions

Minimum supported Minecraft version: **1.16.5** (or **1.17 for 5th gen Intel iGPUs and below**)

Sadly, the developer of OptiFine no longer backports newer features to older Minecraft versions, and Photon relies on some relatively recent OptiFine additions to work, so **I cannot make Photon compatible with older Minecraft versions**.

### Minecraft mods

Photon does not explicitly aim for compatibility with modded Minecraft. Notably, the shaders are disabled in all modded dimensions, and shader effects like waving foliage will not be applied to modded blocks. That said, there is no reason why the shaders shouldn't be generally compatible with most smaller modpacks.

### Iris

At the time of writing, Iris does not yet support all of the shaders mod features that Photon requires. However, once Iris is more complete, Photon will most likely be compatible. It is the job of Iris to support a shader pack, not the other way around.
