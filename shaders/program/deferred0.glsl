/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/deferred0.glsl:
  Render omnidirectional sky map for reflections and SH lighting

--------------------------------------------------------------------------------

  Magic constants, please don't remove these!

  const int colortex0Format  = R11F_G11F_B10F; // full res    | scene color (deferred3 -> temporal), bloom tiles (composite5 -> composite14), final color (composite14 -> final)
  const int colortex1Format  = RGBA16;         // full res    | gbuffer data 0 (solid -> composite1)
  const int colortex2Format  = RGBA16;         // full res    | gbuffer data 1 (solid -> composite1)
  const int colortex3Format  = RGBA8;          // full res    | animated overlays/vanilla sky (solid -> deferred3), blended translucent color (translucent -> composite1), bloomy fog amount (composite1 -> composite14)
  const int colortex4Format  = R11F_G11F_B10F; // 192x108     | sky map (deferred -> composite1)
  const int colortex5Format  = RGBA16F;        // full res    | scene history (always)
  const int colortex6Format  = RGB16F;         // quarter res | ambient occlusion history (always), fog scattering (composite -> composite1 +flip) 
  const int colortex7Format  = RGB8;           // quarter res | fog transmittance
  const int colortex8Format  = R16;            // 256x256     | cloud shadow map
  const int colortex9Format  = RGBA16F;        // clouds res  | low-res clouds  
  const int colortex10Format = R16F;           // clouds res  | low-res clouds apparent distance
  const int colortex11Format = RGBA16F;        // full res    | clouds history
  const int colortex12Format = RG16F;          // full res    | clouds pixel age and apparent distance
  const int colortex13Format = RGB16F;         // full res    | TAAU min color for AABB clipping
  const int colortex14Format = RGB16F;         // full res    | TAAU max color for AABB clipping
  const int colortex15Format = R32F;           // full res    | DH combined depth buffer

  const bool colortex0Clear  = false;
  const bool colortex1Clear  = true;
  const bool colortex2Clear  = false;
  const bool colortex3Clear  = true;
  const bool colortex4Clear  = false;
  const bool colortex5Clear  = false;
  const bool colortex6Clear  = false;
  const bool colortex7Clear  = false;
  const bool colortex8Clear  = false;
  const bool colortex9Clear  = false;
  const bool colortex10Clear = false;
  const bool colortex11Clear = false;
  const bool colortex12Clear = false;
  const bool colortex13Clear = false;
  const bool colortex14Clear = false;
  const bool colortex15Clear = false;

  const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;

flat out vec3 ambient_color;
flat out vec3 light_color;

#if defined WORLD_OVERWORLD
flat out vec3 sun_color;
flat out vec3 moon_color;
flat out vec3 sky_color;

flat out vec2 clouds_cumulus_coverage;
flat out vec2 clouds_altocumulus_coverage;
flat out float clouds_cirrus_coverage;

flat out float clouds_cumulus_congestus_amount;
flat out float clouds_stratus_amount;

flat out float aurora_amount;
flat out mat2x3 aurora_colors;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler3D depthtex0; // atmospheric scattering LUT

uniform float blindness;
uniform float eyeAltitude;
uniform float rainStrength;
uniform float wetness;

uniform int worldTime;
uniform int worldDay;
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform int isEyeInWater;

uniform vec3 fogColor;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

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

// ------------
//   Includes
// ------------

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define WEATHER_AURORA
#define WEATHER_CLOUDS

#if defined WORLD_OVERWORLD
#include "/include/light/colors/light_color.glsl"
#include "/include/light/colors/weather_color.glsl"
#include "/include/misc/weather.glsl"
#endif

#if defined WORLD_NETHER
#include "/include/light/colors/nether_color.glsl"
#endif

#if defined WORLD_END
#include "/include/light/colors/end_color.glsl"
#endif

#if defined WORLD_OVERWORLD
vec3 get_ambient_color() {
	sun_color  = get_sun_exposure() * get_sun_tint();
	moon_color = get_moon_exposure() * get_moon_tint();

	const vec3 sky_dir = normalize(vec3(0.0, 1.0, -0.8)); // don't point direcly upwards to avoid the sun halo when the sun path rotation is 0
	sky_color = atmosphere_scattering(sky_dir, sun_color, sun_dir, moon_color, moon_dir);
	sky_color = tau * sky_color * 1.13;
	sky_color = mix(sky_color, tau * get_weather_color(), rainStrength);

	return sky_color;
}
#endif

void main() {
	uv = gl_MultiTexCoord0.xy;

	light_color   = get_light_color();
	ambient_color = get_ambient_color();

#if defined WORLD_OVERWORLD
	clouds_weather_variation(
		clouds_cumulus_coverage,
		clouds_altocumulus_coverage,
		clouds_cirrus_coverage,
		clouds_cumulus_congestus_amount,
		clouds_stratus_amount
	);

	aurora_amount = get_aurora_amount();
	aurora_colors = get_aurora_colors();

	sky_color += aurora_amount * AURORA_CLOUD_LIGHTING * mix(aurora_colors[0], aurora_colors[1], 0.25);
#endif

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec3 sky_map;

/* RENDERTARGETS: 4 */

in vec2 uv;

flat in vec3 ambient_color;
flat in vec3 light_color;

#if defined WORLD_OVERWORLD
flat in vec3 sun_color;
flat in vec3 moon_color;
flat in vec3 sky_color;

flat in vec2 clouds_cumulus_coverage;
flat in vec2 clouds_altocumulus_coverage;
flat in float clouds_cirrus_coverage;

flat in float clouds_cumulus_congestus_amount;
flat in float clouds_stratus_amount;

flat in float aurora_amount;
flat in mat2x3 aurora_colors;
#endif

// ------------
//   Uniforms
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
uniform float biome_may_snow;

// ------------
//   Includes
// ------------

#define ATMOSPHERE_SCATTERING_LUT depthtex0

#if defined WORLD_OVERWORLD
#include "/include/sky/aurora.glsl"
#include "/include/sky/clouds.glsl"
#endif

#include "/include/sky/sky.glsl"
#include "/include/sky/projection.glsl"

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	if (texel.x == sky_map_res.x) { // Store lighting colors
		sky_map = vec3(0.0);
		switch (texel.y) {
		case 0:
			sky_map = light_color;
			break;

		case 1:
			sky_map = ambient_color;
			break;
		}
	} else { // Draw sky map
		vec3 ray_dir = unproject_sky(uv);

		sky_map = draw_sky(ray_dir);
	}
}

#endif
//----------------------------------------------------------------------------//
