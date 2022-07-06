#version 410 compatibility

/*
 * Program description:
 * Render sky
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 3,6,11,12 */
layout (location = 0) out vec3 radiance;
layout (location = 1) out vec3 atmosphereScattering;
layout (location = 2) out vec4 cloudsHistory;
layout (location = 3) out uint cloudsPixelAge;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

flat in vec3 directIrradiance;
flat in vec3 skyIrradiance;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex0;  // Vanilla sky (sun, moon and custom skies)
uniform sampler2D colortex5;  // New cloud sample
uniform sampler2D colortex11; // Clouds history
uniform usampler2D colortex12; // Clouds pixel age
uniform sampler2D colortex13; // Previous frame depth

uniform sampler3D colortex2; // Atmosphere scattering LUT

uniform sampler2D depthtex1;

//--// Camera uniforms

uniform int isEyeInWater;

uniform float eyeAltitude;

uniform float near;
uniform float far;

uniform float blindness;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

//--// Shadow uniforms

uniform mat4 shadowModelView;

//--// Time uniforms

uniform int frameCounter;

uniform int worldTime;

uniform int moonPhase;

uniform float frameTime;

uniform float sunAngle;

//--// Custom uniforms

uniform bool cloudsMoonlit;
uniform bool worldAgeChanged;

uniform float biomeCave;

uniform float timeNoon;

uniform float lightningFlash;
uniform float moonPhaseBrightness;

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

#define WORLD_OVERWORLD

#define ATMOSPHERE_SCATTERING_LUT colortex2

#include "/block.properties"
#include "/entity.properties"

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/atmospherics/sky.glsl"

#include "/include/fragment/aces/matrices.glsl"
#include "/include/fragment/fog.glsl"

#include "/include/utility/bicubic.glsl"
#include "/include/utility/checkerboard.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Program //-------------------------------------------------------------//

vec4 minOf(vec4 a, vec4 b, vec4 c, vec4 d, vec4 f) {
    return min(a, min(b, min(c, min(d, f))));
}

vec4 maxOf(vec4 a, vec4 b, vec4 c, vec4 d, vec4 f) {
    return max(a, max(b, max(c, max(d, f))));
}

vec3 reprojectClouds(vec2 coord, float distanceToCloud) {
	const float windSpeed = VCLOUD_LAYER0_WIND_SPEED / CLOUDS_SCALE;
	const float windAngle = VCLOUD_LAYER0_WIND_ANGLE * tau / 360.0;

	vec3 pos = screenToViewSpace(vec3(coord, 1.0), false);
	     pos = mat3(gbufferModelViewInverse) * pos;
	     pos = normalize(pos) * distanceToCloud * rcp(CLOUDS_SCALE);

	vec3 velocity  = previousCameraPosition - cameraPosition;
	     velocity += windSpeed * frameTime * vec3(cos(windAngle), sin(windAngle), 0.0).xzy;

	vec3 previousPos = transform(gbufferPreviousModelView, pos + gbufferModelViewInverse[3].xyz - velocity);
	     previousPos = projectAndDivide(gbufferPreviousProjection, previousPos);

	return previousPos * 0.5 + 0.5;
}

