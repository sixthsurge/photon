/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffer/damage_overlay.glsl:
  Handle block breaking overlay

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;

uniform vec2 taa_offset;
uniform vec2 view_pixel_size;

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
#if defined fsh

layout (location = 0) out vec4 damage_overlay;

#ifdef IS_IRIS
/* RENDERTARGETS: 0 */
#else
/* RENDERTARGETS: 3 */
#endif

in vec2 uv;

// ------------
//   Uniforms
// ------------

uniform sampler2D gtexture;

uniform vec2 taa_offset;
uniform vec2 view_pixel_size;

const float lod_bias = log2(taau_render_scale);

#include "/include/utility/color.glsl"

void main() {
#if defined TAA && defined TAAU
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(coord) != coord) discard;
#endif

	damage_overlay = texture(gtexture, uv, lod_bias);
	if (damage_overlay.a < 0.1) discard;

#ifdef IS_IRIS
	damage_overlay.rgb = 0.5 * srgb_eotf_inv(2.0 * damage_overlay.rgb) * rec709_to_rec2020;
	damage_overlay.a   = 1.0;
#else
	// Old overlay handling
	// alpha of 1 <=> block breaking overlay
	damage_overlay.a = 1.0 / 255.0;
#endif
}

#endif
//----------------------------------------------------------------------------//
