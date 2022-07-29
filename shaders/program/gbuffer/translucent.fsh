#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 0,9 */
layout (location = 0) out vec4 fragColor;
layout (location = 1) out vec4 waterMask;

//--// Inputs //--------------------------------------------------------------//

in vec2 texCoord;
in vec2 lmCoord;
in vec3 viewPos;
in vec3 scenePos;
in vec3 viewerDirTangent;

flat in uint blockId;
flat in vec4 tint;
flat in mat3 tbnMatrix;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler2D depthtex1;

uniform sampler2D colortex4;  // Sky capture
uniform sampler2D colortex6;  // Clear sky
uniform sampler2D colortex8;  // Scene history
uniform sampler2D colortex15; // Cloud shadow map

#if MC_VERSION < 11700
	#define gtexture gcolor
#endif

uniform sampler2D gtexture;

#ifdef MC_NORMAL_MAP
uniform sampler2D normals;
#endif

#ifdef MC_SPECULAR_MAP
uniform sampler2D specular;
#endif

#ifdef SHADOW
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif

//--// Camera uniforms

uniform int isEyeInWater;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

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

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

#ifdef SHADOW_COLOR
	#undef SHADOW_COLOR
#endif

#define TEMPORAL_REPROJECTION

#include "/block.properties"
#include "/entity.properties"

#include "/include/fragment/aces/matrices.glsl"
#include "/include/fragment/fog.glsl"
#include "/include/fragment/material.glsl"
#include "/include/fragment/textureFormat.glsl"
#include "/include/fragment/waterNormal.glsl"
#include "/include/fragment/waterVolume.glsl"

#include "/include/lighting/lighting.glsl"
#include "/include/lighting/reflections.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Functions //-----------------------------------------------------------//

const float lodBias = log2(renderScale);
const float waterOpacity = 0.02;

void main() {
	vec2 coord = gl_FragCoord.xy * viewTexelSize;
	if (clamp01(coord) != coord) discard;

	/* -- fetch lighting palette -- */

	vec3 ambientIrradiance = texelFetch(colortex4, ivec2(255, 0), 0).rgb;
	vec3 directIrradiance  = texelFetch(colortex4, ivec2(255, 1), 0).rgb;
	vec3 skyIrradiance     = texelFetch(colortex4, ivec2(255, 2), 0).rgb;

	/* -- get material and normal -- */

	Material material;
	vec3 normalTangent = vec3(0.0, 0.0, 1.0);
	float materialAo   = 1.0;

	vec4 baseTex = texture(gtexture, texCoord, lodBias) * tint;

	if (blockId == BLOCK_WATER) {
		material.albedo           = vec3(0.0);
		material.f0               = vec3(0.02);
		material.emission         = vec3(0.0);
		material.roughness        = 0.002;
		material.n                = isEyeInWater == 1 ? airN / waterN : waterN / airN;
		material.sssAmount        = 1.0;
		material.porosity         = 0.0;
		material.isMetal          = false;
		material.isHardcodedMetal = false;

#ifdef WATER_TEXTURE
		float textureValue     = getLuminance(srgbToLinear(baseTex.rgb), luminanceWeightsR709);
		float textureHighlight = linearStep(0.08, 0.3, textureValue);

		material.albedo     = clamp01(0.5 * exp(-2.0 * waterExtinctionCoeff) * (textureValue + 0.6 * textureHighlight));
		material.roughness += 0.3 * textureHighlight;
#endif

		vec3 worldPos = scenePos + cameraPosition;

		bool isStill = abs(tbnMatrix[2].y) > 0.99;
		vec2 flowDir = isStill ? vec2(0.0) : normalize(tbnMatrix[2].xz);

#ifdef WATER_PARALLAX
		worldPos.xz = waterParallax(normalize(viewerDirTangent), worldPos.xz, flowDir);
#endif

		normalTangent = getWaterNormal(tbnMatrix[2], worldPos, flowDir);
	} else {
		if (baseTex.a < 0.1) discard;

		vec3 albedo = srgbToLinear(baseTex.rgb) * baseTex.a * r709ToAp1Unlit;
		fragColor.a = baseTex.a;

		material = getMaterial(albedo, blockId);

#ifdef MC_SPECULAR_MAP
		vec4 specularTex = textureLod(specular, texCoord, 0);
		decodeSpecularTex(specularTex, material);
#endif

#ifdef MC_NORMAL_MAP
		vec3 normalTex = texture(normals, texCoord, lodBias).xyz;
		decodeNormalTex(normalTex, normalTangent, materialAo);
#endif

		// Hardcoded reflections and SSS for stained glass
		if (blockId == BLOCK_STAINED_GLASS) {
			material.sssAmount = 0.5;
			material.roughness = 0.002;
			material.f0        = vec3(0.04);
		}

		// Hardcoded SSS for slime
		if (blockId == BLOCK_SLIME) {
			material.sssAmount = 0.5;
		}
	}

	float viewerDistance = length(viewPos);

	vec3 normal = tbnMatrix * normalTangent;
	vec3 flatNormal = tbnMatrix[2];
	vec3 viewerDir = (gbufferModelViewInverse[3].xyz - scenePos) * rcp(viewerDistance);

#if defined PROGRAM_GBUFFERS_TEXTURED
	// no normal attribute
	normal = vec3(0.0, 1.0, 0.0);
	flatNormal = normal;
#endif

	/* -- lighting -- */

	float sssDepth;
	fragColor.rgb = getSceneLighting(
		material,
		scenePos,
		normal,
		flatNormal,
		viewerDir,
		directIrradiance,
		ambientIrradiance,
		skyIrradiance,
		lmCoord,
		materialAo,
		blockId,
		sssDepth
	);

	/* -- reflections -- */

#if defined SSR && defined PROGRAM_GBUFFERS_WATER
	fragColor.rgb += getSpecularReflections(
		material,
		tbnMatrix,
		vec3(coord, gl_FragCoord.z),
		viewPos,
		normal,
		viewerDir,
		viewerDirTangent,
		lmCoord.y
	);
#endif

	/* -- fog -- */

	vec3 clearSky = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0).rgb;
	fragColor.rgb = applyFog(fragColor.rgb, scenePos, clearSky);

	/* -- set water mask -- */

	if (blockId == BLOCK_WATER) {
		float eta = isEyeInWater == 1 ? airN / waterN : waterN / airN;
		float NoV = dot(normal, viewerDir);

		fragColor.a = max(fresnelDielectric(NoV, eta), eps);

		vec2 lightingInfo;
		lightingInfo.x = clamp01(rcp(32.0) * sssDepth);
		lightingInfo.y = lmCoord.y;

		waterMask.x = packUnorm2x8(normalTangent.xy * 0.5 + 0.5);
		waterMask.y = packUnorm2x8(lightingInfo);
		waterMask.z = clamp01(viewerDistance / far);
		waterMask.w = float(blockId == BLOCK_WATER);
	} else {
		waterMask = vec4(0.0);
	}

	fragColor.rgb *= rcp(fragColor.a);
}
