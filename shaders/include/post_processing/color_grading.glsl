/*
 * Color Grading
 */

#if !defined INCLUDE_POST_PROCESSING_COLOR_GRADING
#define INCLUDE_POST_PROCESSING_COLOR_GRADING

vec3 rgb_to_hsv(vec3 rgb) {
    vec3 hsv;
    float min_val = min(min(rgb.r, rgb.g), rgb.b);
    float max_val = max(max(rgb.r, rgb.g), rgb.b);
    float delta = max_val - min_val;
    
    hsv.z = max_val;
    
    if (max_val != 0.0) {
        hsv.y = delta / max_val;
    } else {
        hsv.y = 0.0;
    }
    
    if (delta == 0.0) {
        hsv.x = 0.0;
    } else if (max_val == rgb.r) {
        hsv.x = mod((rgb.g - rgb.b) / delta, 6.0);
    } else if (max_val == rgb.g) {
        hsv.x = (rgb.b - rgb.r) / delta + 2.0;
    } else {
        hsv.x = (rgb.r - rgb.g) / delta + 4.0;
    }
    hsv.x /= 6.0;
    
    return hsv;
}

vec3 hsv_to_rgb(vec3 hsv) {
    float h = hsv.x * 6.0;
    float s = hsv.y;
    float v = hsv.z;
    
    float c = v * s;
    float x = c * (1.0 - abs(mod(h, 2.0) - 1.0));
    float m = v - c;
    
    vec3 rgb;
    if (h < 1.0) {
        rgb = vec3(c, x, 0.0);
    } else if (h < 2.0) {
        rgb = vec3(x, c, 0.0);
    } else if (h < 3.0) {
        rgb = vec3(0.0, c, x);
    } else if (h < 4.0) {
        rgb = vec3(0.0, x, c);
    } else if (h < 5.0) {
        rgb = vec3(x, 0.0, c);
    } else {
        rgb = vec3(c, 0.0, x);
    }
    
    return rgb + m;
}

vec3 apply_hue_shift_to_color(vec3 color, float hue_shift_degrees) {
    if (hue_shift_degrees == 0.0) return color;
    
    vec3 hsv = rgb_to_hsv(color);
    hsv.x = mod(hsv.x + hue_shift_degrees / 360.0, 1.0);
    return hsv_to_rgb(hsv);
}

vec3 apply_channel_saturation_boost(vec3 color, float saturation_boost, int channel) {
    if (saturation_boost == 1.0) return color;
 
    vec3 channel_mask = vec3(0.0);
    if (channel == 0) channel_mask.r = 1.0;      
    else if (channel == 1) channel_mask.g = 1.0; 
    else if (channel == 2) channel_mask.b = 1.0; 
    
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    
    vec3 result = color;
    if (channel == 0) {
        result.r = mix(luminance * channel_mask.r, color.r, saturation_boost);
    } else if (channel == 1) {
        result.g = mix(luminance * channel_mask.g, color.g, saturation_boost);
    } else if (channel == 2) {
        result.b = mix(luminance * channel_mask.b, color.b, saturation_boost);
    }
    
    return result;
}

vec3 apply_intensity(vec3 color, float intensity) {
    return color * intensity;
}

vec3 apply_color_grading(vec3 color) {
    vec3 result = color;
    
    #ifdef GRADE_RED_HUE_SHIFT
    if (GRADE_RED_HUE_SHIFT != 0.0) {
        float red_influence = result.r / max(max(result.r, result.g), max(result.b, 0.001));
        vec3 shifted = apply_hue_shift_to_color(result, GRADE_RED_HUE_SHIFT * red_influence);
        result = mix(result, shifted, red_influence);
    }
    #endif
    
    #ifdef GRADE_GREEN_HUE_SHIFT
    if (GRADE_GREEN_HUE_SHIFT != 0.0) {
        float green_influence = result.g / max(max(result.r, result.g), max(result.b, 0.001));
        vec3 shifted = apply_hue_shift_to_color(result, GRADE_GREEN_HUE_SHIFT * green_influence);
        result = mix(result, shifted, green_influence);
    }
    #endif
    
    #ifdef GRADE_BLUE_HUE_SHIFT
    if (GRADE_BLUE_HUE_SHIFT != 0.0) {
        float blue_influence = result.b / max(max(result.r, result.g), max(result.b, 0.001));
        vec3 shifted = apply_hue_shift_to_color(result, GRADE_BLUE_HUE_SHIFT * blue_influence);
        result = mix(result, shifted, blue_influence);
    }
    #endif
    
    #ifdef GRADE_RED_SAT
    if (GRADE_RED_SAT != 1.0) {
        result = apply_channel_saturation_boost(result, GRADE_RED_SAT, 0);
    }
    #endif
    
    #ifdef GRADE_GREEN_SAT
    if (GRADE_GREEN_SAT != 1.0) {
        result = apply_channel_saturation_boost(result, GRADE_GREEN_SAT, 1);
    }
    #endif
    
    #ifdef GRADE_BLUE_SAT
    if (GRADE_BLUE_SAT != 1.0) {
        result = apply_channel_saturation_boost(result, GRADE_BLUE_SAT, 2);
    }
    #endif
    
    #ifdef GRADE_RED_INTENSITY
    result.r *= GRADE_RED_INTENSITY;
    #endif
    
    #ifdef GRADE_GREEN_INTENSITY
    result.g *= GRADE_GREEN_INTENSITY;
    #endif
    
    #ifdef GRADE_BLUE_INTENSITY
    result.b *= GRADE_BLUE_INTENSITY;
    #endif
    
    return clamp(result, 0.0, 1.0);
}

#endif