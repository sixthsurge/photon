/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge
  Physics Mod Ocean Support

  world0/physics_ocean.fsh

--------------------------------------------------------------------------------
*/

#version 400 compatibility
#define WORLD_OVERWORLD
#define PROGRAM_GBUFFERS_WATER
#define PHYSICS_OCEAN_SUPPORT
#define fsh

#include "/include/global.glsl"

layout (location = 0) out vec4 refraction_data;
layout (location = 1) out vec4 fragment_color;

/* RENDERTARGETS: 3,13 */

in vec2 uv;
in vec2 light_levels;
in vec3 position_view;
in vec3 position_scene;
in vec4 tint;

flat in vec3 light_color;
flat in vec3 ambient_color;
flat in uint material_mask;
in mat3 tbn;

in vec2 atlas_tile_coord;
in vec3 position_tangent;
flat in vec2 atlas_tile_offset;
flat in vec2 atlas_tile_scale;

in vec3 physics_localPosition;
in float physics_localWaviness;

#if defined WORLD_OVERWORLD
#include "/include/fog/overworld/parameters.glsl"
flat in OverworldFogParameters fog_params;
#endif

uniform sampler2D noisetex;
uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex7;

#ifdef CLOUD_SHADOWS
uniform sampler2D colortex8;
#endif

uniform sampler2D depthtex1;

#ifdef COLORED_LIGHTS
uniform sampler3D light_sampler_a;
uniform sampler3D light_sampler_b;
#endif

#ifdef SHADOW
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;

uniform int worldTime;
uniform int moonPhase;
uniform int frameCounter;
uniform int isEyeInWater;

uniform float blindness;
uniform float nightVision;
uniform float darknessFactor;
uniform float eyeAltitude;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float eye_skylight;
uniform float biome_cave;
uniform float biome_may_rain;
uniform float biome_may_snow;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

// Physics Mod uniforms
uniform int physics_iterationsNormal;
uniform vec2 physics_waveOffset;
uniform ivec2 physics_textureOffset;
uniform float physics_gameTime;
uniform float physics_globalTime;
uniform float physics_oceanHeight;
uniform float physics_oceanWaveHorizontalScale;
uniform vec3 physics_modelOffset;
uniform float physics_rippleRange;
uniform float physics_foamAmount;
uniform float physics_foamOpacity;
uniform sampler2D physics_waviness;
uniform sampler2D physics_ripples;
uniform sampler3D physics_foam;

// Physics Mod constants
const float PHYSICS_NORMAL_STRENGTH = 1.4;
const float PHYSICS_XZ_SCALE = 0.035;
const float PHYSICS_TIME_MULTIPLICATOR = 0.45;
const float PHYSICS_W_DETAIL = 0.75;
const float PHYSICS_FREQUENCY = 6.0;
const float PHYSICS_SPEED = 2.0;
const float PHYSICS_WEIGHT = 0.8;
const float PHYSICS_FREQUENCY_MULT = 1.18;
const float PHYSICS_SPEED_MULT = 1.07;
const float PHYSICS_ITER_INC = 12.0;
const float PHYSICS_DRAG_MULT = 0.048;

vec3 physics_waveNormal(const in vec2 position, const in vec2 direction, const in float factor, const in float time) {
    float oceanHeightFactor = physics_oceanHeight / 13.0;
    float totalFactor = oceanHeightFactor * factor;
    vec3 waveNormal = normalize(vec3(direction.x * totalFactor, PHYSICS_NORMAL_STRENGTH, direction.y * totalFactor));
    
    vec2 eyePosition = position + physics_modelOffset.xz;
    vec2 rippleFetch = (eyePosition + vec2(physics_rippleRange)) / (physics_rippleRange * 2.0);
    vec2 rippleTexelSize = vec2(2.0 / textureSize(physics_ripples, 0).x, 0.0);
    float left = texture(physics_ripples, rippleFetch - rippleTexelSize.xy).r;
    float right = texture(physics_ripples, rippleFetch + rippleTexelSize.xy).r;
    float top = texture(physics_ripples, rippleFetch - rippleTexelSize.yx).r;
    float bottom = texture(physics_ripples, rippleFetch + rippleTexelSize.yx).r;
    float totalEffect = left + right + top + bottom;
    
    float normalx = left - right;
    float normalz = top - bottom;
    vec3 rippleNormal = normalize(vec3(normalx, 1.0, normalz));
    return normalize(mix(waveNormal, rippleNormal, pow(totalEffect, 0.5)));
}

