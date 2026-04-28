/*
--------------------------------------------------------------------------------

  Photon Reimagined by Britakee

  settings/profiles.glsl:
  Visual profile system — defines PROFILE IDs and per-profile overrides.

  Profiles:
    PROFILE_REIMAGINED  (0) — Reimagined look (default)
    PROFILE_ORIGINAL    (1) — Vanilla Photon defaults
    PROFILE_APOCALYPTIC (2) — Post-apocalyptic atmosphere (WIP)

  To add a profile-specific value, wrap it like:
    #if PROFILE == PROFILE_REIMAGINED
        #define MY_VALUE  1.0
    #elif PROFILE == PROFILE_ORIGINAL
        #define MY_VALUE  0.8
    #elif PROFILE == PROFILE_APOCALYPTIC
        #define MY_VALUE  0.5
    #endif

--------------------------------------------------------------------------------
*/

#if !defined SETTINGS_PROFILES_INCLUDED
#define SETTINGS_PROFILES_INCLUDED

// ----------------------
//   Profile ID constants
// ----------------------

#define PROFILE_REIMAGINED   0
#define PROFILE_ORIGINAL     2
#define PROFILE_APOCALYPTIC  1

// ----------------------
//   Active profile
//   Controlled by the in-game GUI via settings.glsl → PROFILE define.
// ----------------------

#ifndef PROFILE
#define PROFILE PROFILE_REIMAGINED
#endif

// ----------------------
//   Per-profile overrides
//   No visual changes yet — structure only.
//   All three profiles intentionally produce identical output for now.
// ----------------------

// Color grading: brightness multiplier
#if PROFILE == PROFILE_REIMAGINED
    #define PROFILE_GRADE_BRIGHTNESS_MULT  1.0
#elif PROFILE == PROFILE_ORIGINAL
    #define PROFILE_GRADE_BRIGHTNESS_MULT  1.0
#elif PROFILE == PROFILE_APOCALYPTIC
    #define PROFILE_GRADE_BRIGHTNESS_MULT  0.50
#endif

// Color grading: saturation multiplier
#if PROFILE == PROFILE_REIMAGINED
    #define PROFILE_GRADE_SATURATION_MULT  1.0
#elif PROFILE == PROFILE_ORIGINAL
    #define PROFILE_GRADE_SATURATION_MULT  1.0
#elif PROFILE == PROFILE_APOCALYPTIC
    #define PROFILE_GRADE_SATURATION_MULT  0.72
#endif

// Sky: atmosphere saturation boost
#if PROFILE == PROFILE_REIMAGINED
    #define PROFILE_ATMOSPHERE_SATURATION_MULT  1.0
#elif PROFILE == PROFILE_ORIGINAL
    #define PROFILE_ATMOSPHERE_SATURATION_MULT  1.0
#elif PROFILE == PROFILE_APOCALYPTIC
    #define PROFILE_ATMOSPHERE_SATURATION_MULT  0.65
#endif

// Fog: overworld fog density multiplier
#if PROFILE == PROFILE_REIMAGINED
    #define PROFILE_FOG_DENSITY_MULT  1.0
#elif PROFILE == PROFILE_ORIGINAL
    #define PROFILE_FOG_DENSITY_MULT  1.0
#elif PROFILE == PROFILE_APOCALYPTIC
    #define PROFILE_FOG_DENSITY_MULT  2.5
#endif

// Water: absorption multiplier
#if PROFILE == PROFILE_REIMAGINED
    #define PROFILE_WATER_ABSORPTION_MULT  1.0
#elif PROFILE == PROFILE_ORIGINAL
    #define PROFILE_WATER_ABSORPTION_MULT  1.0
#elif PROFILE == PROFILE_APOCALYPTIC
    #define PROFILE_WATER_ABSORPTION_MULT  1.35
#endif

// Sky: saturation multiplier (applied to atmosphere_post_processing)
#if PROFILE == PROFILE_REIMAGINED
    #define PROFILE_SKY_SATURATION_MULT  1.0
#elif PROFILE == PROFILE_ORIGINAL
    #define PROFILE_SKY_SATURATION_MULT  1.0
#elif PROFILE == PROFILE_APOCALYPTIC
    #define PROFILE_SKY_SATURATION_MULT  0.60
#endif

// Ambient/skylight brightness multiplier
#if PROFILE == PROFILE_REIMAGINED
    #define PROFILE_AMBIENT_BRIGHTNESS_MULT  1.0
#elif PROFILE == PROFILE_ORIGINAL
    #define PROFILE_AMBIENT_BRIGHTNESS_MULT  1.0
#elif PROFILE == PROFILE_APOCALYPTIC
    #define PROFILE_AMBIENT_BRIGHTNESS_MULT  0.80
#endif

// Sun intensity multiplier
#if PROFILE == PROFILE_REIMAGINED
    #define PROFILE_SUN_BRIGHTNESS_MULT  1.0
#elif PROFILE == PROFILE_ORIGINAL
    #define PROFILE_SUN_BRIGHTNESS_MULT  1.0
#elif PROFILE == PROFILE_APOCALYPTIC
    #define PROFILE_SUN_BRIGHTNESS_MULT  0.85
#endif

// Night fog extra density multiplier (blended with day_factor)
#if PROFILE == PROFILE_REIMAGINED
    #define PROFILE_NIGHT_FOG_EXTRA_MULT  1.0
#elif PROFILE == PROFILE_ORIGINAL
    #define PROFILE_NIGHT_FOG_EXTRA_MULT  1.0
#elif PROFILE == PROFILE_APOCALYPTIC
    #define PROFILE_NIGHT_FOG_EXTRA_MULT  2.5
#endif

#endif // SETTINGS_PROFILES_INCLUDED
