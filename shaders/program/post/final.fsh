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
#endif

uniform sampler2D colortex2; // Post-processing color

//--// Camera uniforms

uniform float blindness;

uniform vec3 cameraPosition;

//--// Time uniforms

uniform int worldDay;
uniform int worldTime;

uniform float frameTimeCounter;

uniform float rainStrength;
uniform float wetness;

//--// Custom uniforms

uniform float biomeCave;
uniform float biomeTemperature;
uniform float biomeHumidity;
uniform float biomeMayRain;

uniform float timeSunrise;
uniform float timeNoon;
uniform float timeSunset;
uniform float timeMidnight;

uniform vec3 lightDir;

//--// Includes //------------------------------------------------------------//

#include "/include/atmospherics/weather.glsl"

#include "/include/utility/bicubic.glsl"
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

void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);

    if (abs(MC_RENDER_QUALITY - 1.0) < 1e-2) {
#ifdef CAS
        fragColor = textureCas(colortex2, texel, CAS_STRENGTH);
#else
        fragColor = texelFetch(colortex2, texel, 0).rgb;
#endif
    } else {
        fragColor = textureCatmullRom(colortex2, coord).rgb;
    }

#ifdef VIGNETTE
    //fragColor *= vignette(coord);
#endif

	fragColor = linearToSrgb(fragColor);

    float dither = texelFetch(noisetex, texel & 511, 0).b;
	fragColor = dither8Bit(fragColor, dither);

#if   DEBUG_VIEW == DEBUG_VIEW_SAMPLER
	if (clamp(texel, ivec2(0), ivec2(textureSize(DEBUG_SAMPLER, 0))) == texel) {
		fragColor  = texelFetch(DEBUG_SAMPLER, texel, 0).rgb;
		fragColor *= DEBUG_SAMPLER_EXPOSURE;
		fragColor  = linearToSrgb(fragColor);
	} else {
		fragColor = vec3(0.0);
	}
#elif DEBUG_VIEW == DEBUG_VIEW_WEATHER // aesthetic progess bars
    const int  barWidth           = 50;
    const vec3 temperatureColor0  = vec3(0.20, 0.73, 1.00);
    const vec3 temperatureColor1  = vec3(1.00, 0.67, 0.00);
    const vec3 humidityColor0     = vec3(1.00, 0.85, 0.70);
    const vec3 humidityColor1     = vec3(0.00, 0.60, 0.00);
    const vec3 windStrengthColor0 = vec3(0.00, 0.80, 0.80);
    const vec3 windStrengthColor1 = vec3(0.65, 0.20, 1.00);

    vec3 weather = getWeather();
    float displayVariable0, displayVariable1;

    if (texel.x < barWidth) {
        // Temperature bar
        displayVariable0 = weather.x;
        displayVariable1 = biomeTemperature * 0.5 + 0.5;

        fragColor = linearToSrgb(mix(
            srgbToLinear(temperatureColor0),
            srgbToLinear(temperatureColor1),
            cubicSmooth(coord.y)
        ));
    } else if (texel.x < 2 * barWidth) {
        // Humidity bar
        displayVariable0 = weather.y;
        displayVariable1 = biomeHumidity * 0.5 + 0.5;

        fragColor = linearToSrgb(mix(
            srgbToLinear(humidityColor0),
            srgbToLinear(humidityColor1),
            cubicSmooth(coord.y)
        ));
    } else if (texel.x < 3 * barWidth) {
        // Wind strength bar
        displayVariable0 = weather.z;
        displayVariable1 = wetness;

        fragColor = linearToSrgb(mix(
            srgbToLinear(windStrengthColor0),
            srgbToLinear(windStrengthColor1),
            cubicSmooth(coord.y)
        ));
    } else {
        return;
    }

    if (abs(coord.y - displayVariable0) < 0.005) fragColor = vec3(1.0);
    if (abs(coord.y - displayVariable1) < 0.005) fragColor = vec3(0.0);
#endif
}
