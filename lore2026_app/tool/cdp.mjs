// 헤드리스 크롬을 CDP 로 부리는 작은 도구 — 웹 빌드를 키로 조작하고 화면을 찍는다.
// node cdp.mjs nav <url> [ms] | eval <js> | shot <file> | key <Key> [n] [holdMs] [gapMs] | sleep <ms>
//              | cdp <Method> [jsonParams]
// 명령 여러 개를 이어 쓸 수 있다: node cdp.mjs key ArrowUp 2 -- key Enter -- sleep 1000 -- shot a.png
// 크롬을 먼저 띄운다 (HANDOFF.md 「브라우저로 확인하기」):
//   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
//     --remote-debugging-port=9333 --user-data-dir=<임시 폴더> --window-size=1600,960 http://127.0.0.1:5320/
import fs from 'node:fs';
const port = process.env.CDP_PORT || 9333;
const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const page = targets.find(t => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener('open', r, { once: true }));
let id = 0; const pending = new Map();
ws.addEventListener('message', ev => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
});
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
const sleep = ms => new Promise(r => setTimeout(r, ms));
const KEYS = { ArrowDown: 40, ArrowUp: 38, ArrowLeft: 37, ArrowRight: 39, Enter: 13, Escape: 27, ' ': 32, Space: 32 };
const args = process.argv.slice(2);
const cmds = []; let cur = [];
for (const a of args) { if (a === '--') { cmds.push(cur); cur = []; } else cur.push(a); }
if (cur.length) cmds.push(cur);
for (const [c, ...a] of cmds) {
  if (c === 'nav') { await send('Page.navigate', { url: a[0] }); await sleep(Number(a[1] || 4000)); }
  else if (c === 'eval') { const r = await send('Runtime.evaluate', { expression: a[0], awaitPromise: true, returnByValue: true }); console.log(JSON.stringify(r.result?.result?.value ?? r.result)); }
  else if (c === 'shot') { const r = await send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(a[0], Buffer.from(r.result.data, 'base64')); console.log('saved', a[0]); }
  else if (c === 'cdp') { const r = await send(a[0], a[1] ? JSON.parse(a[1]) : {}); console.log(JSON.stringify(r.result ?? r.error).slice(0, 300)); }
  else if (c === 'sleep') { await sleep(Number(a[0])); }
  else if (c === 'key') {
    const key = a[0] === 'Space' ? ' ' : a[0]; const n = Number(a[1] || 1); const hold = Number(a[2] || 170); const gap = Number(a[3] || 200);
    const code = key === ' ' ? 'Space' : key; const vk = KEYS[a[0]] ?? key.toUpperCase().charCodeAt(0);
    for (let i = 0; i < n; i++) {
      await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', key, code, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk });
      if (key.length === 1) await send('Input.dispatchKeyEvent', { type: 'char', text: key, key, code });
      if (hold) await sleep(hold);
      await send('Input.dispatchKeyEvent', { type: 'keyUp', key, code, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk });
      await sleep(gap);
    }
  }
}
ws.close();
