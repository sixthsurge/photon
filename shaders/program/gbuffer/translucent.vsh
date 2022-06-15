#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 texCoord;
out vec2 lmCoord;
out vec4 tint;

flat out uint blockId;
flat out mat3 tbnMatrix;

//--// Inputs //--------------------------------------------------------------//

#define attribute in
attribute vec4 at_tangent;
attribute vec3 mc_Entity;

//--// Uniforms //------------------------------------------------------------//

//--// Camera uniforms

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

//--// Custom uniforms

uniform vec2 taaOffset;

//--// Includes //------------------------------------------------------------//

#include "/block.properties"

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

	vec3 viewPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec4 clipPos = project(gl_ProjectionMatrix, viewPos);

#ifdef TAA
    clipPos.xy += taaOffset * clipPos.w;
	clipPos.xy  = clipPos.xy * renderScale + clipPos.w * (renderScale - 1.0);
#endif

	gl_Position = clipPos;
}
