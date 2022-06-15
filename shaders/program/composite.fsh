/*
 * Program description:
 * Deferred lighting pass for translucent objects, simple fog, reflections and refractions
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 3 */
layout (location = 0) out vec3 radiance;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler2D colortex0;  // Translucent color
uniform usampler2D colortex1; // Scene data
uniform sampler2D colortex3;  // Scene radiance
uniform sampler2D colortex4;  // Sky capture, lighting color palette
uniform sampler2D colortex6;  // Clear sky
uniform sampler2D colortex11; // Clouds

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef SHADOW
#ifdef SHADOW_COLOR
uniform sampler2D shadowcolor0;
#endif
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif

//--// Camera uniforms

uniform int isEyeInWater;

uniform ivec2 eyeBrightnessSmooth;

uniform float eyeAltitude;

uniform float near;
uniform float far;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Shadow uniforms

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

//--// Time uniforms

uniform int frameCounter;

//--// Custom uniforms

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform vec3 lightDir;

//--// Includes //------------------------------------------------------------//

#include "/block.properties"
#include "/entity.properties"

#include "/include/atmospherics/atmosphere.glsl"

#include "/include/fragment/material.glsl"

#include "/include/lighting/shadowMapping.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Functions //-----------------------------------------------------------//

vec3 getCloudsAerialPerspective(vec3 cloudsScattering, vec3 cloudData, vec3 rayDir, vec3 clearSky, float apparentDistance) {
	vec3 rayOrigin = vec3(0.0, planetRadius + CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL), 0.0);
	vec3 rayEnd    = rayOrigin + apparentDistance * rayDir;

	vec3 transmittance;
	if (rayOrigin.y < length(rayEnd)) {
		vec3 trans0 = getAtmosphereTransmittance(rayOrigin, rayDir, 1.0);
		vec3 trans1 = getAtmosphereTransmittance(rayEnd,    rayDir, 1.0);

		transmittance = clamp01(trans0 / trans1);
	} else {
		vec3 trans0 = getAtmosphereTransmittance(rayOrigin, -rayDir, 1.0);
		vec3 trans1 = getAtmosphereTransmittance(rayEnd,    -rayDir, 1.0);

		transmittance = clamp01(trans1 / trans0);
	}

	return mix((1.0 - cloudData.b) * clearSky, cloudsScattering, transmittance);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	float depthFront      = texelFetch(depthtex0, texel, 0).x;
	float depthBack       = texelFetch(depthtex1, texel, 0).x;
	vec4 translucentColor = texelFetch(colortex0, texel, 0);
	uvec4 encoded         = texelFetch(colortex1, texel, 0);
	radiance              = texelFetch(colortex3, texel, 0).rgb;
	vec4 clouds           = texelFetch(colortex11, texel, 0);

	vec3 ambientIrradiance = texelFetch(colortex4, ivec2(255, 0), 0).rgb;
	vec3 directIrradiance  = texelFetch(colortex4, ivec2(255, 1), 0).rgb;
	vec3 skyIrradiance     = texelFetch(colortex4, ivec2(255, 2), 0).rgb;

	vec3 viewPosFront = screenToViewSpace(vec3(coord, depthFront), true);
	vec3 scenePosFront = viewToSceneSpace(viewPosFront);

	float viewerDistance = length(viewPosFront);

	vec3 viewPosBack = screenToViewSpace(vec3(coord, depthBack), true);

	// Blend with clouds

	if (depthBack < 1.0 && clouds.w < viewerDistance * CLOUDS_SCALE) {
		vec3 cloudsScattering = mat2x3(directIrradiance, skyIrradiance) * clouds.xy;

		radiance = radiance * clouds.z + cloudsScattering;
	}
}
