#include "/include/global.glsl"

varying vec2 uv;

flat varying uint material_mask;
flat varying vec3 tint;
flat varying mat3 tbn;

// ------------
//   uniforms
// ------------

uniform sampler2D tex;
uniform sampler2D noisetex;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float rainStrength;


//----------------------------------------------------------------------------//
#if defined vsh

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

#include "/include/lighting/distortion.glsl"
#include "/include/vertex/wind_animation.glsl"

void main()
{
	uv            = gl_MultiTexCoord0.xy;
	material_mask = uint(mc_Entity.x - 10000.0);
	tint          = gl_Color.rgb;

	tbn[0] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbn[2] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);

	vec3 shadow_view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

	// Wind animation
	vec3 scene_pos = transform(shadowModelViewInverse, shadow_view_pos);
	bool is_top_vertex = uv.y < mc_midTexCoord.y;
	scene_pos += animate_vertex(scene_pos + cameraPosition, is_top_vertex, clamp01(rcp(240.0) * gl_MultiTexCoord1.y), material_mask);
	shadow_view_pos = transform(shadowModelView, scene_pos);

	vec3 shadow_clip_pos = project_ortho(gl_ProjectionMatrix, shadow_view_pos);
	     shadow_clip_pos = distort_shadow_space(shadow_clip_pos);

	gl_Position = vec4(shadow_clip_pos, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec3 shadowcolor0_out;

/* DRAWBUFFERS:0 */

#include "/include/utility/color.glsl"

void main()
{
#ifdef SHADOW_COLOR
	if (material_mask == 2) { // Water
		shadowcolor0_out = vec3(1.0);
	} else {
		vec4 base_color = textureLod(tex, uv, 0);
		if (base_color.a < 0.1) discard;

		shadowcolor0_out  = mix(vec3(1.0), base_color.rgb * tint, base_color.a);
		shadowcolor0_out  = 0.25 * srgb_eotf_inv(shadowcolor0_out) * rec709_to_rec2020;
		shadowcolor0_out *= step(base_color.a, 1.0 - rcp(255.0));
	}
#else
	if (texture(tex, uv).a < 0.1) discard;
#endif
}

#endif
//----------------------------------------------------------------------------//
