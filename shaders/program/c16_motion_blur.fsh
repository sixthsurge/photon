/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge (Enhanced)

  program/c16_motion_blur:
  Apply motion blur with quality improvements

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 scene_color;

/* RENDERTARGETS: 0 */

in vec2 uv;

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex0; // Scene color

uniform sampler2D depthtex0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float frameTime;
uniform float near;
uniform float far;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

#define TEMPORAL_REPROJECTION
#include "/include/utility/space_conversion.glsl"

#define MOTION_BLUR_SAMPLES 24
#define MOTION_BLUR_MAX_VELOCITY 0.02
#define MOTION_BLUR_DEPTH_THRESHOLD 0.01

float interleavedGradientNoise(vec2 coord) {
    const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(coord, magic.xy)));
}

vec2 calculateVelocity(vec2 coord, float depth) {
    vec2 velocity = coord - reproject(vec3(coord, depth)).xy;
    float velocity_length = length(velocity);
    if (velocity_length > MOTION_BLUR_MAX_VELOCITY) {
        velocity = normalize(velocity) * MOTION_BLUR_MAX_VELOCITY;
    }
    
    return velocity;
}

float calculateDepthWeight(float sample_depth, float center_depth) {
    float depth_diff = abs(sample_depth - center_depth);
    return exp(-depth_diff * depth_diff / (MOTION_BLUR_DEPTH_THRESHOLD * MOTION_BLUR_DEPTH_THRESHOLD));
}

float gaussianWeight(float x, float sigma) {
    return exp(-0.5 * x * x / (sigma * sigma));
}

void main() {
    ivec2 texel      = ivec2(gl_FragCoord.xy);
    ivec2 view_texel = ivec2(gl_FragCoord.xy * taau_render_scale);

    float center_depth = texelFetch(depthtex0, view_texel, 0).x;

    if (center_depth < hand_depth) {
        scene_color = texelFetch(colortex0, texel, 0).rgb;
        return;
    }

    vec2 velocity = calculateVelocity(uv, center_depth);
    float velocity_length = length(velocity);

    if (velocity_length < 0.0001) {
        scene_color = texelFetch(colortex0, texel, 0).rgb;
        return;
    }

    int samples = int(mix(8, MOTION_BLUR_SAMPLES, clamp(velocity_length * 100.0, 0.0, 1.0)));

    float jitter = interleavedGradientNoise(gl_FragCoord.xy) - 0.5;
    
    vec2 increment = (MOTION_BLUR_INTENSITY / float(samples)) * velocity;
    vec2 start_pos = uv - 0.5 * increment * float(samples) + jitter * increment;

    vec3 color_sum = vec3(0.0);
    float weight_sum = 0.0;

    for (int i = 0; i < samples; ++i) {
        vec2 sample_pos = start_pos + increment * float(i);

        if (any(lessThan(sample_pos, vec2(0.0))) || any(greaterThan(sample_pos, vec2(1.0)))) {
            continue;
        }
        
        ivec2 tap      = ivec2(sample_pos * view_res);
        ivec2 view_tap = ivec2(sample_pos * view_res * taau_render_scale);

        vec3 color = texelFetch(colortex0, tap, 0).rgb;
        float sample_depth = texelFetch(depthtex0, view_tap, 0).x;

        if (sample_depth < hand_depth) {
            continue;
        }

        float depth_weight = calculateDepthWeight(sample_depth, center_depth);
        float gaussian_weight = gaussianWeight(float(i) - float(samples) * 0.5, float(samples) * 0.3);
        float total_weight = depth_weight * gaussian_weight;

        color_sum += color * total_weight;
        weight_sum += total_weight;
    }

    if (weight_sum < 0.001) {
        scene_color = texelFetch(colortex0, texel, 0).rgb;
    } else {
        scene_color = color_sum / weight_sum;
    }
}