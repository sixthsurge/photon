#include "/include/global.glsl"

out vec2 uv;

flat out uint blockId;
flat out vec3 tint;
flat out mat3 tbnMatrix;

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

#include "/include/shadowDistortion.glsl"

void main() {
	uv      = gl_MultiTexCoord0.xy;
	blockId = uint(mc_Entity.x - 10000.0);
	tint    = gl_Color.rgb;

	tbnMatrix[0] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbnMatrix[2] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tbnMatrix[1] = cross(tbnMatrix[0], tbnMatrix[2]) * sign(at_tangent.w);

	vec3 shadowViewPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec3 shadowClipPos = projectOrtho(gl_ProjectionMatrix, shadowViewPos);
	     shadowClipPos = distortShadowSpace(shadowClipPos);

	gl_Position = vec4(shadowClipPos, 1.0);
}
