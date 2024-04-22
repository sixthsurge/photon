/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffer/distant_horizons/terrain.glsl:
  Distant Horizons terrain

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 light_levels;
out vec3 scene_pos;
out vec3 normal;
out vec3 color;

flat out uint material_mask;

// ------------
//   Uniforms
// ------------

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 dhProjection;
uniform vec3 cameraPosition;
uniform vec2 taa_offset;

void main() {
	light_levels = linear_step(
        vec2(1.0 / 32.0),
        vec2(31.0 / 32.0),
        (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy
    );
    color        = gl_Color.rgb;
    normal       = mat3(gbufferModelViewInverse) * (mat3(gl_ModelViewMatrix) * gl_Normal);

// Prevent compile error on older versions of Iris
#ifndef DH_BLOCK_GRASS
#define DH_BLOCK_GRASS 13
#endif

    // Set material mask based on dhMaterialId
    switch (dhMaterialId) {
    case DH_BLOCK_LEAVES:
        material_mask = 5; // Leaves
        break;

    case DH_BLOCK_GRASS:
    case DH_BLOCK_DIRT:
    case DH_BLOCK_STONE:
    case DH_BLOCK_DEEPSLATE:
    case DH_BLOCK_NETHER_STONE:
        material_mask = 6; // Dirts, stones, deepslate and netherrack
        break;

    case DH_BLOCK_SAND:
        if (color.r > color.b * 2.0) material_mask = 9; // Red sand
        else material_mask = 7; // Sand
        break;

    case DH_BLOCK_WOOD:
        material_mask = 10; // Woods
        break;

    case DH_BLOCK_METAL:
        material_mask = 12; // Metals
        break;

    case DH_BLOCK_LAVA:
        material_mask = 39; // Lava
        break;

    case DH_BLOCK_ILLUMINATED:
        material_mask = 36; // Other light sources
        break;

    default:
        material_mask = 0;
        break;
    }

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

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec4 gbuffer_data_0; // albedo, block ID, flat normal, light levels

/* RENDERTARGETS: 1 */

#ifdef NORMAL_MAPPING
/* RENDERTARGETS: 1,2 */
#endif

#ifdef SPECULAR_MAPPING
/* RENDERTARGETS: 1,2 */
#endif

in vec2 light_levels;
in vec3 scene_pos;
in vec3 normal;
in vec3 color;

flat in uint material_mask;

#include "/include/utility/encoding.glsl"

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform vec3 cameraPosition;
uniform float far;

mat3 get_tbn_matrix(vec3 normal) {
	vec3 tangent = normal.y == 1.0 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), normal));
	vec3 bitangent = normalize(cross(tangent, normal));
	return mat3(tangent, bitangent, normal);
}

void main() {
    // Clip close-by DH terrain
    if (length(scene_pos) < 0.8 * far) {
        discard;
        return;
    }

#ifdef NOISE_ON_DH_TERRAIN
    mat3 tbn = get_tbn_matrix(normal);
    vec3 world_pos = scene_pos + cameraPosition;
    vec2 noise_pos = (world_pos * tbn).xy;

    float noise = texture(noisetex, noise_pos.xy * 0.2).x;
    vec3 adjusted_color = clamp01(color * (noise * 0.25 + 0.85));
#else
    vec3 adjusted_color = color;
#endif

	gbuffer_data_0.x  = pack_unorm_2x8(adjusted_color.rg);
	gbuffer_data_0.y  = pack_unorm_2x8(adjusted_color.b, clamp01(float(material_mask) * rcp(255.0)));
	gbuffer_data_0.z  = pack_unorm_2x8(encode_unit_vector(normal));
	gbuffer_data_0.w  = pack_unorm_2x8(light_levels);
}

#endif
//----------------------------------------------------------------------------//
