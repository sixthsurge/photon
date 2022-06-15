out vec2 coord;

void main() {
	coord = gl_MultiTexCoord0.xy;
	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