struct WavePixelData {
    vec2 direction;
    vec2 worldPos;
    vec3 normal;
    float foam;
    float height;
};

WavePixelData physics_wavePixel(const in vec2 position, const in float factor, const in float iterations, const in float time) {
    vec2 wavePos = (position.xy - physics_waveOffset) * PHYSICS_XZ_SCALE * physics_oceanWaveHorizontalScale;
    float iter = 0.0;
    float frequency = PHYSICS_FREQUENCY;
    float speed = PHYSICS_SPEED;
    float weight = 1.0;
    float height = 0.0;
    float waveSum = 0.0;
    float modifiedTime = time * PHYSICS_TIME_MULTIPLICATOR;
    vec2 dx = vec2(0.0);
    
    for (int i = 0; i < int(iterations); i++) {
        vec2 direction = vec2(sin(iter), cos(iter));
        float x = dot(direction, wavePos) * frequency + modifiedTime * speed;
        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
        vec2 force = result * weight * direction;
        
        dx += force / pow(weight, PHYSICS_W_DETAIL);
        wavePos -= force * PHYSICS_DRAG_MULT;
        height += wave * weight;
        iter += PHYSICS_ITER_INC;
        waveSum += weight;
        weight *= PHYSICS_WEIGHT;
        frequency *= PHYSICS_FREQUENCY_MULT;
        speed *= PHYSICS_SPEED_MULT;
    }
    
    WavePixelData data;
    data.direction = -vec2(dx / pow(waveSum, 1.0 - PHYSICS_W_DETAIL));
    data.worldPos = wavePos / physics_oceanWaveHorizontalScale / PHYSICS_XZ_SCALE;
    data.height = height / waveSum * physics_oceanHeight * factor - physics_oceanHeight * factor * 0.5;
    
    data.normal = physics_waveNormal(position, data.direction, factor, time);

    float waveAmplitude = data.height * pow(max(data.normal.y, 0.0), 4.0);
    vec2 waterUV = mix(position - physics_waveOffset, data.worldPos, clamp(factor * 2.0, 0.2, 1.0));
    
    vec2 s1 = textureLod(physics_foam, vec3(waterUV * 0.26, physics_globalTime / 360.0), 0).rg;
    vec2 s2 = textureLod(physics_foam, vec3(waterUV * 0.02, physics_globalTime / 360.0 + 0.5), 0).rg;
    vec2 s3 = textureLod(physics_foam, vec3(waterUV * 0.1, physics_globalTime / 360.0 + 1.0), 0).rg;
    
    float waterSurfaceNoise = s1.r * s2.r * s3.r * 2.8 * physics_foamAmount;
    waveAmplitude = clamp(waveAmplitude * 1.2, 0.0, 1.0);
    waterSurfaceNoise = (1.0 - waveAmplitude) * waterSurfaceNoise + waveAmplitude * physics_foamAmount;
    
    float worleyNoise = 0.2 + 0.8 * s1.g * (1.0 - s2.g);
    float waterFoamMinSmooth = 0.45;
    float waterFoamMaxSmooth = 2.0;
    waterSurfaceNoise = smoothstep(waterFoamMinSmooth, 1.0, waterSurfaceNoise) * worleyNoise;
    
    data.foam = clamp(waterFoamMaxSmooth * waterSurfaceNoise * physics_foamOpacity, 0.0, 1.0);
    
    return data;
}

#define TEMPORAL_REPROJECTION

#ifdef SHADOW_COLOR
    #undef SHADOW_COLOR
#endif

#ifdef DIRECTIONAL_LIGHTMAPS
#include "/include/lighting/directional_lightmaps.glsl"
#endif

