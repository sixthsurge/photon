/*
 * Program description:
 * Clears colortex0 so that translucents can write to it
 */

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 0 */
layout (location = 0) out vec4 clear;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Functions //-----------------------------------------------------------//

void main() {
	clear = vec4(0.0);
}
