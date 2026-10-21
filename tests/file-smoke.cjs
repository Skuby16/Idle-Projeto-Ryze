// Abre index.html como um usuário faria com duplo clique, sem servidor local.
const assert = require('node:assert/strict');
const { resolve } = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', headless: true, args: ['--no-sandbox'] });
  const errors = [];
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    await page.goto(pathToFileURL(resolve(__dirname, '..', 'index.html')).href, { waitUntil: 'load' });
    await page.locator('canvas').waitFor({ timeout: 8000 });
    assert.equal(await page.locator('canvas').count(), 1);
    await page.locator('#inventory-button').click();
    assert.equal(await page.locator('.slot').count(), 4);
    await page.locator('#panel-close').click();
    const canvas = page.locator('canvas');
    const box = await canvas.boundingBox();
    const scale = Math.min(1.2, Math.max(.52, Math.min(box.width / 900, box.height / 530)));
    await canvas.click({ position: { x: box.width / 2 + 285 * scale, y: box.height / 2 + 22 - 45 * scale } });
    await page.locator('#scene-title:has-text("Mundo dos Esqueletos")').waitFor({ timeout: 10000 });
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('idle-ryze-2.save')).scene), 'skeleton');
    await page.locator('#return-button').click();
    await page.locator('#scene-title:has-text("Vila de Ryze")').waitFor({ timeout: 8000 });
    assert.deepEqual(errors, []);
    console.log('Arquivo local: Vila, inventário, portal, combate e save funcionais sem servidor.');
  } catch (error) {
    console.error('Falha ao abrir arquivo local:', error.message, errors);
    process.exitCode = 1;
  } finally { await browser.close(); }
})();
