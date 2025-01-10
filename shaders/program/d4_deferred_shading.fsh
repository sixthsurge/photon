/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/d4_deferred_shading:
  Shade terrain and entities, draw sky

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 scene_color;

#ifdef IS_IRIS
/* RENDERTARGETS: 0 */
#else
layout (location = 1) out vec4 colortex3_clear;

/* RENDERTARGETS: 0,3 */
#endif

in vec2 uv;

flat in vec3 ambient_color;
flat in vec3 light_color;

#if defined WORLD_OVERWORLD
flat in vec3 sun_color;
flat in vec3 moon_color;

#if defined SH_SKYLIGHT
flat in vec3 sky_sh[9];
#else
flat in mat3 sky_samples;
#endif
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex0; // skytextured output
uniform sampler2D colortex1; // gbuffer 0
uniform sampler2D colortex2; // gbuffer 1
uniform sampler2D colortex4; // sky map
uniform sampler2D colortex5; // previous frame color
uniform sampler2D colortex6; // ambient occlusion
uniform sampler2D colortex7; // previous frame fog scattering
uniform sampler2D colortex11; // clouds history
uniform sampler2D colortex12; // clouds apparent distance

#ifndef IS_IRIS
uniform sampler2D colortex3; // OF damage overlay, armor glint
#endif

#if defined WORLD_OVERWORLD && defined GALAXY
uniform sampler2D colortex14;
#define galaxy_sampler colortex14
#endif

#ifdef CLOUD_SHADOWS
uniform sampler2D colortex8; // cloud shadow map
#endif

uniform sampler3D depthtex0; // atmosphere scattering LUT
uniform sampler2D depthtex1;

#ifdef COLORED_LIGHTS
uniform sampler3D light_sampler_a;
uniform sampler3D light_sampler_b;
#endif

#ifdef BLOCKY_CLOUDS
uniform sampler2D depthtex2; // minecraft cloud texture
#endif

#ifndef WORLD_NETHER
#ifdef SHADOW
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;

#ifdef SHADOW_COLOR
uniform sampler2D shadowcolor0;
#endif
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

uniform float eyeAltitude;
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
uniform float darknessFactor;

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

uniform float world_age;
uniform float eye_skylight;

/*
const bool colortex5MipmapEnabled = true;
const bool colortex11MipmapEnabled = true;
*/

// ------------
//   Includes
// ------------

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define TEMPORAL_REPROJECTION

#include "/include/fog/simple_fog.glsl"
#include "/include/lighting/diffuse_lighting.glsl"
#include "/include/lighting/shadows.glsl"
#include "/include/lighting/specular_lighting.glsl"
#include "/include/misc/distant_horizons.glsl"
#include "/include/misc/edge_highlight.glsl"
#include "/include/misc/material.glsl"
#include "/include/misc/purkinje_shift.glsl"
#include "/include/misc/rain_puddles.glsl"
#include "/include/sky/sky.glsl"
#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/space_conversion.glsl"

#if defined WORLD_OVERWORLD && defined BLOCKY_CLOUDS
#include "/include/sky/blocky_clouds.glsl"
#endif

#if defined CLOUD_SHADOWS
#include "/include/lighting/cloud_shadows.glsl"
#endif

