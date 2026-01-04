/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge
  Physics Mod Ocean Support

  world0/physics_ocean_shadow.vsh

--------------------------------------------------------------------------------
*/

#version 400 compatibility
#extension GL_ARB_shader_image_load_store : enable
#define WORLD_END
#define PROGRAM_SHADOW
#define PROGRAM_SHADOW_WATER
#define PHYSICS_OCEAN_SUPPORT
#define vsh

#include "/include/global.glsl"

out vec2 uv;
flat out uint material_mask;
flat out vec3 tint;

#ifdef WATER_CAUSTICS
out vec3 scene_pos;
#endif

attribute vec3 at_midBlock;
attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

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

// Physics Mod uniforms
uniform int physics_iterationsNormal;
uniform vec2 physics_waveOffset;
uniform ivec2 physics_textureOffset;
uniform float physics_gameTime;
uniform float physics_oceanHeight;
uniform float physics_oceanWaveHorizontalScale;
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

#include "/include/lighting/shadows/distortion.glsl"

void main() {
    uv            = gl_MultiTexCoord0.xy;
    material_mask = uint(mc_Entity.x - 10000.0);
    tint          = gl_Color.rgb;

#if defined WORLD_NETHER
    gl_Position = vec4(-1.0);
    return;
#endif

    // Physics Mod wave calculation
    float physics_localWaviness = texelFetch(physics_waviness, ivec2(gl_Vertex.xz) - physics_textureOffset, 0).r;
    
    vec4 physics_vertex = vec4(
        gl_Vertex.x,
        gl_Vertex.y + physics_waveHeight(gl_Vertex.xz, PHYSICS_ITERATIONS_OFFSET, physics_localWaviness, physics_gameTime),
        gl_Vertex.z,
        gl_Vertex.w
    );

    vec3 pos = transform(gl_ModelViewMatrix, physics_vertex.xyz);
    pos = transform(shadowModelViewInverse, pos);

    #ifdef WATER_CAUSTICS
    scene_pos = pos;
    #endif

    pos = transform(shadowModelView, pos);

    vec3 shadow_clip_pos = project_ortho(gl_ProjectionMatrix, pos);
    shadow_clip_pos = distort_shadow_space(shadow_clip_pos);

    gl_Position = vec4(shadow_clip_pos, 1.0);
}
