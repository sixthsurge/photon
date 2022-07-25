#version 410 compatibility

/*
 * Program description:
 * Render cloud shadow map
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 15 */
layout (location = 0) out float cloudShadow;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler2D depthtex1;

uniform sampler3D depthtex0; // 3D worley noise
uniform sampler3D depthtex2; // 3D curl noise

//--// Camera uniforms

uniform float near;
uniform float far;

uniform float eyeAltitude;

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

uniform int worldDay;
uniform int worldTime;

uniform float frameTimeCounter;

uniform float rainStrength;
uniform float wetness;

//--// Custom uniforms

uniform bool cloudsMoonlit;

uniform float biomeTemperature;
uniform float biomeHumidity;
uniform float biomeMayRain;

uniform float timeSunset;
uniform float timeNoon;
uniform float timeSunrise;
uniform float timeMidnight;

uniform float worldAge;

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

vec3 weather;
#include "/include/atmospherics/clouds.glsl"

#include "/include/lighting/cloudShadows.glsl"

//--// Functions //-----------------------------------------------------------//

void main() {
#ifndef CLOUD_SHADOWS
	return;
#endif

	ivec2 texel = ivec2(gl_FragCoord.xy);

	vec2 coord = gl_FragCoord.xy * rcp(vec2(cloudShadowRes));

	if (clamp01(coord) != coord) discard;

	vec3 rayOrigin = unprojectCloudShadowmap(coord);
	     rayOrigin = vec3(rayOrigin.xz, rayOrigin.y + eyeAltitude - SEA_LEVEL).xzy * CLOUDS_SCALE + vec3(0.0, planetRadius, 0.0);

	cloudShadow = getCloudShadows(rayOrigin, lightDir);
}
