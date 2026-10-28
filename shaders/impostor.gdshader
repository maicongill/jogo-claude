shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, world_vertex_coords;
// Impostor: uma imagem (PNG) sempre virada para a câmera, girando só em volta do eixo vertical.
// tier 0 = imagem de um objeto (faixa média): aparece onde o 3D some e some onde a mancha aparece.
// tier 1 = mancha de cor sólida (faixa longe): aparece onde as imagens somem.
// A malha é um quadrado de -0.5..0.5 (x) por 0..1 (y); a escala da instância dá largura e altura.

#include "res://shaders/camera_fade.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform int tier = 0;
uniform bool use_instance_color = false;

varying vec3 v_world;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - center;
	to_cam.y = 0.0;
	to_cam = length(to_cam) > 0.001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	// Coordenadas locais do quadrado a partir do UV (x: -0.5..0.5, y: 0 embaixo .. 1 em cima).
	vec2 local = vec2(UV.x - 0.5, 1.0 - UV.y);
	v_world = center + right * local.x * sx + vec3(0.0, local.y * sy, 0.0);
	// Em world_vertex_coords o VERTEX é no espaço do mundo: profundidade e neblina ficam certas.
	VERTEX = v_world;
	NORMAL = to_cam;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (tex.a < 0.5) {
		discard;
	}
	float d = distance(v_world, CAMERA_POSITION_WORLD);
	float dither = _bayer4(FRAGCOORD.xy);
	if (tier == 0) {
		// Some perto (lá o 3D aparece) e longe (lá a mancha aparece), no padrão complementar.
		if (lod_ramp(d, lod_near_start, lod_near_end) <= dither || lod_ramp(d, lod_far_start, lod_far_end) > dither) {
			discard;
		}
	} else if (lod_ramp(d, lod_far_start, lod_far_end) <= dither) {
		discard;
	}
	// A cor da mancha vem em sRGB (igual ao PNG, que o sampler já converte para linear).
	ALBEDO = use_instance_color ? srgb_to_linear(COLOR.rgb) : tex.rgb;
}
