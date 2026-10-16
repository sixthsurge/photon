/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/d4_split.glsl:
  Pass selection for deferred4 on Apple Silicon

  macOS runs OpenGL 4.1 on Metal, which allows 16 samplers per program, and
  Iris itself always binds colortex0 to unit 0 (and on Iris 1.7.x reserves
  units 1 and 2 in fullscreen passes). The deferred shading pass needs more
  than that, so with APPLE_COMPAT it runs as three passes instead:

  deferred4 (D4_PASS_SHADOWS):  filter shadows -> colortex13 (rgb: shadows,
                                a: sss depth); draw galaxy, skytextured
                                output and stars -> colortex0 (sky only)
  deferred5 (D4_PASS_LIGHTING): diffuse lighting + specular highlight ->
                                colortex0 (terrain only)
  deferred6 (D4_PASS_COMPOSE):  sky, reflections, fog and clouds on top of
                                colortex0; clears colortex13 for the
                                translucent layer

  Otherwise deferred4 does everything (D4_PASS_FULL), as upstream.

--------------------------------------------------------------------------------
*/

#if !defined INCLUDE_PROGRAM_D4_SPLIT
#define INCLUDE_PROGRAM_D4_SPLIT

#define D4_PASS_FULL 0
#define D4_PASS_SHADOWS 1
#define D4_PASS_LIGHTING 2
#define D4_PASS_COMPOSE 3

// deferred5/deferred6 define D4_PASS before including this file
#if !defined D4_PASS
#if defined APPLE_COMPAT && !defined WORLD_NETHER
#define D4_PASS D4_PASS_SHADOWS
#else
#define D4_PASS D4_PASS_FULL
#endif
#endif

// True if the current pass runs the work belonging to pass p
#define D4_NEEDS(p) (D4_PASS == D4_PASS_FULL || D4_PASS == (p))

#endif // INCLUDE_PROGRAM_D4_SPLIT
