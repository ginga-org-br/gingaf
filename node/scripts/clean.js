const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
['playground', 'dist', 'site', 'public/gingaf-web'].forEach((d) => {
  const target = path.join(root, d);
  if (fs.existsSync(target)) {
    fs.rmSync(target, { recursive: true, force: true });
  }
});

console.log('\x1b[33m●\x1b[0m Note: this does not clean the current gingaf-web build, you need to rebuild it by flutter build web --release');
