#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 texCoord;
out vec2 lmCoord;
out vec4 tint;

flat out uint blockId;
flat out mat3 tbnMatrix;

#if defined GBUFFERS_ENTITIES
out vec3 velocity;
#endif

//--// Inputs //--------------------------------------------------------------//

#define attribute in
attribute vec4 at_tangent;
attribute vec3 at_velocity;
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

//--// Functions //-----------------------------------------------------------//

void main() {
	texCoord = gl_MultiTexCoord0.xy;
	lmCoord  = gl_MultiTexCoord1.xy * rcp(240.0);
	tint     = gl_Color;
	blockId  = uint(max0(mc_Entity.x - 10000.0));

	tbnMatrix[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
#ifdef MC_NORMAL_MAP
	tbnMatrix[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbnMatrix[1] = cross(tbnMatrix[0], tbnMatrix[2]) * sign(at_tangent.w);
#endif

#if defined GBUFFERS_ENTITIES
	velocity  = at_velocity;
#if defined GBUFFERS_HAND
	velocity *= MC_HAND_DEPTH;
#endif
#endif

	vec3 viewPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

#ifdef GBUFFERS_TERRAIN
	bool isTopVertex = texCoord.y < mc_midTexCoord.y;

	vec3 scenePos  = viewToSceneSpace(viewPos);
	     scenePos += animateVertex(scenePos + cameraPosition, isTopVertex, lmCoord.y, blockId);

	viewPos = sceneToViewSpace(scenePos);
#endif

	vec4 clipPos = project(gl_ProjectionMatrix, viewPos);

#ifdef TAA
    clipPos.xy += taaOffset * clipPos.w;
	clipPos.xy  = clipPos.xy * renderScale + clipPos.w * (renderScale - 1.0);
#endif

	gl_Position = clipPos;
}
