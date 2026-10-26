shader_type spatial;
// Toon em 3 faixas (sombra / meio-tom / luz). Os parâmetros globais vêm do autoload Visuals,
// então dá para ajustar o visual do jogo inteiro em um lugar só.

global uniform vec4 toon_shadow_tint : source_color;
global uniform vec4 toon_mid_tint : source_color;
global uniform float toon_band_light;
global uniform float toon_softness;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;

#include "res://shaders/camera_fade.gdshaderinc"

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	camera_fade((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy);
	vec3 c = albedo.rgb;
	if (use_vertex_color) {
		c *= srgb_to_linear(COLOR.rgb);
	}
	ALBEDO = c;
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
