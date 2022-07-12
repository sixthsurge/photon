/*
 * Program description:
 * Deferred lighting pass for solid objects
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 3 */
layout (location = 0) out vec3 radiance;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

flat in vec3 ambientIrradiance;
flat in vec3 directIrradiance;

#ifdef SH_SKYLIGHT
flat in vec3[9] skySh;
#else
flat in vec3 skyIrradiance;
#endif

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler2D colortex0;  // Translucent overlays
uniform usampler2D colortex1; // Scene data
uniform sampler2D colortex3;  // Scene radiance
uniform sampler2D colortex4;  // Sky capture
uniform sampler2D colortex6;  // Clear sky
uniform sampler2D colortex8;  // Scene history
uniform sampler2D colortex15; // Cloud shadow map

#ifdef SSPT
uniform sampler2D colortex5;  // SSPT
#endif

#ifdef GTAO
uniform sampler2D colortex10; // GTAO
#endif

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
uniform int worldDay;
uniform int worldTime;

uniform float frameTimeCounter;

uniform float sunAngle;

uniform float rainStrength;
uniform float wetness;

//--// Custom uniforms

uniform float biomeCave;
uniform float biomeTemperature;
uniform float biomeHumidity;
uniform float biomeMayRain;

uniform float timeSunset;
uniform float timeNoon;
uniform float timeSunrise;
uniform float timeMidnight;

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

#define PROGRAM_DEFERRED_LIGHTING
#define TEMPORAL_REPROJECTION

#include "/block.properties"
#include "/entity.properties"

#include "/include/atmospherics/weather.glsl"

#include "/include/fragment/aces/matrices.glsl"
#include "/include/fragment/fog.glsl"
#include "/include/fragment/material.glsl"
#include "/include/fragment/textureFormat.glsl"

#include "/include/lighting/lighting.glsl"
#include "/include/lighting/reflections.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/spaceConversion.glsl"
#include "/include/utility/sphericalHarmonics.glsl"

//--// Program //-------------------------------------------------------------//

const float indirectRenderScale = 0.01 * INDIRECT_RENDER_SCALE;

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	/* -- texture fetches -- */

	float depth   = texelFetch(depthtex1, texel, 0).x;
	vec4 overlays = texelFetch(colortex0, texel, 0);
	uvec4 encoded = texelFetch(colortex1, texel, 0);
	radiance      = texelFetch(colortex3, texel, 0).rgb;
	vec3 clearSky = texelFetch(colortex6, texel, 0).rgb;

#ifdef GTAO
	vec4 gtao = texture(colortex10, coord * indirectRenderScale);
#endif

	if (depth == 1.0) return;

	/* -- transformations -- */

	if (linearizeDepth(depth) < MC_HAND_DEPTH) depth += 0.38; // Hand lighting fix from Capt Tatsu

	vec3 positionView  = screenToViewSpace(vec3(coord, depth), true);
	vec3 positionScene = viewToSceneSpace(positionView);
	vec3 positionWorld = positionScene + cameraPosition;

	vec3 viewerDir = normalize(gbufferModelViewInverse[3].xyz - positionScene);

	/* -- unpack gbuffer -- */

	mat2x4 data = mat2x4(
		unpackUnorm4x8(encoded.x),
		unpackUnorm4x8(encoded.y)
	);

	vec3 albedo = data[0].xyz;
	uint blockId = uint(data[0].w * 255.0);
	vec3 geometryNormal = decodeUnitVector(data[1].xy);
	vec2 lmCoord = data[1].zw;

#ifdef MC_NORMAL_MAP
	vec4 normalData = unpackUnormArb(encoded.z, uvec4(12, 12, 7, 1));
	vec3 normal = decodeUnitVector(normalData.xy);
#else
	#define normal geometryNormal
#endif

	uint overlayId = uint(overlays.a + 0.5);
	albedo = overlayId == 0 ? albedo + overlays.rgb : albedo; // enchantment glint
	albedo = overlayId == 1 ? 2.0 * albedo * overlays.rgb : albedo; // damage overlay
	albedo = srgbToLinear(albedo) * r709ToAp1Unlit;

	/* -- fetch ao/sspt -- */

#ifdef GTAO
	float ao = gtao.w;

	vec3 bentNormal;
	bentNormal.xy = gtao.xy * 2.0 - 1.0;
	bentNormal.z  = sqrt(clamp01(1.0 - dot(bentNormal.xy, bentNormal.xy)));

	bentNormal = mat3(gbufferModelViewInverse) * bentNormal;
#else
	float ao = 1.0;
	vec3 bentNormal = normal;
#endif

#if defined SH_SKYLIGHT && defined GTAO
	vec3 skylight = evaluateSphericalHarmonicsIrradiance(skySh, bentNormal, ao);
#else
	vec3 skylight = skyIrradiance * ao;
#endif

	/* -- get material -- */

	Material material = getMaterial(albedo, blockId);

#ifdef MC_SPECULAR_MAP
	vec4 specularTex = unpackUnorm4x8(encoded.w);
	decodeSpecularTex(specularTex, material);
#endif

	/* -- puddles -- */

	getRainPuddles(
		noisetex,
		material.porosity,
		lmCoord,
		positionWorld,
		geometryNormal,
		normal,
		material.albedo,
		material.f0,
		material.roughness
	);
	material.n = f0ToIor(material.f0.x);

	/* -- lighting -- */

	float distanceTraveled;
	radiance = getSceneLighting(
		material,
		positionScene,
		normal,
		geometryNormal,
		bentNormal,
		viewerDir,
		ambientIrradiance,
		directIrradiance,
		skylight,
		lmCoord,
		ao,
		blockId,
		distanceTraveled
	);

	/* -- reflections -- */

#ifdef SSR
	mat3 tbnMatrix = getTbnMatrix(normal);

	vec3 viewerDirTangent = viewerDir * tbnMatrix;

	radiance += getSpecularReflections(
		material,
		tbnMatrix,
		vec3(coord, depth),
		positionView,
		normal,
		viewerDir,
		viewerDirTangent,
		lmCoord.y
	);
#endif

	/* -- fog -- */

	radiance = applySimpleFog(radiance, positionScene, clearSky);
}
