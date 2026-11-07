const { chromium } = require('playwright');
const S = require("./scripts.json");
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  // a stand-in for the native handler; in the app it lives only in the bridge's content world
  await p.addInitScript({ content: `window.webkit = { messageHandlers: { pt: { postMessage: async m => {
      window.__sent = (window.__sent || []).concat([m.op]);
      if (m.op === 'nope') throw new Error('Unknown op nope.');
      return { op: m.op, picks: 1 } } } } };\n` + S.bridgeWorld + '\n' + S.pageAPI });
  await p.goto('https://promptugal.news/events/ai-doom-or-boom/index.html', { waitUntil: 'networkidle' });
  console.log('ptApp:', await p.evaluate(() => JSON.stringify({ v: window.ptApp.version, ops: window.ptApp.ops })));
  console.log('call ok:', await p.evaluate(() => window.ptApp.call('schedule.get').then(JSON.stringify)));
  console.log('call refused:', await p.evaluate(() => window.ptApp.call('nope').catch(e => 'rejected: ' + e.message)));
  // the page's own toggle reaches the app (bridge world listens to nr:schedule)
  await p.locator('.nr-pick').first().click(); await p.waitForTimeout(300);
  console.log('sent to app:', await p.evaluate(() => JSON.stringify(window.__sent)));
  console.log('class:', await p.evaluate(() => document.documentElement.className));
  await b.close();
})().catch(e => { console.error('FAILED', e); process.exit(1); });
