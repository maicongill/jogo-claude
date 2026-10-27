# jogo claude

Sandbox 3D de mundo aberto (protótipo da fatia vertical do GDD). Godot 4.7, GDScript tipado, single player.
Fantasia leve e colorida, visual cel-shaded anime. O personagem foi modelado e animado no Blender (`art_source/`).

## Como rodar
1. Abra a pasta no **Godot 4.7** e aperte **F5** (cena principal: `scenes/main.tscn`).
2. Ao começar, o canto superior direito mostra os **Objetivos** e o topo da tela mostra a **dica** do próximo passo.

## Controles
| Ação | Tecla |
|---|---|
| Mover / correr / agachar / pular | WASD / Shift / C ou Ctrl / Espaço |
| Câmera | Mouse (Esc abre as opções e solta o mouse) |
| Coletar, interagir, usar o item (comer, plantar, colocar) | E ou clique esquerdo |
| Atacar (espada, arco, punho) | Clique esquerdo (cliques rápidos = combo de 3 golpes da espada) |
| Golpe carregado / tiro carregado | Segurar o clique esquerdo e soltar (o arco em volta da mira fica dourado quando cheio) |
| Crítico | Golpe de espada no ar (pulando ou caindo) |
| Esquiva | Q |
| Lançar a magia escolhida | Clique direito (gasta mana) |
| Inventário e crafting | Tab ou I |
| Escolher magia | Z bola de fogo · X rajada de vento · V muralha de terra · T doma (todas desde o início) |
| Hotbar | 1–9 ou roda do mouse |
| Modo de construção | B (roda: trocar peça, R: girar, G: grade, esquerdo: construir, direito: demolir) |
| Peças | piso, parede, porta (E abre/fecha), telhado, escada, janela e viga (sustenta pisos e telhados, inclusive piso elevado) |
| Vaso de flores | item de crafting; segure e mire em qualquer superfície plana (piso, mesa, chão) |
| Montar / desmontar o pet | F (ou E mirando perto dele; montado, E também desmonta). Espaço sobe, C desce, Shift acelera |
| Voo: mergulho | C em velocidade (ganha velocidade sem gastar estamina) |
| Voo: subida em arco | Espaço logo depois de um mergulho (troca velocidade por altura) |
| Voo: planar | segurar Q (desce devagar e recupera estamina) |
| Alforje do pet | Tab montado ou perto do pet selado (Shift + clique move a pilha) |
| Salvar / carregar | F5 / F9 |

## A meta do protótipo (10–15 minutos, GDD Etapa 6)
Coletar madeira e pedra → fazer uma ferramenta → construir uma casa com porta e janelas → domar o pet voador →
voar fazendo manobras → carregar itens no alforje → derrotar 2 tipos de inimigo, usando espada, arco e magia.
O jogo acompanha isso sozinho (painel de Objetivos).

Dicas rápidas: pedras exigem picareta (3 madeiras); a cama, a sela, o estábulo e o vaso de flores são craftados no Tab;
saltilhos e cuspidores aparecem em qualquer lugar fora da área inicial, musgolhos nas florestas; o Aerolho (pet, azul) aparece perto do início.

## Testes automáticos
Cada marco tem um teste que roda o jogo de verdade, sem janela. `./tests/run_all.sh` roda todos (usa o Godot da Steam desta máquina; defina `GODOT=...` se estiver em outro lugar) e só diz "TODOS OS TESTES PASSARAM" se cada teste chegou ao fim sem falhas nem erros de script:
```bash
GODOT=/caminho/do/godot ./tests/run_all.sh
```
Ou um só: `godot --headless --path . res://tests/test_m10.tscn
godot --headless --path . res://tests/test_config.tscn` (o m10 joga a meta inteira do começo ao fim).
`tools/screenshot.tscn` tira capturas (precisa de janela ou GPU).

## Estrutura
- `scenes/` cenas (principal, jogador, personagem). `scripts/` código por área: `core` (autoloads), `world`, `player`, `items`, `building`, `combat`, `magic`, `pet`, `ui`, `data` (classes dos Resources).
- `config/game_config.json` **o arquivo de configuração: todos os parâmetros, itens, receitas, magias, pets e peças** (veja abaixo).
- `shaders/` toon e contorno. `assets/` modelos. `art_source/` `.blend` e scripts que geram o personagem. `docs/` propostas e registro do GDD.
- Autoloads: `EventBus` (sinais entre sistemas), `Game` (opções e estado global), `WorldState` (o que o jogador mudou), `Database` (conteúdo), `Visuals` (parâmetros do visual toon).

## Configuração do jogo (um arquivo só)
Tudo que dá para ajustar está em **`config/game_config.json`**: velocidades, vida, fome, combate, inimigo, mana, pet, construção,
terreno, visual, e todo o conteúdo (itens, receitas, recursos do mundo, magias, inimigos, pets, peças).
- Edite e salve. O jogo lê o arquivo ao iniciar; **F10** dentro do jogo recarrega e reaplica ao vivo (jogador, magias, itens, receitas, visual).
  Inimigos e pets que já estão no mundo pegam os novos valores quando reaparecem; o terreno só muda ao reiniciar.
- Para criar um item/receita/magia nova: copie um bloco, troque a chave (o id) e os valores. O topo do arquivo (`_leia_me`) explica o formato.
- Se o JSON ficar com erro, o jogo avisa no console e mantém os valores anteriores.

## Visual (marco 7)
Ajuste na seção `visual` do `config/game_config.json` ou pelo menu de opções.

## Decisões confirmadas
Veja `docs/PROPOSTAS.md`: níveis de confiança do pet, formato do salvamento e alforje do pet (10 espaços; a carga reduz a velocidade).

## Fora do escopo desta fatia (GDD, "Fica para depois")
Automação, elementos raros, pets terrestre e aquático, desertos/montanhas/mar, espada de duas mãos e escudo. As animações de nadar existem no modelo, mas ainda não há água no mundo.

## Inimigos

| Tipo | Papel | Como enfrentar |
|---|---|---|
| Saltilho | rápido e fraco, chega pulando | poucos golpes; cuidado com a mordida rápida |
| Musgolho | lento e forte, golpe pesado | espere o aviso (cresce e fica vermelho) e esquive (Q); só golpe carregado ou crítico o atordoa |
| Cuspidor | ataca à distância e foge se você chega perto | arco, ou corra e esquive dos cuspes |

Todos vagam pelo mapa, mostram "!" ao perceber você e reagem aos golpes. Os valores ficam em `enemy_types` no arquivo de configuração.
