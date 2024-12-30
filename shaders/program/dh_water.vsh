/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/dh_water:
  Translucent Distant Horizons terrain

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 light_levels;
out vec3 scene_pos;
out vec3 normal;
out vec4 tint;

flat out uint is_water;
flat out vec3 light_color;
flat out vec3 ambient_color;

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex4; // Sky map, lighting colors

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;

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

void main() {
	light_levels = linear_step(
        vec2(1.0 / 32.0),
        vec2(31.0 / 32.0),
        (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy
    );
	tint          = gl_Color;
    normal        = mat3(gbufferModelViewInverse) * (mat3(gl_ModelViewMatrix) * gl_Normal);
	light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
	ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;

	is_water = uint(dhMaterialId == DH_BLOCK_WATER);

    vec3 camera_offset = fract(cameraPosition);

    vec3 pos = gl_Vertex.xyz;
         pos = floor(pos + camera_offset + 0.5) - camera_offset;
         pos = transform(gl_ModelViewMatrix, pos);

    scene_pos = transform(gbufferModelViewInverse, pos);

    vec4 clip_pos = dhProjection * vec4(pos, 1.0);

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.66;
#endif

    gl_Position = clip_pos;
}

