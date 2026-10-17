# Excitebike — Protótipo (DCC148 - Desenvolvimento de Jogos)

Repositório do Trabalho 1 da disciplina **DCC148 - Desenvolvimento de Jogos** (UFJF), cujo objetivo é desenvolver, em **Godot**, um protótipo funcional de um jogo clássico sorteado para o aluno, replicando suas mecânicas com o máximo de fidelidade possível.

Jogo atribuído: **Excitebike (NES)**.

## Contexto da disciplina

- **Disciplina**: DCC148 – Desenvolvimento de Jogos
- **Trabalho**: Trabalho 1 – Desenvolvimento de protótipo
- **Valor**: 30 pontos
- **Data de entrega**: até 18/10/2026
- **Grupo**: Gabriel Lineker e Gianlucca Paiva
- **Motor utilizado**: Godot

## Descrição geral do trabalho

A proposta é construir um protótipo pequeno e funcional que ilustre as mecânicas básicas do jogo original, sem necessidade de fases adicionais, variação de dificuldade, áudio ou elementos de interface (a menos que especificado em contrário para o jogo sorteado). É permitido usar criatividade para pequenas adaptações, desde que a essência do jogo original seja mantida. Todos os assets utilizados devem ser gratuitos ou de autoria própria.

## Jogo: Excitebike (NES)

### O que deve ser implementado

- [x] Uma pista de corrida vista de lado (side-view);
- [x] Movimentação horizontal da motocicleta;
- [x] Aceleração e desaceleração;
- [x] Rampas e obstáculos;
- [x] Rotação da motocicleta durante os saltos (**sem** uso de animação de sprites — rotação deve ser feita via transformação/física);
- [x] Ao menos dois adversários seguindo trajetórias pré-definidas;
- [x] Condição de vitória/derrota: chegar ao final da pista antes de um tempo limite, ou sofrer um número máximo de acidentes.

> Áudio e elementos de interface (HUD, menus) são opcionais para este trabalho, salvo indicação contrária do professor.

## Entrega

- Submissão via Google Classroom, feita por **um único representante** (em caso de dupla).
- O link submetido deve apontar para o **repositório público no GitHub**.
- O repositório deve conter uma pasta `build/` com um **executável para Linux** já testado.

## Critérios de avaliação

1. Replicação adequada das mecânicas do jogo original;
2. Atendimento aos itens de implementação especificados acima;
3. Execução correta do projeto;
4. Qualidade do código apresentado;
5. Entrega dentro do prazo (desconto de 5% por dia de atraso);
6. Apresentação em sala de aula.

> **Obs.:** Qualquer identificação de plágio ou de não-autoria do código resultará em nota 0.

## Como jogar

| Tecla | Ação |
| :--- | :--- |
| **D** | Acelerar |
| **A** | Frear |
| **W** | Inclinar a moto para trás (no ar) |
| **S** | Inclinar a moto para frente (no ar) |

O fluxo do jogo é: **Menu principal -> Contagem regressiva (3, 2, 1, VAI!) -> Corrida -> Colocação / Hospital / Tempo esgotado**. Há também um menu de pausa durante a corrida.

## Como o projeto foi feito

### Tecnologia e configuração

- **Engine:** Godot 4.x, com **GDScript** tipado estaticamente onde cabível.
- **Resolução nativa:** 256 x 240 px (proporção do NES), ampliada na janela para 1024 x 960 px, com pixel art nítida em grade de 8 px.
- **Cenas e scripts separados por responsabilidade:** `scenes/` guarda as cenas (`entities`, `levels`, `ui`, `referencia`) e `scripts/` guarda os scripts de cada uma (`entite`, `levels`, `ui`, `autoload`).
- **Assets:** sprites, pista, sons e fontes ficam em `assets/`. Todos são gratuitos ou de autoria própria.
- **Autoload:** o `AudioManager` ([`audio_manager.gd`](scripts/autoload/audio_manager.gd)) é um singleton que centraliza a música e os efeitos da corrida.

### Processo de desenvolvimento

Os scripts `.gd` foram padronizados: sem comentários explicativos, divididos em seções nomeadas (`# --- NOME ---`) e com funções relacionadas agrupadas.

