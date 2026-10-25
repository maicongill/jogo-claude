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

## Marco 5 — Construção modular
- Modo de construção (B): peça "fantasma" verde/vermelha, roda do mouse troca a peça, R gira, G liga/desliga a grade (4 m), clique esquerdo constrói, clique direito demole (devolve metade do custo).
- Peças: piso, parede, porta (abre com E), telhado e escada, com custo em madeira (`BuildPieceData`).
- Encaixe por pontos (sockets): paredes e portas nas bordas de pisos/telhados, telhados em cima das paredes, telhados vizinhos, escada na borda. O piso pode ser colocado em qualquer lugar do terreno.
- Estabilidade: peças no chão valem 100%; cada ligação perde estabilidade (piso–piso 25%, demais 10%). Abaixo de 30% a peça é recusada ao construir e desaba (vira entulho) se perder o apoio depois de uma demolição.
- Teste `tests/test_m5.tscn`.

## Marco 6 — Combate
- Espada com combo de 3 golpes (o 3º é mais forte e empurra mais), com hitbox `Area3D` ativa só durante o golpe. Ferramentas e punhos também servem de arma quando não há nada para coletar.
- Arco: clique esquerdo gasta 1 flecha; projétil com gravidade e raycast contra tunelamento.
- Esquiva (Q): dash curto com 0,45 s de invulnerabilidade.
- Vida do jogador e dos inimigos, dano, knockback (dos dois lados) e durabilidade das armas.
- Inimigo: o Musgolho (criatura da floresta) fica parado ou patrulha, persegue a 14 m e ataca corpo a corpo com golpe telegrafado. Nasce nas florestas conforme os chunks carregam e solta carne.
- O item selecionado aparece na mão do personagem; a vida e o dano têm feedback na tela.
- Teste `tests/test_m6.tscn`.

## Marco 7 — Visual cel-shaded anime
- Shader toon (`shaders/toon.gdshader`) com luz em 3 faixas (sombra, meio-tom, luz) para personagem, terreno, árvores, construções e inimigos.
- Contorno por casco invertido (`shaders/toon_outline.gdshader`): modo normal para formas orgânicas e modo "box" para caixas. O terreno não tem contorno (desempenho).
- Parâmetros em um lugar só, o autoload `Visuals`: espessura e cor do contorno, cores das faixas, posição e dureza das faixas. As opções (Esc) têm liga/desliga e espessura do contorno.
- `MaterialFactory` é a única fábrica de materiais; trocar o estilo do jogo é mexer só nela e nos shaders.
- Iluminação ajustada: sol mais baixo (faixas visíveis no relevo), neblina de distância escondendo a borda dos chunks.

## Marco 8 — Magia
- Mana (barra e regeneração depois de uma pausa) e `MagicData` (nome, elemento, custo, efeito).
- Livro de magia (V): escolhe a magia ativa entre as aprendidas; botão direito lança.
- 3 magias: bola de fogo (fogo), rajada de vento (vento) e muralha de terra (terra).
- Fogo interage com o mundo: incendeia árvores e estruturas de madeira (dano contínuo e depois destruição, sem soltar itens) e queima inimigos.
- Mesa de magia (item craftável, colocada no chão): combina itens para criar pergaminhos; usar o pergaminho libera a magia no livro. Receitas fixas em Resources.
- **Proposta pendente:** a tabela de ingredientes dos pergaminhos (ver `docs/PROPOSTAS.md`).
- Corrigido: o jogador agora colide com árvores, pedras e construções (máscara de colisão).
- Teste `tests/test_m8.tscn`.
