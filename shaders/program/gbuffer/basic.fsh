#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 1 */
layout (location = 0) out uvec2 encoded;

//--// Inputs //--------------------------------------------------------------//

in vec2 lmCoord;

flat in vec3 tint;

//--// Uniforms //------------------------------------------------------------//

uniform vec2 viewTexelSize;

//--// Includes //------------------------------------------------------------//

#include "/include/utility/encoding.glsl"

//--// Program //-------------------------------------------------------------//

void main() {
#if TAA_UPSCALING_FACTOR > 1
	vec2 coord = gl_FragCoord.xy * viewTexelSize;
	if (clamp01(coord) != coord) discard;
#endif

	const vec3 normal = vec3(0.0, 1.0, 0.0);

	mat2x4 data;
	data[0].xyz = tint;
	data[0].w   = 0.0;
	data[1].xy  = encodeUnitVector(normal);
	data[1].zw  = lmCoord;

	encoded.x = packUnorm4x8(data[0]);
	encoded.y = packUnorm4x8(data[1]);
}
