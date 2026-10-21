((global) => {
const config = global.IdleRyzeConfig || (typeof module === 'object' && module.exports ? require('./gameConfig.js') : null);
if (!config) return; // game.js exibirá uma mensagem caso gameConfig.js não carregue.
const { GAME, maxHpAt, xpNeeded } = config;

const cleanInt = (value, fallback, min, max) => Number.isFinite(value) ? Math.min(max, Math.max(min, Math.floor(value))) : fallback;

function freshState() {
  return { version: GAME.saveVersion, level: 1, xp: 0, gold: 0, hp: GAME.hero.maxHp, mana: GAME.hero.maxMana, swordLevel: 0, scene: 'village' };
}

function normalizeState(raw) {
  if (!raw || raw.version !== GAME.saveVersion || typeof raw !== 'object') return null;
  const level = cleanInt(raw.level, 1, 1, 999);
  return {
    version: GAME.saveVersion,
    level,
    xp: cleanInt(raw.xp, 0, 0, xpNeeded(level) - 1),
    gold: cleanInt(raw.gold, 0, 0, 999999999),
    hp: cleanInt(raw.hp, maxHpAt(level), 0, maxHpAt(level)),
    mana: cleanInt(raw.mana, GAME.hero.maxMana, 0, GAME.hero.maxMana),
    swordLevel: cleanInt(raw.swordLevel, 0, 0, 99),
    scene: raw.scene === 'skeleton' ? 'skeleton' : 'village',
  };
}

function loadGame(storage) {
  let serialized;
  try { storage ??= global.localStorage; serialized = storage.getItem(GAME.saveKey); }
  catch { return { state: freshState(), writable: false, warning: 'Armazenamento indisponível. Esta sessão não será salva.' }; }
  if (serialized === null) return { state: freshState(), writable: true, warning: '' };
  try {
    const raw = JSON.parse(serialized);
    if (raw?.version !== GAME.saveVersion) return { state: freshState(), writable: false, warning: 'Save de outra versão encontrado. Ele foi preservado; esta sessão não será salva.' };
    const state = normalizeState(raw);
    if (state) return { state, writable: true, warning: '' };
  } catch { /* Preservar o dado bruto em uma chave separada. */ }
  try { storage.setItem(`${GAME.saveKey}.backup.${Date.now()}`, serialized); }
  catch { return { state: freshState(), writable: false, warning: 'Save danificado. Não foi possível criar cópia; esta sessão não será salva.' }; }
  return { state: freshState(), writable: false, warning: 'Save danificado: cópia de segurança criada. Esta sessão não será salva.' };
}

function saveGame(storage, state, writable = true) {
  if (!writable) return false;
  try { storage.setItem(GAME.saveKey, JSON.stringify(normalizeState(state))); return true; }
  catch { return false; }
}

function grantKill(state) {
  state.gold += GAME.skeleton.gold;
  state.xp += GAME.skeleton.xp;
  state.hp = Math.min(maxHpAt(state.level), state.hp + GAME.hero.healOnKill);
  let levels = 0;
  while (state.xp >= xpNeeded(state.level)) {
    state.xp -= xpNeeded(state.level);
    state.level++;
    state.hp = maxHpAt(state.level);
    state.mana = GAME.hero.maxMana;
    levels++;
  }
  return levels;
}

function buySword(state) {
  if (state.gold < GAME.shop.swordCost || state.swordLevel >= 99) return false;
  state.gold -= GAME.shop.swordCost;
  state.swordLevel++;
  return true;
}

function buyPotion(state) {
  if (state.gold < GAME.shop.potionCost || state.hp >= maxHpAt(state.level)) return false;
  state.gold -= GAME.shop.potionCost;
  state.hp = Math.min(maxHpAt(state.level), state.hp + GAME.shop.potionHeal);
  return true;
}

const api = { freshState, normalizeState, loadGame, saveGame, grantKill, buySword, buyPotion };
global.IdleRyzeState = api;
if (typeof module === 'object' && module.exports) module.exports = api;
})(globalThis);
