/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffer/basic.vsh:
  Handle lines

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

flat out vec2 light_access;
flat out vec3 tint;

uniform vec2 taa_offset;
uniform vec2 view_res;
uniform vec2 view_pixel_size;

void main() {
	light_access = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	tint = gl_Color.rgb;

#if defined PROGRAM_LINE
	// Taken from Minecraft 1.17's rendertype_lines.vsh

	const float view_shrink = 1.0 - (1.0 / 256.0);
	const mat4 view_scale = mat4(
		view_shrink, 0.0, 0.0, 0.0,
		0.0, view_shrink, 0.0, 0.0,
		0.0, 0.0, view_shrink, 0.0,
		0.0, 0.0, 0.0, 1.0
	);

	const float line_width = 2.0;

	vec4 line_pos_start = vec4(gl_Vertex.xyz, 1.0);
	     line_pos_start = gl_ProjectionMatrix * view_scale * gl_ModelViewMatrix * line_pos_start;
	vec4 line_pos_end = vec4(gl_Vertex.xyz + gl_Normal, 1.0);
	     line_pos_end = gl_ProjectionMatrix * view_scale * gl_ModelViewMatrix * line_pos_start;

	vec3 ndc1 = line_pos_start.xyz / line_pos_start.w;
	vec3 ndc2 = line_pos_end.xyz / line_pos_end.w;

	vec2 line_screen_dir = normalize((ndc2.xy - ndc1.xy) * view_res);
	vec2 line_offset = vec2(-line_screen_dir.y, line_screen_dir.x) * line_width * view_pixel_size;

	if (line_offset.x < 0.0) line_offset *= -1.0;

	vec4 clip_pos = (gl_VertexID & 1) == 0
		? vec4((ndc1 + vec3(line_offset, 0.0)) * line_pos_start.w, line_pos_start.w)
		: vec4((ndc1 - vec3(line_offset, 0.0)) * line_pos_start.w, line_pos_start.w);
#else
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
