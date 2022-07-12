#version 410 compatibility
#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 texCoord;

flat out vec3 tint;

//--// Uniforms //------------------------------------------------------------//

//--// Custom uniforms

uniform vec2 taaOffset;

//--// Program //-------------------------------------------------------------//

void main() {
	texCoord = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;
	tint     = gl_Color.rgb;

	vec3 positionView = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec4 positionClip = project(gl_ProjectionMatrix, positionView);

#ifdef TAA
    positionClip.xy += taaOffset * positionClip.w;
	positionClip.xy  = positionClip.xy * renderScale + positionClip.w * (renderScale - 1.0);
#endif

	gl_Position = positionClip;
}
