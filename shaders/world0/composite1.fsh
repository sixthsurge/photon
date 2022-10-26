#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/composite1.fsh:


--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 fragColor;

in vec2 uv;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D colortex0; // main color
uniform sampler2D colortex1; // gbuffer 0
uniform sampler2D colortex2; // gbuffer 1
uniform sampler2D colortex3; // volumetric fog transmittance
uniform sampler2D colortex5; // volumetric fog scattering

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

#ifdef SHADOW
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
#endif

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;

uniform float sunAngle;

uniform int worldTime;
uniform int frameCounter;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

uniform vec2 viewSize;
uniform vec2 texelSize;
uniform vec2 taaOffset;

uniform float eyeSkylight;

uniform float biomeCave;

uniform float timeSunrise;
uniform float timeNoon;
uniform float timeSunset;
uniform float timeMidnight;

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/spaceConversion.glsl"

// from http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
vec3 purkinjeShift(vec3 rgb, float purkinjeIntensity) {
	if (purkinjeIntensity == 0.0) return rgb;

	const vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1) * rec709_to_rec2020;
	vec3 xyz = rgb * rec2020_to_xyz;

	vec3 scotopicLuminance = xyz * (1.33 * (1.0 + (xyz.y + xyz.z) / xyz.x) - 1.68);

	float purkinje = dot(rodResponse, scotopicLuminance * xyz_to_rec2020);

	rgb = mix(rgb, purkinje * vec3(0.5, 0.7, 1.0), exp2(-rcp(purkinjeIntensity) * purkinje));

	return max0(rgb);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	float depth   = texelFetch(depthtex1, texel, 0).x;
	fragColor     = texelFetch(colortex0, texel, 0).rgb;
	vec4 gbuffer0 = texelFetch(colortex1, texel, 0);
#if defined NORMAL_MAPPING || defined SPECULAR_MAPPING
	vec4 gbuffer1 = texelFetch(colortex2, texel, 0);
#endif

	bool hand = isHand(depth);
	depth += 0.38 * float(hand); // Hand lighting fix from Capt Tatsu

	mat4x2 data = mat4x2(
		unpackUnorm2x8(gbuffer0.x),
		unpackUnorm2x8(gbuffer0.y),
		unpackUnorm2x8(gbuffer0.z),
		unpackUnorm2x8(gbuffer0.w)
	);

	vec3 albedo      = vec3(data[0], data[1].x);
	uint blockId     = uint(255.0 * data[1].y);
	vec3 flatNormal  = decodeUnitVector(data[2]);
	vec2 lightLevels = data[3];

	vec3 fogScattering = texture(colortex5, 0.5 * uv).rgb;
	vec3 fogTransmittance = texture(colortex3, 0.5 * uv).rgb;

	fragColor = fragColor * fogTransmittance + fogScattering;

	// Purkinje shift

	lightLevels = isSky(depth) ? vec2(0.0, 1.0) : lightLevels;

	float purkinjeIntensity  = 0.1 * PURKINJE_SHIFT_INTENSITY;
	      purkinjeIntensity *= 1.0 - smoothstep(-0.14, -0.08, sunDir.y) * sqrt(lightLevels.y);
	      purkinjeIntensity *= clamp01(1.0 - 1.5 * lightLevels.x);

	fragColor = purkinjeShift(fragColor, purkinjeIntensity);
}
