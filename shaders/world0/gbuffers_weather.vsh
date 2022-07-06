#version 410 compatibility
#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 uv;
out vec4 tint;

//--// Uniforms //------------------------------------------------------------//

//--// Camera uniforms

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

//--// Program //-------------------------------------------------------------//

const float rainTiltAmount = 0.2;

void main() {
	uv     = gl_MultiTexCoord0.xy;
	tint   = gl_Color;

	vec3 viewPos  = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec3 scenePos = transform(gbufferModelViewInverse, viewPos);
	vec3 worldPos = scenePos + cameraPosition;

	float tiltWave = 0.7 + 0.3 * sin(5.0 * (worldPos.x + worldPos.y + worldPos.z));
	scenePos.xz -= rainTiltAmount * tiltWave * scenePos.y;

	viewPos       = transform(gbufferModelView, scenePos);
	vec4 clipPos  = project(gl_ProjectionMatrix, viewPos);

#ifdef TAA
	clipPos.xy  = clipPos.xy * renderScale + clipPos.w * (renderScale - 1.0);
#endif

	gl_Position = clipPos;
}
