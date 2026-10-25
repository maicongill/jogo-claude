shader_type spatial;
render_mode cull_front, unshaded;
// Contorno por casco invertido: a malha é inflada e só as faces de trás aparecem.
// box_mode serve para formas de caixa (normais duras), onde inflar pela normal abriria buracos nos cantos.

global uniform vec4 toon_outline_color : source_color;
global uniform float toon_outline_thickness;

uniform bool box_mode = false;

void vertex() {
	float depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	// Um pouco mais grosso com a distância, para o traço não sumir.
	float t = toon_outline_thickness * (1.0 + clamp(depth, 0.0, 60.0) * 0.03);
	if (box_mode) {
		VERTEX += sign(VERTEX) * t;
	} else {
		VERTEX += NORMAL * t;
	}
}

void fragment() {
	ALBEDO = toon_outline_color.rgb;
}
