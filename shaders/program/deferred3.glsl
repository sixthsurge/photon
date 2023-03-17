/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/deferred3.glsl:
  Shade terrain and entities, draw sky

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

varying vec2 uv;

#if defined WORLD_OVERWORLD
flat varying vec3 light_color;
flat varying vec3 sun_color;
flat varying vec3 moon_color;
#endif

#if defined SH_SKYLIGHT
flat varying vec3 sky_sh[9];
#else
flat varying mat3 sky_samples;
#endif

// ------------
//   uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex1; // gbuffer 0
uniform sampler2D colortex2; // gbuffer 1
uniform sampler2D colortex3; // animated overlays/vanilla sky
uniform sampler2D colortex4; // sky map
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
uniform int moonPhase;
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
uniform float biome_may_snow;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;


//----------------------------------------------------------------------------//
#if defined STAGE_VERTEX

#define ATMOSPHERE_SCATTERING_LUT depthtex0

#include "/include/misc/palette.glsl"
#include "/include/sky/atmosphere.glsl"
#include "/include/sky/projection.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/spherical_harmonics.glsl"

void main()
{
	uv = gl_MultiTexCoord0.xy;

#if defined WORLD_OVERWORLD
	light_color = get_light_color();
	sun_color   = get_sun_exposure() * get_sun_tint();
	moon_color  = get_moon_exposure() * get_moon_tint();
#endif

	float skylight_boost = get_skylight_boost();

#ifdef SH_SKYLIGHT
	// Initialize SH to 0
	for (uint band = 0; band < 9; ++band) sky_sh[band] = vec3(0.0);

	// Sample into SH
	const uint step_count = 256;
	for (uint i = 0; i < step_count; ++i) {
		vec3 direction = uniform_hemisphere_sample(vec3(0.0, 1.0, 0.0), r2(int(i)));
		vec3 radiance  = texture(colortex4, project_sky(direction)).rgb;
		float[9] coeff = sh_coeff_order_2(direction);

		for (uint band = 0; band < 9; ++band) sky_sh[band] += radiance * coeff[band];
	}

	// Apply skylight boost and normalize SH
	const float step_solid_angle = tau / float(step_count);
	for (uint band = 0; band < 9; ++band) sky_sh[band] *= skylight_boost * step_solid_angle;
#elif defined WORLD_OVERWORLD
	vec3 dir0 = normalize(vec3(0.0, 1.0, -0.8));               // Up
	vec3 dir1 = normalize(vec3(sun_dir.xz + 0.1, 0.066).xzy);  // Sun-facing horizon
	vec3 dir2 = normalize(vec3(moon_dir.xz + 0.1, 0.066).xzy); // Opposite horizon

	sky_samples[0] = sun_color  * atmosphere_scattering(dir0, sun_dir)
	               + moon_color * atmosphere_scattering(dir0, moon_dir);
	sky_samples[1] = sun_color  * atmosphere_scattering(dir1, sun_dir)
	               + moon_color * atmosphere_scattering(dir1, moon_dir);
	sky_samples[2] = sun_color  * atmosphere_scattering(dir2, sun_dir)
	               + moon_color * atmosphere_scattering(dir2, moon_dir);

	sky_samples[0] *= skylight_boost;
	sky_samples[1] *= skylight_boost;
	sky_samples[2] *= skylight_boost;
#endif

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined STAGE_FRAGMENT

layout (location = 0) out vec3 scene_color;
layout (location = 1) out vec4 colortex3_clear;

/* DRAWBUFFERS:03 */

#define ATMOSPHERE_SCATTERING_LUT depthtex0

#include "/include/fog/simple_fog.glsl"
#include "/include/light/diffuse.glsl"
#include "/include/light/shadows.glsl"
#include "/include/light/specular.glsl"
#include "/include/misc/material.glsl"
#include "/include/sky/sky.glsl"
#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/space_conversion.glsl"

/*
const bool colortex7MipmapEnabled = true;
 */

float get_puddle_noise(vec3 world_pos, vec3 flat_normal, vec2 light_levels)
{
	const float puddle_frequency = 0.025;

	float puddle = texture(noisetex, world_pos.xz * puddle_frequency).w;
	      puddle = linear_step(0.45, 0.55, puddle) * wetness * biome_may_rain * max0(flat_normal.y);

	// Prevent puddles from appearing indoors
	puddle *= (1.0 - cube(light_levels.x)) * pow5(light_levels.y);

	return puddle;
}

void main()
{
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
		scene_color = draw_sky(world_dir);
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

		vec3 albedo        = vec3(data[0], data[1].x);
		uint material_mask = uint(255.0 * data[1].y);
		vec3 flat_normal   = decode_unit_vector(data[2]);
		vec2 light_levels  = data[3];

		uint overlay_id = uint(255.0 * overlays.a);
		albedo = overlay_id == 0u ? albedo + overlays.rgb : albedo; // enchantment glint
		albedo = overlay_id == 1u ? 2.0 * albedo * overlays.rgb : albedo; // damage overlay

		Material material = material_from(albedo, material_mask, world_pos, light_levels);

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

#if defined WORLD_OVERWORLD && defined RAIN_PUDDLES
		if (wetness > eps && biome_may_rain > eps && wetness < 1.0 - eps) {
			const float puddle_f0        = 0.02;
			const float puddle_roughness = 0.002;

			float puddle = get_puddle_noise(world_pos, flat_normal, light_levels) * float(!material.is_metal);

			material.f0 = mix(material.f0, vec3(puddle_f0), puddle);
			material.roughness = mix(material.roughness, puddle_roughness, dampen(puddle));
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

#if defined WORLD_OVERWORLD || defined WORLD_END
		float sss_depth;
		vec3 shadows = calculate_shadows(scene_pos, flat_normal, light_levels.y, material.sss_amount, sss_depth);

	#if defined POM && defined POM_SHADOW
		shadows *= float(!parallax_shadow);
	#endif
#else
		const float sss_depth = 0.0;
		const vec3 shadows = vec3(0.0);
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

#endif
//----------------------------------------------------------------------------//
