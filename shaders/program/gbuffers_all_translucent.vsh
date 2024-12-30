/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_all_translucent:
  Handle translucent terrain, translucent entities (Iris), translucent handheld
  items and gbuffers_textured

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;
out vec2 light_levels;
out vec3 position_view;
out vec3 position_scene;
out vec4 tint;

flat out vec3 light_color;
flat out vec3 ambient_color;
flat out uint material_mask;
flat out mat3 tbn;

#if defined PROGRAM_GBUFFERS_WATER
out vec2 atlas_tile_coord;
out vec3 position_tangent;
flat out vec2 atlas_tile_offset;
flat out vec2 atlas_tile_scale;
#endif

// --------------
//   Attributes
// --------------

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex4; // Sky map, lighting colors

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform ivec2 atlasSize;

uniform int frameCounter;
uniform int renderStage;
uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform vec3 light_dir;

#if defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT
uniform int entityId;
#endif

#if defined PROGRAM_GBUFFERS_BLOCK_TRANSLUCENT
uniform int blockEntityId;
#endif

#if (defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT || defined PROGRAM_GBUFFERS_HAND_WATER) && defined IS_IRIS
uniform int currentRenderedItemId;
#endif

#include "/include/utility/space_conversion.glsl"
#include "/include/vertex/displacement.glsl"
#include "/include/vertex/utility.glsl"

void main() {
	uv            = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;
	light_levels  = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	tint          = gl_Color;
	material_mask = get_material_mask();
	tbn           = get_tbn_matrix();

	light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
	ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;

	bool is_top_vertex = uv.y < mc_midTexCoord.y;

	position_scene = transform(gl_ModelViewMatrix, gl_Vertex.xyz);                            // To view space
	position_scene = view_to_scene_space(position_scene);                                          // To scene space
	position_scene = position_scene + cameraPosition;                                              // To world space
	position_scene = animate_vertex(position_scene, is_top_vertex, light_levels.y, material_mask); // Apply vertex animations
	position_scene = position_scene - cameraPosition;                                              // Back to scene space

#if defined PROGRAM_GBUFFERS_WATER
	tint.a = 1.0;

	if (material_mask == 62) {
		// Nether portal
		position_tangent = (position_scene - gbufferModelViewInverse[3].xyz) * tbn;

		// (from fayer3)
		vec2 uv_minus_mid = uv - mc_midTexCoord;
		atlas_tile_offset = min(uv, mc_midTexCoord - uv_minus_mid);
		atlas_tile_scale = abs(uv_minus_mid) * 2.0;
		atlas_tile_coord = sign(uv_minus_mid) * 0.5 + 0.5;
	}
#endif

#if defined PROGRAM_GBUFFERS_TEXTURED
	// Make world border emissive
	if (renderStage == MC_RENDER_STAGE_WORLD_BORDER) material_mask = 4;
#endif

#if defined PROGRAM_GBUFFERS_TEXTURED && !defined IS_IRIS
	// Make enderman/nether portal particles glow
	if (gl_Color.r > gl_Color.g && gl_Color.g < 0.6 && gl_Color.b > 0.4) material_mask = 47;
#endif

#if defined PROGRAM_GBUFFERS_WATER
	// Fix issue where the normal of the bottom of the water surface is flipped
	if (dot(position_scene, tbn[2]) > 0.0) tbn[2] = -tbn[2];
#endif

	position_view = scene_to_view_space(position_scene);
	vec4 position_clip = project(gl_ProjectionMatrix, position_view);

#if   defined TAA && defined TAAU
	position_clip.xy  = position_clip.xy * taau_render_scale + position_clip.w * (taau_render_scale - 1.0);
	position_clip.xy += taa_offset * position_clip.w;
#elif defined TAA
	position_clip.xy += taa_offset * position_clip.w * 0.66;
#endif

	gl_Position = position_clip;
}

