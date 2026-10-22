# Idle Ryze 2.0 — protótipos Phaser e Godot

RPG Idle 2D isométrico em português. A versão publicada continua em Phaser 3.90.0, com arquivos estáticos e sem build. Um projeto Godot 4.7.2 foi iniciado no mesmo repositório para desenvolver o jogo visualmente no editor. Ambos reutilizam as ilustrações originais da Vila; a arena e os esqueletos ainda usam arte vetorial provisória.

## Projeto Godot

Abra [`project.godot`](./project.godot) pelo **Importar** do Godot e pressione **F5**. O protótipo permite percorrer a Vila, interagir com Mercador e Comandante, farmar esqueletos automaticamente e enfrentar o Rei Esqueleto na Dungeon. Cada esqueleto renasce após 25 s e tem 10% de chance de soltar uma chave; cada entrada na Dungeon consome uma. A HUD mostra vida, mana, XP, nível, ouro e chaves, com **Menu** no canto superior direito. Controles: **WASD/setas**, clique ou toque no chão, **E** para interagir, **M** para menu, **I** para inventário e **Espaço** para o golpe saltado. Na tela estreita, aparecem botões direcionais. A cena principal está em [`godot/scenes/main.tscn`](./godot/scenes/main.tscn), as regras em [`godot/scripts/game_rules.gd`](./godot/scripts/game_rules.gd), e há instruções de colaboração em [`godot/README.md`](./godot/README.md).

O Godot guarda o progresso em `user://idle_ryze_godot_v2.json`, separado do save Phaser. Saves Godot v1 são migrados sem apagar o arquivo antigo; um save desconhecido ou inválido é preservado e o jogo inicia uma sessão temporária. Os atributos do Rei Esqueleto são provisórios e ele ainda não concede recompensas próprias além do registro de vitória. O projeto usa o renderizador **Compatibility** para preparar a futura exportação web. Por enquanto, o GitHub Pages ainda publica o Phaser na raiz. A exportação Godot será feita numa pasta própria depois de validar esta cena no editor.

## Jogar a versão Phaser

Abra **https://skuby16.github.io/Idle-Projeto-Ryze/** depois de publicar a branch `main`. Para testar a cópia local, abra `index.html` diretamente no navegador. O Phaser e as ilustrações já estão na pasta do jogo, então a cópia local funciona sem internet. O save da cópia local fica separado do save do site publicado.

Na Vila, use **WASD** ou **setas** para caminhar, clique/toque no chão para ir até um ponto e pressione **E** ou **Interagir** perto do Mercador, Comandante ou Portal. No celular, use o direcional na parte inferior ou toque no chão. Toque em um NPC ou no portal para caminhar até ele e interagir.

No Mundo dos Esqueletos, movimento, seleção de alvo e ataque básico são automáticos. Use **Espaço** ou o botão **Golpe saltado** para a habilidade; **Voltar à vila** retorna ao comércio. **I** ou **Mochila** abre o inventário. O Mercador reforça a espada por 20 ouro e cura 12 PV por 10 ouro.

## Regras desta versão

- Espadachim: 28 PV, 5 de dano, ataque a cada 0,8 s. Esqueleto: 30 PV, 3 de dano, ataque a cada 1,6 s.
- Vitória: 5 ouro, 8 XP e 2 PV. Primeiro nível em 40 XP; +3 PV máximos por nível e +1 dano a cada três níveis.
- Habilidade: 20 de dano e recarga de 18 s. **O custo de 12 mana é provisório**, pois ainda não foi definido no documento de design.
- Mana máxima de 30 com regeneração de 1 a cada 2,5 s, preços da loja e aumento de 20 XP na exigência por nível também são números provisórios.
- Esqueletos renascem após 25 s; o herói, após 3 s. Os valores ficam em [`gameConfig.js`](./gameConfig.js).
- O progresso é salvo no `localStorage` deste navegador, com versão do formato. Dados inválidos são copiados para uma chave de backup antes de começar uma sessão temporária. Saves de outra versão também são preservados; nenhuma dessas sessões substitui o progresso anterior.
- O farm avança somente enquanto a página está aberta. Não há ganhos offline ou sincronização entre aparelhos.

## Publicar no GitHub Pages

1. Mantenha `index.html`, `style.css`, `game.js`, `gameConfig.js`, `state.js`, `phaser.min.js`, `PHASER_LICENSE.md`, a pasta `assets/` e `.nojekyll` na **raiz** da branch `main`.
2. No repositório GitHub, abra **Settings → Pages**.
3. Em **Build and deployment**, escolha **Deploy from a branch**, branch **main**, pasta **/(root)** e salve.
4. Abra o endereço acima após a implantação. Todos os caminhos dos arquivos são relativos, compatíveis com `/Idle-Projeto-Ryze/`.

Como alternativa para teste local, se Node.js já estiver disponível, execute `node tests/serve.mjs` e acesse `http://127.0.0.1:4173/`. Isso não é necessário para jogar pela cópia local nem pelo GitHub Pages.

## Limites e próximos passos

A mochila tem espaços demonstrativos; apenas a espada é equipável nesta versão. O Mundo dos Centauros, a partir do nível 5, e os equipamentos restantes ficam para a próxima fase. **TODO:** definir pré-requisitos e probabilidades da corrupção para monstros comuns de todos os mundos; bosses de dungeon não podem ser corrompidos. As ilustrações atuais são uma primeira etapa: personagens ainda não têm quadros de animação, e a arena/esqueletos continuam vetoriais. Os arquivos e prompts de arte estão documentados em [`assets/ART_DIRECTION.md`](./assets/ART_DIRECTION.md).

O jogo usa uma cópia local de `phaser.min.js` 3.90.0, obtida do CDN oficial listado na [página da versão](https://phaser.io/download/release/v3.90.0). Sua licença MIT acompanha o repositório em [`PHASER_LICENSE.md`](./PHASER_LICENSE.md).

## Verificação de código

Com Node.js disponível: `node --test tests/state.test.mjs` verifica carregamento e proteção do save, progressão e compras. A checagem de sintaxe pode ser feita com `node --check game.js`. O teste `tests/file-smoke.cjs` valida a abertura por `file://`, o carregamento real das ilustrações, as interações e o viewport mobile em um ambiente com Playwright e Chrome. `tests/browser-smoke.cjs` cobre também compras, habilidade e acesso HTTP.
