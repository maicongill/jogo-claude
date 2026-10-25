class_name SlotUI
extends Control
## Um espaço do inventário/hotbar desenhado em código (ícone provisório = quadrado colorido).

signal pressed(index: int, button: int)

var index := 0
var stack: ItemStack
var selected := false
var show_key := ""


func _init() -> void:
	custom_minimum_size = Vector2(54, 54)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_stack(s: ItemStack) -> void:
	stack = s
	tooltip_text = _tooltip()
	queue_redraw()


func _tooltip() -> String:
	if stack == null:
		return ""
	var t := stack.item.display_name
	if stack.item.description != "":
		t += "\n" + stack.item.description
	if stack.item.max_durability > 0:
		t += "\nDurabilidade: %d/%d" % [stack.durability, stack.item.max_durability]
	return t


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.08, 0.09, 0.12, 0.85))
	draw_rect(r, Color(1, 0.85, 0.3) if selected else Color(0.4, 0.45, 0.55), false, 3.0 if selected else 1.5)
	if show_key != "":
		draw_string(ThemeDB.fallback_font, Vector2(4, 13), show_key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
	if stack == null:
		return
	var icon := Rect2(Vector2(11, 11), size - Vector2(22, 22))
	draw_rect(icon, stack.item.color)
	draw_rect(icon, Color(0, 0, 0, 0.5), false, 1.5)
	var letter := stack.item.display_name.substr(0, 1)
	draw_string(ThemeDB.fallback_font, icon.position + Vector2(0, icon.size.y * 0.72), letter, HORIZONTAL_ALIGNMENT_CENTER, icon.size.x, 20, Color(0, 0, 0, 0.55))
	if stack.item.max_durability > 0:
		var frac := float(stack.durability) / stack.item.max_durability
		var bar := Rect2(Vector2(6, size.y - 8), Vector2((size.x - 12) * frac, 4))
		draw_rect(Rect2(Vector2(6, size.y - 8), Vector2(size.x - 12, 4)), Color(0, 0, 0, 0.7))
		draw_rect(bar, Color(0.3, 0.9, 0.3).lerp(Color(0.95, 0.25, 0.2), 1.0 - frac))
	elif stack.count > 1:
		var pos := Vector2(0, size.y - 6)
		draw_string_outline(ThemeDB.fallback_font, pos, str(stack.count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5, 15, 4, Color.BLACK)
		draw_string(ThemeDB.fallback_font, pos, str(stack.count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5, 15, Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		pressed.emit(index, event.button_index)
