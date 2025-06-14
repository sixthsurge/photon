/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/dh_water:
  Translucent Distant Horizons terrain

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec4 fragment_color;
layout (location = 1) out vec4 gbuffer_data; // albedo, block ID, flat normal, light levels

/* RENDERTARGETS: 0,1 */

in vec2 light_levels;
in vec3 scene_pos;
in vec3 normal;
in vec4 tint;

flat in uint is_water;
flat in vec3 light_color;
flat in vec3 ambient_color;

#if defined PROGRAM_GBUFFERS_WATER
in vec2 atlas_tile_coord;
in vec3 tangent_pos;
flat in vec2 atlas_tile_offset;
flat in vec2 atlas_tile_scale;
#endif

#if defined WORLD_OVERWORLD 
#include "/include/fog/overworld/parameters.glsl"
flat in OverworldFogParameters fog_params;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex4; // Sky map, lighting colors
uniform sampler2D colortex5; // Previous frame image (for reflections)
uniform sampler2D colortex7; // Previous frame fog scattering (for reflections)

#ifdef CLOUD_SHADOWS
uniform sampler2D colortex8; // Cloud shadow map
#endif

uniform sampler2D depthtex0;

#ifdef COLORED_LIGHTS
uniform sampler3D light_sampler_a;
uniform sampler3D light_sampler_b;
#endif

#ifdef SHADOW
#ifdef WORLD_OVERWORLD
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif

#ifdef WORLD_END
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;

uniform float frameTimeCounter;
uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;

uniform int worldTime;
uniform int moonPhase;
uniform int frameCounter;

uniform int isEyeInWater;
uniform float blindness;
uniform float nightVision;
uniform float darknessFactor;
uniform float eyeAltitude;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float eye_skylight;

uniform float biome_cave;
uniform float biome_may_rain;
uniform float biome_may_snow;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#if defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT
uniform vec4 entityColor;
#endif

// ------------
//   Includes
// ------------

#define TEMPORAL_REPROJECTION

#ifdef SHADOW_COLOR
	#undef SHADOW_COLOR
#endif

#if defined PROGRAM_GBUFFERS_TEXTURED || defined PROGRAM_GBUFFERS_PARTICLES_TRANSLUCENT
	#define NO_NORMAL
#endif

#ifdef DIRECTIONAL_LIGHTMAPS
#include "/include/lighting/directional_lightmaps.glsl"
#endif

#include "/include/fog/simple_fog.glsl"
#include "/include/lighting/diffuse_lighting.glsl"
#include "/include/lighting/shadows/sampling.glsl"
#include "/include/lighting/specular_lighting.glsl"
#include "/include/misc/distant_horizons.glsl"
#include "/include/surface/material.glsl"
#include "/include/surface/water_normal.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/space_conversion.glsl"

#ifdef CLOUD_SHADOWS
#include "/include/lighting/cloud_shadows.glsl"
#endif

void main() {
	// Clip to TAAU viewport

	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);

#if defined TAA && defined TAAU
	if (clamp01(coord) != coord) discard;
#endif

    // Overdraw fade

    float dh_fade_start_distance = max0(far - DH_OVERDRAW_DISTANCE - DH_OVERDRAW_FADE_LENGTH);
    float dh_fade_end_distance = max0(far - DH_OVERDRAW_DISTANCE);
    float view_distance = length(scene_pos);

    float dither = interleaved_gradient_noise(gl_FragCoord.xy, frameCounter);
    float fade = smoothstep(dh_fade_start_distance, dh_fade_end_distance, view_distance);

    if (dither > fade) {
        discard;
        return;
    }

	// Encode gbuffer data

	gbuffer_data.x  = pack_unorm_2x8(tint.rg);
	gbuffer_data.y  = pack_unorm_2x8(tint.b, clamp01(((is_water == 1) ? rcp(255.0) : 0.0)));
	gbuffer_data.z  = pack_unorm_2x8(encode_unit_vector(normal));
	gbuffer_data.w  = pack_unorm_2x8(dither_8bit(light_levels, 0.5));

	if (is_water == 1.0) {
		fragment_color = vec4(0.0);
		return;
	}

	// Space conversions

	float back_depth_mc = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x;
	float back_depth_dh = texelFetch(dhDepthTex1, ivec2(gl_FragCoord.xy), 0).x;
	bool back_is_dh_terrain = is_distant_horizons_terrain(back_depth_mc, back_depth_dh);

	// Prevent water behind terrain from rendering on top of it
	float dh_depth_linear = screen_to_view_space_depth(dhProjectionInverse, gl_FragCoord.z);
	float mc_depth_linear = screen_to_view_space_depth(gbufferProjectionInverse, back_depth_mc);

	if (mc_depth_linear < dh_depth_linear && back_depth_mc != 1.0) { discard; return; }

	vec3 world_pos = scene_pos + cameraPosition;
	vec3 world_dir = normalize(scene_pos - gbufferModelViewInverse[3].xyz);

	vec3 view_back_pos = back_is_dh_terrain
		? screen_to_view_space(vec3(coord, back_depth_dh), true, true)
		: screen_to_view_space(vec3(coord, back_depth_mc), true, false);
	vec3 scene_back_pos = view_to_scene_space(view_back_pos);

	float layer_dist = length(scene_pos - scene_back_pos); // distance to solid layer along view ray

	// Get material and normal

	Material material; 
	fragment_color = tint;

	vec2 adjusted_light_levels = light_levels;
	material = material_from(
		fragment_color.rgb,
		0u,
		world_pos,
		normal,
		adjusted_light_levels
	);

	// Shadows

#ifndef NO_NORMAL
	float NoL = dot(normal, light_dir);
#else
	float NoL = 1.0;
#endif
	float NoV = clamp01(dot(normal, -world_dir));
	float LoV = dot(light_dir, -world_dir);
	float halfway_norm = inversesqrt(2.0 * LoV + 2.0);
	float NoH = (NoL + NoV) * halfway_norm;
	float LoH = LoV * halfway_norm + halfway_norm;

	vec3 shadows = vec3(pow8(light_levels.y));
	#define sss_depth 0.0
	#define shadow_distance_fade 0.0

#ifdef CLOUD_SHADOWS
	float cloud_shadows = get_cloud_shadows(colortex8, scene_pos);
	shadows *= cloud_shadows;
#endif

	fragment_color.rgb = get_diffuse_lighting(
		material,
		scene_pos,
		normal,
		normal,
		normal,
		shadows,
		light_levels,
		1.0,
		0.0,
		sss_depth,
#ifdef CLOUD_SHADOWS
		cloud_shadows,
#endif
		shadow_distance_fade,
		NoL,
		NoV,
		NoH,
		LoV
	);

	// Apply fog

	vec4 fog = common_fog(length(scene_pos), false);
	fragment_color.rgb = fragment_color.rgb * fog.a + fog.rgb;

	fragment_color.a *= border_fog(scene_pos, world_dir);
}
