#define INFO 0 // [0 1]

#include "/include/global.glsl"
#include "/include/pipeline.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec3 fragColor;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

#if DEBUG_VIEW == DEBUG_VIEW_SAMPLER
uniform sampler2D DEBUG_SAMPLER;
#else
uniform sampler2D colortex2; // Post-processing color
#endif

uniform float blindness;
uniform float biomeCave;

//--// Includes //------------------------------------------------------------//

#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"

//--// Functions //-----------------------------------------------------------//

vec3 minOf(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return min(a, min(b, min(c, min(d, f))));
}

vec3 maxOf(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return max(a, max(b, max(c, max(d, f))));
}

// FidelityFX contrast-adaptive sharpening filter
// https://github.com/GPUOpen-Effects/FidelityFX-CAS
vec3 textureCas(sampler2D sampler, ivec2 texel, const float sharpness) {
    // Fetch 3x3 neighborhood
    // a b c
    // d e f
    // g h i
    vec3 a = texelFetch(sampler, texel + ivec2(-1, -1), 0).rgb;
    vec3 b = texelFetch(sampler, texel + ivec2( 0, -1), 0).rgb;
    vec3 c = texelFetch(sampler, texel + ivec2( 1, -1), 0).rgb;
    vec3 d = texelFetch(sampler, texel + ivec2(-1,  0), 0).rgb;
    vec3 e = texelFetch(sampler, texel, 0).rgb;
    vec3 f = texelFetch(sampler, texel + ivec2( 1,  0), 0).rgb;
    vec3 g = texelFetch(sampler, texel + ivec2(-1,  1), 0).rgb;
    vec3 h = texelFetch(sampler, texel + ivec2( 0,  1), 0).rgb;
    vec3 i = texelFetch(sampler, texel + ivec2( 1,  1), 0).rgb;

    // Soft min and max. These are 2x bigger (factored out the extra multiply)
    vec3 minColor  = minOf(d, e, f, b, h);
         minColor += minOf(minColor, a, c, g, i);

    vec3 maxColor  = maxOf(d, e, f, b, h);
         maxColor += maxOf(maxColor, a, c, g, i);

    // Smooth minimum distance to the signal limit divided by smooth max
    vec3 w  = clamp01(min(minColor, 2.0 - maxColor) / maxColor);
         w  = 1.0 - sqr(1.0 - w); // Shaping amount of sharpening
         w *= -1.0 / mix(8.0, 5.0, sharpness);

    // Filter shape:
    // 0 w 0
    // w 1 w
    // 0 w 0
    vec3 weightSum = 1.0 + 4.0 * w;
    return clamp01((b + d + f + h) * w + e) / weightSum;
}

float vignette(vec2 coord) {
    const float vignetteSize = 16.0;
    const float vignetteIntensity = 0.08 * VIGNETTE_INTENSITY;

    float vignette = vignetteSize * (coord.x * coord.y - coord.x) * (coord.x * coord.y - coord.y);
          vignette = pow(vignette, vignetteIntensity + 0.15 * biomeCave + 0.3 * blindness);

    return vignette;
}

uniform float eyeAltitude;
uniform vec3 cameraPosition;

#if DEBUG_VIEW == DEBUG_VIEW_NONE
void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);

#ifdef CAS
	fragColor = textureCas(colortex2, texel, CAS_STRENGTH);
#else
	fragColor = texelFetch(colortex2, texel, 0).rgb;
#endif

#ifdef VIGNETTE
    //fragColor *= vignette(coord);
#endif

	fragColor = linearToSrgb(fragColor);

    float dither = texelFetch(noisetex, texel & 511, 0).b;
	fragColor = dither8Bit(fragColor, dither);
}
#elif DEBUG_VIEW == DEBUG_VIEW_SAMPLER
void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	if (clamp(texel, ivec2(0), ivec2(textureSize(DEBUG_SAMPLER, 0))) == texel) {
		fragColor  = texture(DEBUG_SAMPLER, coord).rgb;
		fragColor *= DEBUG_SAMPLER_EXPOSURE;
		fragColor  = linearToSrgb(fragColor);
	} else {
		fragColor = vec3(0.0);
	}
}
#endif
