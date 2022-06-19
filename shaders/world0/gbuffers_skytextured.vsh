#version 410 compatibility
#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 texCoord;

flat out vec3 tint;

//--// Uniforms //------------------------------------------------------------//

//--// Custom uniforms

uniform vec2 taaOffset;

//--// Functions //-----------------------------------------------------------//

void main() {
	texCoord = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;
	tint     = gl_Color.rgb;

	vec3 viewPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec4 clipPos = project(gl_ProjectionMatrix, viewPos);

#ifdef TAA
    clipPos.xy += taaOffset * clipPos.w;
	clipPos.xy  = clipPos.xy * renderScale + clipPos.w * (renderScale - 1.0);
#endif

	gl_Position = clipPos;
}