#include "/include/fog/simple_fog.glsl"
#include "/include/lighting/diffuse_lighting.glsl"
#include "/include/lighting/shadows/sampling.glsl"
#include "/include/lighting/specular_lighting.glsl"
#include "/include/misc/distant_horizons.glsl"
#include "/include/surface/material.glsl"
#include "/include/misc/material_masks.glsl"
#include "/include/misc/purkinje_shift.glsl"
#include "/include/surface/water_normal.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/space_conversion.glsl"

#ifdef CLOUD_SHADOWS
#include "/include/lighting/cloud_shadows.glsl"
#endif

const float lod_bias = log2(taau_render_scale);

Material get_water_material_physics(vec3 direction_world, vec3 normal, float layer_dist, float foam, out float alpha) {
    Material material = water_material;
    alpha = 0.01;

#if WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT || WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT_UNDERGROUND
    vec4 base_color = texture(gtexture, uv, lod_bias);
    float texture_highlight = dampen(0.5 * sqr(linear_step(0.63, 1.0, base_color.r)) + 0.03 * base_color.r);
#if WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT_UNDERGROUND
    texture_highlight *= 1.0 - cube(linear_step(0.0, 0.5, light_levels.y));
#endif
    material.albedo = clamp01(0.5 * exp(-2.0 * water_absorption_coeff) * texture_highlight);
    material.roughness += 0.3 * texture_highlight;
    alpha += texture_highlight;
#elif WATER_TEXTURE == WATER_TEXTURE_VANILLA
    vec4 base_color = texture(gtexture, uv, lod_bias) * tint;
    material.albedo = srgb_eotf_inv(base_color.rgb * base_color.a) * rec709_to_working_color;
    alpha = base_color.a;
#endif

    // Physics Mod foam
    material.albedo = mix(material.albedo, vec3(1.0), foam * 0.8);
    alpha = max(alpha, foam);

#ifdef WATER_EDGE_HIGHLIGHT
    float dist = layer_dist * max(abs(direction_world.y), eps);
#if WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT || WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT_UNDERGROUND
    float edge_highlight = cube(max0(1.0 - 2.0 * dist)) * (1.0 + 8.0 * texture_highlight);
#else
    float edge_highlight = cube(max0(1.0 - 2.0 * dist));
#endif
    edge_highlight *= WATER_EDGE_HIGHLIGHT_INTENSITY * max0(normal.y) * (1.0 - 0.5 * sqr(light_levels.y));
    material.albedo += 0.1 * edge_highlight / mix(1.0, max(dot(ambient_color, luminance_weights_rec2020), 0.5), light_levels.y);
    material.albedo = clamp01(material.albedo);
    alpha += edge_highlight;
#endif

    return material;
}

vec4 water_absorption_approx_physics(vec4 color, float sss_depth, float layer_dist, float LoV, float NoV, float cloud_shadows) {
    vec3 biome_water_color = srgb_eotf_inv(tint.rgb) * rec709_to_working_color;
    vec3 absorption_coeff = biome_water_coeff(biome_water_color);
    float dist = layer_dist * float(isEyeInWater != 1 || NoV >= 0.0);

    mat2x3 water_fog = water_fog_simple(light_color * cloud_shadows, ambient_color, absorption_coeff, light_levels, dist, -LoV, sss_depth);

    float brightness_control = 1.0 - exp(-0.33 * layer_dist);
    brightness_control = (1.0 - light_levels.y) + brightness_control * light_levels.y;

    return vec4(color.rgb + water_fog[0] * (1.0 + 6.0 * sqr(water_fog[1])) * brightness_control, 1.0 - water_fog[1].x);
}

void main() {
    vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);

#if defined TAA && defined TAAU
    if (clamp01(coord) != coord) discard;
#endif

    // Physics Mod wave calculation
    WavePixelData wave = physics_wavePixel(physics_localPosition.xz, physics_localWaviness, float(physics_iterationsNormal), physics_gameTime);
    
    vec3 physics_normal = wave.normal;
    if (!gl_FrontFacing) physics_normal = -physics_normal;

    float depth0 = gl_FragCoord.z;
    float depth1 = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).x;

    vec3 world_pos = position_scene + cameraPosition;
    vec3 direction_world = normalize(position_scene - gbufferModelViewInverse[3].xyz);

    vec3 view_back_pos = screen_to_view_space(vec3(coord, depth1), true);

