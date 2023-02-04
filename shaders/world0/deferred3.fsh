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
layout (location = 1) out vec4 colortex3_clear;

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

uniform sampler2D colortex1; // gbuffer 0
uniform sampler2D colortex2; // gbuffer 1
uniform sampler2D colortex3; // animated overlays/vanilla sky
uniform sampler2D colortex4; // sky capture
uniform sampler2D colortex6; // ambient occlusion
uniform sampler2D colortex7; // clouds

uniform sampler3D depthtex0; // atmosphere scattering LUT
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

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform int worldTime;
uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;

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
uniform float biome_may_rain;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define PROGRAM_DEFERRED3
#define WORLD_OVERWORLD

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/space_conversion.glsl"

#include "/include/diffuse_lighting.glsl"
#include "/include/fog.glsl"
#include "/include/material.glsl"
#include "/include/shadow_mapping.glsl"
#include "/include/sky.glsl"
#include "/include/specular_lighting.glsl"

/*
const bool colortex7MipmapEnabled = true;
 */

float get_puddle_noise(vec3 world_pos, vec3 flat_normal, vec2 light_levels) {
	const float puddle_frequency = 0.025;

	float puddle = texture(noisetex, world_pos.xz * puddle_frequency).w;
	      puddle = linear_step(0.45, 0.55, puddle) * wetness * biome_may_rain * max0(flat_normal.y);

	// Prevent puddles from appearing indoors
	puddle *= (1.0 - cube(light_levels.x)) * pow5(light_levels.y);

	return puddle;
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Texture fetches

	float depth         = texelFetch(depthtex1, texel, 0).x;
	vec4 gbuffer_data_0 = texelFetch(colortex1, texel, 0);
#if defined NORMAL_MAPPING || defined SPECULAR_MAPPING
	vec4 gbuffer_data_1 = texelFetch(colortex2, texel, 0);
#endif
	vec4 overlays       = texelFetch(colortex3, texel, 0);

	// Transformations

	depth += 0.38 * float(depth < hand_depth); // Hand lighting fix from Capt Tatsu

	vec3 view_pos = screen_to_view_space(vec3(uv, depth), true);
	vec3 scene_pos = view_to_scene_space(view_pos);
	vec3 world_pos = scene_pos + cameraPosition;
	vec3 world_dir = normalize(scene_pos - gbufferModelViewInverse[3].xyz);

	if (depth == 1.0) { // Sky
		float pixel_age = texelFetch(colortex6, texel, 0).w;
		vec4 clouds = bicubic_filter(colortex7, uv * taau_render_scale);

		// Soften clouds for new pixels
		int ld = int(max0(3.0 - 0.25 * pixel_age));
		clouds = mix(bicubic_filter_lod(colortex7, uv * taau_render_scale, ld), clouds, smoothstep(0.0, 30.0, pixel_age));

		scene_color = draw_sky(world_dir, clouds);
	} else { // Terrain
		// Sample half-res lighting data many operations before using it (latency hiding)

		vec2 half_res_pos = gl_FragCoord.xy * (0.5 / taau_render_scale) - 0.5;

		ivec2 i = ivec2(half_res_pos);
		vec2  f = fract(half_res_pos);

		vec3 half_res_00 = texelFetch(colortex6, i + ivec2(0, 0), 0).xyz;
		vec3 half_res_10 = texelFetch(colortex6, i + ivec2(1, 0), 0).xyz;
		vec3 half_res_01 = texelFetch(colortex6, i + ivec2(0, 1), 0).xyz;
		vec3 half_res_11 = texelFetch(colortex6, i + ivec2(1, 1), 0).xyz;

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
		vec2 light_levels = data[3];

		uint overlay_id = uint(255.0 * overlays.a);
		albedo = overlay_id == 0u ? albedo + overlays.rgb : albedo; // enchantment glint
		albedo = overlay_id == 1u ? 2.0 * albedo * overlays.rgb : albedo; // damage overlay

		Material material = material_from(albedo, object_id, world_pos, light_levels);

#ifdef NORMAL_MAPPING
		vec3 normal = decode_unit_vector(gbuffer_data_1.xy);
#else
		#define normal flat_normal
#endif

#ifdef SPECULAR_MAPPING
		vec4 specular_map = vec4(unpack_unorm_2x8(gbuffer_data_1.z), unpack_unorm_2x8(gbuffer_data_1.w));

#if defined POM && defined POM_SHADOW
		// Specular map alpha >= 0.5 => parallax shadow
		bool parallax_shadow = specular_map.a >= 0.5;
		specular_map.a = fract(specular_map.a * 2.0);
#endif

		decode_specular_map(specular_map, material);
#endif

#ifdef RAIN_PUDDLES
		if (wetness > eps && biome_may_rain > eps && wetness < 1.0 - eps) {
			const float puddle_f0        = 0.02;
			const float puddle_roughness = 0.002;

			float puddle = get_puddle_noise(world_pos, flat_normal, light_levels) * float(!material.is_metal);

			material.f0 = mix(material.f0, vec3(puddle_f0), puddle);
			material.roughness = mix(material.roughness, puddle_roughness, puddle);
			normal = normalize_safe(mix(normal, flat_normal, puddle));
		}
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

		vec4 gtao = vec4(half_res_00, 1.0) * depth_weight(half_res_00.z) * (1.0 - f.x) * (1.0 - f.y)
		          + vec4(half_res_10, 1.0) * depth_weight(half_res_10.z) * (f.x - f.x * f.y)
		          + vec4(half_res_01, 1.0) * depth_weight(half_res_01.z) * (f.y - f.x * f.y)
		          + vec4(half_res_11, 1.0) * depth_weight(half_res_11.z) * (f.x * f.y);

		#undef depth_weight

		gtao = (gtao.w == 0.0) ? vec4(0.0) : gtao / gtao.w;

		float ao = gtao.x;
#else
		#define ao 1.0
#endif

		// Terrain diffuse lighting

		float sss_depth;
		vec3 shadows = calculate_shadows(scene_pos, flat_normal, light_levels.y, material.sss_amount, sss_depth);

#if defined POM && defined POM_SHADOW
		shadows *= float(!parallax_shadow);
#endif

		scene_color = get_diffuse_lighting(
			material,
			normal,
			flat_normal,
			shadows,
			light_levels,
			ao,
			sss_depth,
			NoL,
			NoV,
			NoH,
			LoV
		);

		// Specular highlight

		scene_color += get_specular_highlight(material, NoL, NoV, NoH, LoV, LoH) * light_color * shadows * ao;
	}

	apply_fog(scene_color, scene_pos, world_dir, depth == 1.0);

	// Clear colortex3 so that translucents can write to it
	colortex3_clear = vec4(0.0);
}
