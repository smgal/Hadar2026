const fs = require('fs');
const path = require('path');
const os = require('os');

const home = os.homedir();
const extensionTarget = path.resolve(__dirname, '..');
const extensionName = 'hadar2026.cm2-script-0.1.0';

const targets = {
  vscode: path.join(home, '.vscode', 'extensions', extensionName),
  antigravity: path.join(home, '.antigravity-ide', 'extensions', extensionName),
};

const mode = (process.argv[2] || 'all').toLowerCase();
const selected = mode === 'vscode' ? ['vscode'] : mode === 'antigravity' ? ['antigravity'] : ['vscode', 'antigravity'];

for (const key of selected) {
  const dest = targets[key];
  const parentDir = path.dirname(dest);

  if (!fs.existsSync(parentDir)) {
    fs.mkdirSync(parentDir, { recursive: true });
  }

  if (fs.existsSync(dest)) {
    try {
      fs.unlinkSync(dest);
    } catch {
      try {
        fs.rmdirSync(dest);
      } catch {
        fs.rmSync(dest, { recursive: true, force: true });
      }
    }
  }

  const symlinkType = process.platform === 'win32' ? 'junction' : 'dir';
  fs.symlinkSync(extensionTarget, dest, symlinkType);
  console.log(`[${key}] Linked: ${dest} -> ${extensionTarget}`);
}
