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


func play(anim_name: StringName, speed: float = 1.0) -> void:
	if _anim.current_animation != String(anim_name) or not _anim.is_playing():
		_anim.play(anim_name)
	_anim.speed_scale = speed


func current() -> StringName:
	return StringName(_anim.current_animation)


func is_finished() -> bool:
	return not _anim.is_playing()
