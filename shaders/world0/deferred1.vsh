#version 410 compatibility
#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 coord;

flat out float cloudsCirrusCoverage;
flat out float cloudsCumulusCoverage;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex4; // Sky capture, color palette and weather properties

//--// Functions //-----------------------------------------------------------//

void main() {
	coord = gl_MultiTexCoord0.xy;

	vec3 weather = texelFetch(colortex4, ivec2(255, 3), 0).rgb;
	cloudsCirrusCoverage = weather.y;
	cloudsCumulusCoverage = weather.z;

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
