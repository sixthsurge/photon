#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 0 */
layout (location = 0) out vec4 fragColor;

//--// Inputs //--------------------------------------------------------------//

in vec2 texCoord;

//--// Uniforms //------------------------------------------------------------//

#if MC_VERSION < 11700
	#define gtexture gcolor
#endif

uniform sampler2D gtexture;

//--// Program //-------------------------------------------------------------//

void main() {
	fragColor = texture(gtexture, texCoord, log2(renderScale));
	if (fragColor.a < 0.1) discard;

#if defined PROGRAM_GBUFFERS_ARMOR_GLINT
	// alpha of 0 <=> enchantment glint
	fragColor.a = 0.0;
#elif defined PROGRAM_GBUFFERS_DAMAGEDBLOCK
	// alpha of 1 <=> damage overlay
	fragColor.a = 1.0;
#endif
}
