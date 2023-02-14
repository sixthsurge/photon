/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/weather.glsl:
  Handle rain and snow particles

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

varying vec2 uv;

flat varying vec4 tint;

// ------------
//   uniforms
// ------------

uniform sampler2D gtexture;

#if defined NORMAL_MAPPING
uniform sampler2D normals;
#endif

#ifdef SPECULAR_MAPPING
uniform sampler2D specular;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform int frameCounter;

uniform vec2 taa_offset;
uniform vec2 view_pixel_size;

// ------------------
//   fragment stage
// ------------------
#if defined FSH

/* DRAWBUFFERS:31 */
layout (location = 0) out vec4 base_color;
layout (location = 1) out vec4 gbuffer_data;

#include "/include/utility/encoding.glsl"

const uint rain_flag = 253u;
const uint snow_flag = 254u;
const float lod_bias = log2(taau_render_scale);

void main() {
#if defined TAA && defined TAAU
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(coord) != coord) discard;
#endif

	base_color = texture(gtexture, uv, lod_bias) * tint;

	if (base_color.a < 0.1) discard;

	bool is_snow = abs(base_color.r - base_color.b) < eps;
	uint object_id = is_snow ? snow_flag : rain_flag;

	gbuffer_data.x  = pack_unorm_2x8(base_color.rg);
	gbuffer_data.y  = pack_unorm_2x8(base_color.b, float(object_id) * rcp(255.0));
	gbuffer_data.z  = pack_unorm_2x8(encode_unit_vector(vec3(0.0, 1.0, 0.0)));
	gbuffer_data.w  = pack_unorm_2x8(vec2(1.0));
}

#endif

// ----------------
//   vertex stage
// ----------------
#if defined VSH

void main() {
	uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;

	tint = gl_Color;

	vec3 view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

#ifdef SLANTED_RAIN
	const float rain_tilt_amount = 0.2;

	vec3 scene_pos = transform(gbufferModelViewInverse, view_pos);
	vec3 world_pos = scene_pos + cameraPosition;

	float tilt_wave = 0.7 + 0.3 * sin(dot(world_pos, vec3(5.0)));
	scene_pos.xz -= rain_tilt_amount * tilt_wave * scene_pos.y;

	view_pos = transform(gbufferModelView, scene_pos);
#endif

	vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.66;
#endif

	gl_Position = clip_pos;
}

#endif
