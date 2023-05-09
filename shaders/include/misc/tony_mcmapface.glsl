/*
MIT License

Copyright (c) 2023 Tomasz Stachowiak
Copyright (c) 2023 Antonio Ferreras

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Original Repositories:
    https://github.com/h3r2tic/tony-mc-mapface

This is a GLSL port of the "Tony McMapface" display transform by Tomasz Stachowiak.
*/


// "HDR Rec.709/sRGB stimulus, and maps it to LDR"
vec3 TonyMcMapface(sampler3D LUT, vec3 stimulus) {
    vec3 encoded = max(stimulus / (stimulus + 1.0), 0.0);

    // compute UVs
    const float LUT_DIMS = 48.0;
    vec3 uv = encoded * ((LUT_DIMS - 1.0) / LUT_DIMS) + 0.5 / LUT_DIMS;
    // uv.y = 1.0 - uv.y;

    return texture3D(LUT, uv).rgb;
}
