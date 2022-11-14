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

flat in vec3 lightColor;
flat in mat3 skyColors;

uniform sampler2D colortex0; // Scene color
uniform sampler2D colortex1; // Gbuffer 0
uniform sampler2D colortex2; // Gbuffer 1
uniform sampler2D colortex3; // Blended color
uniform sampler2D colortex4; // Sky capture
uniform sampler2D colortex5; // Volumetric fog scattering
uniform sampler2D colortex6; // Volumetric fog transmittance

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

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

uniform float sunAngle;

uniform int worldTime;
uniform int frameCounter;

uniform int isEyeInWater;
uniform float blindness;

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

#define PROGRAM_COMPOSITE1
#define WORLD_OVERWORLD

#ifdef SHADOW_COLOR
	#undef SHADOW_COLOR
#endif

#ifdef SH_SKYLIGHT
	#undef SH_SKYLIGHT
#endif

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/spaceConversion.glsl"

#include "/include/diffuseLighting.glsl"
#include "/include/fog.glsl"
#include "/include/material.glsl"
#include "/include/shadows.glsl"
#include "/include/specularLighting.glsl"

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
	const vec3 purkinjeTint = vec3(0.43, 0.64, 1.0);
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

	float depth0    = texelFetch(depthtex0, texel, 0).x;
	float depth1    = texelFetch(depthtex1, texel, 0).x;

	fragColor       = texelFetch(colortex0, texel, 0).rgb;
	vec4 gbuffer0   = texelFetch(colortex1, texel, 0);
#if defined NORMAL_MAPPING || defined SPECULAR_MAPPING
	vec4 gbuffer1   = texelFetch(colortex2, texel, 0);
#endif
	vec4 blendColor = texelFetch(colortex3, texel, 0);

	vec2 fogUv = clamp(uv * FOG_RENDER_SCALE, vec2(0.0), floor(viewSize * FOG_RENDER_SCALE - 1.0) * texelSize);

	vec3 fogScattering    = textureSmooth(colortex5, fogUv).rgb;
	vec3 fogTransmittance = textureSmooth(colortex6, fogUv).rgb;

	// Transformations

	depth0 += 0.38 * float(isHand(depth0)); // Hand lighting fix from Capt Tatsu

	vec3 screenPos = vec3(uv, depth0);
	vec3 viewPos   = screenToViewSpace(screenPos, true);
	vec3 scenePos  = viewToSceneSpace(viewPos);
	vec3 worldPos  = scenePos + cameraPosition;

	vec3 worldDir; float viewDist;
	lengthNormalize(scenePos - gbufferModelViewInverse[3].xyz, worldDir, viewDist);

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

	Material material;

	// Shade translucent layer

	bool isTranslucent  = depth0 != depth1;
	bool isWater        = blockId == 1;
	bool isRainParticle = blockId == 253;
	bool isSnowParticle = blockId == 254;

	if (isTranslucent) {
		material = getMaterial(blendColor.rgb, blockId, fract(worldPos), lmCoord);

#ifdef NORMAL_MAPPING
		vec3 normal = decodeUnitVector(gbuffer1.xy);
#else
		#define normal flatNormal
#endif

#ifdef SPECULAR_MAPPING
		vec4 specularTex = vec4(unpackUnorm2x8(gbuffer1.z), unpackUnorm2x8(gbuffer1.w));
		decodeSpecularTexture(specularTex, material);
#endif

		float NoL = dot(normal, lightDir);
		float NoV = clamp01(dot(normal, -worldDir));
		float LoV = dot(lightDir, -worldDir);
		float halfwayNorm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfwayNorm;
		float LoH = LoV * halfwayNorm + halfwayNorm;

		float sssDepth;
		vec3 shadows = calculateShadows(scenePos, flatNormal, lmCoord.y, material.sssAmount, sssDepth);

		vec3 translucentColor = getSceneLighting(
			material,
			normal,
			flatNormal,
			normal,
			shadows,
			lmCoord,
			1.0,
			sssDepth,
			NoL,
			NoV,
			NoH,
			LoV
		);

		translucentColor += getSpecularHighlight(material, NoL, NoV, NoH, LoV, LoH) * lightColor * shadows;

		applyFog(translucentColor, scenePos, worldDir, false);

#ifdef BORDER_FOG
		// Handle border fog by attenuating the alpha component
		float borderFog = getBorderFog(scenePos, worldDir);
		blendColor.a *= borderFog;
#else
		const float borderFog = 1.0;
#endif

		// Blend with background
		vec3 tint = material.albedo;
		float alpha = blendColor.a;
		fragColor *= (1.0 - alpha) + tint * alpha;
		fragColor *= 1.0 - alpha;
		fragColor += translucentColor * borderFog;
	}

	// Apply volumetric fog

#ifdef VOLUMETRIC_FOG
	fragColor = fragColor * fogTransmittance + fogScattering;
#endif

	// Purkinje shift

#ifdef PURKINJE_SHIFT
	lmCoord = isSky(depth0) ? vec2(0.0, 1.0) : lmCoord;

	float purkinjeIntensity  = 0.066 * PURKINJE_SHIFT_INTENSITY;
	      purkinjeIntensity *= 1.0 - smoothstep(-0.12, -0.06, sunDir.y);
		  purkinjeIntensity *= 0.1 + 0.9 * lmCoord.y;
	      purkinjeIntensity *= clamp01(1.0 - lmCoord.x);

	fragColor = purkinjeShift(fragColor, purkinjeIntensity);
#endif

	// Calculate bloomy fog

#ifdef BLOOMY_FOG
	#ifdef VOLUMETRIC_FOG
	bloomyFog = clamp01(dot(fogTransmittance, vec3(0.33)));
	#else
	bloomyFog = 1.0;
	#endif

	#ifdef CAVE_FOG
	bloomyFog *= getSphericalFog(viewDist, 0.0, 0.005 * biomeCave * float(depth0 != 1.0));
	#endif
#endif

}
