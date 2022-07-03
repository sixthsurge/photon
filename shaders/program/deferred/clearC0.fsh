/*
 * Program description:
 * Clears colortex0 so that translucents can write to it
 */

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 0 */
layout (location = 0) out vec4 colortex0Clear;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Program //-------------------------------------------------------------//

void main() {
	colortex0Clear = vec4(0.0);
}
