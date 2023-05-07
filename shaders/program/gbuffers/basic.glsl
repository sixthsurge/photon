/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffers/basic.glsl:
  Handle lines

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

flat out vec2 light_levels;
flat out vec3 tint;

#ifdef PROGRAM_GBUFFERS_LINE
// gbuffers_line seems to break in Iris 1.6 when the compatibility profile is
// used, so we must use the core spec
in vec3  vaPosition;
in vec3  vaNormal;
in vec4  vaColor;
in ivec2 vaUV2;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;
#endif

uniform vec2 taa_offset;
uniform vec2 view_res;
uniform vec2 view_pixel_size;

void main() {
#if defined PROGRAM_GBUFFERS_LINE
	light_levels = clamp01(vec2(vaUV2) * rcp(240.0));
	tint = vaColor.rgb;

	// Taken from Minecraft 1.17's rendertype_lines.vsh

	const float view_shrink = 1.0 - (1.0 / 256.0);
	const mat4 view_scale = mat4(
		view_shrink, 0.0, 0.0, 0.0,
		0.0, view_shrink, 0.0, 0.0,
		0.0, 0.0, view_shrink, 0.0,
		0.0, 0.0, 0.0, 1.0
	);

	const float line_width = 2.0;

	vec4 line_pos_start = vec4(vaPosition, 1.0);
	     line_pos_start = projectionMatrix * view_scale * modelViewMatrix * line_pos_start;
	vec4 line_pos_end = vec4(vaPosition + vaNormal, 1.0);
	     line_pos_end = projectionMatrix * view_scale * modelViewMatrix * line_pos_start;

	vec3 ndc1 = line_pos_start.xyz / line_pos_start.w;
	vec3 ndc2 = line_pos_end.xyz / line_pos_end.w;

	vec2 line_screen_dir = normalize((ndc2.xy - ndc1.xy) * view_res);
	vec2 line_offset = vec2(-line_screen_dir.y, line_screen_dir.x) * line_width * view_pixel_size;

	if (line_offset.x < 0.0) line_offset *= -1.0;

	vec4 clip_pos = (gl_VertexID & 1) == 0
		? vec4((ndc1 + vec3(line_offset, 0.0)) * line_pos_start.w, line_pos_start.w)
		: vec4((ndc1 - vec3(line_offset, 0.0)) * line_pos_start.w, line_pos_start.w);
#else
	light_levels = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	tint = gl_Color.rgb;

	vec3 view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);
#endif

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.66;
#endif

	gl_Position = clip_pos;
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec3 scene_color;
layout (location = 1) out vec4 gbuffer_data_0; // albedo, block ID, flat normal, light levels
layout (location = 2) out vec4 gbuffer_data_1; // detailed normal, specular map (optional)

/* DRAWBUFFERS:012 */

flat in vec2 light_levels;
flat in vec3 tint;

// ------------
//   Uniforms
// ------------

uniform vec2 view_res;
uniform vec2 view_pixel_size;

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"

const vec3 normal = vec3(0.0, 1.0, 0.0);

void main() {
#if defined TAA && defined TAAU
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(coord) != coord) discard;
#endif

	scene_color = srgb_eotf_inv(tint) * rec709_to_working_color;

	vec2 encoded_normal = encode_unit_vector(normal);

	gbuffer_data_0.x = pack_unorm_2x8(tint.rg);
	gbuffer_data_0.y = pack_unorm_2x8(tint.b, 0.0);
	gbuffer_data_0.z = pack_unorm_2x8(encode_unit_vector(normal));
	gbuffer_data_0.w = pack_unorm_2x8(light_levels);

#ifdef NORMAL_MAPPING
	gbuffer_data_1.xy = encoded_normal;
#endif

#ifdef SPECULAR_MAPPING
	const vec4 specular_map = vec4(0.0);
	gbuffer_data_1.z = pack_unorm_2x8(specular_map.xy);
	gbuffer_data_1.w = pack_unorm_2x8(specular_map.zw);
#endif
}

#endif
//----------------------------------------------------------------------------//
