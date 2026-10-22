extends RefCounted

# Valores do protótipo, alinhados a GAME_DESIGN.md e gameConfig.js.
const HERO_HP := 28
const HERO_MANA := 30
const HERO_DAMAGE := 5
const HERO_ATTACK_SECONDS := 0.8
const HERO_MOVE_SPEED := 180.0
const HERO_RESPAWN_SECONDS := 3.0
const SKELETON_HP := 30
const SKELETON_DAMAGE := 3
const SKELETON_ATTACK_SECONDS := 1.6
const SKELETON_RESPAWN_SECONDS := 25.0
const KILL_GOLD := 5
const KILL_XP := 8
const KILL_HEAL := 2
const SKILL_DAMAGE := 20
const SKILL_COOLDOWN_SECONDS := 18.0
const SKILL_MANA_COST := 12 # Provisório: custo ainda não definido no design.
const MANA_REGEN_SECONDS := 2.5 # Provisório.
const SWORD_COST := 20 # Provisório.
const POTION_COST := 10 # Provisório.
const POTION_HEAL := 12 # Provisório.
const INTERACTION_RADIUS := 80.0

static func max_hp(level: int) -> int:
	return HERO_HP + max(0, level - 1) * 3

static func xp_needed(level: int) -> int:
	return 40 + max(0, level - 1) * 20 # Progressão após nível 1 é provisória.

static func damage(level: int, sword_level: int) -> int:
	return HERO_DAMAGE + int(max(0, level - 1) / 3.0) + sword_level
