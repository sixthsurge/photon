/*
 * Program description:
 * Temporal filter for HBIL
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 5,10 */
layout (location = 0) out vec4 data;
layout (location = 1) out vec4 irradianceHistory;

//--// Uniforms //-------------------------------------------------------------//

uniform sampler2D depthtex1;

uniform usampler2D colortex1;  // Scene data
uniform sampler2D colortex2;  // Velocity vectors
uniform sampler2D colortex5;  // Indirect lighting data
uniform sampler2D colortex10; // Indirect lighting history
uniform sampler2D colortex13; // Previous frame light levels
uniform sampler2D colortex14; // Temporally stable linear depth

//--// Camera uniforms

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

//--// Custom uniforms

uniform bool worldAgeChanged;

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

//--// Includes //------------------------------------------------------------//

#define TEMPORAL_REPROJECTION

#include "/include/utility/fastMath.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Functions //-----------------------------------------------------------//

const float hbilRenderScale = 0.01 * HBIL_RENDER_SCALE;

ivec2 viewportSize = ivec2(viewSize * hbilRenderScale);

float depthWeight(float z0, float z1, float NoV) {
	const float depthStrictness = 20.0;
	const float depthTolerance  = 0.05;

	float depthDelta = abs(z0 - z1);
	float handWeight = float((z0 < MC_HAND_DEPTH) == (z1 < MC_HAND_DEPTH));

	return exp2(-max0(depthDelta - depthTolerance) * depthStrictness * sqr(NoV)) * handWeight;
}

float normalWeight(vec3 normal0, vec3 normal1) {
	return pow16(abs(dot(normal0, normal1)));
}

float distanceWeight(float dist) {
	const float distanceStrictness = 0.5;

	return exp2(-distanceStrictness * dist);
}

vec2 clipAabb(vec2 q, vec2 aabbMin, vec2 aabbMax, out bool clipped) {
    vec2 pClip = 0.5 * (aabbMax + aabbMin);
    vec2 eClip = 0.5 * (aabbMax - aabbMin);

    vec2 vClip = q - pClip;
    vec2 vUnit = vClip / eClip;
    vec2 aUnit = abs(vUnit);
    float maUnit = maxOf(aUnit);

	clipped = maUnit > 1.0;
    return clipped ? pClip + vClip / maUnit : q;
}

void processSample(inout vec3 irradiance, inout float weightSum, vec4 data, ivec2 offset, float depth, vec3 normal, float NoV) {
	ivec2 texel = offset + ivec2(gl_FragCoord.xy);
	if (clamp(texel, ivec2(0), viewportSize - 1) != texel) return;

	vec3 irradianceSample = decodeRgbe8(vec4(unpackUnorm2x8(data.x), unpackUnorm2x8(data.y)));
	vec3 normalSample = decodeUnitVector(unpackUnorm2x8(data.w));
	float depthSample = data.z * far;

	float depthWeight    = depthWeight(depth, depthSample, NoV);
	float normalWeight   = normalWeight(normal, normalSample);
	float distanceWeight = distanceWeight(length(vec2(offset)));

	float weight = depthWeight * normalWeight * distanceWeight;

	irradiance += weight * irradianceSample;
	weightSum += weight;
}

