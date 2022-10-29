#version 410 compatibility
#include "/include/global.glsl"

out vec2 uv;

flat out vec3 tint;

uniform vec2 taaOffset;

void main() {
	uv   = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;
	tint = gl_Color.rgb;

	vec3 viewPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec4 clipPos = project(gl_ProjectionMatrix, viewPos);

#if   defined TAA && defined TAAU
	clipPos.xy  = clipPos.xy * taauRenderScale + clipPos.w * (taauRenderScale - 1.0);
	clipPos.xy += taaOffset * clipPos.w;
#elif defined TAA
	clipPos.xy += taaOffset * clipPos.w * 0.75;
#endif

	gl_Position = clipPos;
}
