/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_skytextured:
  Handle vanilla sun and moon and custom skies

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


out vec2 uv;
out vec3 view_pos;

flat out vec3 tint;
flat out vec3 sun_color;
flat out vec3 moon_color;

// ------------
//   Uniforms
// ------------

uniform float sunAngle;
uniform float rainStrength;

uniform vec2 taa_offset;

uniform vec3 sun_dir;
uniform vec3 light_dir;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#include "/include/lighting/colors/light_color.glsl"

void main() {
	sun_color = get_sun_exposure() * get_sun_tint();
	moon_color = get_moon_exposure() * get_moon_tint();

	uv   = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;
	tint = gl_Color.rgb;

	view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

	vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.75;
#endif

	gl_Position = clip_pos;
}