vec4 upscaleClouds(ivec2 dstTexel, vec3 screenPos) {
	/*
	 * x: sunlight
	 * y: skylight
	 * z: transmittance
	 * w: apparent distance
	 */

#if CLOUDS_UPSCALING_FACTOR == 1
	const vec2 cloudsRenderScale = vec2(1.0);
	#define checkerboardOffsets ivec2[1](ivec2(0))
#elif CLOUDS_UPSCALING_FACTOR == 2
	const vec2 cloudsRenderScale = vec2(0.5, 1.0);
	#define checkerboardOffsets checkerboardOffsets2x1
#elif CLOUDS_UPSCALING_FACTOR == 4
	const vec2 cloudsRenderScale = vec2(0.5);
	#define checkerboardOffsets checkerboardOffsets2x2
#elif CLOUDS_UPSCALING_FACTOR == 8
	const vec2 cloudsRenderScale = vec2(0.25, 0.5);
	#define checkerboardOffsets checkerboardOffsets4x2
#elif CLOUDS_UPSCALING_FACTOR == 9
	const vec2 cloudsRenderScale = vec2(1.0 / 3.0);
	#define checkerboardOffsets checkerboardOffsets3x3
#elif CLOUDS_UPSCALING_FACTOR == 16
	const vec2 cloudsRenderScale = vec2(0.25);
	#define checkerboardOffsets checkerboardOffsets4x4
#endif

	// Scales new sample values back to its actual range
	const vec4 currentScale = vec4(1e2, 1e2, 1.0, 1e6);

	ivec2 srcTexel = ivec2(dstTexel * cloudsRenderScale);

	// Fetch 3x3 neighborhood
	vec4 a = texelFetch(colortex5, srcTexel + ivec2(-1, -1), 0);
	vec4 b = texelFetch(colortex5, srcTexel + ivec2( 0, -1), 0);
	vec4 c = texelFetch(colortex5, srcTexel + ivec2( 1, -1), 0);
	vec4 d = texelFetch(colortex5, srcTexel + ivec2(-1,  0), 0);
	vec4 e = texelFetch(colortex5, srcTexel, 0);
	vec4 f = texelFetch(colortex5, srcTexel + ivec2( 1,  0), 0);
	vec4 g = texelFetch(colortex5, srcTexel + ivec2(-1,  1), 0);
	vec4 h = texelFetch(colortex5, srcTexel + ivec2( 0,  1), 0);
	vec4 i = texelFetch(colortex5, srcTexel + ivec2( 1,  1), 0);

	// Soft minimum and maximum ("Hybrid Reconstruction Antialiasing")
	//        b         a b c
	// (min d e f + min d e f) / 2
	//        h         g h i
	vec4 aabbMin  = minOf(b, d, e, f, h);
	     aabbMin += minOf(aabbMin, a, c, g, i);
	     aabbMin *= 0.5 * currentScale;

	vec4 aabbMax  = maxOf(b, d, e, f, h);
	     aabbMax += maxOf(aabbMax, a, c, g, i);
	     aabbMax *= 0.5 * currentScale;

	vec2 previousCoord = reprojectClouds(coord, e.w * 1e6).xy;
	vec2 previousCoordClamped = clamp(previousCoord.xy, vec2(0.0), 1.0 - 2.0 * viewTexelSize); // Prevent line at edge of screen

	vec2 velocity = (coord - previousCoord) * viewSize;

	vec4 current = e * currentScale;
	vec4 history = textureCatmullRom(colortex11, previousCoordClamped);
	vec4 historyClamped = clamp(history, aabbMin, aabbMax);

	// Only clamp when moving fast or when close to or above clouds
	float clampingStrength = smoothstep(0.8 * VCLOUD_LAYER0_ALTITUDE, VCLOUD_LAYER0_ALTITUDE, CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL));
	      clampingStrength = clamp01(clampingStrength);

	history = mix(history, historyClamped, clampingStrength);

	bool offscreen = clamp01(previousCoord.xy) != previousCoord.xy;

	float historyDepth = texture(colortex13, previousCoordClamped).y;
	bool disoccluded = screenPos.z == 1.0 && historyDepth > eps;

	bool invalidHistory = offscreen || disoccluded || worldAgeChanged || any(isnan(history)) || any(isinf(history));

	uint pixelAge = texelFetch(colortex12, ivec2(previousCoord * viewSize * cloudsRenderScale), 0).x;

	if (invalidHistory) {
		current = history = textureBicubic(colortex5, coord * cloudsRenderScale) * currentScale;
		pixelAge = 0;
	}

	float x = float(pixelAge);
	float historyWeight = min(x / (x + 1.0), CLOUDS_ACCUMULATION_LIMIT);

	// Soften history sample for newer pixels
	vec4 historySmooth = textureBicubic(colortex11, previousCoordClamped);
	     historySmooth = mix(historySmooth, history, clamp01(historyWeight));
		 historySmooth = invalidHistory ? history : mix(historySmooth, clamp(historySmooth, aabbMin, aabbMax), clampingStrength);

	// Checkerboard upscaling
	ivec2 offset0 = dstTexel % ivec2(rcp(cloudsRenderScale));
	ivec2 offset1 = checkerboardOffsets[frameCounter % CLOUDS_UPSCALING_FACTOR];
	if (offset0 != offset1) current = historySmooth;

	// Velocity rejection
	historyWeight *= exp(-length(velocity)) * 0.7 + 0.3;

	// Offcenter rejection from Jessie, which is originally from Zombye
	// Reduces blur in motion
	vec2 pixelOffset = 1.0 - abs(2.0 * fract(previousCoord * viewSize) - 1.0);
	historyWeight *= sqrt(pixelOffset.x * pixelOffset.y) * 0.5 + 0.5;

	current = mix(current, history, historyWeight);

	// Update history for next frame
	cloudsHistory = current;
	cloudsPixelAge = min(pixelAge + 1, 254);

	return current;
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	float depth = texelFetch(depthtex1, texel, 0).x;

	vec3 screenPos = vec3(coord, 1.0);
	vec3 viewPos = screenToViewSpace(screenPos, true);
	vec3 rayDir = mat3(gbufferModelViewInverse) * normalize(viewPos);

	vec4 cloudData = upscaleClouds(texel, vec3(coord, depth));

	atmosphereScattering = sunIrradiance * getAtmosphereScattering(rayDir, sunDir)
	                     + moonIrradiance * getAtmosphereScattering(rayDir, moonDir) * moonPhaseBrightness;

	if (depth != 1.0) return;

	/* -- space -- */

	radiance = vec3(0.0);

	vec4 vanillaSky = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0); // Sun, moon and custom skies
	vec3 vanillaSkyColor = srgbToLinear(vanillaSky.rgb) * r709ToAp1Unlit;
	uint vanillaSkyId = uint(255.0 * vanillaSky.a);

