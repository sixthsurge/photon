const float blocklight_scale = 6.0f;
const float rcp_blocklight_scale = 1/blocklight_scale;

void modify_restir_gi(inout vec3 color) {
    color*= rcp_blocklight_scale * SKYLIGHT_I;
}