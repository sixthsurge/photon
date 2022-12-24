#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred3.vsh:
  Generate sky SH for far-field indirect lighting

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 light_color;
flat out vec3 sun_color;
flat out vec3 moon_color;
#ifdef SH_SKYLIGHT
flat out vec3 sky_sh[9];
#else
flat out mat3 sky_samples;
#endif

uniform sampler2D colortex4; // Sky capture

uniform sampler3D depthtex0; // Atmospheric scattering LUT

uniform float sunAngle;

uniform int worldTime;

uniform float rainStrength;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define WORLD_OVERWORLD

#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/spherical_harmonics.glsl"

#include "/include/atmosphere.glsl"
#include "/include/palette.glsl"
#include "/include/sky_projection.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	sun_color = get_sunlight_scale() * get_sunlight_tint();
	moon_color = get_moonlight_scale() * get_moonlight_tint();

	light_color = get_light_color();

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
	vec3 dir0 = normalize(vec3(0.0, 1.0, -0.8));              // Up
	vec3 dir1 = normalize(vec3(sun_dir.xz + 0.1, 0.066).xzy);  // Sun-facing horizon
	vec3 dir2 = normalize(vec3(moon_dir.xz + 0.1, 0.066).xzy); // Opposite horizon

	sky_samples[0] = sun_color * atmosphere_scattering(dir0, sun_dir)
	             + moon_color * atmosphere_scattering(dir0, moon_dir);
	sky_samples[1] = sun_color * atmosphere_scattering(dir1, sun_dir)
	             + moon_color * atmosphere_scattering(dir1, moon_dir);
	sky_samples[2] = sun_color * atmosphere_scattering(dir2, sun_dir)
	             + moon_color * atmosphere_scattering(dir2, moon_dir);

	sky_samples[0] *= skylight_boost;
	sky_samples[1] *= skylight_boost;
	sky_samples[2] *= skylight_boost;
#endif

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}
