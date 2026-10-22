# Idle Ryze no Godot

## Abrir e testar

1. Abra o Godot 4.7.2. Se o programa baixado estiver no ZIP, extraia os arquivos antes. Há uma cópia extraída em `C:\Game Idle Ryze\.local-tools\Godot\` neste computador.
2. No Gerenciador de Projetos, escolha **Importar** e selecione `C:\Game Idle Ryze\project.godot`.
3. Abra o projeto e pressione **F5** (Executar projeto). A cena inicial já está definida.
4. Na Vila: WASD/setas ou clique/toque para mover, **E** perto de NPC ou portal. O Mercador abre a loja; o Comandante apresenta o Mundo dos Esqueletos. Também é possível clicar/tocar neles e caminhar até a interação.
5. No Mundo dos Esqueletos, o Espadachim anda e ataca sozinho enquanto o jogo está aberto. Cada esqueleto renasce 25 s após morrer e tem 10% de chance de soltar uma Chave da Dungeon. Um número sobre a lápide indica o tempo restante. **Espaço** ou **Golpe saltado** usa a habilidade.
6. O botão **Menu** no canto superior direito ou a tecla **M** abre a mochila, a Dungeon e a opção de voltar à Vila. Uma chave é consumida ao entrar na Dungeon. O Rei Esqueleto é um boss de combate automático; a vitória leva de volta ao Mundo dos Esqueletos. **I** abre a mochila diretamente. Em tela estreita há botões de direção.

Para editar comigo, descreva a mudança que deseja e o que aconteceu ao pressionar F5. Posso alterar as cenas, os scripts e os assets no projeto; você vê a mudança no editor ao reabrir/recarregar a cena e executar de novo. Uma captura de tela do jogo e os erros em **Depurador → Erros** ajudam a reproduzir problemas visuais ou de controle.

## Estrutura

- `scenes/main.tscn`: Vila, personagem, NPCs, portal, arena e HUD.
- `scripts/main.gd`: controles, interações, combate, interface e save.
- `scripts/game_rules.gd`: valores configuráveis do protótipo.
- `scripts/arena.gd`, `scripts/skeleton.gd` e `scripts/boss.gd`: placeholders vetoriais do combate.
- `../assets/`: ilustrações originais compartilhadas com a versão Phaser.

O save do Godot usa `user://idle_ryze_godot_v2.json` e não importa automaticamente o progresso do navegador. O save v1 é lido e migrado sem apagar o arquivo anterior. Nenhum ganho ocorre com o jogo fechado. Atributos do Rei Esqueleto (100 PV, 4 de dano, ataque a cada 2 s) são provisórios; recompensas próprias ainda não foram definidas. A versão publicada no GitHub Pages ainda é a de Phaser; não exporte por cima do `index.html` da raiz. Quando a cena estiver aprovada, faremos um export web separado, testaremos no navegador e só então escolheremos qual versão publicar.

## Verificação automatizada

Com o executável Godot 4.7.2 disponível, rode na raiz do repositório:

```powershell
.\tests\run-godot-smoke.ps1
```

Esse teste percorre Vila, controles de toque, NPCs, portal, farm, respawn de 25 s, chance de chave, boss, menu, HUD, migração do save e layout estreito. O script cria um diretório de dados temporário dentro de `.local-tools/` para preservar o progresso pessoal.