vec4 read_clouds_and_aurora(out float apparent_distance) {
#if defined WORLD_OVERWORLD
	// Soften clouds for new pixels
	float pixel_age = texelFetch(colortex12, ivec2(gl_FragCoord.xy), 0).y;
	float ld = 2.0 * dampen(max0(1.0 - 0.1 * pixel_age));

	apparent_distance = min_of(textureGather(colortex12, uv * taau_render_scale, 0));

	return textureLod(colortex11, uv * taau_render_scale, ld);
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

void main() {
#if !defined IS_IRIS
	colortex3_clear = vec4(0.0);
#endif

	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Sample textures

	float depth         = texelFetch(combined_depth_buffer, texel, 0).x;
	vec4 gbuffer_data_0 = texelFetch(colortex1, texel, 0);
#if defined NORMAL_MAPPING || defined SPECULAR_MAPPING
	vec4 gbuffer_data_1 = texelFetch(colortex2, texel, 0);
#endif
#if !defined IS_IRIS
	vec4 overlays       = texelFetch(colortex3, texel, 0);
#endif

	float clouds_distance;
	vec4 clouds_and_aurora = read_clouds_and_aurora(clouds_distance);

    // Check for Distant Horizons terrain

#ifdef DISTANT_HORIZONS
    float depth_mc = texelFetch(depthtex1, texel, 0).x;
    float depth_dh = texelFetch(dhDepthTex, texel, 0).x;
	bool is_dh_terrain = is_distant_horizons_terrain(depth_mc, depth_dh);
#else
    const bool is_dh_terrain = false;
#endif

	// Space conversions

	depth += 0.38 * float(depth < hand_depth); // Hand lighting fix from Capt Tatsu

	vec3 view_pos = screen_to_view_space(combined_projection_matrix_inverse, vec3(uv, depth), true);
	vec3 scene_pos = view_to_scene_space(view_pos);
	vec3 world_pos = scene_pos + cameraPosition;
	vec3 world_dir = normalize(scene_pos - gbufferModelViewInverse[3].xyz);

#if defined WORLD_OVERWORLD
	vec3 atmosphere = atmosphere_scattering(
		world_dir, 
		sun_color, 
		sun_dir, 
		moon_color, 
		moon_dir, 
		/* use_klein_nishina_phase */ depth == 1.0
	);

#ifdef BLOCKY_CLOUDS
	vec3 world_start_pos = gbufferModelViewInverse[3].xyz + cameraPosition;
	vec3 world_end_pos   = world_pos;

	float dither = texelFetch(noisetex, texel & 511, 0).b;
	      dither = r1(frameCounter, dither);

	vec4 blocky_clouds = raymarch_blocky_clouds(
		world_start_pos,
		world_end_pos,
		depth == 1.0,
		blocky_clouds_altitude_l0,
		dither
	);

#ifdef BLOCKY_CLOUDS_LAYER_2
	float visibility = pow4(blocky_clouds.a);
	vec4 blocky_clouds_l2 = raymarch_blocky_clouds(
		world_start_pos,
		world_end_pos,
		depth == 1.0,
		blocky_clouds_altitude_l1,
		dither
	);
	blocky_clouds.rgb += blocky_clouds_l2.xyz * visibility;
	blocky_clouds.a   *= mix(1.0, blocky_clouds_l2.a, visibility);
#endif

	float new_alpha = sqr(sqr(blocky_clouds.a));
	blocky_clouds.rgb += atmosphere * (1.0 - new_alpha) * (blocky_clouds.a - new_alpha);
	blocky_clouds.a = new_alpha;
#endif
#endif

	if (depth == 1.0) { // Sky
#if defined WORLD_OVERWORLD
		scene_color = draw_sky(world_dir, atmosphere);
#else
		scene_color = draw_sky(world_dir);
#endif

		// Apply clouds and aurora
		scene_color = scene_color * clouds_and_aurora.w + clouds_and_aurora.xyz;

		// Apply blocky clouds 
#if defined WORLD_OVERWORLD && defined BLOCKY_CLOUDS 
		scene_color = scene_color * blocky_clouds.w + blocky_clouds.xyz;
#endif

		// Apply common fog
		vec4 fog = common_fog(far, true);
		scene_color = mix(fog.rgb, scene_color.rgb, fog.a);

		// Apply purkinje shift
		scene_color = purkinje_shift(scene_color, vec2(0.0, 1.0));
	} else { // Terrain
		// Sample ambient occlusion a while before using it (latency hiding)

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

#if !defined IS_IRIS
		uint overlay_id = uint(255.0 * overlays.a);
		albedo = overlay_id == 0u ? albedo + overlays.rgb : albedo; // enchantment glint
		albedo = overlay_id == 1u ? 2.0 * albedo * overlays.rgb : albedo; // damage overlay
#endif

		// Get material and normal

		Material material = material_from(albedo, material_mask, world_pos, flat_normal, light_levels);

		vec3 normal = flat_normal;
        bool parallax_shadow = false;

#ifdef DISTANT_HORIZONS
		if (!is_dh_terrain) {
#endif

	#ifdef NORMAL_MAPPING
		normal = decode_unit_vector(gbuffer_data_1.xy);
	#endif

	#ifdef SPECULAR_MAPPING
		vec4 specular_map = vec4(unpack_unorm_2x8(gbuffer_data_1.z), unpack_unorm_2x8(gbuffer_data_1.w));
		decode_specular_map(specular_map, material, parallax_shadow);
	#elif defined NORMAL_MAPPING
		parallax_shadow = gbuffer_data_1.z >= 0.5;
	#endif

#ifdef DISTANT_HORIZONS
		}
#endif

		// Rain puddles

#if defined WORLD_OVERWORLD && defined RAIN_PUDDLES
		if (wetness > eps && biome_may_rain > eps) {
			bool puddle = get_rain_puddles(
				world_pos,
				flat_normal,
				light_levels,
				material.porosity,
				normal,
				material.f0,
				material.roughness,
				material.ssr_multiplier
			);
		}
#endif

		// Upscale ambient occlusion

#ifdef GTAO
		float lin_z = screen_to_view_space_depth(combined_projection_matrix_inverse, depth);

		#define depth_weight(reversed_depth) exp2(-10.0 * abs(screen_to_view_space_depth(combined_projection_matrix_inverse, 1.0 - reversed_depth) - lin_z))

		vec4 gtao = vec4(half_res_00, 1.0) * depth_weight(half_res_00.z) * (1.0 - f.x) * (1.0 - f.y)
		          + vec4(half_res_10, 1.0) * depth_weight(half_res_10.z) * (f.x - f.x * f.y)
		          + vec4(half_res_01, 1.0) * depth_weight(half_res_01.z) * (f.y - f.x * f.y)
		          + vec4(half_res_11, 1.0) * depth_weight(half_res_11.z) * (f.x * f.y);

		#undef depth_weight

		float ao = (gtao.w == 0.0) ? half_res_00.x : gtao.x / gtao.w;
#else
		#define ao 1.0
#endif

		// Shadows

		float NoL = dot(normal, light_dir);
		float NoV = clamp01(dot(normal, -world_dir));
		float LoV = dot(light_dir, -world_dir);
		float halfway_norm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfway_norm;
		float LoH = LoV * halfway_norm + halfway_norm;

#if defined WORLD_OVERWORLD && defined CLOUD_SHADOWS
		float cloud_shadows = get_cloud_shadows(colortex8, scene_pos);
#else
		const float cloud_shadows = 1.0;
#endif

#if defined SHADOW && (defined WORLD_OVERWORLD || defined WORLD_END)
		float sss_depth;
		float shadow_distance_fade;
		vec3 shadows;

        shadows = calculate_shadows(scene_pos, flat_normal, light_levels.y, cloud_shadows, material.sss_amount, shadow_distance_fade, sss_depth);

	#ifdef DISTANT_HORIZONS
		if (is_dh_terrain) {
			shadow_distance_fade = 1.0;
		}
	#endif
#else
		vec3 shadows = vec3(sqrt(ao) * pow8(light_levels.y));
		#define sss_depth 0.0
		#define shadow_distance_fade 0.0
#endif

#if defined POM && defined POM_SHADOW && (defined SPECULAR_MAPPING || defined NORMAL_MAPPING)
		shadows *= float(!parallax_shadow);
#endif

		// Diffuse lighting

		scene_color = get_diffuse_lighting(
			material,
			scene_pos,
			normal,
			flat_normal,
			shadows,
			light_levels,
			ao,
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

		// Specular highlight

#if defined WORLD_OVERWORLD || defined WORLD_END
		scene_color += get_specular_highlight(material, NoL, NoV, NoH, LoV, LoH) * light_color * shadows * cloud_shadows * ao;
#endif

		// Specular reflections

#if defined ENVIRONMENT_REFLECTIONS || defined SKY_REFLECTIONS
		if (material.ssr_multiplier > eps) {
			mat3 tbn = get_tbn_matrix(normal);

			scene_color += get_specular_reflections(
				material,
				tbn,
				vec3(uv, depth),
				view_pos,
				normal,
				flat_normal,
				world_dir,
				world_dir * tbn,
				light_levels.y,
				false
			);
		}
#endif
		// Edge highlight

#ifdef EDGE_HIGHLIGHT
		scene_color *= 1.0 + 0.5 * get_edge_highlight(scene_pos, flat_normal, depth, material_mask);
#endif

		// Apply fog

		float view_distance = length(view_pos);

#ifdef BORDER_FOG
	#if defined WORLD_OVERWORLD
		vec3 horizon_dir = normalize(vec3(world_dir.xz, min(world_dir.y, -0.1)).xzy);
		vec3 horizon_color = texture(colortex4, project_sky(horizon_dir)).rgb;

		float horizon_factor = linear_step(0.1, 1.0, exp(-75.0 * sqr(sun_dir.y + 0.0496)));
			  horizon_factor = clamp01(horizon_factor + step(0.01, rainStrength));

		vec3 border_fog_color = mix(atmosphere, horizon_color, sqr(horizon_factor)) * (1.0 - biome_cave);
	#else
		vec3 border_fog_color = texture(colortex4, project_sky(world_dir)).rgb;
	#endif

		float border_fog = border_fog(scene_pos, world_dir);
		scene_color = mix(border_fog_color, scene_color, border_fog);
#endif

		vec4 fog = common_fog(view_distance, false);
		scene_color = scene_color * fog.a + fog.rgb;

		// Apply clouds in front of terrain
#if defined WORLD_OVERWORLD
	#ifndef BLOCKY_CLOUDS
		if (clouds_distance < view_distance) {
			scene_color = scene_color * clouds_and_aurora.w + clouds_and_aurora.xyz;
		}
	#else
		scene_color = scene_color * blocky_clouds.w + blocky_clouds.xyz;
	#endif
#endif

		// Apply purkinje shift
		scene_color = purkinje_shift(scene_color, light_levels);
	}
}

