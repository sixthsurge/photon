/*
 * Program description:
 * Building linear model of luminance against depth for local exposure - step 1: horizontal sum
 * https://bartwronski.com/2019/09/22/local-linear-models-guided-filter/
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 2 */
layout (location = 0) out vec4 moments;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex8;  // Scene history
uniform sampler2D colortex14; // Temporally stable linear depth

uniform float far;

//--// Includes //------------------------------------------------------------//

#include "/include/utility/color.glsl"

//--// Functions //-----------------------------------------------------------//

/*
const bool colortex8MipmapEnabled = true;
const bool colortex14MipmapEnabled = true;
*/

void main() {

}
