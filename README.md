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
| Coletar, interagir, usar o item (comer, plantar, ler pergaminho) | E ou clique esquerdo |
| Atacar (espada, arco, punho) | Clique esquerdo |
| Esquiva | Q |
| Lançar a magia escolhida | Clique direito |
| Inventário e crafting | Tab ou I |
| Livro de magia | V |
| Hotbar | 1–9 ou roda do mouse |
| Modo de construção | B (roda: trocar peça, R: girar, G: grade, esquerdo: construir, direito: demolir) |
| Montar / desmontar o pet | F (Espaço sobe, C desce, Shift acelera) |
| Salvar / carregar | F5 / F9 |

## A meta do protótipo (10–15 minutos)
Coletar madeira e pedra → fazer uma ferramenta → construir uma casa pequena → criar um pergaminho e aprender uma magia →
domar o pet voador → voar com ele → derrotar um inimigo. O jogo acompanha isso sozinho (painel de Objetivos).

Dicas rápidas: pedras exigem picareta (3 madeiras); a mesa de magia, a cama, a sela e o estábulo são craftados no Tab;
musgolhos (inimigos) vivem nas florestas; o Aerolho (pet, azul) aparece perto do início.

## Testes automáticos
Cada marco tem um teste que roda o jogo de verdade, sem janela:
```bash
GODOT=/caminho/do/godot ./tests/run_all.sh
```
Ou um só: `godot --headless --path . res://tests/test_m10.tscn` (o m10 joga a meta inteira do começo ao fim).
`tools/screenshot.tscn` tira capturas (precisa de janela ou GPU).

## Estrutura
- `scenes/` cenas (principal, jogador, personagem). `scripts/` código por área: `core` (autoloads), `world`, `player`, `items`, `building`, `combat`, `magic`, `pet`, `ui`, `data` (classes dos Resources).
- `resources/` conteúdo em Resources (`.tres`): itens, receitas, recursos do mundo, magias, pergaminhos, pets, peças de construção. **Para criar conteúdo novo, crie um .tres na pasta certa**; ele é carregado sozinho.
- `tools/generate_resources.gd` gera os .tres iniciais (rode com `--script` para regerar; depois dá para editar no inspetor).
- `shaders/` toon e contorno. `assets/` modelos. `art_source/` `.blend` e scripts que geram o personagem. `docs/` propostas e registro do GDD.
- Autoloads: `EventBus` (sinais entre sistemas), `Game` (opções e estado global), `WorldState` (o que o jogador mudou), `Database` (conteúdo), `Visuals` (parâmetros do visual toon).

## Visual (marco 7)
Ajuste em `scripts/core/visuals.gd` (espessura/cor do contorno, cores e posição das faixas de luz) ou pelo menu de opções.

## Pendente de confirmação
Veja `docs/PROPOSTAS.md`: ingredientes dos pergaminhos, níveis de confiança do pet e o formato do salvamento.

## Fora do escopo desta fatia (GDD, "Fica para depois")
Automação, elementos raros, pets terrestre e aquático, desertos/montanhas/mar, espada de duas mãos e escudo. As animações de nadar existem no modelo, mas ainda não há água no mundo.
