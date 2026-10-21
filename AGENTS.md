# Instruções para agentes de programação — Idle Ryze

- Antes de modificar regras, ler **GAME_DESIGN.md**.
- Projeto: **Idle Ryze 2.0**, RPG Idle de fantasia em **2D isométrico moderno**, destinado a navegador desktop e mobile. Visual aprovado: fantasia sombria estilizada, pedra, tochas quentes, brilho mágico azul/verde; detalhes artísticos são criados do zero, não copiar screenshots.
- O usuário não quer instalar programas no PC. Publicação: **GitHub Pages** na branch `main`, pasta raiz. Preferir arquivos estáticos HTML/CSS/JS, Phaser via CDN, sem etapa de build local, e caminhos relativos compatíveis com `/Idle-Projeto-Ryze/`.
- Prioridade atual: primeiro protótipo jogável com Vila, Espadachim, Mercador, Comandante do Portal, Mundo dos Esqueletos, combate automático, HUD, slots de inventário e save local.
- Manter cena da Vila com controles manuais WASD/setas/toque; no Mundo dos Esqueletos o combate deve ser Idle.
- Código organizado e configurável; regras/valores ficam centralizados, evitando valores mágicos.
- Testar alterações antes de enviar sempre que houver ambiente de teste; se não houver, informar explicitamente. Não declarar teste executado sem execução real.
- Nunca sobrescrever progresso salvo sem migração; adicionar identificador de versão ao estado persistente.
- Não presumir que artes geradas no chat estejam dentro do repositório. Usar placeholders legíveis inicialmente; criar assets originais separadamente.
- Evitar dependências pesadas, serviços pagos, backend ou contas adicionais.
- Nos commits/PRs, explicar alterações e forma de testar; manter README atualizado.
- Em caso de detalhes de corrupção de monstros não documentados, isolar em `TODO` e não inventar probabilidades; bosses de dungeon não podem ser corrompidos.
