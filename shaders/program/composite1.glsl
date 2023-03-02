/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/composite1.glsl:
  Shade translucent layer, apply SSR and VL

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

varying vec2 uv;

flat varying mat3 sky_samples;
flat varying vec3 water_fog_color;

#if defined WORLD_OVERWORLD
flat varying vec3 light_color;
flat varying vec3 sun_color;
flat varying vec3 moon_color;
#endif

// ------------
//   uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex0; // Scene color
uniform sampler2D colortex1; // Gbuffer 0
uniform sampler2D colortex2; // Gbuffer 1
uniform sampler2D colortex3; // Blended color
uniform sampler2D colortex4; // Sky map
uniform sampler2D colortex5; // Scene history
uniform sampler2D colortex6; // Volumetric fog scattering
uniform sampler2D colortex7; // Volumetric fog transmittance

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef SHADOW
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
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
uniform int frameCounter;

uniform int isEyeInWater;
uniform float blindness;
uniform float nightVision;

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


//----------------------------------------------------------------------------//
#if defined vsh

#include "/include/misc/palette.glsl"

void main()
{
	uv = gl_MultiTexCoord0.xy;

#if defined WORLD_OVERWORLD
	light_color = get_light_color();
	sun_color   = get_sun_exposure() * get_sun_tint();
	moon_color  = get_moon_exposure() * get_moon_tint();

	sky_samples[0] = get_sky_color();
	sky_samples[1] = sky_samples[0];
	sky_samples[2] = sky_samples[0];
#endif

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec3 scene_color;
layout (location = 1) out float bloomy_fog;

/* DRAWBUFFERS:03 */

#define TEMPORAL_REPROJECTION

#ifdef SHADOW_COLOR
	#undef SHADOW_COLOR
#endif

#ifdef SH_SKYLIGHT
	#undef SH_SKYLIGHT
#endif

#include "/include/lighting/diffuse.glsl"
#include "/include/lighting/shadows.glsl"
#include "/include/lighting/specular.glsl"
#include "/include/misc/fog/simple_fog.glsl"
#include "/include/misc/material.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/space_conversion.glsl"

/*
const bool colortex5MipmapEnabled = true;
 */

// https://iquilezles.org/www/articles/texture/texture.htm
vec4 smooth_filter(sampler2D sampler, vec2 coord)
{
	vec2 res = vec2(textureSize(sampler, 0));

	coord = coord * res + 0.5;

	vec2 i, f = modf(coord, i);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	coord = i + f;

	coord = (coord - 0.5) / res;
	return texture(sampler, coord);
}

// http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
vec3 purkinje_shift(vec3 rgb, float purkinje_intensity)
{
	const vec3 purkinje_tint = vec3(0.5, 0.7, 1.0) * rec709_to_rec2020;
	const vec3 rod_response = vec3(7.15e-5, 4.81e-1, 3.28e-1) * rec709_to_rec2020;

	if (purkinje_intensity == 0.0) return rgb;

	vec3 xyz = rgb * rec2020_to_xyz;

	vec3 scotopic_luminance = xyz * (1.33 * (1.0 + (xyz.y + xyz.z) / xyz.x) - 1.68);

	float purkinje = dot(rod_response, scotopic_luminance * xyz_to_rec2020);

	rgb = mix(rgb, purkinje * purkinje_tint, exp2(-rcp(purkinje_intensity) * purkinje));

	return max0(rgb);
}

// -----------
//   puddles
// -----------

float get_ripple_height(vec2 coord)
{
	const float ripple_frequency = 0.3;
	const float ripple_speed     = 0.1;
	const vec2 ripple_dir_0       = vec2( 3.0,   4.0) / 5.0;
	const vec2 ripple_dir_1       = vec2(-5.0, -12.0) / 13.0;

	float ripple_noise_1 = texture(noisetex, coord * ripple_frequency + frameTimeCounter * ripple_speed * ripple_dir_0).y;
	float ripple_noise_2 = texture(noisetex, coord * ripple_frequency + frameTimeCounter * ripple_speed * ripple_dir_1).y;

	return mix(ripple_noise_1, ripple_noise_2, 0.5);
}

float get_puddle_noise(vec3 world_pos, vec3 flat_normal, vec2 light_levels)
{
	const float puddle_frequency = 0.025;

	float puddle = texture(noisetex, world_pos.xz * puddle_frequency).w;
	      puddle = linear_step(0.45, 0.55, puddle) * wetness * biome_may_rain * max0(flat_normal.y);

	// Prevent puddles from appearing indoors
	puddle *= (1.0 - cube(light_levels.x)) * pow5(light_levels.y);

	return puddle;
}

bool get_rain_puddles(
	vec3 world_pos,
	vec3 flat_normal,
	vec2 light_levels,
	float distance_fade,
	float porosity,
	inout vec3 normal,
	inout vec3 f0,
	inout float roughness,
	inout float ssr_multiplier
) {
	const float puddle_f0                      = 0.02;
	const float puddle_roughness               = 0.002;
	const float puddle_darkening_factor        = 0.25;
	const float puddle_darkening_factor_porous = 0.4;

	if (wetness < 0.0 || biome_may_rain < 0.0) return false;

	float puddle = get_puddle_noise(world_pos, flat_normal, light_levels) * distance_fade;

	if (puddle < eps) return false;

	// Puddle darkening
	scene_color *= 1.0 - puddle_darkening_factor_porous * porosity * puddle;
	puddle *= 1.0 - porosity;
	scene_color *= 1.0 - puddle_darkening_factor * puddle;

	// Replace material with puddle material
	f0             = max(f0, mix(f0, vec3(puddle_f0), puddle));
	roughness      = puddle_roughness;
	ssr_multiplier = max(ssr_multiplier, puddle);

	// Ripple animation
	const float h = 0.1;
	float ripple0 = get_ripple_height(world_pos.xz);
	float ripple1 = get_ripple_height(world_pos.xz + vec2(h, 0.0));
	float ripple2 = get_ripple_height(world_pos.xz + vec2(0.0, h));

	vec3 ripple_normal     = vec3(ripple1 - ripple0, ripple2 - ripple0, h);
	     ripple_normal.xy *= 0.05 * smoothstep(0.0, 0.1, abs(dot(flat_normal, normalize(world_pos - cameraPosition))));
	     ripple_normal     = normalize(ripple_normal);
		 ripple_normal     = ripple_normal.xzy; // convert to world space

	normal = mix(normal, flat_normal, puddle);
	normal = mix(normal, ripple_normal, puddle * rainStrength);
	normal = normalize_safe(normal);

	return true;
}

void main()
{
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Texture fetches

	float depth0        = texelFetch(depthtex0, texel, 0).x;
	float depth1        = texelFetch(depthtex1, texel, 0).x;
	vec4 gbuffer_data_0 = texelFetch(colortex1, texel, 0);
#if defined NORMAL_MAPPING || defined SPECULAR_MAPPING
	vec4 gbuffer_data_1 = texelFetch(colortex2, texel, 0);
#endif
	vec4 blend_color    = texelFetch(colortex3, texel, 0);

	vec2 fog_uv = clamp(uv * VL_RENDER_SCALE, vec2(0.0), floor(view_res * VL_RENDER_SCALE - 1.0) * view_pixel_size);

	vec3 fog_scattering    = smooth_filter(colortex6, fog_uv).rgb;
	vec3 fog_transmittance = smooth_filter(colortex7, fog_uv).rgb;

	bool is_translucent = depth0 != depth1;

	// Transformations

	depth0 += 0.38 * float(depth0 < hand_depth); // Hand lighting fix from Capt Tatsu

	vec3 screen_pos = vec3(uv, depth0);
	vec3 view_pos   = screen_to_view_space(screen_pos, true);
	vec3 scene_pos  = view_to_scene_space(view_pos);
	vec3 world_pos  = scene_pos + cameraPosition;

	vec3 world_dir; float view_dist;
	length_normalize(scene_pos - gbufferModelViewInverse[3].xyz, world_dir, view_dist);

	// Unpack gbuffer data

	mat4x2 data = mat4x2(
		unpack_unorm_2x8(gbuffer_data_0.x),
		unpack_unorm_2x8(gbuffer_data_0.y),
		unpack_unorm_2x8(gbuffer_data_0.z),
		unpack_unorm_2x8(gbuffer_data_0.w)
	);

	vec3 albedo        = is_translucent ? blend_color.rgb : vec3(data[0], data[1].x);
	uint material_mask = uint(255.0 * data[1].y);
	vec3 flat_normal   = decode_unit_vector(data[2]);
	vec2 light_levels  = data[3];

	Material material;
	vec3 normal = flat_normal;

	mat3 tbn = get_tbn_matrix(flat_normal);

	// Get material

	bool is_water = material_mask == 1;
	bool is_rain_particle = material_mask == 253;
	bool is_snow_particle = material_mask == 254;

	if (is_water) {
		material.albedo             = srgb_eotf_inv(albedo) * rec709_to_rec2020;
		material.emission           = vec3(0.0);
		material.f0                 = vec3(0.02);
		material.roughness          = 0.002;
		material.sss_amount         = 1.0;
		material.sheen_amount       = 0.0;
		material.porosity           = 0.0;
		material.is_metal           = false;
		material.is_hardcoded_metal = false;
		material.ssr_multiplier     = 1.0;
	} else {
		material = material_from(albedo, material_mask, world_pos, light_levels);

#ifdef NORMAL_MAPPING
		normal = decode_unit_vector(gbuffer_data_1.xy);
#endif

#ifdef SPECULAR_MAPPING
		vec4 specular_map = vec4(unpack_unorm_2x8(gbuffer_data_1.z), unpack_unorm_2x8(gbuffer_data_1.w));

#if defined POM && defined POM_SHADOW
		// Specular map alpha > 0.5 => inside parallax shadow
		bool parallax_shadow = specular_map.a > 0.5;
		specular_map.a -= 0.5 * float(parallax_shadow);
		specular_map.a *= 2.0;
#endif

		decode_specular_map(specular_map, material);
#endif
	}

	// Refraction

#if REFRACTION == REFRACTION_OFF
	scene_color = texelFetch(colortex0, texel, 0).rgb;
#else
	vec2 refracted_uv = uv;

#if REFRACTION == REFRACTION_WATER_ONLY
	if (is_water) {
#elif REFRACTION == REFRACTION_ALL
	if (is_translucent) {
#endif
		vec3 tangent_normal = normal * tbn;
		refracted_uv = uv + 0.5 * tangent_normal.xy * rcp(view_dist);
	}

	scene_color = texture(colortex0, refracted_uv * taau_render_scale).rgb;
	depth1      = texture(depthtex1, refracted_uv * taau_render_scale).x;

	vec3 view_back_pos = screen_to_view_space(vec3(refracted_uv, depth1), true);
#endif

	// Shade translucent layer

	if (is_rain_particle) {
		vec3 rain_color = get_rain_color();
		scene_color = mix(scene_color, rain_color, RAIN_OPACITY);
	} else if (is_snow_particle) {
		vec3 snow_color = mix(0.5, 3.0, smoothstep(-0.1, 0.5, sun_dir.y)) * sunlight_color * vec3(0.49, 0.65, 1.00);
		scene_color = mix(scene_color, snow_color, SNOW_OPACITY);
	} else if (is_translucent) {
		float NoL = dot(normal, light_dir);
		float NoV = clamp01(dot(normal, -world_dir));
		float LoV = dot(light_dir, -world_dir);
		float halfway_norm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfway_norm;
		float LoH = LoV * halfway_norm + halfway_norm;

#if defined WORLD_OVERWORLD || defined WORLD_END
		float sss_depth;
		vec3 shadows = calculate_shadows(scene_pos, flat_normal, light_levels.y, material.sss_amount, sss_depth);
#else
		const float sss_depth = 0.0;
		const vec3 shadows = vec3(0.0);
#endif

		vec3 translucent_color = get_diffuse_lighting(
			material,
			normal,
			flat_normal,
			shadows,
			light_levels,
			material.sss_amount,
			sss_depth,
			NoL,
			NoV,
			NoH,
			LoV
		);

		translucent_color += get_specular_highlight(material, NoL, NoV, NoH, LoV, LoH) * light_color * shadows;

		// Blend with background

		if (is_water) {
			float dist = (isEyeInWater == 1) ? 0.0 : distance(view_pos, view_back_pos);
			float LoV = dot(world_dir, light_dir);
			float water_n = isEyeInWater == 1 ? air_n / water_n : water_n / air_n;

			mat2x3 water_fog = water_fog_simple(light_color, sky_samples[0], dist, LoV, light_levels.y, sss_depth);

			scene_color *= water_fog[1];
			scene_color += water_fog[0];
			scene_color *= 1.0 - fresnel_dielectric_n(NoV, water_n);
		} else {
			vec3 tint = normalize_safe(material.albedo);
			float alpha = blend_color.a;

			vec3 absorption_coeff = 3.0 * (1.0 - tint) * alpha;
			float dist = clamp(distance(view_pos, view_back_pos), 0.25, 1.41);

			scene_color *= exp(-absorption_coeff * dist);
			scene_color *= 1.0 - cube(alpha);
		}

		scene_color += translucent_color;
	}

	float distance_fade = border_fog(scene_pos, world_dir);

	// Rain puddles

#ifdef RAIN_PUDDLES
	bool puddle = get_rain_puddles(
		world_pos,
		flat_normal,
		light_levels,
		distance_fade,
		material.porosity,
		normal,
		material.f0,
		material.roughness,
		material.ssr_multiplier
	);

	if (puddle) {
		material.is_metal = false;
		material.is_hardcoded_metal = false;
	}
#endif

	// Specular reflections

#ifdef SSR
	if (material.ssr_multiplier > eps && depth0 < 1.0) {
		scene_color += get_specular_reflections(
			material,
			tbn,
			screen_pos,
			view_pos,
			normal,
			world_dir,
			world_dir * tbn,
			light_levels.y
		) * distance_fade;
	}
#endif

	// Apply fog to translucents

	if (is_translucent) {
		apply_fog(scene_color, scene_pos, world_dir, false);
	}

	// Apply volumetric lighting

#ifdef VL
	scene_color = mix(
		scene_color,
		scene_color * fog_transmittance + fog_scattering,
		depth0 == 1.0 ? 1.0 : distance_fade
	);
#endif

	// Purkinje shift

#ifdef PURKINJE_SHIFT
	light_levels = (depth0 == 1.0) ? vec2(0.0, 1.0) : light_levels;

	float purkinje_intensity  = 0.04 * PURKINJE_SHIFT_INTENSITY;
	      purkinje_intensity *= 1.0 - smoothstep(-0.12, -0.06, sun_dir.y) * light_levels.y;
	      purkinje_intensity *= clamp01(1.0 - light_levels.x);

	scene_color = purkinje_shift(scene_color, purkinje_intensity);
#endif

	// Calculate bloomy fog amount

#ifdef BLOOMY_FOG
	#ifdef VL
	bloomy_fog = clamp01(dot(fog_transmittance, vec3(0.33)));
	#else
	bloomy_fog = 1.0;
	#endif

	#ifdef CAVE_FOG
	bloomy_fog *= spherical_fog(view_dist, 0.0, 0.005 * biome_cave * float(depth0 != 1.0));
	#endif

	#ifdef BLOOMY_RAIN
	bloomy_fog *= 1.0 - RAIN_OPACITY * float(is_rain_particle) - SNOW_OPACITY * float(is_snow_particle);
	#endif
#endif
}

#endif
//----------------------------------------------------------------------------//