#ifdef DISTANT_HORIZONS
    float depth1_dh = texelFetch(dhDepthTex1, ivec2(gl_FragCoord.xy), 0).x;
    if (is_distant_horizons_terrain(depth1, depth1_dh)) {
        view_back_pos = screen_to_view_space(vec3(coord, depth1_dh), true, true);
    }
#endif

    vec3 scene_back_pos = view_to_scene_space(view_back_pos);
    float layer_dist = distance(position_scene, scene_back_pos);

    Material material;
    vec3 normal = physics_normal;
    vec3 normal_tangent = vec3(physics_normal.x, physics_normal.z, physics_normal.y);

    bool is_water = material_mask == MATERIAL_WATER;
    vec2 adjusted_light_levels = light_levels;

    if (is_water) {
        material = get_water_material_physics(direction_world, normal, layer_dist, wave.foam, fragment_color.a);
    } else {
        fragment_color = texture(gtexture, uv, lod_bias) * tint;
        if (fragment_color.a < 0.1) { discard; return; }
        material = material_from(fragment_color.rgb, material_mask, world_pos, tbn[2], adjusted_light_levels);
    }

    float NoL = dot(normal, light_dir);
    float NoV = clamp01(dot(normal, -direction_world));
    float LoV = dot(light_dir, -direction_world);
    float halfway_norm = inversesqrt(2.0 * LoV + 2.0);
    float NoH = (NoL + NoV) * halfway_norm;
    float LoH = LoV * halfway_norm + halfway_norm;

#if defined WORLD_OVERWORLD && defined CLOUD_SHADOWS
    float cloud_shadows = get_cloud_shadows(colortex8, position_scene);
#else
    #define cloud_shadows 1.0
#endif

#if defined SHADOW && defined WORLD_OVERWORLD
    float sss_depth;
    float shadow_distance_fade;
    vec3 shadows = calculate_shadows(position_scene, tbn[2], adjusted_light_levels.y, cloud_shadows, material.sss_amount, shadow_distance_fade, sss_depth);
#else
    #define sss_depth 0.0
    #define shadow_distance_fade 0.0
    vec3 shadows = vec3(pow8(adjusted_light_levels.y));
#endif

    fragment_color.rgb = get_diffuse_lighting(
        material, position_scene, normal, tbn[2], tbn[2], shadows, adjusted_light_levels, 1.0, 0.0, sss_depth,
#ifdef CLOUD_SHADOWS
        cloud_shadows,
#endif
        shadow_distance_fade, NoL, NoV, NoH, LoV
    ) * fragment_color.a;

#if defined WORLD_OVERWORLD
    fragment_color.rgb += get_specular_highlight(material, NoL, NoV, NoH, LoV, LoH) * light_color * shadows * cloud_shadows;
#endif

#if defined ENVIRONMENT_REFLECTIONS || defined SKY_REFLECTIONS
    if (material.ssr_multiplier > eps) {
        vec3 position_screen = vec3(gl_FragCoord.xy * rcp(taau_render_scale) * view_pixel_size, gl_FragCoord.z);
        mat3 new_tbn = get_tbn_matrix(normal);
        fragment_color.rgb += get_specular_reflections(material, new_tbn, position_screen, position_view, world_pos, normal, tbn[2], direction_world, direction_world * new_tbn, light_levels.y, is_water);
    }
#endif

    if (is_water) {
        fragment_color = water_absorption_approx_physics(fragment_color, sss_depth, layer_dist, LoV, dot(tbn[2], direction_world), cloud_shadows);

#ifdef SNELLS_WINDOW
        if (isEyeInWater == 1) {
            fragment_color.a = mix(fragment_color.a, 1.0, fresnel_dielectric_n(NoV, air_n / water_n).x);
        }
#endif
    }

    vec4 fog = common_fog(length(position_scene), false);
    fragment_color.rgb = fragment_color.rgb * fog.a + fog.rgb;
    fragment_color.rgb = purkinje_shift(fragment_color.rgb, adjusted_light_levels);

    refraction_data.xy = split_2x8(normal_tangent.x * 0.5 + 0.5);
    refraction_data.zw = split_2x8(normal_tangent.y * 0.5 + 0.5);
}
