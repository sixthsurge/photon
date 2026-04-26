bool modify_is_hand() {
    //Photonics bug! depthtex0 is inheirted from d0_sky_map
    return texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).x < 0.56;
}