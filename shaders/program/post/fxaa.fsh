/*
 * Program description:
 * FXAA v3.11 from http://blog.simonrodriguez.fr/articles/2016/07/implementing_fxaa.html
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 2 */
layout (location = 0) out vec3 fragColor;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex2; // LDR linear scene color

uniform vec2 windowTexelSize;

//--// Functions //-----------------------------------------------------------//

const int maxIterations = 12;
const float[12] quality = float[12](1.0, 1.0, 1.0, 1.0, 1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 4.0, 8.0);

const float edgeThresholdMin = 0.0312;
const float edgeThresholdMax = 0.125;
const float subpixelQuality  = 0.75;

float getLuma(vec3 rgb) {
	const vec3 luminanceWeightsR709 = vec3(0.2126, 0.7152, 0.0722);
	return sqrt(dot(rgb, luminanceWeightsR709));
}

float minOf(float a, float b, float c, float d, float e) {
	return min(a, min(b, min(c, min(d, e))));
}

float maxOf(float a, float b, float c, float d, float e) {
	return max(a, max(b, max(c, max(d, e))));
}

void main() {
#ifndef FXAA
	#error "This program should be disabled if FXAA is disabled"
#endif

	ivec2 texel = ivec2(gl_FragCoord.xy);

	//--// Detecting where to apply AA

	// Fetch 3x3 neighborhood
	// a b c
	// d e f
	// g h i
	vec3 a = texelFetch(colortex2, texel + ivec2(-1,  1), 0).rgb;
	vec3 b = texelFetch(colortex2, texel + ivec2( 0,  1), 0).rgb;
	vec3 c = texelFetch(colortex2, texel + ivec2( 1,  1), 0).rgb;
	vec3 d = texelFetch(colortex2, texel + ivec2(-1,  0), 0).rgb;
	vec3 e = texelFetch(colortex2, texel, 0).rgb;
	vec3 f = texelFetch(colortex2, texel + ivec2( 1,  0), 0).rgb;
	vec3 g = texelFetch(colortex2, texel + ivec2(-1, -1), 0).rgb;
	vec3 h = texelFetch(colortex2, texel + ivec2( 0, -1), 0).rgb;
	vec3 i = texelFetch(colortex2, texel + ivec2( 1, -1), 0).rgb;

	// Luma at the current fragment
	float luma = getLuma(e);

	// Luma at the four direct neighbors of the current fragment
	float lumaU = getLuma(b);
	float lumaL = getLuma(d);
	float lumaR = getLuma(f);
	float lumaD = getLuma(h);

	// Maximum and minimum luma around the current fragment
	float lumaMin = minOf(luma, lumaD, lumaU, lumaL, lumaR);
	float lumaMax = maxOf(luma, lumaD, lumaU, lumaL, lumaR);

	// Compute the delta
	float lumaRange = lumaMax - lumaMin;

	// If the luma variation is lower that a threshold (or if we are in a really dark area), we are not on an edge, don't perform any AA.
	if (lumaRange < max(edgeThresholdMin, lumaMax * edgeThresholdMax)) { fragColor = e; return; }

	//--// Estimating gradient and choosing edge direction

	// Get the lumas of the four remaining corners
	float lumaUl = getLuma(a);
	float lumaUr = getLuma(c);
	float lumaDl = getLuma(g);
	float lumaDr = getLuma(i);

	// Combine the four edges lumas (using intermediary variables for future computations with the same values)
	float lumaHorizontal = lumaD + lumaU;
	float lumaVertical   = lumaL + lumaR;

	// Same for the corners
	float lumaLeftCorners  = lumaDl + lumaUl;
	float lumaDownCorners  = lumaDl + lumaDr;
	float lumaRightCorners = lumaDr + lumaUr;
	float lumaUpCorners    = lumaUl + lumaUr;

	// Compute an estimation of the gradient along the horizontal and vertical axis.
	float edgeHorizontal = abs(-2.0 * lumaL + lumaLeftCorners)  + abs(-2.0 * luma + lumaVertical)   * 2.0  + abs(-2.0 * lumaR + lumaRightCorners);
	float edgeVertical   = abs(-2.0 * lumaU + lumaUpCorners)    + abs(-2.0 * luma + lumaHorizontal) * 2.0  + abs(-2.0 * lumaD + lumaDownCorners);

	// Is the local edge horizontal or vertical?
	bool isHorizontal = edgeHorizontal >= edgeVertical;

	//--// Choosing edge orientation

	// Select the two neighboring texels lumas in the opposite direction to the local edge
	float luma1 = isHorizontal ? lumaD : lumaL;
	float luma2 = isHorizontal ? lumaU : lumaR;

	// Compute gradients in this direction
	float gradient1 = luma1 - luma;
	float gradient2 = luma2 - luma;

	// Which direction is the steepest?
	bool is1Steepest = abs(gradient1) >= abs(gradient2);

	// Gradient in the corresponding direction, normalized
	float gradientScaled = 0.25 * max(abs(gradient1), abs(gradient2));

	// Choose the step size (one pixel) according to the edge direction
	float stepLength = isHorizontal ? windowTexelSize.y : windowTexelSize.x;

	// Average luma in the correct direction
	float lumaLocalAverage;
	if (is1Steepest) {
		// Switch the direction
		stepLength = -stepLength;
		lumaLocalAverage = 0.5 * (luma1 + luma);
	} else {
		lumaLocalAverage = 0.5 * (luma2 + luma);
	}

	// Shift UV in the correct direction by half a pixel
	vec2 currentUv = coord;
	if (isHorizontal) {
		currentUv.y += stepLength * 0.5;
	} else {
		currentUv.x += stepLength * 0.5;
	}

	//--// First iteration exploration

	// Compute offste (for each iteration step) in the right direction
	vec2 offset = isHorizontal ? vec2(windowTexelSize.x, 0.0) : vec2(0.0, windowTexelSize.y);

	// Compute UVs to explore on each side of the edge, orthogonally. "quality" allows us to step faster
	vec2 uv1 = currentUv - offset;
	vec2 uv2 = currentUv + offset;

	// Read the lumas at both current extremities of the exploration segment, and compute the delta wrt the local average luma
	float lumaEnd1 = getLuma(texture(colortex2, uv1).rgb);
	float lumaEnd2 = getLuma(texture(colortex2, uv2).rgb);
	lumaEnd1 -= lumaLocalAverage;
	lumaEnd2 -= lumaLocalAverage;

	// If the luma deltas at the current extremities are larger than the local gradient, we have reached the side of the edge
	bool reached1 = abs(lumaEnd1) >= gradientScaled;
	bool reached2 = abs(lumaEnd2) >= gradientScaled;
	bool reachedBoth = reached1 && reached2;

	// If the side is not reached, we continue to explore in this direction
	if (!reached1) uv1 -= offset;
	if (!reached2) uv2 += offset;

	//--// Iterating

	// If both sides have not been reached, continue to explore
	if (!reachedBoth) {
		for (int i = 2; i < maxIterations; ++i) {
			// If needed, read luma in 1st direction, compute delta
			if (!reached1) {
				lumaEnd1  = getLuma(texture(colortex2, uv1).rgb);
				lumaEnd1 -= lumaLocalAverage;
			}
			// If needed, read luma in the opposite direction, compute delta
			if (!reached2) {
				lumaEnd2  = getLuma(texture(colortex2, uv2).rgb);
				lumaEnd2 -= lumaLocalAverage;
			}

			// If the luma deltas at the current extremities is larger than the local gradient, we have reached the side of the edge
			reached1 = abs(lumaEnd1) >= gradientScaled;
			reached2 = abs(lumaEnd2) >= gradientScaled;
			reachedBoth = reached1 && reached2;

			// If the side is not reached, we continue to explore in this direction, with a variable quality
			if (!reached1) uv1 -= offset * quality[i];
			if (!reached2) uv2 += offset * quality[i];

			// If both sides have been reached, stop the exploration
			if (reachedBoth) break;
		}
	}

	//--// Estimating offset

	// Compute the distance to each extremity of the edge
	float distance1 = isHorizontal ? (coord.x - uv1.x) : (coord.y - uv1.y);
	float distance2 = isHorizontal ? (uv2.x - coord.x) : (uv2.y - coord.y);

	// In which direction is the extremity of the edge closer?
	bool isDirection1 = distance1 < distance2;
	float distanceFinal = min(distance1, distance2);

	// Length of the edge
	float edgeThickness = distance1 + distance2;

	// UV offset: read in the direction of the closest side of the edge
	float pixelOffset = -distanceFinal / edgeThickness + 0.5;

	// Is the luma at center smaller than the local average?
	bool isLumaCenterSmaller = luma < lumaLocalAverage;

	// If the luma at center is smaller than at its neighbour, the delta luma at each end should be positive (same variation)
	bool correctVariation = ((isDirection1 ? lumaEnd1 : lumaEnd2) < 0.0) != isLumaCenterSmaller;

	// If the luma variation is incorrect, do not offset
	float finalOffset = correctVariation ? pixelOffset : 0.0;

	//--// Subpixel antialiasing

	// Full weighted average of the luma over the 3x3 neighborhood
	float lumaAverage = rcp(12.0) * (2.0 * (lumaHorizontal + lumaVertical) + lumaLeftCorners + lumaRightCorners);

	// Ratio of the delta between the global average and the center luma, over the luma range in the 3x3 neighborhood
	float subPixelOffset1 = clamp01(abs(lumaAverage - luma) / lumaRange);
	float subPixelOffset2 = (-2.0 * subPixelOffset1 + 3.0) * subPixelOffset1 * subPixelOffset1;

	// Compute a sub-pixel offset based on this delta.
	float subPixelOffsetFinal = subPixelOffset2 * subPixelOffset2 * subpixelQuality;

	// Pick the biggest of the two offsets.
	finalOffset = max(finalOffset,subPixelOffsetFinal);

	//--// Final read

	// Compute the final UV coordinates
	vec2 finalUv = coord;
	if (isHorizontal) {
		finalUv.y += finalOffset * stepLength;
	} else {
		finalUv.x += finalOffset * stepLength;
	}

	// Return the color at the new UV coordinates
	fragColor = texture(colortex2, finalUv).rgb;
}
