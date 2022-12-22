#include "/include/global.glsl"

out vec2 uv;

flat out uint object_id;
flat out vec3 tint;
flat out mat3 tbn;

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

uniform sampler2D noisetex;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float rainStrength;

#include "/include/shadow_distortion.glsl"
#include "/include/wind_animation.glsl"

void main() {
	uv      = gl_MultiTexCoord0.xy;
	object_id = uint(mc_Entity.x - 10000.0);
	tint    = gl_Color.rgb;

	tbn[0] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbn[2] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);

	vec3 shadow_view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

	// Wind animation
	vec3 scene_pos = transform(shadowModelViewInverse, shadow_view_pos);
	bool is_top_vertex = uv.y < mc_midTexCoord.y;
	scene_pos += animate_vertex(scene_pos + cameraPosition, is_top_vertex, clamp01(rcp(240.0) * gl_MultiTexCoord1.y), object_id);
	shadow_view_pos = transform(shadowModelView, scene_pos);

	vec3 shadow_clip_pos = project_ortho(gl_ProjectionMatrix, shadow_view_pos);
	     shadow_clip_pos = distort_shadow_space(shadow_clip_pos);

	gl_Position = vec4(shadow_clip_pos, 1.0);
}
