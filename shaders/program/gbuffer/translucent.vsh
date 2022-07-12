#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 texCoord;
out vec2 lmCoord;
out vec3 positionView;
out vec3 positionScene;
out vec3 viewerDirTangent;

flat out uint blockId;
flat out vec4 tint;
flat out mat3 tbnMatrix;

//--// Inputs //--------------------------------------------------------------//

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

//--// Camera uniforms

uniform float near;
uniform float far;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Time uniforms

uniform float frameTimeCounter;

uniform float rainStrength;

//--// Custom uniforms

uniform vec2 taaOffset;

//--// Includes //------------------------------------------------------------//

#include "/block.properties"

#include "/include/utility/spaceConversion.glsl"

#include "/include/vertex/animation.glsl"

//--// Program //-------------------------------------------------------------//

void main() {
	texCoord = gl_MultiTexCoord0.xy;
	lmCoord  = gl_MultiTexCoord1.xy * rcp(240.0);
	tint     = gl_Color;
	blockId  = uint(max0(mc_Entity.x - 10000.0));

	tbnMatrix[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tbnMatrix[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbnMatrix[1] = cross(tbnMatrix[0], tbnMatrix[2]) * sign(at_tangent.w);

	positionView  = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	positionScene = transform(gbufferModelViewInverse, positionView);

	viewerDirTangent = normalize(gbufferModelViewInverse[3].xyz - positionScene) * tbnMatrix;

	vec4 positionClip  = project(gl_ProjectionMatrix, positionView);

#ifdef TAA
    positionClip.xy += taaOffset * positionClip.w;
	positionClip.xy  = positionClip.xy * renderScale + positionClip.w * (renderScale - 1.0);
#endif

	gl_Position = positionClip;
}
