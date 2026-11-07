// End-to-end check of the app's injected page-world scripts against the live promptugal.news, in Chromium.
// callAsyncJavaScript runs a function body with named arguments; here the same body is wrapped in an async function.
const { chromium } = require('playwright');
const S = require("./scripts.json");
const call = (page, body, args) => page.evaluate(({ body, args }) => {
  const names = Object.keys(args);
  const fn = new Function(...names, `return (async () => { ${body} })()`);
  return fn(...names.map(n => args[n]));
}, { body, args });

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const log = (...a) => console.log(...a);
  const slug = 'ai-doom-or-boom';

  // 1. An event page: the app writes a pick; the website's own button must repaint to "In my day".
  await page.goto(`https://promptugal.news/events/${slug}/index.html`, { waitUntil: 'networkidle' });
  log('read before:', JSON.stringify(await call(page, S.readSchedule, {})));
  const before = await page.locator('.nr-pick').first().textContent();
  const doc = JSON.stringify({ v: 1, picks: [{ id: slug, at: '2026-11-08T03:12:45.120Z' }] });
  const changed = await call(page, S.writeSchedule, { doc });
  const after = await page.locator('.nr-pick').first().textContent();
  log('button:', JSON.stringify(before), '→', JSON.stringify(after), '| changed', changed);
  log('read after:', await call(page, S.readSchedule, {}));
  log('website NRSchedule.has:', await page.evaluate(s => window.NRSchedule && window.NRSchedule.has(s), slug));

  // 2. A pick made on the page is what the app reads back.
  await page.locator('.nr-pick').first().click();   // toggles it off on the website
  log('after website toggle:', await call(page, S.readSchedule, {}));

  // 3. /my-day/ lists a pick the app wrote.
  await call(page, S.writeSchedule, { doc });
  await page.goto('https://promptugal.news/my-day/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  const rows = await page.locator('.pt-myday li').allTextContents();
  log('my-day rows:', rows.length, rows.map(r => r.slice(0, 60)));

  // 4. The meter: read it, credit once, credit the same reference again (must be refused).
  await page.goto('https://promptugal.news/account/index.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  log('meter before:', await call(page, S.readMeter, {}));
  log('credit 1:', await call(page, S.creditMeter, { amount: 500, ref: 'appstore-test-1' }));
  log('credit again:', await call(page, S.creditMeter, { amount: 500, ref: 'appstore-test-1' }));
  log('meter after:', await call(page, S.readMeter, {}));
  log('balance shown:', await page.locator('#nr-balance').textContent().catch(() => 'n/a'));

  // 5. The top-up hiding script (page world, document start in the app): Stripe link hidden, app button added.
  await page.addInitScript({ content: 'window.ptApp = { call: async () => ({}) };\n' + S.hideWebTopUp });
  await page.goto('https://promptugal.news/account/index.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  const topup = page.locator('#nr-account .balance-card .actions a.btn.primary[href*="top-up"]');
  log('web top-up visible:', await topup.count() ? await topup.first().isVisible() : 'absent',
      '| app button:', await page.locator('.pt-app-topup').count());
  await page.goto('https://promptugal.news/account/top-up.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  log('top-up page stripe visible:', await page.locator('a[href*="buy.stripe.com"]').count()
      ? await page.locator('a[href*="buy.stripe.com"]').first().isVisible() : 'absent',
      '| note:', await page.locator('.pt-app-note').count());

  await browser.close();
})().catch(e => { console.error('FAILED', e); process.exit(1); });
