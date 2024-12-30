/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_basic:
  Handle lines

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

flat out vec2 light_levels;
flat out vec4 tint;
in vec4  vaColor;

#ifdef PROGRAM_GBUFFERS_LINE
// gbuffers_line seems to break in Iris 1.6 when the compatibility profile is
// used, so we must use the core spec
in vec3  vaPosition;
in vec3  vaNormal;
in ivec2 vaUV2;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

#if BOX_LINE_WIDTH != 2
uniform int renderStage;
#endif
#endif

uniform vec2 taa_offset;
uniform vec2 view_res;
uniform vec2 view_pixel_size;

void main() {
#if defined PROGRAM_GBUFFERS_LINE
	light_levels = clamp01(vec2(vaUV2) * rcp(240.0));

	// Taken from Minecraft 1.17's rendertype_lines.vsh

	const float view_shrink = 1.0 - (1.0 / 256.0);
	const mat4 view_scale = mat4(
		view_shrink, 0.0, 0.0, 0.0,
		0.0, view_shrink, 0.0, 0.0,
		0.0, 0.0, view_shrink, 0.0,
		0.0, 0.0, 0.0, 1.0
	);

	vec4 line_pos_start = vec4(vaPosition, 1.0);
	     line_pos_start = projectionMatrix * view_scale * modelViewMatrix * line_pos_start;
	vec4 line_pos_end = vec4(vaPosition + vaNormal, 1.0);
	     line_pos_end = projectionMatrix * view_scale * modelViewMatrix * line_pos_end;

	vec3 ndc1 = line_pos_start.xyz / line_pos_start.w;
	vec3 ndc2 = line_pos_end.xyz / line_pos_end.w;

	vec2 line_screen_dir = normalize((ndc2.xy - ndc1.xy) * view_res);

	vec2 line_offset =
#if BOX_LINE_WIDTH != 2
		vec2(-line_screen_dir.y, line_screen_dir.x) * view_pixel_size * ((renderStage == MC_RENDER_STAGE_OUTLINE) ? float(BOX_LINE_WIDTH) : 2.0);
#else
		vec2(-line_screen_dir.y, line_screen_dir.x) * view_pixel_size * 2.0;
#endif

	if (line_offset.x < 0.0) line_offset *= -1.0;

	vec4 clip_pos = (gl_VertexID & 1) == 0
		? vec4((ndc1 + vec3(line_offset, 0.0)) * line_pos_start.w, line_pos_start.w)
		: vec4((ndc1 - vec3(line_offset, 0.0)) * line_pos_start.w, line_pos_start.w);
#else
	light_levels = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	vec3 view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);
#endif

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.66;
#endif

	tint = vaColor;
	gl_Position = clip_pos;
}

