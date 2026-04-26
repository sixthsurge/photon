void modify_light(inout Light light, vec3 world_pos) {
    if (light.index < 0) {
        light.color *= HANDHELD_LIGHTING_INTENSITY;
    } else {
        light.color *= BLOCKLIGHT_I;
    }
}