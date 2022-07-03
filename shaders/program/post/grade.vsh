/*
 * Program description:
 * Pass global exposure and white balance matrix to fragment stage
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 coord;

flat out float globalExposure;
flat out mat3 whiteBalanceMatrix;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex8; // Anti-aliased color and exposure

//--// Includes //------------------------------------------------------------//

#include "/include/fragment/aces/matrices.glsl"
#include "/include/fragment/aces/utility.glsl"

//--// Program //-------------------------------------------------------------//

mat3 getWhiteBalanceMatrix(const float whiteBalance) {
	vec3 srcXyz = blackbody(whiteBalance) * ap1ToXyz;
	vec3 dstXyz = blackbody(      6500.0) * ap1ToXyz;
	mat3 cat = getChromaticAdaptationMatrix(srcXyz, dstXyz);

	return ap1ToXyz * cat * xyzToAp1;
}

void main() {
	coord = gl_MultiTexCoord0.xy;

	globalExposure = texelFetch(colortex8, ivec2(0), 0).a;

#ifdef GRADE
	whiteBalanceMatrix = getWhiteBalanceMatrix(GRADE_WHITE_BALANCE);
#endif

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
