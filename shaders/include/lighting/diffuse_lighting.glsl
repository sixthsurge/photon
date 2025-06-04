#if !defined INCLUDE_LIGHTING_DIFFUSE_LIGHTING
#define INCLUDE_LIGHTING_DIFFUSE_LIGHTING

#include "/include/lighting/colors/blocklight_color.glsl"
#include "/include/lighting/bsdf.glsl"
#include "/include/misc/end_lighting_fix.glsl"
#include "/include/surface/material.glsl"
#include "/include/utility/phase_functions.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/spherical_harmonics.glsl"

#ifdef COLORED_LIGHTS
#include "/include/lighting/lpv/blocklight.glsl"
#endif

#ifdef HANDHELD_LIGHTING
#include "/include/lighting/handheld_lighting.glsl"
#endif

#if !defined WORLD_OVERWORLD
	#undef CLOUD_SHADOWS
#endif

const float sss_density          = 14.0;
const float sss_scale            = 5.0 * SSS_INTENSITY;
const float night_vision_scale   = 1.5;
const float metal_diffuse_amount = 0.5; // Scales diffuse lighting on metals, ideally this would be zero but purely specular metals don't play well with SSR

float get_blocklight_falloff(float blocklight, float skylight, float ao) {
	float falloff  = pow8(blocklight) + 0.18 * sqr(blocklight) + 0.16 * dampen(blocklight);                // Base falloff
	      falloff *= mix(cube(ao), 1.0, clamp01(falloff));                                                 // Stronger AO further from the light source
		  falloff *= mix(1.0, ao * dampen(abs(cos(2.0 * frameTimeCounter))) * 0.67 + 0.2, darknessFactor); // Pulsing blocklight with darkness effect
		  falloff *= 1.0 - 0.2 * time_noon * skylight - 0.2 * skylight;                                    // Reduce blocklight intensity in daylight
		  falloff += min(2.7 * pow12(blocklight), 0.9);                                                    // Strong highlight around the light source, visible even in the daylight
		  falloff *= smoothstep(0.0, 0.125, blocklight);                                                   // Ease transition at edge of lightmap

	return falloff;
}

float get_skylight_falloff(float skylight) {
#if defined WORLD_OVERWORLD
	return sqr(skylight);
#else
	return 1.0;
#endif
}

#ifdef SHADOW_VPS
vec3 sss_approx(
	vec3 albedo, 
	float sss_amount, 
	float sheen_amount, 
	float sss_depth, 
	float LoV, 
	float shadow
) {
	// Transmittance-based SSS
	if (sss_amount < eps) return vec3(0.0);

	vec3 coeff = albedo * inversesqrt(dot(albedo, luminance_weights) + eps);
	     coeff = 0.75 * clamp01(coeff);
	     coeff = (1.0 - coeff) * sss_density / sss_amount;

	float phase = mix(isotropic_phase, henyey_greenstein_phase(-LoV, 0.7), 0.33);

	vec3 sss = sss_scale * phase * exp2(-coeff * sss_depth) * dampen(sss_amount) * pi;

	#ifdef SSS_SHEEN
	vec3 sheen = (0.8 * SSS_INTENSITY) * rcp(albedo + eps) * exp2(-1.0 * coeff * sss_depth) * henyey_greenstein_phase(-LoV, 0.5) * linear_step(-0.8, -0.2, -LoV);
	sss += sheen * sheen_amount;
	#endif

	return sss;
}
#else
vec3 sss_approx(
	vec3 albedo, 
	float sss_amount, 
	float sheen_amount, 
	float sss_depth, 
	float LoV, 
	float shadow
) {
	// Blur-based SSS
	float sss = 0.06 * sss_scale * pi;
	vec3 sheen = 0.8 * rcp(albedo + eps) * henyey_greenstein_phase(-LoV, 0.5) * linear_step(-0.8, -0.2, -LoV) * shadow;

	return sss + sheen * sheen_amount;
}
#endif

