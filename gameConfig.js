// Script clássico para também funcionar quando index.html é aberto por file://.
((global) => {
// Valores de protótipo. Ajustar aqui após testes de balanceamento.
// Mana, preços da loja e XP após o primeiro nível são parâmetros provisórios.
const GAME = Object.freeze({
  saveKey: 'idle-ryze-2.save',
  saveVersion: 1,
  hero: { maxHp: 28, maxMana: 30, damage: 5, attackMs: 800, moveSpeed: 175, manaRegenMs: 2500, respawnMs: 3000, healOnKill: 2 },
  skeleton: { maxHp: 30, damage: 3, attackMs: 1600, respawnMs: 25000, speed: 60, gold: 5, xp: 8 },
  skill: { damage: 20, manaCost: 12, cooldownMs: 18000 }, // Custo de mana provisório; ainda não definido no design.
  progression: { firstLevelXp: 40, extraXpPerLevel: 20, hpPerLevel: 3, damageEveryLevels: 3 },
  shop: { swordCost: 20, swordDamage: 1, potionCost: 10, potionHeal: 12 },
  interactionRadius: 90,
  attackRadius: 75,
  enemyAttackRadius: 68,
});

const xpNeeded = (level) => GAME.progression.firstLevelXp + (level - 1) * GAME.progression.extraXpPerLevel;
const maxHpAt = (level) => GAME.hero.maxHp + (level - 1) * GAME.progression.hpPerLevel;
const damageAt = (level, swordLevel = 0) => GAME.hero.damage + Math.floor((level - 1) / GAME.progression.damageEveryLevels) + swordLevel * GAME.shop.swordDamage;

const api = { GAME, xpNeeded, maxHpAt, damageAt };
global.IdleRyzeConfig = api;
if (typeof module === 'object' && module.exports) module.exports = api;
})(globalThis);
