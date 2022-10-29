#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/composite1.fsh:
  Shade translucent layer, apply specular and fog

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:03 */
layout (location = 0) out vec3 fragColor;
layout (location = 1) out float bloomyFog;

in vec2 uv;

uniform sampler2D colortex0; // Scene color
uniform sampler2D colortex1; // Gbuffer 0
uniform sampler2D colortex2; // Gbuffer 1
uniform sampler2D colortex3; // Translucent color
uniform sampler2D colortex4; // Sky capture
uniform sampler2D colortex5; // Volumetric fog scattering
uniform sampler2D colortex6; // Volumetric fog transmittance

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef SHADOW
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

// from https://iquilezles.org/www/articles/texture/texture.htm
vec4 textureSmooth(sampler2D sampler, vec2 coord) {
	vec2 res = vec2(textureSize(sampler, 0));

	coord = coord * res + 0.5;

	vec2 i, f = modf(coord, i);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	coord = i + f;

	coord = (coord - 0.5) / res;
	return texture(sampler, coord);
}

// from http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
vec3 purkinjeShift(vec3 rgb, float purkinjeIntensity) {
	const vec3 purkinjeTint = vec3(0.5, 0.7, 1.0) * rec709_to_rec2020;
	const vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1) * rec709_to_rec2020;

	if (purkinjeIntensity == 0.0) return rgb;

	vec3 xyz = rgb * rec2020_to_xyz;

	vec3 scotopicLuminance = xyz * (1.33 * (1.0 + (xyz.y + xyz.z) / xyz.x) - 1.68);

	float purkinje = dot(rodResponse, scotopicLuminance * xyz_to_rec2020);

	rgb = mix(rgb, purkinje * purkinjeTint, exp2(-rcp(purkinjeIntensity) * purkinje));

	return max0(rgb);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Texture fetches

	fragColor     = texelFetch(colortex0, texel, 0).rgb;

	float depth0  = texelFetch(depthtex0, texel, 0).x;
	float depth1  = texelFetch(depthtex1, texel, 0).x;
	vec4 gbuffer0 = texelFetch(colortex1, texel, 0);
#if defined NORMAL_MAPPING || defined SPECULAR_MAPPING
	vec4 gbuffer1 = texelFetch(colortex2, texel, 0);
#endif
	vec4 transCol = texelFetch(colortex3, texel, 0);

	vec2 fogUv = clamp(uv * FOG_RENDER_SCALE, vec2(0.0), floor(viewSize * FOG_RENDER_SCALE - 1.0) * texelSize);

	vec3 fogScattering    = textureSmooth(colortex5, fogUv).rgb;
	vec3 fogTransmittance = textureSmooth(colortex6, fogUv).rgb;

	// Transformations

	depth0 += 0.38 * float(isHand(depth0)); // Hand lighting fix from Capt Tatsu

	vec3 screenPos = vec3(uv, depth0);
	vec3 viewPos   = screenToViewSpace(screenPos, true);
	vec3 scenePos  = viewToSceneSpace(viewPos);
	vec3 worldPos  = scenePos + cameraPosition;

	vec3 worldDir; float viewDistance;
	lengthNormalize(scenePos - gbufferModelViewInverse[3].xyz, worldDir, viewDistance);

	vec3 viewBackPos = screenToViewSpace(vec3(uv, depth1), true);

	// Unpack gbuffer data

	mat4x2 data = mat4x2(
		unpackUnorm2x8(gbuffer0.x),
		unpackUnorm2x8(gbuffer0.y),
		unpackUnorm2x8(gbuffer0.z),
		unpackUnorm2x8(gbuffer0.w)
	);

	vec3 albedo     = vec3(data[0], data[1].x);
	uint blockId    = uint(255.0 * data[1].y);
	vec3 flatNormal = decodeUnitVector(data[2]);
	vec2 lmCoord    = data[3];

	fragColor = mix(fragColor, transCol.rgb, transCol.a);

	// Apply volumetric fog

#ifdef VOLUMETRIC_FOG
	fragColor = fragColor * fogTransmittance + fogScattering;

#ifdef BLOOMY_FOG
	bloomyFog = clamp01(dot(fogTransmittance, vec3(0.33)));
#endif
#endif

	// Purkinje shift

#ifdef PURKINJE_SHIFT
	lmCoord = isSky(depth0) ? vec2(0.0, 1.0) : lmCoord;

	float purkinjeIntensity  = 0.025 * PURKINJE_SHIFT_INTENSITY;
	      purkinjeIntensity *= 1.0 - smoothstep(-0.14, -0.08, sunDir.y) * sqrt(lmCoord.y);
	      purkinjeIntensity *= clamp01(1.0 - lmCoord.x);

	fragColor = purkinjeShift(fragColor, purkinjeIntensity);
#endif
}
