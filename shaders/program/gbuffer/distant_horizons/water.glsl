/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffer/distant_horizons/water.glsl:
  Translucent Distant Horizons terrain

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 light_levels;
out vec3 scene_pos;
out vec3 normal;
out vec4 tint;

flat out uint is_water;
flat out vec3 light_color;
flat out vec3 ambient_color;

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex4; // Sky map, lighting colors

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform ivec2 atlasSize;

uniform int frameCounter;
uniform int renderStage;
uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform vec3 light_dir;

void main() {
	light_levels = linear_step(
        vec2(1.0 / 32.0),
        vec2(31.0 / 32.0),
        (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy
    );
	tint          = gl_Color;
    normal        = mat3(gbufferModelViewInverse) * (mat3(gl_ModelViewMatrix) * gl_Normal);
	light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
	ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;

	is_water = uint(dhMaterialId == DH_BLOCK_WATER);

    vec3 camera_offset = fract(cameraPosition);

    vec3 pos = gl_Vertex.xyz;
         pos = floor(pos + camera_offset + 0.5) - camera_offset;
         pos = transform(gl_ModelViewMatrix, pos);

    scene_pos = transform(gbufferModelViewInverse, pos);

    vec4 clip_pos = dhProjection * vec4(pos, 1.0);

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.66;
#endif

    gl_Position = clip_pos;
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec4 scene_color;
layout (location = 1) out vec4 gbuffer_data_0; // albedo, block ID, flat normal, light levels
layout (location = 2) out vec4 gbuffer_data_1; // detailed normal, specular map (optional)

/* RENDERTARGETS: 0,1 */

#ifdef NORMAL_MAPPING
/* RENDERTARGETS: 0,1,2 */
#endif

#ifdef SPECULAR_MAPPING
/* RENDERTARGETS: 0,1,2 */
#endif

out vec2 uv;
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

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

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

#ifdef SH_SKYLIGHT
	#undef SH_SKYLIGHT
#endif

#if defined PROGRAM_GBUFFERS_TEXTURED || defined PROGRAM_GBUFFERS_PARTICLES_TRANSLUCENT
	#define NO_NORMAL
#endif

#ifdef DIRECTIONAL_LIGHTMAPS
#include "/include/light/directional_lightmaps.glsl"
#endif

#include "/include/fog/simple_fog.glsl"
#include "/include/light/diffuse_lighting.glsl"
#include "/include/light/shadows.glsl"
#include "/include/light/specular_lighting.glsl"
#include "/include/misc/distant_horizons.glsl"
#include "/include/misc/material.glsl"
#include "/include/misc/water_normal.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/space_conversion.glsl"

#ifdef CLOUD_SHADOWS
#include "/include/light/cloud_shadows.glsl"
#endif

const float lod_bias = log2(taau_render_scale);

void main() {
    // Clip close-by DH terrain
    if (length(scene_pos) < far) {
        discard;
        return;
    }

	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);

	// Clip to TAAU viewport

#if defined TAA && defined TAAU
	if (clamp01(coord) != coord) discard;
#endif

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

	Material material; vec4 base_color;

	if (is_water == 1) {
		material = water_material;

		base_color = vec4(0.0);

#if   WATER_TEXTURE == WATER_TEXTURE_OFF
		base_color = vec4(0.0);
#elif WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT
		base_color  = tint;
		base_color += 0.61 * texture(gtexture, uv, lod_bias);
		float texture_highlight = 0.5 * sqr(linear_step(0.61, 1.0, base_color.r)) + 0.03 * base_color.r;

		material.albedo     = clamp01(0.33 * exp(-2.0 * water_absorption_coeff) * texture_highlight);
		material.roughness += 0.3 * texture_highlight;
#elif WATER_TEXTURE == WATER_TEXTURE_VANILLA
		base_color  = tint;
		base_color *= texture(gtexture, uv, lod_bias);
		material.albedo = srgb_eotf_inv(base_color.rgb * base_color.a) * rec709_to_working_color;
#endif

#ifdef WATER_FOAM
		float dist = layer_dist * max(abs(world_dir.y), eps);

	#if WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT
		float foam = cube(max0(1.0 - 2.0 * dist)) * (1.0 + 8.0 * texture_highlight);
	#else
		float foam = cube(max0(1.0 - 2.0 * dist));
	#endif

		material.albedo += 0.05 * foam / mix(1.0, max(dot(ambient_color, luminance_weights_rec2020), 0.5), light_levels.y);
		material.albedo  = clamp01(material.albedo);
#endif
	} else {
		base_color = tint;
		vec2 adjusted_light_levels = light_levels;
		material = material_from(
			base_color.rgb,
			0u,
			world_pos,
			normal,
			adjusted_light_levels
		);
	}

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

	vec3 radiance = get_diffuse_lighting(
		material,
		scene_pos,
		normal,
		normal,
		shadows,
		light_levels,
		1.0,
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

	// Blending

	float alpha;

	if (is_water == 1) {
		// Water absorption

		vec3 transmittance = exp(-water_absorption_coeff * max(1.0, layer_dist));
		alpha = 1.0 - transmittance.x;
	} else {
		alpha = base_color.a;
	}

	scene_color = vec4(radiance / max(alpha, eps), alpha);

	// Apply fog

	vec4 fog = common_fog(length(scene_pos), false);
	scene_color.rgb = scene_color.rgb * fog.a + fog.rgb;

	scene_color.a *= border_fog(scene_pos, world_dir);

	// Encode gbuffer data

	gbuffer_data_0.x  = pack_unorm_2x8(tint.rg);
	gbuffer_data_0.y  = pack_unorm_2x8(tint.b, clamp01(((is_water == 1) ? rcp(255.0) : 0.0)));
	gbuffer_data_0.z  = pack_unorm_2x8(encode_unit_vector(normal));
	gbuffer_data_0.w  = pack_unorm_2x8(dither_8bit(light_levels, 0.5));
}

#endif
//----------------------------------------------------------------------------//
