#version 400 compatibility
#define WORLD_END
#define PROGRAM_GBUFFERS_SPIDEREYES
#define fsh

#include "/settings.glsl"

#if defined IS_IRIS && defined USE_SEPARATE_ENTITY_DRAWS 
#include "/program/gbuffers_all_translucent.fsh"
#else
#include "/program/gbuffers_all_solid.fsh"
#endif
