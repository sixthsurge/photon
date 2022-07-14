#if !defined INCLUDE_FRAGMENT_TEXTUREFORMAT
#define INCLUDE_FRAGMENT_TEXTUREFORMAT

#include "material.glsl"

#if   TEXTURE_FORMAT == TEXTURE_FORMAT_LAB
void decodeNormalTex(vec3 normalTex, out vec3 normal, out float ao) {
	normal.xy = normalTex.xy * 2.0 - 1.0;
	normal.z  = sqrt(clamp01(1.0 - dot(normal.xy, normal.xy)));

	ao = normalTex.z;
}

void decodeSpecularTex(vec4 specularTex, inout Material material) {
	material.roughness = sqr(1.0 - specularTex.r);

	if (specularTex.g < 229.5 / 255.0) {
		// dielectrics
		material.f0 = vec3(specularTex.g);
		material.n  = f0ToIor(material.f0.x);

		float hasPorosity = float(specularTex.b < 64.5 / 255.0);
		material.porosity = specularTex.b * hasPorosity;
		material.sssAmount = max(material.sssAmount, specularTex.b - specularTex.b * hasPorosity);
		material.emission = max(material.emission, material.albedo * specularTex.a * float(specularTex.a != 1.0));
	//} else if (specularTex.g < 237.5 / 255.0) {
		// hardcoded metals
	} else {
		// generic metal
		material.f0 = material.albedo;
		material.isMetal = true;
	}
}
#elif TEXTURE_FORMAT == TEXTURE_FORMAT_OLD

#endif

#endif // INCLUDE_FRAGMENT_TEXTUREFORMAT
