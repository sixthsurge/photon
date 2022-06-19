#version 410 compatibility
#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 coord;

flat out vec3 directIrradiance;
flat out vec3 skyIrradiance;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex4; // Sky capture, lighting color palette,

//--// Functions //-----------------------------------------------------------//

void main() {
	coord = gl_MultiTexCoord0.xy;

	directIrradiance = texelFetch(colortex4, ivec2(255, 1), 0).rgb;
	skyIrradiance    = texelFetch(colortex4, ivec2(255, 2), 0).rgb;

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
