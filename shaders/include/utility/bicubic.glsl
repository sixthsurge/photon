#if !defined INCLUDE_UTILITY_BICUBIC
#define INCLUDE_UTILITY_BICUBIC

// Source for bicubic filter: https://stackoverflow.com/questions/13501081/efficient-bicubic-filtering-code-in-glsl

vec4 bicubic_weights(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0 / 6.0);
}

vec4 bicubic_filter_lod(sampler2D sampler, vec2 coord, int lod){
	vec2 res = textureSize(sampler, lod);
	vec2 view_pixel_size = 1.0 / res;

	coord = coord * res - 0.5;

	vec2 fxy = fract(coord);
	coord -= fxy;

	vec4 x_weights = bicubic_weights(fxy.x);
	vec4 y_weights = bicubic_weights(fxy.y);

	vec4 c = coord.xxyy + vec2(-0.5, 1.5).xyxy;

	vec4 s = vec4(x_weights.xz + x_weights.yw, y_weights.xz + y_weights.yw);
	vec4 offset = c + vec4(x_weights.yw, y_weights.yw) / s;

	offset *= view_pixel_size.xxyy;

	vec4 sample0 = textureLod(sampler, offset.xz, lod);
	vec4 sample1 = textureLod(sampler, offset.yz, lod);
	vec4 sample2 = textureLod(sampler, offset.xw, lod);
	vec4 sample3 = textureLod(sampler, offset.yw, lod);

	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);

	return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec4 bicubic_filter(sampler2D sampler, vec2 coord){
	return bicubic_filter_lod(sampler, coord, 0);
}

// Source: https://gist.github.com/TheRealMJP/c83b8c0f46b63f3a88a5986f4fa982b1 (MIT license)
vec4 catmull_rom_filter(sampler2D sampler, vec2 coord, out float confidence) {
	vec2 res = textureSize(sampler, 0);
	vec2 view_pixel_size = 1.0 / res;

	// We're going to sample a a 4x4 grid of texels surrounding the target UV coordinate. We'll do this by rounding
	// down the sample location to get the exact center of our "starting" texel. The starting texel will be at
	// location [1, 1] in the grid, where [0, 0] is the top left corner.
	vec2 sample_pos = coord * res;
	vec2 tex_pos_1 = floor(sample_pos - 0.5) + 0.5;

	// Compute the fractional offset from our starting texel to our original sample location, which we'll
	// feed into the Catmull-Rom spline function to get our filter weights.
	vec2 f = sample_pos - tex_pos_1;

	// Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
	// These equations are pre-expanded based on our knowledge of where the texels will be located,
	// which lets us avoid having to evaluate a piece-wise function.
	vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
	vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
	vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
	vec2 w3 = f * f * (-0.5 + 0.5 * f);

	// Work out weighting factors and sampling offsets that will let us use bilinear filtering to
	// simultaneously evaluate the middle 2 samples from the 4x4 grid.
	vec2 w12 = w1 + w2;
	vec2 offset12 = w2 / (w1 + w2);

	// Compute the final UV coordinates we'll use for sampling the texture
	vec2 tex_pos_0 = tex_pos_1 - 1.0;
	vec2 tex_pos_3 = tex_pos_1 + 2.0;
	vec2 tex_pos_12 = tex_pos_1 + offset12;

	tex_pos_0 *= view_pixel_size;
	tex_pos_3 *= view_pixel_size;
	tex_pos_12 *= view_pixel_size;

	vec4 result = vec4(0.0);
	result += texture(sampler, vec2(tex_pos_0.x, tex_pos_0.y), 0.0) * w0.x * w0.y;
	result += texture(sampler, vec2(tex_pos_12.x, tex_pos_0.y), 0.0) * w12.x * w0.y;
	result += texture(sampler, vec2(tex_pos_3.x, tex_pos_0.y), 0.0) * w3.x * w0.y;

	result += texture(sampler, vec2(tex_pos_0.x, tex_pos_12.y), 0.0) * w0.x * w12.y;
	result += texture(sampler, vec2(tex_pos_12.x, tex_pos_12.y), 0.0) * w12.x * w12.y;
	result += texture(sampler, vec2(tex_pos_3.x, tex_pos_12.y), 0.0) * w3.x * w12.y;

	result += texture(sampler, vec2(tex_pos_0.x, tex_pos_3.y), 0.0) * w0.x * w3.y;
	result += texture(sampler, vec2(tex_pos_12.x, tex_pos_3.y), 0.0) * w12.x * w3.y;
	result += texture(sampler, vec2(tex_pos_3.x, tex_pos_3.y), 0.0) * w3.x * w3.y;

	// Calculate confidence-of-quality factor using UE method (maximum weight)
	confidence = max_of(vec4(w0.x, w1.x, w2.x, w3.x)) * max_of(vec4(w0.y, w1.y, w2.y, w3.y));

	return result;
}
vec4 catmull_rom_filter(sampler2D sampler, vec2 coord) {
	float confidence;
	return catmull_rom_filter(sampler, coord, confidence);
}

