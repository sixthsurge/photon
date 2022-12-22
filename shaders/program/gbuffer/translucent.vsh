/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/translucent.fsh:
  Handle translucent terrain, translucent handheld items, water and particles

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;
out vec2 light_access;

flat out uint object_id;
flat out vec4 tint;
flat out mat3 tbn;

#ifdef POM
flat out vec2 atlas_tile_offset;
flat out vec2 atlas_tile_scale;
#endif

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float near;
uniform float far;

uniform vec2 taa_offset;

#include "/include/utility/space_conversion.glsl"

void main() {
	uv           = gl_MultiTexCoord0.xy;
	light_access = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	tint         = gl_Color;
	object_id    = uint(max0(mc_Entity.x - 10000.0));

	tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
#ifdef MC_NORMAL_MAP
	tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);
#endif

#ifdef PROGRAM_WATER
	tint.a = 1.0;
#endif

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
