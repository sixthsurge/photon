writeonly uniform image2D radiosity_indirect_image;

void write_indirect(vec3 color) {
    imageStore(radiosity_indirect_image, ivec2(gl_FragCoord.xy), vec4(color, 1f));
}