### Estrutura principal

| Elemento | Arquivo | Papel |
| :--- | :--- | :--- |
| Corrida | [`main_game.gd`](scripts/levels/main_game.gd) | Orquestra a cena: cronômetro, sensores da pista, bots, chegada e classificação |
| Player | [`player.gd`](scripts/entite/player.gd) | Física, controle, rotação aérea, pouso e acidente da moto |
| Adversários | [`follower.gd`](scripts/entite/follower.gd) | Seguidor de trilha (`PathFollow2D`) para os bots |
| Áudio do player | [`player_audio.gd`](scripts/entite/player_audio.gd) | Som do motor, desaceleração, queda e morte |
| Áudio geral | [`audio_manager.gd`](scripts/autoload/audio_manager.gd) | Estádio, torcida, vaia, chegada, pódio e hospital |
| HUD | [`hub.gd`](scripts/ui/hub.gd) | Cronômetro MM:SS:CC, velocímetro e vidas |
| Telas | `colocacao.gd`, `hospital.gd`, `tempo_esgotado.gd`, `pause.gd`, `menu_game.gd`, `countdown_ui.gd` | Resultados, derrota, pausa, menu e largada |
| Áudio de UI | [`sounds.gd`](scripts/ui/sounds.gd) | Sons de foco e hover dos botões |

## Mecânicas implementadas

- **Pista side-view com cenário:** pista vista de lado com estádio, parallax e equipe de filmagem ao fundo, dividida em quatro raias.
- **Movimento, aceleração e desaceleração:** aceleração e freio com velocidade máxima, atrito natural e freio ativo. A velocidade é exibida em km/h no HUD.
- **Rampas, quebra-molas e obstáculos:** sensores (`Area2D`) na pista disparam efeitos no player ao passar por rampas e obstáculos. A inércia da rampa impulsiona o salto.
- **Rotação aérea sem animação de sprite:** no ar, o player inclina a moto com W/S. A rotação é feita por transformação angular e física (gravidade, velocidade máxima de queda e velocidade de rotação), sem animação de sprites.
- **Pouso e acidente:** se o player pousa com o ângulo acima do limite seguro (empinado ou de frente), ele sofre um acidente e fica caído por um tempo antes de se recuperar. O número de acidentes é limitado.
- **Adversários autônomos:** quatro competidores seguem trajetórias predefinidas por `Path2D` e `PathFollow2D`, cada um com velocidade e raia próprias. Eles acompanham as rampas com rotação suave (`lerp_angle`).
- **Contagem de largada:** contagem regressiva 3, 2, 1, VAI! que bloqueia os controles do player e dos bots e os libera na largada.
- **Condições de vitória e derrota:**
  - *Vitória:* chegar ao fim da pista antes do tempo limite. A classificação dos quatro competidores é mostrada em um pódio com medalha.
  - *Derrota:* estourar o tempo limite (tela de tempo esgotado) ou atingir o limite de acidentes (tela do hospital).
  - Após a chegada, o player desacelera automaticamente e os controles ficam bloqueados.
- **HUD:** cronômetro, velocímetro e vidas, com expressões do piloto que mudam conforme as quedas.
- **Menu principal e pausa:** menu com parallax contínuo e manobras do player em exibição, mais pausa durante a corrida.
- **Áudio:** música de estádio, som do motor, torcida, vaia, efeitos de chegada, pódio, hospital e feedback de navegação nos botões.

## Executável

A pasta [`build/`](build/) contém o executável para Linux (`excitebike.x86_64` e `excitebike.pck`). Para executar:

```bash
chmod +x build/excitebike.x86_64
./build/excitebike.x86_64
```

Para abrir o projeto no editor, importe a pasta na Godot 4.x e execute a cena principal.

## Créditos

Desenvolvido por **Gabriel Lineker** e **Gianlucca Paiva** para a disciplina DCC148 (UFJF). Excitebike é propriedade da Nintendo; este protótipo é um trabalho acadêmico sem fins comerciais.

## Status do desenvolvimento

**Status: TRABALHO CONCLUÍDO.** Todos os itens obrigatórios do trabalho foram implementados e validados, e o executável para Linux está disponível na pasta `build/`