void main() {
	vec2 coord = gl_FragCoord.xy * viewTexelSize * rcp(hbilRenderScale);

	ivec2 texel     = ivec2(gl_FragCoord.xy);
    ivec2 viewTexel = ivec2(gl_FragCoord.xy * rcp(hbilRenderScale));

	float depth = texelFetch(depthtex1, viewTexel, 0).x;

	if (depth == 1.0 || clamp01(coord) != coord) { data = vec4(0.0); return; }

	vec3 screenPos = vec3(coord, depth);
	vec3 viewPos = screenToViewSpace(screenPos, true);

	//--// Spatial reconstruction

	const ivec2[8] offsets = ivec2[8](
		ivec2(-1,  1),
		ivec2( 0,  1),
		ivec2( 1,  1),
		ivec2(-1,  0),
		ivec2( 1,  0),
		ivec2(-1, -1),
		ivec2( 0, -1),
		ivec2( 1, -1)
	);

    // fetch 3x3 neighborhood
    // a b c
    // d e f
    // g h i
    vec4 a = texelFetch(colortex5, texel + offsets[0], 0);
    vec4 b = texelFetch(colortex5, texel + offsets[1], 0);
    vec4 c = texelFetch(colortex5, texel + offsets[2], 0);
    vec4 d = texelFetch(colortex5, texel + offsets[3], 0);
    vec4 e = texelFetch(colortex5, texel, 0);
    vec4 f = texelFetch(colortex5, texel + offsets[4], 0);
    vec4 g = texelFetch(colortex5, texel + offsets[5], 0);
    vec4 h = texelFetch(colortex5, texel + offsets[6], 0);
    vec4 i = texelFetch(colortex5, texel + offsets[7], 0);

	// decode center sample
	vec3 irradiance = decodeRgbe8(vec4(unpackUnorm2x8(e.x), unpackUnorm2x8(e.y)));
	float weightSum = 1.0;

	vec3 normal = decodeUnitVector(unpackUnorm2x8(e.w));
	vec3 viewNormal = mat3(gbufferModelView) * normal;

	float z = e.z * far;
	float NoV = abs(dot(viewNormal, viewPos) * rcpLength(viewPos));

	// process surrounding samples
	processSample(irradiance, weightSum, a, offsets[0], z, normal, NoV);
	processSample(irradiance, weightSum, b, offsets[1], z, normal, NoV);
	processSample(irradiance, weightSum, c, offsets[2], z, normal, NoV);
	processSample(irradiance, weightSum, d, offsets[3], z, normal, NoV);
	processSample(irradiance, weightSum, f, offsets[4], z, normal, NoV);
	processSample(irradiance, weightSum, g, offsets[5], z, normal, NoV);
	processSample(irradiance, weightSum, h, offsets[6], z, normal, NoV);
	processSample(irradiance, weightSum, i, offsets[7], z, normal, NoV);

	irradiance *= rcp(weightSum);

	//--// Temporal accumulation

	const float smearAmount     = 0.25;
	const float smearStrictness = 0.5;

	bool smear;

	vec3 previousScreenPos = reproject(screenPos, colortex2);
	vec2 previousScreenPosClipped = clipAabb(previousScreenPos.xy, vec2(0.0), vec2(1.0), smear);

	irradianceHistory = texture(colortex10, previousScreenPosClipped * hbilRenderScale);
	if (any(isnan(irradianceHistory))) irradianceHistory = vec4(irradiance, 0.0);

	vec2 lightLevels = unpackUnorm4x8(texelFetch(colortex1, viewTexel, 0).y).zw;
	vec2 previousLightLevels = texture(colortex13, previousScreenPos.xy).zw;
	vec2 lightmapWeight = exp(-40.0 * max0(abs(lightLevels - previousLightLevels) - 0.01) * sqr(NoV));

	float z0 = linearizeDepth(previousScreenPos.z);
	float z1 = texture(colortex14, previousScreenPos.xy).x;
	float depthWeight = depthWeight(z0, z1, NoV);

	float smearDist = distance(previousScreenPos.xy, previousScreenPosClipped);
	float smearWeight = smearAmount * exp2(-smearStrictness * smearDist);

	float pixelAge  = min(irradianceHistory.w, float(HBIL_ACCUMULATION_LIMIT));
	      pixelAge *= smear ? smearWeight : depthWeight * lightmapWeight.x * lightmapWeight.y;
		  pixelAge *= float(!worldAgeChanged);
	      pixelAge += 1.0;

	irradianceHistory.xyz = mix(irradianceHistory.xyz, irradiance, rcp(pixelAge));
	irradianceHistory.w   = pixelAge;

	//--// Pack irradiance and gbuffer data

	vec4 irradianceRgbe8 = encodeRgbe8(irradianceHistory.xyz);

	data.xy = vec2(packUnorm2x8(irradianceRgbe8.xy), packUnorm2x8(irradianceRgbe8.zw));
	data.zw = e.zw;
}
