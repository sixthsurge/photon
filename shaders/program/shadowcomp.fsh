/*
 * Program description:
 * Prepare shadowcolor0 for colored shadows, calculate projected caustics
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

layout (location = 0) out vec3 shadowcolor0Out;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D shadowcolor0;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

//--// Shadow uniforms

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

//--// Includes //------------------------------------------------------------//

#include "/include/utility/color.glsl"

//--// Functions //-----------------------------------------------------------//

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	float frontDepth = texelFetch(shadowtex0, texel, 0).x;
	float backDepth  = texelFetch(shadowtex1, texel, 0).x;

	if (frontDepth == backDepth) { shadowcolor0Out = vec3(1.0); return; } // Solid

	vec3 data = texelFetch(shadowcolor0, texel, 0).xyz;

	if (data.x == 1.0) {
		// Water
		// Temp
		shadowcolor0Out = vec3(1.0);
	} else {
		// Translucents
		shadowcolor0Out = data;
	}
}
