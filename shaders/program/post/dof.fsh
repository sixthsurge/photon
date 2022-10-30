/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/fxaa.fsh
  Calculate depth of field

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 fragColor;

in vec2 uv;

uniform sampler2D noisetex;

uniform sampler2D colortex0;

uniform sampler2D depthtex0;

uniform mat4 gbufferProjection;

uniform float near, far;

uniform float aspectRatio;
uniform float centerDepthSmooth;

uniform int frameCounter;

#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"

float reverseLinearDepth(float linearZ) {
	return (far + near) / (far - near) + (2.0 * far * near) / (linearZ * (far - near));
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	float depth = texelFetch(depthtex0, texel, 0).x;

	if (isHand(depth)) {
		fragColor = texelFetch(colortex0, texel, 0).rgb;
		return;
	};

	// Calculate vogel disk rotation
	float theta  = texelFetch(noisetex, texel & 511, 0).b;
	      theta  = R1(frameCounter, theta);
	      theta *= tau;

	// Calculate circle of confusion
	float focus = DOF_FOCUS < 0.0 ? centerDepthSmooth : reverseLinearDepth(DOF_FOCUS);
	vec2 CoC = min(abs(depth - focus), 0.1) * (DOF_INTENSITY * 0.2 / 1.37) * vec2(1.0, aspectRatio) * gbufferProjection[1][1];

	fragColor = vec3(0.0);

	for (int i = 0; i < DOF_SAMPLES; ++i) {
		vec2 offset = vogelDiskSample(i, DOF_SAMPLES, theta);
		fragColor += textureLod(colortex0, uv + offset * CoC, 0).rgb;
	}

	fragColor *= rcp(DOF_SAMPLES);
}
