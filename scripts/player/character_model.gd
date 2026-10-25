class_name CharacterModel
extends Node3D
## Modelo do aventureiro (.glb do Blender) com atalhos para tocar animações.

## O .glb não guarda se a animação é cíclica, então listamos aqui.
const LOOPING: Array[StringName] = [&"idle", &"walk", &"run", &"crouch", &"crouch_walk", &"fall", &"swim"]

var _anim: AnimationPlayer


func _ready() -> void:
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_anim.playback_default_blend_time = 0.15
	for anim_name in LOOPING:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play(&"idle")
	_apply_toon()


func play(anim_name: StringName, speed: float = 1.0) -> void:
	if _anim.current_animation != String(anim_name) or not _anim.is_playing():
		_anim.play(anim_name)
	_anim.speed_scale = speed


func current() -> StringName:
	return StringName(_anim.current_animation)


func is_finished() -> bool:
	return not _anim.is_playing()


## Troca os materiais do .glb por toon + contorno, mantendo as cores originais.
func _apply_toon() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			var color := src.albedo_color if src != null else Color.WHITE
			# Olhos e sobrancelhas são peças coladas no rosto: sem contorno.
			var hull := MaterialFactory.Hull.NONE if src != null and src.resource_name.begins_with("M_eye") else MaterialFactory.Hull.NORMAL
			mi.set_surface_override_material(i, MaterialFactory.toon(color, false, hull))
