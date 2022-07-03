#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 texCoord;

flat out uint blockId;
flat out vec3 normal;
flat out vec4 tint;

//--// Inputs //--------------------------------------------------------------//

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

	vec3 shadowViewPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz), shadowClipPos;

	vec3 scenePos  = transform(shadowModelViewInverse, shadowViewPos);
	     scenePos += animateVertex(scenePos + cameraPosition, texCoord.y < mc_midTexCoord.y, rcp(240.0) * gl_MultiTexCoord1.y, blockId);

	shadowViewPos = transform(shadowModelView, scenePos);
	shadowClipPos = projectOrtho(gl_ProjectionMatrix, shadowViewPos);

	float distortionFactor = getShadowDistortionFactor(shadowClipPos.xy);
	shadowClipPos = distortShadowSpace(shadowClipPos, distortionFactor);

	gl_Position = vec4(shadowClipPos, 1.0);
}
