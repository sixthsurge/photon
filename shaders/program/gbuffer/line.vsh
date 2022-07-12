#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 lmCoord;

flat out vec3 tint;

//--// Uniforms //------------------------------------------------------------//

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

//--// Program //-------------------------------------------------------------//

void main() {
	lmCoord = gl_MultiTexCoord1.xy * rcp(240.0);
	tint    = gl_Color.rgb;

#if defined GBUFFERS_LINE
	// Ripped from vanilla 1.17's rendertype_lines.vsh

	const float viewShrink = 1.0 - (1.0 / 256.0);
	const mat4 viewScale = mat4(
		viewShrink, 0.0, 0.0, 0.0,
		0.0, viewShrink, 0.0, 0.0,
		0.0, 0.0, viewShrink, 0.0,
		0.0, 0.0, 0.0, 1.0
	);

	const float lineWidth = 2.0;

	vec4 linePosStart = vec4(gl_Vertex.xyz, 1.0);
	     linePosStart = gl_ProjectionMatrix * viewScale * gl_ModelViewMatrix * linePosStart;
	vec4 linePosEnd = vec4(gl_Vertex.xyz + gl_Normal, 1.0);
	     linePosEnd = gl_ProjectionMatrix * viewScale * gl_ModelViewMatrix * linePosStart;

	vec3 ndc1 = linePosStart.xyz / linePosStart.w;
	vec3 ndc2 = linePosEnd.xyz / linePosEnd.w;

	vec2 lineScreenDir = normalize((ndc2.xy - ndc1.xy) * viewSize);
	vec2 lineOffset = vec2(-lineScreenDir.y, lineScreenDir.x) * lineWidth * viewTexelSize;

	if (lineOffset.x < 0.0) lineOffset *= -1.0;

	vec4 positionClip = (gl_VertexID & 1) == 0
		? vec4((ndc1 + vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w)
		: vec4((ndc1 - vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
#else
	vec3 positionView = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec4 positionClip = project(gl_ProjectionMatrix, positionView);
#endif

#ifdef TAA
    positionClip.xy += taaOffset * positionClip.w;
	positionClip.xy  = positionClip.xy * renderScale + positionClip.w * (renderScale - 1.0);
#endif

	gl_Position = positionClip;
}
