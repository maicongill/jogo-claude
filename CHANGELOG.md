# Changelog

## Marco 1 — Projeto base e personagem
- Projeto Godot 4.7 recriado do zero, com autoloads `EventBus`, `Game`, `WorldState` e `Database`.
- Personagem (`CharacterBody3D`) com o modelo do Blender: andar, correr, agachar, pular e cair.
- Câmera em 3ª pessoa (`SpringArm3D`) controlada pelo mouse, sem atravessar objetos.
- Input Map completo (WASD, Espaço, Shift, C/Ctrl, mouse, E para interagir, e as teclas dos próximos marcos).
- Cena principal com chão plano de teste e obstáculos.

## Marco 2 — Terreno procedural infinito
- `TerrainGenerator`: altura e bioma (planície/floresta) por `FastNoiseLite`, tudo a partir de `Game.world_seed`.
- `ChunkBuilder` gera chunks de 32 x 32 m em threads (`WorkerThreadPool`): malha com cor por vértice, `HeightMapShape3D` e posição dos recursos.
- `ChunkManager` carrega e descarta chunks em volta do jogador (raio 6, ajustável). A área inicial é sempre planície.
- Árvores, pedras e arbustos de frutinhas distribuídos de forma determinística (`MultiMeshInstance3D`, um `ResourceField` por tipo e chunk).
- Dados em Resources: `ItemData`, `ResourceNodeData`, `RecipeData`, carregados pelo autoload `Database`. O gerador `tools/generate_resources.gd` cria os .tres.
- Teste automático `tests/test_m2.tscn` e ferramenta de captura `tools/screenshot.tscn`.
