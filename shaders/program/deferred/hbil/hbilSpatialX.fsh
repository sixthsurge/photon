/*
 * Program description:
 * Spatial filter for HBIL - horizontal pass
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 5 */
layout (location = 0) out vec4 data;

//--// Uniforms //-------------------------------------------------------------//

uniform sampler2D depthtex1;

uniform sampler2D colortex5;  // Indirect lighting data
uniform sampler2D colortex10; // Indirect lighting history

//--// Camera uniforms

uniform float near;
uniform float far;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Custom uniforms

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

//--// Includes //------------------------------------------------------------//

#include "/include/utility/fastMath.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Functions //-----------------------------------------------------------//

const float hbilRenderScale = 0.01 * HBIL_RENDER_SCALE;

ivec2 viewportSize = ivec2(viewSize * hbilRenderScale);

float depthWeight(float z0, float z1, float NoV) {
	const float depthStrictness = 10.0;
	const float depthTolerance  = 0.05;

	float depthDelta = abs(z0 - z1);
	float handWeight = float((z0 < MC_HAND_DEPTH) == (z1 < MC_HAND_DEPTH));

	return exp2(-max0(depthDelta - depthTolerance) * depthStrictness * sqr(NoV)) * handWeight;
}

float normalWeight(vec3 normal0, vec3 normal1) {
	return pow16(abs(dot(normal0, normal1)));
}

vec4 weighHbilSample(vec4 data, vec3 normal, float z0, float offset, float NoV, float sigma) {
	const float depthStrictness = 10.0;
	const float depthTolerance  = 0.005;

	bool isSky = data.x == 0.0;

	if (!isSky) {
		vec3 irradianceSample = decodeRgbe8(vec4(unpackUnorm2x8(data.x), unpackUnorm2x8(data.y)));
		vec3 normalSample = decodeUnitVector(unpackUnorm2x8(data.w));

		float z1 = data.z * far;

		float weight  = exp(-sigma * offset);
		      weight *= depthWeight(z0, z1, NoV);
		      weight *= normalWeight(normal, normalSample);

		return vec4(irradianceSample, 1.0) * weight;
	} else {
		return vec4(0.0);
	}
}

const ivec2[7] offsets = ivec2[7](
	ivec2(-3,  0),
	ivec2(-2,  0),
	ivec2(-1,  0),
	ivec2( 0,  0),
	ivec2( 1,  0),
	ivec2( 2,  0),
	ivec2( 3,  0)
);

void main() {
	vec2 coord = gl_FragCoord.xy * viewTexelSize * rcp(hbilRenderScale);

	ivec2 texel     = ivec2(gl_FragCoord.xy);
    ivec2 viewTexel = ivec2(gl_FragCoord.xy * rcp(hbilRenderScale));

	float depth = texelFetch(depthtex1, viewTexel, 0).x;

	if (depth == 1.0 || clamp01(coord) != coord) { data = vec4(0.0); return; }

	vec3 screenPos = vec3(coord, depth);
	vec3 viewPos = screenToViewSpace(screenPos, true);

	// fetch samples
    vec4 a = texelFetch(colortex5, texel + offsets[0], 0);
    vec4 b = texelFetch(colortex5, texel + offsets[1], 0);
    vec4 c = texelFetch(colortex5, texel + offsets[2], 0);
    vec4 d = texelFetch(colortex5, texel + offsets[3], 0);
    vec4 e = texelFetch(colortex5, texel + offsets[4], 0);
    vec4 f = texelFetch(colortex5, texel + offsets[5], 0);
    vec4 g = texelFetch(colortex5, texel + offsets[6], 0);

	// decode center sample
	vec3 irradiance = decodeRgbe8(vec4(unpackUnorm2x8(d.x), unpackUnorm2x8(d.y)));

	vec3 normal = decodeUnitVector(unpackUnorm2x8(d.w));
	vec3 viewNormal = mat3(gbufferModelView) * normal;

	float z = d.z * far;
	float NoV = abs(dot(viewNormal, viewPos) * rcpLength(viewPos));

	// adjust blur strength based on pixel age
	float pixelAge = texelFetch(colortex10, texel, 0).w;
	float blurSigma = 0.0025 * sqrt(pixelAge) + 0.004 * pixelAge;

	// horizontal blur
	vec4 result  = vec4(irradiance, 1.0);
	     result += weighHbilSample(a, normal, z, 3.0, NoV, blurSigma);
	     result += weighHbilSample(b, normal, z, 2.0, NoV, blurSigma);
	     result += weighHbilSample(c, normal, z, 1.0, NoV, blurSigma);
	     result += weighHbilSample(e, normal, z, 1.0, NoV, blurSigma);
	     result += weighHbilSample(f, normal, z, 2.0, NoV, blurSigma);
	     result += weighHbilSample(g, normal, z, 3.0, NoV, blurSigma);

	result.xyz /= result.w;

	// pack irradiance and gbuffer data

	vec4 irradianceRgbe8 = encodeRgbe8(result.xyz);

	data.x  = packUnorm2x8(irradianceRgbe8.xy);
	data.y  = packUnorm2x8(irradianceRgbe8.zw);
	data.zw = e.zw;
}
