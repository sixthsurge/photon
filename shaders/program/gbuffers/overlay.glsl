/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffers/overlay.glsl:
  Handle animated overlays (block breaking overlay and enchantment glint)

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

varying vec2 uv;

// ------------
//   uniforms
// ------------

uniform sampler2D gtexture;

uniform vec2 taa_offset;
uniform vec2 view_pixel_size;


//----------------------------------------------------------------------------//
#if defined STAGE_VERTEX

void main() {
	uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;

	vec3 view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
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
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined STAGE_FRAGMENT

layout (location = 0) out vec4 overlays;

/* DRAWBUFFERS:3 */

const float lod_bias = log2(taau_render_scale);

void main() {
#if defined TAA && defined TAAU
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(coord) != coord) discard;
#endif

	overlays = texture(gtexture, uv, lod_bias);
	if (overlays.a < 0.1) discard;

#if   defined PROGRAM_GBUFFERS_ARMOR_GLINT
	// alpha of 0 <=> enchantment glint
	overlays.a = 0.0 / 255.0;
#elif defined PROGRAM_GBUFFERS_DAMAGEDBLOCK
	// alpha of 1 <=> block breaking overlay
	overlays.a = 1.0 / 255.0;
#endif
}

#endif
//----------------------------------------------------------------------------//
