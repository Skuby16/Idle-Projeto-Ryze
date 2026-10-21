import test from 'node:test';
import assert from 'node:assert/strict';
import { GAME, damageAt, maxHpAt } from '../gameConfig.mjs';
import { freshState, loadGame, saveGame, grantKill, buySword, buyPotion } from '../state.mjs';

function memoryStorage(initial = {}) {
  const data = new Map(Object.entries(initial));
  return { data, getItem: key => data.has(key) ? data.get(key) : null, setItem: (key, value) => data.set(key, String(value)) };
}

test('cinco esqueletos geram o primeiro nível e preservam o excedente de XP', () => {
  const state = freshState();
  for (let i = 0; i < 4; i++) assert.equal(grantKill(state), 0);
  assert.equal(grantKill(state), 1);
  assert.equal(state.level, 2);
  assert.equal(state.xp, 0);
  assert.equal(state.gold, 25);
  assert.equal(state.hp, maxHpAt(2));
  assert.equal(damageAt(4), GAME.hero.damage + 1);
});

test('compras cobram ouro, curam até o máximo e aumentam dano', () => {
  const state = freshState();
  state.gold = 30;
  state.hp = 20;
  assert.equal(buySword(state), true);
  assert.equal(buyPotion(state), true);
  assert.equal(state.gold, 0);
  assert.equal(state.hp, 28);
  assert.equal(damageAt(state.level, state.swordLevel), 6);
  assert.equal(buySword(state), false);
});

test('save versionado normaliza valores e volta à cena salva', () => {
  const storage = memoryStorage();
  const state = freshState();
  state.scene = 'skeleton'; state.gold = 17;
  assert.equal(saveGame(storage, state), true);
  const loaded = loadGame(storage);
  assert.equal(loaded.state.scene, 'skeleton');
  assert.equal(loaded.state.gold, 17);
  assert.equal(loaded.writable, true);
});

test('save de versão futura permanece intacto', () => {
  const original = JSON.stringify({ version: GAME.saveVersion + 1, gold: 999 });
  const storage = memoryStorage({ [GAME.saveKey]: original });
  const loaded = loadGame(storage);
  assert.equal(loaded.writable, false);
  assert.equal(saveGame(storage, loaded.state, loaded.writable), false);
  assert.equal(storage.getItem(GAME.saveKey), original);
});

test('save de versão antiga também permanece intacto até haver migração', () => {
  const original = JSON.stringify({ version: 0, gold: 999 });
  const storage = memoryStorage({ [GAME.saveKey]: original });
  const loaded = loadGame(storage);
  assert.equal(loaded.writable, false);
  assert.equal(saveGame(storage, loaded.state, loaded.writable), false);
  assert.equal(storage.getItem(GAME.saveKey), original);
});

test('save danificado cria backup antes do novo jogo', () => {
  const storage = memoryStorage({ [GAME.saveKey]: '{quebrado' });
  const loaded = loadGame(storage);
  assert.equal(loaded.state.level, 1);
  assert.equal(loaded.writable, false);
  const backup = [...storage.data.entries()].find(([key]) => key.startsWith(`${GAME.saveKey}.backup.`));
  assert.equal(backup?.[1], '{quebrado');
  assert.equal(storage.getItem(GAME.saveKey), '{quebrado');
});