#ifdef VANILLA_SUN
	if (vanillaSkyId == 2) {
		const vec3 brightnessScale = 5.0 * sunIrradiance;
		radiance += vanillaSkyColor * brightnessScale;
	}
#else
	radiance += drawSun(rayDir);
#endif

#ifdef VANILLA_MOON
	if (vanillaSkyId == 3) {
		const vec3 brightnessScale = 5.0 * moonIrradiance;
		radiance += vanillaSkyColor * brightnessScale;
	}
#else
	radiance += drawMoon(rayDir);
#endif

#ifdef STARS
	radiance += drawStars(rayDir);
#endif

	/* -- atmosphere -- */

	vec3 atmosphereTransmittance = getAtmosphereTransmittance(rayDir.y, planetRadius);

	radiance = radiance * atmosphereTransmittance + atmosphereScattering;

	/* -- clouds -- */

	const vec3 cloudsLightningFlash = vec3(20.0);

	vec3 cloudsScattering = mat2x3(directIrradiance, skyIrradiance + cloudsLightningFlash * lightningFlash) * cloudData.xy;
	     cloudsScattering = cloudsAerialPerspective(cloudsScattering, cloudData.rgb, rayDir, atmosphereScattering, cloudData.w);

	#define cloudsTransmittance cloudData.z

	radiance = radiance * cloudsTransmittance + cloudsScattering;

	// fade lower part of sky into cave fog color when underground so that the sky isn't visible
	// beyond the render distance
	float undergroundSkyFade = biomeCave * smoothstep(-0.1, 0.1, 0.4 - rayDir.y);
	radiance = mix(radiance, caveFogColor, undergroundSkyFade);

	radiance *= 1.0 - blindness;
}
