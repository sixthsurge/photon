/*
 * Program description:
 * Resize image to 960x540 (fixed-size first bloom tile)
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 15 */
layout (location = 0) out vec3 bloom;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex8; // Scene history

//--// Includes //------------------------------------------------------------//

#include "/include/utility/bicubic.glsl"

//--// Program //-------------------------------------------------------------//

/*
const bool colortex8MipMapEnabled = true;
*/

void main() {
#ifndef BLOOM
	#error "This program should be disabled if bloom is disabled"
#endif

	if (coord.y < 0.5) {
		vec2 windowCoord = vec2(1.0, 2.0) * coord;

		int lod = int(textureQueryLod(colortex8, windowCoord).x);
		bloom = textureBicubicLod(colortex8, windowCoord, lod).rgb;
	}
}
