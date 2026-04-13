void modify_light(inout Light light, vec3 world_pos) {
    light.color*= BLOCKLIGHT_I;
}