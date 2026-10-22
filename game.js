(() => {
const $ = (id) => document.getElementById(id);
if (!window.IdleRyzeConfig || !window.IdleRyzeState) {
  $('game').textContent = 'Não foi possível carregar os arquivos do jogo. Recarregue a página ou abra o index.html da pasta completa.';
  return;
}
const { GAME, maxHpAt, xpNeeded, damageAt } = window.IdleRyzeConfig;
const { loadGame, saveGame, grantKill, buySword, buyPotion } = window.IdleRyzeState;

const Phaser = window.Phaser ?? { Scene: class {} };
const imageAssets = {};
let browserStorage;
try { browserStorage = window.localStorage; } catch { /* O jogo ainda funciona sem save. */ }
const loaded = loadGame(browserStorage);
const state = loaded.state;
let currentScene = null;
let toastTimer;
let lastSave = 0;
let skillReadyAt = 0;
const heldDirections = new Set();

function persist() {
  if (!saveGame(browserStorage, state, loaded.writable)) toast('Não foi possível salvar nesta sessão.');
  lastSave = Date.now();
}

function toast(message) {
  const element = $('toast');
  element.textContent = message;
  element.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => element.classList.remove('show'), 2700);
}

function renderHud() {
  $('level').textContent = state.level;
  $('hp').textContent = `${state.hp}/${maxHpAt(state.level)}`;
  $('mana').textContent = `${state.mana}/${GAME.hero.maxMana}`;
  $('xp').textContent = `${state.xp}/${xpNeeded(state.level)}`;
  $('gold').textContent = state.gold;
  $('hp-fill').style.width = `${100 * state.hp / maxHpAt(state.level)}%`;
  $('mana-fill').style.width = `${100 * state.mana / GAME.hero.maxMana}%`;
  $('xp-fill').style.width = `${100 * state.xp / xpNeeded(state.level)}%`;
  const combat = currentScene?.scene.key === 'SkeletonWorld';
  $('interact-button').hidden = combat;
  $('return-button').hidden = !combat;
  $('mobile-pad').style.visibility = combat ? 'hidden' : '';
  const skill = $('skill-button');
  skill.hidden = !combat;
  if (combat) {
    const remaining = Math.ceil(Math.max(0, currentScene.skillCooldown) / 1000);
    skill.textContent = remaining ? `Golpe saltado · ${remaining}s` : `Golpe saltado · ${GAME.skill.manaCost} mana`;
    skill.disabled = remaining > 0 || state.mana < GAME.skill.manaCost || state.hp <= 0 || !currentScene.enemies?.some(enemy => enemy.alive);
  }
}

function openPanel(kicker, title, html) {
  $('panel-kicker').textContent = kicker;
  $('panel-title').textContent = title;
  $('panel-body').innerHTML = html;
  $('panel').showModal();
}

function openInventory() {
  openPanel('ESPADACHIM · EQUIPAMENTO', 'Inventário', `
    <p class="panel-copy">Quatro espaços de equipamento e uma mochila preparada para os próximos itens.</p>
    <h3 class="panel-section">EQUIPADO</h3><div class="slots">
    <div class="slot"><small>Arma / espada</small><strong>${state.swordLevel ? `Espada reforçada +${state.swordLevel}` : 'Espada gasta'}</strong></div>
    <div class="slot"><small>Capacete</small><strong>Vazio</strong></div><div class="slot"><small>Botas</small><strong>Vazio</strong></div><div class="slot"><small>Peitoral</small><strong>Vazio</strong></div></div>
    <h3 class="panel-section">MOCHILA</h3><div class="bag">${'<span>＋</span>'.repeat(8)}</div>
    <p class="panel-note">Os demais equipamentos e os itens da mochila chegam nas próximas versões.</p>`);
}

function openMerchant() {
  openPanel('VILA · COMÉRCIO', 'Mercador', `
    <p class="panel-copy">“Tenho aço para sua jornada e um tônico para as feridas.”</p>
    <div class="shop-row"><div><strong>Reforçar espada</strong><small>+1 dano permanente · nível atual ${state.swordLevel}</small></div><button id="buy-sword" type="button" ${state.gold < GAME.shop.swordCost ? 'disabled' : ''}>${GAME.shop.swordCost} ◆</button></div>
    <div class="shop-row"><div><strong>Tônico de cura</strong><small>Recupera até ${GAME.shop.potionHeal} PV agora</small></div><button id="buy-potion" type="button" ${state.gold < GAME.shop.potionCost || state.hp >= maxHpAt(state.level) ? 'disabled' : ''}>${GAME.shop.potionCost} ◆</button></div>
    <p class="panel-note">Dano atual: ${damageAt(state.level, state.swordLevel)} por ataque básico.</p>`);
  $('buy-sword').addEventListener('click', () => { if (buySword(state)) { persist(); renderHud(); openMerchant(); toast('Espada reforçada!'); } });
  $('buy-potion').addEventListener('click', () => { if (buyPotion(state)) { persist(); renderHud(); openMerchant(); toast('Vida restaurada.'); } });
}

function openCommander() {
  openPanel('VILA · PORTAL', 'Comandante do Portal', `
    <p class="panel-copy">“Os esqueletos avançam além do limiar. Você está pronto, Espadachim?”</p>
    <button id="enter-world" type="button" class="panel-primary">Entrar no Mundo dos Esqueletos</button>
    <p class="panel-note">O Mundo dos Centauros abre no nível 5 em uma versão futura.</p>`);
  $('enter-world').addEventListener('click', () => { $('panel').close(); enterSkeletonWorld(); });
}

function enterSkeletonWorld() {
  state.scene = 'skeleton';
  persist();
  currentScene.scene.start('SkeletonWorld');
}

function returnToVillage() {
  state.scene = 'village';
  persist();
  currentScene.scene.start('Village');
}

function fillPoly(graphics, points, color, alpha = 1) {
  graphics.fillStyle(color, alpha);
  graphics.fillPoints(points.map(([x, y]) => ({ x, y })), true);
}

function makeHero(scene) {
  const wrap = scene.add.container(0, 0);
  const shadow = scene.add.ellipse(0, 8, 43, 16, 0x061319, .48);
  if (scene.textures.exists('swordsman')) {
    const art = scene.add.image(0, 1, 'swordsman').setOrigin(.5, 1);
    art.setDisplaySize(104 * art.width / art.height, 104);
    wrap.add([shadow, art]);
    return wrap;
  }
  const g = scene.add.graphics();
  // Silhueta original, simples e legível mesmo em tela pequena.
  g.fillStyle(0x293b4a).fillEllipse(0, -4, 31, 16);
  g.fillStyle(0x244c6a).fillRect(-13, -41, 25, 31);
  g.fillStyle(0x788a96).fillRect(-15, -42, 29, 8);
  g.fillStyle(0x485b66).fillRect(-10, -11, 8, 16).fillRect(3, -11, 8, 16);
  g.fillStyle(0xe4b99a).fillEllipse(0, -49, 17, 18);
  fillPoly(g, [[-15,-52],[-6,-64],[8,-64],[15,-52]], 0xaabac1);
  g.lineStyle(4, 0xd7e7df).lineBetween(15, -34, 31, -59);
  g.lineStyle(3, 0xc69c5d).lineBetween(11, -30, 21, -39);
  wrap.add([shadow, g]);
  return wrap;
}

function makeNpc(scene, key, x, y, height) {
  const npc = scene.add.container(x, y);
  const shadow = scene.add.ellipse(0, 6, 45, 13, 0x061319, .5);
  const art = scene.add.image(0, 0, key).setOrigin(.5, 1);
  art.setDisplaySize(height * art.width / art.height, height);
  npc.add([shadow, art]);
  return npc;
}

function makeSkeleton(scene) {
  const wrap = scene.add.container(0, 0);
  const g = scene.add.graphics();
  g.fillStyle(0x061318, .5).fillEllipse(0, 7, 34, 13);
  g.lineStyle(5, 0xc4c7b5).lineBetween(-7,-7,-8,5).lineBetween(7,-7,8,5);
  g.fillStyle(0xbac1b3).fillEllipse(0, -25, 18, 25);
  g.lineStyle(2, 0x556d6a).strokeEllipse(0,-25,18,25);
  g.fillStyle(0xd6d9c7).fillEllipse(0,-43,23,21);
  g.fillStyle(0x283537).fillCircle(-5,-45,3).fillCircle(5,-45,3);
  g.lineStyle(3, 0x879991).lineBetween(11,-24,22,-7);
  wrap.add(g);
  return wrap;
}

function drawTree(scene, parent, x, y, scale = 1) {
  const g = scene.add.graphics();
  g.fillStyle(0x513e32).fillRect(-4,-28,8,34);
  fillPoly(g, [[0,-72],[-23,-27],[23,-27]], 0x1e524f);
  fillPoly(g, [[0,-59],[-19,-19],[19,-19]], 0x2b7163);
  g.lineStyle(2,0x518373,.6).lineBetween(0,-62,-7,-44);
  g.setPosition(x,y).setScale(scale);
  parent.add(g);
}

function drawBuilding(scene, parent, x, y, kind) {
  const g = scene.add.graphics();
  const wall = kind === 'shop' ? 0x735e4b : 0x586a69;
  fillPoly(g,[[-66,-14],[0,20],[66,-14],[0,-48]],0x242f32);
  fillPoly(g,[[-57,-28],[0,0],[0,-65],[-57,-92]],wall);
  fillPoly(g,[[0,0],[57,-28],[57,-92],[0,-65]],kind === 'shop' ? 0x8a6d50 : 0x728281);
  fillPoly(g,[[-68,-89],[0,-121],[68,-89],[0,-55]],kind === 'shop' ? 0x4b342f : 0x384856);
  fillPoly(g,[[-68,-89],[0,-55],[0,-64],[-68,-98]],0x342c30);
  g.fillStyle(0xe6ad59).fillRect(18,-64,20,25);
  g.fillStyle(0xffdc84,.25).fillCircle(28,-53,23);
  g.fillStyle(0x26343b).fillRect(-30,-45,16,35);
  g.lineStyle(3,0xbf9d66).strokeRect(-30,-45,16,35);
  g.setPosition(x,y);
  parent.add(g);
}

function label(scene, parent, x, y, title, sub, color = '#f2e7cd') {
  const wrap = scene.add.container(x,y);
  const titleText = scene.add.text(0, 0, title, {fontFamily:'system-ui',fontSize:'17px',fontStyle:'bold',color,stroke:'#0b1a21',strokeThickness:4}).setOrigin(.5);
  const subText = scene.add.text(0, 20, sub, {fontFamily:'system-ui',fontSize:'11px',color:'#c8d3c9',stroke:'#0b1a21',strokeThickness:3}).setOrigin(.5);
  wrap.add([titleText, subText]);
  if(scene.worldScale < .7) wrap.setScale(1.5);
  parent.add(wrap);
  return wrap;
}

class BaseWorld extends Phaser.Scene {
  constructor(key) { super(key); }
  createBase(bgColor) {
    currentScene = this;
    this.cameras.main.setBackgroundColor(bgColor);
    for (const [key, source] of Object.entries(imageAssets)) {
      if (source && !this.textures.exists(key)) this.textures.addImage(key, source);
    }
    this.world = this.add.container(0,0);
    this.hero = makeHero(this);
    this.world.add(this.hero);
    this.scale.on('resize', this.layout, this);
    this.events.once('shutdown', () => { this.scale.off('resize', this.layout, this); if (currentScene === this) currentScene = null; });
    this.layout();
  }
  layout() {
    const w = this.scale.width, h = this.scale.height;
    this.worldScale = w < 650
      ? Math.min(.55, Math.max(.34, w/900))
      : Math.min(1.2, Math.max(.52, Math.min(w/900,h/530)));
    this.world.setScale(this.worldScale);
    this.positionWorld();
  }
  positionWorld() {
    const w = this.scale.width, h = this.scale.height;
    const follow = w < 650 ? .25 : 0;
    this.world.setPosition(w/2 - (this.hero?.x || 0)*this.worldScale*follow, h/2 + 22 - (this.hero?.y || 0)*this.worldScale*follow);
  }
  localPointer(pointer) { return { x:(pointer.x-this.world.x)/this.worldScale, y:(pointer.y-this.world.y)/this.worldScale }; }
  setHeroPosition(x,y) { this.hero.setPosition(x,y); this.positionWorld(); }
  floatingText(x,y,text,color='#ffe7a2') {
    const t=this.add.text(this.world.x+x*this.worldScale,this.world.y+(y-48)*this.worldScale,text,{fontFamily:'system-ui',fontSize:'18px',fontStyle:'bold',color,stroke:'#102029',strokeThickness:4}).setOrigin(.5);
    this.tweens.add({targets:t,y:t.y-35,alpha:0,duration:850,onComplete:()=>t.destroy()});
  }
}

class Village extends BaseWorld {
  constructor(){super('Village');}
  create(){
    this.createBase('#10252b');
    $('scene-kicker').textContent='REFÚGIO INICIAL'; $('scene-title').textContent='Vila de Ryze';
    $('scene-hint').textContent='WASD / setas · E para interagir';
    $('legend').textContent='Clique/toque no chão para caminhar. Aproxime-se de um personagem ou do portal.';
    this.illustrated = ['village-courtyard', 'merchant', 'portal-commander'].every(key => this.textures.exists(key));
    this.drawVillage();
    this.world.bringToTop(this.hero);
    this.setHeroPosition(-15,125);
    this.keys=this.input.keyboard.addKeys('W,A,S,D,UP,DOWN,LEFT,RIGHT');
    this.target=null; this.pending=null;
    this.interactables=this.illustrated ? [
      {x:-260,y:5,name:'Mercador',action:openMerchant},
      {x:140,y:-45,name:'Comandante',action:openCommander},
      {x:300,y:-30,name:'Portal',action:enterSkeletonWorld},
    ] : [
      {x:-230,y:35,name:'Mercador',action:openMerchant},
      {x:140,y:-65,name:'Comandante',action:openCommander},
      {x:285,y:-45,name:'Portal',action:enterSkeletonWorld},
    ];
    this.input.on('pointerdown',pointer=>{
      const p=this.localPointer(pointer);
      const chosen=this.interactables.find(o=>this.illustrated
        ? o.name==='Portal' ? Math.abs(p.x-340)<88 && p.y>-255 && p.y<20
          : Math.abs(p.x-o.x)<48 && p.y>o.y-112 && p.y<o.y+46
        : Phaser.Math.Distance.Between(p.x,p.y,o.x,o.y)<53);
      if(chosen){ this.target={x:chosen.x,y:chosen.y}; this.pending=chosen; if(this.near(chosen)){this.target=null;this.pending=null;chosen.action();} }
      else { this.target=p; this.pending=null; }
    });
    renderHud();
  }
  drawVillage(){
    if (this.illustrated) {
      const ambient=this.add.image(0,0,'village-courtyard').setDisplaySize(1550,1450).setAlpha(.16).setTint(0x6fa5a2);
      this.world.add(ambient);
      const backdrop=this.add.image(0,0,'village-courtyard').setDisplaySize(1000,667);
      this.world.add(backdrop);
      const portal=this.add.container(340,-160);
      const portalArt=this.textures.exists('skeleton-portal')
        ? this.add.image(0,0,'skeleton-portal').setDisplaySize(160,240)
        : this.add.ellipse(0,0,140,180,0x30d8a6,.65);
      portal.add(portalArt);
      this.world.add(portal);
      this.tweens.add({targets:portal,alpha:.72,scaleX:1.03,scaleY:1.02,duration:1300,yoyo:true,repeat:-1});
      this.world.add(makeNpc(this,'merchant',-260,5,102));
      this.world.add(makeNpc(this,'portal-commander',140,-45,110));
      label(this,this.world,-260,-115,'Mercador','equipamentos');
      label(this,this.world,140,-165,'Comandante','mundos');
      label(this,this.world,340,-272,'Portal','esqueletos','#8af1df');
      return;
    }
    const ground=this.add.graphics();
    ground.fillStyle(0x10252b).fillRect(-650,-360,1300,720);
    for(let row=0;row<11;row++)for(let col=0;col<11;col++){
      const x=(col-row)*42, y=(col+row-10)*21;
      const path=Math.abs(col-row)<2 || Math.abs(col+row-10)<2;
      const color=path ? ((row+col)%3===0 ? 0x77847a : 0x68786f) : ((row*13+col*7)%5===0 ? 0x3e6258 : 0x36574f);
      fillPoly(ground,[[x,y-21],[x+42,y],[x,y+21],[x-42,y]],color);
      ground.lineStyle(1,0x172e31,.42).strokePoints([{x,y:y-21},{x:x+42,y},{x,y:y+21},{x:x-42,y}],true);
    }
    this.world.add(ground);
    drawTree(this,this.world,-360,-5,1.15); drawTree(this,this.world,-300,-110,.85);
    drawTree(this,this.world,356,55,1.1); drawTree(this,this.world,60,-165,.78);
    drawBuilding(this,this.world,-250,-36,'shop');
    drawBuilding(this,this.world,83,-122,'guard');
    // Fogueiras e bandeiras aquecem a pedra escura.
    const props=this.add.graphics();
    for(const [x,y] of [[-115,10],[210,98]]){
      props.fillStyle(0x193a39).fillEllipse(x,y+4,39,14);
      props.fillStyle(0xffbc5e,.25).fillCircle(x,y-10,23);
      fillPoly(props,[[x,y-25],[x-8,y],[x+8,y]],0xf5ae54);
      fillPoly(props,[[x,y-18],[x-4,y],[x+4,y]],0xffe5a1);
    }
    this.world.add(props);
    // Portal em camadas; animação pequena e barata.
    const portal=this.add.container(285,-53),pg=this.add.graphics();
    pg.fillStyle(0x1b343e).fillEllipse(0,15,95,33);
    pg.lineStyle(11,0x597e80).strokeEllipse(0,-29,69,100);
    pg.lineStyle(5,0x7ee2d3,.9).strokeEllipse(0,-29,53,84);
    pg.fillStyle(0x35c2b4,.44).fillEllipse(0,-29,44,75);
    pg.fillStyle(0xc7fff0,.22).fillEllipse(0,-29,20,55);
    portal.add(pg); this.world.add(portal);
    this.tweens.add({targets:pg,alpha:.65,scaleX:1.06,scaleY:1.03,duration:1100,yoyo:true,repeat:-1});
    // NPCs distantes entre si e com silhuetas diferentes.
    const merchant=this.add.graphics();
    merchant.fillStyle(0x12252b,.55).fillEllipse(-230,43,45,15);
    fillPoly(merchant,[[-248,35],[-239,-6],[-219,-6],[-211,35]],0x946c41);
    merchant.fillStyle(0xe8c69e).fillCircle(-230,-13,11);
    merchant.fillStyle(0x654a33).fillEllipse(-230,-20,24,9);
    merchant.fillStyle(0xd1ad70).fillRect(-246,5,31,7);
    this.world.add(merchant);
    const commander=this.add.graphics();
    commander.fillStyle(0x12252b,.55).fillEllipse(140,-53,42,14);
    fillPoly(commander,[[124,-59],[130,-104],[150,-104],[158,-59]],0x566e83);
    commander.fillStyle(0xc7d1c9).fillRect(127,-98,27,7);
    commander.fillStyle(0xe6ba94).fillCircle(140,-112,11);
    fillPoly(commander,[[126,-116],[139,-130],[154,-116]],0xb8c2bf);
    commander.lineStyle(4,0xb5c7bf).lineBetween(161,-112,161,-45);
    this.world.add(commander);
    label(this,this.world,-230,-80,'Mercador','equipamentos');
    label(this,this.world,140,-147,'Comandante','mundos');
    label(this,this.world,285,-132,'Portal','esqueletos','#8af1df');
  }
  near(object){return Phaser.Math.Distance.Between(this.hero.x,this.hero.y,object.x,object.y)<GAME.interactionRadius;}
  interact(){
    const nearest=this.interactables.reduce((best,o)=>!best||Phaser.Math.Distance.Between(this.hero.x,this.hero.y,o.x,o.y)<Phaser.Math.Distance.Between(this.hero.x,this.hero.y,best.x,best.y)?o:best,null);
    if(nearest&&this.near(nearest)) nearest.action(); else toast('Aproxime-se do Mercador, Comandante ou Portal.');
  }
  update(_time,delta){
    const dt=Math.min(delta,50)/1000;
    let dx=0,dy=0;
    if(this.keys.A.isDown||this.keys.LEFT.isDown||heldDirections.has('left')) dx--;
    if(this.keys.D.isDown||this.keys.RIGHT.isDown||heldDirections.has('right')) dx++;
    if(this.keys.W.isDown||this.keys.UP.isDown||heldDirections.has('up')) dy--;
    if(this.keys.S.isDown||this.keys.DOWN.isDown||heldDirections.has('down')) dy++;
    if(dx||dy){this.target=null;this.pending=null;}
    else if(this.target){ const dist=Phaser.Math.Distance.Between(this.hero.x,this.hero.y,this.target.x,this.target.y); if(dist>5){dx=(this.target.x-this.hero.x)/dist;dy=(this.target.y-this.hero.y)/dist;} else this.target=null; }
    if(dx||dy){
      const size=Math.hypot(dx,dy),speed=GAME.hero.moveSpeed*dt;
      let x=this.hero.x+dx/size*speed,y=this.hero.y+dy/size*speed;
      const diamond=Math.abs(x)/410+Math.abs(y)/205;
      if(diamond>.91){x*=.91/diamond;y*=.91/diamond;}
      this.setHeroPosition(x,y);
      this.hero.scaleX=dx<0?-1:1;
    }
    if(this.pending&&this.near(this.pending)){const action=this.pending.action;this.pending=null;this.target=null;action();}
  }
}

class SkeletonWorld extends BaseWorld {
  constructor(){super('SkeletonWorld');}
  create(){
    this.createBase('#11242a');
    $('scene-kicker').textContent='REGIÃO DE COMBATE · IDLE'; $('scene-title').textContent='Mundo dos Esqueletos';
    $('scene-hint').textContent='Combate automático · espaço para golpe saltado';
    $('legend').textContent='O Espadachim encontra alvos e ataca sozinho. Volte à vila para comprar melhorias.';
    this.drawArena();
    this.world.bringToTop(this.hero);
    this.setHeroPosition(-215,80);
    this.enemies=[[-30,-55],[155,-80],[200,85]].map((pos,index)=>this.spawnSkeleton(pos[0],pos[1],index));
    this.attackClock=0;this.manaClock=0;this.skillCooldown=Math.max(0,skillReadyAt-Date.now());this.deathClock=state.hp<=0?GAME.hero.respawnMs:0;
    renderHud();toast('Combate automático iniciado.');
  }
  drawArena(){
    const g=this.add.graphics();
    g.fillStyle(0x11242a).fillRect(-650,-340,1300,680);
    for(let row=0;row<10;row++)for(let col=0;col<12;col++){
      const x=(col-row)*38,y=(col+row-10)*19;
      const c=(row*7+col*11)%7===0?0x435453:0x304846;
      fillPoly(g,[[x,y-19],[x+38,y],[x,y+19],[x-38,y]],c);
      g.lineStyle(1,0x10252a,.5).strokePoints([{x,y:y-19},{x:x+38,y},{x,y:y+19},{x:x-38,y}],true);
    }
    for(const [x,y] of [[-305,-70],[300,-72],[-90,135]]){
      g.fillStyle(0x596965).fillEllipse(x,y,37,13);
      g.fillStyle(0x6a7670).fillRect(x-5,y-28,10,26);
      fillPoly(g,[[x-12,y-28],[x+12,y-28],[x+7,y-41],[x-7,y-41]],0x79857d);
    }
    this.world.add(g);
    drawTree(this,this.world,-340,-75,.7);drawTree(this,this.world,320,65,.85);
    label(this,this.world,0,-190,'Terras das Ossadas','combate automático','#e2cab7');
  }
  spawnSkeleton(x,y,index){
    const sprite=makeSkeleton(this);sprite.setPosition(x,y);this.world.add(sprite);
    const bar=this.add.graphics();this.world.add(bar);
    const enemy={x,y,homeX:x,homeY:y,index,sprite,bar,hp:GAME.skeleton.maxHp,alive:true,respawn:0,attackClock:GAME.skeleton.attackMs};
    this.drawEnemyBar(enemy);
    return enemy;
  }
  drawEnemyBar(enemy){
    const g=enemy.bar;g.clear();if(!enemy.alive)return;
    g.fillStyle(0x0d1a1e,.9).fillRoundedRect(enemy.x-25,enemy.y-67,50,7,3);
    g.fillStyle(0xcb7471).fillRoundedRect(enemy.x-23,enemy.y-65,46*enemy.hp/GAME.skeleton.maxHp,3,1);
  }
  nearest(){
    let nearest, best=Infinity;
    for(const enemy of this.enemies){if(!enemy.alive)continue;const d=(this.hero.x-enemy.x)**2+(this.hero.y-enemy.y)**2;if(d<best){best=d;nearest=enemy;}}
    return nearest;
  }
  hitEnemy(enemy,damage,special=false){
    enemy.hp=Math.max(0,enemy.hp-damage);
    this.floatingText(enemy.x,enemy.y,special?`✦ ${damage}`:`${damage}`,special?'#7bf1e5':'#ffe3a3');
    enemy.sprite.setAlpha(.4);this.time.delayedCall(110,()=>enemy.sprite?.setAlpha(1));
    this.drawEnemyBar(enemy);
    if(enemy.hp===0){
      enemy.alive=false;enemy.sprite.setVisible(false);enemy.bar.clear();enemy.respawn=GAME.skeleton.respawnMs;
      const levels=grantKill(state);persist();renderHud();
      toast(levels?`Nível ${state.level}! +${GAME.skeleton.gold} ouro · +${GAME.skeleton.xp} XP`:`Esqueleto derrotado! +${GAME.skeleton.gold} ouro · +${GAME.skeleton.xp} XP`);
      if(levels) this.floatingText(this.hero.x,this.hero.y,`NÍVEL ${state.level}`,'#fff0a0');
    }
  }
  castSkill(){
    if(state.hp<=0||state.mana<GAME.skill.manaCost||this.skillCooldown>0)return;
    const target=this.nearest();if(!target)return;
    state.mana-=GAME.skill.manaCost;skillReadyAt=Date.now()+GAME.skill.cooldownMs;this.skillCooldown=GAME.skill.cooldownMs;
    const dx=target.x-this.hero.x,dy=target.y-this.hero.y,d=Math.hypot(dx,dy)||1;
    this.setHeroPosition(target.x-dx/d*43,target.y-dy/d*43);
    const ring=this.add.circle(this.world.x+target.x*this.worldScale,this.world.y+target.y*this.worldScale,12,0x7cf4dd,.35);
    this.tweens.add({targets:ring,scale:3.2,alpha:0,duration:330,onComplete:()=>ring.destroy()});
    this.hitEnemy(target,GAME.skill.damage,true);persist();renderHud();
  }
  update(_time,delta){
    const ms=Math.min(delta,100),dt=ms/1000;
    this.skillCooldown=Math.max(0,skillReadyAt-Date.now());
    this.manaClock+=ms;
    if(this.manaClock>=GAME.hero.manaRegenMs){this.manaClock-=GAME.hero.manaRegenMs;state.mana=Math.min(GAME.hero.maxMana,state.mana+1);}
    for(const enemy of this.enemies){
      if(!enemy.alive){enemy.respawn-=ms;if(enemy.respawn<=0){enemy.alive=true;enemy.hp=GAME.skeleton.maxHp;enemy.x=enemy.homeX;enemy.y=enemy.homeY;enemy.sprite.setPosition(enemy.x,enemy.y).setVisible(true);enemy.attackClock=GAME.skeleton.attackMs;this.drawEnemyBar(enemy);}continue;}
    }
    if(state.hp<=0){
      this.deathClock-=ms;
      if(this.deathClock<=0){state.hp=maxHpAt(state.level);state.mana=GAME.hero.maxMana;this.setHeroPosition(-215,80);this.deathClock=0;persist();toast('Você renasceu e voltou à luta.');}
      renderHud();return;
    }
    const target=this.nearest();
    if(target){
      const distance=Phaser.Math.Distance.Between(this.hero.x,this.hero.y,target.x,target.y);
      if(distance>GAME.attackRadius-12){const step=Math.min(GAME.hero.moveSpeed*dt,distance-GAME.attackRadius+12);this.setHeroPosition(this.hero.x+(target.x-this.hero.x)/distance*step,this.hero.y+(target.y-this.hero.y)/distance*step);}
      else{this.attackClock-=ms;if(this.attackClock<=0){this.attackClock=GAME.hero.attackMs;this.hitEnemy(target,damageAt(state.level,state.swordLevel));}}
    }
    for(const enemy of this.enemies){
      if(!enemy.alive)continue;
      const distance=Phaser.Math.Distance.Between(this.hero.x,this.hero.y,enemy.x,enemy.y);
      if(distance>GAME.enemyAttackRadius&&distance<220){const step=Math.min(GAME.skeleton.speed*dt,distance-GAME.enemyAttackRadius);enemy.x+=(this.hero.x-enemy.x)/distance*step;enemy.y+=(this.hero.y-enemy.y)/distance*step;enemy.sprite.setPosition(enemy.x,enemy.y);this.drawEnemyBar(enemy);}
      else if(distance<=GAME.enemyAttackRadius){enemy.attackClock-=ms;if(enemy.attackClock<=0){enemy.attackClock=GAME.skeleton.attackMs;state.hp=Math.max(0,state.hp-GAME.skeleton.damage);this.floatingText(this.hero.x,this.hero.y,`-${GAME.skeleton.damage}`,'#ff8587');if(state.hp===0){this.deathClock=GAME.hero.respawnMs;toast('Você caiu. Renascimento em 3 segundos.');persist();}renderHud();}}
    }
  }
}

$('inventory-button').addEventListener('click',openInventory);
$('panel-close').addEventListener('click',()=>$('panel').close());
$('interact-button').addEventListener('click',()=>currentScene?.interact?.());
$('skill-button').addEventListener('click',()=>currentScene?.castSkill?.());
$('return-button').addEventListener('click',returnToVillage);
for(const button of document.querySelectorAll('[data-dir]')){
  const direction=button.dataset.dir;
  button.addEventListener('pointerdown',event=>{event.preventDefault();button.setPointerCapture(event.pointerId);heldDirections.add(direction);});
  for(const name of ['pointerup','pointercancel','lostpointercapture'])button.addEventListener(name,()=>heldDirections.delete(direction));
}
window.addEventListener('blur',()=>heldDirections.clear());
window.addEventListener('keydown',event=>{
  if(event.repeat||$('panel').open||event.target.closest?.('input,textarea,[contenteditable="true"]'))return;
  if(event.code==='KeyI'){event.preventDefault();openInventory();}
  if(event.code==='KeyE'&&currentScene?.scene.key==='Village'){event.preventDefault();currentScene.interact();}
  if(event.code==='Space'&&currentScene?.scene.key==='SkeletonWorld'){event.preventDefault();currentScene.castSkill();}
  if(['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(event.code))event.preventDefault();
});
window.addEventListener('beforeunload',()=>saveGame(browserStorage,state,loaded.writable));
setInterval(()=>{renderHud();if(loaded.writable&&Date.now()-lastSave>5000)persist();},250);

function loadImage(file) {
  return new Promise(resolve => {
    const picture = new Image();
    picture.onload = () => resolve(picture);
    picture.onerror = () => resolve(null);
    picture.src = `./assets/${file}`;
  });
}

if(!window.Phaser){$('game').textContent='Não foi possível carregar Phaser. Reabra o index.html da pasta completa.';}
else {
  $('game').textContent='Carregando cenário…';
  Promise.all([
    ['swordsman','swordsman.png'],
    ['village-courtyard','village-courtyard.png'],
    ['merchant','merchant.png'],
    ['portal-commander','portal-commander.png'],
    ['skeleton-portal','skeleton-portal.png'],
  ].map(async ([key,file]) => [key,await loadImage(file)])).then(assets => {
    for (const [key,picture] of assets) imageAssets[key]=picture;
    $('game').textContent='';
    window.idleRyzeGame = new Phaser.Game({
      type:Phaser.CANVAS,parent:'game',backgroundColor:'#14282e',
      scale:{mode:Phaser.Scale.RESIZE,width:960,height:600,autoCenter:Phaser.Scale.CENTER_BOTH},
      render:{pixelArt:false,antialias:true},
      input:{activePointers:3},
      scene:state.scene==='skeleton'?[SkeletonWorld,Village]:[Village,SkeletonWorld],
      callbacks:{postBoot(){if(loaded.warning)setTimeout(()=>toast(loaded.warning),500);}}
    });
  });
}
})();
