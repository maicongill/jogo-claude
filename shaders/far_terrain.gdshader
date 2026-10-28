shader_type spatial;
// Terreno distante com a floresta "dentro" dele: onde há árvores o terreno sobe como um dossel
// verde-escuro. A subida cresce com a distância na mesma faixa em que as imagens das árvores somem,
// então a floresta vira dossel aos poucos e nada fica flutuando.
// UV.x = quanto de floresta há em cada vértice (0 a 1). Iluminação toon igual à de toon.gdshader.

#include "res://shaders/camera_fade.gdshaderinc"

global uniform vec4 toon_shadow_tint : source_color;
global uniform vec4 toon_mid_tint : source_color;
global uniform float toon_band_light;
global uniform float toon_softness;

uniform float canopy_height = 4.5;
uniform vec4 canopy_color : source_color = vec4(0.02, 0.30, 0.03, 1.0);

varying float v_canopy;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float grow = lod_ramp(distance(w, CAMERA_POSITION_WORLD), lod_far_start, lod_far_end);
	v_canopy = UV.x * grow;
	VERTEX.y += v_canopy * canopy_height;
}

void fragment() {
	vec3 c = srgb_to_linear(COLOR.rgb);
	ALBEDO = mix(c, canopy_color.rgb, smoothstep(0.05, 0.45, v_canopy));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float s = max(toon_softness, 0.001);
	float b_mid = smoothstep(0.0, s, ndl);
	float b_light = smoothstep(toon_band_light, toon_band_light + s, ndl);
	vec3 tone = mix(toon_shadow_tint.rgb, toon_mid_tint.rgb, b_mid);
	tone = mix(tone, vec3(1.0), b_light);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * tone / PI;
}