vec3 get_diffuse_lighting(
	Material material,
	vec3 scene_pos,
	vec3 normal,
	vec3 flat_normal,
	vec3 bent_normal,
	vec3 shadows,
	vec2 light_levels,
	float ao,
	float ambient_sss,
	float sss_depth,
#ifdef CLOUD_SHADOWS
	float cloud_shadows,
#endif
	float shadow_distance_fade,
	float NoL,
	float NoV,
	float NoH,
	float LoV
) {
#if defined PROGRAM_GBUFFERS_WATER
	// Small optimization, don't calculate diffuse lighting when albedo is 0 (eg water)
	if (max_of(material.albedo) < eps) return vec3(0.0);
#endif

	vec3 lighting = vec3(0.0);

	// Arbitrary directional shading to make faces easier to distinguish
	float directional_lighting = (0.9 + 0.1 * normal.x) * (0.8 + 0.2 * abs(flat_normal.y)) + 2.0 * ambient_sss * material.sss_amount; 

#if defined WORLD_OVERWORLD || defined WORLD_END

	// Sunlight/moonlight

#ifdef SHADOW
	vec3 diffuse = vec3(lift(max0(NoL), 0.25 * rcp(SHADING_STRENGTH)) * (1.0 - 0.5 * material.sss_amount));
	vec3 bounced = 0.033 * (1.0 - shadows) * (1.0 - 0.1 * max0(normal.y)) * pow1d5(ao + eps) * pow4(light_levels.y) * BOUNCED_LIGHT_I;
	vec3 sss = sss_approx(material.albedo, material.sss_amount, material.sheen_amount, mix(sss_depth, 0.0, shadow_distance_fade), LoV, shadows.x);

	// Adjust SSS outside of shadow distance
	sss *= mix(1.0, (ao + pi * ambient_sss) * (clamp01(NoL) * 0.8 + 0.2), clamp01(shadow_distance_fade));

	#ifdef AO_IN_SUNLIGHT
	diffuse *= sqr(ao);
	#endif

	#ifdef SHADOW_VPS
	// Add SSS and diffuse
	lighting += diffuse * shadows + bounced + sss;
	#else
	// Blend SSS and diffuse
	lighting += mix(diffuse, sss, material.sss_amount) * shadows + bounced;
	#endif
#else
	// Simple shading for when shadows are disabled
	vec3 sss = 0.08 * sss_scale * pi + 0.5 * material.sheen_amount * rcp(material.albedo + eps) * henyey_greenstein_phase(-LoV, 0.5) * linear_step(-0.8, -0.2, -LoV);

	vec3 diffuse  = vec3(lift(max0(NoL), 0.5 * rcp(SHADING_STRENGTH)) * 0.6 + 0.4) * (shadows * 0.8 + 0.2);
	     diffuse  = mix(diffuse, sss, lift(material.sss_amount, 5.0));
	     diffuse *= 1.0 * (0.9 + 0.1 * normal.x) * (0.8 + 0.2 * abs(flat_normal.y));
	     diffuse *= ao * pow4(light_levels.y) * (dampen(light_dir.y) * 0.5 + 0.5);

	lighting += diffuse;
#endif

	lighting *= light_color;

#ifdef CLOUD_SHADOWS
	lighting *= cloud_shadows;
#endif
#endif

	// Skylight

#if defined WORLD_OVERWORLD && defined PROGRAM_DEFERRED4 && defined SH_SKYLIGHT
	vec3 skylight = sh_evaluate_irradiance(sky_sh, bent_normal, ao);
	skylight = mix(skylight_up, skylight, sqr(light_levels.y));
#else
	vec3 skylight = ambient_color * ao;
	vec3 skylight_up = skylight;
#endif

	// Skylight SSS
	skylight = mix(skylight, 0.5 * skylight_up * ao, material.sss_amount);
	skylight += ambient_sss * skylight_up * material.sss_amount * 2.0;

#if defined WORLD_NETHER
	// Brighten + desaturate nether ambient
	skylight = 16.0 * directional_lighting * mix(skylight, vec3(dot(skylight, luminance_weights_rec2020)), 0.5);
#endif

	lighting += skylight * get_skylight_falloff(light_levels.y);

	// Blocklight

	float blocklight_falloff = get_blocklight_falloff(light_levels.x, light_levels.y, ao);
	vec3 mc_blocklight = (blocklight_falloff * directional_lighting) * (blocklight_scale * blocklight_color);

#ifdef COLORED_LIGHTS
	lighting += get_lpv_blocklight(scene_pos, flat_normal, mc_blocklight, ao * directional_lighting);
#else
	lighting += mc_blocklight;
#endif

#ifdef HANDHELD_LIGHTING
	lighting += get_handheld_lighting(scene_pos, ao);
#endif

	lighting += material.emission * emission_scale;

#if defined WORLD_OVERWORLD
	// Cave lighting

	lighting += 0.15 * CAVE_LIGHTING_I * directional_lighting * ao * (1.0 - light_levels.y * light_levels.y) * (1.0 - 0.7 * darknessFactor);
	lighting += nightVision * night_vision_scale * directional_lighting * ao;
#endif

	return max0(lighting) * material.albedo * rcp_pi * mix(1.0, metal_diffuse_amount, float(material.is_metal));
}

#endif // INCLUDE_LIGHTING_DIFFUSE_LIGHTING
