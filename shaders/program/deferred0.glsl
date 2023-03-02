/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/deferred0.glsl:
  Render omnidirectional sky map

--------------------------------------------------------------------------------

  Magic constants, please don't remove these!

  const int colortex0Format = R11F_G11F_B10F; // scene color (deferred3 -> temporal), bloom tiles (composite5 -> composite14), final color (composite14 -> final)
  const int colortex1Format = RGBA16;         // gbuffer data 0 (solid -> composite1)
  const int colortex2Format = RGBA16;         // gbuffer data 1 (solid -> composite1)
  const int colortex3Format = RGBA8;          // animated overlays/vanilla sky (solid -> deferred3), blended translucent color (translucent -> composite1)
  const int colortex4Format = R11F_G11F_B10F; // sky map (deferred -> composite1)
  const int colortex5Format = RGBA16F;        // scene history (always), low-res clouds (deferred1 -> deferred2 +flip),
  const int colortex6Format = RGBA16F;        // ambient occlusion history & clouds pixel age (always), fog scattering (composite -> composite1 +flip), TAAU min color (composite2 -> composite3 +flip)
  const int colortex7Format = RGBA16F;        // clouds history (always), fog transmittance (composite -> composite1), TAAU max color (composite2 -> composite3 +flip)

  const bool colortex0Clear = false;
  const bool colortex1Clear = true;
  const bool colortex2Clear = false;
  const bool colortex3Clear = true;
  const bool colortex4Clear = false;
  const bool colortex5Clear = false;
  const bool colortex6Clear = false;
  const bool colortex7Clear = false;

  const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

varying vec2 uv;

#if defined WORLD_OVERWORLD
flat varying vec3 sun_color;
flat varying vec3 moon_color;
flat varying vec3 base_light_color;
flat varying vec3 light_color;
flat varying vec3 sky_color;
flat varying vec3 sky_color_fog;

flat varying vec2 clouds_coverage_cu;
flat varying vec2 clouds_coverage_ac;
flat varying vec2 clouds_coverage_cc;
flat varying vec2 clouds_coverage_ci;

flat varying mat2x3 air_fog_coeff[2];
#endif

// ------------
//   uniforms
// ------------

uniform sampler3D colortex6; // 3D worley noise
uniform sampler3D colortex7; // 3D curl noise

uniform sampler3D depthtex0; // atmospheric scattering LUT
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

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
uniform float eyeAltitude;
uniform float rainStrength;
uniform float blindness;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float world_age;
uniform float eye_skylight;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

uniform float biome_cave;
uniform float biome_temperate;
uniform float biome_arid;
uniform float biome_snowy;
uniform float biome_taiga;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_may_rain;
uniform float biome_may_snow;
uniform float biome_temperature;
uniform float biome_humidity;

uniform bool clouds_moonlit;
uniform vec3 clouds_light_dir;


//----------------------------------------------------------------------------//
#if defined vsh

#define ATMOSPHERE_SCATTERING_LUT depthtex0

#include "/include/misc/palette.glsl"
#include "/include/misc/weather.glsl"

void main()
{
	uv = gl_MultiTexCoord0.xy;

#if defined WORLD_OVERWORLD
	light_color = get_light_color();
	sun_color = get_sun_exposure() * get_sun_tint();
	moon_color = get_moon_exposure() * get_moon_tint();
	base_light_color = mix(sun_color, moon_color, float(clouds_moonlit)) * (1.0 - rainStrength);

	const vec3 sky_dir = normalize(vec3(0.0, 1.0, -0.8)); // don't point direcly upwards to avoid the sun halo when the sun path rotation is 0
	sky_color = atmosphere_scattering(sky_dir, sun_dir) * sun_color + atmosphere_scattering(sky_dir, moon_dir) * moon_color;
	sky_color = tau * mix(sky_color, vec3(sky_color.b) * sqrt(2.0), rcp_pi);
	sky_color = mix(sky_color, tau * get_weather_color(), rainStrength);

	clouds_weather_variation(
		clouds_coverage_cu,
		clouds_coverage_ac,
		clouds_coverage_cc,
		clouds_coverage_ci
	);

	mat2x3 rayleigh_coeff = air_fog_rayleigh_coeff(), mie_coeff = air_fog_mie_coeff();
	air_fog_coeff[0] = mat2x3(rayleigh_coeff[0], mie_coeff[0]);
	air_fog_coeff[1] = mat2x3(rayleigh_coeff[1], mie_coeff[1]);

	sky_color_fog = get_sky_color();
#endif

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec3 sky_map;

/* DRAWBUFFERS:4 */

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define CLAMP_MIE_SCATTERING

#if defined WORLD_OVERWORLD
#include "/include/misc/fog/air_fog_vl.glsl"
#include "/include/sky/clouds.glsl"
#endif

#include "/include/sky/sky.glsl"
#include "/include/sky/projection.glsl"

void main()
{
	ivec2 texel = ivec2(gl_FragCoord.xy);

	vec3 ray_dir = unproject_sky(uv);

	sky_map = draw_sky(ray_dir);

#if defined WORLD_OVERWORLD
	// Apply volumetric fog to sky capture
	vec3 world_start_pos = vec3(cameraPosition);
	vec3 world_end_pos   = world_start_pos + ray_dir;

	mat2x3 fog = raymarch_air_fog(world_start_pos, world_end_pos, true, eye_skylight, 0.5);

	sky_map *= fog[1];
	sky_map += fog[0];
#endif
}

#endif
//----------------------------------------------------------------------------//
