/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/shadow:
  Render shadow map

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out uint material_mask;
flat out vec3 tint;

#ifdef WATER_CAUSTICS
out vec3 scene_pos;
#endif

// --------------
//   Attributes
// --------------

attribute vec3 at_midBlock;
attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

// ------------
//   Uniforms
// ------------

uniform sampler2D tex;
uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;

uniform vec2 taa_offset;
uniform vec3 light_dir;

uniform float world_age;
uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;
uniform float biome_temperature;
uniform float biome_humidity;

#ifdef COLORED_LIGHTS
writeonly uniform uimage3D voxel_img;

uniform int renderStage;
#endif

// ------------
//   Includes
// ------------

#include "/include/lighting/shadows/distortion.glsl"
#include "/include/vertex/displacement.glsl"

#ifdef COLORED_LIGHTS
#include "/include/lighting/lpv/voxelization.glsl"
#endif

void main() {
	uv            = gl_MultiTexCoord0.xy;
	material_mask = uint(mc_Entity.x - 10000.0);
	tint          = gl_Color.rgb;

#if defined COLORED_LIGHTS && !defined PROGRAM_SHADOW_ENTITIES
	update_voxel_map(material_mask);
#endif

#if defined WORLD_NETHER
	// No shadows, discard vertices now
	gl_Position = vec4(-1.0);
	return;
#endif

	bool is_top_vertex = uv.y < mc_midTexCoord.y;

	vec3 pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

#if !defined PROGRAM_SHADOW_ENTITIES
	// Animations
	pos = transform(shadowModelViewInverse, pos);
	pos = pos + cameraPosition;
	pos = animate_vertex(pos, is_top_vertex, clamp01(rcp(240.0) * gl_MultiTexCoord1.y), material_mask);
	pos = pos - cameraPosition;

	#ifdef WATER_CAUSTICS
	scene_pos = pos;
	#endif

	pos = transform(shadowModelView, pos);;
#endif

	vec3 shadow_clip_pos = project_ortho(gl_ProjectionMatrix, pos);
	     shadow_clip_pos = distort_shadow_space(shadow_clip_pos);

	gl_Position = vec4(shadow_clip_pos, 1.0);
}
