// Abre um "buraco" pontilhado nos objetos que ficam entre a câmera e o personagem.
// Os pontos vêm do autoload Visuals (atualizados pelo jogador a cada quadro).

global uniform vec3 cam_fade_from;    // posição da câmera
global uniform vec3 cam_fade_to;      // cabeça do personagem
global uniform float cam_fade_radius; // 0 = desligado

uniform bool fade_occluder = false;

float _bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int idx = i.x + i.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0;
}

// Descarta o fragmento se ele estiver dentro do cilindro câmera -> personagem.
void camera_fade(vec3 world_pos, vec2 frag) {
	if (!fade_occluder || cam_fade_radius <= 0.0) {
		return;
	}
	vec3 seg = cam_fade_to - cam_fade_from;
	float len = length(seg);
	if (len < 0.01) {
		return;
	}
	vec3 dir = seg / len;
	float t = dot(world_pos - cam_fade_from, dir);
	// Só o que está na frente do personagem (com uma folga perto dele).
	if (t < 0.0 || t > len - 0.4) {
		return;
	}
	float d = length(world_pos - (cam_fade_from + dir * t));
	// Fica mais estreito perto da câmera, como um cone.
	float r = cam_fade_radius * mix(0.6, 1.0, clamp(t / len, 0.0, 1.0));
	float amount = 1.0 - smoothstep(r * 0.55, r, d);
	if (amount > _bayer4(frag)) {
		discard;
	}
}

// ---------------------------------------------------------------- níveis de detalhe (LOD)
// Trocas por distância com pontilhado complementar: no mesmo pixel, o que sai some quando o que
// entra aparece, então a troca fica difícil de notar. Faixas vêm do autoload Visuals (seção "lod").
global uniform float lod_near_start; // 3D -> imagens
global uniform float lod_near_end;
global uniform float lod_far_start;  // imagens -> manchas
global uniform float lod_far_end;

uniform bool lod_fade_out = false;   // objetos 3D que somem ao virar imagem

float lod_ramp(float d, float a, float b) {
	return clamp((d - a) / max(b - a, 0.001), 0.0, 1.0);
}

// Objeto 3D perto: some (pontilhado) na faixa em que a imagem dele aparece.
void lod_near_fade(vec3 world_pos, vec3 cam_pos, vec2 frag) {
	if (!lod_fade_out || lod_near_end <= 0.0) {
		return;
	}
	if (lod_ramp(distance(world_pos, cam_pos), lod_near_start, lod_near_end) > _bayer4(frag)) {
		discard;
	}
}
