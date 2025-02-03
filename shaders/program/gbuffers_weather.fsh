/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_weather:
  Handle rain and snow particles

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec4 frag_color;

/* RENDERTARGETS: 13 */

in vec2 uv;

flat in vec4 tint;

// ------------
//   Uniforms
// ------------

uniform sampler2D gtexture;

uniform int frameCounter;

uniform vec3 sun_dir;

uniform vec2 taa_offset;
uniform vec2 view_pixel_size;

uniform float biome_may_snow;

#include "/include/lighting/colors/weather_color.glsl"
#include "/include/utility/encoding.glsl"

const uint rain_flag = 253u;
const uint snow_flag = 254u;

void main() {
#if defined TAA && defined TAAU
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(coord) != coord) discard;
#endif

	vec4 base_color = texture(gtexture, uv);
	if (base_color.a < 0.1) discard;

	bool is_rain = (abs(base_color.r - base_color.b) > eps);

	frag_color = is_rain
		? vec4(get_rain_color(), RAIN_OPACITY * base_color.a) * tint
		: vec4(get_snow_color(), SNOW_OPACITY * base_color.a) * tint;
	frag_color.rgb *= frag_color.a;
}

