/*
 * Program description:
 * Blend solid and translucent layers, apply effects behind water
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 3 */
layout (location = 0) out vec3 radiance;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex0;  // Translucent layer
uniform sampler2D colortex3;  // Solid layer + sky
uniform sampler2D colortex4;  // Sky capture
uniform sampler2D colortex6;  // Sky color
uniform sampler2D colortex9;  // Water mask
uniform sampler2D colortex11; // Clouds
uniform sampler2D colortex15; // Cloud shadow map

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

//--// Camera uniforms

uniform int isEyeInWater;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform float eyeAltitude;

uniform float near;
uniform float far;

uniform float blindness;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Shadow uniforms

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

//--// Time uniforms

uniform int frameCounter;

uniform int moonPhase;

uniform float frameTimeCounter;

uniform float sunAngle;
uniform float rainStrength;

//--// Custom uniforms

uniform float biomeCave;

uniform float timeNoon;

uniform float eyeSkylight;

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

#include "/include/atmospherics/sky.glsl"

#include "/include/fragment/aces/matrices.glsl"
#include "/include/fragment/waterVolume.glsl"

#include "/include/lighting/cloudShadows.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Functions //-----------------------------------------------------------//

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	/* -- texture fetches -- */

	float frontDepth  = texelFetch(depthtex0,  texel, 0).x;
	float backDepth   = texelFetch(depthtex1,  texel, 0).x;
	radiance          = texelFetch(colortex3,  texel, 0).rgb;
	vec4 translucents = texelFetch(colortex0,  texel, 0);
	vec4 waterMask    = texelFetch(colortex9,  texel, 0);
	vec3 clearSky     = texelFetch(colortex6,  texel, 0).rgb;
	vec4 clouds       = texelFetch(colortex11, texel, 0);

	/* -- fetch lighting palette -- */

	vec3 ambientIrradiance = texelFetch(colortex4, ivec2(255, 0), 0).rgb;
	vec3 directIrradiance  = texelFetch(colortex4, ivec2(255, 1), 0).rgb;
	vec3 skyIrradiance     = texelFetch(colortex4, ivec2(255, 2), 0).rgb;

	/* -- transformations -- */

	vec3 screenPos = vec3(coord, frontDepth);
	vec3 viewPos   = screenToViewSpace(screenPos, true);
	vec3 scenePos  = viewToSceneSpace(viewPos);

	float viewerDistance = length(viewPos);
	vec3 viewerDir = (gbufferModelViewInverse[3].xyz - scenePos) * rcp(viewerDistance);

	/* -- underwater effects -- */

	if (waterMask.a > 0.5) {
		vec2 normalTangentXy       = unpackUnorm2x8(waterMask.x) * 2.0 - 1.0;
		vec2 lightingInfo          = unpackUnorm2x8(waterMask.y);
		float distanceToWater      = waterMask.z * far;

		// water refraction

#ifdef WATER_REFRACTION
		const float refractionStrength = 0.5;
		vec2 refractedCoord = coord + normalTangentXy * (refractionStrength * rcp(max(distanceToWater, 1.0)));

		radiance         = texture(colortex3, refractedCoord).rgb;
		backDepth        = texture(depthtex1, refractedCoord * renderScale).x;
		vec3 backPosView = screenToViewSpace(vec3(refractedCoord, backDepth), true);
#endif

		// water volume

		float distanceThroughWater = max0(length(backPosView) - distanceToWater) * float(isEyeInWater != 1);
		float LoV = dot(viewerDir, lightDir);
		float sssDepth = lightingInfo.x * 32.0;
		float skylight = lightingInfo.y;
		float cloudShadow = getCloudShadows(colortex15, scenePos);

		mat2x3 waterVolume = getSimpleWaterVolume(
			directIrradiance,
			skyIrradiance,
			ambientIrradiance,
			distanceThroughWater,
			LoV,
			sssDepth,
			skylight,
			cloudShadow
		);

		radiance = radiance * waterVolume[1] + waterVolume[0];
	}

	/* -- blend layers -- */

	radiance = radiance * (1.0 - translucents.a) + translucents.rgb;

	/* -- blend with clouds -- */

	if (backDepth < 1.0 && clouds.w < viewerDistance * CLOUDS_SCALE) {
		vec3 cloudsScattering = mat2x3(directIrradiance, skyIrradiance) * clouds.xy;

		radiance = radiance * clouds.z + cloudsScattering;
	}
}
