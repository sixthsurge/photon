#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred3.fsh:
  Shade terrain and entities, draw sky

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:03 */
layout (location = 0) out vec3 scene_color;
layout (location = 3) out vec4 colortex3_clear; // Clear colortex3 so that translucents can write to it

in vec2 uv;

flat in vec3 light_color;
flat in vec3 sun_color;
flat in vec3 moon_color;

#ifdef SH_SKYLIGHT
flat in vec3 sky_sh[9];
#else
flat in mat3 sky_samples;
#endif

uniform sampler2D noisetex;

uniform sampler2D colortex1; // Gbuffer 0
uniform sampler2D colortex2; // Gbuffer 1
uniform sampler2D colortex3; // Animated overlays/vanilla sky
uniform sampler2D colortex6; // Ambient occlusion

uniform sampler3D shadowcolor1; // Atmosphere scattering LUT
uniform sampler2D depthtex1;

#ifdef SHADOW
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#ifdef SHADOW_COLOR
uniform sampler2D shadowcolor0;
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

uniform int worldTime;
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform float blindness;
uniform float nightVision;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float biome_cave;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#define ATMOSPHERE_SCATTERING_LUT shadowcolor1
#define PROGRAM_DEFERRED3
#define TEMPORAL_REPROJECTION
#define WORLD_OVERWORLD

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/space_conversion.glsl"

#include "/include/diffuse_lighting.glsl"
#include "/include/fog.glsl"
#include "/include/material.glsl"
#include "/include/shadow_mapping.glsl"
#include "/include/sky.glsl"
#include "/include/specular_lighting.glsl"

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Texture fetches

	float depth   = texelFetch(depthtex1, texel, 0).x;
	vec4 gbuffer_data_0 = texelFetch(colortex1, texel, 0);
#if defined NORMAL_MAPPING || defined SPECULAR_MAPPING
	vec4 gbuffer_data_1 = texelFetch(colortex2, texel, 0);
#endif
	vec4 overlays = texelFetch(colortex3, texel, 0);

	// Transformations

	depth += 0.38 * float(is_hand(depth)); // Hand lighting fix from Capt Tatsu

	vec3 view_pos = screen_to_view_space(vec3(uv, depth), true);
	vec3 scene_pos = view_to_scene_space(view_pos);
	vec3 world_pos = scene_pos + cameraPosition;
	vec3 world_dir = normalize(scene_pos - gbufferModelViewInverse[3].xyz);

	if (is_sky(depth)) { // Sky
		scene_color = draw_sky(world_dir);
	} else { // Terrain
		// Sample half-res lighting data many operations before using it (latency hiding)

		vec2 half_res_pos = gl_FragCoord.xy * (0.5 / taau_render_scale) - 0.5;

		ivec2 i = ivec2(half_res_pos);
		vec2  f = fract(half_res_pos);

		vec4 half_res_00 = texelFetch(colortex6, i + ivec2(0, 0), 0);
		vec4 half_res_10 = texelFetch(colortex6, i + ivec2(1, 0), 0);
		vec4 half_res_01 = texelFetch(colortex6, i + ivec2(0, 1), 0);
		vec4 half_res_11 = texelFetch(colortex6, i + ivec2(1, 1), 0);

		// Unpack gbuffer data

		mat4x2 data = mat4x2(
			unpack_unorm_2x8(gbuffer_data_0.x),
			unpack_unorm_2x8(gbuffer_data_0.y),
			unpack_unorm_2x8(gbuffer_data_0.z),
			unpack_unorm_2x8(gbuffer_data_0.w)
		);

		vec3 albedo       = vec3(data[0], data[1].x);
		uint object_id    = uint(255.0 * data[1].y);
		vec3 flat_normal  = decode_unit_vector(data[2]);
		vec2 light_access = data[3];

		uint overlay_id = uint(255.0 * overlays.a);
		albedo = overlay_id == 0u ? albedo + overlays.rgb : albedo; // enchantment glint
		albedo = overlay_id == 1u ? 2.0 * albedo * overlays.rgb : albedo; // damage overlay

		Material material = material_from(albedo, object_id, world_pos, light_access);

#ifdef NORMAL_MAPPING
		vec3 normal = decode_unit_vector(gbuffer_data_1.xy);
#else
		#define normal flat_normal
#endif

#ifdef SPECULAR_MAPPING
		vec4 specular_map = vec4(unpack_unorm_2x8(gbuffer_data_1.z), unpack_unorm_2x8(gbuffer_data_1.w));
		decode_specular_map(specular_map, material);
#endif

		float NoL = dot(normal, light_dir);
		float NoV = clamp01(dot(normal, -world_dir));
		float LoV = dot(light_dir, -world_dir);
		float halfway_norm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfway_norm;
		float LoH = LoV * halfway_norm + halfway_norm;

#ifdef GTAO
		// Depth-aware upscaling for GTAO

		float lin_z = linearize_depth_fast(depth);

		#define depth_weight(reversed_depth) exp2(-10.0 * abs(linearize_depth_fast(1.0 - reversed_depth) - lin_z))

		vec4 gtao = vec4(half_res_00.xyw, 1.0) * depth_weight(half_res_00.z) * (1.0 - f.x) * (1.0 - f.y)
		          + vec4(half_res_10.xyw, 1.0) * depth_weight(half_res_10.z) * (f.x - f.x * f.y)
		          + vec4(half_res_01.xyw, 1.0) * depth_weight(half_res_01.z) * (f.y - f.x * f.y)
		          + vec4(half_res_11.xyw, 1.0) * depth_weight(half_res_11.z) * (f.x * f.y);

		#undef depth_weight

		gtao = (gtao.w == 0.0) ? vec4(0.0) : gtao / gtao.w;

		// Reconstruct bent normal

		float ao = gtao.z;

		vec3 bent_normal;
		bent_normal.xy = gtao.xy * 2.0 - 1.0;
		bent_normal.z = sqrt(max0(1.0 - dot(bent_normal.xy, bent_normal.xy)));
		bent_normal = mat3(gbufferModelViewInverse) * bent_normal;
#else
		#define ao 1.0
		#define bent_normal normal
#endif

		// Terrain diffuse lighting

		float sss_depth;
		vec3 shadows = calculate_shadows(scene_pos, flat_normal, light_access.y, 1.0, sss_depth);

		scene_color = get_diffuse_lighting(
			material,
			normal,
			flat_normal,
			bent_normal,
			shadows,
			light_access,
			ao,
			sss_depth,
			NoL,
			NoV,
			NoH,
			LoV
		);

		scene_color += get_specular_highlight(material, NoL, NoV, NoH, LoV, LoH) * light_color * shadows * ao;
	}

	apply_fog(scene_color, scene_pos, world_dir, depth == 1.0);

	colortex3_clear = vec4(0.0);
}
