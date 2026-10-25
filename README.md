# jogo claude

Sandbox 3D de mundo aberto (protótipo). Godot 4.7, GDScript. Veja o GDD para a visão do jogo.

## Como rodar
1. Abra a pasta no Godot 4.7 e aperte F5 (cena principal: `scenes/main.tscn`).
2. Controles: WASD mover, Shift correr, C ou Ctrl agachar, Espaço pular, mouse para a câmera, Esc solta o mouse.

## Testes automáticos
```bash
godot --headless --path . res://tests/test_m1.tscn
godot --headless --path . res://tests/test_m2.tscn
godot --headless --path . res://tests/test_m3.tscn
godot --headless --path . res://tests/test_m4.tscn
godot --headless --path . res://tests/test_m5.tscn
godot --headless --path . res://tests/test_m6.tscn
godot --headless --path . res://tests/test_m8.tscn
```

## Estrutura
`scenes/`, `scripts/`, `resources/`, `shaders/`, `ui/`, `assets/` (modelos), `art_source/` (arquivo .blend e scripts de geração do personagem), `tests/`.
