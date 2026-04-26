/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge
  Physics Mod Ocean Support

  world0/physics_ocean.vsh

--------------------------------------------------------------------------------
*/

#version 400 compatibility
#define WORLD_END
#define PROGRAM_GBUFFERS_WATER
#define PHYSICS_OCEAN_SUPPORT
#define vsh

#include "/include/global.glsl"

out vec2 uv;
out vec2 light_levels;
out vec3 position_view;
out vec3 position_scene;
out vec4 tint;

flat out vec3 light_color;
flat out vec3 ambient_color;
flat out uint material_mask;
out mat3 tbn;

out vec2 atlas_tile_coord;
out vec3 position_tangent;
flat out vec2 atlas_tile_offset;
flat out vec2 atlas_tile_scale;

out vec3 physics_localPosition;
out float physics_localWaviness;

#if defined WORLD_END
#include "/include/fog/overworld/parameters.glsl"
flat out OverworldFogParameters fog_params;
#endif

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

uniform sampler2D noisetex;
uniform sampler2D colortex4;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;
uniform float near;
uniform float far;
uniform ivec2 atlasSize;
uniform int renderStage;
uniform int worldTime;
uniform int worldDay;
uniform int frameCounter;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;
uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;
uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform float eye_skylight;

uniform float biome_temperate;
uniform float biome_arid;
uniform float biome_snowy;
uniform float biome_taiga;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_may_rain;
uniform float biome_may_snow;
uniform float biome_temperature;
uniform float biome_humidity;
uniform float world_age;
uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;
uniform float desert_sandstorm;

// Physics Mod uniforms
uniform int physics_iterationsNormal;
uniform vec2 physics_waveOffset;
uniform ivec2 physics_textureOffset;
uniform float physics_gameTime;
uniform float physics_oceanHeight;
uniform float physics_oceanWaveHorizontalScale;
uniform vec3 physics_modelOffset;
uniform sampler2D physics_waviness;

// Physics Mod constants
const int PHYSICS_ITERATIONS_OFFSET = 13;
const float PHYSICS_DRAG_MULT = 0.048;
const float PHYSICS_XZ_SCALE = 0.035;
const float PHYSICS_TIME_MULTIPLICATOR = 0.45;
const float PHYSICS_FREQUENCY = 6.0;
const float PHYSICS_SPEED = 2.0;
const float PHYSICS_WEIGHT = 0.8;
const float PHYSICS_FREQUENCY_MULT = 1.18;
const float PHYSICS_SPEED_MULT = 1.07;
const float PHYSICS_ITER_INC = 12.0;

float physics_waveHeight(vec2 position, int iterations, float factor, float time) {
    position = (position - physics_waveOffset) * PHYSICS_XZ_SCALE * physics_oceanWaveHorizontalScale;
    float iter = 0.0;
    float frequency = PHYSICS_FREQUENCY;
    float speed = PHYSICS_SPEED;
    float weight = 1.0;
    float height = 0.0;
    float waveSum = 0.0;
    float modifiedTime = time * PHYSICS_TIME_MULTIPLICATOR;
    
    for (int i = 0; i < iterations; i++) {
        vec2 direction = vec2(sin(iter), cos(iter));
        float x = dot(direction, position) * frequency + modifiedTime * speed;
        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
        vec2 force = result * weight * direction;
        
        position -= force * PHYSICS_DRAG_MULT;
        height += wave * weight;
        iter += PHYSICS_ITER_INC;
        waveSum += weight;
        weight *= PHYSICS_WEIGHT;
        frequency *= PHYSICS_FREQUENCY_MULT;
        speed *= PHYSICS_SPEED_MULT;
    }
    
    return height / waveSum * physics_oceanHeight * factor - physics_oceanHeight * factor * 0.5;
}

#include "/include/misc/material_masks.glsl"
#include "/include/utility/space_conversion.glsl"
#include "/include/vertex/displacement.glsl"

#if defined WORLD_END
#include "/include/weather/fog.glsl"
#endif

uint get_material_mask_physics() {
    return uint(max(0.0, mc_Entity.x - 10000.0));
}

mat3 get_tbn_matrix_physics() {
    mat3 tbn_matrix;
    tbn_matrix[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
    tbn_matrix[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
    tbn_matrix[1] = cross(tbn_matrix[0], tbn_matrix[2]) * sign(at_tangent.w);
    return tbn_matrix;
}

void main() {
    uv            = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;
    light_levels  = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
    tint          = gl_Color;
    material_mask = get_material_mask_physics();
    tbn           = get_tbn_matrix_physics();

    light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
#if defined WORLD_END && defined SH_SKYLIGHT
    ambient_color = texelFetch(colortex4, ivec2(191, 11), 0).rgb;
#else
    ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;
#endif

    // Physics Mod wave calculation
    physics_localWaviness = texelFetch(physics_waviness, ivec2(gl_Vertex.xz) - physics_textureOffset, 0).r;
    
    vec4 physics_vertex = vec4(
        gl_Vertex.x,
        gl_Vertex.y + physics_waveHeight(gl_Vertex.xz, PHYSICS_ITERATIONS_OFFSET, physics_localWaviness, physics_gameTime),
        gl_Vertex.z,
        gl_Vertex.w
    );
    
    physics_localPosition = physics_vertex.xyz;

    bool is_top_vertex = uv.y < mc_midTexCoord.y;

    position_scene = transform(gl_ModelViewMatrix, physics_vertex.xyz);
    position_scene = view_to_scene_space(position_scene);
    position_scene = position_scene + cameraPosition;
    position_scene = position_scene - cameraPosition;

    tint.a = 1.0;

    if (material_mask == 62u) {
        position_tangent = (position_scene - gbufferModelViewInverse[3].xyz) * tbn;
        vec2 uv_minus_mid = uv - mc_midTexCoord;
        atlas_tile_offset = min(uv, mc_midTexCoord - uv_minus_mid);
        atlas_tile_scale = abs(uv_minus_mid) * 2.0;
        atlas_tile_coord = sign(uv_minus_mid) * 0.5 + 0.5;
    }

    if (dot(position_scene, tbn[2]) > 0.0) tbn[2] = -tbn[2];

#if defined WORLD_END
    fog_params = get_fog_parameters(get_weather());
#endif

    position_view = scene_to_view_space(position_scene);
    vec4 position_clip = project(gl_ProjectionMatrix, position_view);

#if defined TAA && defined TAAU
    position_clip.xy  = position_clip.xy * taau_render_scale + position_clip.w * (taau_render_scale - 1.0);
    position_clip.xy += taa_offset * position_clip.w;
#elif defined TAA
    position_clip.xy += taa_offset * position_clip.w * 0.66;
#endif

    gl_Position = position_clip;
}
