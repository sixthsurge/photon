/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffer/armor_glint.glsl:
  Handle enchantment glint

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;

uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform ivec2 atlasSize;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec2 taa_offset;
uniform vec3 light_dir;

#include "/include/utility/space_conversion.glsl"
#include "/include/vertex/displacement.glsl"

void main() {
	uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;

	vec3 pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	     pos = view_to_scene_space(pos);
	     pos = pos + cameraPosition;
	     pos = animate_vertex(pos, false, 1.0, 0);
	     pos = pos - cameraPosition;

	vec3 view_pos = scene_to_view_space(pos);
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

layout (location = 0) out vec3 colortex0_out;
layout (location = 1) out vec4 colortex3_out;

/* RENDERTARGETS: 0,3 */

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

	vec3 armor_glint = texture(gtexture, uv, lod_bias).rgb;

	colortex0_out = srgb_eotf_inv(armor_glint) * rec709_to_working_color;

	// Old overlay handling
	// alpha of 0 <=> enchantment glint
	colortex3_out.rgb = armor_glint;
	colortex3_out.a = 0.0 / 255.0;
}

#endif
//----------------------------------------------------------------------------//
