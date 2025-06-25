/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_all_translucent:
  Handle translucent terrain, translucent entities (Iris), translucent handheld
  items and gbuffers_textured

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;
out vec2 light_levels;
out vec3 position_view;
out vec3 position_scene;
out vec4 tint;

flat out vec3 light_color;
flat out vec3 ambient_color;
flat out uint material_mask;
flat out mat3 tbn;

#if defined PROGRAM_GBUFFERS_WATER
out vec2 atlas_tile_coord;
out vec3 position_tangent;
flat out vec2 atlas_tile_offset;
flat out vec2 atlas_tile_scale;
#endif

#if defined WORLD_OVERWORLD 
#include "/include/fog/overworld/parameters.glsl"
flat out OverworldFogParameters fog_params;
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

uniform sampler2D colortex4; // Sky map, lighting colors, sky SH

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform ivec2 atlasSize;
uniform int renderStage;

uniform int worldTime;
uniform int worldDay;
uniform int frameCounter;
uniform float frameTimeCounter;

uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform vec3 light_dir;
uniform vec3 sun_dir;

uniform float eye_skylight;

uniform float biome_temperate;
uniform float biome_arid;
uniform float biome_snowy;
uniform float biome_taiga;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_may_rain;
uniform float biome_may_snow;
uniform float biome_temperature;
uniform float biome_humidity;

uniform float world_age;
uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

uniform float desert_sandstorm;

#if defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT || defined PROGRAM_GBUFFERS_LIGHTNING
uniform int entityId;
#endif

#if defined PROGRAM_GBUFFERS_BLOCK_TRANSLUCENT
uniform int blockEntityId;
#endif

#if (defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT || defined PROGRAM_GBUFFERS_HAND_WATER) && defined IS_IRIS
uniform int currentRenderedItemId;
#endif

#include "/include/misc/material_masks.glsl"
#include "/include/utility/space_conversion.glsl"
#include "/include/vertex/displacement.glsl"
#include "/include/vertex/utility.glsl"

#if defined WORLD_OVERWORLD 
#include "/include/weather/fog.glsl"
#endif

void main() {
	uv            = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;  // Faster method breaks on Intel for some reason, thanks to ilux-git for finding this!
	light_levels  = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	tint          = gl_Color;
	material_mask = get_material_mask();
	tbn           = get_tbn_matrix();

	light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
#if defined WORLD_OVERWORLD && defined SH_SKYLIGHT
	ambient_color = texelFetch(colortex4, ivec2(191, 11), 0).rgb;
#else
	ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;
#endif

	bool is_top_vertex = uv.y < mc_midTexCoord.y;

	position_scene = transform(gl_ModelViewMatrix, gl_Vertex.xyz);                            // To view space
	position_scene = view_to_scene_space(position_scene);                                          // To scene space
	position_scene = position_scene + cameraPosition;                                              // To world space
	position_scene = animate_vertex(position_scene, is_top_vertex, light_levels.y, material_mask); // Apply vertex animations
	position_scene = position_scene - cameraPosition;                                              // Back to scene space

#if defined PROGRAM_GBUFFERS_WATER
	tint.a = 1.0;

	if (material_mask == 62) {
		// Nether portal
		position_tangent = (position_scene - gbufferModelViewInverse[3].xyz) * tbn;

		// (from fayer3)
		vec2 uv_minus_mid = uv - mc_midTexCoord;
		atlas_tile_offset = min(uv, mc_midTexCoord - uv_minus_mid);
		atlas_tile_scale = abs(uv_minus_mid) * 2.0;
		atlas_tile_coord = sign(uv_minus_mid) * 0.5 + 0.5;
	}
#endif

#if defined PROGRAM_GBUFFERS_LIGHTNING && defined WORLD_END
	// For some reason the Ender Dragon death beams also use gbuffers_lightning

	// Ender Dragon death beam check from Euphoria Patches by SpacEagle17, used with permission
	// https://www.euphoriapatches.com/
	bool is_dragon_death_beam = entityId == 0 && (tint.a < 0.2 || tint.a == 1.0);

	if (is_dragon_death_beam) {
		material_mask = MATERIAL_DRAGON_BEAM;

		if (tint.r < 0.2) {
			// Dark bit at the end
			tint.a = 0.0;
		}
	}
#endif

#if defined PROGRAM_GBUFFERS_TEXTURED
	// Make world border emissive
	if (renderStage == MC_RENDER_STAGE_WORLD_BORDER) material_mask = 4;
#endif

#if defined PROGRAM_GBUFFERS_TEXTURED && !defined IS_IRIS
	// Make enderman/nether portal particles glow
	if (gl_Color.r > gl_Color.g && gl_Color.g < 0.6 && gl_Color.b > 0.4) material_mask = 47;
#endif

#if defined PROGRAM_GBUFFERS_WATER
	// Fix issue where the normal of the bottom of the water surface is flipped
	if (dot(position_scene, tbn[2]) > 0.0) tbn[2] = -tbn[2];
#endif

#if defined WORLD_OVERWORLD 
	fog_params = get_fog_parameters(get_weather());
#endif

	position_view = scene_to_view_space(position_scene);
	vec4 position_clip = project(gl_ProjectionMatrix, position_view);

#if   defined TAA && defined TAAU
	position_clip.xy  = position_clip.xy * taau_render_scale + position_clip.w * (taau_render_scale - 1.0);
	position_clip.xy += taa_offset * position_clip.w;
#elif defined TAA
	position_clip.xy += taa_offset * position_clip.w * 0.66;
#endif

	gl_Position = position_clip;
}
