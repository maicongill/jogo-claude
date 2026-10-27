# Decisões propostas e confirmadas

O GDD pede que o que não está definido seja proposto e confirmado antes de virar regra. Tudo abaixo foi
confirmado pelo usuário e está no `config/game_config.json` (F10 recarrega no jogo).

## Marco 9 — Níveis de confiança do pet (confirmado)
| Nível | Confiança | O que libera |
|---|---|---|
| 1 | 30 | O pet tolera o jogador (não foge) |
| 2 | 60 | O pet segue o jogador |
| 3 | 100 | Aceita sela e montaria |

Arquivo: `config/game_config.json` → `pets.aerolho.trust_thresholds`.

## Marco 10 — Salvar e carregar (confirmado)
Um único arquivo JSON (`user://savegame.json`) com seed, posição, inventário, magias, vida/fome, construções,
plantas, cama/estábulo/vasos, pets (com o alforje) e o que foi coletado ou derrotado. F5 salva e F9 carrega
(também pelo menu de opções). Não há salvamento automático nem vários espaços de save.

## Etapa 6 / Ajuste 1 — Alforje do pet (confirmado em 2026-10-27)
- 10 espaços (`pet.bag_slots`).
- A carga **não** gasta estamina; ela reduz a velocidade de voo: alforje cheio = 25% mais lento
  (`pet.bag_speed_penalty`, proporcional aos espaços ocupados).

## Removido na Etapa 6 / Ajuste 4
Os pergaminhos e a mesa de magia saíram do jogo (as 3 magias estão disponíveis desde o início), então os
ingredientes de pergaminho propostos no Marco 8 não valem mais.
