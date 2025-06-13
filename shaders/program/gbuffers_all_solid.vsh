/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_all_solid:
  Handle terrain, entities, the hand, beacon beams and spider eyes

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;
out vec2 light_levels;
out vec3 scene_pos;
out vec4 tint;

flat out uint material_mask;
flat out mat3 tbn;

#if defined POM
out vec2 atlas_tile_coord;
out vec3 tangent_pos;
flat out vec2 atlas_tile_offset;
flat out vec2 atlas_tile_scale;
#endif

#if defined PROGRAM_GBUFFERS_TERRAIN
out float vanilla_ao;
#endif

#if defined PROGRAM_GBUFFERS_ENTITIES || defined PROGRAM_GBUFFERS_HAND
out vec2 uv_local;
#endif

// --------------
//   Attributes
// --------------

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform ivec2 atlasSize;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;

uniform vec2 taa_offset;
uniform vec3 light_dir;

uniform float world_age;
uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;
uniform float biome_temperature;
uniform float biome_humidity;

#if defined PROGRAM_GBUFFERS_BLOCK
uniform int blockEntityId;
#endif

#if defined PROGRAM_GBUFFERS_ENTITIES
uniform int entityId;
#endif

#if (defined PROGRAM_GBUFFERS_ENTITIES || defined PROGRAM_GBUFFERS_HAND) && defined IS_IRIS
uniform int currentRenderedItemId;
#endif

#include "/include/utility/space_conversion.glsl"
#include "/include/vertex/displacement.glsl"
#include "/include/vertex/utility.glsl"

void main() {
	uv            = gl_MultiTexCoord0.xy;
	light_levels  = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	tint          = gl_Color;
	material_mask = get_material_mask();
	tbn           = get_tbn_matrix();

#if defined PROGRAM_GBUFFERS_TERRAIN
	vanilla_ao = gl_Color.a < 0.1 ? 1.0 : gl_Color.a; // fixes models where vanilla ao breaks (eg lecterns)
	vanilla_ao = material_mask == 5 ? 1.0 : vanilla_ao; // no vanilla ao on leaves
	tint.a = 1.0;

	#ifdef POM
	// from fayer3
	vec2 uv_minus_mid = uv - mc_midTexCoord;
	atlas_tile_offset = min(uv, mc_midTexCoord - uv_minus_mid);
	atlas_tile_scale = abs(uv_minus_mid) * 2.0;
	atlas_tile_coord = sign(uv_minus_mid) * 0.5 + 0.5;
	#endif
#endif

#if defined PROGRAM_GBUFFERS_ENTITIES
	// Fix fire entity not glowing with Colored Lights
	if (light_levels.x > 0.99) material_mask = 40;
#endif

#if defined PROGRAM_GBUFFERS_PARTICLES
	// Make enderman/nether portal particles glow
	if (gl_Color.r > gl_Color.g && gl_Color.g < 0.6 && gl_Color.b > 0.4) material_mask = 47;
#endif

#if defined PROGRAM_GBUFFERS_BEACONBEAM
	// Make beacon beam glow
	material_mask = 32;
#endif

#if defined PROGRAM_GBUFFERS_ENTITIES || defined PROGRAM_GBUFFERS_HAND
	// Calculate local uv used to fix hardcoded emission on some handheld/dropped items
	uv_local = sign(uv - mc_midTexCoord) * 0.5 + 0.5;
#endif

	bool is_top_vertex = uv.y < mc_midTexCoord.y;

	vec3 pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	     pos = view_to_scene_space(pos);
	     pos = pos + cameraPosition;
	     pos = animate_vertex(pos, is_top_vertex, light_levels.y, material_mask);
	     pos = pos - cameraPosition;

	scene_pos = pos;

#if defined POM && defined PROGRAM_GBUFFERS_TERRAIN
	tangent_pos = (pos - gbufferModelViewInverse[3].xyz) * tbn;
#endif

	vec3 view_pos = scene_to_view_space(pos);
	vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.66;
#endif

	gl_Position = clip_pos;
}

