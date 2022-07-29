/*
 * Program description:
 * Compute horizon-based indirect lighting
 *
 * references:
 * HBIL - https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf
 * GTAO - https://github.com/Patapom/GodComplex/blob/master/Tests/TestHBIL/2018%20Mayaux%20-%20Horizon-Based%20Indirect%20Lighting%20(HBIL).pdf (new paper)
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 5 */
layout (location = 0) out vec4 data;

//--// Inputs //--------------------------------------------------------------//

flat in vec3[9] skySh;

flat in vec3 ambientIrradiance;
flat in vec3 skyIrradiance;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform usampler2D colortex1; // Scene data
uniform sampler2D colortex15; // Reprojected scene history

uniform sampler2D depthtex1;

//--// Camera uniforms

uniform float aspectRatio;

uniform float near;
uniform float far;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Time uniforms

uniform int frameCounter;

//--// Custom uniforms

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform bool worldAgeChanged;

//--// Includes //------------------------------------------------------------//

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/spaceConversion.glsl"
#include "/include/utility/sphericalHarmonics.glsl"

//--// Functions //-----------------------------------------------------------//

const float hbilRenderScale = 0.01 * HBIL_RENDER_SCALE;

// ∫[theta0, theta1] dot(normal, omega_i) * sin(theta) * dtheta
// equation 18 from the paper
float integrateArc(vec2 sliceNormal, vec2 cosTheta) {
	vec2 theta = fastAcos(cosTheta);
	vec2 sinTheta = sqrt(1.0 - sqr(cosTheta));

	float x = theta[1] - theta[0] + sinTheta[0] * cosTheta[0] - sinTheta[1] * cosTheta[1];
	float y = sqr(cosTheta[0]) - sqr(cosTheta[1]);

	return dot(sliceNormal, vec2(x, y)) * 0.5;
}

vec3 integrateNormal(vec3 viewSliceDir, vec3 viewerDir, vec2 cosTheta) {
	vec2 theta = fastAcos(cosTheta) * vec2(1.0, -1.0);
	vec2 sinTheta = sqrt(1.0 - cosTheta * cosTheta) * vec2(1.0, -1.0);

	float x = theta[1] + theta[0] - sinTheta[0] * cosTheta[0] - sinTheta[1] * cosTheta[1]; // (eq. 5)
	float y = 2.0 - sqr(cosTheta[0]) - sqr(cosTheta[1]); // (eq. 6)

	return x * viewSliceDir + y * viewerDir;
}

vec4 horizonSearch(
	inout float maxCosTheta,
	vec3 screenPos,
	vec3 viewPos,
	vec3 viewSliceDir,
	vec3 viewerDir,
	vec2 sliceNormal,
	float maxRadius,
	float dither
) {
	const uint stepCount = HBIL_HORIZON_STEPS;

	const float stepGrowth = 1.0;
	const float stepCoeff  = (stepGrowth - 1.0) / (pow(stepGrowth, float(stepCount)) - 1.0);

	float stepSize = maxRadius * (stepGrowth != 1.0 ? stepCoeff : rcp(float(stepCount)));

	vec2 rayStep = (viewToScreenSpace(viewPos + viewSliceDir * stepSize, true) - screenPos).xy;
	vec2 rayPos  = screenPos.xy + maxOf(viewTexelSize) * normalize(rayStep);

	vec4 irradiance = vec4(0.0);

	for (int i = 0; i < stepCount; ++i, rayPos += rayStep) {
		vec2 ditheredPos = rayPos + rayStep * stepGrowth * dither;

		float depth = texelFetch(depthtex1, ivec2(ditheredPos * viewSize - 0.5), 0).x;

		if (depth == screenPos.z || depth == 1.0 || depth < handDepth) continue;

		vec3 offset = screenToViewSpace(vec3(ditheredPos, depth), true) - viewPos;

		float lenSq = lengthSquared(offset);
		float cosTheta = dot(viewerDir, offset) * inversesqrt(lenSq);

		float distanceFade = linearStep(0.7 * HBIL_RADIUS, HBIL_RADIUS, sqrt(lenSq));
		//cosTheta = mix(cosTheta, -1.0, distanceFade);

		if (cosTheta <= maxCosTheta) continue;

		float arcIntegral = integrateArc(sliceNormal, vec2(cosTheta, maxCosTheta));

		vec3 radiance = texture(colortex15, clamp01(ditheredPos) * vec2(1.0, 0.5)).rgb * (1.0 - distanceFade);

		irradiance += arcIntegral * vec4(radiance, 1.0);

		maxCosTheta = cosTheta;

		rayStep *= stepGrowth;
	}

	return max0(irradiance);
}

