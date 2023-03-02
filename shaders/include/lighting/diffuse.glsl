#ifndef INCLUDE_LIGHTING_DIFFUSE
#define INCLUDE_LIGHTING_DIFFUSE

#include "/include/lighting/bsdf.glsl"
#include "/include/misc/material.glsl"
#include "/include/misc/palette.glsl"
#include "/include/utility/phase_functions.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/spherical_harmonics.glsl"

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

const vec3  blocklight_color     = from_srgb(vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B)) * BLOCKLIGHT_I;
const float blocklight_scale     = 9.0;
const float emission_scale       = 40.0 * EMISSION_STRENGTH;
const float sss_density          = 14.0;
const float sss_scale            = 4.2;
const float metal_diffuse_amount = 0.25; // Scales diffuse lighting on metals, ideally this would be zero but purely specular metals don't play well with SSR
const float night_vision_scale   = 1.5;

vec3 sss_approx(vec3 albedo, float sss_amount, float sheen_amount, float sss_depth, float LoV) {
	if (sss_amount < eps) return vec3(0.0);

	vec3 coeff = albedo * inversesqrt(dot(albedo, luminance_weights) + eps);
	     coeff = clamp01(0.75 * coeff);
	     coeff = (1.0 - coeff) * sss_density / sss_amount;

	float phase = mix(isotropic_phase, henyey_greenstein_phase(-LoV, 0.7), 0.33);

	vec3 sss = sss_scale * phase * exp2(-coeff * sss_depth) * dampen(sss_amount) * pi;
	vec3 sheen = 0.8 * rcp(albedo + eps) * exp2(-1.0 * coeff * sss_depth) * henyey_greenstein_phase(-LoV, 0.5) * linear_step(-0.8, -0.2, -LoV);

	return sss + sheen * sheen_amount;
}

vec3 get_diffuse_lighting(
	Material material,
	vec3 normal,
	vec3 flat_normal,
	vec3 shadows,
	vec2 light_levels,
	float ao,
	float sss_depth,
	float NoL,
	float NoV,
	float NoH,
	float LoV
) {
	vec3 lighting = vec3(0.0);

	// Sunlight/moonlight

	vec3 diffuse = vec3(lift(max0(NoL), 0.33) * (1.0 - 0.5 * material.sss_amount));
	vec3 bounced = 0.08 * (1.0 - shadows * max0(NoL)) * (1.0 - 0.33 * max0(normal.y)) * pow1d5(ao + eps) * pow4(light_levels.y);
	vec3 sss = sss_approx(material.albedo, material.sss_amount, material.sheen_amount, sss_depth, LoV);

#ifdef AO_IN_SUNLIGHT
	diffuse *= sqrt(ao) * mix(ao * ao, 1.0, NoL * NoL);
#endif

	lighting += light_color * (diffuse * shadows + bounced + sss);

	// Skylight

	float vanilla_diffuse = (0.9 + 0.1 * normal.x) * (0.8 + 0.2 * abs(flat_normal.y)); // Random directional shading to make faces easier to distinguish

#ifdef SH_SKYLIGHT
	vec3 skylight = sh_evaluate_irradiance(sky_sh, normal, ao);
#else
	vec3 horizon_color = mix(sky_samples[1], sky_samples[2], dot(normal.xz, moon_dir.xz) * 0.5 + 0.5);
	     horizon_color = mix(horizon_color, mix(sky_samples[1], sky_samples[2], step(sun_dir.y, 0.5)), abs(normal.y) * (time_noon + time_midnight));

	float horizon_weight = 0.166 * (time_noon + time_midnight) + 0.03 * (time_sunrise + time_sunset);

	vec3 rain_skylight  = get_weather_color() * mix(sqr(vanilla_diffuse), 0.95, step(eps, material.sss_amount));
	     rain_skylight *= mix(4.0, 2.0, smoothstep(-0.1, 0.5, sun_dir.y));

	vec3 skylight  = mix(sky_samples[0] * 1.3, horizon_color, horizon_weight);
	     skylight  = mix(horizon_color * 0.2, skylight, clamp01(abs(normal.y)) * 0.3 + 0.7);
	     skylight *= 1.0 - 0.75 * clamp01(-normal.y);
	     skylight *= 1.0 + 0.33 * clamp01(flat_normal.y) * (1.0 - shadows.x * (1.0 - rainStrength)) * (time_noon + time_midnight);
		 skylight  = mix(skylight, rain_skylight, rainStrength);
	     skylight *= ao * pi;
#endif

	float skylight_falloff = sqr(light_levels.y);

	lighting += skylight * skylight_falloff;

	// Blocklight

	float blocklight_falloff  = 0.3 * pow5(light_levels.x) + 0.12 * sqr(light_levels.x) + 0.15 * dampen(light_levels.x); // Base falloff
	      blocklight_falloff *= mix(ao, 1.0, clamp01(blocklight_falloff * 2.0));                          // Stronger AO further from the light source
		  blocklight_falloff *= 1.0 - 0.2 * time_noon * light_levels.y - 0.2 * light_levels.y;                      // Reduce blocklight intensity in daylight
		  blocklight_falloff += 2.5 * pow12(light_levels.x);                                                 // Strong highlight around the light source, visible even in the daylight

	lighting += (blocklight_falloff * vanilla_diffuse) * (blocklight_scale * blocklight_color);

	lighting += material.emission * emission_scale;

	// Cave lighting

	lighting += CAVE_LIGHTING_I * vanilla_diffuse * ao * (1.0 - skylight_falloff);
	lighting += nightVision * night_vision_scale * vanilla_diffuse * ao;

	return max0(lighting) * material.albedo * rcp_pi * mix(1.0, metal_diffuse_amount, float(material.is_metal));
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

//----------------------------------------------------------------------------//
#elif defined WORLD_END

#endif

#endif // INCLUDE_LIGHTING_DIFFUSE
