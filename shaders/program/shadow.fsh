#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

layout (location = 0) out vec3 shadowcolor0Out;

//--// Inputs //--------------------------------------------------------------//

in vec2 texCoord;

flat in uint blockId;
flat in vec3 normal;
flat in vec4 tint;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D tex;

//--// Includes //-----------------------------------------------------------//

#include "/block.properties"

#include "/include/fragment/aces/matrices.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"

//--// Functions //----------------------------------------------------------//

void main() {
	if (blockId == BLOCK_WATER) {
		shadowcolor0Out.x  = 1.0; // Red value of 1.0 signifies water
		shadowcolor0Out.yz = encodeUnitVector(normal);
	} else {
		vec4 baseTex = texture(tex, texCoord) * tint;
		if (baseTex.a < 0.1) discard;

		shadowcolor0Out = mix(vec3(1.0), baseTex.rgb, baseTex.a);
		shadowcolor0Out = srgbToLinear(shadowcolor0Out) * r709ToAp1Unlit;
		shadowcolor0Out.x = shadowcolor0Out.x == 1.0 ? 254.0 / 255.0 : shadowcolor0Out.x;
	}
}