vec4 calculateHbil(
	vec3 screenPos,
	vec3 viewPos,
	vec3 viewNormal,
	vec2 rng,
	out vec3 bentNormal
) {
	float rcpViewDistance = rcpLength(viewPos);
	float maxRadius = HBIL_RADIUS;

	bentNormal = vec3(0.0);

	// Set up local camera space (Section 1.1)
	vec3 viewerDir = viewPos * -rcpViewDistance;
	vec3 lcsX = normalize(cross(vec3(0.0, 1.0, 0.0), viewerDir));
	vec3 lcsY = cross(viewerDir, lcsX);
	mat3 lcsToView = mat3(lcsX, lcsY, viewerDir); // Since lcsToView is a rotation matrix, viewToLcs = transpose(lcsToView)

	vec4 irradiance = vec4(0.0); // irradiance (rgb), ao (a)

	for (int i = 0; i < HBIL_SLICES; ++i) {
		float sliceAngle = (i + rng.x) * (pi / float(HBIL_SLICES));

		vec3 sliceDir = vec3(cos(sliceAngle), sin(sliceAngle), 0.0);
		vec3 viewSliceDir = lcsToView * sliceDir;

		// Set up slice space (Section 1.2)
		mat2x3 sliceToView = mat2x3(viewSliceDir, viewerDir);

		// Project normal vector into slice space
		vec2 sliceNormal = viewNormal * sliceToView;

		// Initialize horizon angles using the normal (Section 2.1)
		float t = -sliceNormal.x / sliceNormal.y;
		vec2 cosTheta = t * inversesqrt(1.0 + sqr(t)) * vec2(1.0, -1.0);

		// Carry out horizon search in each direction
		irradiance += horizonSearch(cosTheta.x, screenPos, viewPos,  viewSliceDir, viewerDir,                   sliceNormal, maxRadius, rng.y);
		irradiance += horizonSearch(cosTheta.y, screenPos, viewPos, -viewSliceDir, viewerDir, vec2(-1.0, 1.0) * sliceNormal, maxRadius, rng.y);

		// Update bent normal with new horizon angles
		bentNormal += integrateNormal(viewSliceDir, viewerDir, cosTheta);
	}

	bentNormal = mat3(gbufferModelViewInverse) * normalize(bentNormal);

	return irradiance * (pi / float(HBIL_SLICES));
}

float getBlocklightFalloff(float blocklight, float ao) {
	float falloff  = rcp(sqr(16.0 - 15.0 * blocklight));
	      falloff  = linearStep(rcp(sqr(16.0)), 1.0, falloff);
	      falloff *= mix(ao, 1.0, falloff);

	return falloff;
}

float getSkylightFalloff(float skylight) {
	return pow4(skylight);
}

void main() {
#ifndef HBIL
	#error "This program should be disabled if HBIL is disabled"
#endif

	ivec2 texel     = ivec2(gl_FragCoord.xy);
    ivec2 viewTexel = ivec2(gl_FragCoord.xy * rcp(hbilRenderScale));

	vec2 coord = gl_FragCoord.xy * viewTexelSize * rcp(hbilRenderScale);

	if (clamp01(coord) != coord) discard;

	/* -- texture fetches -- */

	float depth   = texelFetch(depthtex1, viewTexel, 0).x;
	uvec3 encoded = texelFetch(colortex1, viewTexel, 0).xyz;
	vec2 dither   = vec2(texelFetch(noisetex, texel & 511, 0).b, texelFetch(noisetex, (texel + 249) & 511, 0).b);

	if (depth == 1.0) { data = vec4(0.0); return; }
	if (depth < handDepth) depth += 0.38; // Hand lighting fix from Capt Tatsu

	/* -- transformations  -- */

	vec3 screenPos = vec3(coord, depth);
	vec3 viewPos = screenToViewSpace(screenPos, true);
	vec3 viewerDir = normalize(viewPos);

	/* -- unpack gbuffer  -- */

	vec2 lmCoord = unpackUnorm4x8(encoded.y).zw;

#ifdef MC_NORMAL_MAP
	vec4 normalData = unpackUnormArb(encoded.z, uvec4(12, 12, 7, 1));
	vec2 encodedNormal = normalData.xy;
#else
	vec2 encodedNormal = unpackUnorm4x8(encoded.y).xy;
#endif

	vec3 worldNormal = decodeUnitVector(encodedNormal);
	vec3 viewNormal  = mat3(gbufferModelView) * worldNormal;

	/* -- indirect lighting -- */

	vec2 rng = R2(frameCounter, dither);

	vec3 bentNormal;
	vec4 hbil = calculateHbil(screenPos, viewPos, viewNormal, rng, bentNormal);

	vec3 irradiance = hbil.xyz;
	float visibility = 1.0 - hbil.w * rcpPi;

	// Blocklight

	vec3 blocklightColor = blackbody(BLOCKLIGHT_TEMPERATURE);
	float blocklightFalloff = getBlocklightFalloff(lmCoord.x, visibility);
	irradiance += 32.0 * blocklightColor * blocklightFalloff;

	// Skylight

	vec3 skylight = evaluateSphericalHarmonicsIrradiance(skySh, bentNormal, visibility);

	irradiance += skylight * pow4(lmCoord.y);

	// Ambient light

	irradiance += ambientIrradiance * visibility;

	/* -- pack irradiance and gbuffer data -- */

	vec4 irradianceRgbe8 = encodeRgbe8(irradiance);

	data.x = packUnorm2x8(irradianceRgbe8.xy);
	data.y = packUnorm2x8(irradianceRgbe8.zw);
	data.z = clamp01(linearizeDepth(depth) * rcp(far));
	data.w = packUnorm2x8(encodedNormal);
}
