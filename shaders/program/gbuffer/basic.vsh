/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/basic.vsh:
  Handle lines

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

flat out vec2 lightLevels;
flat out vec3 tint;

uniform vec2 taaOffset;
uniform vec2 viewSize;
uniform vec2 texelSize;

void main() {
	lightLevels = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	tint        = gl_Color.rgb;

#if defined PROGRAM_LINE
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
	vec2 lineOffset = vec2(-lineScreenDir.y, lineScreenDir.x) * lineWidth * texelSize;

	if (lineOffset.x < 0.0) lineOffset *= -1.0;

	vec4 clipPos = (gl_VertexID & 1) == 0
		? vec4((ndc1 + vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w)
		: vec4((ndc1 - vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
#else
	vec3 viewPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec4 clipPos = project(gl_ProjectionMatrix, viewPos);
#endif

#if   defined TAA && defined TAAU
	clipPos.xy  = clipPos.xy * taauRenderScale + clipPos.w * (taauRenderScale - 1.0);
	clipPos.xy += taaOffset * clipPos.w;
#elif defined TAA
	clipPos.xy += taaOffset * clipPos.w * 0.75;
#endif

	gl_Position = clipPos;
}
