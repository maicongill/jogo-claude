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

## Marco 3 — Coleta e inventário
- Interação por raycast (E ou clique esquerdo) com árvores, pedras e arbustos de frutinhas.
- Árvores e pedras se esgotam após alguns golpes; o arbusto regenera depois de 90 s. O estado sobrevive ao descarte do chunk.
- 2 níveis de ferramenta (madeira e pedra): a pedra exige picareta; machado derruba árvore mais rápido que a mão.
- Plantio: a muda vira árvore coletável depois de 60 s.
- Inventário em grade (36 espaços, 9 na hotbar) com empilhamento, durabilidade e interface (Tab). Hotbar com teclas 1–9 e roda do mouse.
- `Game.debug_starter_kit` dá um machado e uma picareta no início, só para testes (some no marco 4).
- Teste `tests/test_m3.tscn`.

## Marco 4 — Crafting, sobrevivência e morte
- `RecipeData` + crafting livre pelo inventário (painel ao lado, abre com Tab): ferramentas, armas, arco e flechas, sela, cama, mesa de magia e estábulo.
- Durabilidade em ferramentas (a arma entra no marco 6); ao chegar a zero o item quebra.
- Fome (cai ao longo de 10 min; zerada causa dano) e vida, com barras na tela. Comer: segure o alimento e aperte E/clique.
- Morte: perde os itens e renasce na cama (colocada com E/clique no chão; E nela redefine o ponto). Menu de opções (Esc) com a caixa "Perder itens ao morrer". Fome e durabilidade não têm opção de desativar.
- Teste `tests/test_m4.tscn` e `tests/run_all.sh`.
