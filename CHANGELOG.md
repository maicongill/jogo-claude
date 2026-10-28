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

## Marco 9 — Pet voador
- Aerolho (`PetData`): criatura voadora selvagem em planícies e florestas (sempre há um perto do início). Pousa, voa de um ponto a outro e foge de quem se aproxima enquanto não confia.
- Preferências (comida e bioma favoritos) descobertas por observação: olhe para ele de perto por 3 s (comida) e 6 s (bioma).
- Magia de doma (já conhecida desde o início, botão direito com ela selecionada): dá confiança; comida favorita (+15 e bônus de 30 s) e bioma favorito aceleram.
- Níveis de confiança (**proposta pendente**, ver `docs/PROPOSTAS.md`): 1 tolera, 2 segue, 3 aceita sela e montaria.
- Sela (item craftado, usada no pet de nível 3) e montaria: WASD voa, Espaço sobe, C desce, Shift acelera, F monta/desmonta.
- Estamina: gasta só voando rápido. Zerada, o pet planeia perdendo altitude, ou não consegue decolar no chão, até recuperar.
- Combate montado: o jogador ataca e lança magias da sela; os golpes de inimigos atingem o pet.
- Estábulo (item craftado e colocado no chão): se o pet morre, renasce nele com a confiança e a sela. Sem estábulo, o pet se perde.
- Teste `tests/test_m9.tscn`.

## Marco 10 — Integração e teste da meta
- Painel de **Objetivos** (a meta do GDD) e **dicas** na tela que guiam o próximo passo (`GoalTracker`).
- Menu de opções completo (Esc): perda de itens ao morrer, sensibilidade, contorno, distância de visão, salvar e carregar.
- **Salvar/carregar** (F5/F9) em um JSON: inventário, posição, vida e fome, magias, construções, plantas, cama/mesa/estábulo, pets, recursos coletados e inimigos derrotados. **Proposta pendente.**
- Teste `tests/test_m10.tscn`: joga a meta inteira com as regras do jogo (coletar, craftar, construir, aprender magia, domar, montar e voar, vencer um inimigo) e depois salva e carrega.
- Correções: o desbloqueio do jogador espera o chão carregar em qualquer lugar do mundo (também após carregar um save); a mão do personagem não quebra mais durante o golpe.

## Configuração em arquivo único
- Novo `config/game_config.json`: **fonte única** de parâmetros (jogador, sobrevivência, combate, inimigo, magia, pet, construção, mundo, visual) e de todo o conteúdo (itens, receitas, recursos do mundo, magias, pergaminhos, pets, peças de construção).
- Autoload `Config` lê o arquivo; `Database` monta os objetos a partir dele. Os antigos `.tres` e o gerador foram removidos.
- **F10** recarrega o arquivo no jogo e reaplica ao vivo; JSON inválido é recusado e mantém os valores anteriores.
- Teste `tests/test_config.tscn` (edita uma cópia do arquivo e confere que o jogo mudou, incluindo item e receita novos).

## Etapa 6 — Ajustes após o primeiro teste (2026-10-27)
- **Pet voador:** voo com embalo (aceleração/frenagem graduais), inclinação nas curvas, mergulho (ganha velocidade
  sem estamina), subida em arco (troca velocidade por altura), planar (Q); decolagem e pouso suaves; câmera montada
  com seguimento suave e FOV que abre com a velocidade; alforje de 10 espaços (Tab), salvo no save; a carga reduz
  a velocidade.
- **Construção:** janela (parede com abertura), viga (pilar que sustenta pisos e telhados com pouca perda de
  estabilidade, inclusive piso elevado) e vaso de flores (item colocado em qualquer superfície).
- **Combate:** 3 tipos de inimigo em `enemy_types` (Saltilho, Musgolho, Cuspidor); vagam, mostram "!" ao perceber,
  avisam antes de atacar e reagem com recuo/atordoamento conforme a resistência; espada com golpe carregado e crítico
  no ar; arco com tiro carregado; indicador de carga na mira.
- **Magia:** mesa de magia, pergaminhos e livro removidos; as 3 magias (e a doma) desde o início, escolhidas por
  Z/X/V/T, com barra de magias acima da hotbar.
- **Meta:** objetivos novos (casa com porta e janelas, manobras de voo, carregar itens, 2 tipos de inimigo,
  espada + arco + magia) e o teste `test_m10` joga a meta nova inteira.
- **Testes:** `run_all.sh` passou a usar o Godot desta máquina e a falhar quando um teste não roda ou tem erro de
  script (antes ele "passava" sem rodar nada quando o comando `godot` não existia).

## Ajustes no voo (2026-10-28)
- Subida em arco removida (não estava funcionando bem).
- Estamina do Aerolho dobrada (100 -> 200), com a regeneração também dobrada (14 -> 28/s) para o descanso
  depois de exausto continuar levando o mesmo tempo.
- Planar agora liga/desliga com um toque em Q (C ou pousar também desligam) e recupera estamina.
- Voar se deslocando gasta um pouco de estamina (`pet.move_stamina_drain`); Shift gasta mais.
- Objetivo "Voar fazendo manobras" pede mergulho e planar.
- Parado no ar o pássaro também gasta um pouco de estamina (`pet.hover_stamina_drain`); ela só volta no chão ou planando.
- Planando, W ou Espaço saem do planar.
- Opção `game.start_with_tamed_pet` (ligada): o jogo novo começa com um Aerolho domado (confiança máxima) e selado.
- Pássaro 1,4x mais rápido (voo 9 -> 12,6 m/s, rápido 16 -> 22,4 m/s, aceleração do mergulho 9 -> 12,6) e
  planar perde altitude pela metade (1,3 -> 0,65 m/s). O mergulho conta como manobra ao passar de 1,25x o voo normal.
