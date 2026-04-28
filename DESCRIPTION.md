# Photon Shaders - Physics Mod + Colorwheel

**Minecraft 1.16+ - Iris 1.5+**

> **This is a clean upstream PR branch.** It contains only the Physics Mod ocean support and Colorwheel integration patches - no Reimagined visual changes. For the full custom version see [Photon Reimagined](https://github.com/realBritakee/photon-reimagined/tree/reimagined).

---

A clean patch set on top of [Photon Shaders](https://github.com/sixthsurge/photon) by sixthsurge adding two major compatibility improvements:

## Physics Mod Ocean Support

Realistic wave physics from [Physics Mod](https://minecraftphysicsmod.com/) are now rendered correctly in Photon's deferred pipeline. Wave normals, foam, and water geometry all integrate with Photon's water rendering pass instead of clashing with it.

## Colorwheel / Flywheel Integration

[Create](https://modrinth.com/mod/create/) and other Flywheel-based mods use [Colorwheel](https://github.com/djefrey/Colorwheel) to hook into the shader pipeline. This patch adds native Colorwheel support so Create contraptions, trains, and moving parts render with full Photon shading and shadows instead of appearing flat or unlit.

## What is not included

This branch contains no visual style changes, profile systems, or quality preset expansions. It is kept clean for upstream PR submission purposes.

## Credits

- Original shader: [Photon Shaders](https://github.com/sixthsurge/photon) by sixthsurge
- Physics Mod + Colorwheel patches: Britakee
