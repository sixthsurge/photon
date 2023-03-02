/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffers/basic.glsl:
  Handle vanilla sun and moon and custom skies

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

varying vec2 uv;

flat varying vec3 tint;

// ------------
//   uniforms
// ------------

uniform sampler2D gtexture;

uniform int renderStage;

uniform vec2 taa_offset;


//----------------------------------------------------------------------------//
#if defined vsh

void main()
{
	uv   = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;
	tint = gl_Color.rgb;

	vec3 view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.75;
#endif

	gl_Position = clip_pos;
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec4 scene_color;

/* DRAWBUFFERS:3 */

void main()
{
	vec2 new_uv = uv;
	vec2 offset;

	switch (renderStage) {
#ifdef VANILLA_SUN
	case MC_RENDER_STAGE_SUN:
	 	// alpha of 2 <=> sun
		scene_color.a = 2.0 / 255.0;

		// Cut out the sun itself (discard the halo around it)
		offset = uv * 2.0 - 1.0;
		if (max_of(abs(offset)) > 0.25) discard;

		break;
#endif

#ifdef VANILLA_MOON
	case MC_RENDER_STAGE_MOON:
	 	// alpha of 3 <=> moon
		scene_color.a = 3.0 / 255.0;

		// Cut out the moon itself (discard the halo around it) and flip moon texture along the
		// diagonal
		offset = fract(vec2(4.0, 2.0) * uv);
		new_uv = new_uv + vec2(0.25, 0.5) * ((1.0 - offset.yx) - offset);
		offset = offset * 2.0 - 1.0;
		if (max_of(abs(offset)) > 0.25) discard;

		break;
#endif

	case MC_RENDER_STAGE_CUSTOM_SKY:
	 	// alpha of 4 <=> custom sky
		scene_color.a = 4.0 / 255.0;
		break;

	default:
		discard;
	}

	scene_color.rgb = texture(gtexture, new_uv).rgb;
}

#endif
//----------------------------------------------------------------------------//
