const fs = require('fs');
const path = require('path');

const src = path.resolve(__dirname, '..', '..', 'ginga', 'build', 'web');
const dest = path.resolve(__dirname, '..', 'assets');

if (fs.existsSync(dest)) {
  fs.rmSync(dest, { recursive: true, force: true });
}
fs.mkdirSync(dest, { recursive: true });
fs.cpSync(src, dest, { recursive: true });

const idx = path.join(dest, 'index.html');
if (fs.existsSync(idx)) {
  let content = fs.readFileSync(idx, 'utf8');
  content = content.replace(/<base href="[^"]*">/, '<base href="./">');
  fs.writeFileSync(idx, content, 'utf8');
}
