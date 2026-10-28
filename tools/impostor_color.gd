extends SceneTree
## Média da cor das copas no tree.png (pixels opacos da metade de cima): a cor sólida das manchas.
## godot --headless --path . --script res://tools/impostor_color.gd

func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/impostors/tree.png"))
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in int(img.get_height() * 0.6):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				sum += Color(c.r, c.g, c.b, 1)
				n += 1
	var avg := Color(sum.r / n, sum.g / n, sum.b / n)
	print("cor média das copas: [%.3f, %.3f, %.3f]" % [avg.r, avg.g, avg.b])
	quit()
