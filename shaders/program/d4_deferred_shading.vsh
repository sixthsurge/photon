/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/d4_deferred_shading:
  Shade terrain and entities, draw sky

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 ambient_color;
flat out vec3 light_color;

#if defined WORLD_OVERWORLD
flat out vec3 sun_color;
flat out vec3 moon_color;

#if defined SH_SKYLIGHT
flat out vec3 sky_sh[9];
#else
flat out mat3 sky_samples;
#endif
#endif

// ------------
//   Uniforms
// ------------

uniform sampler3D depthtex0; // Atmosphere scattering LUT

uniform sampler2D colortex4; // Sky map, lighting colors

uniform int worldTime;
uniform int worldDay;
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

uniform float biome_cave;
uniform float biome_may_rain;
uniform float biome_may_snow;
uniform float biome_snowy;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

// ------------
//   Includes
// ------------

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define WEATHER_AURORA

#if defined WORLD_OVERWORLD
#include "/include/lighting/colors/light_color.glsl"
#include "/include/misc/weather.glsl"
#include "/include/sky/atmosphere.glsl"
#include "/include/sky/projection.glsl"
#endif

#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/spherical_harmonics.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
	ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;

#if defined WORLD_OVERWORLD
	sun_color    = get_sun_exposure() * get_sun_tint();
	moon_color   = get_moon_exposure() * get_moon_tint();
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
	#else
	vec3 dir0 = normalize(vec3(0.0, 1.0, -0.8));               // Up
	vec3 dir1 = normalize(vec3(sun_dir.xz + 0.1, 0.066).xzy);  // Sun-facing horizon
	vec3 dir2 = normalize(vec3(moon_dir.xz + 0.1, 0.066).xzy); // Opposite horizon

	sky_samples[0] = atmosphere_scattering(dir0, sun_color, sun_dir, moon_color, moon_dir, /* use_klein_nishina_phase */ false) * skylight_boost;
	sky_samples[1] = atmosphere_scattering(dir1, sun_color, sun_dir, moon_color, moon_dir, /* use_klein_nishina_phase */ false) * skylight_boost;
	sky_samples[2] = atmosphere_scattering(dir2, sun_color, sun_dir, moon_color, moon_dir, /* use_klein_nishina_phase */ false) * skylight_boost;

	// Aurorae
	float aurora_amount = get_aurora_amount();
	mat2x3 aurora_colors = get_aurora_colors();

	sky_samples[0] += aurora_amount * AURORA_GROUND_LIGHTING * mix(aurora_colors[0], aurora_colors[1], 0.25);
	#endif
#endif

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}

