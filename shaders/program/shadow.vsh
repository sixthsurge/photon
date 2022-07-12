#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 texCoord;
out vec3 positionWorld;

flat out uint blockId;
flat out vec3 normal;
flat out vec4 tint;
flat out mat3 tbnMatrix;

//--// Inputs //--------------------------------------------------------------//

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

//--// Camera uniforms

uniform vec3 cameraPosition;

//--// Shadow uniforms

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

//--// Time uniforms

uniform float frameTimeCounter;

uniform float rainStrength;

//--// Includes //------------------------------------------------------------//

#include "/block.properties"

#include "/include/lighting/shadowDistortion.glsl"

#include "/include/vertex/animation.glsl"

//--// Program //-------------------------------------------------------------//

void main() {
	texCoord = gl_MultiTexCoord0.xy;
	blockId  = uint(mc_Entity.x - 10000.0);
	normal   = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tint     = gl_Color;

#ifdef WATER_CAUSTICS
	tbnMatrix[0] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbnMatrix[1] = cross(tbnMatrix[0], normal) * sign(at_tangent.w);
	tbnMatrix[2] = normal;
#endif

	vec3 positionShadowView = transform(gl_ModelViewMatrix, gl_Vertex.xyz), positionShadowClip;

	vec3 positionScene = transform(shadowModelViewInverse, positionShadowView);

	positionWorld  = positionScene + cameraPosition;
	positionWorld += animateVertex(positionWorld, texCoord.y < mc_midTexCoord.y, rcp(240.0) * gl_MultiTexCoord1.y, blockId);
	positionScene  = positionWorld - cameraPosition;

	positionShadowView = transform(shadowModelView, positionScene);
	positionShadowClip = projectOrtho(gl_ProjectionMatrix, positionShadowView);

	float distortionFactor = getShadowDistortionFactor(positionShadowClip.xy);
	positionShadowClip = distortShadowSpace(positionShadowClip, distortionFactor);

	gl_Position = vec4(positionShadowClip, 1.0);
}
