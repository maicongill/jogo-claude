# Propostas pendentes de confirmação

O GDD pede que o que não está definido seja proposto e confirmado antes de virar regra. Tudo abaixo já está
implementado com valores simples, em Resources fáceis de editar, e **aguarda a sua confirmação**.

## Marco 8 — Ingredientes dos pergaminhos (mesa de magia)
| Pergaminho | Ingredientes | Arquivo |
|---|---|---|
| Bola de fogo | 2 madeira + 2 pedra | `resources/scroll_recipes/fire.tres` |
| Rajada de vento | 3 madeira + 1 muda | `resources/scroll_recipes/wind.tres` |
| Muralha de terra | 4 pedra + 1 madeira | `resources/scroll_recipes/earth.tres` |

Para mudar: edite o .tres no inspetor, ou os números em `tools/generate_resources.gd` e rode o gerador.

## Marco 9 — Níveis de confiança do pet
| Nível | Confiança | O que libera |
|---|---|---|
| 1 | 30 | O pet tolera o jogador (não foge) |
| 2 | 60 | O pet segue o jogador |
| 3 | 100 | Aceita sela e montaria |

Arquivo: `resources/pets/aerolho.tres` (`trust_thresholds`).

## Marco 10 — Salvar e carregar
Proposta (já implementada): um único arquivo JSON (`user://savegame.json`) com seed, posição, inventário, magias,
vida/fome, construções, plantas, cama/mesa/estábulo, pets e o que foi coletado ou derrotado. F5 salva e F9 carrega
(também pelo menu de opções). Não há salvamento automático nem vários espaços de save.
