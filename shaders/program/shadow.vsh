#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 texCoord;

flat out uint blockId;
flat out vec3 normal;
flat out vec4 tint;

//--// Inputs //--------------------------------------------------------------//

#define attribute in
attribute vec3 mc_Entity;

//--// Uniforms //------------------------------------------------------------//

uniform mat4 shadowModelViewInverse;

//--// Includes //------------------------------------------------------------//

#include "/block.properties"

#include "/include/lighting/shadowDistortion.glsl"

//--// Functions //-----------------------------------------------------------//

void main() {
	texCoord = gl_MultiTexCoord0.xy;
	blockId  = uint(mc_Entity.x - 10000.0);
	normal   = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tint     = gl_Color;

	vec3 shadowViewPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec3 shadowClipPos = projectOrtho(gl_ProjectionMatrix, shadowViewPos);

	float distortionFactor = getShadowDistortionFactor(shadowClipPos.xy);
	shadowClipPos = distortShadowSpace(shadowClipPos, distortionFactor);

	gl_Position = vec4(shadowClipPos, 1.0);
}
