#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred3.fsh:
  Shade terrain and entities, draw sky

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:03 */
layout (location = 0) out vec3 fragColor;
layout (location = 3) out vec4 colortex3Clear; // Clear colortex3 so that translucents can write to it

in vec2 uv;

flat in vec3 lightCol;
flat in vec3 skySh[9];
flat in mat2x3 illuminance;

uniform sampler2D noisetex;

uniform sampler2D colortex1; // Gbuffer 0
uniform sampler2D colortex2; // Gbuffer 1
uniform sampler2D colortex3; // Animated overlays/vanilla sky
uniform sampler2D colortex6; // Ambient occlusion

uniform sampler3D depthtex0; // Atmosphere scattering LUT
uniform sampler2D depthtex1;

#ifdef SHADOW
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#ifdef SHADOW_COLOR
uniform sampler2D shadowcolor0;
#endif
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

uniform int worldTime;
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

uniform vec2 viewSize;
uniform vec2 texelSize;
uniform vec2 taaOffset;

uniform float biomeCave;

uniform float timeSunrise;
uniform float timeNoon;
uniform float timeSunset;
uniform float timeMidnight;

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define TEMPORAL_REPROJECTION
#define WORLD_OVERWORLD

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/spaceConversion.glsl"

#include "/include/diffuseLighting.glsl"
#include "/include/fog.glsl"
#include "/include/material.glsl"
#include "/include/shadows.glsl"
#include "/include/sky.glsl"
#include "/include/specularLighting.glsl"

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Texture fetches

	float depth   = texelFetch(depthtex1, texel, 0).x;
	vec4 gbuffer0 = texelFetch(colortex1, texel, 0);
#if defined NORMAL_MAPPING || defined SPECULAR_MAPPING
	vec4 gbuffer1 = texelFetch(colortex2, texel, 0);
#endif
	vec4 overlays = texelFetch(colortex3, texel, 0);

	// Transformations

	depth += 0.38 * float(isHand(depth)); // Hand lighting fix from Capt Tatsu

	vec3 viewPos = screenToViewSpace(vec3(uv, depth), true);
	vec3 scenePos = viewToSceneSpace(viewPos);
	vec3 worldDir = normalize(scenePos - gbufferModelViewInverse[3].xyz);

	if (isSky(depth)) { // Sky
		fragColor = renderSky(worldDir);
	} else { // Terrain
		// Sample half-res lighting data many operations before using it (latency hiding)

		vec2 halfResPos = gl_FragCoord.xy * (0.5 / taauRenderScale) - 0.5;

		ivec2 i = ivec2(halfResPos);
		vec2  f = fract(halfResPos);

		vec4 halfRes00 = texelFetch(colortex6, i + ivec2(0, 0), 0);
		vec4 halfRes10 = texelFetch(colortex6, i + ivec2(1, 0), 0);
		vec4 halfRes01 = texelFetch(colortex6, i + ivec2(0, 1), 0);
		vec4 halfRes11 = texelFetch(colortex6, i + ivec2(1, 1), 0);

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

		albedo = overlays.a < 0.5 ? albedo + overlays.rgb : 2.0 * albedo * overlays.rgb;

		Material material = getMaterial(albedo, blockId, lmCoord);

#ifdef NORMAL_MAPPING
		vec3 normal = decodeUnitVector(gbuffer1.xy);
#else
		#define normal flatNormal
#endif

#ifdef SPECULAR_MAPPING
		vec4 specularTex = vec4(unpackUnorm2x8(gbuffer1.z), unpackUnorm2x8(gbuffer1.w));
		//decodeSpecularTexture(specularTex, material);
#endif

		float NoL = dot(normal, lightDir);
		float NoV = clamp01(dot(normal, -worldDir));
		float LoV = dot(lightDir, -worldDir);
		float halfwayNorm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfwayNorm;
		float LoH = LoV * halfwayNorm + halfwayNorm;

#ifdef GTAO
		// Depth-aware upscaling for GTAO

		float linZ = linearizeDepthFast(depth);

		#define depthWeight(reversedDepth) exp2(-10.0 * abs(linearizeDepthFast(1.0 - reversedDepth) - linZ))

		vec4 gtao = vec4(halfRes00.xyw, 1.0) * depthWeight(halfRes00.z) * (1.0 - f.x) * (1.0 - f.y)
		          + vec4(halfRes10.xyw, 1.0) * depthWeight(halfRes10.z) * (f.x - f.x * f.y)
		          + vec4(halfRes01.xyw, 1.0) * depthWeight(halfRes01.z) * (f.y - f.x * f.y)
		          + vec4(halfRes11.xyw, 1.0) * depthWeight(halfRes11.z) * (f.x * f.y);

		#undef depthWeight

		gtao = (gtao.w == 0.0) ? vec4(0.0) : gtao / gtao.w;

		// Reconstruct bent normal

		float ao = gtao.z;

		vec3 bentNormal;
		bentNormal.xy = gtao.xy * 2.0 - 1.0;
		bentNormal.z = sqrt(max0(1.0 - dot(bentNormal.xy, bentNormal.xy)));
		bentNormal = mat3(gbufferModelViewInverse) * bentNormal;
#else
		#define ao 1.0
		#define bentNormal normal
#endif

		// Terrain diffuse lighting

		float sssDepth;
		vec3 shadows = calculateShadows(scenePos, flatNormal, lmCoord.y, material.sssAmount, sssDepth);

		fragColor = getSceneLighting(
			material,
			normal,
			bentNormal,
			shadows,
			lmCoord,
			ao,
			sssDepth,
			NoL,
			NoV,
			NoH,
			LoV
		);

		fragColor += getSpecularHighlight(material, NoL, NoV, NoH, LoV, LoH) * lightCol * shadows * ao;

		getSimpleFog(fragColor, scenePos, worldDir);
	}

	colortex3Clear = vec4(0.0);
}
