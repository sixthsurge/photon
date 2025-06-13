#if !defined INCLUDE_SKY_RAINBOW
#define INCLUDE_SKY_RAINBOW

#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"

// Colours of the rainbow, specified in CIE LAB
const vec3[] rainbow_colors_lab = vec3[](
	// Black (padding)
	vec3(0.0, 0.0, 0.0),
	// Red
	vec3(1.9204079259259252, 8.615652850435307, 3.034993236839206),
	// Orange
	vec3(5.150595481481478, 2.0166722671075, 7.751801674224828),
	// Yellow 
	vec3(8.374896406590196, -4.55693490912186, 12.458460748771072),
	// Green
	vec3(6.460375111111109, -13.197961166655613, 9.433616874771245),
	// Blue 
	vec3(2.5902924592592598, 0.6233705627450292, -9.638464531481834),
	// Indigo
	vec3(0.6521799259259282, 4.582758912741708, -12.47089864973529),
	// Violet 
	vec3(2.57258785185185, 13.19841176317703, -9.435757721780169),
	// Black (padding)
	vec3(0.0, 0.0, 0.0)
);

const float first_rainbow_middle_angle = 42.0 * degree;
const float first_rainbow_thickness = 4.0 * degree;
const float second_rainbow_middle_angle = 47.0 * degree;
const float second_rainbow_thickness = 3.0 * degree;
const float rainbow_start_distance = 500.0;
const float rainbow_end_distance = 600.0;

vec3 draw_single_rainbow(float view_angle, float start_angle, float end_angle) {
	float rainbow_progress = linear_step_unclamped(start_angle, end_angle, view_angle);

	if (clamp01(rainbow_progress) != rainbow_progress) {
		return vec3(0.0);
	}

	float i, f = modf(rainbow_progress * float(rainbow_colors_lab.length() - 1) - 0.5, i);

	vec3 rainbow_color_lab = mix(rainbow_colors_lab[int(i)], rainbow_colors_lab[int(i + 1)], f);
	vec3 rainbow_color = max0(lab_to_xyz(rainbow_color_lab) * xyz_to_rec2020);
	float rainbow_intensity = rainbow_progress - rainbow_progress * dampen(rainbow_progress);

	return rainbow_color * rainbow_intensity;
}

vec3 draw_rainbows(
	vec3 fragment_color,
	vec3 direction_world,
	float view_distance
) {
#ifndef RAINBOWS
	return fragment_color;
#endif

	if (rainbow_amount < eps) {
		return fragment_color;
	}

	float rainbow_angle = fast_acos(clamp01(-dot(direction_world, light_dir)));

	vec3 first_rainbow = draw_single_rainbow(
		rainbow_angle,
		first_rainbow_middle_angle + first_rainbow_thickness * 0.5,
		first_rainbow_middle_angle - first_rainbow_thickness * 0.5
	);

	vec3 second_rainbow = draw_single_rainbow(
		rainbow_angle,
		second_rainbow_middle_angle + second_rainbow_thickness * 0.5,
		second_rainbow_middle_angle - second_rainbow_thickness * 0.5
	);

	vec3 transmittance_approx = mix(vec3(1.0, 0.75, 0.5), vec3(1.0), dampen(max0(direction_world.y)));

	vec3 rainbow_color = light_color * 0.1 * (3.0 * first_rainbow + 0.5 * second_rainbow) * sqr(transmittance_approx);
	float rainbow_fade = rainbow_amount * smoothstep(rainbow_start_distance, rainbow_end_distance, view_distance) * smoothstep(0.0, 0.05, direction_world.y);;

	return fragment_color + rainbow_color * rainbow_fade;
}

#endif // INCLUDE_SKY_RAINBOW
