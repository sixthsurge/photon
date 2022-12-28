/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffer/solid.vsh:
  Handle terrain, entities, the hand, beacon beams and spider eyes

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

#ifdef PROGRAM_TERRAIN
out float vertex_ao;
#endif

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec2 taa_offset;

#ifdef PROGRAM_ENTITIES
uniform int entityId;
#endif

#ifdef PROGRAM_BLOCK
uniform int blockEntityId;
#endif

#ifdef PROGRAM_HAND
uniform int heldItemId;
uniform int heldItemId2;
#endif

#include "/include/utility/space_conversion.glsl"

#include "/include/wind_animation.glsl"

void main() {
	uv           = gl_MultiTexCoord0.xy;
	light_access = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	tint         = gl_Color;
	object_id    = uint(max0(mc_Entity.x - 10000.0));

#if defined PROGRAM_ENTITIES
	object_id = uint(max(entityId - 10000, 0));
#endif

#if defined PROGRAM_BLOCK
	object_id = uint(max(blockEntityId - 10000, 0));
#endif

	tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
#ifdef NORMAL_MAPPING
	tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);
#endif

#ifdef PROGRAM_TERRAIN
	vertex_ao = gl_Color.a < 0.1 ? 1.0 : gl_Color.a; // fixes models where vanilla ao breaks (eg lecterns)
	tint.a = 1.0;
#endif

#ifdef PROGRAM_SPIDEREYES
	object_id = 2; // full emissive
	light_access.x = 1.0;
#endif

	vec3 view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
#if defined PROGRAM_TERRAIN
	bool is_top_vertex = uv.y < mc_midTexCoord.y;
	vec3 scene_pos = view_to_scene_space(view_pos);
	scene_pos += animate_vertex(scene_pos + cameraPosition, is_top_vertex, light_access.y, object_id);
    view_pos = scene_to_view_space(scene_pos);
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
