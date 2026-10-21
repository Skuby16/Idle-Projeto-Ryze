# Idle Ryze 2.0 — Documento de design

## Visão do projeto
Reconstrução completa do jogo **Idle Ryze** para web PC e celular. **Não** migrar o código, gráficos ou estrutura visual antigos. **Preservar** as regras e a essência de gameplay Idle, refinando os detalhes em iterações. Idioma da interface: **português do Brasil**.

**Direção de arte aprovada:** 2D isométrico moderno, fantasia medieval levemente sombria, com leitura clara de personagens e ambientes; vila em pedra, iluminação quente nas lojas, efeitos mágicos azul-esverdeados no portal e sensação de ARPG premium simplificado. A arte conceitual aprovada na conversa serve como referência, mas **não** é sprite/tileset pronto para jogo. Criar assets originais modulares (ou placeholders vetoriais temporários) que possam ser substituídos depois.

## Plataforma e restrições
- Rodar diretamente em navegador no PC e celular, sem instalar programas.
- GitHub Pages a partir de `main` / `(root)` em https://skuby16.github.io/Idle-Projeto-Ryze/.
- Para a primeira versão preferir **Phaser** por CDN com HTML/CSS/JavaScript estáticos, sem build obrigatório no PC.
- Otimizar desempenho para máquinas modestas; manter controles responsivos para teclado, mouse e toque.
- Salvar progresso localmente (localStorage). Versionar o formato de save, tolerar corrupção de dados e oferecer reinício/exportação/importação futuramente.
- Com GitHub Pages e salvamento local, **não** presumir contas online, multiplayer, backend nem sincronização entre dispositivos.

## Loop central
1. Jogador inicia na **Vila** como **Espadachim**.
2. Na vila, controla o personagem por **WASD**, setas e controle de toque (joystick opcional) e interage com o **Mercador** e **Comandante do Portal**.
3. Entra pelo portal no **Mundo dos Esqueletos**.
4. Na região de combate, movimentação/seleção de alvo e ataques básicos são **automáticos** (Idle); herói enfrenta monstros, recebe dano, sobe de nível e ganha ouro.
5. Pode retornar à Vila, melhorar equipamentos e escolher novos mundos. O loop de farm só funciona enquanto o jogo estiver aberto inicialmente (não criar ganhos offline sem aprovação).

## Mecânicas estabelecidas em discussões anteriores
- Mundo inicial: **Mundo dos Esqueletos**. Segundo mundo planejado: **Mundo dos Centauros**, disponível a partir do **nível 5**.
- Classe inicial **Espadachim**, com ataque básico automático e habilidade especial de **salto/golpe de espada** que consome mana. Um valor anteriormente proposto foi **20 de dano** e **18 s de recarga** (confirmar/rebalancear depois; custo de mana ainda indefinido).
- Valores de protótipo usados anteriormente: herói **28 PV**, **5 dano por ataque**, intervalo **0,8 s**; Esqueleto **30 PV**, **3 dano por ataque**, intervalo **1,6 s**.
- Vitória contra esqueleto: **5 ouro** e **8 XP**; primeira subida de nível a **40 XP**; recupera **2 PV** ao vencer.
- Evolução inicial anterior: **+3 PV máximos por nível**, **+1 dano a cada 3 níveis**. Ao morrer, renascimento após **3 s**.
- Respawn de monstros: pedido mais recente mencionou **25 segundos**. Há uma definição anterior de **45 segundos**: tratar como valor ajustável e validar no teste.
- Equipamentos no inventário: **4 slots separados**, para **arma/espada**, **capacete**, **botas** e **peitoral**. Ao lado, mostrar a **mochila** com espaços vazios preparados para os itens.
- Ouro, XP, nível, vida e mana visíveis na HUD, e feedback visual de ataques e de subida de nível.
- **Corrupção dos monstros**: Pedra de Corrupção e outros requisitos / probabilidades por tipo de monstro. O usuário quer aplicar a regra aos monstros comuns de **todos os mundos**, incluindo centauros, **exceto bosses de dungeon**. **Não inventar** os números e os pré-requisitos ainda não recuperados; documentar como pendente.
- A vila deve ter distância visual entre **Mercador** e **Comandante do Portal**, e o comandante pode ficar um pouco mais acima.

## Primeiro marco jogável (v0.1)
- Cena de Vila isométrica navegável, com Espadachim, Mercador, Comandante e Portal dos Esqueletos.
- Mundo dos Esqueletos, com pelo menos um monstro e combate Idle visível.
- Indicadores de Vida, Mana, XP, Nível e Ouro.
- Retorno à vila, uma habilidade com cooldown, salvamento simples no navegador.
- Inventário abre e mostra quatro slots equipáveis + mochila (itens podem ser apenas demonstrativos por enquanto).
- Visuais temporários gerados via Graphics/SVG enquanto os sprites definitivos não estiverem prontos.
- README com instruções de execução no Pages, controles e limitações.
- Testar no navegador e em viewport mobile, sem depender de instalação local do usuário.

## Critérios para futuras fases
- Substituir placeholders por tilesets e sprites 2D isométricos originais com animações de caminhada/ataque.
- Segundo mundo, centauros, progressão e drop de equipamentos.
- Sistema completo de corrupção baseado nas regras confirmadas.
- Interface avançada de inventário e gerenciamento de equipamentos.
- Balanceamento de combate/XP e salvamento robusto.

## Atenção
As regras de sistema não devem ser alteradas silenciosamente. Quando um valor tiver sido usado apenas em protótipo, mantê-lo configurável em `gameConfig` para facilitar ajustes. Não prometer que a imagem conceitual da conversa está incluída nos arquivos do repositório.
