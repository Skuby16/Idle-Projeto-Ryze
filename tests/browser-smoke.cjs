// Smoke test opcional: usa Playwright instalado no ambiente de teste, sem build do jogo.
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', headless: true, args: ['--no-sandbox'] });
  const errors = [];
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
    page.on('pageerror', error => errors.push(error.message));
    await page.goto('http://127.0.0.1:4173/', { waitUntil: 'domcontentloaded' });
    await page.locator('canvas').waitFor({ timeout: 20000 });
    assert.match(await page.locator('#scene-title').innerText(), /Vila/);
    await page.screenshot({ path: 'tests/desktop-smoke.png' });
    await page.locator('#inventory-button').click();
    assert.equal(await page.locator('.slot').count(), 4);
    await page.locator('#panel-close').click();

    const canvas = page.locator('canvas');
    const box = await canvas.boundingBox();
    const scale = Math.min(1.2, Math.max(.52, Math.min(box.width / 900, box.height / 530)));
    const centerX = box.width / 2, centerY = box.height / 2 + 22;
    await canvas.click({ position: { x: centerX - 230 * scale, y: centerY + 35 * scale } });
    await page.locator('#panel-title:has-text("Mercador")').waitFor({ timeout: 8000 });
    await page.locator('#panel-close').click();
    await canvas.click({ position: { x: centerX + 140 * scale, y: centerY - 65 * scale } });
    await page.locator('#panel-title:has-text("Comandante do Portal")').waitFor({ timeout: 8000 });
    await page.locator('#panel-close').click();
    await page.keyboard.press('e');
    await page.locator('#panel-title:has-text("Comandante do Portal")').waitFor({ timeout: 8000 });
    await page.locator('#panel-close').click();
    await canvas.click({ position: { x: centerX + 285 * scale, y: centerY - 45 * scale } });
    await page.locator('#scene-title:has-text("Mundo dos Esqueletos")').waitFor({ timeout: 10000 });
    await page.locator('#skill-button').click();
    assert.match(await page.locator('#skill-button').innerText(), /s$/);
    await page.waitForFunction(() => Number(document.querySelector('#gold').textContent) >= 5, { timeout: 15000 });
    await page.locator('#return-button').click();
    await page.locator('#scene-title:has-text("Vila de Ryze")').waitFor({ timeout: 8000 });
    await page.reload();
    await page.locator('canvas').waitFor();
    assert.ok(Number(await page.locator('#gold').innerText()) >= 5);
    const shopPage = await browser.newPage({ viewport: { width: 1280, height: 800 } });
    shopPage.on('pageerror', error => errors.push(error.message));
    await shopPage.addInitScript(() => localStorage.setItem('idle-ryze-2.save', JSON.stringify({ version: 1, level: 1, xp: 0, gold: 50, hp: 14, mana: 30, swordLevel: 0, scene: 'village' })));
    await shopPage.goto('http://127.0.0.1:4173/', { waitUntil: 'domcontentloaded' });
    await shopPage.locator('canvas').waitFor();
    const shopBox = await shopPage.locator('canvas').boundingBox();
    const shopScale = Math.min(1.2, Math.max(.52, Math.min(shopBox.width / 900, shopBox.height / 530)));
    await shopPage.locator('canvas').click({ position: { x: shopBox.width / 2 - 230 * shopScale, y: shopBox.height / 2 + 22 + 35 * shopScale } });
    await shopPage.locator('#buy-sword').waitFor({ timeout: 8000 });
    await shopPage.locator('#buy-sword').click();
    await shopPage.locator('#buy-potion').click();
    assert.equal(await shopPage.locator('#gold').innerText(), '20');
    assert.equal(await shopPage.locator('#hp').innerText(), '26/28');
    await shopPage.locator('#panel-close').click();

    const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
    mobile.on('pageerror', error => errors.push(error.message));
    await mobile.goto('http://127.0.0.1:4173/', { waitUntil: 'domcontentloaded' });
    await mobile.locator('canvas').waitFor({ timeout: 20000 });
    assert.equal(await mobile.locator('#mobile-pad').isVisible(), true);
    assert.equal(await mobile.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    assert.equal(await mobile.evaluate(() => [...document.querySelectorAll('.resource')].every(element => element.getBoundingClientRect().right <= innerWidth)), true);
    await mobile.screenshot({ path: 'tests/mobile-smoke.png' });
    const mobileCanvas = mobile.locator('canvas');
    const mobileBox = await mobileCanvas.boundingBox();
    const mobileScale = Math.min(1.2, Math.max(.52, Math.min(mobileBox.width / 900, mobileBox.height / 530)));
    await mobileCanvas.click({ position: { x: mobileBox.width / 2 + 15 * mobileScale * .25 + 285 * mobileScale, y: mobileBox.height / 2 + 22 - 125 * mobileScale * .25 - 45 * mobileScale } });
    await mobile.locator('#scene-title:has-text("Mundo dos Esqueletos")').waitFor({ timeout: 10000 });
    const withoutCdn = await browser.newPage();
    await withoutCdn.route('https://cdnjs.cloudflare.com/ajax/libs/phaser/**', route => route.abort());
    await withoutCdn.goto('http://127.0.0.1:4173/', { waitUntil: 'domcontentloaded' });
    await withoutCdn.locator('#game:has-text("Não foi possível carregar Phaser")').waitFor();
    assert.deepEqual(errors, []);
    console.log('Browser smoke: vila, NPCs, compras, portal, combate, habilidade, save, viewport mobile e falha do CDN OK');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
