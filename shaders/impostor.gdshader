shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, world_vertex_coords;
// Impostor: imagem (PNG) de uma árvore, pedra ou arbusto, sempre virada para a câmera (gira só em
// volta do eixo vertical). As imagens ficam lado a lado num atlas; INSTANCE_CUSTOM.x diz a coluna.
// Aparece onde o objeto 3D some (faixa perto) e some onde a floresta vira dossel no terreno
// (faixa longe), sempre em pontilhado complementar.
// A malha é um quadrado de -0.5..0.5 (x) por 0..1 (y); a escala da instância dá largura e altura.

#include "res://shaders/camera_fade.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float columns = 1.0;

varying vec3 v_world;
varying float v_column;

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
	v_column = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 uv = vec2((clamp(UV.x, 0.01, 0.99) + floor(v_column + 0.5)) / columns, UV.y);
	vec4 tex = texture(albedo_tex, uv);
	if (tex.a < 0.5) {
		discard;
	}
	float d = distance(v_world, CAMERA_POSITION_WORLD);
	float dither = _bayer4(FRAGCOORD.xy);
	// Some perto (lá o 3D aparece) e longe (lá a floresta vira dossel), no padrão complementar.
	if (lod_ramp(d, lod_near_start, lod_near_end) <= dither || lod_ramp(d, lod_far_start, lod_far_end) > dither) {
		discard;
	}
	ALBEDO = tex.rgb;
}
