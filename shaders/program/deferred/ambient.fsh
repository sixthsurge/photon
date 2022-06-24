/*
 * Program description:
 * Calculate ambient lighting; SSPT or GTAO
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

#ifdef SSPT
/* RENDERTARGETS: 5,9,10 */
layout (location = 0) out vec4 data;
layout (location = 1) out vec3 historyIrradiance;
layout (location = 2) out vec4 historyData;
#else
/* RENDERTARGETS: 10 */
layout (location = 0) out vec4 historyData;
#endif

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform usampler2D colortex1; // Scene data
uniform sampler2D colortex2;  // Motion vectors
uniform sampler2D colortex4;  // Sky capture
uniform sampler2D colortex8;  // Scene history
uniform sampler2D colortex9;  // History irradiance
uniform sampler2D colortex10; // History data
uniform sampler2D colortex13; // Previous frame depth

uniform sampler2D depthtex1;

//--// Camera uniforms

uniform float aspectRatio;

uniform float near;
uniform float far;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

//--// Time uniforms

uniform int frameCounter;

//--// Custom uniforms

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform bool worldAgeChanged;

//--// Includes //------------------------------------------------------------//

#define RAYTRACE_REVERSE_Z
#define TEMPORAL_REPROJECTION

#include "/include/atmospherics/skyProjection.glsl"

#include "/include/fragment/raytracer.glsl"

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/spaceConversion.glsl"
#include "/include/utility/sphericalHarmonics.glsl"

//--// Functions //-----------------------------------------------------------//

/*
 * data packing:
 *
 * GTAO:
 * colortex10
 * x: bent normal X
 * y: bent normal Y
 * z: pixelAge
 * w: visibility
 *
 * SSPT:
 */

const float indirectRenderScale = 0.01 * INDIRECT_RENDER_SCALE;

#ifdef SSPT
#endif

#ifdef GTAO
float integrateArc(vec2 h, float n, float cosN) {
	vec2 tmp = cosN + 2.0 * h * sin(n) - cos(2.0 * h - n);
	return 0.25 * (tmp.x + tmp.y);
}

float calculateMaximumHorizonAngle(
	vec3 sliceDir,
	vec3 viewDir,
	vec3 screenPos,
	vec3 viewPos,
	vec2 radius,
	float dither
) {
	float maxHorizonCosine = -1.0;

	vec2 stepSize = radius * (1.0 / float(GTAO_HORIZON_STEPS));
	vec2 rayStep = sliceDir.xy * stepSize;

	screenPos.xy += sliceDir.xy * (stepSize * dither + length(viewTexelSize) * sqrt(2.0));

	for (int i = 0; i < GTAO_HORIZON_STEPS; ++i, screenPos.xy += rayStep) {
		float depth = texelFetch(depthtex1, ivec2(clamp01(screenPos.xy) * viewSize - 0.5), 0).x;

		if (depth == screenPos.z || depth == 1.0 || linearizeDepth(depth) < MC_HAND_DEPTH) continue;

		vec3 viewSampleVec = screenToViewSpace(vec3(screenPos.xy, depth), true) - viewPos;

		float lenSq = dot(viewSampleVec, viewSampleVec);
		float falloff = linearStep(1.0, 2.0, lenSq);
		float cosTheta = dot(viewDir, viewSampleVec) * inversesqrt(lenSq);
		      cosTheta = mix(cosTheta, -1.0, falloff);

		const float beta = 0.0;

		maxHorizonCosine = cosTheta < maxHorizonCosine
			? maxHorizonCosine - beta
			: cosTheta;
	}

	return acosApprox(clamp(maxHorizonCosine, -1.0, 1.0));
}

float multiBounceApprox(float visibility) {
	const float albedo = 0.2;
	return visibility / (albedo * visibility + (1.0 - albedo));
}

