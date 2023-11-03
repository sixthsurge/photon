/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/basic.glsl:
  Handle lines

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

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

#if BOX_LINE_WIDTH != 2.0
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
#if BOX_LINE_WIDTH != 2.0
		vec2(-line_screen_dir.y, line_screen_dir.x) * view_pixel_size * ((renderStage == MC_RENDER_STAGE_OUTLINE) ? BOX_LINE_WIDTH : 2.0);
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

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec4 scene_color;
layout (location = 1) out vec4 gbuffer_data_0; // albedo, block ID, flat normal, light levels
layout (location = 2) out vec4 gbuffer_data_1; // detailed normal, specular map (optional)

/* DRAWBUFFERS:012 */

flat in vec2 light_levels;
flat in vec4 tint;

// ------------
//   Uniforms
// ------------

uniform vec2 view_res;
uniform vec2 view_pixel_size;

#if BOX_MODE != BOX_MODE_NONE
uniform int renderStage;
#if BOX_MODE == BOX_MODE_RAINBOW
uniform float frameTimeCounter;
#endif
#endif

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"

const vec3 normal = vec3(0.0, 1.0, 0.0);

// gbuffers_basic is abused by mods for rendering overlays and the like, for now we mostly just
// want to reduce the intensity of these translucent overlays. This shader and vanilla are still
// both affected by Z-fighting in some areas, we could attempt to fix this in the vertex
// shader but this would require mods to send correct normals for their geometry which unfortunately
// doesn't happen often.
float fixup_translucent(float alpha) {
    return mix(alpha * 0.25, alpha, step(0.9, alpha));
}

void main() {
#if defined TAA && defined TAAU
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(coord) != coord) discard;
#endif
	// I have yet to see anything render something transparent but we assume it can happen.
	if (tint.a < 0.1)
		discard;

#if defined PROGRAM_GBUFFERS_LINE && BOX_MODE != BOX_MODE_NONE
	if (renderStage == MC_RENDER_STAGE_OUTLINE) {
#if BOX_MODE == BOX_MODE_COLOR
		vec3  col      = vec3(BOX_COLOR_R, BOX_COLOR_G, BOX_COLOR_B);
#else // BOX_MODE_RAINBOW
		vec2  uv       = gl_FragCoord.xy * view_pixel_size;
		vec3  col      = hsl_to_rgb(vec3(fract(uv.y + uv.x * uv.y + frameTimeCounter * 0.1), 1.0, 1.0));
#endif
		scene_color.rgb = srgb_eotf_inv(col * vec3(1.0 + BOX_EMISSION)) * rec709_to_working_color;
	} else // careful editing scene_color below
#endif
	scene_color.rgb = srgb_eotf_inv(tint.rgb) * rec709_to_working_color;

	// see note in function
	scene_color.a = fixup_translucent(tint.a);

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