// Approximation from Siggraph 2016 SMAA presentation
// Ignores the corner texels, reducing the overhead from 9 to 5 bilinear samples
vec4 catmull_rom_filter_fast(sampler2D sampler, vec2 coord, const float sharpness) {
	vec2 res = vec2(textureSize(sampler, 0));
	vec2 view_pixel_size = 1.0 / res;

	vec2 position = res * coord;
	vec2 center_position = floor(position - 0.5) + 0.5;
	vec2 f = position - center_position;
	vec2 f2 = f * f;
	vec2 f3 = f * f2;

	vec2 w0 =        -sharpness  * f3 +  2.0 * sharpness         * f2 - sharpness * f;
	vec2 w1 =  (2.0 - sharpness) * f3 - (3.0 - sharpness)        * f2         + 1.0;
	vec2 w2 = -(2.0 - sharpness) * f3 + (3.0 -  2.0 * sharpness) * f2 + sharpness * f;
	vec2 w3 =         sharpness  * f3 -                sharpness * f2;

	vec2 w12 = w1 + w2;
	vec2 tc12 = view_pixel_size * (center_position + w2 / w12);
	vec4 center_color = texture(sampler, vec2(tc12.x, tc12.y));

	vec2 tc0 = view_pixel_size * (center_position - 1.0);
	vec2 tc3 = view_pixel_size * (center_position + 2.0);

	float l0 = w12.x * w0.y;
	float l1 = w0.x  * w12.y;
	float l2 = w12.x * w12.y;
	float l3 = w3.x  * w12.y;
	float l4 = w12.x * w3.y;

	vec4 color = texture(sampler, vec2(tc12.x, tc0.y )) * l0
	           + texture(sampler, vec2(tc0.x,  tc12.y)) * l1
	           + center_color                            * l2
	           + texture(sampler, vec2(tc3.x,  tc12.y)) * l3
	           + texture(sampler, vec2(tc12.x, tc3.y )) * l4;

	return color / (l0 + l1 + l2 + l3 + l4);
}

vec3 catmull_rom_filter_fast_rgb(sampler2D sampler, vec2 coord, const float sharpness) {
	vec2 res = vec2(textureSize(sampler, 0));
	vec2 view_pixel_size = 1.0 / res;

	vec2 position = res * coord;
	vec2 center_position = floor(position - 0.5) + 0.5;
	vec2 f = position - center_position;
	vec2 f2 = f * f;
	vec2 f3 = f * f2;

	vec2 w0 =        -sharpness  * f3 +  2.0 * sharpness         * f2 - sharpness * f;
	vec2 w1 =  (2.0 - sharpness) * f3 - (3.0 - sharpness)        * f2         + 1.0;
	vec2 w2 = -(2.0 - sharpness) * f3 + (3.0 -  2.0 * sharpness) * f2 + sharpness * f;
	vec2 w3 =         sharpness  * f3 -                sharpness * f2;

	vec2 w12 = w1 + w2;
	vec2 tc12 = view_pixel_size * (center_position + w2 / w12);
	vec3 center_color = texture(sampler, vec2(tc12.x, tc12.y)).rgb;

	vec2 tc0 = view_pixel_size * (center_position - 1.0);
	vec2 tc3 = view_pixel_size * (center_position + 2.0);

	vec4 color = vec4(texture(sampler, vec2(tc12.x, tc0.y )).rgb, 1.0) * (w12.x * w0.y )
	           + vec4(texture(sampler, vec2(tc0.x,  tc12.y)).rgb, 1.0) * (w0.x  * w12.y)
	           + vec4(center_color,                                1.0) * (w12.x * w12.y)
	           + vec4(texture(sampler, vec2(tc3.x,  tc12.y)).rgb, 1.0) * (w3.x  * w12.y)
	           + vec4(texture(sampler, vec2(tc12.x, tc3.y )).rgb, 1.0) * (w12.x * w3.y );

	return color.rgb / color.a;
}

#endif // INCLUDE_UTILITY_BICUBIC