vec4 calculateGtao(
	vec3 screenPos,
	vec3 viewPos,
	vec3 normalView,
	vec2 rng
) {
	float rcpViewDistance = inversesqrt(dot(viewPos, viewPos));

	vec3 viewDir = viewPos * -rcpViewDistance;

	vec2 radius = GTAO_RADIUS * rcpViewDistance / vec2(1.0, aspectRatio);

	float visibility = 0.0;
	vec3 bentNormal = vec3(0.0);

	for (int i = 0; i < GTAO_SLICES; ++i) {
		float sliceAngle = (i + rng.x) * (pi / float(GTAO_SLICES));

		vec3 sliceDir = vec3(cos(sliceAngle), sin(sliceAngle), 0.0);

		vec3 orthoDir = sliceDir - dot(sliceDir, viewDir) * viewDir;
		vec3 axis = cross(sliceDir, viewDir);
		vec3 projectedNormal = normalView - axis * dot(normalView, axis);

		float lenSq = dot(projectedNormal, projectedNormal);
		float norm = inversesqrt(lenSq);

		float sgnGamma = sign(dot(orthoDir, projectedNormal));
		float cosGamma = clamp01(dot(projectedNormal, viewDir) * norm);
		float gamma = sgnGamma * acosApprox(cosGamma);

		vec2 maxHorizonAngles;
		maxHorizonAngles.x = calculateMaximumHorizonAngle(-sliceDir, viewDir, screenPos, viewPos, radius, rng.y);
		maxHorizonAngles.y = calculateMaximumHorizonAngle( sliceDir, viewDir, screenPos, viewPos, radius, rng.y);

		maxHorizonAngles = gamma + clamp(vec2(-1.0, 1.0) * maxHorizonAngles - gamma, -halfPi, halfPi);
		visibility += integrateArc(maxHorizonAngles, gamma, cosGamma) * lenSq * norm;

		float bentAngle = dot(maxHorizonAngles, vec2(0.5));
		bentNormal += viewDir * cos(bentAngle) + orthoDir * sin(bentAngle);
	}

	visibility = multiBounceApprox(visibility * (1.0 / float(GTAO_SLICES)));
	bentNormal = normalize(normalize(bentNormal) - 0.5 * viewDir);
	bentNormal = bentNormal;

    return vec4(bentNormal, visibility);
}
#endif

void main() {
	ivec2 srcTexel = ivec2(gl_FragCoord.xy);
    ivec2 dstTexel = ivec2(gl_FragCoord.xy * (renderScale / indirectRenderScale));

	if (clamp(dstTexel, ivec2(0), ivec2(viewSize)) != dstTexel) discard;

	float depth   = texelFetch(depthtex1, dstTexel, 0).x;
	uvec3 encoded = texelFetch(colortex1, dstTexel, 0).xyz;
	float dither  = texelFetch(noisetex, srcTexel & 511, 0).b;

	if (linearizeDepth(depth) < MC_HAND_DEPTH) depth += 0.38; // hand lighting fix from Capt Tatsu

	vec3 screenPos = vec3(coord * rcp(indirectRenderScale), depth);
	vec3 viewPos = screenToViewSpace(screenPos, true);
	vec3 viewDir = normalize(viewPos);

	if (depth == 1.0) { historyData = vec4(0.5, 0.5, 0.0, 1.0); return; }

#ifdef MC_NORMAL_MAP
	vec4 normalData = unpackUnormArb(encoded.z, uvec4(12, 12, 7, 1));
	vec3 normal = decodeUnitVector(normalData.xy);
#else
	vec3 normal = decodeUnitVector(unpackUnorm4x8(encoded.y).xy);
#endif

	vec3 viewNormal = mat3(gbufferModelView) * normal;

#if   defined SSPT

#elif defined GTAO
    vec4 gtao = calculateGtao(
        screenPos,
        viewPos,
        viewNormal,
        R2(frameCounter, vec2(dither))
    );

	//--// Temporal accumulation

    vec3 previousScreenPos = reproject(screenPos, colortex2);

	historyData = textureSmooth(colortex10, previousScreenPos.xy * indirectRenderScale);
	float historyDepth = 1.0 - textureSmooth(colortex13, previousScreenPos.xy).y;

	float depthDelta  = abs(linearizeDepth(depth) - linearizeDepth(historyDepth));
	float depthWeight = exp(-10.0 * depthDelta) * float(historyDepth < 1.0);

	float pixelAge  = min(historyData.z * 65535.0, float(GTAO_ACCUMULATED_FRAMES));
	      pixelAge *= float(clamp01(previousScreenPos.xy) == previousScreenPos.xy);
		  pixelAge *= depthWeight;

	float historyWeight = pixelAge / (pixelAge + 1.0);

	// Reconstruct bent normal
	historyData.xy = historyData.xy * 2.0 - 1.0;
	historyData.z  = sqrt(clamp01(1.0 - dot(historyData.xy, historyData.xy)));

	// Blend with previous frame
	historyData.xyz = mix(gtao.xyz, historyData.xyz, historyWeight);
	historyData.w   = mix(gtao.w, historyData.w, historyWeight);

	// Store data for next frame
	historyData.xy *= rcpLength(historyData.xyz);
	historyData.xy  = historyData.xy * 0.5 + 0.5;
	historyData.z   = clamp01(pixelAge * rcp(65535.0) + rcp(65535.0));
#endif
}
