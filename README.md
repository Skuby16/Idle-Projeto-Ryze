# Idle Ryze 2.0 — protótipo jogável (v0.1)

RPG Idle 2D isométrico em português, feito com Phaser 3.90.0 via CDN. São apenas arquivos HTML, CSS e JavaScript; não há build, backend nem instalação para jogar. A arte vetorial é provisória e original.

## Jogar

Abra **https://skuby16.github.io/Idle-Projeto-Ryze/** depois de publicar a branch `main`. É necessária conexão com a internet para carregar o Phaser pelo CDN.

Na Vila, use **WASD** ou **setas** para caminhar, clique/toque no chão para ir até um ponto e pressione **E** ou **Interagir** perto do Mercador, Comandante ou Portal. No celular, use o direcional na parte inferior ou toque no chão. Toque em um NPC ou no portal para caminhar até ele e interagir.

No Mundo dos Esqueletos, movimento, seleção de alvo e ataque básico são automáticos. Use **Espaço** ou o botão **Golpe saltado** para a habilidade; **Voltar à vila** retorna ao comércio. **I** ou **Mochila** abre o inventário. O Mercador reforça a espada por 20 ouro e cura 12 PV por 10 ouro.

## Regras desta versão

- Espadachim: 28 PV, 5 de dano, ataque a cada 0,8 s. Esqueleto: 30 PV, 3 de dano, ataque a cada 1,6 s.
- Vitória: 5 ouro, 8 XP e 2 PV. Primeiro nível em 40 XP; +3 PV máximos por nível e +1 dano a cada três níveis.
- Habilidade: 20 de dano e recarga de 18 s. **O custo de 12 mana é provisório**, pois ainda não foi definido no documento de design.
- Mana máxima de 30 com regeneração de 1 a cada 2,5 s, preços da loja e aumento de 20 XP na exigência por nível também são números provisórios.
- Esqueletos renascem após 25 s; o herói, após 3 s. Os valores ficam em [`gameConfig.mjs`](./gameConfig.mjs).
- O progresso é salvo no `localStorage` deste navegador, com versão do formato. Dados inválidos são copiados para uma chave de backup antes de começar uma sessão temporária. Saves de outra versão também são preservados; nenhuma dessas sessões substitui o progresso anterior.
- O farm avança somente enquanto a página está aberta. Não há ganhos offline ou sincronização entre aparelhos.

## Publicar no GitHub Pages

1. Coloque `index.html`, `style.css`, `game.mjs`, `gameConfig.mjs` e `state.mjs` na **raiz** da branch `main`.
2. No repositório GitHub, abra **Settings → Pages**.
3. Em **Build and deployment**, escolha **Deploy from a branch**, branch **main**, pasta **/(root)** e salve.
4. Abra o endereço acima após a implantação. Todos os caminhos dos arquivos são relativos, compatíveis com `/Idle-Projeto-Ryze/`.

Para testar localmente, se Node.js já estiver disponível, execute `node tests/serve.mjs` e acesse `http://127.0.0.1:4173/`. Abrir `index.html` diretamente com `file://` pode bloquear módulos JavaScript em alguns navegadores.

## Limites e próximos passos

A mochila tem espaços demonstrativos; apenas a espada é equipável nesta versão. O Mundo dos Centauros, a partir do nível 5, e os equipamentos restantes ficam para a próxima fase. **TODO:** definir pré-requisitos e probabilidades da corrupção para monstros comuns de todos os mundos; bosses de dungeon não podem ser corrompidos. Sprites e tilesets finais ainda não estão incluídos.

## Verificação de código

Com Node.js disponível: `node --test tests/state.test.mjs` verifica carregamento e proteção do save, progressão e compras. A checagem de sintaxe pode ser feita com `node --check game.mjs`.
