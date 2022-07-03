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

uniform mat4 shadowProjectionInverse;

//--// Custom uniforms

uniform vec2 taaOffset;

uniform vec3 lightDir;

//--// Includes //------------------------------------------------------------//

#include "/include/fragment/waterVolume.glsl"

#include "/include/lighting/shadowDistortion.glsl"

#include "/include/utility/color.glsl"

//--// Program //-------------------------------------------------------------//

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	float depth0 = texelFetch(shadowtex0, texel, 0).x;
	float depth1  = texelFetch(shadowtex1, texel, 0).x;

	if (depth1 <= depth0 + 0.0005) { shadowcolor0Out = vec3(1.0); return; } // Solid

	vec3 data = texelFetch(shadowcolor0, texel, 0).xyz;

	if (data.x == 1.0) {
		float z0 = depth0 * rcp(SHADOW_DEPTH_SCALE) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
		float z1 = depth1 * rcp(SHADOW_DEPTH_SCALE) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
		float distanceTraveled = abs(z1 - z0); // distance traveled through the volume

		shadowcolor0Out = data.y * exp(-waterExtinctionCoeff * distanceTraveled);
	} else {
		// Translucents
		shadowcolor0Out = data;
	}
}
